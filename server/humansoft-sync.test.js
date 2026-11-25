import test from 'node:test';
import assert from 'node:assert/strict';
import jpeg from 'jpeg-js';
import {sourceDateTime,syncFor} from './humansoft-sync.js';
import {hash,dateKey} from './hono.js';
import {seal,issueFaceProof} from './session.js';
import handler from '../api/[route].js';

const source = {company:'psd',employee:'fixture-source'};
const config = {HUMANSOFT_IMPORT_MODE:'uat',HUMANSOFT_IMPORT_KEY:'uat-key',
  HUMANSOFT_EMPLOYEE_MAP:'{"fixture-source":"fixture-target"}',
  UPSTASH_REDIS_REST_URL:'https://ledger.invalid',UPSTASH_REDIS_REST_TOKEN:'fixture-token'};

function network(t, {rows = [],reply,loseReply = false,honoReply = true, historyLag = false} = {}) {
  const ledger = new Map(), imports = [], events = [];
  const original = globalThis.fetch;
  const day = dateKey(), now = new Date(Date.now()+7*3600000).toISOString().slice(11,19);
  const sourceRows = [];
  let visible = !historyLag;
  globalThis.fetch = async(input,init) => {
    const url = new URL(input);
    if(url.hostname === 'ledger.invalid') {
      const [command,...args] = JSON.parse(init.body);
      if(command==='HGETALL') return Response.json({result:[...(ledger.get(args[0]) ?? new Map())].flat()});
      const [,n,key,id,old,next,claim] = args;
      assert.equal(command,'EVAL'); assert.equal(n,1);
      const set = ledger.get(key) ?? new Map(); ledger.set(key,set);
      if ((set.get(id) ?? '') !== old || (claim && set.has(claim))) return Response.json({result:0});
      if(claim) set.set(claim,id);
      if(next) set.set(id,next); else set.delete(id);
      return Response.json({result:1});
    }
    if (url.hostname === 'openapi.humansoft.co.th') {
      assert.ok(url.pathname.startsWith('/uat/api/v1/open-apis/'));
      assert.equal(init.headers['Ocp-Apim-Subscription-Key'],'uat-key');
      if(url.pathname.endsWith('/salary/get-data-filter')) {
        assert.equal(url.searchParams.get('employee_code'),'fixture-target');
        return Response.json({code:200,payload:rows});
      }
      assert.equal(url.pathname,'/uat/api/v1/open-apis/time-attendance/import');
      events.push('import'); imports.push(JSON.parse(init.body));
      if(loseReply) throw Error('lost response');
      return Response.json(reply ?? {code:200,message:'successfully en-queued',payload:{invalid_items:[]}});
    }
    if(url.hostname==='psd.hono.ai') {
      if(url.pathname.endsWith('checkForAttMethod_v2')) return Response.json({result:true,facial_recog:1,showbothinout:1,inTimeFlag:1});
      if(url.pathname.endsWith('UserVisitFetchRecords_v2')) return Response.json({result:true,data:visible?sourceRows:[]});
      if(url.pathname.endsWith('UserVisitProfileImage')) {
        events.push('hono');
        if(honoReply===null) throw Error('uncertain HONO');
        if(honoReply)sourceRows.push({emp_code:source.employee,punch_time:now,flag:init.body.get('punch'),status:1});
        return Response.json({result:honoReply});
      }
    }
    throw Error('Unexpected request: '+url.pathname);
  };
  t.after(()=>globalThis.fetch=original);
  return {imports,events,day,now,sourceRows,reveal:()=>{visible=true;}};
}
function setupEnv(t) {
  for(const [key,value] of Object.entries({...config,SESSION_SECRET:'ab'.repeat(32)})){
    const old=process.env[key]; process.env[key]=value;
    t.after(()=>{if(old===undefined) delete process.env[key]; else process.env[key]=old;});
  }
}
function client(day,punch='I') {
  const session={...source,id:'fixture-'+punch,base:'https://psd.hono.ai/Service/',php:'1',token:'source',markKey:'mark',exp:Date.now()+60000};
  const image=jpeg.encode({width:4,height:4,data:Buffer.alloc(64,255)}).data;
  const headers={host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(session)};
  async function call(path,body) {
    const res={setHeader(){},status(n){this.http=n;return this;},json(x){this.data=x;}};
    await handler({method:'POST',url:'/api/'+path,headers,body},res);return res;
  }
  return {
    submit:()=>call('submit',{proof:issueFaceProof({sid:session.id,hash:hash(image),date:day,historyHash:hash('[]')}),
      punch,jpeg:image.toString('base64'),lat:13,lng:100}),
    history:()=>call('history',{date:day,syncPending:true}),
  };
}

test('web submit imports one confirmed OUT and read-back requires employee, direction and receipt',async t=>{
  setupEnv(t);const rows=[];const net=network(t,{rows});const web=client(net.day,'O');
  const result=await web.submit();
  assert.deepEqual(result.data,{ok:true,humanSoft:'queued'});assert.deepEqual(net.events,['hono','import']);
  const time=net.day+' '+net.now;
  assert.deepEqual(net.imports,[{import_data:[{status:'ADD',employee_code:'fixture-target',date:net.day,datetime:time,time_attendance_type:'OUT'}]}]);
  const row={employee_code:'fixture-target',attendance_datetime:time,attendance_inout:'OUT',time_attendance_transac_id:'receipt'};
  rows.push({...row,employee_code:'other'}, {...row,attendance_inout:'IN'}, {...row,time_attendance_transac_id:null});
  assert.equal((await web.history()).data.data[0].humanSoft,'queued');
  rows.push(row);
  assert.equal((await web.history()).data.data[0].humanSoft,'recorded');assert.equal(net.imports.length,1);
});

test('delayed IN visibility and racing refreshes emit only one import; lost acknowledgement never resubmits',async t=>{
  setupEnv(t);const net=network(t,{historyLag:true,loseReply:true});const web=client(net.day);
  assert.deepEqual((await web.submit()).data,{ok:true,humanSoft:'waiting'});assert.deepEqual(net.events,['hono']);
  net.reveal();await Promise.all([web.history(),web.history(),web.history()]);
  assert.equal(net.imports.length,1);assert.equal(net.imports[0].import_data[0].time_attendance_type,'IN');
  assert.equal((await web.history()).data.data[0].humanSoft,'unknown');assert.equal(net.imports.length,1);
});

for (const [name,reply] of [['rejects',false],['times out',null]]) {
  test('when HONO '+name+' no destination attendance request is made',async t=>{
    setupEnv(t);const net=network(t,{honoReply:reply});const web=client(net.day,'O');
    assert.notEqual((await web.submit()).http,200);await web.history();
    assert.deepEqual(net.events,['hono']);
  });
}
test('a partially rejected import never displays as queued',async t=>{
  const net=network(t,{reply:{code:200,message:'successfully en-queued',payload:{invalid_items:[{index:0}]}}});
  const sync=syncFor(source,net.day,config);const ticket=await sync.reserve([],'I');
  assert.equal(await sync.confirmed(ticket,async()=>({data:[{flag:'I',punch_time:net.now}]})),'rejected');
});

test('separate instances honor the reservation and existing destination history',async t=>{
  const rows=[]; const net=network(t,{rows});
  rows.push({employee_code:'fixture-target',attendance_inout:'IN',attendance_datetime:net.day+' '+net.now,time_attendance_transac_id:'existing'});
  const a=syncFor(source,net.day,config),b=syncFor(source,net.day,config);
  const ticket=await a.reserve([],'I');
  await assert.rejects(b.reserve([],'I'),{code:'sync_duplicate'});
  assert.equal(await a.confirmed(ticket,async()=>({data:[{flag:'I',punch_time:net.now}]})),'recorded');
  assert.equal(net.imports.length,0);
});

test('legacy Thai office time, date rollover and malformed or out-of-day source times',()=>{
  const d='2026-11-06';
  assert.equal(sourceDateTime(d,'06-Nov-2026----  9:05am'),d+' 09:05:00');
  assert.equal(sourceDateTime(d,'2026-11-05T17:01:00Z'),d+' 00:01:00');
  assert.equal(sourceDateTime(d,'12:34:56'),d+' 12:34:56');
  for(const bad of ['2026-11-05 12:30','XX:00','24:01','9:60','2026-11-06T17:01:00Z'])assert.equal(sourceDateTime(d,bad),null);
  assert.equal(syncFor(source,d,{}),null);
  assert.equal(syncFor({...source,employee:'other'},d,config),null);
  assert.throws(()=>syncFor(source,d,{...config,HUMANSOFT_IMPORT_MODE:'production',VERCEL_ENV:'preview'}),{code:'sync_config'});
});

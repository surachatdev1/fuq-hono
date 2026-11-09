import test from 'node:test';
import assert from 'node:assert/strict';
import {hex,encode,query,validDate,allows,hash,jpegBytes} from './hono.js';
import {seal,open,requireLedger} from './session.js';
import {validate} from './maps.js';
import handler from '../api/[route].js';

test('PHP envelope retains exact inner URL and space-padded AES',()=>{
 const inner=query('https://psd.hono.ai/Service/login',{pass:'a b&?',userid:'owner'});
 assert.match(inner,/pass=a%20b%26%3F/);
 const encoded=encode(inner,'1');assert.equal(Buffer.from(encoded.slice(3,-3),'base64').toString(),inner);
 assert.equal(hex('1234567890123456').length,64);
});
test('dates, owner-directed punch selection and image limits reject bad input',()=>{
 assert.equal(validDate('2026-11-09'),'2026-11-09');assert.throws(()=>validDate('2026-02-30'));
 assert.equal(allows({inTimeFlag:1},[],'I'),true);
 assert.equal(allows({inTimeFlag:''},[],'O'),false);
 assert.equal(allows({inTimeFlag:'unknown'},[],'O'),false);
 assert.equal(allows({inTimeFlag:'1.0'},[],'I'),false);
 assert.equal(allows({inTimeFlag:1},[{flag:'I'}],'I'),false);
 assert.equal(allows({inTimeFlag:1},[{flag:'O'}],'O'),true);
 assert.throws(()=>jpegBytes('not-an-image'));
 assert.notEqual(hash('image 1'),hash('image 2'));
});
test('sealed session hides tokens, detects tamper and expires',()=>{
 process.env.SESSION_SECRET='01'.repeat(32);
 const raw={id:'session-owner',token:'private-token',exp:Date.now()+60000};const encrypted=seal(raw);
 assert.equal(encrypted.includes('private-token'),false);assert.deepEqual(open(encrypted),raw);
 const bytes=Buffer.from(encrypted,'base64url');bytes[15]^=1;assert.throws(()=>open(bytes.toString('base64url')));
 assert.throws(()=>open(seal({...raw,exp:Date.now()-1})));
});
test('Maps blocks foreign destinations and credentials',()=>{
 assert.equal(validate('https://maps.app.goo.gl/example').hostname,'maps.app.goo.gl');
 for(const url of ['https://evil.test/maps','http://google.com/maps','https://google.com.evil.test/maps','https://user@google.com/maps','https://google.com:444/maps'])assert.throws(()=>validate(url));
});
test('clocking is fail-closed without durable ledger',()=>{delete process.env.UPSTASH_REDIS_REST_URL;delete process.env.UPSTASH_REDIS_REST_TOKEN;assert.throws(requireLedger,/ต้องเชื่อม/);});
function response(){return {headers:{},statusCode:0,setHeader(k,v){this.headers[k]=v;},status(c){this.statusCode=c;return this;},json(j){this.body=j;return this;}};}
test('BFF rejects cross-origin and unauthenticated HR reads without upstream calls',async()=>{
 const old=globalThis.fetch;let calls=0;globalThis.fetch=async()=>{calls++;throw Error();};
 try{
 let res=response();await handler({method:'POST',query:{route:'history'},headers:{host:'nwl.test',origin:'https://foreign.test','content-type':'application/json'},body:{date:'2026-11-09'}},res);assert.equal(res.statusCode,403);
 res=response();await handler({method:'POST',query:{route:'history'},headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json'},body:{date:'2026-11-09'}},res);assert.equal(res.statusCode,401);assert.equal(calls,0);
 }finally{globalThis.fetch=old;}
});

test('one-time proof rejects replay and never retries an uncertain HONO write',async()=>{
 const {default:jpeg}=await import('jpeg-js');
 const image=jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,255)},20).data;
 const account={id:'own-session',company:'psd',employee:'own-id',base:'https://psd.hono.ai/Service/',php:'1',token:'private-token',markKey:'private-key',exp:Date.now()+60000};
 const {dateKey}=await import('./hono.js');
 const proof=JSON.stringify({sid:account.id,hash:hash(image),date:dateKey(),exp:Date.now()+60000,historyHash:hash('[]')});
 process.env.UPSTASH_REDIS_REST_URL='https://ledger.example.test';process.env.UPSTASH_REDIS_REST_TOKEN='test-only';
 let consumed=false,writes=0;const old=globalThis.fetch;
 globalThis.fetch=async(url,options)=>{
   const u=new URL(url);
   if(u.hostname==='ledger.example.test'){
     const command=JSON.parse(options.body);let result;
     if(command[0]==='GET')result=proof;
     else if(command[0]==='EVAL'){result=consumed?0:1;consumed=true;}
     else throw Error('unexpected ledger operation');
     return Response.json({result});
   }
   if(u.pathname.endsWith('checkForAttMethod_v2'))return Response.json({result:true,inTimeFlag:1,showbothinout:0,facial_recog:1});
   if(u.pathname.endsWith('UserVisitFetchRecords_v2'))return Response.json({result:true,data:[]});
   if(u.pathname.endsWith('UserVisitProfileImage')){writes++;throw Error('upstream connection lost');}
   throw Error('unexpected network destination');
 };
 const req={method:'POST',query:{route:'submit'},headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(account)},body:{proof:'ab'.repeat(24),jpeg:image.toString('base64'),lat:18.7,lng:98.9,punch:'I'}};
 try{
   const first=response();await handler(req,first);assert.equal(first.body.code,'unknown');assert.equal(writes,1);
   const replay=response();await handler(req,replay);assert.equal(replay.statusCode,400);assert.equal(writes,1);
   const swapped=response();await handler({...req,body:{...req.body,jpeg:jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,0)},20).data.toString('base64')}},swapped);assert.equal(swapped.statusCode,400);assert.equal(writes,1);
 }finally{globalThis.fetch=old;delete process.env.UPSTASH_REDIS_REST_URL;delete process.env.UPSTASH_REDIS_REST_TOKEN;}
});

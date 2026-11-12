import test from 'node:test';
import assert from 'node:assert/strict';
import {hex,encode,query,validDate,allows,hash,jpegBytes} from './hono.js';
import {seal,open,issueFaceProof,readFaceProof,reserveWrite,finishWrite} from './session.js';
import {validate} from './maps.js';
import handler, {parseApiRoute} from '../api/[route].js';

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
test('face proof is signed, expires, and requires no Redis configuration',()=>{
 for(const k of ['UPSTASH_REDIS_REST_URL','UPSTASH_REDIS_REST_TOKEN','KV_REST_API_URL','KV_REST_API_TOKEN'])delete process.env[k];
 const text=issueFaceProof({sid:'owner',hash:'image',date:'2026-11-09'});
 assert.equal(readFaceProof(text).sid,'owner');
 const [payload,signature]=text.split('.');
 const tampered=Buffer.from(JSON.stringify({...JSON.parse(Buffer.from(payload,'base64url')),sid:'other'})).toString('base64url');
 assert.throws(()=>readFaceProof(tampered+'.'+signature));
 assert.throws(()=>readFaceProof(seal({id:'session',exp:Date.now()+60000})));
 const now=Date.now;
 try{Date.now=()=>now()+60001;assert.throws(()=>readFaceProof(text));}finally{Date.now=now;}
});
test('local account lock blocks parallel captures and allows a fresh proof after confirmed success',()=>{
 const one=readFaceProof(issueFaceProof({sid:'one'})),two=readFaceProof(issueFaceProof({sid:'one'}));
 reserveWrite('local-test-account',one);
 assert.throws(()=>reserveWrite('local-test-account',two));
 finishWrite('local-test-account',one);
 assert.throws(()=>reserveWrite('local-test-account',one));
 reserveWrite('local-test-account',two);finishWrite('local-test-account',two);
});
function response(){return {headers:{},statusCode:0,setHeader(k,v){this.headers[k]=v;},status(c){this.statusCode=c;return this;},json(j){this.body=j;return this;}};}
test('BFF rejects cross-origin and unauthenticated HR reads without upstream calls',async()=>{
 const old=globalThis.fetch;let calls=0;globalThis.fetch=async()=>{calls++;throw Error();};
 try{
 let res=response();await handler({method:'POST',url:'/api/history',headers:{host:'nwl.test',origin:'https://foreign.test','content-type':'application/json'},body:{date:'2026-11-09'}},res);assert.equal(res.statusCode,403);
 res=response();await handler({method:'POST',url:'/api/history',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json'},body:{date:'2026-11-09'}},res);assert.equal(res.statusCode,401);assert.equal(calls,0);
 }finally{globalThis.fetch=old;}
});

test('attendance state returns only valid HONO work areas for the authenticated session',async()=>{
 const account={id:'work-areas-session',company:'psd',employee:'fixture',base:'https://psd.hono.ai/Service/',php:'1',token:'fixture',markKey:'fixture',exp:Date.now()+60000};
 const req={method:'POST',url:'/api/state',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(account)},body:{}};
 const old=globalThis.fetch;
 let rows=[
  {latitude:'13.7',longitude:'100.5',radius:'150',unrelated:'ignored'},
  {latitude:13.8,longitude:100.6,radius:250},
  {latitude:'',longitude:100.5,radius:150},
  {latitude:13.8,longitude:181,radius:200},
  {latitude:13.8,longitude:100.6,radius:0},
 ];
 let requests=0;
 globalThis.fetch=async url=>{
  requests++;
  assert.equal(new URL(url).pathname,'/Service/checkForAttMethod_v2');
  return Response.json({result:true,inTimeFlag:1,facial_recog:1,work_location_lat_long:rows});
 };
 try{
  const verified=response();await handler(req,verified);
  assert.equal(verified.statusCode,200);
  assert.deepEqual(verified.body.work_location_lat_long,[
   {latitude:13.7,longitude:100.5,radius:150},
   {latitude:13.8,longitude:100.6,radius:250},
  ]);
  assert.equal(verified.body.inTimeFlag,1);
  rows=[];
  const empty=response();await handler(req,empty);assert.deepEqual(empty.body.work_location_lat_long,[]);
  rows=undefined;
  const unavailable=response();await handler(req,unavailable);assert.equal(unavailable.body.work_location_lat_long,null);
  const denied=response();await handler({...req,headers:{...req.headers,cookie:''}},denied);
  assert.equal(denied.statusCode,401);
  assert.equal(requests,3);
 }finally{globalThis.fetch=old;}
});

test('verify returns its attendance snapshot while submit rejects a newer history',async()=>{
 const {default:jpeg}=await import('jpeg-js');
 const image=jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,255)},20).data;
 const person='12345678-1234-1234-1234-123456789abc';
 const account={id:'snapshot-session',company:'psd',employee:'own-id',base:'https://psd.hono.ai/Service/',php:'1',token:'fixture',markKey:'fixture',faceKey:'fixture',legacy:true,exp:Date.now()+60000};
 const headers={host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(account)};
 const punches=[{emp_code:account.employee,flag:'I',punch_time:'08:00',status:1}];
 let writes=0;
 const previousFetch=globalThis.fetch;
 globalThis.fetch=async url=>{
  const {pathname}=new URL(url);
  if(pathname.endsWith('getPersonFace_v2'))return Response.json({result:true,FacialEndPoint:'https://fixture.cognitiveservices.azure.com',Facialthreshold:'0.5',PersonID:person,spoof:'0',GroupID:'fixture',FacialSubscription:'fixture'});
  if(pathname.endsWith('/detect'))return Response.json([{faceId:'fixture-face'}]);
  if(pathname.endsWith('/identify'))return Response.json([{faceId:'fixture-face',candidates:[{personId:person,confidence:0.99}]}]);
  if(pathname.endsWith('checkForAttMethod_v2'))return Response.json({result:true,inTimeFlag:1,showbothinout:1,facial_recog:1});
  if(pathname.endsWith('UserVisitFetchRecords_v2'))return Response.json({result:true,data:punches});
  if(pathname.endsWith('UserVisitProfileImage')){writes++;return Response.json({result:true});}
  throw Error('unexpected network destination');
 };
 try{
  const verified=response(),encoded=image.toString('base64');
  await handler({method:'POST',url:'/api/verify',headers,body:{jpeg:encoded}},verified);
  assert.equal(verified.statusCode,200);
  assert.deepEqual(verified.body.attendance,{historyCount:1,checkIn:false,checkOut:true});
  punches.push({emp_code:account.employee,flag:'O',punch_time:'17:30',status:1});
  const submitted=response();
  await handler({method:'POST',url:'/api/submit',headers,body:{proof:verified.body.proof,jpeg:encoded,lat:13.71688,lng:100.52173,punch:'O'}},submitted);
  assert.equal(submitted.statusCode,400);
  assert.match(submitted.body.message,/สถานะเปลี่ยนแล้ว/);
  assert.equal(writes,0);
 }finally{globalThis.fetch=previousFetch;}
});

test('submit forwards a selected HONO area only while it belongs to the account',async()=>{
 const {default:jpeg}=await import('jpeg-js');
 const {dateKey}=await import('./hono.js');
 const image=jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,255)},20).data;
 const account={id:'work-area-submit',company:'psd',employee:'fixture',base:'https://psd.hono.ai/Service/',php:'1',token:'fixture',markKey:'fixture',exp:Date.now()+60000};
 const proof=issueFaceProof({sid:account.id,hash:hash(image),date:dateKey(),historyHash:hash('[]')});
 const headers={host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(account)};
 const body={proof,jpeg:image.toString('base64'),punch:'I',workLocation:true,lat:13.8,lng:100.6};
 const locations=[{latitude:'13.7',longitude:'100.5',radius:'150'}];
 const writes=[];
 const previousFetch=globalThis.fetch;
 globalThis.fetch=async(url,options)=>{
  const {pathname}=new URL(url);
  if(pathname.endsWith('checkForAttMethod_v2'))return Response.json({result:true,inTimeFlag:1,facial_recog:1,work_location_lat_long:locations});
  if(pathname.endsWith('UserVisitFetchRecords_v2'))return Response.json({result:true,data:[]});
  if(pathname.endsWith('UserVisitProfileImage')){
   writes.push([options.body.get('lat'),options.body.get('lng'),options.body.has('workLocation')]);
   return Response.json({result:true});
  }
  throw Error('unexpected network destination');
 };
 try{
  const req={method:'POST',url:'/api/submit',headers,body};
  const removed=response();await handler(req,removed);
  assert.equal(removed.statusCode,409);
  assert.equal(removed.body.code,'work_location_changed');
  assert.equal(writes.length,0);
  locations.push({latitude:'13.8',longitude:'100.6',radius:'250'});
  const allowed=response();await handler(req,allowed);
  assert.equal(allowed.statusCode,200);
  assert.deepEqual(writes,[['13.8','100.6',false]]);
 }finally{globalThis.fetch=previousFetch;}
});

test('local replay protection never retries an uncertain HONO write',async()=>{
 const {default:jpeg}=await import('jpeg-js');
 const image=jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,255)},20).data;
 const account={id:'own-session',company:'psd',employee:'own-id',base:'https://psd.hono.ai/Service/',php:'1',token:'private-token',markKey:'private-key',exp:Date.now()+60000};
 const {dateKey}=await import('./hono.js');
 const proof=issueFaceProof({sid:account.id,hash:hash(image),date:dateKey(),historyHash:hash('[]')});
 let writes=0;const old=globalThis.fetch;
 globalThis.fetch=async(url,options)=>{
   const u=new URL(url);
   if(u.pathname.endsWith('checkForAttMethod_v2'))return Response.json({result:true,inTimeFlag:1,showbothinout:0,facial_recog:1});
   if(u.pathname.endsWith('UserVisitFetchRecords_v2'))return Response.json({result:true,data:[]});
   if(u.pathname.endsWith('UserVisitProfileImage')){writes++;throw Error('upstream connection lost');}
   throw Error('unexpected network destination');
 };
 const req={method:'POST',url:'/api/submit',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json',cookie:'__Host-nwl='+seal(account)},body:{proof,jpeg:image.toString('base64'),lat:18.7,lng:98.9,punch:'I'}};
 try{
   const first=response();await handler(req,first);assert.equal(first.body.code,'unknown');assert.equal(writes,1);
   const replay=response();await handler(req,replay);assert.equal(replay.statusCode,400);assert.equal(writes,1);
   const swapped=response();await handler({...req,body:{...req.body,jpeg:jpeg.encode({width:16,height:16,data:Buffer.alloc(16*16*4,0)},20).data.toString('base64')}},swapped);assert.equal(swapped.statusCode,400);assert.equal(writes,1);
 }finally{globalThis.fetch=old;}
});


test('HONO login rejection is a 401 with privacy-safe correlation rather than bad gateway',async()=>{
 const previousFetch=globalThis.fetch,previousInfo=console.info,previousWarn=console.warn;
 const entries=[];
 process.env.SESSION_SECRET='01'.repeat(32);
 console.info=(line)=>entries.push(String(line));
 console.warn=(line)=>entries.push(String(line));
 globalThis.fetch=async(url,options)=>{
  const path=new URL(url).pathname;
  if(path.endsWith('/getCompanyLogo_ml_v2'))return Response.json({result:true,companycode:'psd',sso:0,mobileTheme:0,phpversion:'0',loginfunction:'UserMaster/login'});
  if(path.endsWith('/dynamicAPIKeys_v2'))return Response.json({result:true,api_keys:{LOGIN:'placeholder-key'}});
  if(options?.method==='POST')return Response.json({result:false});
  throw Error('unexpected request');
 };
 try{
  const res=response();
  await handler({method:'POST',url:'/api/login',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json','user-agent':'Mozilla/5.0 (iPhone; CPU iPhone OS)'},body:{company:'psd',employee:'mock-employee',password:'never-log-this-password'}},res);
  assert.equal(res.statusCode,401);
  assert.equal(res.body.code,'auth_rejected');
  assert.match(res.body.requestId,/^[0-9a-f]{12}$/);
  assert.equal(res.headers['X-Request-ID'],res.body.requestId);
  assert.match(entries.join('\n'),/"stage":"credential_auth"/);
  assert.match(entries.join('\n'),/"platform":"ios"/);
  assert.equal(entries.join('\n').includes('mock-employee'),false);
  assert.equal(entries.join('\n').includes('never-log-this-password'),false);
  assert.equal(entries.join('\n').includes('placeholder-key'),false);
 }finally{globalThis.fetch=previousFetch;console.info=previousInfo;console.warn=previousWarn;}
});

test('upstream credential API outages remain 502 with upstream HTTP status in safe logs',async()=>{
 const previousFetch=globalThis.fetch,previousInfo=console.info,previousWarn=console.warn;
 const entries=[];
 process.env.SESSION_SECRET='01'.repeat(32);
 console.info=(line)=>entries.push(String(line));console.warn=(line)=>entries.push(String(line));
 globalThis.fetch=async(url,options)=>{
  const path=new URL(url).pathname;
  if(path.endsWith('/getCompanyLogo_ml_v2'))return Response.json({result:true,companycode:'psd',sso:0,mobileTheme:0,phpversion:'0',loginfunction:'UserMaster/login'});
  if(path.endsWith('/dynamicAPIKeys_v2'))return Response.json({result:true,api_keys:{LOGIN:'placeholder-key'}});
  if(options?.method==='POST')return Response.json({error:'upstream failure'},{status:503});
  throw Error('unexpected request');
 };
 try{
  const res=response();
  await handler({method:'POST',url:'/api/login',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json'},body:{company:'psd',employee:'mock-employee',password:'never-log-this-password'}},res);
  assert.equal(res.statusCode,502);
  assert.equal(res.body.code,'upstream_http');
  assert.match(entries.join('\n'),/"upstreamStatus":503/);
  assert.match(entries.join('\n'),/"stage":"credential_auth"/);
  assert.equal(entries.join('\n').includes('never-log-this-password'),false);
 }finally{globalThis.fetch=previousFetch;console.info=previousInfo;console.warn=previousWarn;}
});

test('missing session cookie after login is distinguishable from password rejection',async()=>{
 process.env.SESSION_SECRET='01'.repeat(32);
 const res=response();
 await handler({method:'POST',url:'/api/history',headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json'},body:{date:'2026-11-10'}},res);
 assert.equal(res.statusCode,401);
 assert.equal(res.body.code,'session_cookie_missing');
});


test('Vercel-safe logs cover successful API calls and approved browser failures',async()=>{
 const originalInfo=console.info;
 const originalWarn=console.warn;
 const entries=[];
 console.info=(message)=>entries.push(String(message));
 console.warn=(message)=>entries.push(String(message));
 const headers={host:'nwl.test',origin:'https://nwl.test','content-type':'application/json','user-agent':'Mozilla/5.0 (iPhone)'};
 try{
  const done=response();
  await handler({method:'POST',url:'/api/logout',headers,body:{}},done);
  assert.equal(done.statusCode,200);
  const success=JSON.parse(entries.at(-1));
  assert.equal(success.event,'nwl.request');
  assert.equal(success.route,'logout');
  assert.equal(success.code,'ok');
  assert.equal(success.status,200);
  assert.equal(success.platform,'ios');
  assert.match(success.requestId,/^[a-f0-9]{12}$/);

  const browser=response();
  await handler({method:'POST',url:'/api/client-event',headers,body:{targetRoute:'login',kind:'network_failure'}},browser);
  assert.equal(browser.statusCode,202);
  const event=JSON.parse(entries.at(-1));
  assert.equal(event.route,'client-event');
  assert.equal(event.stage,'browser_login');
  assert.equal(event.code,'network_failure');
  assert.equal(event.status,202);

  const unsafe=response();
  await handler({method:'POST',url:'/api/client-event',headers,body:{targetRoute:'login',kind:'password-SECRET-never-log'}},unsafe);
  assert.equal(unsafe.statusCode,400);
  assert.equal(entries.join('\n').includes('password-SECRET-never-log'),false);
  assert.equal(entries.join('\n').includes('iPhone)'),false);
 }finally{console.info=originalInfo;console.warn=originalWarn;}
});

test('WHATWG route selection never evaluates the deprecated Vercel req.query getter',async()=>{
 assert.equal(parseApiRoute('/api/login'),'login');
 assert.equal(parseApiRoute('/api/login?utm=1'),'login');
 for(const path of ['/api/login/','/api/login/../../submit','//evil.test/api/login','https://evil.test/api/login','/api/%6cogin','/unrelated','/api/unknown'])
  assert.equal(parseApiRoute(path),'other',path);
 const res=response();
 const req={
  method:'POST',
  url:'/api/logout',
  get query(){throw new Error('deprecated req.query getter must not be read');},
  headers:{host:'nwl.test',origin:'https://nwl.test','content-type':'application/json'},
  body:{}
 };
 await handler(req,res);
 assert.equal(res.statusCode,200);
 assert.equal(res.body.ok,true);
});

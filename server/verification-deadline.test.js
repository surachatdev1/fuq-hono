import test from 'node:test';
import assert from 'node:assert/strict';
import {withVerificationDeadline} from './verification-deadline.js';
import {request} from './hono.js';
test('face verification can finish before the deadline', async()=>{
 assert.equal(await withVerificationDeadline(async()=>42,100),42);
});
test('verification deadline aborts the active request and rejects late completion',async()=>{
 const original=global.fetch;
 let aborted=false;
 global.fetch=async(_url,{signal})=>new Promise((resolve,reject)=>{
  const hold=setTimeout(()=>resolve(new Response('{}')),1000);
  signal.addEventListener('abort',()=>{aborted=true;clearTimeout(hold);reject(signal.reason);},{once:true});
 });
 try{
  await assert.rejects(withVerificationDeadline(()=>request('https://example.test/face'),10),e=>e.code==='verification_timeout');
  assert.equal(aborted,true);
 }finally{global.fetch=original;}
});
test('all provider stages share one deadline and an expired task cannot start another request',async()=>{
 const original=global.fetch;let calls=0;
 global.fetch=async()=>{calls++;return new Response('{}');};
 try{
  await assert.rejects(withVerificationDeadline(async()=>{
   await request('https://example.test/first');
   await new Promise(r=>setTimeout(r,20));
   await request('https://example.test/second');
  },10),e=>e.code==='verification_timeout');
  assert.equal(calls,1);
 }finally{global.fetch=original;}
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createHmsHandler } from '../api/hms.js';

const host = 'fuq-hono.vercel.app';
const oauth = { SESSION_SECRET: '00'.repeat(32), HMS_OAUTH_CLIENT_ID: 'fixture', VERCEL_ENV: 'production' };
const unreachable = () => { throw Error('Unexpected network call'); };
function browser(handler) {
  const jar = new Map();
  return async function visit(url, method = 'GET') {
    const req = { method, url, headers: { host, cookie: [...jar].map(([k,v]) => k+'='+v).join('; ') } };
    const res = { headers: {}, statusCode: 200, setHeader(k,v) { this.headers[k] = v; }, end(body) { this.body = body; } };
    await handler(req,res);
    for (const cookie of res.headers['Set-Cookie'] || []) {
      const [name, value] = cookie.split(';')[0].split('=');
      if (value) jar.set(name,value); else jar.delete(name);
    }
    return res;
  };
}
test('public /hms uses the employee portal without HONO login, import credentials or attendance requests', async () => {
  const visit = browser(createHmsHandler({},unreachable));
  const page = await visit('/hms');
  assert.match(page.body,/href="https:\/\/hrs.humansoft.co.th\/auth\/login"/);
  assert.match(page.body,/PSDGROUP/); assert.match(page.body,/NWL/);
  assert.doesNotMatch(page.body,/<form|type="password"|\/api\/submit/);
  assert.equal((await visit('/api/hms?start=1')).headers.Location,'https://hrs.humansoft.co.th/auth/login');
  assert.equal((await visit('/api/hms','POST')).statusCode,405);
  assert.equal((await visit('/hms','HEAD')).body,undefined);
  const config = JSON.parse(readFileSync(new URL('../vercel.json',import.meta.url)));
  assert.deepEqual(config.rewrites[0],{ source:'/hms', destination:'/api/hms' });
});
test('registered login confirms userinfo via PKCE, returns a clean URL and keeps tokens off the page', async () => {
  const calls=[];
  const fake = async (url,opts) => { calls.push([url,opts]); return Response.json(url.endsWith('/token') ?
    {access_token:'fixture-access-token',token_type:'Bearer'} : {sub:'fixture-user'}); };
  const visit=browser(createHmsHandler(oauth,fake));
  const start=await visit('/api/hms?start=1');
  const auth=new URL(start.headers.Location);
  assert.equal(auth.origin,'https://auth.humansoft.co.th');
  assert.equal(auth.searchParams.get('instance_server_code'),'PSDGROUP');
  const callback=await visit('/api/hms?code=fixture&state='+auth.searchParams.get('state'));
  assert.equal(callback.headers.Location,'/hms');
  assert.equal(calls.length,2);
  assert.equal(calls[1][1].headers.Authorization,'Bearer fixture-access-token');
  const body=JSON.parse(calls[0][1].body);
  assert.equal(createHash('sha256').update(body.code_verifier).digest('base64url'),auth.searchParams.get('code_challenge'));
  const result=await visit('/hms');
  assert.match(result.body,/HumanSoft ยืนยันการเข้าสู่ระบบแล้ว/);
  assert.doesNotMatch(result.body,/fixture-access-token|fixture-user/);
  await visit('/api/hms?code=fixture&state='+auth.searchParams.get('state'));
  assert.equal(calls.length,2);
});
test('a mismatched state or cancelled sign-in cannot show a successful login',async () => {
  const visit=browser(createHmsHandler(oauth,unreachable));
  await visit('/api/hms?start=1');
  await visit('/api/hms?code=no&state=wrong');
  assert.match((await visit('/hms')).body,/คำขอหมดอายุ/);
  const auth=new URL((await visit('/api/hms?start=1')).headers.Location);
  await visit('/api/hms?error=access_denied&state='+auth.searchParams.get('state'));
  assert.match((await visit('/hms')).body,/ยกเลิกการเข้าสู่ระบบแล้ว/);
});

test('attendance entry opens employee and enrolled-device channels with no provider calls', async () => {
  const visit=browser(createHmsHandler({},unreachable));
  const page=await visit('/hms');
  assert.match(page.body,/href="\/hms\/attendance"/);
  const config=JSON.parse(readFileSync(new URL('../vercel.json',import.meta.url)));
  const route=config.rewrites.find(r=>r.source==='/hms/attendance');
  const attendance=await visit(route.destination);
  assert.match(attendance.body,/href="https:\/\/timeapp.humansoft.co.th\/#\/timeapp\/config"/);
  assert.match(attendance.body,/href="https:\/\/line.me\/R\/ti\/p\/@app.humansoft"/);
  assert.match(attendance.body,/ขึ้นทะเบียน/);
  assert.doesNotMatch(attendance.body,/<form|\/api\/submit|ลงเวลาสำเร็จ/);
});

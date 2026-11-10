import {randomBytes} from 'node:crypto';
import jpeg from 'jpeg-js';
import {PNG} from 'pngjs';
import * as hono from '../server/hono.js';
import {session,cookie,issueFaceProof,readFaceProof,reserveWrite,finishWrite,requireSessionConfig} from '../server/session.js';
import {resolve} from '../server/maps.js';
export const config={maxDuration:60};
// Temporary preview-only diagnostic. Identify the calling module rather than
// suppressing Node.js's DEP0169 warning. Remove after investigation.
process.on('warning', warning => {
  if (warning.code === 'DEP0169') {
    const frames = String(warning.stack ?? '').split('\n').slice(0, 15);
    console.warn(JSON.stringify({event:'nwl.deprecation.trace',code:'DEP0169',frames}));
  }
});
let clientLogMinute=0,clientLogCount=0;
export default async function handler(req,res){
 const requestId=randomBytes(6).toString('hex');
 const started=Date.now();
 const path=typeof req.query?.route==='string'?req.query.route:'unknown';
 const route=['login','logout','history','calendar','state','maps','enrollment','verify','submit','client-event'].includes(path)?path:'other';
 let stage=route==='login'?'validation':route;
 const ua=String(req.headers?.['user-agent']??'');
 const platform=/iPhone|iPad|iPod/i.test(ua)?'ios':/Android/i.test(ua)?'android':/Windows|Macintosh|Linux/i.test(ua)?'desktop':'unknown';
 // Structured diagnostic metadata only: no employee IDs, passwords, tokens,
 // cookies, IPs, photos, request bodies, or raw HONO responses.
 function audit(status,code,upstreamStatus=null){
  const event={event:'nwl.request',requestId,route,stage,status,code,elapsedMs:Date.now()-started,platform};
  if(Number.isInteger(upstreamStatus))event.upstreamStatus=upstreamStatus;
  const line=JSON.stringify(event);
  if(status>=500)console.warn(line);else console.info(line);
 }
 function ok(body){audit(200,'ok');return res.status(200).json(body);}
 res.setHeader('Cache-Control','no-store, max-age=0');
 res.setHeader('X-Content-Type-Options','nosniff');
 res.setHeader('X-Request-ID',requestId);
 try{
 if(req.method!=='POST')throw new hono.Failure('Method not allowed',405);
 const origin=req.headers.origin,host=req.headers.host;
 if(!origin||new URL(origin).protocol!=='https:'||new URL(origin).host!==host)throw new hono.Failure('คำขอไม่ถูกต้อง',403);
 if(!String(req.headers['content-type']??'').startsWith('application/json'))throw new hono.Failure('Content type ไม่ถูกต้อง',415);
 const b=typeof req.body==='string'?JSON.parse(req.body):req.body;
 if(!b||Array.isArray(b)||JSON.stringify(b).length>2100000)throw new hono.Failure('ข้อมูลเกินขนาด',413);
 const route=req.query.route;
 if(route==='client-event'){
  // Browser-side transport failures may never reach /api/login; log only an
  // allowlisted category and route, never an untrusted error string or URL.
  if(JSON.stringify(b).length>256)throw new hono.Failure('Invalid diagnostics payload',413,'client_event_too_large');
  const targetRoute=b.targetRoute,kind=b.kind;
  if(!['login','logout','history','calendar','state','maps','enrollment','verify','submit'].includes(targetRoute)||
     !['network_failure','timeout','invalid_response'].includes(kind))
   throw new hono.Failure('Invalid diagnostics category',400,'client_event_invalid');
  // Best effort per-instance cap; the endpoint is not for unrestricted analytics.
  const minute=Math.floor(Date.now()/60000);
  if(clientLogMinute!==minute){clientLogMinute=minute;clientLogCount=0;}
  if(clientLogCount++<60){stage='browser_'+targetRoute;audit(202,kind);}
  return res.status(202).json({ok:true});
 }
 if(route==='login'){
 requireSessionConfig();
 const s=await hono.login(String(b.company??'').trim(),String(b.employee??'').trim(),String(b.password??''),next=>{stage=next;});cookie(res,s);
 stage='complete';
 return ok({company:s.company,employee:s.employee,name:s.name});
 }
 if(route==='logout'){cookie(res,null);return ok({ok:true});}
 const s=session(req);
 if(route==='history')return ok(await hono.history(s,b.date));
 if(route==='calendar')return ok(await hono.calendar(s,b.date));
 if(route==='state')return ok(await hono.state(s));
 if(route==='maps')return ok({url:await resolve(b.url)});
 if(route==='enrollment'){await hono.enrollment(s);return ok({ok:true});}
 if(route==='verify'){
 const bytes=hono.jpegBytes(b.jpeg);
 try{
 const decoded=jpeg.decode(bytes,{useTArray:true,maxResolutionInMP:2,maxMemoryUsageInMB:48});if(decoded.width>1280||decoded.height>1280)throw new hono.Failure('ภาพใหญ่เกินกำหนด');
 const e=await hono.enrollment(s);await hono.verify(e,bytes);
 const [state,history]=await Promise.all([hono.state(s),hono.history(s,hono.dateKey())]);
 const proof=issueFaceProof({sid:s.id,hash:hono.hash(bytes),date:hono.dateKey(),historyHash:hono.hash(JSON.stringify(history.data))});
 return ok({proof});
 }finally{bytes.fill(0);}
 }
 if(route==='submit'){
 if(!['I','O'].includes(b.punch)||typeof b.lat!=='number'||typeof b.lng!=='number'||!Number.isFinite(b.lat)||!Number.isFinite(b.lng)||Math.abs(b.lat)>90||Math.abs(b.lng)>180)throw new hono.Failure('ข้อมูลลงเวลาไม่ถูกต้อง');
 const bytes=hono.jpegBytes(b.jpeg);
 try{
 const proof=readFaceProof(b.proof);if(proof.sid!==s.id||proof.hash!==hono.hash(bytes)||proof.date!==hono.dateKey())throw new hono.Failure('ผลสแกนไม่ตรงกับภาพหรือหมดอายุ');
 const decoded=jpeg.decode(bytes,{useTArray:true,maxResolutionInMP:2,maxMemoryUsageInMB:48});if(decoded.width>1280||decoded.height>1280)throw new hono.Failure('ภาพใหญ่เกินกำหนด');
 const [state,history]=await Promise.all([hono.state(s),hono.history(s,hono.dateKey())]);
 if(Number(state.facial_recog)!==1||!hono.allows(state,history.data,b.punch)||proof.historyHash!==hono.hash(JSON.stringify(history.data)))throw new hono.Failure('สถานะเปลี่ยนแล้ว กรุณาตรวจประวัติและสแกนใหม่');
 const account=hono.hash(s.company+':'+s.employee);
 reserveWrite(account,proof);
 const png=PNG.sync.write({width:decoded.width,height:decoded.height,data:Buffer.from(decoded.data)});
 try{await hono.submit(s,b.lat,b.lng,b.punch,png);finishWrite(account,proof);}
 catch(e){if(e instanceof hono.Failure&&e.code!=='unknown')finishWrite(account,proof);throw e;}
 finally{png.fill(0);decoded.data.fill(0);}
 return ok({ok:true});
 }finally{bytes.fill(0);}
 }
 throw new hono.Failure('ไม่พบรายการที่ร้องขอ',404);
 }catch(e){
  const known=e instanceof hono.Failure;
  const status=known?e.status:502,code=known?e.code:'internal_error';
  audit(status,code,known?e.upstreamStatus:null);
  res.status(status).json({message:known?e.message:'เชื่อมต่อระบบไม่สำเร็จ กรุณาลองใหม่',code,requestId});
 }
}

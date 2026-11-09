import {randomBytes} from 'node:crypto';
import jpeg from 'jpeg-js';
import {PNG} from 'pngjs';
import * as hono from '../server/hono.js';
import {session,cookie,redis,requireLedger,requireSessionConfig} from '../server/session.js';
import {resolve} from '../server/maps.js';
export const config={maxDuration:60};
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store, max-age=0');res.setHeader('X-Content-Type-Options','nosniff');
 try{
 if(req.method!=='POST')throw new hono.Failure('Method not allowed',405);
 const origin=req.headers.origin,host=req.headers.host;
 if(!origin||new URL(origin).protocol!=='https:'||new URL(origin).host!==host)throw new hono.Failure('คำขอไม่ถูกต้อง',403);
 if(!String(req.headers['content-type']??'').startsWith('application/json'))throw new hono.Failure('Content type ไม่ถูกต้อง',415);
 const b=typeof req.body==='string'?JSON.parse(req.body):req.body;
 if(!b||Array.isArray(b)||JSON.stringify(b).length>2100000)throw new hono.Failure('ข้อมูลเกินขนาด',413);
 const route=req.query.route;
 if(route==='login'){
 requireSessionConfig();
 const s=await hono.login(String(b.company??'').trim(),String(b.employee??'').trim(),String(b.password??''));cookie(res,s);
 return res.status(200).json({company:s.company,employee:s.employee,name:s.name});
 }
 if(route==='logout'){cookie(res,null);return res.status(200).json({ok:true});}
 const s=session(req);
 if(route==='history')return res.status(200).json(await hono.history(s,b.date));
 if(route==='calendar')return res.status(200).json(await hono.calendar(s,b.date));
 if(route==='state')return res.status(200).json(await hono.state(s));
 if(route==='maps')return res.status(200).json({url:await resolve(b.url)});
 if(route==='enrollment'){requireLedger();await hono.enrollment(s);return res.status(200).json({ok:true});}
 if(route==='verify'){
 requireLedger();
 const bytes=hono.jpegBytes(b.jpeg);
 try{
 const decoded=jpeg.decode(bytes,{useTArray:true,maxResolutionInMP:2,maxMemoryUsageInMB:48});if(decoded.width>1280||decoded.height>1280)throw new hono.Failure('ภาพใหญ่เกินกำหนด');
 const e=await hono.enrollment(s);await hono.verify(e,bytes);
 const [state,history]=await Promise.all([hono.state(s),hono.history(s,hono.dateKey())]);
 const proof=randomBytes(24).toString('hex'),data=JSON.stringify({sid:s.id,hash:hono.hash(bytes),date:hono.dateKey(),exp:Date.now()+60000,historyHash:hono.hash(JSON.stringify(history.data))});
 await redis(['SET','nwl:proof:'+proof,data,'EX','60','NX']);return res.status(200).json({proof});
 }finally{bytes.fill(0);}
 }
 if(route==='submit'){
 requireLedger();
 if(!/^[a-f0-9]{48}$/.test(b.proof??'')||!['I','O'].includes(b.punch)||typeof b.lat!=='number'||typeof b.lng!=='number'||!Number.isFinite(b.lat)||!Number.isFinite(b.lng)||Math.abs(b.lat)>90||Math.abs(b.lng)>180)throw new hono.Failure('ข้อมูลลงเวลาไม่ถูกต้อง');
 const bytes=hono.jpegBytes(b.jpeg);
 try{
 const raw=await redis(['GET','nwl:proof:'+b.proof]);if(!raw)throw new hono.Failure('ผลสแกนหมดอายุ กรุณาสแกนใหม่');
 const proof=JSON.parse(raw);if(proof.sid!==s.id||proof.hash!==hono.hash(bytes)||proof.date!==hono.dateKey()||proof.exp<Date.now())throw new hono.Failure('ผลสแกนไม่ตรงกับภาพหรือหมดอายุ');
 const decoded=jpeg.decode(bytes,{useTArray:true,maxResolutionInMP:2,maxMemoryUsageInMB:48});if(decoded.width>1280||decoded.height>1280)throw new hono.Failure('ภาพใหญ่เกินกำหนด');
 const [state,history]=await Promise.all([hono.state(s),hono.history(s,hono.dateKey())]);
 if(Number(state.facial_recog)!==1||!hono.allows(state,history.data,b.punch)||proof.historyHash!==hono.hash(JSON.stringify(history.data)))throw new hono.Failure('สถานะเปลี่ยนแล้ว กรุณาตรวจประวัติและสแกนใหม่');
 // Atomic single-use proof consumption and per-account cross-instance lock.
 const accepted=await redis(['EVAL',"if redis.call('GET',KEYS[1]) ~= ARGV[1] then return 0 end; if not redis.call('SET',KEYS[2],'1','NX','EX',90) then return 0 end; redis.call('DEL',KEYS[1]); return 1",'2','nwl:proof:'+b.proof,'nwl:write:'+hono.hash(s.company+':'+s.employee),raw]);
 if(accepted!==1)throw new hono.Failure('รายการกำลังส่งหรือใช้ผลสแกนนี้แล้ว กรุณาตรวจประวัติ');
 const png=PNG.sync.write({width:decoded.width,height:decoded.height,data:Buffer.from(decoded.data)});
 try{await hono.submit(s,b.lat,b.lng,b.punch,png);}finally{png.fill(0);decoded.data.fill(0);}
 return res.status(200).json({ok:true});
 }finally{bytes.fill(0);}
 }
 throw new hono.Failure('ไม่พบรายการที่ร้องขอ',404);
 }catch(e){const known=e instanceof hono.Failure;res.status(known?e.status:502).json({message:known?e.message:'เชื่อมต่อระบบไม่สำเร็จ กรุณาลองใหม่',code:known?e.code:'upstream'});}
}

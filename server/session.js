import {createCipheriv,createDecipheriv,createHmac,randomBytes,timingSafeEqual} from 'node:crypto';
import {Failure} from './hono.js';
function key(){const k=Buffer.from(process.env.SESSION_SECRET??'','hex');if(k.length!==32)throw new Failure('ยังไม่ได้ตั้งค่าบริการ session ของเว็บ',503);return k;}
export function requireSessionConfig(){ key(); }
export function seal(s){const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',key(),iv);const body=Buffer.concat([c.update(JSON.stringify(s)),c.final()]);return Buffer.concat([iv,c.getAuthTag(),body]).toString('base64url');}
export function open(cookie){try{const b=Buffer.from(cookie??'','base64url');if(b.length>4000||b.length<29)throw Error();const d=createDecipheriv('aes-256-gcm',key(),b.subarray(0,12));d.setAuthTag(b.subarray(12,28));const s=JSON.parse(Buffer.concat([d.update(b.subarray(28)),d.final()]).toString());if(!s.id||s.exp<Date.now())throw Error();return s;}catch{throw new Failure('session หมดอายุ กรุณาเข้าสู่ระบบใหม่',401,'session_invalid');}}
export function session(req){const match=(req.headers.cookie??'').match(/(?:^|;\s*)__Host-nwl=([^;]+)/);if(!match)throw new Failure('ไม่พบ session ของเว็บ กรุณาเข้าสู่ระบบใหม่และอนุญาตคุกกี้ของเว็บไซต์',401,'session_cookie_missing');return open(match[1]);}
export function cookie(res,s){res.setHeader('Set-Cookie',`__Host-nwl=${s?seal(s):''}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${s?28800:0}`);}
const signature=payload=>createHmac('sha256',key()).update('nwl-face-proof-v1.').update(payload).digest();
export function issueFaceProof(data){
 const payload=Buffer.from(JSON.stringify({...data,id:randomBytes(24).toString('hex'),exp:Date.now()+60000})).toString('base64url');
 return payload+'.'+signature(payload).toString('base64url');
}
export function readFaceProof(text){
 try{
  if(typeof text!=='string'||text.length>2048||!/^[-_A-Za-z0-9]+\.[-_A-Za-z0-9]+$/.test(text))throw Error();
  const [payload,tag]=text.split('.'),actual=Buffer.from(tag,'base64url'),expected=signature(payload);
  if(actual.length!==expected.length||!timingSafeEqual(actual,expected))throw Error();
  const p=JSON.parse(Buffer.from(payload,'base64url').toString());
  if(!/^[a-f0-9]{48}$/.test(p.id)||!Number.isFinite(p.exp)||p.exp<=Date.now())throw Error();
  return p;
 }catch{throw new Failure('ผลสแกนหมดอายุหรือไม่ถูกต้อง กรุณาสแกนใหม่');}
}
// Best-effort duplicate protection within this process only. Serverless instances
// do not share these maps; the fresh HONO history check remains mandatory.
const usedProofs=new Map(),accountLocks=new Map();
export function reserveWrite(account,proof){
 const now=Date.now();
 if(proof.exp<=now)throw new Failure('ผลสแกนหมดอายุ กรุณาสแกนใหม่');
 for(const [id,expiry]of usedProofs)if(expiry<=now)usedProofs.delete(id);
 for(const [id,lock]of accountLocks)if(lock.exp<=now)accountLocks.delete(id);
 if(usedProofs.has(proof.id)||accountLocks.has(account))throw new Failure('รายการกำลังส่งหรือใช้ผลสแกนนี้แล้ว กรุณาตรวจประวัติ');
 if(usedProofs.size>=4096||accountLocks.size>=4096)throw new Failure('ระบบกำลังทำรายการจำนวนมาก กรุณาลองใหม่',503);
 usedProofs.set(proof.id,proof.exp);
 accountLocks.set(account,{id:proof.id,exp:now+90000});
}
export function finishWrite(account,proof){
 if(accountLocks.get(account)?.id===proof.id)accountLocks.delete(account);
}

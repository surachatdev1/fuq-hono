import {createCipheriv,createDecipheriv,randomBytes} from 'node:crypto';
import {Failure} from './hono.js';
function key(){const k=Buffer.from(process.env.SESSION_SECRET??'','hex');if(k.length!==32)throw new Failure('ยังไม่ได้ตั้งค่าบริการ session ของเว็บ',503);return k;}
export function requireSessionConfig(){ key(); }
export function seal(s){const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',key(),iv);const body=Buffer.concat([c.update(JSON.stringify(s)),c.final()]);return Buffer.concat([iv,c.getAuthTag(),body]).toString('base64url');}
export function open(cookie){try{const b=Buffer.from(cookie??'','base64url');if(b.length>4000||b.length<29)throw Error();const d=createDecipheriv('aes-256-gcm',key(),b.subarray(0,12));d.setAuthTag(b.subarray(12,28));const s=JSON.parse(Buffer.concat([d.update(b.subarray(28)),d.final()]).toString());if(!s.id||s.exp<Date.now())throw Error();return s;}catch{throw new Failure('session หมดอายุ กรุณาเข้าสู่ระบบใหม่',401);}}
export function session(req){const match=(req.headers.cookie??'').match(/(?:^|;\s*)__Host-nwl=([^;]+)/);return open(match?.[1]);}
export function cookie(res,s){res.setHeader('Set-Cookie',`__Host-nwl=${s?seal(s):''}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${s?28800:0}`);}
function ledgerConfig(){
 const explicit=process.env.UPSTASH_REDIS_REST_URL||process.env.UPSTASH_REDIS_REST_TOKEN;
 const url=explicit?process.env.UPSTASH_REDIS_REST_URL:process.env.KV_REST_API_URL;
 const token=explicit?process.env.UPSTASH_REDIS_REST_TOKEN:process.env.KV_REST_API_TOKEN;
 if(!url||!token)throw new Failure('การลงเวลาบนเว็บยังไม่พร้อม: ต้องเชื่อม Redis ก่อน',503);
 return {url,token};
}
export async function redis(command){
 const {url,token}=ledgerConfig();
 const u=new URL(url);if(u.protocol!=='https:')throw new Failure('ที่เก็บ session ไม่พร้อม',503);
 const r=await fetch(u,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(command),signal:AbortSignal.timeout(8000)});
 const j=await r.json();if(!r.ok||j.error)throw new Failure('ที่เก็บ session ไม่พร้อม กรุณาลองใหม่',503);return j.result;
}
export function requireLedger(){ ledgerConfig(); }

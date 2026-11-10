import {Failure} from './hono.js';
const hosts=new Set(['google.com','www.google.com','maps.google.com','google.co.th','www.google.co.th','maps.google.co.th','maps.app.goo.gl','goo.gl']);
export function validate(input){const u=new URL(input);if(u.protocol!=='https:'||u.port||u.username||u.password||!hosts.has(u.hostname)||!(u.hostname==='maps.app.goo.gl'||u.hostname.startsWith('maps.google.')||u.pathname==='/maps'||u.pathname.startsWith('/maps/')))throw new Failure('ใช้ลิงก์ HTTPS จาก Google Maps เท่านั้น');return u;}
const number='([+-]?\\d+(?:\\.\\d+)?)';
const pair=new RegExp(`^\\s*${number}\\s*,\\s*${number}\\s*$`);
export function hasCoordinates(u){
 let text;try{text=decodeURIComponent(u.href);}catch{return false;}
 const candidates=['query','q','destination','ll'].map(k=>pair.exec(u.searchParams.get(k)??''));
 candidates.push(new RegExp(`!3d${number}!4d${number}`).exec(text),new RegExp(`@${number},${number}(?:,|/|$)`).exec(text));
 return candidates.some(m=>m&&Math.abs(Number(m[1]))<=90&&Math.abs(Number(m[2]))<=180);
}
const clean=s=>s.replace(/&amp;|&#38;|&#x26;/g,'&').replace(/&quot;/g,'"');
export function pageDestination(html){
 const candidates=[], centers=[];
 for(const tag of html.match(/<(?:link|meta)\b[^>]*>/gi)??[]){
  const a=Object.fromEntries([...tag.matchAll(/([\w-]+)\s*=\s*(["'])(.*?)\2/gs)].map(m=>[m[1].toLowerCase(),m[3]]));
  if(a.rel?.toLowerCase()==='canonical'&&a.href)candidates.push(a.href);
  if(a.property?.toLowerCase()==='og:url'&&a.content)candidates.push(a.content);
  if(a.property?.toLowerCase()==='og:image'&&a.content){
   try{
    const image=new URL(clean(a.content));
    if(image.protocol==='https:'&&['maps.googleapis.com','maps.google.com','www.google.com'].includes(image.hostname)){
     const center=image.searchParams.get('center');
     if(pair.test(center??''))centers.push(new URL('https://www.google.com/maps?ll='+encodeURIComponent(center)));
    }
   }catch{}
  }
 }
 // Maps sometimes serves an app-opening HTML page instead of an HTTP redirect.
 for(const m of html.matchAll(/https:\/\/(?:maps\.google\.com|www\.google\.com|google\.com)\/[^\s<>"']+/g))candidates.push(m[0]);
 const valid=candidates.flatMap(s=>{try{return [validate(clean(s))];}catch{return [];}});
 return (valid.find(hasCoordinates)??centers.find(hasCoordinates)??valid[0])?.href;
}
export async function resolve(input,{fetcher=fetch}={}){
 let u=validate(input);const seen=new Set();const signal=AbortSignal.timeout(25000);
 for(let n=0;n<6;n++){
  if(seen.has(u.href))throw new Failure('อ่านหมุดจากลิงก์นี้ไม่ได้ กรุณาคัดลอกลิงก์หมุดแบบเต็ม');seen.add(u.href);
  const nested=u.searchParams.get('link')??u.searchParams.get('deep_link_id');
  if(nested){u=validate(nested);continue;}
  if(hasCoordinates(u))return u.href;
  let r;try{r=await fetcher(u,{redirect:'manual',signal});}catch{throw new Failure('Google Maps ตอบกลับช้า กรุณาลองใหม่หรือใช้ลิงก์หมุดแบบเต็ม');}
  let next;
  if(r.status>=300&&r.status<400){next=r.headers.get('location');await r.body?.cancel();}
  else{
   if(r.status!==200){await r.body?.cancel();throw new Failure('เปิด Maps ไม่สำเร็จ กรุณาใช้ลิงก์หมุดแบบเต็ม');}
   let size=0,parts=[];for await(const part of r.body){size+=part.length;if(size>2000000)throw new Failure('หน้า Maps ใหญ่เกินกำหนด ใช้ลิงก์หมุดแบบเต็ม');parts.push(part);}
   next=pageDestination(Buffer.concat(parts).toString());
  }
  if(!next)throw new Failure('ลิงก์นี้ไม่มีพิกัด กรุณาแชร์หมุดจาก Google Maps หรือคัดลอกละติจูด, ลองจิจูด');
  u=validate(new URL(next,u).href);
 }
 throw new Failure('ลิงก์เปลี่ยนเส้นทางหลายครั้ง กรุณาใช้ลิงก์หมุดแบบเต็ม');
}

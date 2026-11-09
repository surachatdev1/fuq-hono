import {Failure} from './hono.js';
const hosts=new Set(['google.com','www.google.com','maps.google.com','google.co.th','www.google.co.th','maps.google.co.th','maps.app.goo.gl','goo.gl']);
export function validate(input){const u=new URL(input);if(u.protocol!=='https:'||u.port||u.username||u.password||!hosts.has(u.hostname)||!(u.hostname==='maps.app.goo.gl'||u.hostname.startsWith('maps.google.')||u.pathname==='/maps'||u.pathname.startsWith('/maps/')))throw new Failure('ใช้ลิงก์ HTTPS จาก Google Maps เท่านั้น');return u;}
const coordinate=u=>/[!@]3?d?[+-]?\d/.test(decodeURIComponent(u.href))||['q','query','destination','ll'].some(k=>/^\s*[+-]?\d+(?:\.\d+)?\s*,\s*[+-]?\d+(?:\.\d+)?\s*$/.test(u.searchParams.get(k)??''));
export async function resolve(input){let u=validate(input);const seen=new Set();for(let n=0;n<6;n++){
 if(coordinate(u))return u.href;if(seen.has(u.href))throw new Failure('ลิงก์สั้นวนซ้ำ');seen.add(u.href);
 const r=await fetch(u,{redirect:'manual',signal:AbortSignal.timeout(12000)});let next;
 if(r.status>=300&&r.status<400){next=r.headers.get('location');await r.body?.cancel();}else{
 if(r.status!==200)throw new Failure('เปิด Maps ไม่สำเร็จ กรุณาใช้ลิงก์เต็ม');
 let size=0,parts=[];for await(const part of r.body){size+=part.length;if(size>1000000)throw new Failure('หน้า Maps ใหญ่เกินกำหนด ใช้ลิงก์เต็ม');parts.push(part);}
 const html=Buffer.concat(parts).toString();
 for(const tag of html.match(/<(?:link|meta)\b[^>]*>/gi)??[]){const attrs=Object.fromEntries([...tag.matchAll(/([\w-]+)\s*=\s*(["'])(.*?)\2/gs)].map(m=>[m[1].toLowerCase(),m[3]]));const candidate=attrs.rel?.toLowerCase()==='canonical'?attrs.href:attrs.property?.toLowerCase()==='og:url'?attrs.content:null;if(candidate){try{next=validate(candidate.replace(/&amp;|&#38;|&#x26;/g,'&')).href;break;}catch{}}}
 }
 if(!next)throw new Failure('อ่านหมุดไม่ได้ กรุณาใช้ลิงก์เต็ม');u=validate(new URL(next,u).href);
 }throw new Failure('ลิงก์เปลี่ยนเส้นทางหลายครั้ง');}

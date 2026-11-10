import {createCipheriv, randomBytes, createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const material=JSON.parse(readFileSync(new URL('../assets/hono_client_protocol.json',import.meta.url),'utf8'));
export class Failure extends Error { constructor(message,status=400,code='invalid',upstreamStatus=null){super(message);this.status=status;this.code=code;this.upstreamStatus=upstreamStatus;} }
export const value=(j,k)=>String(j?.[k]??'').trim();
export const truth=x=>String(x).toLowerCase()==='true';
export const integer=x=>/^[+-]?\d+$/.test(String(x??'').trim())?Number(x):null;
export function requireResult(j){if(!truth(j?.result))throw new Failure('HONO ปฏิเสธรายการ กรุณาตรวจบัญชีและสิทธิ์',502,'upstream_rejected');return j;}
export function hex(text){const input=Buffer.from(text+' '.repeat(16-text.length%16));if(input.length%16)throw new Failure('ข้อความไม่รองรับโปรโตคอลเดิม');const cipher=createCipheriv('aes-128-cbc',Buffer.from(material.key),Buffer.from(material.iv));cipher.setAutoPadding(false);return Buffer.concat([cipher.update(input),cipher.final()]).toString('hex');}
export function encode(text,php){return php==='1'?randomBytes(3).toString('hex').slice(0,3)+Buffer.from(text).toString('base64')+randomBytes(3).toString('hex').slice(0,3):hex(text);}
export const query=(url,fields)=>url+'?'+Object.entries(fields).map(([k,v])=>encodeURIComponent(k)+'='+encodeURIComponent(v)).join('&');
export async function request(url,options={}){
  let res;
  try{
    res=await fetch(url,{...options,redirect:'error',signal:AbortSignal.timeout(28000)});
  }catch(e){
    const timedOut=e?.name==='TimeoutError'||e?.name==='AbortError';
    throw new Failure(timedOut?'ระบบ HONO ตอบกลับช้าเกินไป กรุณาลองอีกครั้ง':'เชื่อมต่อระบบ HONO ไม่สำเร็จ กรุณาลองอีกครั้ง',timedOut?504:502,timedOut?'upstream_timeout':'upstream_network');
  }
  if(res.status!==200)throw new Failure('ระบบ HONO ตอบกลับไม่สำเร็จ กรุณาลองอีกครั้ง',502,'upstream_http',res.status);
  let size=0;const chunks=[];
  try{
    for await(const part of res.body){
      size+=part.length;
      if(size>2000000){await res.body.cancel().catch(()=>{});throw new Failure('ข้อมูลตอบกลับเกินขนาด',502,'upstream_too_large');}
      chunks.push(part);
    }
  }catch(e){
    if(e instanceof Failure)throw e;
    throw new Failure('อ่านข้อมูลจากระบบ HONO ไม่สำเร็จ',502,'upstream_stream');
  }
  try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}
  catch{throw new Failure('รูปแบบข้อมูลจากระบบ HONO ไม่ถูกต้อง',502,'upstream_json');}
}
const post=(url,data,headers={})=>request(url,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify(data)});
export const get=async(url,fields,php,bootstrap=false)=>request(url+'?'+new URLSearchParams({encryption_key:bootstrap?hex(query(url,fields)):encode(query(url,fields),php),type:'android'}));
const common=s=>({comp_code:s.company,api_key:s.markKey,userid:s.employee,token:s.token});
export async function login(company,employee,password,onStage=()=>{}){
  if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(company)||!employee||employee.length>128||!password||password.length>256)throw new Failure('กรอกรหัสบริษัท รหัสพนักงาน และรหัสผ่าน');
  onStage('company_lookup');
  const c=requireResult(await get('https://api.honohr.com/sapi/Service/getCompanyLogo_ml_v2',{comp_code:company,version:'35'},'0',true));
  onStage('company_policy');
  if(Number(c.sso||0)!==0)throw new Failure('บริษัทนี้ใช้ SSO กรุณาใช้ HONO เดิม',403,'sso_required');
  const comp=value(c,'companycode');if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(comp))throw new Failure('รหัสบริษัทไม่ถูกต้อง');
  const domain=Number(c.mobileTheme)===1?value(c,'domain_name'):'honohr.com/sapi/';
  if(/[?#@\\]/.test(domain))throw new Failure('โดเมนบริษัทไม่รองรับ');
  const base=`https://${comp}.${domain}Service/`,u=new URL(base),php=value(c,'phpversion'),fn=value(c,'loginfunction');
  if(u.protocol!=='https:'||u.port||u.username||u.password||!['.hono.ai','.honohr.com'].some(x=>u.hostname.endsWith(x))||!/^[A-Za-z0-9_/-]+$/.test(fn)||fn.startsWith('/')||fn.includes('..'))throw new Failure('โดเมนหรือวิธีเข้าสู่ระบบไม่รองรับ');
  onStage('api_keys');
  const keys=requireResult(await get(base+'dynamicAPIKeys_v2',{comp_code:comp,api_key:material.bootstrap_key},php)).api_keys;
  if(!value(keys,'LOGIN'))throw new Failure('ไม่พบสิทธิ์เข้าสู่ระบบ',403,'login_key_missing');
  const endpoint=base+fn;
  onStage('credential_auth');
  const raw=await post(endpoint,{type:'android',encryption_key:encode(query(endpoint,{comp_code:comp,api_key:value(keys,'LOGIN'),userid:employee,pass:php==='1'?password:hex(password),iemi_no:randomBytes(16).toString('hex'),lang_id:'1'}),php)});
  if(raw?.result===false||String(raw?.result).toLowerCase()==='false')throw new Failure('HONO ปฏิเสธการเข้าสู่ระบบ กรุณาตรวจบัญชี รหัสผ่าน หรือสิทธิ์กับผู้ดูแล',401,'auth_rejected');
  if(!truth(raw?.result))throw new Failure('HONO ตอบข้อมูลการเข้าสู่ระบบไม่ครบ กรุณาลองใหม่',502,'auth_response_invalid');
  onStage('account_policy');
  if(Number(raw.authmfa||0)!==0)throw new Failure('บัญชีต้องยืนยัน MFA ผ่าน HONO เดิม',403,'mfa_required');
  if(['ResetPasswordFlag','COCFlagV2'].some(k=>value(raw,k)==='1'||truth(raw[k])))throw new Failure('โปรดยืนยันเงื่อนไขหรือเปลี่ยนรหัสผ่านใน HONO เดิม',403,'account_action_required');
  if(!value(raw,'tokenID')||value(raw,'tokenID')==='null'||!value(raw,'Usercode')||value(raw,'Usercode')==='null'||(Number(c.mobileTheme)===1&&raw.rolecheck==null))throw new Failure('ข้อมูล session ไม่ครบ',502,'auth_session_incomplete');
  return {id:randomBytes(24).toString('hex'),base,company:comp,php,employee:value(raw,'Usercode'),name:value(raw,'Username')||value(raw,'Usercode'),token:value(raw,'tokenID'),markKey:value(keys,'MARKIN_MARKOUT'),faceKey:value(keys,'FACIAL_RECOG'),calendarKey:value(keys,'CALENDAR'),legacy:Number(c.honoapp_facial)===0,exp:Date.now()+8*3600000};
}
export function dateKey(date=new Date()){return new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Bangkok',year:'numeric',month:'2-digit',day:'2-digit'}).format(date);}
export function validDate(date){if(typeof date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(date)||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)throw new Failure('วันที่ไม่ถูกต้อง');return date;}
export async function history(s,date){
  const j=await get(s.base+'UserVisitFetchRecords_v2',{...common(s),punchdate:validDate(date),mngr_code:s.employee},s.php);
  if(!truth(j.result)){
    const message=['error','message','msg'].map(k=>value(j,k)).join(' ').toLowerCase();
    if((j.data==null||(Array.isArray(j.data)&&!j.data.length))&&!/token|session|auth|permission|unauthori|forbidden|expired|สิทธิ|หมดอายุ/.test(message)&&/no\s+(?:data|records?)\b|(?:data|records?)\s+not\s+found|ไม่พบข้อมูล|ไม่มีรายการ/.test(message))return {result:true,data:[]};
    throw new Failure('HONO ไม่คืนประวัติของวันที่เลือก กรุณาโหลดใหม่หรือตรวจสิทธิ์',502);
  }
  if(!Array.isArray(j.data)||j.data.some(r=>value(r,'emp_code')!==s.employee||!value(r,'punch_time')))throw new Failure('รายการไม่ตรงกับบัญชีที่เข้าสู่ระบบ',502);
  return {result:true,data:j.data.map(r=>({emp_code:s.employee,flag:r.flag,punch_time:r.punch_time,status:r.status}))};
}
export async function calendar(s,date){
  validDate(date);const [year,month]=date.split('-').map(Number),first=date.slice(0,7)+'-01',last=date.slice(0,7)+'-'+new Date(Date.UTC(year,month,0)).getUTCDate();
  if(!s.calendarKey)throw new Failure('เข้าสู่ระบบใหม่เพื่ออ่านปฏิทินหลังประมวลผล');
  const j=requireResult(await get(new URL('../CalendarMaster/showCalendar_v2',s.base).href,{comp_code:s.company,api_key:s.calendarKey,emp_code:s.employee,from_date:first,to_date:last,role:'Employee',loggedin_user:s.employee,token:s.token},'1'));
  const rows=typeof j.show_calendar==='string'?JSON.parse(j.show_calendar):j.show_calendar;
  if(!Array.isArray(rows)||(j.emp_code!=null&&value(j,'emp_code')!==s.employee)||rows.some(r=>r.emp_code!=null&&value(r,'emp_code')!==s.employee))throw new Failure('ปฏิทินไม่ตรงกับบัญชี',502);
  return {result:true,emp_code:s.employee,show_calendar:rows.map(r=>Object.fromEntries(['start','startTime','endTime','status','isHoliday','isWeeklyOff','typeOfAwaitingApproval'].map(k=>[k,r[k]??''])))};
}
export async function state(s){
 const j=requireResult(await get(s.base+'checkForAttMethod_v2',common(s),s.php));
 return {...Object.fromEntries(['inTimeFlag','showbothinout','facial_recog','intime','outtime'].map(k=>[k,j[k]??null])),facial_method:Array.isArray(j.facial_method)?j.facial_method.map(r=>({method_id:integer(r?.method_id)})):[]};
}
export function allows(j,rows,punch){return rows.some(r=>r.flag==='I'||r.flag==='O')?punch==='O':integer(j.showbothinout)===1||(punch==='I'?integer(j.inTimeFlag)===1:integer(j.inTimeFlag)!=null&&integer(j.inTimeFlag)!==1);}
export async function enrollment(s){
 if(!s.legacy||!s.faceKey)throw new Failure('ยังไม่รองรับวิธียืนยันใบหน้าของบริษัทนี้');
 const j=requireResult(await get(new URL('../FacialMaster/getPersonFace_v2',s.base).href,{comp_code:s.company,api_key:s.faceKey,emp_code:s.employee,token:s.token},s.php));
 const u=new URL(value(j,'FacialEndPoint')),threshold=Number(j.Facialthreshold);
 if(u.protocol!=='https:'||u.port||u.username||u.password||u.search||u.hash||!['.cognitiveservices.azure.com','.api.cognitive.microsoft.com'].some(x=>u.hostname.endsWith(x))||!['','/','/face/v1.0','/face/v1.0/'].includes(u.pathname)||!value(j,'Facialthreshold')||!Number.isFinite(threshold)||threshold<0||threshold>1||!/^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/i.test(value(j,'PersonID'))||!['0','1'].includes(value(j,'spoof'))||!value(j,'GroupID')||!value(j,'FacialSubscription'))throw new Failure('ข้อมูลยืนยันใบหน้าไม่ครบ');
 return {endpoint:u,key:value(j,'FacialSubscription'),group:value(j,'GroupID'),person:value(j,'PersonID'),threshold,spoof:value(j,'spoof')==='1'};
}
export function jpegBytes(text){
 if(typeof text!=='string'||text.length>2000000||!/^[/+A-Za-z0-9]*={0,2}$/.test(text))throw new Failure('ภาพจากกล้องไม่ถูกต้อง');
 const b=Buffer.from(text,'base64');if(b.length<4||b[0]!==255||b[1]!==216||b[2]!==255)throw new Failure('ภาพจากกล้องไม่ถูกต้อง');return b;
}
export const hash=b=>createHash('sha256').update(b).digest('hex');
export async function verify(e,jpeg){
 if(e.spoof){const r=await post('https://devgpt.honohr.com/attendance/checkSpoofing/',{imageselect:jpeg.toString('base64')});if(!truth(r.status))throw new Failure('ภาพไม่ผ่านการตรวจ spoofing กรุณาสแกนใหม่');}
 const headers={'Ocp-Apim-Subscription-Key':e.key};
 const detect=new URL('/face/v1.0/detect',e.endpoint);detect.search='returnFaceId=true&returnFaceLandmarks=false';
 const faces=await request(detect,{method:'POST',headers:{...headers,'Content-Type':'application/octet-stream'},body:jpeg});
 if(!Array.isArray(faces)||faces.length!==1||!faces[0]?.faceId)throw new Failure('ต้องพบใบหน้าเพียงคนเดียว');
 const faceId=faces[0].faceId;
 const matches=await post(new URL('/face/v1.0/identify',e.endpoint),{personGroupId:e.group,faceIds:[faceId],maxNumOfCandidatesReturned:1,confidenceThreshold:.5},headers);
 const candidate=matches?.[0]?.candidates?.[0],confidence=Number(candidate?.confidence),threshold=Math.trunc(Math.fround(Math.fround(e.threshold)*100));
 if(!Array.isArray(matches)||matches.length!==1||matches[0].faceId!==faceId||value(candidate,'personId').toLowerCase()!==e.person.toLowerCase()||!Number.isFinite(confidence)||confidence<0||confidence>1||confidence*100<=threshold)throw new Failure('ใบหน้าไม่ตรงกับบัญชีหรือความมั่นใจต่ำกว่าเกณฑ์บริษัท');
}
export async function submit(s,lat,lng,punch,png){
 const form=new FormData();for(const [k,v]of Object.entries({comp_code:s.company,api_key:s.markKey,userid:s.employee,status:'1',punch,lat:String(lat),lng:String(lng)}))form.set(k,v);
 form.set('profile_image_url',new Blob([png],{type:'image/png'}),'capture.png');
 let j;try{j=await request(s.base+'UserVisitProfileImage',{method:'POST',body:form});}catch{throw new Failure('ไม่ทราบผลการบันทึก กรุณาตรวจประวัติก่อนเริ่มใหม่',502,'unknown');}
 if(truth(j?.result))return;
 if(String(j?.result).toLowerCase()==='false')throw new Failure('HONO ปฏิเสธการลงเวลา กรุณาตรวจประวัติ',502);
 throw new Failure('ไม่ทราบผลการบันทึก กรุณาตรวจประวัติก่อนเริ่มใหม่',502,'unknown');
}

import {AsyncLocalStorage} from 'node:async_hooks';
import {Failure} from './hono.js';
const scope=new AsyncLocalStorage();
export const verificationSignal=()=>scope.getStore();
export function checkVerificationDeadline(){
 if(verificationSignal()?.aborted)throw new Failure('ตรวจภาพไม่สำเร็จภายใน 30 วินาที กรุณาสแกนใหม่',504,'verification_timeout');
}
export async function withVerificationDeadline(task,milliseconds=30000){
 const signal=AbortSignal.timeout(milliseconds);
 return scope.run(signal,async()=>{
  try{const result=await task();checkVerificationDeadline();return result;}
  catch(e){checkVerificationDeadline();throw e;}
 });
}

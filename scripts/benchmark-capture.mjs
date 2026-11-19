// Synthetic pixels only. Run with: node scripts/benchmark-capture.mjs
import jpeg from 'jpeg-js';
import {PNG} from 'pngjs';
import {performance} from 'node:perf_hooks';
import {attendancePng} from '../server/capture-image.js';

const width=960,height=1280,data=Buffer.alloc(width*height*4);
let seed=9001;
for(let y=0;y<height;y++)for(let x=0;x<width;x++){
 seed=(Math.imul(seed,1664525)+1013904223)>>>0;
 const noise=((seed>>>24)-128)*.08,i=(y*width+x)*4;
 data[i]=Math.max(0,Math.min(255,60+x*.12+noise));
 data[i+1]=Math.max(0,Math.min(255,85+y*.08+noise));
 data[i+2]=Math.max(0,Math.min(255,120+Math.sin(x/7)*15+noise));
 data[i+3]=255;
}
const encoded=jpeg.encode({width,height,data},92).data;
const decoded=jpeg.decode(encoded,{useTArray:true,maxResolutionInMP:2,maxMemoryUsageInMB:48});
const input={width,height,data:Buffer.from(decoded.data)};
function bench(name,task){
 const samples=[];let output;
 for(let i=0;i<4;i++){const start=performance.now();output=task();samples.push(performance.now()-start);}
 samples.sort((a,b)=>a-b);
 return {name,medianMs:Math.round((samples[1]+samples[2])/2),bytes:output.length};
}
console.log(JSON.stringify({
 fixture:'Synthetic gradient/noise; no employee image',width,height,jpegBytes:encoded.length,
 results:[
  bench('previous PNG',()=>PNG.sync.write(input)),
  bench('optimized PNG',()=>attendancePng(decoded)),
 ],
 note:'Local encoding benchmark; not an end-to-end HONO latency or recognition benchmark.',
},null,2));

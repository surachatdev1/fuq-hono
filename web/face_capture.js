import {FaceLandmarker, FilesetResolver} from './vision/vision_bundle.mjs';
let detector, video, stream, epoch = 0, last = -1;
window.nwlFaceStart = async id => {
  const current = ++epoch;
  window.nwlFaceStop(false);
  video = document.getElementById(id);
  if (!video || !window.isSecureContext || !navigator.mediaDevices?.getUserMedia) throw Error('camera unavailable');
  const next = await navigator.mediaDevices.getUserMedia({video:{facingMode:'user',width:{ideal:640},height:{ideal:480}},audio:false});
  if (current !== epoch) { next.getTracks().forEach(t=>t.stop()); throw Error('cancelled'); }
  stream = next; video.srcObject = stream; video.muted = true; video.playsInline = true; await video.play();
  if (!detector) detector = await FaceLandmarker.createFromOptions(await FilesetResolver.forVisionTasks('/vision/wasm'), {baseOptions:{modelAssetPath:'/vision/face_landmarker.task',delegate:'CPU'},runningMode:'VIDEO',numFaces:2,outputFaceBlendshapes:true});
  if (current !== epoch) throw Error('cancelled');
  last = -1;
  return 'ready';
};
window.nwlFacePoll = () => {
  if (!video || video.readyState < 2 || !detector || document.hidden || video.currentTime === last) return '{}';
  last = video.currentTime;
  const result = detector.detectForVideo(video, performance.now());
  const faces = result.faceLandmarks;
  if (faces.length !== 1) return JSON.stringify({one:false});
  const scores = Object.fromEntries(result.faceBlendshapes[0].categories.map(x=>[x.categoryName,x.score]));
  const xs = faces[0].map(p=>p.x), ys=faces[0].map(p=>p.y);
  const one = Math.max(...xs)-Math.min(...xs)>.16 && Math.min(...xs)>0 && Math.max(...xs)<1 && Math.min(...ys)>0 && Math.max(...ys)<1;
  return JSON.stringify({one,left:1-scores.eyeBlinkLeft,right:1-scores.eyeBlinkRight});
};
window.nwlFaceCapture = () => {
  if (!video || document.hidden || !stream?.active) throw Error('camera stopped');
  const canvas = document.createElement('canvas'); canvas.width=video.videoWidth; canvas.height=video.videoHeight;
  canvas.getContext('2d').drawImage(video,0,0); const data=canvas.toDataURL('image/jpeg',.85); canvas.width=canvas.height=0; return data;
};
window.nwlFaceStop = (advance = true) => { if(advance) epoch++; stream?.getTracks().forEach(t=>t.stop());stream=null;if(video)video.srcObject=null; };
document.addEventListener('visibilitychange',()=>{ if(document.hidden)window.nwlFaceStop(); });
let audio, ringing;
window.nwlSilence = () => { if(ringing)clearTimeout(ringing); audio?.close().catch(()=>{});audio=null; };
window.nwlSound = kind => {
  window.nwlSilence(); if(kind==='silent')return;
  try { audio=new AudioContext(); const end=audio.currentTime+(kind==='chime'?1.6:1);
    const osc=audio.createOscillator(),gain=audio.createGain();osc.type='sine';osc.frequency.value=kind==='chime'?880:520;
    gain.gain.setValueAtTime(.001,audio.currentTime);gain.gain.exponentialRampToValueAtTime(.12,audio.currentTime+.05);gain.gain.exponentialRampToValueAtTime(.001,end);
    osc.connect(gain);gain.connect(audio.destination);osc.start();osc.stop(end);ringing=setTimeout(window.nwlSilence,2200);
  }catch{};
};

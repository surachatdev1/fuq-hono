import {FaceLandmarker, FilesetResolver} from './vision/vision_bundle.mjs';
let detector, video, stream, epoch = 0, last = -1;
window.nwlFaceStart = async element => {
  const current = ++epoch;
  window.nwlFaceStop(false);
  // Flutter onElementCreated fires before DOM attachment. Pass the video element
  // directly: getElementById cannot find it yet (especially on mobile Safari).
  const currentVideo = element;
  video = currentVideo;
  if (!currentVideo || currentVideo.tagName !== 'VIDEO' || !window.isSecureContext || !navigator.mediaDevices?.getUserMedia) throw Error('camera unavailable');
  currentVideo.muted = true;
  currentVideo.autoplay = true;
  currentVideo.playsInline = true;
  currentVideo.setAttribute('playsinline', '');
  currentVideo.setAttribute('webkit-playsinline', '');
  try {
    const next = await navigator.mediaDevices.getUserMedia({video:{facingMode:'user',width:{ideal:640},height:{ideal:480}},audio:false});
    if (current !== epoch) { next.getTracks().forEach(t=>t.stop()); throw Error('cancelled'); }
    stream = next;
    currentVideo.srcObject = stream;
    // iOS Safari may refuse video.play() until the Flutter view is connected.
    await new Promise((resolve, reject) => {
      const deadline = performance.now() + 5000;
      const poll = () => {
        if (current !== epoch) return reject(Error('cancelled'));
        if (currentVideo.isConnected) return resolve();
        if (performance.now() >= deadline) return reject(Error('camera view not attached'));
        requestAnimationFrame(poll);
      };
      poll();
    });
    if (current !== epoch) throw Error('cancelled');
    await currentVideo.play();
    if (!detector) detector = await FaceLandmarker.createFromOptions(await FilesetResolver.forVisionTasks('/vision/wasm'), {baseOptions:{modelAssetPath:'/vision/face_landmarker.task',delegate:'CPU'},runningMode:'VIDEO',numFaces:2,outputFaceBlendshapes:true});
    if (current !== epoch) throw Error('cancelled');
    last = -1;
    return 'ready';
  } catch (error) {
    if (current === epoch) window.nwlFaceStop();
    throw error;
  }
};
window.nwlFacePoll = () => {
  if (!video || video.readyState < 2 || !detector || document.hidden || video.currentTime === last) return '{}';
  last = video.currentTime;
  const result = detector.detectForVideo(video, performance.now());
  const faces = result.faceLandmarks;
  if (faces.length !== 1) return JSON.stringify({one:false,hint:faces.length>1?'multiple':'missing'});
  const scores = Object.fromEntries(result.faceBlendshapes[0].categories.map(x=>[x.categoryName,x.score]));
  const xs = faces[0].map(p=>p.x), ys=faces[0].map(p=>p.y);
  const width=Math.max(...xs)-Math.min(...xs), height=Math.max(...ys)-Math.min(...ys);
  const cx=(Math.max(...xs)+Math.min(...xs))/2, cy=(Math.max(...ys)+Math.min(...ys))/2;
  const inside=Math.min(...xs)>.04 && Math.max(...xs)<.96 && Math.min(...ys)>.02 && Math.max(...ys)<.98;
  const hint=width<.22?'closer':width>.76||height>.94?'back':!inside||Math.abs(cx-.5)>.16||Math.abs(cy-.5)>.2?'center':'ready';
  return JSON.stringify({one:hint==='ready',hint,left:1-scores.eyeBlinkLeft,right:1-scores.eyeBlinkRight});
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

let detector, detectorLoading, video, stream, epoch = 0, lastFrame = -1;

function loadDetector() {
  if (detector) return Promise.resolve(detector);
  detectorLoading ??= (async () => {
    const {FaceLandmarker, FilesetResolver} = await import('./vision/vision_bundle.mjs');
    const files = await FilesetResolver.forVisionTasks('/vision/wasm');
    detector = await FaceLandmarker.createFromOptions(files, {
      baseOptions: {modelAssetPath: '/vision/face_landmarker.task', delegate: 'CPU'},
      runningMode: 'VIDEO',
      numFaces: 2,
      outputFaceBlendshapes: true,
    });
    return detector;
  })().finally(() => { detectorLoading = null; });
  return detectorLoading;
}

function waitForCamera(test, current) {
  return new Promise((resolve, reject) => {
    const deadline = performance.now() + 5000;
    function check() {
      if (current !== epoch) return reject(new Error('cancelled'));
      if (test()) return resolve();
      if (performance.now() >= deadline) return reject(new Error('camera not ready'));
      requestAnimationFrame(check);
    }
    check();
  });
}

window.nwlFaceStart = async element => {
  const current = ++epoch;
  window.nwlFaceStop(false);
  if (element?.tagName !== 'VIDEO' || !window.isSecureContext ||
      !navigator.mediaDevices?.getUserMedia) return 'camera_unsupported';
  if (document.hidden) return 'cancelled';

  video = element;
  video.muted = true;
  video.autoplay = true;
  video.playsInline = true;
  video.setAttribute('playsinline', '');
  video.setAttribute('webkit-playsinline', '');

  // Fetch and initialize the model while the browser opens the camera.
  const modelReady = loadDetector().then(() => true, () => false);
  let phase = 'camera_start';
  try {
    const next = await navigator.mediaDevices.getUserMedia({
      video: {facingMode: 'user', width: {ideal: 640}, height: {ideal: 480}},
      audio: false,
    });
    if (current !== epoch || document.hidden) {
      next.getTracks().forEach(track => track.stop());
      return 'cancelled';
    }
    stream = next;
    element.srcObject = stream;
    // Flutter creates the element before attaching it. Safari needs it attached
    // before play(), and a playing video can still lack its first frame.
    await waitForCamera(() => element.isConnected, current);
    phase = 'camera_no_frames';
    await element.play();
    await waitForCamera(() => element.readyState >= 2 && element.videoWidth > 0, current);
    phase = 'model_load';
    if (!await modelReady) throw new Error('model unavailable');
    if (current !== epoch) return 'cancelled';
    lastFrame = -1;
    return 'ready';
  } catch (error) {
    if (current !== epoch) return 'cancelled';
    window.nwlFaceStop();
    if (phase !== 'camera_start') return phase;
    switch (error?.name) {
      case 'NotAllowedError':
      case 'SecurityError':
        return 'camera_permission';
      case 'NotFoundError':
      case 'OverconstrainedError':
        return 'camera_missing';
      case 'NotReadableError':
      case 'AbortError':
        return 'camera_busy';
      default:
        return phase;
    }
  }
};

window.nwlFacePoll = () => {
  if (document.hidden) return '{}';
  if (!video || !stream?.active) return '{"error":"camera_stopped"}';
  if (video.readyState < 2 || !detector || video.currentTime === lastFrame) return '{}';
  lastFrame = video.currentTime;
  const result = detector.detectForVideo(video, performance.now());
  const faces = result.faceLandmarks;
  if (faces.length !== 1) {
    return JSON.stringify({one: false, hint: faces.length > 1 ? 'multiple' : 'missing'});
  }

  let left = 1, right = 0, top = 1, bottom = 0;
  for (const {x, y} of faces[0]) {
    left = Math.min(left, x);
    right = Math.max(right, x);
    top = Math.min(top, y);
    bottom = Math.max(bottom, y);
  }
  const width = right - left, height = bottom - top;
  const centered = Math.abs((left + right) / 2 - .5) <= .18 &&
    Math.abs((top + bottom) / 2 - .5) <= .21;
  const inside = left > .03 && right < .97 && top > .02 && bottom < .98;
  const hint = width < .19 ? 'closer'
    : width > .76 || height > .94 ? 'back'
    : !inside || !centered ? 'center' : 'ready';
  const categories = result.faceBlendshapes?.[0]?.categories ?? [];
  const leftBlink = categories.find(category => category.categoryName === 'eyeBlinkLeft')?.score;
  const rightBlink = categories.find(category => category.categoryName === 'eyeBlinkRight')?.score;
  return JSON.stringify({
    one: hint === 'ready',
    hint,
    left: Number.isFinite(leftBlink) ? 1 - leftBlink : null,
    right: Number.isFinite(rightBlink) ? 1 - rightBlink : null,
  });
};

window.nwlFaceCapture = () => {
  if (!video || document.hidden || !stream?.active || video.readyState < 2 ||
      !video.videoWidth || !video.videoHeight) throw new Error('camera frame unavailable');
  const canvas = document.createElement('canvas');
  const scale = Math.min(1, 1280 / Math.max(video.videoWidth, video.videoHeight));
  canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
  canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
  try {
    canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/jpeg', .85);
  } finally {
    canvas.width = canvas.height = 0;
  }
};

window.nwlFaceStop = (advance = true) => {
  if (advance) epoch++;
  stream?.getTracks().forEach(track => track.stop());
  stream = null;
  if (video) video.srcObject = null;
  video = null;
};
document.addEventListener('visibilitychange', () => {
  if (document.hidden) window.nwlFaceStop();
});

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

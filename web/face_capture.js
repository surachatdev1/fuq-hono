import {facePosition} from './face_geometry.js';
import {CaptureWindow, faceNeedsStraightening, measureFaceFrame} from './face_quality.js';

let detector, detectorLoading, video, stream, epoch = 0, lastFrame = -1;
let analysisFrame, frozenFrame, bestFrame, faceSample, captureReady = false;
const captureWindow = new CaptureWindow();
const captureEdge = 1280;
const jpegPrefix = 'data:image/jpeg;base64,';

function drawFrame(canvas, source, sourceWidth, sourceHeight, maxEdge) {
  const scale = Math.min(1, maxEdge / Math.max(sourceWidth, sourceHeight));
  const width = Math.max(1, Math.round(sourceWidth * scale));
  const height = Math.max(1, Math.round(sourceHeight * scale));
  if (canvas.width !== width) canvas.width = width;
  if (canvas.height !== height) canvas.height = height;
  canvas.getContext('2d').drawImage(source, 0, 0, width, height);
}

function faceQuality(frame, {left, top, width, height}) {
  const side = 48;
  if (!faceSample) {
    faceSample = document.createElement('canvas');
    faceSample.width = faceSample.height = side;
  }
  const context = faceSample.getContext('2d', {willReadFrequently: true});
  context.drawImage(frame,
    (left + width * .2) * frame.width, (top + height * .2) * frame.height,
    width * .6 * frame.width, height * .6 * frame.height, 0, 0, side, side);
  return measureFaceFrame(context.getImageData(0, 0, side, side).data, side);
}

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
  video.removeAttribute('poster');
  video.muted = true;
  video.autoplay = true;
  video.playsInline = true;
  video.setAttribute('playsinline', '');
  video.setAttribute('webkit-playsinline', '');

  // Fetch and initialize the model while the browser opens the camera.
  const modelReady = loadDetector().then(() => true, () => false);
  let phase = 'camera_start';
  try {
    const portrait = window.innerWidth < 700 && window.innerHeight > window.innerWidth;
    const next = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: 'user',
        width: {ideal: portrait ? 960 : 1280},
        height: {ideal: portrait ? 1280 : 960},
        aspectRatio: {ideal: portrait ? .75 : 4 / 3},
      },
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

window.nwlFacePoll = (freezeFrame = false) => {
  captureReady = false;
  if (document.hidden) return '{}';
  if (!video || !stream?.active) return '{"error":"camera_stopped"}';
  if (video.readyState < 2 || !video.videoWidth || !video.videoHeight ||
      !detector || video.currentTime === lastFrame) return '{}';
  lastFrame = video.currentTime;
  const width = video.videoWidth, height = video.videoHeight;
  let frame = video;
  let sourceWidth = width, sourceHeight = height;
  if (freezeFrame) {
    frozenFrame ??= document.createElement('canvas');
    drawFrame(frozenFrame, video, width, height, captureEdge);
    frame = frozenFrame;
    sourceWidth = frame.width;
    sourceHeight = frame.height;
  }
  let input = frame;
  if (Math.max(sourceWidth, sourceHeight) > 640) {
    // The detector sees the same frame at lower resolution. Keep the original
    // snapshot for quality ranking and verification.
    analysisFrame ??= document.createElement('canvas');
    drawFrame(analysisFrame, frame, sourceWidth, sourceHeight, 640);
    input = analysisFrame;
  }
  const now = performance.now();
  const aspectRatio = width / height;
  const result = detector.detectForVideo(input, now);
  const faces = result.faceLandmarks;
  if (faces.length !== 1) {
    captureWindow.reset();
    return JSON.stringify({
      one: false,
      hint: faces.length > 1 ? 'multiple' : 'missing',
      aspectRatio,
    });
  }

  const position = facePosition(faces[0], width, height);
  const {hint} = position;
  const categories = result.faceBlendshapes?.[0]?.categories ?? [];
  const leftBlink = categories.find(category => category.categoryName === 'eyeBlinkLeft')?.score;
  const rightBlink = categories.find(category => category.categoryName === 'eyeBlinkRight')?.score;
  const leftOpen = Number.isFinite(leftBlink) ? 1 - leftBlink : null;
  const rightOpen = Number.isFinite(rightBlink) ? 1 - rightBlink : null;
  const candidate = freezeFrame && hint === 'ready' && leftOpen > .7 && rightOpen > .7;
  let lighting = null, quality = null;
  if (candidate && faceNeedsStraightening(faces[0], width, height)) quality = 'straight';
  if (candidate && !quality) {
    const measured = faceQuality(frozenFrame, position);
    lighting = measured.lighting;
    if (!lighting) {
      const sample = captureWindow.offer(
        position, now, measured.detail, sourceWidth, sourceHeight);
      if (sample.replace) {
        bestFrame ??= document.createElement('canvas');
        drawFrame(bestFrame, frozenFrame, sourceWidth, sourceHeight, captureEdge);
      }
      captureReady = sample.ready;
    }
  }
  if (!candidate || lighting || quality) captureWindow.reset();
  return JSON.stringify({
    one: hint === 'ready',
    face: {left: position.left, top: position.top, width: position.width, height: position.height},
    hint,
    aspectRatio,
    left: leftOpen,
    right: rightOpen,
    lighting,
    quality,
    captureReady,
  });
};

window.nwlFaceCapture = () => {
  if (!captureReady || !bestFrame || document.hidden || !stream?.active) {
    throw new Error('checked camera frame unavailable');
  }
  captureReady = false;
  for (const quality of [.92, .85, .76]) {
    const data = bestFrame.toDataURL('image/jpeg', quality);
    if (data.startsWith(jpegPrefix) && data.length - jpegPrefix.length <= 2_000_000) {
      video.poster = data;
      return data;
    }
  }
  throw new Error('JPEG exceeds verification limit');
};

window.nwlFaceStop = (advance = true) => {
  if (advance) epoch++;
  stream?.getTracks().forEach(track => track.stop());
  stream = null;
  if (video) video.srcObject = null;
  video = null;
  captureReady = false;
  captureWindow.reset();
  for (const canvas of [analysisFrame, frozenFrame, bestFrame, faceSample]) {
    if (canvas) canvas.width = canvas.height = 0;
  }
  analysisFrame = frozenFrame = bestFrame = faceSample = null;
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

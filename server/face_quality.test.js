import {strict as assert} from 'node:assert';
import {test} from 'node:test';
import {CaptureWindow, faceNeedsStraightening, measureFaceFrame} from '../web/face_quality.js';

test('capture pose catches obvious tilt and turning in either orientation', () => {
  const landmarks = [];
  landmarks[33] = {x:.35, y:.40};
  landmarks[263] = {x:.65, y:.40};
  landmarks[1] = {x:.50, y:.55};
  assert.equal(faceNeedsStraightening(landmarks, 1280, 960), false);
  assert.equal(faceNeedsStraightening(landmarks, 960, 1280), false);

  landmarks[1].x = .59;
  assert.equal(faceNeedsStraightening(landmarks, 1280, 960), true);
  landmarks[1].x = .50;
  landmarks[263].y = .54;
  assert.equal(faceNeedsStraightening(landmarks, 960, 1280), true);
});

test('face detail ranks a crisp edge higher and still rejects extreme light', () => {
  function sample(pixel) {
    const side = 8;
    const pixels = new Uint8Array(side * side * 4);
    for (let row = 0; row < side; row++) {
      for (let col = 0; col < side; col++) {
        const i = (row * side + col) * 4;
        pixels.fill(pixel(col), i, i + 3);
        pixels[i + 3] = 255;
      }
    }
    return measureFaceFrame(pixels, side);
  }
  const crisp = sample(col => col < 4 ? 70 : 160);
  const soft = sample(col => 70 + col * 12);
  assert.equal(crisp.lighting, null);
  assert.ok(crisp.detail > soft.detail);
  assert.equal(sample(() => 15).lighting, 'dark');
  assert.equal(sample(() => 250).lighting, 'bright');
});

test('capture ranks stable frames and discards a burst after motion or a stale gap', () => {
  const window = new CaptureWindow();
  const face = {left:.33, top:.23, width:.34, height:.50};
  const offer = (instant, detail, bounds = face) =>
    window.offer(bounds, instant, detail, 1280, 960);
  assert.deepEqual(offer(100, 20), {replace:true, ready:false});
  assert.deepEqual(offer(170, 50), {replace:true, ready:false});
  assert.deepEqual(offer(240, 25), {replace:false, ready:true});
  const moved = {...face, left:.40};
  assert.deepEqual(offer(310, 10, moved), {replace:true, ready:false});
  assert.deepEqual(offer(800, 9, moved), {replace:true, ready:false});
  assert.deepEqual(offer(1050, 8, moved), {replace:false, ready:true});
});

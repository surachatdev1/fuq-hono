// Let the user finish the blink challenge before asking for a frontal photo.
export function faceNeedsStraightening(landmarks, width, height) {
  const left = landmarks[33], right = landmarks[263], nose = landmarks[1];
  if (!left || !right || !nose) return false;
  const dx = (right.x - left.x) * width;
  const dy = (right.y - left.y) * height;
  const eyeSpanSquared = dx * dx + dy * dy;
  if (!eyeSpanSquared) return false;
  const noseX = (nose.x - (left.x + right.x) / 2) * width;
  const noseY = (nose.y - (left.y + right.y) / 2) * height;
  const noseOffset = (noseX * dx + noseY * dy) / eyeSpanSquared;
  const roll = Math.atan2(Math.abs(dy), Math.abs(dx));
  return roll > Math.PI / 9 || Math.abs(noseOffset) > .24;
}

export function measureFaceFrame(pixels, side) {
  const gray = new Float32Array(side * side);
  let mean = 0;
  for (let i = 0; i < gray.length; i++) {
    const offset = i * 4;
    const luminance = .2126 * pixels[offset] + .7152 * pixels[offset + 1] +
      .0722 * pixels[offset + 2];
    gray[i] = luminance;
    mean += luminance;
  }
  mean /= gray.length;
  let detail = 0;
  for (let row = 1; row < side - 1; row++) {
    for (let col = 1; col < side - 1; col++) {
      const i = row * side + col;
      detail += Math.abs(4 * gray[i] -
        gray[i - 1] - gray[i + 1] - gray[i - side] - gray[i + side]);
    }
  }
  return {lighting: mean < 30 ? 'dark' : mean > 245 ? 'bright' : null, detail};
}

export class CaptureWindow {
  constructor() {
    this.reset();
  }

  reset() {
    this.anchor = null;
    this.bestDetail = -1;
    this.frames = 0;
  }

  offer(face, now, detail, width, height) {
    const anchor = this.anchor;
    if (anchor && (now - this.started > 450 || width !== this.width ||
        height !== this.height || !faceStayedStill(anchor, face))) {
      this.reset();
    }
    if (!this.anchor) {
      this.anchor = face;
      this.started = now;
      this.width = width;
      this.height = height;
    }
    const replace = detail >= this.bestDetail;
    if (replace) this.bestDetail = detail;
    this.frames++;
    // A slower camera can still finish with two stable, recent frames.
    const ready = this.frames >= 3 || (this.frames >= 2 && now - this.started >= 220);
    return {replace, ready};
  }
}

function faceStayedStill(a, b) {
  const x = a.left + a.width / 2 - b.left - b.width / 2;
  const y = a.top + a.height / 2 - b.top - b.height / 2;
  return Math.abs(x) <= .1 * a.width && Math.abs(y) <= .1 * a.height &&
    Math.abs(a.width - b.width) <= .15 * a.width &&
    Math.abs(a.height - b.height) <= .15 * a.height;
}

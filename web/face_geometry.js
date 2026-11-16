// Coordinates are normalized to the whole video frame. The preview mirrors
// that frame, so horizontal instructions refer to what the employee sees.
export function facePosition(landmarks, frameWidth, frameHeight) {
  let left = 1, right = 0, top = 1, bottom = 0;
  for (const {x, y} of landmarks) {
    left = Math.min(left, x);
    right = Math.max(right, x);
    top = Math.min(top, y);
    bottom = Math.max(bottom, y);
  }
  const width = right - left, height = bottom - top;
  const shortEdge = Math.min(frameWidth, frameHeight);
  const minimumWidth = Math.max(.20 * shortEdge, .15 * frameWidth);
  const minimumHeight = Math.max(.32 * shortEdge, .25 * frameHeight);
  const x = (left + right) / 2 - .5;
  const y = (top + bottom) / 2 - .5;
  const edgeX = left < .03 || right > .97;
  const edgeY = top < .02 || bottom > .98;

  let hint = 'ready';
  if (width > .76 || height > .88) {
    hint = 'back';
  } else if (width * frameWidth < minimumWidth ||
             height * frameHeight < minimumHeight) {
    hint = 'closer';
  } else if (edgeX || edgeY || Math.hypot(x / .23, y / .25) > 1) {
    if (edgeX || (!edgeY && Math.abs(x / .23) >= Math.abs(y / .25))) {
      hint = x > 0 ? 'right' : 'left';
    } else {
      hint = y > 0 ? 'up' : 'down';
    }
  }
  return {left, top, width, height, hint};
}

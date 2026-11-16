import {strict as assert} from 'node:assert';
import {test} from 'node:test';
import {facePosition} from '../web/face_geometry.js';

function hint(x, y, width, height, frameWidth = 640, frameHeight = 480) {
  return facePosition([
    {x: x - width / 2, y: y - height / 2},
    {x: x + width / 2, y: y + height / 2},
  ], frameWidth, frameHeight).hint;
}

test('camera guides use the same physical face sizes in portrait and landscape', () => {
  assert.equal(hint(.5, .5, .17, .37), 'ready');
  assert.equal(hint(.5, .5, .23, .28, 480, 640), 'ready');
  assert.equal(hint(.5, .5, .10, .22), 'closer');
  assert.equal(hint(.5, .5, .23, .16, 480, 640), 'closer');
  assert.equal(hint(.5, .5, .60, .92), 'back');
});

test('alignment directions describe the mirrored preview and reject clipped faces', () => {
  assert.equal(hint(.72, .5, .23, .44), 'ready');
  assert.equal(hint(.76, .5, .23, .44), 'right');
  assert.equal(hint(.24, .5, .23, .44), 'left');
  assert.equal(hint(.5, .77, .23, .32), 'up');
  assert.equal(hint(.5, .23, .23, .32), 'down');
  assert.equal(hint(.72, .5, .53, .44), 'right');
});

import {test} from 'node:test';
import assert from 'node:assert/strict';
import jpeg from 'jpeg-js';
import {PNG} from 'pngjs';
import {attendancePng} from './capture-image.js';

test('smaller attendance PNG preserves every pixel of the verified JPEG', () => {
  const width = 320, height = 480;
  const data = Buffer.alloc(width * height * 4);
  let seed = 9001;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const i = (y * width + x) * 4;
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const noise = ((seed >>> 24) - 128) * .08;
    data[i] = 60 + x * .12 + noise;
    data[i + 1] = 85 + y * .08 + noise;
    data[i + 2] = 120 + Math.sin(x / 7) * 15 + noise;
    data[i + 3] = 255;
  }
  const decoded = jpeg.decode(jpeg.encode({width, height, data}, 92).data, {useTArray: true});
  const optimized = attendancePng(decoded);
  const png = PNG.sync.read(optimized);
  assert.equal(png.width, width);
  assert.equal(png.height, height);
  assert.deepEqual(png.data, Buffer.from(decoded.data));
  const previous = PNG.sync.write({width, height, data: Buffer.from(decoded.data)});
  assert.ok(optimized.length < previous.length, `${optimized.length} >= ${previous.length}`);
});

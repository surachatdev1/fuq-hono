import {PNG} from 'pngjs';

// Camera JPEGs decode to opaque RGBA. RGB PNG preserves their verified pixels
// without an unnecessary alpha channel; Sub filtering bounds encoding work.
export function attendancePng(decoded) {
  return PNG.sync.write({
    width: decoded.width,
    height: decoded.height,
    data: Buffer.from(decoded.data),
  }, {colorType: 2, filterType: 1, deflateLevel: 3, deflateStrategy: 0});
}

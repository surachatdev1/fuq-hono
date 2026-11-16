import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';

const [source, output] = process.argv.slice(2);
const snapshot = '5b0fc5e329f562152b2ffa6a3a597dd81d9a6adf';
const origin = 'https://raw.githubusercontent.com/GeoThai/boundaries/' + snapshot;
async function read(filename, checksum) {
  let input;
  if (source === '-') {
    const response = await fetch(origin + '/' + filename, {
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(filename + ': HTTP ' + response.status);
    input = Buffer.from(await response.arrayBuffer());
  } else {
    input = readFileSync(source + '/' + filename);
  }
  if (createHash('sha256').update(input).digest('hex') !== checksum) {
    throw new Error('Unexpected GeoThai snapshot: ' + filename);
  }
  return JSON.parse(input).features;
}

const [provinces, districts] = await Promise.all([
  read('provinces.geojson', '26741e78228724f03f39c35648027034c75faaeb4fed6db0cb0b44e517a93eac'),
  read('districts.geojson', '6c52e6c12bccdb7abeb67216f0dd28d3a6d4342b9d93e270e37b2f546def6d75'),
]);
const provinceNames = Object.fromEntries(
  provinces.map(({properties}) => [properties.code, properties.name_th]),
);
const rows = districts.map(({properties, geometry}) => {
  const polygons = geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.coordinates;
  return [
    properties.province_code,
    properties.name_th,
    polygons.map(polygon => {
      let west = Infinity, south = Infinity, east = -Infinity, north = -Infinity;
      const rings = polygon.map(ring => {
        let previousX = 0, previousY = 0;
        return ring.flatMap(([lng, lat]) => {
          const x = Math.round(lng * 10000), y = Math.round(lat * 10000);
          west = Math.min(west, x);
          south = Math.min(south, y);
          east = Math.max(east, x);
          north = Math.max(north, y);
          const delta = [x - previousX, y - previousY];
          previousX = x;
          previousY = y;
          return delta;
        });
      });
      return [west, south, east, north, rings];
    }),
  ];
});

writeFileSync(output, JSON.stringify({
  source: 'GeoThai, from OCHA COD-AB and the Royal Thai Survey Department',
  provinces: provinceNames,
  districts: rows,
}));

import test from 'node:test';
import assert from 'node:assert/strict';
import {resolve,hasCoordinates,pageDestination} from './maps.js';
test('short share links expand to an exact pin',async()=>{
 let calls=0;
 const url=await resolve('https://maps.app.goo.gl/example',{fetcher:async()=>{calls++;return new Response(null,{status:302,headers:{location:'https://www.google.com/maps/place/Office/data=!3d18.78!4d98.98'}});}});
 assert.match(url,/!3d18.78!4d98.98/);assert.equal(calls,1);
});
test('nested app-opening links resolve without network',async()=>{
 const url=await resolve('https://maps.app.goo.gl/?link='+encodeURIComponent('https://www.google.com/maps?q=18.78,98.98'),{fetcher:()=>{throw Error('unexpected fetch');}});
 assert.match(url,/q=18.78,98.98/);
});
test('HTML chooses coordinates over coordinate-free canonical and decodes entities',()=>{
 assert.equal(pageDestination('<link rel="canonical" href="https://www.google.com/maps?cid=123"><meta property="og:url" content="https://www.google.com/maps?q=18,99&amp;foo=1">'),'https://www.google.com/maps?q=18,99&foo=1');
});
test('static preview center is explicitly a viewport, never an exact pin',()=>{
 assert.equal(pageDestination('<meta property="og:image" content="https://maps.googleapis.com/maps/api/staticmap?center=18.7%2C98.9&amp;zoom=15">'),'https://www.google.com/maps?ll=18.7%2C98.9');
});
test('does not mistake incomplete or invalid markers for a coordinate pair',()=>{
 for(const part of ['!1m2!1splace-id','!3d18','!3d91!4d99','!4d99','@18','?q=91,99'])assert.equal(hasCoordinates(new URL('https://www.google.com/maps/'+part)),false);
});
test('rejects off-site redirects and nested URLs before fetching destination',async()=>{
 let calls=0;
 await assert.rejects(resolve('https://maps.app.goo.gl/a',{fetcher:async()=>{calls++;return new Response(null,{status:302,headers:{location:'https://evil.test/maps?q=18,99'}});}}));
 assert.equal(calls,1);
 await assert.rejects(resolve('https://maps.app.goo.gl/?link=https%3A%2F%2Fevil.test%2Fmaps'));
});
test('redirect loops stop without repeated fetch',async()=>{
 let calls=0;
 await assert.rejects(resolve('https://maps.app.goo.gl/a',{fetcher:async()=>{calls++;return new Response(null,{status:302,headers:{location:'https://maps.app.goo.gl/a'}});}}));
 assert.equal(calls,1);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {PNG} from 'pngjs';
import jpeg from 'jpeg-js';
import {createListenHubProvider, alignment, removal, transcriptType, blobType, supportsAlignment} from '../dist/provider.js';
import {assertEvidenceWav, transcriptEvidence} from '../dist/transcript.js';
import {keyGreenRgba, keyImage} from '../dist/keying.js';

const wav = () => {
  const bytes = Buffer.alloc(44 + 32000);
  bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(16000, 24); bytes.writeUInt32LE(32000, 28); bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34); bytes.write('data', 36); bytes.writeUInt32LE(32000, 40);
  return bytes;
};
const blob = bytes => ({kind: 'blob', resource: 'res_test', size: bytes.length, mediaType: 'audio/wav'});
const transcript = {sentences: [{startMs: 0, endMs: 1000, words: [{text: '你好', startMs: 12.5, endMs: 750, confidence: 0.93}]}]};
const reply = data => new Response(JSON.stringify({code: 0, data}), {headers: {'content-type': 'application/json'}});

async function harness(fetcher, bytes = wav()) {
  const provider = createListenHubProvider({baseUrl: 'https://api.test/openapi', apiKey: {store: 'env', key: 'TEST_KEY'}, fetch: fetcher});
  const endpoints = new Map();
  await provider.install({registerImmediateEndpoint(_id, capability, _returns, handler) {endpoints.set(capability.name, handler);}, registerAsyncEndpoint(_id, capability, _returns, endpoint) {endpoints.set(capability.name, endpoint);}});
  const context = {operation: 'test-operation', need: {constraints: {audio: blob(bytes), sampleFrames: 16000, language: 'zh'}}, resources: {get: async () => bytes, put: async (output, mediaType) => ({kind: 'blob', resource: 'res_output', size: output.length, mediaType})}, credentials: {apiKey: {secret: 'test-secret'}}};
  return {provider, endpoints, context};
}

test('maps milliseconds to exact 16 kHz samples and omits unavailable/invalid times', () => {
  assert.deepEqual(transcriptEvidence(transcript, 16000).passages[0].words[0], {text: '你好', startSample: 200, endSampleExclusive: 12000, score: 0.93});
  const evidence = transcriptEvidence({sentences: [{words: [{text: 'later', startMs: 2000, endMs: 2100}, {text: 'missing'}, {text: 'bad', startMs: -1, endMs: 10, confidence: 2}]}]}, 16000);
  assert.deepEqual(evidence.passages[0].words, [{text: 'later'}, {text: 'missing'}, {text: 'bad'}]);
  assert.deepEqual(evidence.passages[0].chars, []);
  assert.throws(() => transcriptEvidence(transcript, 0));
});

test('refuses unsupported language before any paid submission', () => {
  const request = {capability: alignment, returns: transcriptType, constraints: {language: 'zh'}, pendingInputs: [{input: 'audio'}]};
  assert.equal(supportsAlignment(request).status, 'supported');
  for (const language of ['auto', 'zh-CN', 'und', 'xx', '']) assert.equal(supportsAlignment({...request, constraints: {language}}).status, 'unsupported');
});

test('validates the canonical evidence WAV before upload', () => {
  const bytes = wav();
  assert.doesNotThrow(() => assertEvidenceWav(bytes, 16000));
  assert.throws(() => assertEvidenceWav(bytes, 15999));
  bytes.writeUInt32LE(48000, 24);
  assert.throws(() => assertEvidenceWav(bytes, 16000));
});

test('green keying makes background transparent, retains foreground and suppresses soft green edges', () => {
  const keyed = keyGreenRgba(new Uint8Array([0,255,0,255, 190,120,100,255, 70,130,60,255]));
  assert.equal(keyed[3], 0); assert.equal(keyed[7], 255);
  assert.ok(keyed[11] > 0 && keyed[11] < 255); assert.ok(keyed[9] < 130);
  const edges = keyGreenRgba(new Uint8Array([70,90,60,255, 20,30,18,255, 30,110,130,255, 130,120,35,255, 190,175,150,255]));
  assert.deepEqual([...edges], [70,65,60,255, 20,19,18,255, 30,110,130,255, 130,83,35,255, 190,175,150,255]);
  const image = new PNG({width: 2, height: 1}); image.data.set([0,255,0,255,190,120,100,255]);
  const decoded = PNG.sync.read(keyImage(PNG.sync.write(image)));
  assert.equal(decoded.data[3], 0); assert.equal(decoded.data[7], 255);
  assert.equal(PNG.sync.read(keyImage(jpeg.encode({width: 2, height: 1, data: image.data}, 100).data)).width, 2);
});

test('readPricing uses the two live estimates, resolves credentials only for the read, and makes no generation', async () => {
  const calls = [];
  const {provider} = await harness(async (url, options) => {calls.push([url, JSON.parse(options.body), options.headers]); return reply({credits: url.includes('audio-transcriptions') ? 1 : 15});});
  let credentialReads = 0;
  const credentials = async () => {credentialReads++; return {apiKey: {secret: 'pricing-key'}};};
  const known = await provider.readPricing({request: {capability: alignment, returns: transcriptType, constraints: {sampleFrames: 16000}}, credentials});
  assert.equal(calls[0][1].durationMs, 1000); assert.equal(known[0].data.credits, 1); assert.equal(known[0].data.usageKnown, true);
  const pending = await provider.readPricing({request: {capability: alignment, returns: transcriptType, constraints: {}}, credentials});
  assert.equal(pending[0].data.usageKnown, false); assert.match(pending[0].summary, /rate example/);
  await provider.readPricing({request: {capability: removal, returns: blobType, constraints: {}}, credentials});
  assert.equal(calls[2][1].model, 'seedream-5-0-pro'); assert.equal(credentialReads, 3);
  assert.ok(calls.every(([url]) => url.endsWith('/estimate-credits')));
});

test('uploads without API bearer, reports task receipt, polls and returns aligned evidence', async () => {
  const calls = [];
  const {endpoints, context} = await harness(async (url, options) => {
    calls.push([String(url), options]);
    if (String(url).endsWith('/uploads')) return reply({fileKey: 'audio-key', presignedUrl: 'https://storage.test/upload', headers: {'Content-Type': 'audio/wav'}});
    if (String(url).includes('storage.test')) return new Response('', {status: 200});
    if (String(url).endsWith('/transcript')) return reply(transcript);
    if (options.method === 'POST') return reply({id: 'task-1', status: 'queued', reservedCredits: 1});
    return reply({id: 'task-1', status: 'completed'});
  });
  const endpoint = endpoints.get(alignment.name);
  const diagnostics = [];
  context.reportDiagnostic = async value => diagnostics.push(value);
  const finished = await endpoint(context);
  assert.match(diagnostics[0].message, /task-1/);
  assert.equal(calls[1][1].headers.Authorization, undefined);
  const created = JSON.parse(calls[2][1].body);
  assert.equal(created.durationMs, 1000); assert.equal(created.language, undefined); assert.match(created.idempotencyKey, /^hypit-[a-f0-9]{64}$/);
  assert.equal(finished.value.value.passages[0].words[0].startSample, 200);
  await endpoint(context);
  assert.equal(JSON.parse(calls[7][1].body).idempotencyKey, created.idempotencyKey);
});

test('failed tasks stop without creating another charge', async () => {
  let creates = 0;
  const {endpoints, context} = await harness(async (url, options) => {
    if (String(url).endsWith('/uploads')) return reply({fileKey: 'audio-key', presignedUrl: 'https://storage.test/upload', headers: {'Content-Type': 'audio/wav'}});
    if (String(url).includes('storage.test')) return new Response('', {status: 200});
    if (options.method === 'POST') {creates++; return reply({id: 'task-failed', status: 'queued'});}
    return reply({id: 'task-failed', status: 'failed'});
  });
  await assert.rejects(endpoints.get(alignment.name)(context), /task-failed failed/);
  assert.equal(creates, 1);
  assert.throws(() => createListenHubProvider({baseUrl: 'http://remote.test', apiKey: {store: 'env', key: 'TEST'}}));
});

test('background endpoint polls one accepted image task and downloads without API bearer', async () => {
  const picture = new PNG({width: 1, height: 1}); picture.data.set([0,255,0,255]);
  const png = PNG.sync.write(picture);
  let creates = 0;
  const {endpoints, context} = await harness(async (url, options) => {
    if (String(url).endsWith('/async')) {
      creates++;
      const body = JSON.parse(options.body);
      assert.equal(body.model, 'seedream-5-0-pro');
      assert.equal(body.referenceImages[0].inlineData.mimeType, 'image/png');
      return reply({taskId: 'image-1', status: 'pending'});
    }
    if (String(url).includes('/tasks/')) return reply({taskId: 'image-1', status: 'success', images: [{url: 'https://cdn.test/image.png'}]});
    assert.equal(String(url), 'https://cdn.test/image.png');
    assert.equal(options.headers, undefined);
    return new Response(png, {headers: {'content-type': 'image/png'}});
  }, png);
  context.need.constraints = {source: {...blob(png), mediaType: 'image/png'}};
  const diagnostics = [];
  context.reportDiagnostic = async value => diagnostics.push(value);
  let output;
  context.resources.put = async (bytes, mediaType) => {output = PNG.sync.read(bytes); return {kind: 'blob', resource: 'res_output', size: bytes.length, mediaType};};
  const result = await endpoints.get(removal.name)(context);
  assert.equal(result.value.mediaType, 'image/png'); assert.equal(output.data[3], 0);
  assert.equal(creates, 1); assert.match(diagnostics[0].message, /image-1/);
});

test('failed or missing image results stop without submitting another image', async () => {
  const picture = new PNG({width: 1, height: 1}); picture.data.set([0,255,0,255]);
  const png = PNG.sync.write(picture);
  for (const task of [{status: 'fail'}, {status: 'success', images: []}]) {
    let creates = 0;
    const {endpoints, context} = await harness(async (url) => {
      if (String(url).endsWith('/async')) {creates++; return reply({taskId: 'image-stop', status: 'pending'});}
      return reply(task);
    }, png);
    context.need.constraints = {source: {...blob(png), mediaType: 'image/png'}};
    await assert.rejects(endpoints.get(removal.name)(context), /image-stop/);
    assert.equal(creates, 1);
  }
});

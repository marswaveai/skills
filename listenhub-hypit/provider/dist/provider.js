import { Buffer } from 'node:buffer';
import { createHash } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { canonicalize, defineEndpointPackage, } from '@hypit/hypit/endpoint-kit';
import { assertEvidenceWav, languages, transcriptEvidence, } from './transcript.js';
import { decodeImage, keyImage, nearestAspect } from './keying.js';
export const moduleReference = {
    name: '@listenhub/provider-hypit',
    version: '1',
};
export const alignment = {
    module: { name: '@hypit/whisperx', version: '1' },
    name: 'whisperx-alignment',
};
export const removal = {
    module: { name: '@hypit/background-removal', version: '1' },
    name: 'remove-background',
};
export const transcriptType = {
    module: { name: '@hypit/speech-evidence', version: '1' },
    name: 'AlignedTranscriptEvidence',
};
export const blobType = {
    module: { name: '@hypit/artifact', version: '1' },
    name: 'BlobArtifact',
};
const transcriptionPath = '/v1/audio-transcriptions';
const imagePath = '/v1/images/generation';
const greenPrompt = 'Preserve exactly the subject, face, hair, clothing, pose and framing of the reference. Replace only the entire background with perfectly flat solid chroma green RGB(0,255,0), #00FF00. Keep fine hair detail. No shadows or gradients on the background, no green reflected light on the subject. One unchanged subject, no text.';
const imageParameters = {
    provider: 'bytedance',
    model: 'seedream-5-0-pro',
    prompt: greenPrompt,
    imageConfig: { imageSize: '2K', aspectRatio: '1:1' },
};
function object(value) {
    if (value === null || typeof value !== 'object' || Array.isArray(value))
        throw new Error('Invalid ListenHub response/request object');
    return value;
}
function text(value, name) {
    if (typeof value !== 'string' || !value)
        throw new Error(`Missing ${name}`);
    return value;
}
function alignmentRequest(value) {
    const request = object(value);
    const audio = object(request.audio);
    if (audio.kind !== 'blob' ||
        audio.mediaType !== 'audio/wav' ||
        !Number.isSafeInteger(request.sampleFrames) ||
        Number(request.sampleFrames) <= 0 ||
        !languages.has(String(request.language)))
        throw new Error('Invalid or unsupported alignment request');
    return request;
}
export function supportsAlignment(request) {
    const constraints = object(request.constraints);
    return languages.has(String(constraints.language))
        ? { status: 'supported' }
        : {
            status: 'unsupported',
            reason: 'ListenHub transcription does not support this language; use one of the 30 documented spoken-language codes',
        };
}
async function resource(context, blob) {
    const bytes = await context.resources.get(blob.resource);
    if (!bytes || bytes.byteLength !== blob.size)
        throw new Error('Source artifact is missing or changed');
    return bytes;
}
export function createListenHubProvider(options) {
    const url = new URL(options.baseUrl);
    if (url.username ||
        url.password ||
        url.search ||
        url.hash ||
        (url.protocol !== 'https:' &&
            !(url.protocol === 'http:' &&
                ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname))))
        throw new Error('baseUrl must be HTTPS (or loopback HTTP for local tests), without credentials/query/fragment');
    const baseUrl = url.href.replace(/\/+$/u, '');
    const fetcher = options.fetch ?? fetch;
    const timeoutMs = options.timeoutMs ?? 600_000;
    const pollIntervalMs = options.pollIntervalMs ?? 3000;
    const secret = (context) => text(context.credentials.apiKey?.secret, 'ListenHub API key');
    const call = async (path, apiKey, body) => {
        let response;
        try {
            response = await fetcher(`${baseUrl}${path}`, {
                method: body === undefined ? 'GET' : 'POST',
                headers: {
                    Authorization: `Bearer ${apiKey}`,
                    'Content-Type': 'application/json',
                },
                ...(body === undefined ? {} : { body: JSON.stringify(body) }),
                signal: AbortSignal.timeout(timeoutMs),
                redirect: 'error',
            });
        }
        catch {
            throw new Error(`ListenHub ${path} transport failed; submission outcome may be unknown. Do not automatically resubmit paid work`);
        }
        if (!response.ok)
            throw new Error(`ListenHub ${path} returned HTTP ${response.status}`);
        const value = object(await response.json());
        if (value.code !== undefined && value.code !== 0)
            throw new Error(`ListenHub ${path} business error ${String(value.code)}`);
        if (value.errno !== undefined && value.errno !== 0)
            throw new Error(`ListenHub ${path} business error ${String(value.errno)}`);
        return object(value.data ?? value);
    };
    return defineEndpointPackage({
        module: moduleReference,
        facet: 'listenhub',
        instance: options.instance ?? 'listenhub.local',
        pool: options.pool ?? 'listenhub.local',
        credentials: { apiKey: options.apiKey },
        credentialInputs: { apiKey: { label: 'ListenHub API key', kind: 'secret' } },
        defaultConcurrency: 1,
        pricing: { kind: 'page', url: 'https://listenhub.ai/pricing' },
        async readPricing(context) {
            const credentials = await context.credentials();
            const apiKey = text(credentials.apiKey?.secret, 'ListenHub API key');
            const isAlignment = context.request.capability.name === alignment.name;
            const samples = Number(object(context.request.constraints).sampleFrames);
            const usageKnown = Number.isSafeInteger(samples) && samples > 0;
            const durationMs = usageKnown ? Math.ceil(samples / 16) : 60_000;
            const path = `${isAlignment ? transcriptionPath : imagePath}/estimate-credits`;
            const estimate = await call(path, apiKey, isAlignment ? { durationMs } : imageParameters);
            return [
                {
                    source: `${baseUrl}${path}`,
                    data: canonicalize({
                        ...estimate,
                        usageKnown: isAlignment ? usageKnown : true,
                        ...(isAlignment ? { durationMs } : {}),
                    }),
                    summary: isAlignment
                        ? `${String(estimate.credits)} ListenHub credits / ${durationMs} ms${usageKnown ? '' : ' (rate example; actual audio duration is pending)'}`
                        : `${String(estimate.credits)} ListenHub credits / Seedream 5.0 Pro 2K background removal; local keying is free`,
                },
            ];
        },
        capabilities: [
            {
                lifecycle: 'immediate',
                capability: alignment,
                returns: transcriptType,
                supports: supportsAlignment,
                async handler(context) {
                    const request = alignmentRequest(context.need.constraints);
                    const bytes = await resource(context, request.audio);
                    assertEvidenceWav(bytes, request.sampleFrames);
                    const apiKey = secret(context);
                    const upload = await call(`${transcriptionPath}/uploads`, apiKey, {
                        fileName: 'hypit-evidence.wav',
                        contentType: 'audio/wav',
                        fileSize: bytes.length,
                    });
                    const uploadUrl = new URL(text(upload.presignedUrl, 'upload URL'));
                    if (uploadUrl.protocol !== 'https:' &&
                        !['localhost', '127.0.0.1', '[::1]'].includes(uploadUrl.hostname))
                        throw new Error('Upload URL must use HTTPS');
                    const uploaded = await fetcher(uploadUrl, {
                        method: 'PUT',
                        headers: object(upload.headers),
                        body: Buffer.from(bytes),
                        signal: AbortSignal.timeout(timeoutMs),
                        redirect: 'error',
                    });
                    if (!uploaded.ok)
                        throw new Error(`Evidence upload returned HTTP ${uploaded.status}`);
                    const created = await call(transcriptionPath, apiKey, {
                        fileKey: text(upload.fileKey, 'fileKey'),
                        fileName: 'hypit-evidence.wav',
                        durationMs: Math.ceil(request.sampleFrames / 16),
                        terms: [],
                        idempotencyKey: `hypit-${createHash('sha256').update('listenhub-asr-v1:').update(request.language).update(bytes).digest('hex')}`,
                    });
                    const id = text(created.id, 'transcription task id');
                    await context.reportDiagnostic?.({
                        level: 'info',
                        message: `ListenHub transcription task ${id}; reserved credits ${String(created.reservedCredits ?? 'unknown')}`,
                    });
                    const path = `${transcriptionPath}/${encodeURIComponent(id)}`;
                    const deadline = Date.now() + timeoutMs;
                    /* eslint-disable no-await-in-loop -- Polling must wait for the previous task response. */
                    while (Date.now() <= deadline) {
                        const task = await call(path, apiKey);
                        if (task.status === 'failed')
                            throw new Error(`ListenHub transcription ${id} failed; inspect the existing task before retrying`);
                        if (task.status === 'completed') {
                            const transcript = await call(`${path}/transcript`, apiKey);
                            return {
                                value: {
                                    kind: 'inline',
                                    value: canonicalize(transcriptEvidence(transcript, request.sampleFrames)),
                                },
                            };
                        }
                        if (!['queued', 'transcribing'].includes(String(task.status)))
                            throw new Error(`Unknown transcription status for ${id}`);
                        await context.reportProgress?.({
                            phase: `ListenHub transcription ${id}: ${String(task.status)}`,
                        });
                        await delay(pollIntervalMs);
                    }
                    /* eslint-enable no-await-in-loop */
                    throw new Error(`ListenHub transcription ${id} wait timed out; the task may still be running. Inspect it before resubmitting`);
                },
            },
            {
                lifecycle: 'immediate',
                capability: removal,
                returns: blobType,
                supports(request) {
                    const { source } = object(request.constraints);
                    if (!source &&
                        request.pendingInputs?.some((input) => input.input === 'source'))
                        return { status: 'supported' };
                    const mime = object(source).mediaType;
                    return ['image/png', 'image/jpeg'].includes(String(mime))
                        ? { status: 'supported' }
                        : {
                            status: 'unsupported',
                            reason: 'Background removal accepts PNG/JPEG; convert the source image first',
                        };
                },
                async handler(context) {
                    const source = object(context.need.constraints).source;
                    const bytes = await resource(context, source);
                    const decoded = decodeImage(bytes);
                    const result = await call(imagePath, secret(context), {
                        ...imageParameters,
                        imageConfig: {
                            ...imageParameters.imageConfig,
                            aspectRatio: nearestAspect(decoded.width, decoded.height),
                        },
                        referenceImages: [
                            {
                                inlineData: {
                                    data: Buffer.from(bytes).toString('base64'),
                                    mimeType: source.mediaType,
                                },
                            },
                        ],
                    });
                    const candidates = result.candidates;
                    const encoded = candidates
                        ?.flatMap((candidate) => candidate.content?.parts ?? [])
                        .find((part) => part.inlineData?.data)?.inlineData?.data;
                    if (!encoded)
                        throw new Error('Seedream returned no inline image; inspect the paid request before retrying');
                    const png = keyImage(Buffer.from(encoded, 'base64'));
                    return { value: await context.resources.put(png, 'image/png') };
                },
            },
        ],
    });
}

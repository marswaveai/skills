export const languages = new Set(
  'zh en ja ko vi th id ms fil hi ar fr de es pt ru it nl sv da fi no el pl cs hu ro bg hr sk'.split(
    ' ',
  ),
);

export type Word = {
  text: string;
  startMs?: number;
  endMs?: number;
  confidence?: number;
};
export type Transcript = {
  sentences: Array<{startMs?: number; endMs?: number; words: Word[]}>;
};

function window(
  start: number | undefined,
  end: number | undefined,
  samples: number,
) {
  if (
    start === undefined ||
    end === undefined ||
    !Number.isFinite(start) ||
    !Number.isFinite(end) ||
    start < 0 ||
    end < start
  )
    return {};
  const startSample = Math.round(start * 16);
  const endSampleExclusive = Math.round(end * 16);
  if (
    !Number.isSafeInteger(startSample) ||
    !Number.isSafeInteger(endSampleExclusive) ||
    endSampleExclusive > samples
  )
    return {};
  return {startSample, endSampleExclusive};
}

export function transcriptEvidence(
  transcript: Transcript,
  sampleFrames: number,
) {
  if (!Number.isSafeInteger(sampleFrames) || sampleFrames <= 0)
    throw new Error('Invalid evidence sample count');
  if (!Array.isArray(transcript.sentences))
    throw new Error('Transcript has no sentences');
  return {
    passages: transcript.sentences.map((sentence) => ({
      ...window(sentence.startMs, sentence.endMs, sampleFrames),
      words: sentence.words
        .filter((word) => word.text.trim())
        .map((word) => ({
          text: word.text.trim(),
          ...window(word.startMs, word.endMs, sampleFrames),
          ...(word.confidence !== undefined &&
          Number.isFinite(word.confidence) &&
          word.confidence >= 0 &&
          word.confidence <= 1
            ? {score: word.confidence}
            : {}),
        })),
      chars: [],
    })),
  };
}

export function assertEvidenceWav(bytes: Uint8Array, sampleFrames: number) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const tag = (at: number) =>
    new TextDecoder().decode(bytes.subarray(at, at + 4));
  if (bytes.length < 44 || tag(0) !== 'RIFF' || tag(8) !== 'WAVE')
    throw new Error('Evidence must be a WAV');
  let validFormat = false;
  let validData = false;
  for (let at = 12; at + 8 <= bytes.length;) {
    const length = view.getUint32(at + 4, true);
    const body = at + 8;
    if (body + length > bytes.length) throw new Error('Truncated WAV');
    if (tag(at) === 'fmt ' && length >= 16)
      validFormat =
        view.getUint16(body, true) === 1 &&
        view.getUint16(body + 2, true) === 1 &&
        view.getUint32(body + 4, true) === 16_000 &&
        view.getUint16(body + 14, true) === 16;
    if (tag(at) === 'data') validData = length === sampleFrames * 2;
    at = body + length + (length % 2);
  }

  if (!validFormat || !validData)
    throw new Error(
      'Evidence must be 16 kHz mono PCM s16 with the declared sample count',
    );
}

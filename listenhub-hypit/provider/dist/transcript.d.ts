export declare const languages: Set<string>;
export type Word = {
    text: string;
    startMs?: number;
    endMs?: number;
    confidence?: number;
};
export type Transcript = {
    sentences: Array<{
        startMs?: number;
        endMs?: number;
        words: Word[];
    }>;
};
export declare function transcriptEvidence(transcript: Transcript, sampleFrames: number): {
    passages: ({
        words: ({
            score?: number | undefined;
            startSample?: undefined;
            endSampleExclusive?: undefined;
            text: string;
        } | {
            score?: number | undefined;
            startSample: number;
            endSampleExclusive: number;
            text: string;
        })[];
        chars: never[];
        startSample?: undefined;
        endSampleExclusive?: undefined;
    } | {
        words: ({
            score?: number | undefined;
            startSample?: undefined;
            endSampleExclusive?: undefined;
            text: string;
        } | {
            score?: number | undefined;
            startSample: number;
            endSampleExclusive: number;
            text: string;
        })[];
        chars: never[];
        startSample: number;
        endSampleExclusive: number;
    })[];
};
export declare function assertEvidenceWav(bytes: Uint8Array, sampleFrames: number): void;

import { Buffer } from 'node:buffer';
import jpeg from 'jpeg-js';
export declare function decodeImage(bytes: Uint8Array): import("pngjs").PNGWithMetadata | (jpeg.UintArrRet & {
    comments?: string[];
});
export declare function keyGreenRgba(data: Uint8Array): Uint8Array<ArrayBuffer>;
export declare function keyImage(bytes: Uint8Array): Buffer<ArrayBufferLike>;
export declare function nearestAspect(width: number, height: number): string;

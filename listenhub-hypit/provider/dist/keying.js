import { Buffer } from 'node:buffer';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';
export function decodeImage(bytes) {
    const buffer = Buffer.from(bytes);
    if (buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])))
        return PNG.sync.read(buffer);
    if (buffer[0] === 255 && buffer[1] === 216)
        return jpeg.decode(buffer, { useTArray: true, maxMemoryUsageInMB: 256 });
    throw new Error('Use a PNG or JPEG image; convert other formats with hypit media/ffmpeg first');
}
export function keyGreenRgba(data) {
    const output = new Uint8Array(data);
    for (let i = 0; i < output.length; i += 4) {
        const red = output[i];
        const green = output[i + 1];
        const blue = output[i + 2];
        const dominance = green - Math.max(red, blue);
        const removal = green > 70 ? Math.min(1, Math.max(0, (dominance - 25) / 75)) : 0;
        output[i + 3] = Math.round(output[i + 3] * (1 - removal));
        if (removal > 0)
            output[i + 1] = Math.round(green - dominance * removal);
    }
    return output;
}
export function keyImage(bytes) {
    const decoded = decodeImage(bytes);
    const output = new PNG({ width: decoded.width, height: decoded.height });
    output.data = Buffer.from(keyGreenRgba(decoded.data));
    return PNG.sync.write(output);
}
export function nearestAspect(width, height) {
    const distance = (value) => {
        const [w, h] = value.split(':').map(Number);
        return Math.abs(Math.log(w / h / (width / height)));
    };
    let best = '1:1';
    for (const ratio of ['4:3', '3:4', '16:9', '9:16', '21:9']) {
        if (distance(ratio) < distance(best))
            best = ratio;
    }
    return best;
}

import {register} from 'tsx/esm/api';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
register();
const root = resolve(fileURLToPath(new URL('.', import.meta.resolve('@hypit/hypit/endpoint-kit'))), '../../..');
const loader = await import(pathToFileURL(resolve(root, 'packages/package-loader-node/src/distribution-resolution.ts')).href);
loader.installDistributionPackageResolution([root]);

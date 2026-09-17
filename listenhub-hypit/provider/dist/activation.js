import { createRuntimeEndpointAdapterFacet, runtimeConfigCredentialRef, runtimeConfigExact, runtimeConfigObject, runtimeConfigPositiveInteger, runtimeConfigString, } from '@hypit/hypit/runtime-kit';
import { createListenHubProvider, moduleReference } from './provider.js';
const hypitPackage = {
    format: 'hypit.node-package@1',
    hostFacets: [
        createRuntimeEndpointAdapterFacet({
            use: moduleReference.name,
            activate(context) {
                const config = runtimeConfigObject(context.config, 'ListenHub');
                runtimeConfigExact(config, ['baseUrl', 'apiKey', 'pollIntervalMs', 'timeoutMs'], 'ListenHub');
                const apiKey = runtimeConfigCredentialRef(config.apiKey, 'ListenHub API key');
                if (!apiKey || !context.pool)
                    throw new Error('ListenHub requires apiKey credential reference and pool');
                return {
                    endpoint: createListenHubProvider({
                        instance: context.instance,
                        pool: context.pool,
                        apiKey,
                        baseUrl: runtimeConfigString(config.baseUrl, 'ListenHub baseUrl') ??
                            'https://api.listenhub.ai/openapi',
                        pollIntervalMs: runtimeConfigPositiveInteger(config.pollIntervalMs, 'pollIntervalMs'),
                        timeoutMs: runtimeConfigPositiveInteger(config.timeoutMs, 'timeoutMs'),
                    }),
                };
            },
        }),
    ],
};
export default hypitPackage;

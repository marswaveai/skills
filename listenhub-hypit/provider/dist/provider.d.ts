import { type CredentialRef, type EndpointRequest } from '@hypit/hypit/endpoint-kit';
export declare const moduleReference: {
    name: string;
    version: string;
};
export declare const alignment: {
    module: {
        name: string;
        version: string;
    };
    name: string;
};
export declare const removal: {
    module: {
        name: string;
        version: string;
    };
    name: string;
};
export declare const transcriptType: {
    module: {
        name: string;
        version: string;
    };
    name: string;
};
export declare const blobType: {
    module: {
        name: string;
        version: string;
    };
    name: string;
};
type Options = {
    instance?: string;
    pool?: string;
    baseUrl: string;
    apiKey: CredentialRef;
    pollIntervalMs?: number;
    timeoutMs?: number;
    fetch?: typeof fetch;
};
export declare function supportsAlignment(request: EndpointRequest): {
    status: "supported";
    reason?: undefined;
} | {
    status: "unsupported";
    reason: string;
};
export declare function createListenHubProvider(options: Options): import("@hypit/hypit/endpoint-kit").EndpointPackage;
export {};

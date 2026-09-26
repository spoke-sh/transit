import contract from "./contract.json" with { type: "json" };

export const limits = Object.freeze({ ...contract.limits });
export function integer(value: unknown, name: string, min = 1, max = limits.max_counter): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new TypeError(`${name} must be a safe integer in the supported range`);
  }
  return value;
}
export function owned(value: unknown, bound: number): Uint8Array {
  if (!(value instanceof Uint8Array) || value.byteLength > bound) {
    throw new TypeError("Expected bytes within the operation bound");
  }
  return new Uint8Array(value);
}
export function text(value: unknown, bound = limits.max_body): string {
  if (typeof value !== "string" || value.length > bound || Buffer.byteLength(value) > bound) {
    throw new TypeError("Expected text within the operation bound");
  }
  return value;
}
export function record(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError("Expected a native object");
  }
  return value as Record<string, unknown>;
}
export class ProcessRef {
  readonly realm: number;
  readonly pid: number;
  constructor(realm: number, pid: number) {
    this.realm = integer(realm, "realm");
    this.pid = integer(pid, "pid");
    Object.freeze(this);
  }
}
export class ResourceRef {
  readonly realm: number;
  readonly resource: number;
  constructor(realm: number, resource: number) {
    this.realm = integer(realm, "realm");
    this.resource = integer(resource, "resource");
    Object.freeze(this);
  }
}
export class OperationIdentity {
  readonly sha256: string;
  constructor(sha256: string) {
    if (typeof sha256 !== "string" || !/^[0-9a-f]{64}$/.test(sha256)) {
      throw new TypeError("Expected a canonical native operation identity");
    }
    this.sha256 = sha256;
    Object.freeze(this);
  }
}
export class Credential {
  readonly realm: number;
  readonly principal: number;
  readonly #seedFile: string;
  constructor(realm: number, principal: number, seedFile: string) {
    this.realm = integer(realm, "realm");
    this.principal = integer(principal, "principal", 0);
    this.#seedFile = text(seedFile);
    if (!this.#seedFile) throw new TypeError("An explicit seed file is required");
    Object.freeze(this);
  }
  get seedFile(): string {
    return this.#seedFile;
  }
}
export class AdmissionReceipt {
  readonly kind = "admitted";
  readonly position: number;
  constructor(position: number) {
    this.position = integer(position, "receipt position");
    Object.freeze(this);
  }
}
export class MutationReceipt {
  readonly kind = "mutation";
  readonly position: number;
  constructor(position: number) {
    this.position = integer(position, "receipt position");
    Object.freeze(this);
  }
}
export interface ClientConfig {
  readonly url: string;
  readonly profile: "growing_v3";
  readonly timeoutMs?: number;
  readonly nativeHost?: string;
}
export function configuration(
  value: ClientConfig,
): Readonly<Required<Omit<ClientConfig, "nativeHost">> & Pick<ClientConfig, "nativeHost">> {
  if (value === null || typeof value !== "object" || value.profile !== "growing_v3") {
    throw new TypeError("Select the explicit growing_v3 profile");
  }
  const url = text(value.url);
  const parsed = new URL(url);
  if (
    !["http:", "https:"].includes(parsed.protocol) ||
    parsed.username ||
    parsed.password ||
    parsed.search ||
    parsed.hash
  ) {
    throw new TypeError("Expected an HTTP endpoint without credentials, query or fragment");
  }
  const timeoutMs = integer(value.timeoutMs ?? 5000, "timeoutMs", 1, 60000);
  const nativeHost = value.nativeHost === undefined ? undefined : text(value.nativeHost);
  return Object.freeze({ url, profile: value.profile, timeoutMs, nativeHost });
}

import { inspect } from "node:util";
import { Closed, IncompatibleNative, UnsupportedCapability } from "./errors.ts";
import {
  Credential,
  OperationIdentity,
  ProcessRef,
  integer,
  limits,
  owned,
  record,
  text,
} from "./values.ts";
import { Port, validators } from "./port.ts";
import schemas from "./schemas.json" with { type: "json" };
import type { OperationMetadata } from "./wire.ts";

export const validation = validators(schemas);
const utf8 = new TextDecoder("utf-8", { fatal: true });
export function frozenText(bytes: Uint8Array): string {
  return utf8.decode(owned(bytes, limits.max_body));
}
export function frozenBytes(value: unknown): Uint8Array {
  return new Uint8Array(Buffer.from(text(value)));
}
export async function metadata(port: Port, frozen: Uint8Array): Promise<OperationMetadata> {
  const value = await port.request(
    { metadata: frozenText(frozen) },
    { phase: "metadata", validator: validation.OperationMetadata },
  );
  const result = value as OperationMetadata;
  if (result.version !== 1) throw new IncompatibleNative("Unsupported operation metadata version");
  new OperationIdentity(result.identity);
  integer(result.realm, "operation realm");
  integer(result.principal, "operation principal", 0);
  return result;
}
export async function prepare(
  port: Port,
  kind: number,
  credential: Credential,
  document: object,
): Promise<Uint8Array> {
  const value = await port.request(
    { prepare: { kind, seed_file: credential.seedFile, document: JSON.stringify(document) } },
    { phase: "prepare" },
  );
  return frozenBytes(value);
}
export function sequence(value: string | null): number {
  if (typeof value !== "string" || value.length > 16 || !/^[1-9][0-9]*$/.test(value))
    throw new IncompatibleNative("Invalid native sequence");
  return integer(Number(value), "sequence");
}
export interface SendInfo {
  readonly identity: OperationIdentity;
  readonly peer: ProcessRef;
  readonly principal: number;
  readonly sequence: number;
}
export interface MutationInfo {
  readonly identity: OperationIdentity;
  readonly realm: number;
  readonly principal: number;
  readonly sequence: number;
  readonly command: string;
}
class Pending<I extends { readonly identity: OperationIdentity }> {
  readonly info: I;
  #bytes: Uint8Array | undefined;
  constructor(info: I, frozen: Uint8Array) {
    this.info = Object.freeze(info);
    this.#bytes = owned(frozen, limits.max_body);
  }
  get identity(): OperationIdentity {
    return this.info.identity;
  }
  export(): Uint8Array {
    if (!this.#bytes) throw new Closed("Pending operation is closed");
    return new Uint8Array(this.#bytes);
  }
  close(): void {
    this.#bytes = undefined;
  }
  [Symbol.dispose](): void {
    this.close();
  }
  [inspect.custom](): string {
    return `${this.constructor.name}(${this.identity.sha256})`;
  }
}
export class PendingSend extends Pending<SendInfo> {}
export class PendingMutation extends Pending<MutationInfo> {}
export async function recoverSend(port: Port, frozen: Uint8Array): Promise<PendingSend> {
  const info = await metadata(port, frozen);
  if (info.profile !== "growing_v3" || info.kind !== "growing_command" || info.command !== "send") {
    throw new UnsupportedCapability("Recovery material is not a growing send");
  }
  return new PendingSend(
    {
      identity: new OperationIdentity(info.identity),
      peer: new ProcessRef(info.realm, integer(info.destination, "destination")),
      principal: info.principal,
      sequence: sequence(info.sequence),
    },
    frozen,
  );
}
export async function recoverMutation(port: Port, frozen: Uint8Array): Promise<PendingMutation> {
  const info = await metadata(port, frozen);
  if (info.profile !== "growing_v3" || info.kind !== "growing_command" || !info.command) {
    throw new UnsupportedCapability("Recovery material is not a growing mutation");
  }
  return new PendingMutation(
    {
      identity: new OperationIdentity(info.identity),
      realm: info.realm,
      principal: info.principal,
      sequence: sequence(info.sequence),
      command: info.command,
    },
    frozen,
  );
}
export interface Capabilities {
  readonly realm: number;
  readonly observedAt: number;
  readonly principalSequence: number;
  readonly pageSize: number;
  readonly mutationsPerTurn: number;
  readonly outputsPerTurn: number;
  readonly retainedVersions: boolean;
  readonly associationLookup: boolean;
  readonly scopedRetry: boolean;
  readonly station: boolean;
}
export async function authorityCapabilities(
  port: Port,
  credential: Credential,
): Promise<Capabilities> {
  const operation = await prepare(port, 7, credential, {
    realm: credential.realm,
    principal: credential.principal,
    kind: { capabilities: {} },
  });
  const value = record(
    await port.request({ call: frozenText(operation) }, { phase: "authority-capabilities" }),
  );
  const caps = record(record(value.body).capabilities);
  if (value.version !== 3 || caps.version !== 3 || caps.profile !== "growing_v1") {
    throw new UnsupportedCapability("Authority does not advertise the explicit growing profile");
  }
  if (
    typeof caps.retained_read_versions !== "boolean" ||
    typeof caps.station !== "boolean" ||
    typeof caps.association_lookup !== "boolean" ||
    typeof caps.scoped_retry !== "boolean"
  ) {
    throw new IncompatibleNative("Invalid authority capability flags");
  }
  return Object.freeze({
    realm: integer(value.realm, "realm"),
    observedAt: integer(value.position, "position", 0),
    principalSequence: integer(value.principal_sequence, "principal sequence", 0),
    pageSize: integer(caps.page_entries, "page size"),
    mutationsPerTurn: integer(caps.mutation_budget, "mutation budget"),
    outputsPerTurn: integer(caps.output_budget, "output budget"),
    retainedVersions: caps.retained_read_versions,
    associationLookup: caps.association_lookup,
    scopedRetry: caps.scoped_retry,
    station: caps.station,
  });
}

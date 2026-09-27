import {
  IncompatibleNative,
  UnsupportedCapability,
  TurnExpired,
  OperationIdentity,
} from "@transit/client";
import {
  Port,
  validators,
  record,
  metadata,
  authorityCapabilities,
  frozenBytes,
} from "@transit/client/internal";
import schemas from "./schemas.json" with { type: "json" };
import type {
  DocumentCodecAction,
  DocumentCodecResult,
  DocumentReadAction,
  DocumentReadResult,
  GrowingAction,
  GrowingResult,
  GrowingEvent,
  GrowingCapabilities,
  HttpCodecAction,
  HttpCodecResult,
  HttpReadAction,
  HttpReadResult,
  GrpcCodecAction,
  GrpcCodecResult,
  GrpcReadAction,
  GrpcReadResult,
} from "./wire.ts";
import {
  FrozenMutation,
  serviceConfiguration,
  type ServiceConfig,
  type FailurePolicy,
} from "./values.ts";

const validation = validators(schemas);
async function openPort(config: object, override?: string): Promise<Port> {
  let executable = override;
  if (!executable) {
    try {
      const native = await import("@transit/native-station");
      if (native.version !== "0.2.0") throw new Error();
      executable = native.hostPath;
    } catch {
      throw new IncompatibleNative(
        "Install the matching @transit/native-station artifact or supply nativeHost",
      );
    }
  }
  const requestValidator = validation.HostRequest;
  if (!requestValidator) throw new IncompatibleNative("Missing generated Station schema");
  const port = await Port.open(executable, config, requestValidator);
  try {
    const hello = record(await port.request({ hello: {} }, { phase: "hello" }));
    if (
      Object.keys(hello).sort().join(",") !== "host_version,station_version,transit_version" ||
      hello.host_version !== 1 ||
      hello.station_version !== 1 ||
      hello.transit_version !== 1
    ) {
      throw new IncompatibleNative("Native Station protocol version mismatch");
    }
    return port;
  } catch (error) {
    await port.close();
    throw error;
  }
}
export class Bridge {
  readonly port: Port;
  readonly caps: GrowingCapabilities;
  private constructor(port: Port, caps: GrowingCapabilities) {
    this.port = port;
    this.caps = caps;
  }
  static async local(nativeHost?: string): Promise<Bridge> {
    const port = await openPort({ local_codec: true }, nativeHost);
    try {
      return new Bridge(port, await Bridge.capabilities(port));
    } catch (error) {
      await port.close();
      throw error;
    }
  }
  private static async capabilities(port: Port): Promise<GrowingCapabilities> {
    const caps = (await port.request(
      { growing_capabilities: {} },
      { phase: "native-capabilities", validator: validation.GrowingCapabilities },
    )) as GrowingCapabilities;
    if (
      caps.version !== 1 ||
      caps.profile !== "growing_v3" ||
      !caps.gated_dispatch ||
      !caps.retained_confirmation ||
      !caps.scoped_turns ||
      !caps.paged_state ||
      !caps.tables ||
      !caps.retained_sources
    ) {
      throw new UnsupportedCapability("Native Station lacks required growing turn capabilities");
    }
    return caps;
  }
  static async open(input: ServiceConfig, failure: FailurePolicy): Promise<Bridge> {
    const config = serviceConfiguration(input);
    if (failure !== "stop" && failure !== "block-input")
      throw new TypeError("Select an explicit failure policy");
    const activation = config.activation;
    const port = await openPort(
      {
        url: config.url,
        seed_file: activation.credential.seedFile,
        timeout_ms: config.timeoutMs,
        growing_server: {
          profile: config.profile,
          realm: activation.process.realm,
          principal: activation.credential.principal,
          pid: activation.process.pid,
          generation: activation.generation,
          association: config.association,
          timeout_ms: config.timeoutMs,
          failure_policy: failure === "stop" ? "stop" : "block_input",
          query_results: config.queryResults,
        },
      },
      config.nativeHost,
    );
    try {
      const caps = await Bridge.capabilities(port);
      if (config.queryResults && !caps.query_results)
        throw new UnsupportedCapability("Native query results are unavailable");
      const authority = await authorityCapabilities(port, activation.credential);
      if (!authority.associationLookup || !authority.scopedRetry || !authority.retainedVersions) {
        throw new UnsupportedCapability(
          "Authority lacks required growing state/recovery primitives",
        );
      }
      return new Bridge(port, caps);
    } catch (error) {
      await port.close();
      throw error;
    }
  }
  async prepare(): Promise<GrowingEvent> {
    return (await this.port.request(
      { growing_prepare: Date.now() + 30000 },
      { phase: "prepare-turn", validator: validation.GrowingEvent },
    )) as GrowingEvent;
  }
  async apply(scope: number, action: GrowingAction): Promise<GrowingResult> {
    return (await this.port.request(
      { growing_apply: { scope, action } },
      { phase: "apply", validator: validation.GrowingResult },
    )) as GrowingResult;
  }
  async documentCodec(action: DocumentCodecAction): Promise<DocumentCodecResult> {
    if (!this.caps.document_codecs)
      throw new UnsupportedCapability("Native Document codecs are unavailable");
    return (await this.port.request(
      { document_codec: action },
      { phase: "document-codec", validator: validation.DocumentCodecResult },
    )) as DocumentCodecResult;
  }
  async documentRead(action: DocumentReadAction): Promise<DocumentReadResult> {
    if (!this.caps.document_reads)
      throw new UnsupportedCapability("Native Document reads are unavailable");
    return (await this.port.request(
      { growing_document_read: action },
      { phase: "document-read", validator: validation.DocumentReadResult },
    )) as DocumentReadResult;
  }
  async httpCodec(action: HttpCodecAction): Promise<HttpCodecResult> {
    if (!this.caps.http_requests)
      throw new UnsupportedCapability("Native HTTP requests are unavailable");
    return (await this.port.request(
      { http_codec: action },
      {
        phase: "http-codec",
        validator: validation.HttpCodecResult,
      },
    )) as HttpCodecResult;
  }
  async httpRead(action: HttpReadAction): Promise<HttpReadResult> {
    if (!this.caps.http_replay)
      throw new UnsupportedCapability("Native HTTP replay is unavailable");
    return (await this.port.request(
      { growing_http_read: action },
      {
        phase: "http-read",
        validator: validation.HttpReadResult,
      },
    )) as HttpReadResult;
  }
  async grpcCodec(action: GrpcCodecAction): Promise<GrpcCodecResult> {
    if (!this.caps.grpc_requests)
      throw new UnsupportedCapability("Native RPC requests are unavailable");
    return (await this.port.request(
      { grpc_codec: action },
      {
        phase: "grpc-codec",
        validator: validation.GrpcCodecResult,
      },
    )) as GrpcCodecResult;
  }
  async grpcRead(action: GrpcReadAction): Promise<GrpcReadResult> {
    if (!this.caps.grpc_replay) throw new UnsupportedCapability("Native RPC replay is unavailable");
    return (await this.port.request(
      { growing_grpc_read: action },
      {
        phase: "grpc-read",
        validator: validation.GrpcReadResult,
      },
    )) as GrpcReadResult;
  }
  async finish(scope: number, failed: boolean): Promise<void> {
    await this.port.request({ growing_finish_result: { scope, failed } }, { phase: "finish" });
  }
  async discard(scope: number): Promise<void> {
    await this.port.request({ growing_discard: scope }, { phase: "discard" });
  }
  async pending(event: GrowingEvent): Promise<FrozenMutation> {
    const purpose = event.pending_kind;
    if (!purpose || !event.pending_input)
      throw new IncompatibleNative("Pending event lacks native mutation identity");
    const bytes = frozenBytes(
      await this.port.request({ growing_pending: {} }, { phase: "pending" }),
    );
    const info = await metadata(this.port, bytes);
    const commands = {
      permit: ["begin_turn"],
      open: ["open_view"],
      commit: ["turn", "turn_with_versions"],
    };
    if (
      info.kind !== "growing_command" ||
      info.profile !== "growing_v3" ||
      !info.command ||
      !commands[purpose].includes(info.command)
    ) {
      throw new IncompatibleNative("Pending native mutation does not match its framework purpose");
    }
    return new FrozenMutation(
      new OperationIdentity(info.identity),
      purpose,
      event.pending_input,
      bytes,
    );
  }
  async dispatch(): Promise<GrowingEvent> {
    return (await this.port.request(
      { growing_dispatch: {} },
      { phase: "dispatch", mutation: true, validator: validation.GrowingEvent },
    )) as GrowingEvent;
  }
  async confirmation(pending: FrozenMutation): Promise<GrowingEvent | undefined> {
    let event: GrowingEvent;
    try {
      event = (await this.port.request(
        { growing_confirmation: {} },
        { phase: "observe-confirmation", validator: validation.GrowingEvent },
      )) as GrowingEvent;
    } catch (error) {
      if (error instanceof TurnExpired) return undefined;
      throw error;
    }
    const confirmed = event.confirmation;
    return confirmed?.kind === pending.purpose && confirmed.input === pending.inputPosition
      ? event
      : undefined;
  }
  close(): Promise<void> {
    return this.port.close();
  }
}

type Tags<T> = T extends unknown ? keyof T : never;
export function result<K extends Tags<GrowingResult>>(
  value: GrowingResult,
  key: K,
): Extract<GrowingResult, Record<K, unknown>>[K] {
  if (!(key in value)) throw new IncompatibleNative("Unexpected native action result");
  return (value as Extract<GrowingResult, Record<K, unknown>>)[key];
}

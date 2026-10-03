import fixture from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { describe, expect, it } from "vite-plus/test";
import { text } from "./components";
import {
  validateCapabilities,
  validateRecords,
  validateHttp,
  validateGrpc,
  validateDocument,
  type DocumentResponse,
  type GrpcResponse,
  type HttpResponse,
  BoardError,
} from "@rey/transit-board-client";
import { message } from "./state";
describe("inspection semantics", () => {
  it("preserves bytes as text and refuses invalid UTF-8 previews", () => {
    expect(text("3c7363726970743e")).toBe("<script>");
    expect(text("ff")).toContain("binary");
  });
  it("distinguishes gaps and disconnection instead of inventing an empty state", () => {
    expect(message(new BoardError(409, "HistoryReclaimed"))).toContain("Retention");
    expect(message(new BoardError(409, "QueryExpired"))).toContain("cannot be combined");
    expect(message(new Error("offline"))).toContain("No new observation");
  });
  it("renders owned inspection detail and keeps the primary fallback for invalid detail", () => {
    const detail = structuredClone(fixture);
    detail.message = "Missing <capture> member; no complete observation.";
    const failure = new BoardError(409, "IncompleteResult", detail);
    detail.message = "replaced";
    expect(message(failure)).toContain("Missing <capture> member");
    expect(message(failure)).not.toContain("replaced");
    const malformed = new BoardError(409, "HistoryReclaimed", { code: "invented" });
    expect(malformed.diagnosticInvalid).toBe(true);
    expect(message(malformed)).toContain("Retention");
  });
  it("validates exact integer identity at the TypeScript boundary", () => {
    const caps = {
      version: 1,
      profile: "native_v1",
      query_enabled: false,
      realm: 9007199254740991,
      scope_pid: null,
      read_only: true,
      shared_principal: true,
      page_size: 8,
      scan_limit: 128,
      max_edges: 32,
      min_refresh_ms: 5000,
      max_request_bytes: 4096,
      state_resources: true,
      station: false,
      http_connector: false,
      grpc_connector: false,
      documents: false,
      reactive_table: false,
      push: false,
    };
    expect(validateCapabilities(caps)).toBe(true);
    expect(validateCapabilities({ ...caps, profile: "legacy_v2" })).toBe(false);
    expect(validateCapabilities({ ...caps, realm: 9007199254740992 })).toBe(false);
    expect(validateCapabilities({ ...caps, scope_pid: "1" })).toBe(false);
    expect(validateCapabilities({ ...caps, unexpected: true })).toBe(false);
  });
});

describe("exchange metadata boundary", () => {
  const page = () => ({
    version: 1,
    realm: 1,
    position: 20,
    resource: {
      id: 7,
      writer: 2,
      owner: null,
      revision: 18,
      entries: 1,
      deadline_ms: null,
      phase: "active",
      retired_at: null,
      history_ms: null,
      changed_ms: 0,
      last_turn: null,
    },
    page: {
      entries: [{ key: "0045", revision: 18 }, ...Array(7).fill(null)],
      next: null,
    },
    documents: Array(8).fill(null),
    queries: Array(8).fill(null),
    exchanges: [
      {
        version: 1,
        source: {
          realm: 1,
          pid: 2,
          resource: 7,
          key: "0045",
          entry_revision: 18,
          resource_revision: 18,
          position: 20,
        },
        declaration: {
          lineage: {
            exchange: "18446744073709551615",
            root: "1",
            parent: "1",
            ordinal: 2,
            reason: "retry",
            policy: "18446744073709551615",
            policy_revision: "7",
          },
        },
      },
      ...Array(7).fill(null),
    ],
  });
  it("preserves full-width identity and refuses narrowed or invented source evidence", () => {
    const valid = page();
    expect(validateRecords(valid)).toBe(true);
    for (const exchange of ["18446744073709551616", "01", "0", "1e3", 1]) {
      const changed = structuredClone(valid);
      changed.exchanges[0].declaration.lineage.exchange = exchange;
      expect(validateRecords(changed)).toBe(false);
    }
    const other = page();
    other.exchanges[0].source.resource = 8;
    expect(validateRecords(other)).toBe(false);
    const context = page();
    context.exchanges[0].declaration.lineage.context = "private";
    expect(validateRecords(context)).toBe(false);
  });
});

const captureFailure = (): NonNullable<HttpResponse["failure"]> => ({
  exchange: "18446744073709551615",
  resource: 3,
  owner: 2,
  principal: 4,
  input: 11,
  reason: "transport_failure",
  operation: "none",
  origin_input: 0,
  kind: 0,
  member: 0,
  chunk: 0,
  requested_bytes: 0,
  cause: "ConnectionResetByPeer",
  cause_truncated: false,
  phase: "capturing",
  effect: 7,
  attempt: 8,
  segments: 3,
  bytes: "1024",
});

describe("HTTP metadata boundary", () => {
  const prefix = "0045ffffffffffffffff";
  const member = (
    ordinal: number,
    kind: NonNullable<HttpResponse["policy"]>["member"]["kind"],
  ) => ({
    key: `${prefix}6d${ordinal.toString(16).padStart(8, "0")}`,
    ordinal,
    kind,
    bytes: 20,
    digest: Array(32).fill(1),
    chain: Array(32).fill(1),
  });
  const page = (): HttpResponse => ({
    version: 1,
    source: {
      realm: 1,
      pid: 2,
      resource: 3,
      key: `${prefix}6400000000`,
      entry_revision: 10,
      resource_revision: 12,
      position: 12,
    },
    exchange: "18446744073709551615",
    phase: "complete",
    coverage: Array(32).fill(1),
    failure: null,
    policy: {
      member: member(0, "request_template"),
      endpoint_revision: "18446744073709551615",
      tls: true,
      trust_digest: Array(32).fill(1),
      timeout_ms: 1000,
      request_bytes: "65536",
      response_bytes: "65536",
      method: "POST",
      retry: { id: "18446744073709551615", revision: "1" },
      redirect: null,
      reconcile: null,
      cancel: null,
    },
    terminal: {
      timing: {
        member: member(5, "timing"),
        started_ms: "1000",
        elapsed_ns: "18446744073709551615",
      },
      omission: { member: member(6, "omission"), response_headers: 1, request_secrets: 1 },
      completion: {
        member: member(7, "completion"),
        status: 200,
        request_bytes: "4",
        response_bytes: "1027",
        heads: 1,
        framing: "length",
      },
    },
  });
  it("preserves wide policy and time fields and refuses mismatched member evidence", () => {
    expect(validateHttp(page())).toBe(true);
    for (const invalid of ["18446744073709551616", "01", "-1", "1e3"]) {
      const changed = page();
      changed.terminal!.timing.elapsed_ns = invalid;
      expect(validateHttp(changed)).toBe(false);
    }
    const changed = page();
    changed.terminal!.omission.member.key = member(5, "omission").key;
    expect(validateHttp(changed)).toBe(false);
    const incomplete = page();
    incomplete.phase = "unknown";
    expect(validateHttp(incomplete)).toBe(false);
    incomplete.terminal = null;
    expect(validateHttp(incomplete)).toBe(false);
    incomplete.failure = captureFailure();
    expect(validateHttp(incomplete)).toBe(true);
    for (const invalid of [
      { resource: 4 },
      { owner: 3 },
      { exchange: "1" },
      { input: 13 },
      { phase: "complete" },
      { effect: 0 },
      { cause: null },
      { cause: "x".repeat(97) },
      { chunk: 1 },
      { reason: "recovered_incomplete" },
      { origin_input: 2 },
    ]) {
      expect(validateHttp({ ...incomplete, failure: { ...incomplete.failure, ...invalid } })).toBe(
        false,
      );
    }
    expect(validateHttp({ ...page(), raw_body: "private" })).toBe(false);
    const preparation = {
      ...incomplete,
      policy: null,
      failure: {
        ...captureFailure(),
        reason: "preparation_failure" as const,
        phase: "preparing" as const,
        cause: "HttpRequestTooLarge",
        origin_input: 8,
        effect: 0,
        attempt: 0,
      },
    };
    expect(validateHttp(preparation)).toBe(true);
    for (const invalid of [
      { origin_input: 0 },
      { origin_input: 13 },
      { phase: "ready" },
      { effect: 7, attempt: 8 },
      { cause: null },
      { operation: "append" },
    ]) {
      expect(
        validateHttp({ ...preparation, failure: { ...preparation.failure, ...invalid } }),
      ).toBe(false);
    }
    const narrowed = page();
    narrowed.policy!.retry!.id = "0";
    expect(validateHttp(narrowed)).toBe(false);
  });
});

describe("RPC metadata boundary", () => {
  const prefix = "0045ffffffffffffffff";
  const member = (
    ordinal: number,
    kind: NonNullable<GrpcResponse["policy"]>["member"]["kind"],
  ) => ({
    key: `${prefix}6d${ordinal.toString(16).padStart(8, "0")}`,
    ordinal,
    kind,
    bytes: 20,
    digest: Array(32).fill(1),
    chain: Array(32).fill(1),
  });
  const page = (): GrpcResponse => ({
    version: 1,
    source: {
      realm: 1,
      pid: 2,
      resource: 3,
      key: `${prefix}6400000000`,
      entry_revision: 10,
      resource_revision: 12,
      position: 12,
    },
    exchange: "18446744073709551615",
    phase: "complete",
    coverage: Array(32).fill(1),
    failure: null,
    policy: {
      member: member(2, "endpoint_policy"),
      endpoint_revision: "18446744073709551615",
      tls: true,
      trust_digest: Array(32).fill(1),
      timeout_ms: 1000,
      limits: {
        request_messages: 64,
        response_messages: 64,
        message_bytes: 16384,
        request_bytes: 65536,
        response_bytes: 262144,
        metadata_bytes: 8192,
      },
      shape: "bidi",
      descriptor_digest: Array(32).fill(1),
      retry: { id: "1", revision: "1" },
    },
    half_close: { member: member(3, "half_close"), messages: 2, wire_bytes: 10 },
    response_message_records: 2,
    response_body_bytes: "0",
    terminal: {
      timing: {
        member: member(5, "timing"),
        started_ms: "1000",
        elapsed_ns: "18446744073709551615",
      },
      omission: { member: member(6, "omission"), response_fields: 1, request_secrets: 1 },
      completion: {
        member: member(7, "completion"),
        status: 0,
        sent_messages: 2,
        received_messages: 2,
        sent_bytes: 10,
        received_bytes: 10,
        half_closed: true,
      },
    },
  });
  it("preserves OK, empty messages and wide identities while refusing inconsistent evidence", () => {
    expect(validateGrpc(page())).toBe(true);
    for (const change of [
      (p: GrpcResponse) => {
        p.terminal!.completion.status = 17;
      },
      (p: GrpcResponse) => {
        p.terminal!.timing.elapsed_ns = "18446744073709551616";
      },
      (p: GrpcResponse) => {
        p.half_close!.messages = 1;
      },
      (p: GrpcResponse) => {
        p.response_body_bytes = "1";
      },
      (p: GrpcResponse) => {
        p.terminal!.completion.member.chain[0] = 2;
      },
      (p: GrpcResponse) => {
        p.policy!.member.key = member(1, "endpoint_policy").key;
      },
      (p: GrpcResponse) => {
        p.source.key = "0045";
      },
      (p: GrpcResponse) => {
        p.phase = "unknown";
      },
    ]) {
      const changed = page();
      change(changed);
      expect(validateGrpc(changed)).toBe(false);
    }
    const partial = page();
    partial.phase = "unknown";
    partial.terminal = null;
    expect(validateGrpc(partial)).toBe(false);
    partial.failure = captureFailure();
    expect(validateGrpc(partial)).toBe(true);
    expect(validateGrpc({ ...page(), protobuf: "private" })).toBe(false);
    expect(
      validateGrpc({ ...page(), policy: { ...page().policy, method: "/private.Method" } }),
    ).toBe(false);
  });
});

describe("Document metadata boundary", () => {
  const page = (): DocumentResponse => ({
    version: 1,
    source: {
      realm: 1,
      pid: 2,
      resource: 3,
      key: "0044ffffffffffffffff680000000000000000",
      entry_revision: 9,
      resource_revision: 10,
      position: 12,
    },
    declaration: {
      document: "18446744073709551615",
      epoch: "2",
      type_revision: 1,
      change_format: 1,
      revision: "5",
      floor: "4",
      merge_window: "2",
      active_job: "0",
      retired: false,
    },
    registers: {
      count: 8,
      conflicts: 1,
      assignments: 9,
      next: "52" + "0000000000000001".repeat(2),
    },
  });
  it("keeps bounded counts distinct from values, retention gaps and retirement", () => {
    expect(validateDocument(page())).toBe(true);
    for (const document of ["18446744073709551616", "01", "0", "1e3"]) {
      const bad = page();
      bad.declaration.document = document;
      expect(validateDocument(bad)).toBe(false);
    }
    const floor = page();
    floor.declaration.floor = "6";
    expect(validateDocument(floor)).toBe(false);
    const count = page();
    count.registers!.count = 9;
    expect(validateDocument(count)).toBe(false);
    const source = page();
    source.source.key = "00440000000000000001680000000000000000";
    expect(validateDocument(source)).toBe(false);
    const retired = page();
    retired.declaration.retired = true;
    expect(validateDocument(retired)).toBe(false);
    retired.registers = null;
    expect(validateDocument(retired)).toBe(true);
    expect(validateDocument({ ...page(), text: "private body" })).toBe(false);
  });
});

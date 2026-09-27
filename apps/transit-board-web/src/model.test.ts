import { describe, expect, it } from "vite-plus/test";
import { text } from "./components";
import {
  validateCapabilities,
  validateQuery,
  validateRecords,
  type QueryResponse,
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
  it("validates exact integer identity at the TypeScript boundary", () => {
    const caps = {
      version: 1,
      profile: "legacy_v2",
      query_enabled: false,
      realm: 9007199254740991,
      scope_pid: null,
      read_only: true,
      shared_principal: true,
      page_size: 16,
      scan_limit: 128,
      max_edges: 32,
      min_refresh_ms: 5000,
      max_request_bytes: 4096,
      state_resources: true,
      station: false,
      http_connector: false,
      push: false,
    };
    expect(validateCapabilities(caps)).toBe(true);
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
    },
    page: {
      entries: [{ key: "0045", revision: 18 }, ...Array(7).fill(null)],
      next: null,
    },
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

describe("typed query boundary", () => {
  const page = (): Extract<QueryResponse, { page: unknown }>["page"] => ({
    version: 1,
    manifest: {
      result: 20,
      destination: 8,
      correlation: 10,
      table: 1,
      policy_revision: 1,
      basis: { resource: 3, revision: 15, schema: Array(32).fill(0) },
      plan: Array(32).fill(0),
      segments: 1,
      bytes: 288,
      rows: 1,
      chain: Array(32).fill(0),
      schema: Array(32).fill(0),
    },
    ordinal: 0,
    columns: [{ name: "value", type: "int64", nullable: true }, null],
    rows: [[{ int64: "9223372036854775807" }, null], ...Array(31).fill(null)],
    count: 1,
    next: null,
  });
  it("preserves full-width values and rejects overflow, wrong types and row gaps", () => {
    const value = page();
    expect(validateQuery({ page: value })).toBe(true);
    value.rows[0]![0] = { int64: "9223372036854775808" };
    expect(validateQuery({ page: value })).toBe(false);
    value.rows[0]![0] = { utf8: "9223372036854775807" };
    expect(validateQuery({ page: value })).toBe(false);
    value.rows[0]![0] = { null: {} };
    expect(validateQuery({ page: value })).toBe(true);
    value.rows[1] = value.rows[0]!;
    value.rows[0] = null;
    expect(validateQuery({ page: value })).toBe(false);
  });
  it("rejects invented continuation and malformed text", () => {
    const value = page();
    value.next = 1;
    expect(validateQuery({ page: value })).toBe(false);
    value.next = null;
    value.columns[0]!.type = "utf8";
    value.rows[0]![0] = { utf8: "\ud800" };
    expect(validateQuery({ page: value })).toBe(false);
    value.rows[0]![0] = { utf8: "🙂" };
    expect(validateQuery({ page: value })).toBe(true);
  });
});

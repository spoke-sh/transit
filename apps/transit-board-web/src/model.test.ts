import { describe, expect, it } from "vite-plus/test";
import { text } from "./components";
import {
  validateCapabilities,
  validateQuery,
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

import { describe, expect, it } from "vite-plus/test";
import { text } from "./components";
import { validateCapabilities, BoardError } from "@rey/transit-board-client";
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
      realm: 9007199254740991,
      scope_pid: null,
      read_only: true,
      shared_principal: true,
      page_size: 16,
      scan_limit: 128,
      max_edges: 32,
      min_refresh_ms: 5000,
      max_request_bytes: 4096,
      session_seconds: 900,
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

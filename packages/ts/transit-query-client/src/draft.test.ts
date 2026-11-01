import { afterEach, expect, test, vi } from "vite-plus/test";
import { DraftSession } from "./draft";
import { prepareCapture } from "./capture";
import { QueryError, type Transport } from "./transport";
import type { Draft, Request, Response } from "./types";
import type { ResultPage } from "./result";

afterEach(() => vi.useRealTimers());
const contract = Array(32).fill(1);
const limits = { pages: "8", segments: "8", result_bytes: "65536" };
const source = {
  version: 1,
  resource: 4,
  source: {
    table: {
      scope: { realm: 1, resource: 4, catalog: "1" },
      owner: 3,
      object: "1",
      branch: "1",
      namespace: 1,
      interpretation: {
        revision: "1",
        bytes: "200",
        digest: Array(32).fill(1),
        schema: Array(32).fill(2),
      },
      collations: ["none" as const, "none" as const],
      semantics: [
        { rounding: null, metric: null, timezone: null, spatial: null },
        { rounding: null, metric: null, timezone: null, spatial: null },
      ],
      historical: null,
      projection: null,
      row_type: {
        structure: [
          { name: "id", type: { int64: {} }, nullable: false, optional: false },
          { name: "value", type: { int64: {} }, nullable: true, optional: false },
        ],
      },
    },
  },
};
const compiled: Extract<Response, { compiled: unknown }>["compiled"] = {
  bundle: "00",
  source,
  limits,
  contract,
  schema: Array(32).fill(2),
  plan: {
    version: 1,
    collations: null,
    scalar_program: "00",
    projection: [1],
    output_names: null,
    limit: "1",
    aggregate: "rows",
    predicate: { all: {} },
  },
};
const page: ResultPage = {
  cells: [[{ value: { atom: { signed: "7" } } }]],
  evidence: {
    columns: [{ name: "value", type: { int64: {} }, nullable: true, optional: false }],
    ordinal: "0",
    rows: 1,
    ipc: "00",
    next: null,
    manifest: {
      job: 1,
      source: { table: { worker: 3 } },
      requester: 5,
      correlation: "10",
      policy_revision: "1",
      request: "00",
      basis: {
        cut: { resource: 4, kind: "table", position: { table: Array(32).fill(1) } },
        contract,
        schema: compiled.schema,
      },
      table_position: {
        resource: 4,
        partition: "1",
        accepted: "7",
        contract,
        schema: compiled.schema,
      },
      plan: Array(32).fill(3),
      pages: "1",
      scanned: "1",
      selected: "1",
      value_count: "0",
      segments: "1",
      rows: "1",
      bytes: "1",
      sum: null,
      finished: "source_end",
      chain: Array(32).fill(4),
    },
  },
};
// Scheduling fixture only: native decoding, authority, budgets and result bytes
// are qualified separately by the actual Table host/browser proof.
function fixture(role: number | null = null) {
  let budget: Draft | null = null;
  let sequence = 0;
  let input = 100;
  let held = 0;
  const commands = new Map<string, Request>();
  const receipts = new Map<string, number>();
  const jobs = new Set<string>();
  const cancelled = new Set<string>();
  const compiledSql: string[] = [];
  const captures: Extract<Request, { capture: unknown }>["capture"][] = [];
  const submitted: string[] = [];
  const controls: Request[] = [];
  const faults = { lose: false, deny: false, captureDeny: false, ready: true, reject: false };
  const prepare = (request: Request): Response => {
    const token = String(++sequence);
    commands.set(token, structuredClone(request));
    return { prepared: { token } };
  };
  const transport: Transport = async (request) => {
    if ("describe" in request)
      return {
        description: {
          connection: {
            realm: 1,
            principal: 2,
            role,
            source: 3,
            resource: 4,
            requester: 5,
            requests: 6,
          },
          name: "items",
          budgets: limits,
          source: {
            source,
            active: null,
            resource_revision: 1,
            policy_revision: "1",
            limits,
            capabilities: {
              version: 1,
              source: 1,
              plan: 1,
              result: 1,
              bundle_bytes: 25743,
              part_bytes: 128,
              segment_bytes: 65536,
              batch_rows: 8,
              columns: 128,
              kv: true,
              table: true,
              document: true,
            },
          },
          sql: {
            version: 1,
            statement_bytes: 4096,
            named_columns: 128,
            star_columns: 128,
            uint64_limits: true,
            uint64_literals: false,
            float64_literals: false,
            null_comparison: false,
            explicit_null_test: true,
            writes: false,
            continuous: false,
          },
          columns: [
            { name: "id", type: { int64: {} }, nullable: true, optional: false },
            { name: "value", type: { int64: {} }, nullable: true, optional: false },
          ],
        },
      };
    if ("draft_status" in request) return { draft: structuredClone(budget) };
    if ("draft_open" in request || "draft_close" in request || "prepare_control" in request)
      return prepare(request);
    if ("compile" in request) {
      if (faults.deny) throw new QueryError(403, "Forbidden");
      compiledSql.push(request.compile.sql);
      if (request.compile.sql === "incomplete") throw new QueryError(400, "UnsupportedQuery");
      return { compiled: structuredClone(compiled) };
    }
    if ("capture" in request) {
      if (faults.deny || faults.captureDeny) throw new QueryError(403, "Forbidden");
      captures.push(structuredClone(request.capture));
      return { compiled: { ...structuredClone(compiled), bundle: "01" } };
    }
    if ("next_draft" in request) {
      expect(request.next_draft.bundle).toBe("01");
      return jobs.has(request.next_draft.namespace) ? { prepared: null } : prepare(request);
    }
    if ("submit" in request) {
      const token = request.submit.token;
      submitted.push(token);
      let position = receipts.get(token);
      if (!position) {
        const command = commands.get(token)!;
        controls.push(command);
        position = ++input;
        receipts.set(token, position);
        if ("draft_open" in command)
          budget = {
            generation: String(BigInt(command.draft_open.expected) + 1n),
            starts: 0,
            limit: command.draft_open.limit,
            enabled: true,
            contract,
            budgets: limits,
            namespaces: Array(8).fill("0"),
          };
        if ("draft_close" in command) budget!.enabled = false;
        if ("prepare_control" in command) cancelled.add(command.prepare_control.namespace);
        if ("next_draft" in command) {
          jobs.add(command.next_draft.namespace);
          budget!.namespaces[budget!.starts++] = command.next_draft.namespace;
        }
      }
      if (faults.lose) {
        faults.lose = false;
        throw new Error("lost reply");
      }
      return { receipt: { position } };
    }
    if ("observe" in request)
      return { observation: faults.reject ? { rejected: "64656e696564" } : { committed: {} } };
    if ("status" in request)
      return {
        status: jobs.has(request.status)
          ? {
              reference: "00",
              phase: cancelled.has(request.status)
                ? "cancelled"
                : faults.ready
                  ? "complete"
                  : "admitted",
              correlation: "10",
              manifest: null,
              collected: cancelled.has(request.status),
              failure: null,
              diagnostic: null,
            }
          : null,
      };
    if ("page" in request) {
      if (faults.deny) throw new QueryError(403, "Forbidden");
      return { page: structuredClone(page) };
    }
    throw new Error("Unexpected fixture request");
  };
  const session = new DraftSession(transport, async () => {
    held++;
    return () => {
      held--;
    };
  });
  return {
    transport,
    session,
    faults,
    controls,
    compiledSql,
    captures,
    submitted,
    held: () => held,
    budget: () => budget,
  };
}
async function advance(ms = 8000) {
  await vi.advanceTimersByTimeAsync(ms);
}

test("edits are inert until opt-in and only the newest complete draft consumes the finite generation", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.session.edit("SELECT value FROM items LIMIT 1");
  await advance();
  expect(f.controls).toHaveLength(0);
  await f.session.open(2);
  f.session.edit("discarded edit");
  f.session.edit("SELECT id FROM items LIMIT 1");
  await advance();
  expect(f.compiledSql).toEqual(["SELECT id FROM items LIMIT 1"]);
  expect(f.session.getSnapshot().result?.sql).toBe(f.compiledSql[0]);
  f.session.edit("incomplete");
  f.session.edit("SELECT value FROM items LIMIT 1");
  await advance();
  expect(f.session.getSnapshot().phase).toBe("exhausted");
  expect(f.budget()?.starts).toBe(2);
  f.session.edit("SELECT * FROM items LIMIT 1");
  await advance();
  expect(f.compiledSql).toHaveLength(2);
  expect(f.captures).toHaveLength(2);
  expect(f.captures.map((capture) => capture.operation)).toEqual(
    f.budget()!.namespaces.slice(0, 2),
  );
  expect(f.controls.filter((request) => "draft_open" in request)).toHaveLength(1);
  expect(f.held()).toBe(0);
});

test("a restored uncertain draft upload retains its capture without compiling or signing again", async () => {
  vi.useFakeTimers();
  const f = fixture();
  await f.session.open(2);
  await advance();
  f.faults.lose = true;
  f.session.edit("SELECT id FROM items");
  await advance();
  expect(f.session.getSnapshot().phase).toBe("uncertain");
  expect(f.captures).toHaveLength(1);
  const saved = f.session.exportRecovery();
  expect(JSON.parse(saved).job.compiled.bundle).toBe("01");
  const original = f.submitted.at(-1);
  const restored = new DraftSession(f.transport, async () => () => {});
  restored.restoreRecovery(saved);
  restored.recover();
  await advance();
  expect(f.submitted.at(-1)).toBe(original);
  expect(f.captures).toHaveLength(1);
  expect(f.compiledSql).toEqual(["SELECT id FROM items"]);
  expect(f.controls.filter((request) => "next_draft" in request)).toHaveLength(1);
});

test("denied capture authorization cannot dispatch a compiled draft", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.faults.captureDeny = true;
  f.session.edit("SELECT id FROM items");
  await f.session.open(2);
  await advance();
  expect(f.session.getSnapshot().phase).toBe("denied");
  expect(f.session.getSnapshot().acceptedWork).toBe(false);
  expect(f.budget()?.starts).toBe(0);
  expect(f.controls.filter((request) => "next_draft" in request)).toHaveLength(0);
});

test("capture authorization refuses a changed source, plan or budget", async () => {
  for (const field of ["source", "plan", "limits", "contract", "schema"] as const) {
    const changed = structuredClone(compiled);
    if (field === "source") changed.source.resource++;
    else if (field === "plan") changed.plan.limit = "2";
    else if (field === "limits") changed.limits.pages = "9";
    else changed[field][0] = 7;
    await expect(
      prepareCapture(async () => ({ compiled: changed }), compiled, "123"),
    ).rejects.toMatchObject({ code: "CaptureScopeChanged" });
  }
});

test("saved unknown controls restore exact tokens and cannot import changed plan identities", async () => {
  vi.useFakeTimers();
  const f = fixture(19);
  f.faults.lose = true;
  await f.session.open(2);
  await advance();
  const saved = f.session.exportRecovery();
  const restored = new DraftSession(f.transport, async () => () => {});
  expect(JSON.parse(saved).connection.role).toBe(19);
  const legacy = JSON.parse(saved);
  delete legacy.connection.role;
  expect(() => restored.restoreRecovery(JSON.stringify(legacy))).toThrow("InvalidDraftRecovery");
  const invalidRole = JSON.parse(saved);
  invalidRole.connection.role = 0;
  expect(() => restored.restoreRecovery(JSON.stringify(invalidRole))).toThrow(
    "InvalidDraftRecovery",
  );
  const changed = JSON.parse(saved);
  changed.intent.generation = "2";
  expect(() => restored.restoreRecovery(JSON.stringify(changed))).toThrow("InvalidDraftRecovery");
  restored.restoreRecovery(saved);
  expect(restored.getSnapshot().phase).toBe("paused");
  expect(restored.getSnapshot().result).toBeNull();
  restored.recover();
  await advance();
  expect(f.submitted).toEqual([f.submitted[0], f.submitted[0]]);
  expect(f.controls.filter((request) => "draft_open" in request)).toHaveLength(1);
  expect(restored.getSnapshot().budget?.generation).toBe("1");
  expect(restored.getSnapshot().recoverable).toBe(false);
});

test("lost admission keeps the caller gate and recovers the same token without opening another generation", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.faults.lose = true;
  await f.session.open(2);
  await advance();
  expect(f.session.getSnapshot().phase).toBe("uncertain");
  expect(f.session.getSnapshot().recoverable).toBe(true);
  expect(f.held()).toBe(1);
  f.session.edit("SELECT id FROM items");
  await advance();
  expect(f.submitted).toHaveLength(1);
  f.session.recover();
  await advance();
  expect(f.submitted).toEqual([f.submitted[0], f.submitted[0]]);
  expect(f.controls.filter((request) => "draft_open" in request)).toHaveLength(1);
  expect(f.compiledSql).toHaveLength(0);
  expect(f.session.getSnapshot().phase).toBe("paused");
  expect(f.held()).toBe(0);
});

test("pause closes native scheduling, and a known rejection cannot turn into repeated reconnect", async () => {
  vi.useFakeTimers();
  const f = fixture();
  await f.session.open(2);
  await advance();
  f.session.pause();
  await expect(f.session.open(2)).rejects.toThrow("RecoverAcceptedDraftFirst");
  f.session.edit("SELECT id FROM items");
  await advance();
  expect(f.budget()?.enabled).toBe(false);
  expect(f.compiledSql).toHaveLength(0);
  expect(f.session.getSnapshot().phase).toBe("paused");
  f.faults.reject = true;
  await f.session.open(2);
  await advance();
  const count = f.submitted.length;
  expect(f.session.getSnapshot().phase).toBe("failed");
  expect(f.session.getSnapshot().recoverable).toBe(false);
  await advance();
  expect(f.submitted).toHaveLength(count);
});

test("current denial clears the prior result while an incomplete draft never dispatches", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.session.edit("SELECT id FROM items");
  await f.session.open(3);
  await advance();
  expect(f.session.getSnapshot().result).not.toBeNull();
  f.session.edit("incomplete");
  await advance();
  expect(f.budget()?.starts).toBe(1);
  expect(f.session.getSnapshot().phase).toBe("failed");
  // Resume is explicit and observes the same remaining budget.
  f.faults.deny = true;
  f.session.edit("SELECT value FROM items");
  await f.session.open(3);
  await advance();
  expect(f.session.getSnapshot().phase).toBe("denied");
  expect(f.session.getSnapshot().result).toBeNull();
  expect(f.budget()?.starts).toBe(1);
});

test("edits during accepted work coalesce without replacing that job or mixing result identities", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.faults.ready = false;
  const shown: string[] = [];
  const unsubscribe = f.session.subscribe(() => {
    const result = f.session.getSnapshot().result;
    if (result && shown.at(-1) !== result.sql) shown.push(result.sql);
  });
  f.session.edit("original");
  await f.session.open(2);
  await advance();
  const first = f.session.getSnapshot().namespace;
  f.session.edit("discarded intermediate");
  f.session.edit("newest");
  await advance();
  expect(f.compiledSql).toEqual(["original"]);
  expect(f.session.getSnapshot().namespace).toBe(first);
  f.faults.ready = true;
  await advance(12000);
  expect(f.compiledSql).toEqual(["original", "newest"]);
  expect(shown).toEqual(["original", "newest"]);
  expect(f.session.getSnapshot().namespace).not.toBe(first);
  unsubscribe();
});

test("pause preserves accepted work and explicit cancellation settles it without refunding the budget", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.faults.ready = false;
  f.session.edit("SELECT id FROM items");
  await f.session.open(2);
  await advance();
  const first = f.session.getSnapshot().namespace;
  f.session.pause();
  await advance();
  expect(f.session.getSnapshot().acceptedWork).toBe(true);
  expect(f.budget()?.enabled).toBe(false);
  await expect(f.session.open(2)).rejects.toMatchObject({ code: "RecoverAcceptedDraftFirst" });
  f.session.cancel();
  await advance();
  expect(f.session.getSnapshot().acceptedWork).toBe(false);
  expect(f.session.getSnapshot().namespace).toBe(first);
  expect(f.budget()?.starts).toBe(1);
});

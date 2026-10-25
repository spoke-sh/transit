import { expect, test } from "vite-plus/test";
import { RefreshPreparation } from "./refresh";
import type { Request, Response } from "./types";
import type { Transport } from "./transport";
import { validateUnifiedQuery } from "./values";

function compiled(operation: string): Extract<Response, { compiled: unknown }>["compiled"] {
  return {
    bundle: BigInt(operation).toString(16).padStart(16, "0"),
    source: {
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
          row_type: {
            structure: [{ name: "value", type: { int64: {} }, nullable: false, optional: false }],
          },
        },
      },
    },
    limits: { pages: "8", segments: "8", result_bytes: "65536" },
    contract: Array(32).fill(1),
    schema: Array(32).fill(2),
    plan: {
      version: 1,
      projection: [0],
      output_names: null,
      limit: "1",
      aggregate: "rows",
      predicate: { all: {} },
    },
  };
}

// A caller-state fixture: native signatures, uploads and query execution have
// separate proofs. Opaque bundles/tokens here expose accidental replacement.
function fixture(persist?: (owner: RefreshPreparation) => void) {
  const connection = {
    realm: 1,
    principal: 2,
    role: null as number | null,
    source: 3,
    resource: 4,
    requester: 5,
    requests: 6,
  };
  const controls: Request[] = [];
  const tokens = new Map<string, string>();
  const receipts = new Map<string, number>();
  const ready = new Set<string>();
  const faults = { lost: false, pending: false, rejected: false, used: false };
  let held = 0;
  const transport: Transport = async (request) => {
    controls.push(structuredClone(request));
    if ("describe" in request)
      return { description: { connection: structuredClone(connection) } } as Response;
    if ("refresh" in request) return { compiled: compiled(request.refresh.operation) };
    if ("next" in request) {
      expect(request.next.prepare_only).toBe(true);
      if (ready.has(request.next.namespace)) return { prepared: null };
      const token = `frozen:${tokens.size}`;
      tokens.set(token, request.next.namespace);
      return { prepared: { token } };
    }
    if ("submit" in request) {
      const token = request.submit.token;
      if (!receipts.has(token)) {
        receipts.set(token, receipts.size + 1);
        ready.add(tokens.get(token)!);
      }
      // Mutation of the transport's argument must not corrupt retained bytes.
      request.submit.token = "mutated transport argument";
      if (faults.lost) {
        faults.lost = false;
        throw new Error("lost receipt");
      }
      return { receipt: { position: receipts.get(token)! } };
    }
    if ("observe" in request)
      return {
        observation: faults.pending
          ? { pending: {} }
          : faults.rejected
            ? { rejected: "64656e696564" }
            : { committed: {} },
      };
    if ("recover_preparation" in request) {
      expect(tokens.get(request.recover_preparation.token)).toBe(
        request.recover_preparation.namespace,
      );
      const position = receipts.get(request.recover_preparation.token);
      return { recovered_preparation: position ? { position } : null } as Response;
    }
    if ("status" in request)
      return { status: { phase: faults.used ? "admitted" : "prepared" } } as Response;
    throw new Error("Unexpected refresh operation");
  };
  const owner = new RefreshPreparation(
    transport,
    async () => {
      ++held;
      return () => {
        --held;
      };
    },
    () => persist?.(owner),
  );
  const prepare = (key = "start", template = "1", limit = 2) =>
    owner.prepare(key, template, limit, new AbortController().signal);
  return { owner, prepare, connection, controls, receipts, faults, transport, held: () => held };
}

test("Follow prepares distinct bounded captures without activating any query", async () => {
  const f = fixture();
  const captures = await f.prepare();
  expect(captures).toHaveLength(8);
  expect(new Set(captures.slice(0, 2)).size).toBe(2);
  expect(captures.slice(2)).toEqual(Array(6).fill("0"));
  const signed = f.controls.flatMap((r) => ("refresh" in r ? [r.refresh.operation] : []));
  expect(new Set([...captures.slice(0, 2), ...signed, "1"]).size).toBe(5);
  expect(f.held()).toBe(0);
  expect(f.owner.uncertain).toBe(false);
  const before = f.receipts.size;
  expect(await f.prepare()).toEqual(captures);
  expect(f.receipts.size).toBe(before);
  expect(await f.prepare("new start")).not.toEqual(captures);
});

test("lost submission preserves the original token, signature, namespace and caller lease", async () => {
  const f = fixture();
  f.faults.lost = true;
  await expect(f.prepare()).rejects.toThrow("lost receipt");
  expect(f.owner.uncertain).toBe(true);
  expect(f.held()).toBe(1);
  const before = f.controls.length;
  await expect(f.prepare("different", "2")).rejects.toThrow("RecoverRefreshPreparationFirst");
  expect(f.controls.slice(before).every((r) => "describe" in r)).toBe(true);
  await f.prepare("explicit retry");
  const submitted = f.controls.flatMap((r) => ("submit" in r ? [r.submit.token] : []));
  expect(submitted).toEqual(["frozen:0", "frozen:0", "frozen:1"]);
  expect(f.controls.filter((r) => "refresh" in r)).toHaveLength(2);
  expect(f.receipts.size).toBe(2);
  expect(f.held()).toBe(0);
  expect(f.owner.uncertain).toBe(false);
});

test("accepted pending work is observed without another submission or signature", async () => {
  const f = fixture();
  f.faults.pending = true;
  await expect(f.prepare()).rejects.toThrow("RefreshPreparationPending");
  expect(f.held()).toBe(0);
  const before = f.controls.length;
  await expect(f.prepare()).rejects.toThrow("RefreshPreparationPending");
  expect(f.controls.slice(before)).toEqual([{ describe: {} }, { observe: 1 }]);
  f.faults.pending = false;
  await f.prepare();
  expect(f.controls.filter((r) => "submit" in r)).toHaveLength(2);
});

test("scope changes cannot transfer an uncertain operation to a different caller", async () => {
  const f = fixture();
  f.faults.lost = true;
  await expect(f.prepare()).rejects.toThrow();
  f.connection.principal = 10;
  const before = f.controls.length;
  await expect(f.prepare()).rejects.toThrow("RefreshScopeChanged");
  expect(f.controls.slice(before)).toEqual([{ describe: {} }]);
  expect(f.held()).toBe(1);
  f.connection.principal = 2;
  await f.prepare();
  expect(f.held()).toBe(0);
});

test("rejection and an already activated request do not become prepared captures", async () => {
  for (const fault of ["rejected", "used"] as const) {
    const f = fixture();
    f.faults[fault] = true;
    await expect(f.prepare()).rejects.toThrow(
      fault === "rejected" ? "RefreshPreparationRejected" : "RefreshRequestAlreadyUsed",
    );
    expect(f.held()).toBe(0);
    expect(f.controls.filter((r) => "refresh" in r)).toHaveLength(1);
  }
});

test.each([
  ["0", 1],
  ["01", 1],
  ["18446744073709551616", 1],
  ["1", 0],
  ["1", 9],
  ["1", 1.5],
] as const)("invalid template %s or budget %s cannot prepare work", async (template, limit) => {
  const f = fixture();
  await expect(f.prepare("start", template, limit)).rejects.toThrow("InvalidRefreshPreparation");
  expect(f.controls).toEqual([]);
});

test.each(["lost", "pending"] as const)(
  "reload recovers %s work without replacement grants or tokens",
  async (fault) => {
    const f = fixture();
    expect(validateUnifiedQuery({ compiled: compiled("1") })).toBe(true);
    f.faults[fault] = true;
    await expect(f.prepare()).rejects.toThrow();
    const saved = f.owner.exportRecovery();
    const restored = new RefreshPreparation(f.transport, async () => () => {});
    const before = f.controls.length;
    restored.restoreRecovery(saved);
    expect(f.controls.length).toBe(before);
    expect(restored.uncertain).toBe(true);
    f.faults.pending = false;
    await restored.prepare("start", "1", 2, new AbortController().signal);
    const submitted = f.controls.flatMap((r) => ("submit" in r ? [r.submit.token] : []));
    expect(submitted).toEqual(["frozen:0", "frozen:1"]);
    expect(f.controls.filter((r) => "refresh" in r)).toHaveLength(2);
    expect(f.receipts.size).toBe(2);
  },
);

test("saved readiness is rechecked and an activated capture cannot reopen after reload", async () => {
  const f = fixture();
  await f.prepare();
  const saved = f.owner.exportRecovery();
  f.faults.used = true;
  const restored = new RefreshPreparation(f.transport);
  restored.restoreRecovery(saved);
  const before = f.controls.length;
  await expect(restored.prepare("start", "1", 2, new AbortController().signal)).rejects.toThrow(
    "RefreshRequestAlreadyUsed",
  );
  expect(f.controls.slice(before).some((r) => "submit" in r || "refresh" in r)).toBe(false);
});

test("an altered saved input cannot settle a different preparation upload", async () => {
  const f = fixture();
  f.faults.pending = true;
  await expect(f.prepare()).rejects.toThrow("RefreshPreparationPending");
  const saved = JSON.parse(f.owner.exportRecovery());
  saved.pending.input = 99;
  const recovered = new RefreshPreparation(f.transport, async () => () => {});
  recovered.restoreRecovery(JSON.stringify(saved));
  const before = f.controls.length;
  await expect(recovered.prepare("start", "1", 2, new AbortController().signal)).rejects.toThrow(
    "RefreshRecoveryChanged",
  );
  expect(f.controls.slice(before).map((request) => Object.keys(request)[0])).toEqual([
    "describe",
    "recover_preparation",
  ]);
  expect(recovered.uncertain).toBe(true);
});

test("a failed durable save cannot dispatch or replace the prepared token", async () => {
  let fail = true;
  let token: unknown;
  const f = fixture((owner) => {
    const saved = JSON.parse(owner.exportRecovery());
    if (saved.pending && fail) {
      token = saved.pending.token;
      throw new Error("storage full");
    }
  });
  await expect(f.prepare()).rejects.toThrow("storage full");
  expect(f.controls.some((request) => "submit" in request)).toBe(false);
  expect(JSON.parse(f.owner.exportRecovery()).pending.token).toEqual(token);
  fail = false;
  await f.prepare();
  expect(f.controls.filter((request) => "refresh" in request)).toHaveLength(2);
  expect(f.receipts.size).toBe(2);
});

test("reload cannot move accepted preparation to a different connection", async () => {
  const f = fixture();
  f.faults.pending = true;
  await expect(f.prepare()).rejects.toThrow();
  const restored = new RefreshPreparation(f.transport);
  restored.restoreRecovery(f.owner.exportRecovery());
  f.connection.role = 10;
  const before = f.controls.length;
  await expect(restored.prepare("start", "1", 2, new AbortController().signal)).rejects.toThrow(
    "RefreshScopeChanged",
  );
  expect(f.controls.slice(before)).toEqual([{ describe: {} }]);
  expect(restored.uncertain).toBe(true);
});

test("malformed recovery cannot replace retained work or dispatch saved bytes", async () => {
  const f = fixture();
  f.faults.pending = true;
  await expect(f.prepare()).rejects.toThrow();
  const saved = JSON.parse(f.owner.exportRecovery());
  const invalid = [
    "{",
    " ".repeat(1048577),
    ...[
      { ...saved, version: 2 },
      { ...saved, pending: { ...saved.pending, namespace: saved.work.slots[1].namespace } },
      { ...saved, pending: { ...saved.pending, input: 1.5 } },
      { ...saved, work: { ...saved.work, slots: Array(9).fill(saved.work.slots[0]) } },
      {
        ...saved,
        work: {
          ...saved.work,
          slots: [{ ...saved.work.slots[0], ready: true }, saved.work.slots[1]],
        },
      },
      {
        ...saved,
        work: {
          ...saved.work,
          slots: [{ ...saved.work.slots[0], compiled: { bundle: "00" } }, saved.work.slots[1]],
        },
      },
    ].map((value) => JSON.stringify(value)),
  ];
  const before = f.controls.length;
  for (const value of invalid) {
    const restored = new RefreshPreparation(f.transport);
    expect(() => restored.restoreRecovery(value)).toThrow("InvalidRefreshRecovery");
    expect(() => restored.exportRecovery()).toThrow("NoRefreshRecovery");
  }
  expect(() => f.owner.restoreRecovery(JSON.stringify(saved))).toThrow(
    "RefreshRecoveryUnavailable",
  );
  expect(f.controls.length).toBe(before);
});

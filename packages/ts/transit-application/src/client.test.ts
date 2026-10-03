import { afterEach, expect, test, vi } from "vite-plus/test";
import {
  ApplicationTransportError,
  request,
  readInterface,
  OperatorSession,
  type Transport,
} from "./client";
import publicationFixture from "../../../zig/transit-station-app/src/fixtures/publication-v1.json" with { type: "json" };
import fixture from "../../../zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import type { Diagnostic } from "@rey/transit-query-client";
import type { HostRequest, Scope, Signed } from "./types";
const scope: Scope = { realm: 49, application: 9, pid: 17, resource: 19, namespace: "23" };
afterEach(() => vi.unstubAllGlobals());
test("application HTTP failures preserve owned diagnostic evidence and flag invalid detail", async () => {
  const original = structuredClone(fixture);
  const retained = new ApplicationTransportError(400, "UnsupportedQuery", original);
  original.message = "changed";
  expect(retained.diagnostic?.message).toBe(fixture.message);
  const fetcher = vi.fn();
  vi.stubGlobal("fetch", fetcher);
  for (const call of [
    () => request({ compile: { source: "DROP INTERFACE board;" } }),
    () => readInterface(),
  ]) {
    fetcher.mockResolvedValueOnce(
      Response.json({ err: "Forbidden", diagnostic: fixture }, { status: 403 }),
    );
    await expect(call()).rejects.toMatchObject({
      status: 403,
      code: "Forbidden",
      diagnostic: fixture,
      diagnosticInvalid: false,
    });
    fetcher.mockResolvedValueOnce(
      Response.json(
        { err: "Forbidden", diagnostic: { ...fixture, definition: "0".repeat(64) } },
        { status: 403 },
      ),
    );
    await expect(call()).rejects.toMatchObject({
      status: 403,
      code: "Forbidden",
      diagnostic: undefined,
      diagnosticInvalid: true,
    });
  }
  expect(fetcher).toHaveBeenCalledTimes(4);
});
test("lost admission survives remount/export and retries the identical signature", async () => {
  const submitted: Signed[] = [];
  let sequenceReads = 0;
  const transport: Transport = async (request: HostRequest) => {
    if ("prepare_read" in request)
      return { prepared_read: { scope, ...request.prepare_read, digest: Array(32).fill(1) } };
    if ("read" in request) {
      sequenceReads++;
      return {
        observation: {
          identity: { principal: 44, sequence: "9", permissions: 1, pid: 17, policy_revision: "2" },
        },
      };
    }
    if ("prepare" in request)
      return { prepared: { scope, ...request.prepare, digest: Array(32).fill(2) } };
    if ("submit" in request) {
      submitted.push(structuredClone(request.submit));
      if (submitted.length === 1) throw new Error("Reply lost after admission");
      return { admitted: { position: 91 } };
    }
    throw new Error("Unexpected request");
  };
  let held = 0;
  const coordinate = async () => {
    held++;
    return () => {
      held--;
    };
  };
  const session = new OperatorSession(
    scope,
    44,
    async () => Array(64).fill(3),
    transport,
    coordinate,
  );
  await expect(session.submit({ publish: "18446744073709551615" })).rejects.toThrow("Reply lost");
  expect(session.pending?.prepared.sequence).toBe("10");
  expect(held).toBe(1);
  await expect(session.submit({ publish: "2" })).rejects.toThrow("Recover");
  const mounted = new OperatorSession(
    scope,
    44,
    async () => {
      throw new Error("Retry must not sign again");
    },
    transport,
    coordinate,
  );
  mounted.restorePending(session.exportPending());
  expect(await mounted.retry()).toBe(91);
  expect(submitted).toHaveLength(2);
  expect(submitted[0]).toEqual(submitted[1]);
  expect(sequenceReads).toBe(1);
  expect(mounted.pending).toBeNull();
  expect(held).toBe(1); // Only the original unresolved session still holds its gate.
  const wrong = new OperatorSession({ ...scope, resource: 20 }, 44, async () => [], transport);
  expect(() => wrong.restorePending(session.exportPending())).toThrow("another scope");
});
test("changed prepared scope is rejected before signing", async () => {
  let signs = 0;
  const transport: Transport = async (request) => {
    if (!("prepare_read" in request)) throw new Error("Unexpected transport");
    return {
      prepared_read: {
        scope: { ...scope, realm: 50 },
        ...request.prepare_read,
        digest: Array(32).fill(0),
      },
    };
  };
  const session = new OperatorSession(
    scope,
    44,
    async () => {
      signs++;
      return [];
    },
    transport,
  );
  await expect(session.read({ identity: {} })).rejects.toThrow("scope changed");
  expect(signs).toBe(0);
});

test("publication receipt survives invalid optional diagnostic detail", async () => {
  const read: HostRequest = {
    read: {
      prepared: {
        scope,
        principal: 44,
        selection: { state: { operation: publicationFixture.proposal.operation } },
        digest: Array(32).fill(0),
      },
      signature: Array(64).fill(0),
    },
  };
  const detail = structuredClone(fixture) as Diagnostic;
  detail.code = "publication.applied";
  detail.outcome = "applied";
  detail.identity = {
    domain: "publication",
    id: publicationFixture.proposal.operation,
    realm: "49",
    resource: "19",
    sequence: null,
  };
  detail.facts.fill(null);
  detail.actions.fill(null);
  detail.location = null;
  const state = {
    revision: "99",
    configuration: {
      application: 9,
      namespace: "23",
      realm: 49,
      administrator: 44,
      name_digest: Array(32).fill(1),
    },
    policy: null,
    head: publicationFixture.head,
    receipt: publicationFixture.receipt,
    upload: null,
    disposition: null,
    receipt_diagnostic: detail,
  };
  const fetcher = vi.fn();
  vi.stubGlobal("fetch", fetcher);
  fetcher.mockResolvedValueOnce(Response.json({ observation: { state } }));
  const accepted = await request(read);
  expect(accepted).toMatchObject({
    observation: { state: { receipt: publicationFixture.receipt, receipt_diagnostic: detail } },
  });
  fetcher.mockResolvedValueOnce(
    Response.json({
      observation: {
        state: { ...state, receipt_diagnostic: { ...detail, definition: "0".repeat(64) } },
      },
    }),
  );
  const malformed = await request(read);
  expect(malformed).toMatchObject({
    observation: { state: { receipt: publicationFixture.receipt, receipt_diagnostic: null } },
  });
});

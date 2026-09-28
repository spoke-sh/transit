import { expect, test } from "vite-plus/test";
import { OperatorSession, type Transport } from "./client";
import type { HostRequest, Scope, Signed } from "./types";
const scope: Scope = { realm: 49, application: 9, pid: 17, resource: 19, namespace: "23" };
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
  const session = new OperatorSession(scope, 44, async () => Array(64).fill(3), transport);
  await expect(session.submit({ publish: "18446744073709551615" })).rejects.toThrow("Reply lost");
  expect(session.pending?.prepared.sequence).toBe("10");
  await expect(session.submit({ publish: "2" })).rejects.toThrow("Recover");
  const mounted = new OperatorSession(
    scope,
    44,
    async () => {
      throw new Error("Retry must not sign again");
    },
    transport,
  );
  mounted.restorePending(session.exportPending());
  expect(await mounted.retry()).toBe(91);
  expect(submitted).toHaveLength(2);
  expect(submitted[0]).toEqual(submitted[1]);
  expect(sequenceReads).toBe(1);
  expect(mounted.pending).toBeNull();
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

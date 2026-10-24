import { expect, test } from "vite-plus/test";
import {
  currentDefinition,
  ReactiveError,
  Session,
  Transport,
  type HostRequest,
  type HostResponse,
  type SignedCommand,
} from "@transit/reactive-client";

const connection = { realm: 1, principal: 2, service: 3, ingress: 4, role: 7 };
const description = {
  connection,
  observed_ms: 1000,
  max_lease_ms: 30000,
  discovery: {
    service: 3,
    ingress: 4,
    resource: 9,
    binding_revision: 1,
    watch_revision: 1,
    openapi_sha256: Array<number>(32).fill(1),
    asyncapi_sha256: Array<number>(32).fill(2),
  },
};
const open = { open: { session: 11, source_revision: 1, lease_before_ms: 29000 } };
const signed: SignedCommand = {
  request: {
    definition: currentDefinition,
    realm: 1,
    principal: 2,
    sequence: 21,
    command: { send: { pid: 4, role: 7, value: "00" } },
  },
  signature: Array<number>(64).fill(3),
};
const acquire = async () => () => {};

/** Inject transport observations here; native command decoding/receipt authority
 * is exercised independently through the Zig direct Follow schedule. */
async function lost() {
  const requests: HostRequest[] = [];
  let saved = "";
  const transport = new Transport();
  const session = new Session(transport, acquire, () => {
    saved = session.exportRecovery();
  });
  transport.host = async (request): Promise<HostResponse> => {
    requests.push(structuredClone(request));
    if ("describe" in request) return { description };
    if ("prepare" in request) return { prepared: signed };
    if ("submit" in request) {
      expect(JSON.parse(saved).pending.signed).toEqual(signed);
      throw new ReactiveError(503, "unavailable");
    }
    throw new Error("Unexpected host call");
  };
  await expect(session.command(open)).rejects.toThrow("unavailable");
  expect(session.pending?.input).toBeNull();
  return { saved, requests };
}

test("reload recovers the original accepted control without preparing or submitting a replacement", async () => {
  const { saved } = await lost();
  const requests: HostRequest[] = [];
  const transport = new Transport();
  const recovered = new Session(transport, acquire);
  transport.host = async (request): Promise<HostResponse> => {
    requests.push(structuredClone(request));
    if ("recover_control" in request) {
      expect(request.recover_control).toEqual(signed);
      return { recovered_control: { connection, control: { reactive: open }, input: 77 } };
    }
    if ("observe" in request) {
      expect(request.observe).toEqual(signed);
      return { observation: { committed: {} } };
    }
    throw new Error("Recovery must not prepare or resubmit an accepted control");
  };
  recovered.restoreRecovery(saved);
  expect(requests).toHaveLength(0);
  await recovered.recover();
  expect(recovered.scope).toEqual({
    realm: 1,
    principal: 2,
    service: 3,
    ingress: 4,
    session: 11,
    generation: 77,
    subscription: 0,
    subscription_generation: 0,
  });
  expect(recovered.pending).toBeNull();
  expect(requests.map((request) => Object.keys(request)[0])).toEqual([
    "recover_control",
    "observe",
  ]);
});

test("saved input positions cannot retarget the signed control", async () => {
  const { saved } = await lost();
  for (const position of [78]) {
    const changed = JSON.parse(saved);
    changed.pending.input = position;
    let calls = 0;
    const transport = new Transport();
    transport.host = async (request): Promise<HostResponse> => {
      ++calls;
      expect("recover_control" in request).toBe(true);
      return { recovered_control: { connection, control: { reactive: open }, input: 77 } };
    };
    const recovered = new Session(transport, acquire);
    recovered.restoreRecovery(JSON.stringify(changed));
    await expect(recovered.recover()).rejects.toThrow("session_recovery_changed");
    expect(recovered.pending?.signed).toEqual(signed);
    expect(recovered.scope).toBeNull();
    expect(calls).toBe(1);
  }
});

test("the accepted Follow token supplies the original template, capture pool and budget after reload", async () => {
  const transport = new Transport();
  const follow = {
    follow: {
      session: { session: 11, generation: 77 },
      expected: 0,
      template: "100",
      captures: ["101", "102", "0", "0", "0", "0", "0", "0"],
      limit: 2,
    },
  };
  transport.host = async (request): Promise<HostResponse> => {
    if ("describe" in request) return { description };
    if ("refresh_prepare" in request) return { prepared: signed };
    if ("submit" in request) return { receipt: { receipt: { position: 80 } } } as HostResponse;
    if ("observe" in request) return { observation: { committed: {} } };
    throw new Error("Unexpected host call");
  };
  const original = new Session(transport, acquire);
  original.description = description;
  original.scope = {
    ...connection,
    session: 11,
    generation: 77,
    subscription: 0,
    subscription_generation: 0,
  };
  delete (original.scope as unknown as Record<string, unknown>).role;
  await original.refresh(follow);
  const restored = new Session(transport, acquire);
  restored.restoreRecovery(original.exportRecovery());
  let recovered = 0;
  transport.host = async (request): Promise<HostResponse> => {
    if ("describe" in request) return { description };
    expect("recover_control" in request).toBe(true);
    ++recovered;
    return { recovered_control: { connection, control: { refresh: follow }, input: 80 } };
  };
  expect(await restored.recoverSelection()).toEqual(follow.follow);
  expect(recovered).toBe(1);
  restored.selection!.generation = 81;
  await expect(restored.recoverSelection()).rejects.toThrow("session_recovery_changed");
});

test("invalid or foreign saved artifacts reject without changing the caller", async () => {
  const { saved } = await lost();
  for (const mutate of [
    (value: Record<string, unknown>) => {
      value.definition = "previous-definition";
    },
    (value: Record<string, unknown>) => {
      delete value.definition;
    },
    (value: Record<string, unknown>) => {
      value.attachment = -1;
    },
    (value: Record<string, unknown>) => {
      value.nonce = [0];
    },
    (value: Record<string, unknown>) => {
      value.extra = true;
    },
    (value: Record<string, unknown>) => {
      (value.pending as Record<string, unknown>).command = open;
    },
  ]) {
    const changed: Record<string, unknown> = JSON.parse(saved);
    mutate(changed);
    const recovered = new Session(new Transport(), acquire);
    expect(() => recovered.restoreRecovery(JSON.stringify(changed))).toThrow(
      "invalid_session_recovery",
    );
    expect(recovered.description).toBeNull();
    expect(recovered.pending).toBeNull();
  }
});

test("persistence failure prevents control dispatch and preserves its frozen bytes", async () => {
  const transport = new Transport();
  let submitted = false;
  transport.host = async (request): Promise<HostResponse> => {
    if ("describe" in request) return { description };
    if ("prepare" in request) return { prepared: signed };
    submitted = true;
    throw new Error("Must not dispatch");
  };
  const session = new Session(transport, acquire, () => {
    throw new Error("Storage full");
  });
  await expect(session.command(open)).rejects.toThrow("Storage full");
  expect(submitted).toBe(false);
  expect(session.pending?.signed).toEqual(signed);
});

test("a restored scope requires the same host and watch before resuming reads", async () => {
  const original = new Session(new Transport(), acquire);
  original.description = description;
  original.scope = {
    realm: 1,
    principal: 2,
    service: 3,
    ingress: 4,
    session: 11,
    generation: 77,
    subscription: 0,
    subscription_generation: 0,
  };
  const transport = new Transport();
  let calls = 0;
  transport.host = async (request): Promise<HostResponse> => {
    ++calls;
    expect("describe" in request).toBe(true);
    return {
      description: { ...description, discovery: { ...description.discovery, watch_revision: 2 } },
    };
  };
  const session = new Session(transport, acquire);
  session.restoreRecovery(original.exportRecovery());
  await expect(session.open()).rejects.toThrow("reset_required");
  expect(calls).toBe(1);
  expect(session.scope).toEqual(original.scope);
});

test("attachment recovery derives nonce and generation from the original native command", async () => {
  const original = new Session(new Transport(), acquire);
  original.description = description;
  original.scope = {
    realm: 1,
    principal: 2,
    service: 3,
    ingress: 4,
    session: 11,
    generation: 77,
    subscription: 13,
    subscription_generation: 78,
  };
  original.pending = { signed, command: null, input: null };
  original.attachment = 100;
  original.nonce = Array(16).fill(9);
  const command = {
    attach: { identity: { session: 11, generation: 77 }, expected: 3, nonce: Array(16).fill(4) },
  };
  const transport = new Transport();
  transport.host = async (request): Promise<HostResponse> => {
    if ("recover_control" in request)
      return { recovered_control: { connection, control: { reactive: command }, input: 79 } };
    expect("observe" in request).toBe(true);
    return { observation: { committed: {} } };
  };
  const restored = new Session(transport, acquire);
  restored.restoreRecovery(original.exportRecovery());
  await restored.recover();
  expect(restored.attachment).toBe(4);
  expect(restored.nonce).toEqual(command.attach.nonce);
});

import diagnosticFixture from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { describe, expect, test } from "vite-plus/test";
import { SseDecoder, ReactiveError, Session, Transport } from "@rey/transit-reactive-client";

describe("generated reactive transport boundary", () => {
  test("incremental framing validates the wrapper and its JSON payload", () => {
    const decoder = new SseDecoder();
    const seen: string[] = [];
    const bytes = new TextEncoder().encode(
      'event: heartbeat\ndata: {"heartbeat":{"version":1}}\n\n',
    );
    for (const byte of bytes) decoder.push(new Uint8Array([byte]), (item) => seen.push(item.event));
    decoder.end();
    expect(seen).toEqual(["heartbeat"]);
    for (const content of [
      'event: heartbeat\ndata: {"heartbeat":{"version":"1"}}\n\n',
      'event: heartbeat\ndata: {"terminal":{"reason":"denied"}}\n\n',
      'event: heartbeat\nevent: heartbeat\ndata: {"heartbeat":{"version":1}}\n\n',
      'event: heartbeat\nid: aa\ndata: {"heartbeat":{"version":1}}\n\n',
    ])
      expect(() => new SseDecoder().push(new TextEncoder().encode(content), () => {})).toThrow(
        ReactiveError,
      );
  });
  test("unbounded lines, incomplete endings and invalid UTF-8 reject", () => {
    expect(() => new SseDecoder().push(new Uint8Array(9217).fill(120), () => {})).toThrow(
      ReactiveError,
    );
    const decoder = new SseDecoder();
    decoder.push(new TextEncoder().encode("event: heartbeat"), () => {});
    expect(() => decoder.end()).toThrow(ReactiveError);
    expect(() => new SseDecoder().push(new Uint8Array([255, 10, 10]), () => {})).toThrow(
      ReactiveError,
    );
  });
  test("lost submission retains the identical frozen command and prohibits replacement", async () => {
    const sent: string[] = [];
    const signed = {
      request: {
        version: 1,
        definition: "8d2c6617b339418cf2d3afa6259009e4b3efc5308e40fe65757ca9385c227803",
        realm: 49,
        principal: 65536,
        sequence: 1,
        command: { send: { pid: 1, value: "00" } },
      },
      signature: Array(64).fill(0),
    };
    let lost = true;
    const transport = new Transport(async (_url, options) => {
      const body = JSON.parse(options!.body as string);
      let response: unknown;
      if ("prepare" in body) response = { prepared: signed };
      else if ("submit" in body) {
        sent.push(JSON.stringify(body.submit));
        if (lost) {
          lost = false;
          throw new TypeError("reply lost");
        }
        response = { receipt: { stage: "ingress_accepted", receipt: { position: 10 } } };
      } else response = { observation: { committed: {} } };
      return new Response(JSON.stringify(response), {
        headers: { "Content-Type": "application/json" },
      });
    });
    let held = false;
    const session = new Session(transport, async () => {
      expect(held).toBe(false);
      held = true;
      return () => {
        held = false;
      };
    });
    session.description = {
      connection: { realm: 49, principal: 65536, service: 1, ingress: 1 },
      max_lease_ms: 30000,
      observed_ms: 1,
      discovery: {
        service: 1,
        ingress: 1,
        resource: 2,
        binding_revision: 1,
        watch_revision: 1,
        openapi_sha256: Array(32).fill(0),
        asyncapi_sha256: Array(32).fill(0),
      },
    };
    await expect(session.command({ close: { session: 1, generation: 2 } })).rejects.toMatchObject({
      status: 503,
      reason: "unavailable",
    });
    expect(session.pending?.signed).toEqual(signed);
    expect(held).toBe(true);
    await expect(session.command({ close: { session: 2, generation: 3 } })).rejects.toThrow(
      "control_uncertain",
    );
    await session.recover();
    expect(session.pending).toBeNull();
    expect(held).toBe(false);
    expect(sent).toEqual([JSON.stringify(signed), JSON.stringify(signed)]);
  });
  test("an unchanged observer sample cannot create another renewal", async () => {
    const requests: unknown[] = [];
    const session = new Session(
      new Transport(async (_url, options) => {
        requests.push(JSON.parse(options!.body as string));
        return new Response(JSON.stringify({ clock: { observed_ms: 1000, max_lease_ms: 30000 } }), {
          headers: { "Content-Type": "application/json" },
        });
      }),
    );
    session.scope = {
      realm: 49,
      principal: 65536,
      service: 1,
      ingress: 1,
      session: 1,
      generation: 2,
      subscription: 3,
      subscription_generation: 4,
    };
    session.leaseBefore = 30000;
    await session.renew();
    expect(requests).toEqual([{ clock: {} }]);
    expect(session.pending).toBeNull();
    expect(session.leaseBefore).toBe(30000);
  });
  test.each([403, 410, 409, 0])(
    "rejected control observes current scope before terminal presentation (%s)",
    async (status) => {
      const signed = {
        request: {
          version: 1,
          definition: "8d2c6617b339418cf2d3afa6259009e4b3efc5308e40fe65757ca9385c227803",
          realm: 49,
          principal: 65536,
          sequence: 1,
          command: { send: { pid: 1, value: "00" } },
        },
        signature: Array(64).fill(0),
      };
      let inspections = 0;
      const session = new Session(
        new Transport(async (_url, options) => {
          const request = JSON.parse(options!.body as string);
          if ("inspect" in request) {
            ++inspections;
            return new Response("", { status });
          }
          const response =
            "prepare" in request
              ? { prepared: signed }
              : "submit" in request
                ? { receipt: { receipt: { position: 10 } } }
                : {
                    observation: {
                      rejected: {
                        record: {
                          reason: "ReactiveLeaseConflict",
                          input: 10,
                          kind: "reactive",
                          subject: "5",
                          generation: "6",
                          payload: Array(32).fill(0),
                          cause: "52656163746976654c65617365436f6e666c696374",
                        },
                        diagnostic: null,
                      },
                    },
                  };
          return new Response(JSON.stringify(response), {
            headers: { "Content-Type": "application/json" },
          });
        }),
        async () => () => {},
      );
      session.description = {
        connection: { realm: 49, principal: 65536, service: 1, ingress: 1 },
      } as never;
      session.scope = {
        realm: 49,
        principal: 65536,
        service: 1,
        ingress: 1,
        session: 5,
        generation: 6,
        subscription: 7,
        subscription_generation: 8,
      };
      if (status === 0)
        session.inspect = async () => {
          ++inspections;
          throw new DOMException("Scope observation aborted", "AbortError");
        };
      session.attachment = 9;
      session.nonce = Array(16).fill(1);
      await expect(
        session.command({
          renew: { identity: { session: 5, generation: 6 }, expected: 1000, lease_before_ms: 2000 },
        }),
      ).rejects.toMatchObject({
        status: 409,
        reason: "ReactiveLeaseConflict",
        scopeFailure: {
          status,
          reason:
            status === 403
              ? "denied"
              : status === 410
                ? "expired"
                : status === 0
                  ? "interrupted"
                  : "reset_required",
        },
      });
      expect(inspections).toBe(1);
      expect(session.pending).toBeNull();
    },
  );
});

test.each(["valid", "malformed", "foreign", "wrong_input", "wrong_outcome", "absent"])(
  "committed rejection preserves primary reason without resubmitting (%s)",
  async (kind) => {
    const original = {
      ...structuredClone(diagnosticFixture),
      code: "reactive.lease_conflict",
      outcome: "input_rejected",
      evidence: "domain_status",
      facts: [
        {
          field: "native_input",
          origin: "owner",
          availability: "provided",
          value: { unsigned: "10" },
        },
        ...Array(15).fill(null),
      ],
      actions: [{ kind: "inspect_status", target: null }, null, null, null],
    };
    const diagnostic =
      kind === "malformed"
        ? {}
        : kind === "foreign"
          ? { ...original, definition: "0".repeat(64) }
          : kind === "wrong_input"
            ? {
                ...original,
                facts: [
                  { ...original.facts[0], value: { unsigned: "11" } },
                  ...Array(15).fill(null),
                ],
              }
            : kind === "wrong_outcome"
              ? { ...original, outcome: "applied" }
              : kind === "absent"
                ? null
                : original;
    let calls = 0;
    const session = new Session(
      new Transport(async (_url, options) => {
        ++calls;
        expect(JSON.parse(options!.body as string)).toEqual({ observe: 10 });
        return Response.json({
          observation: {
            rejected: {
              record: {
                reason: "ReactiveLeaseConflict",
                input: 10,
                kind: "reactive",
                subject: "5",
                generation: "6",
                payload: Array(32).fill(0),
                cause: "52656163746976654c65617365436f6e666c696374",
              },
              diagnostic,
            },
          },
        });
      }),
      async () => () => {},
    );
    session.description = {
      connection: { realm: 49, principal: 65536, service: 1, ingress: 1 },
    } as never;
    session.pending = {
      signed: {} as never,
      command: {
        renew: { identity: { session: 5, generation: 6 }, expected: 1000, lease_before_ms: 2000 },
      },
      input: 10,
    };
    await expect(session.recover()).rejects.toMatchObject({
      status: 409,
      reason: "ReactiveLeaseConflict",
      diagnosticInvalid: kind !== "valid" && kind !== "absent",
      diagnostic: kind === "valid" ? original : undefined,
    });
    expect(session.pending).toBeNull();
    expect(calls).toBe(1);
  },
);

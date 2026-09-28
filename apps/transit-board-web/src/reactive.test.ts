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
        version: 3,
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
    const session = new Session(transport);
    await expect(session.command({ close: { session: 1, generation: 2 } })).rejects.toThrow();
    expect(session.pending?.signed).toEqual(signed);
    await expect(session.command({ close: { session: 2, generation: 3 } })).rejects.toThrow(
      "control_uncertain",
    );
    await session.recover();
    expect(session.pending).toBeNull();
    expect(sent).toEqual([JSON.stringify(signed), JSON.stringify(signed)]);
  });
});

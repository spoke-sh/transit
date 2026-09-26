import { ProcessRef, HandlerError } from "@transit/client";
import { Key, u64, type Handler, type Turn, type Incoming } from "@transit/station";
import {
  counterCodec,
  totalCodec,
  u64Codec,
  type Add,
  type Read,
  type Start,
  type Total,
} from "./codecs.ts";

export const TOTAL = new Key(new TextEncoder().encode("total"), u64Codec);
export const REQUEST = new Key(new TextEncoder().encode("request"), u64Codec);
export const OBSERVED = new Key(new TextEncoder().encode("observed"), u64Codec);
export class Counter implements Handler<Add | Read> {
  async initialize(turn: Turn): Promise<void> {
    await turn.state.put(TOTAL, 0n);
  }
  async handle(turn: Turn, input: Incoming<Add | Read>): Promise<void> {
    if (input.kind === "cast" && input.value.kind === "add") {
      await turn.state.put(
        TOTAL,
        u64.checkedAdd(await turn.state.require(TOTAL), input.value.value),
      );
    } else if (input.kind === "call" && input.value.kind === "read") {
      await turn.reply({ kind: "total", value: await turn.state.require(TOTAL) }, totalCodec);
    } else throw new HandlerError("Unexpected counter message");
  }
}
export class Requester implements Handler<Start | Total> {
  readonly #counter: ProcessRef;
  constructor(counter: ProcessRef) {
    this.#counter = counter;
  }
  async initialize(_turn: Turn): Promise<void> {}
  async handle(turn: Turn, input: Incoming<Start | Total>): Promise<void> {
    if (input.kind === "cast" && input.value.kind === "start") {
      if ((await turn.state.find(REQUEST)) !== undefined) throw new HandlerError("Already started");
      const correlation = await turn.call(
        this.#counter,
        { kind: "read" },
        { codec: counterCodec, wait: { kind: "untimed" } },
      );
      await turn.state.put(REQUEST, correlation);
    } else if (input.kind === "reply" && input.value.kind === "total") {
      turn.requireReply(input, {
        peer: this.#counter,
        correlation: await turn.state.require(REQUEST),
      });
      await turn.state.put(OBSERVED, input.value.value);
    } else throw new HandlerError("Unexpected requester message");
  }
}

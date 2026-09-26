import { ProcessRef, HandlerError } from "@transit/client";
import {
  TableSchema,
  QueryPlan,
  type Handler,
  type Turn,
  type Incoming,
  type ResultReader,
  type IpcSegment,
} from "@transit/station";
import {
  queryServiceCodec,
  type Initialize,
  type Insert,
  type Rows,
  type Start,
} from "./codecs.ts";
import { REQUEST, OBSERVED } from "./counter.ts";

export const TABLE = TableSchema.int64(1);
export class TableService implements Handler<Initialize | Insert | Rows> {
  readonly #requester: ProcessRef;
  constructor(requester: ProcessRef) {
    this.#requester = requester;
  }
  async initialize(turn: Turn): Promise<void> {
    await turn.createTable(TABLE);
    await turn.allowQuery(this.#requester, TABLE, { expectedRevision: 0, allow: true });
  }
  async handle(turn: Turn, input: Incoming<Initialize | Insert | Rows>): Promise<void> {
    if (input.kind === "cast" && input.value.kind === "initialize") return;
    if (input.kind === "cast" && input.value.kind === "insert") {
      await (await turn.table(TABLE)).insert({ key: input.value.key, value: input.value.value });
    } else if (input.kind === "call" && input.value.kind === "rows") {
      await turn.startQuery(TABLE, new QueryPlan({ limit: (1n << 64n) - 1n }));
    } else throw new HandlerError("Unexpected Table message");
  }
}
export class QueryRequester implements Handler<Start> {
  readonly #source: ProcessRef;
  readonly #consume: (segment: IpcSegment) => Promise<void>;
  constructor(source: ProcessRef, consume: (segment: IpcSegment) => Promise<void>) {
    this.#source = source;
    this.#consume = consume;
  }
  async initialize(_turn: Turn): Promise<void> {}
  async handle(turn: Turn, input: Incoming<Start>): Promise<void> {
    if (input.kind !== "cast" || input.value.kind !== "start")
      throw new HandlerError("Expected query start");
    if ((await turn.state.find(REQUEST)) !== undefined)
      throw new HandlerError("Query already started");
    const correlation = await turn.call(
      this.#source,
      { kind: "rows" },
      { codec: queryServiceCodec, wait: { kind: "untimed" } },
    );
    await turn.state.put(REQUEST, correlation);
  }
  async handleResult(turn: Turn, reader: ResultReader): Promise<void> {
    const manifest = await reader.manifest();
    if (
      manifest.correlation !== (await turn.state.require(REQUEST)) ||
      manifest.source.realm !== this.#source.realm ||
      manifest.source.pid !== this.#source.pid
    )
      throw new HandlerError("Result does not match the saved request");
    // External callback effects need their own idempotency policy: this turn is private.
    for (let ordinal = 0n; ordinal < manifest.segments; ordinal++)
      await this.#consume(await reader.segment(ordinal));
    await turn.state.put(OBSERVED, manifest.rows);
  }
}

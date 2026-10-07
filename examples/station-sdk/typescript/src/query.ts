import { ProcessRef, HandlerError } from "@transit/client";
import {
  TableSchema,
  TableMutation,
  QueryPlan,
  Key,
  type Cell,
  type Mutation,
  type Handler,
  type Turn,
  type Incoming,
  type ResultReader,
  type IpcSegment,
} from "@transit/station";
import {
  queryServiceCodec,
  queryReplyCodec,
  u64Codec,
  type TableCommand,
  type TableMessage,
  type Start,
  type NotReady,
} from "./codecs.ts";
import { REQUEST, OBSERVED } from "./counter.ts";
import {
  QUEUE,
  INITIAL,
  MAX_INPUT,
  REJECTIONS,
  workKey,
  outcomeKey,
  type Queue,
} from "./table-work.ts";

export const signed = (value: bigint): Cell => ({
  state: "value",
  value: { kind: "atom", atom: { kind: "signed", value } },
});
export const TABLE = new TableSchema(
  1n,
  1n,
  5n,
  [
    { id: 1n, name: "id", type: { kind: "int64" }, nullable: false },
    { id: 2n, name: "value", type: { kind: "int64" } },
    {
      id: 3n,
      name: "label",
      type: { kind: "utf8" },
      nullable: false,
      default: {
        state: "value",
        value: { kind: "atom", atom: { kind: "utf8", value: "example" } },
      },
    },
    {
      id: 4n,
      name: "tags",
      type: { kind: "list", element: { type: { kind: "int64" } } },
      nullable: false,
      default: { state: "value", value: { kind: "list", cells: [signed(1n), signed(2n)] } },
    },
  ],
  [1n],
);
const LIMITS = { recordBytes: 65536, stagingBytes: 8388608n, stagingRecords: 1024 };
export const NOT_READY = new Key(new TextEncoder().encode("not-ready"), u64Codec);

export class TableService implements Handler<TableMessage> {
  readonly #requester: ProcessRef;
  constructor(requester: ProcessRef) {
    this.#requester = requester;
  }
  async initialize(_turn: Turn): Promise<void> {}
  async #queue(turn: Turn): Promise<Queue> {
    return (await turn.state.find(QUEUE))?.value ?? { head: 0n, tail: 0n, ready: false };
  }
  async #wake(turn: Turn): Promise<void> {
    await turn.cast(turn.process, { kind: "advance" }, queryServiceCodec);
  }
  async #enqueue(turn: Turn, position: number, command: TableCommand): Promise<void> {
    if (!Number.isSafeInteger(position) || position < 1)
      throw new HandlerError("Invalid original input");
    const identity = BigInt(position);
    if (identity > MAX_INPUT) throw new HandlerError("Invalid original input");
    const queue = await this.#queue(turn),
      key = workKey(identity);
    if ((await turn.state.find(key)) || (await turn.state.find(outcomeKey(identity))))
      throw new HandlerError("Table input identity reused");
    let head = identity;
    if (queue.tail) {
      if (identity <= queue.tail) throw new HandlerError("Table queue order changed");
      const tail = await turn.state.require(workKey(queue.tail));
      if (tail.next) throw new HandlerError("Invalid Table queue tail");
      await turn.state.put(workKey(queue.tail), { next: identity, command: tail.command });
      head = queue.head;
    } else if (!queue.ready && command.kind !== "initialize") {
      await turn.state.put(workKey(INITIAL), { next: identity, command: { kind: "initialize" } });
      head = INITIAL;
    }
    await turn.state.put(key, { next: 0n, command });
    await turn.state.put(QUEUE, { head, tail: identity, ready: queue.ready });
    if (!queue.head) await this.#wake(turn);
  }
  async #drive(turn: Turn): Promise<void> {
    const queue = await this.#queue(turn);
    if (!queue.head) return;
    const work = await turn.state.require(workKey(queue.head));
    if (
      (work.next === 0n) !== (queue.head === queue.tail) ||
      (work.next !== 0n && queue.head !== INITIAL && work.next <= queue.head)
    )
      throw new HandlerError("Invalid Table queue link");
    const command = work.command;
    let status;
    if (command.kind === "initialize") status = await turn.createTable(TABLE, LIMITS);
    else {
      if (!queue.ready || queue.head === INITIAL)
        throw new HandlerError("Table queue is not initialized");
      const predicate = [
        { kind: "compare", column: 1n, op: "eq", value: { kind: "signed", value: command.key } },
      ] as const;
      let spec: Mutation;
      if (command.kind === "delete") spec = { kind: "delete", predicate };
      else {
        const value: Cell = command.value === null ? { state: "null" } : signed(command.value);
        spec =
          command.kind === "insert"
            ? {
                kind: "insert",
                rows: [
                  [
                    { column: 1n, value: signed(command.key) },
                    { column: 2n, value },
                  ],
                ],
              }
            : { kind: "update", assignments: [{ column: 2n, value }], predicate };
      }
      status = await TableMutation.prepare(turn.resource, 0, queue.head, TABLE, spec).step(turn);
    }
    if (status.state === "building") {
      await this.#wake(turn);
      return;
    }
    const initialize = command.kind === "initialize";
    if ((await turn.budgets()).mutations < 3 + Number(initialize && !queue.ready)) {
      await this.#wake(turn);
      return;
    }
    if (status.completedInput === undefined) throw new HandlerError("Missing Table completion");
    const outcome = {
      state: 0,
      admitted: BigInt(status.admittedInput),
      completed: BigInt(status.completedInput),
      matched: 0n,
      changed: 0n,
      rejection: 0,
    };
    if (!("reference" in status)) {
      if (status.state !== "applied") throw new HandlerError("Table initialization failed");
      if (!queue.ready)
        await turn.allowQuery(this.#requester, TABLE.objectId, {
          expectedRevision: 0n,
          allow: true,
        });
    } else {
      outcome.state = { applied: 1, rejected: 2, cancelled: 3 }[status.state];
      outcome.matched = status.counts?.matched ?? 0n;
      outcome.changed = status.counts?.changed ?? 0n;
      outcome.rejection = REJECTIONS.indexOf(status.rejection);
    }
    await turn.state.put(outcomeKey(queue.head), outcome);
    await turn.state.delete(workKey(queue.head));
    await turn.state.put(QUEUE, {
      head: work.next,
      tail: work.next ? queue.tail : 0n,
      ready: queue.ready || initialize,
    });
    if (work.next) await this.#wake(turn);
  }
  async handle(turn: Turn, input: Incoming<TableMessage>): Promise<void> {
    const value = input.value;
    if (
      input.kind === "cast" &&
      (value.kind === "initialize" ||
        value.kind === "insert" ||
        value.kind === "update" ||
        value.kind === "delete")
    )
      await this.#enqueue(turn, input.position, value);
    else if (input.kind === "cast" && value.kind === "advance") {
      if (
        input.origin.kind !== "process" ||
        input.origin.process.realm !== turn.process.realm ||
        input.origin.process.pid !== turn.process.pid
      )
        throw new HandlerError("Table continuation requires its recorded self output");
      await this.#drive(turn);
    } else if (input.kind === "call" && value.kind === "rows") {
      const queue = await this.#queue(turn);
      if (!queue.ready || queue.head) await turn.reply({ kind: "notReady" }, queryReplyCodec);
      else
        await turn.startQuery(
          TABLE.objectId,
          new QueryPlan({ projection: [0, 1, 2, 3], limit: INITIAL }),
        );
    } else throw new HandlerError("Unexpected Table message");
  }
}
export class QueryRequester implements Handler<Start | NotReady> {
  readonly #source: ProcessRef;
  readonly #consume: (segment: IpcSegment) => Promise<void>;
  constructor(source: ProcessRef, consume: (segment: IpcSegment) => Promise<void>) {
    this.#source = source;
    this.#consume = consume;
  }
  async initialize(_turn: Turn): Promise<void> {}
  async handle(turn: Turn, input: Incoming<Start | NotReady>): Promise<void> {
    if (input.kind === "reply" && input.value.kind === "notReady") {
      turn.requireReply(input, {
        peer: this.#source,
        correlation: await turn.state.require(REQUEST),
      });
      await turn.state.put(NOT_READY, input.correlation);
      return;
    }
    if (input.kind !== "cast" || input.value.kind !== "start")
      throw new HandlerError("Expected query start");
    const previous = await turn.state.find(REQUEST),
      notReady = await turn.state.find(NOT_READY);
    if (previous !== undefined && notReady?.value !== previous.value)
      throw new HandlerError("Query already started");
    const correlation = await turn.call(
      this.#source,
      { kind: "rows" },
      { codec: queryServiceCodec, wait: { kind: "untimed" } },
    );
    await turn.state.put(REQUEST, correlation);
    if (notReady !== undefined) await turn.state.delete(NOT_READY);
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

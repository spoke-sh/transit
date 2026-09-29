# Workload examples across languages

Build a telemetry reader, a recoverable service request, a research result
consumer or a shared incident notebook with the same durable boundaries. These
recipes connect the [workload model](../reference/workloads.md) to existing
executable examples in Python, TypeScript, Rust and Zig, plus console SQL.

The code blocks are excerpts from the linked complete applications, not standalone
scripts. Their runners supply imports/codecs, provision identities and grants,
start workers and couriers, and clean up owned fixtures. Site checks keep the
excerpts synchronized with those sources. Scenario names suggest applications
of the examples; they do not imply that a market feed, research engine or incident
management product is implemented.

## Choose a recipe

| Recipe | Language | Workload and durable boundary |
| --- | --- | --- |
| [Inspect an operational Table](#inspect-an-operational-table-with-sql) | SQL | Finite snapshot query with typed Arrow output |
| [Record sensor observations](#record-sensor-observations-with-python) | Python | A typed row commits with its consumed input |
| [Recover a service request](#recover-a-service-request-with-typescript) | TypeScript | Saved correlation binds a later reply to the original call |
| [Consume research batches](#consume-research-batches-with-rust) | Rust | Verified result identity and bounded owned IPC segments |
| [Share an incident notebook](#share-an-incident-notebook-with-zig) | Zig | Accepted Document revision, explicit conflicts and Unicode text |
| [Replay captured enrichment](#replay-captured-enrichment-with-zig) | Zig | Recorded connector outcome; replay performs no external request |

Use Linux x86_64 and run commands from the repository root. `nix develop` supplies
the pinned default tools; the Rust recipe uses `nix develop .#bindings`. Install
locked frontend dependencies once with `just transit-board::install` before the
TypeScript checks. These SDKs are built from the checkout, not downloaded from
public package registries. The full fixture commands below can take minutes and
require the local disk-store/container prerequisites in their linked guides.
They use disposable synthetic installations, not your running server.

The local `transit app` supervisor currently hosts Zig workers. The other language
examples use their own public SDK runners; installing a Python package or Node
tarball does not register a worker with that supervisor.

## Inspect an operational Table with SQL

Start the [local quickstart](quickstart.md). From its `.cache/docs-start` working
directory, open the console:

```sh
../transit-local/bin/transit console
```

```text
.mode table
.timing on
SELECT id, value FROM items WHERE id >= 0 LIMIT 8;
SELECT COUNT(*) FROM items;
```

The default Table is empty: the first query displays typed `id`/`value` headings
and zero rows; the second returns a count of zero. Once an application supplies
rows through its owning mutation API, the same read pattern can inspect work-item
states, sensor readings or keyed features. SQL does not insert those rows or
declare a different source. There are no joins, grouping or general sorting.

For one statement and exit:

```sh
../transit-local/bin/transit console -c 'SELECT COUNT(*) FROM items;'
```

Read the phase timings alongside the [performance reference](../reference/performance.md).
The current console uses durable captured queries. Fresh interactive sessions
and cancellation on exit are [planned behavior](../reference/queries.md#planned-interactive-sessions).
The commands above do not demonstrate that future lifecycle.

To exercise populated sources without modifying your local installation:

```sh
just examples::query table
just examples::query kv
just examples::query document
```

These run the [recoverable query example](../../examples/state-query/README.md)
against synthetic Unicode data. It saves the original submission and checks
complete nested result coverage with bounded pages. KV requires an explicit
decoder; Document projections preserve missing, null, conflict and type-error
states instead of flattening them into an empty value.

## Record sensor observations with Python

Think of an int64 key as an observation sequence and its nullable int64 value as
a reading in an application-defined integer unit. The executable example calls
these fields `key` and `value`; it is a finite Table service, not a sensor adapter.
Declare units and validate source coordinates before adapting it to real input.

The [complete Python service](../../examples/station-sdk/python/transit_sdk_examples/query.py)
creates its Table, grants one requester query access, and handles typed input:

<!-- source-excerpt: examples/station-sdk/python/transit_sdk_examples/query.py -->
```python
class TableService:
    def __init__(self, requester: ProcessRef) -> None:
        self.requester = requester
    def initialize(self, turn: Turn) -> None:
        turn.create_table(TABLE)
        turn.allow_query(self.requester, TABLE, expected_revision=0, allow=True)
    def handle(self, turn: Turn, incoming: Incoming[Initialize | Insert | Rows]) -> None:
        value = incoming.value
        if isinstance(incoming, Cast) and isinstance(value, Initialize):
            pass
        elif isinstance(incoming, Cast) and isinstance(value, Insert):
            turn.table(TABLE).insert(Row(value.key, value.value))
        elif isinstance(incoming, Call) and isinstance(value, Rows):
            turn.start_query(TABLE, QueryPlan(limit=2**64-1))
        else:
            raise HandlerError('Unexpected Table message')
```

`TABLE` is `TableSchema.int64(1)` in the complete source. The public codecs reject
malformed messages and out-of-range integers. The runner commits the inserted
row with input progress; a handler field is not the durable Table. An effectively
unlimited row count does not remove page and execution bounds.

Run the installed wheel consumer and real authority schedule:

```sh
just bindings::python-test
```

The [Python example guide](../../examples/station-sdk/python/README.md) explains
installation and explicit configuration. Its Table/query schedule checks 41 rows
across six segments, retained reads, current access checks and owned Arrow bytes.
For a telemetry application, add gap/correction handling and measure ingestion,
materialization lag and catch-up independently. These finite results establish
no feed-rate or continuous-query guarantee.

## Recover a service request with TypeScript

A workflow may need a durable answer from another worker: for example, read a
device's accumulated count before advancing a maintenance step. The executable
counter/requester pair isolates the call/reply boundary. Its `Start` event records
the call correlation; a later authenticated reply must match the peer and that
saved correlation.

From the [complete TypeScript requester](../../examples/station-sdk/typescript/src/counter.ts):

<!-- source-excerpt: examples/station-sdk/typescript/src/counter.ts -->
```typescript
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
```

The outgoing call, saved state and consumed start input commit together. The
`Promise` schedules local execution; it does not hold the durable wait. Full-width
values use `bigint`, and the counter checks addition overflow. This requester
deliberately accepts one start; a recurring workflow needs explicit per-job
identity and lifecycle rather than deleting an unresolved `REQUEST`.

```sh
just bindings::node-sdk-test
```

The [installed TypeScript examples](../../examples/station-sdk/typescript/README.md)
exercise worker replacement as well as Table/query handling. The CLI roles require
fresh ownership after host loss; applications choosing exact pending-operation
recovery provide the runner's persistence hooks. Host restart, reply recovery
and retrying an uncertain native mutation are separate concerns.

## Consume research batches with Rust

A research job can consume a captured result one Arrow segment at a time without
retaining every row. The executable [Rust query requester](../../examples/station-sdk/rust/src/lib.rs)
checks the saved correlation and source before invoking its consumer:

<!-- source-excerpt: examples/station-sdk/rust/src/lib.rs -->
```rust
fn handle_result(&mut self, turn: &mut Turn<'_>, complete: ResultComplete) -> Result<()> {
    let expected = turn.state().require(&REQUEST)?;
    let manifest = {
        let mut reader = turn.result(complete.correlation)?;
        let manifest = reader.manifest()?;
        if manifest.correlation.get() != expected || manifest.source != self.source {
            return Err(unexpected());
        }
        // Callback effects need their own idempotency policy: this turn is private.
        for ordinal in 0..manifest.segments {
            (self.consume)(reader.segment(ordinal)?)?;
        }
        manifest
    };
    turn.state().put(&OBSERVED, &manifest.rows)
}
```

The surrounding `QueryRequester<F>` accepts `FnMut(IpcSegment) -> Result<()>`.
Each segment owns its original IPC bytes. The reader's release precedes the
state update; the application records the verified row count only after traversing
all segments. A callback that retains every batch defeats the example's bounded
consumption pattern. File uploads or other callback effects need their own
idempotency policy because the handler's turn has not committed yet.

```sh
nix develop .#bindings --command just bindings::rust-sdk-test
```

The [Rust example guide](../../examples/station-sdk/rust/README.md) covers the
installed crates and full runner. Its proof independently decodes the same IPC
with PyArrow. This is an explicit durable query job, unlike the proposed console
session lifetime. A reproducible research application must additionally record
dataset/source basis, plan, feature/model versions and application configuration;
this small example is not a historical simulation engine.

## Share an incident notebook with Zig

Two operators edit the title and Unicode body of a shared note while one is
disconnected. The [Document example](../../examples/station-document/README.md)
submits their changes in reverse order, observes conflicts, resolves them
explicitly and recovers after writer/store loss. It also demonstrates stale
replica resynchronization after opted-in compaction.

The inspector binds both field reads to one accepted revision:

<!-- source-excerpt: examples/station-document/main.zig -->
```zig
const description = try client.describe(identity);
const title = (try client.readPath(description.reference, &.{try doc.Model.Name.init("title")})).value;
const body = (try client.readPath(description.reference, &.{try doc.Model.Name.init("body")})).value;
```

The [complete inspector](../../examples/station-document/main.zig) reads text
through bounded sequence pages and reports revision, merge epoch, retained floor
and title alternatives. Its 512-byte/128-page display budget fails explicitly
when exceeded. It does not silently choose a conflicting title or truncate text.

```sh
just examples::document
```

The same pattern can support shared research context or an agent's evidence
notebook. Current grants still govern every read; collaborative merge semantics
do not create a multi-user identity service or authorize writes. Search and
analytical projections would need their own accepted source basis and explicit
freshness; they are [planned structures](../reference/workloads.md#architectural-priorities).

## Replay captured enrichment with Zig

An enrichment step should be able to re-read a captured response even after its
remote service disappears. The [HTTP example](../../examples/station-http/README.md)
uses a synthetic TLS POST, a separate connector worker and a recorded outcome.
After stopping the peer and removing its credential, the caller replays the
captured body and checks its digest:

<!-- source-excerpt: examples/station-http/main.zig -->
```zig
var replay = try http.Replay.open(&driver.reader, try outcome.reference(), .captured);
var hash = std.crypto.hash.sha2.Sha256.init(.{});
var count: u64 = 0;
while (try replay.read()) |part| {
    if (part.kind == .response_body) {
        hash.update(part.bytes.slice());
        count += part.bytes.len;
    }
    if (part.complete) break;
}
if (!replay.done) return error.IncompleteExchange;
```

```sh
just examples::http
```

The schedule checks exactly one external send and recovery of the captured
response through the [complete caller](../../examples/station-http/main.zig).
For internet research, add source timestamps, content identity and extractor/model
versions; do not treat an HTTP success code as application truth. This finite
connector has explicit payload limits, and unknown remote outcomes still require
reconciliation. It supplies neither a crawler nor a general exactly-once remote
effect guarantee. Trading actions would require their own domain policy and
numeric rules, while preserving this pre-dispatch authorization boundary.

## Extend a recipe deliberately

Use [language SDKs](../reference/sdks.md) for the other supported languages and
[caller semantics](../reference/callers.md) for shared ownership and uncertainty
rules. Keep retained data independent of resident memory, record exact source
evidence, and budget background work separately from interactive/control work.
Select workload-specific measurements from the
[performance evaluation plan](../reference/performance.md#reproduce-and-compare)
before claiming scale or latency improvements.

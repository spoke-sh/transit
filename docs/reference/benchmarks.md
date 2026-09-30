# Declarative benchmarks

Transit measures small, deterministic components associated with **TPC-C,
TPC-E, TPC-H and TPC-DS** through its shared Zig SQL compiler and Fuze/Station
execution APIs. These measurements use Transit-authored synthetic fixtures.
**None of the four complete TPC workloads executes at this source revision.**
The report preserves that blocked status even when every component succeeds.

Use this reference to interpret measurements and find the missing declarative
contracts. The [benchmark tooling guide](../../tests/benchmarks/README.md) owns
runnable repository commands and report options; the
[proof ledger](../../tests/README.md#declarative-benchmark-components) records
executed checks. The [performance reference](performance.md) separately covers
native interactive queries and storage costs.

## Coverage and source specifications

The inventory pins these upstream specifications; their version numbers are
independent of Transit's v1 contracts. Each inventory unit appears individually
in the generated report, with a status and blockers. The count is an inventory
of workload units, not a count of completed queries or a conformance percentage.

| Suite and primary specification                                                          | Full-workload inventory                                                                                                                                                            | Measured components                                                                                  | Full-workload status |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | -------------------- |
| [TPC-C 5.11.0](https://www.tpc.org/TPC_Documents_Current_Versions/pdf/tpc-c_v5.11.0.pdf) | New-Order, Payment, Order-Status, Delivery, Stock-Level                                                                                                                            | Stock quantity lookup, low-stock count and quantity sum; reduced declaration and literal writes      | Blocked              |
| [TPC-E 1.14.0](https://www.tpc.org/TPC_Documents_Current_Versions/pdf/TPC-E_v1.14.0.pdf) | Broker-Volume, Customer-Position, Market-Feed, Market-Watch, Security-Detail, Trade-Lookup, Trade-Order, Trade-Result, Trade-Status, Trade-Update, Data-Maintenance, Trade-Cleanup | Trade quantity lookup, filtered sum and limited projection; reduced declaration and literal writes   | Blocked              |
| [TPC-H 3.0.1](https://www.tpc.org/TPC_Documents_Current_Versions/pdf/TPC-H_v3.0.1.pdf)   | Q01–Q22 and RF1–RF2                                                                                                                                                                | Line-item quantity sum, filtered count and limited-input sum; reduced declaration and literal writes | Blocked              |
| [TPC-DS 4.0.0](https://www.tpc.org/TPC_Documents_Current_Versions/pdf/TPC-DS_v4.0.0.pdf) | Q01–Q99 templates; LF_CR, LF_CS, LF_I, LF_SR, LF_SS, LF_WR, LF_WS, DF_CS, DF_SS, DF_WS, DF_I                                                                                       | Inventory quantity sum, null count and limited projection; reduced declaration and literal writes    | Blocked              |

TPC-DS coverage counts each template as one blocked unit, including constituent
statements and permitted variants. Those statements are not separately executed
or silently omitted from a successful query total. TPC-E's Trade-Cleanup is a
setup operation, not another timed transaction in this harness. Standard data
load, transaction mixes, refresh schedules, query validation, concurrency,
recovery, measurement intervals and disclosure requirements remain unimplemented
in the full-suite driver.

All 151 inventory units share two immediate blockers: the full schemas exceed
Transit's published Table profile, and complete workload drivers/oracles are
absent. The report also records suite-level transaction, relational, expression
and bulk-operation prerequisites. This is complete enumeration with common
blockers, not an exhaustive operator audit of every generated query variant.
Nine small executable probes check current rejection boundaries; they are
Transit examples, not substituted standard queries.

These results provide no tpmC, tpsE, QphH or QphDS score and are not comparable
with published TPC results. Consult the [TPC specifications index](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp)
for the standards and tools. No standard query text or generator is vendored by
this harness, and no decimal monetary representation or trading policy is chosen.

## What runs

The [component manifest](../../tests/benchmarks/manifest.json) owns the exact SQL.
Each family has seven components: three SELECTs, one two-column declaration and
literal INSERT, UPDATE and DELETE. The 28 components exercise the same public
package implementation used by declarative callers. They do not establish
transport-specific latency or execute a complete business transaction.

| Measured phase          | Actual boundary                                                                                                                                    | Excluded work                                                                                     |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| SELECT compilation      | SQL text to the production Fuze plan                                                                                                               | Catalog lookup, authorization and source acquisition                                              |
| SELECT execution        | Canonical plan round-trip and binding precede timed paged Fuze execution, including generated rows, validation, Arrow encoding and segment hashing | Native source adapters, snapshot acquisition, disk/network I/O, rendering and durable publication |
| Declaration compilation | Production state compiler; independent canonical text and two-column schema checks follow                                                          | Catalog creation, resource provisioning and grants                                                |
| Mutation compilation    | Literal SQL to the shared typed mutation plan                                                                                                      | Admission and durable request recovery                                                            |
| Mutation proposal       | Real Station private turn with in-memory point reads and bounded row proposals                                                                     | Authority validation, commit, Ursula durability, contention and external callers                  |

The reduced fixture has `id INT64 NOT NULL` and `quantity INT64 NULL`.
IDs increase from zero; quantity is null every thirteenth row and otherwise
`(id * 17 + seed) modulo 101`. These are dimensionless synthetic quantities,
not prices. They are not DBGEN, EGen or DSDGEN output and have no standard scale
factor. The default fixture contains 8192 rows, generated in pages of eight.
Changing row count changes work, without allocating the complete source in Zig.

SELECT results are independently checked against SQLite and decoded with
PyArrow before measurement. All output cells, column order, completion and row
counts are checked. Empty inputs preserve typed empty results and null SUM.
Mutation checks compare independently encoded row keys/values and affected counts;
every repetition starts from the same two existing rows. Those private proposals
do not accumulate committed data. SQLite and PyArrow are verification tools;
Transit's runtime remains Zig native.

The point-filter component traverses synthetic pages, so its timing says nothing
about native primary-key seeking. KV and Document adapters, catalog publication,
CLI, SDK, Board and Flight calls are outside these component timings. Sharing
Fuze does not make those execution paths equally fast or equally capable.

## Intended declarative surface and blockers

The [grammar inventory](sql/grammar-surface.md) owns implemented/planned labels.
Benchmark coverage follows its exact contracts and does not enable new syntax.

| Surface                                                     | Current measurement or blocker                                                                                                          | Owning contract                                                                                                        |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| SELECT and shared typed plans                               | Measured finite filter/projection/limit/count/checked int64 sum; canonical plan round-trip precedes execution                           | [SQL](sql.md), [queries](queries.md)                                                                                   |
| CREATE TABLE and catalog                                    | Reduced definition compilation measured; published two-column Tables cannot represent complete suite schemas/constraints                | [CREATE TABLE](sql/create-table.md)                                                                                    |
| INSERT, UPDATE, DELETE                                      | Compilation and private proposals measured; literal bounded writes cannot substitute for full transactions or refresh functions         | [Mutation contract](../../contracts/TABLE_MUTATION_V1.md)                                                              |
| Joins, grouping, ordering and subqueries                    | Planned; full relational workloads blocked                                                                                              | [Planned composition](sql/grammar-surface.md#planned-declarations-and-relational-composition)                          |
| Decimal/date operations, arithmetic and compound predicates | Planned; quantities here do not implement monetary/date expressions                                                                     | [Expressions](sql/expressions.md)                                                                                      |
| BEGIN/COMMIT/ROLLBACK, parameters and bulk operations       | Planned; no multi-statement transaction session or general data loading                                                                 | [Other SQL operations](sql.md#other-sql-operations)                                                                    |
| KV, Document, graph and foreign relations                   | Native KV/Document query profiles exist but are not measured here; graph/foreign relations remain planned                               | [Source contracts](queries.md), [multi-model targets](sql/grammar-surface.md#planned-standards-and-data-model-surface) |
| Views, subscriptions, dataflows and recorded effects        | No component result establishes maintained execution or external effects; complete TPC suites do not cover this entire intended surface | [Streaming](sql/streaming.md)                                                                                          |
| Historical schemas, snapshots and branches                  | Planned and unmeasured; a synthetic fixed basis does not implement historical binding                                                   | [Historical targets](sql/grammar-surface.md#planned-historical-schemas-and-branches)                                   |
| CLI, SDKs, Board and Flight                                 | Existing caller profiles retain separate permissions and transport limits; all are unmeasured by this harness                           | [Caller APIs](callers.md), [SDKs](sdks.md), [Flight](flight.md)                                                        |

A native resource transaction is not a cross-resource transaction. Running
separate supported statements does not reproduce a standard transaction's
atomicity, isolation or rollback semantics. Enlarging fixture constants cannot
resolve these contract gaps.

## Reading a report

Reports separate `components_passed_full_workloads_blocked`, `failed` and
incomplete `running` status. Each full workload stays `blocked` with zero
completed units. Requiring full coverage makes the runner exit nonzero even
when components pass. Unexpected acceptance of a blocker probe requires a
coverage review; it never automatically promotes a suite.

A report retains exact SQL, raw nanoseconds and iteration counts, min/median/max
per-iteration timing, source revision and dirty state, binary and source hashes,
compiler/build profile, lock and fixture hashes, CPU/affinity/load, platform,
page size, seed and oracle versions. Verification and warm-up precede samples.
Per-process timeouts fail the run; failed or interrupted work has no valid timing
summary. No duration threshold determines correctness.

Compare the same component and phase at equal fixture and build settings on a
controlled host. These repeated-loop summaries are not request latency
percentiles. A busy shared machine, compiler differences and page size affect
results. No paired performance improvement follows from one run, and no
end-to-end throughput follows from component nanoseconds.

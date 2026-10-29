# Guarantees and verification limits

Transit's data guarantees depend on identity, current authorization and atomic
publication across worker restarts and uncertain transport outcomes. Assess a
supported declaration through its accepted definition, data or result, and
attributed operation/progress evidence. The [data model](data-model.md) identifies
those observations and their limits; a live worker or accepted request is not
proof of completion. The contracts below define the
guarantees at each boundary, the required deployment assumptions and how the
test suites exercise them.

## Guarantees by boundary

| Boundary               | Required behavior under failure                                                                                                    | Public contract                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| Authority              | One conditional successor; stale owners cannot commit; recovery preserves fencing and retirement                                   | [Processes](processes.md)            |
| Permissions            | Current native/resource policy gates writes, receipts, replay and bounded disclosure                                               | [Security](security.md)              |
| State                  | Mutations, input progress and outputs share one visibility decision; rejected proposals publish nothing partial                    | [State](state.md)                    |
| Retry                  | Lost acknowledgements retain one original identity/outcome; conflicting content rejects; unknown stays distinct from rejection     | [Callers](callers.md)                |
| Delivery               | Committed destinations/provenance survive retries; no source-turn rollback or invented cross-process atomicity                     | [Streams](streams.md)                |
| Lifetime               | Expiry/closure cannot be reopened by late evidence or an old snapshot; pressure does not authorize deletion                        | [Retention](retention.md)            |
| Growth                 | Retained collections exceed resident caches with bounded page/work budgets and explicit quotas                                     | [Storage](storage.md)                |
| Effects                | Complete captures and known outcomes require evidence; no hidden retry or dispatch during replay                                   | [Connectors](connectors.md)          |
| Documents              | Convergence under declared rules, explicit conflicts/dependencies and no resurrection across deletion/compaction                   | [Documents](documents.md)            |
| Queries                | Exact source basis, typed cells, bounded complete-result verification and explicit unsupported syntax                              | [Queries](queries.md), [SQL](sql.md) |
| Reactive views         | No-gap snapshot/watch handoff or reset; current permission and generation fence disclosure/replacement                             | [Reactive](reactive.md)              |
| Installation/migration | Frozen provisioning/step recovery, independent revisions and explicit activation; no permission renewal through worker replacement | [Applications](applications.md)      |

The machine-readable [invariant inventory](../../../tests/verification/invariants.json)
maps these claims to owning implementation, tasks, scenarios and limits.
[The proof ledger](../../history/qualification/README.md) records actual commands and results,
including independent clients, workloads and deployment configurations.

## Verification layers

Static checks cover schemas, generated declarations, documentation links,
formatting, types and package boundaries. Deterministic units exercise transition
validation, codecs, budgets and allocation/rollback. Independent fixtures check
wire bytes, signatures, full-width values and cross-language ownership.

Generated schedules and saved counterexamples explore races across ownership,
revocation, retry and time. Finite models establish only their stated bounded
invariants and assumptions; they are not a proof of every Zig execution or cluster
size. The Lean 4 SQL specifications check rewrite factorization, 5-state cell
lattice and Kleene/SQL truth semantics, multi-version schema evolution and
projection commutation, and collation sort-key preorders with Umbra 4-byte prefix
reflection and zone-map pruning under explicit correspondence assumptions; no
optimizer rewrite is enabled by those proofs.

The local WAL model separates visible writes from durable file contents, directory
entries and metadata. Its finite checks cover acknowledgement, fencing, recovery
and authorized prefix deletion under explicit sync and atomic-replacement
assumptions. Process death and power loss are distinct modeled transitions; the
disk suites exercise process death and injected I/O errors. A model check does
not establish host power-loss behavior or a refinement proof of the Zig owner.
The [storage account](../internals/storage-runtime.md#local-wal-publication-and-recovery-model)
defines the correspondence and exclusions.

The storage lifecycle, transaction workspace, transaction decision, write
lifecycle/token, and resident owner/cache models check finite transition invariants
and replay their negative-control counterexample traces against the real Zig
`TablePartition`, `TableMaintenanceState`, `TableStorageRoots`,
`TableGarbageCollection`, `TransactionDecisionLog`, and `DirectCatalog` owners.
The forward-design `QueueLeaseTransaction` model checks proposed
`QueuePartition` `.tack` Roaring states, `key_fifo` affinity, `_lease_epoch`
fencing, and 3-primitive turn commits. See [the model reference](../../../tests/verification/models/README.md)
for scope and limits.

The console interaction model checks bounded editor/request transitions and
replays every exported edge against its Zig owner. Its conditional progress
check assumes eventual request settlement, cancellation join and foreground
completion; terminal I/O, arbitrary text and latency remain separate obligations.
The [interaction account](../internals/service-interfaces.md#console-interaction-transitions)
defines that correspondence and its limits.

The SQL result models check finite logical progress and established-session
result delivery. Every exported progress edge is replayed against the Zig
progress owner; the session retry/disclosure model has no adapter or server
replay. Both checks are safety-only. They distinguish completion evidence,
consumer exhaustion and resource release, and preserve current authorization at
server disclosure. See the [result-model account](../internals/query-engine.md#finite-result-transition-models)
for bounds, assumptions and excluded uncertain-write settlement.

The authority/delivery simulation runs two producer processes and one destination
against the real core with atomic conditional append and injected acknowledgement
loss. It preserves the live engine between events, compares its logical state
with independent recovery and a separate oracle, and replays each trace twice.
An explicit finite schedule checks that remaining eligible input and pending
outputs resolve once permissions and storage are available. That result does not
establish fairness of an automatic worker/courier scheduler or external effects.

The resource simulation injects numbered failures before/after immutable page
staging, unavailable page reads, conditional publication and prefix trimming.
An independent oracle checks resource values, input progress, outputs and captured
view roots. A two-page test cache and explicit eviction exercise cold reads;
recovery must preserve the same logical state without staging pages. Its journal
is atomic and its pages remain in memory. These checks do not establish physical
storage durability or authorize page garbage collection.

The shared-client simulation schedules actual Session preparation/submission and
courier steps over an in-process signed transport. It distinguishes lost requests
from lost responses, retains exact uncertain operations, replaces activations and
checks current permission. A finite-lifetime profile exercises recorded turn
permits, settlement, expiry maintenance and clock refusal. Independent input,
output and provenance checks run after each event. Network framing, operating
system scheduling and host await-cancellation require the external suites.

Component schedules exercise accepted Document edit sets and checkpoint floors,
Exchange capture/closure and replay holds, query source cuts and refresh generation
replacement, provider readiness/activation fencing, and conditional catalog
publication. Direct catalog schedules check lost admission/publication replies,
terminal conflicts, cancellation, original receipts after replacement, current
create/inspect policy and paginated metadata with a one-page cache. These use the
real component implementations with volatile log/object adapters and independent
contract assertions. Seeded replay compares their event records; these stores
establish logical publication boundaries, not disk or remote-effect durability.

The external fault supervisor runs the compiled node, counter worker and courier
against disk-backed Ursula. It injects request/reply delay and loss, interrupts
connections, pauses the courier, and kills/restarts processes against current
history. Public reads check resource/input/output agreement, original delivery
provenance, current permission, stale activation and bounded eligible progress.
Histories distinguish requested faults from observed execution and retain exact
signed attempts and receipts for the synthetic workload. A seed selects workload
intent; operating-system scheduling remains nondeterministic.

Separate external profiles install the Python and Node SDKs outside the checkout
and exercise lost replies, seedless recovery, host cancellation/disposal and
revoked retry. Application, query and reactive profiles use their owning local
integration rigs. These results apply to the executed host/placement; they do not
expand Kubernetes, browser, TLS or other-language support implicitly.

Real disk/provider and service tests exercise acknowledgement loss, WAL recovery,
current permissions and process interruption. Deployment tests exercise
local, Compose and reference configurations. Browser checks test actual routes,
protocol use, generation ownership and accessibility. Installed SDK tests and
independent consumers expose dependencies hidden by a monorepo build.

## Limits that matter to deployment decisions

- Process SIGKILL is not host power loss or arbitrary storage corruption.
- Recovery against current storage is not live restore from an old backup.
- Native protocol enforcement does not prove honest application computation or
  sandbox same-user native code.
- Growing durable state does not establish horizontal authority throughput or
  every offered-load/latency target.
- A complete finite query or streaming transport does not establish continuous
  query semantics.
- TLS or one independently tested peer does not establish universal protocol,
  type or platform compatibility.
- A local duration is not a hosted CI cost measurement or a production SLO.

Tests must check forbidden outcomes as well as eventual success: duplicate
effects, partial publication, unauthorized disclosure, late-generation overwrite,
silent truncation and revived identities. Record workload, toolchain, topology,
seed/trace and current limits with claims. New application policy or unsupported
transforms need their own evidence.

For contributor commands and clean-checkout checks use
[contributing](../guides/contributing.md). For application onboarding use the real
[local quickstart](../guides/quickstart.md) and [work-item guide](../guides/applications.md).

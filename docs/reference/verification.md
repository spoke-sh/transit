# Guarantees and verification limits

Transit preserves identity, authorization and atomic commit across worker
restarts and uncertain transport outcomes. The contracts below define the
guarantees at each boundary, the required deployment assumptions and how the
test suites exercise them.

## Guarantees by boundary

| Boundary | Required behavior under failure | Public contract |
| --- | --- | --- |
| Authority | One conditional successor; stale owners cannot commit; recovery preserves fencing and retirement | [Processes](processes.md) |
| Permissions | Current native/resource policy gates writes, receipts, replay and bounded disclosure | [Security](security.md) |
| State | Mutations, input progress and outputs share one visibility decision; rejected proposals publish nothing partial | [State](state.md) |
| Retry | Lost acknowledgements retain one original identity/outcome; conflicting content rejects; unknown stays distinct from rejection | [Callers](callers.md) |
| Delivery | Committed destinations/provenance survive retries; no source-turn rollback or invented cross-process atomicity | [Streams](streams.md) |
| Lifetime | Expiry/closure cannot be reopened by late evidence or an old snapshot; pressure does not authorize deletion | [Retention](retention.md) |
| Growth | Retained collections exceed resident caches with bounded page/work budgets and explicit quotas | [Storage](storage.md) |
| Effects | Complete captures and known outcomes require evidence; no hidden retry or dispatch during replay | [Connectors](connectors.md) |
| Documents | Convergence under declared rules, explicit conflicts/dependencies and no resurrection across deletion/compaction | [Documents](documents.md) |
| Queries | Exact source basis, typed cells, bounded complete-result verification and explicit unsupported syntax | [Queries](queries.md), [SQL](sql.md) |
| Reactive views | No-gap snapshot/watch handoff or reset; current permission and generation fence disclosure/replacement | [Reactive](reactive.md) |
| Installation/migration | Frozen provisioning/step recovery, independent revisions and explicit activation; no permission renewal through worker replacement | [Applications](applications.md) |

The machine-readable [invariant inventory](../../tests/verification/invariants.json)
maps these claims to owning implementation, tasks, scenarios and limits.
[The proof ledger](../../tests/README.md) records actual commands and results,
including independent clients, workloads and deployment configurations.

## Verification layers

Static checks cover schemas, generated declarations, documentation links,
formatting, types and package boundaries. Deterministic units exercise transition
validation, codecs, budgets and allocation/rollback. Independent fixtures check
wire bytes, signatures, full-width values and cross-language ownership.

Generated schedules and saved counterexamples explore races across ownership,
revocation, retry and time. Finite models establish only their stated bounded
invariants and assumptions; they are not a proof of every Zig execution or cluster
size. The selected SQL rewrite theorems are specification results with explicit
correspondence assumptions; no optimizer rewrite is enabled by those proofs.

The authority/delivery simulation runs two producer processes and one destination
against the real core with atomic conditional append and injected acknowledgement
loss. It preserves the live engine between events, compares its logical state
with independent recovery and a separate oracle, and replays each trace twice.
An explicit finite schedule checks that remaining eligible input and pending
outputs resolve once permissions and storage are available. That result does not
establish fairness of an automatic worker/courier scheduler or external effects.

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

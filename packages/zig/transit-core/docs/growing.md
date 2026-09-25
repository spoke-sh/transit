# Growing authority integration

Status: M10 in development. `transit_core.growing.Engine(Journal, PageStore)` is
not yet composed into the running node or public client. The [v3 contract](../../../../contracts/TRANSIT_V3.md)
owns proposed wire types; the existing v2 engine remains the deployed profile.

The first implemented transitions are bootstrap, root-authorized principal
grant/revocation, process creation, ownership, mailbox admission and termination.
They use the [typed immutable catalog](pages.md#typed-catalog). Principal sequence,
exact-retry receipt, process metadata and accepted mailbox entry become visible
through one conditional journal append of a new root. A prepared candidate can
leave unreachable pages; it cannot advance a live process or disclose acceptance.

Principals use full-width value keys. Grants have an epoch for later resource-
grant invalidation without scanning all resources. Receipts are independently
addressed by principal and sequence; retry does not scan the history or evict an
older receipt. Authentication/current command permission precedes retry lookup.
Mailbox keys combine PID and per-process ordinal; input bytes and source evidence
remain retained after progress, with no resident queue proportional to backlog.

The journal entry carries the previous root and a complete constant-size head,
including a genesis fingerprint. Opening/refreshing reads the latest published
head and materializes records on demand. It relies on the trusted journal's
conditional append/record-coordinate contract; page identity checks protect
referenced content. Recovery never stages pages or runs application code.
Root-history checkpoint/trim and compatibility rejection still need composition
into this engine; the separate page proof is not that integration.

No running capability advertises these transitions. State/view turns, delivery,
effect settlement, current resource rights on receipt disclosure, query services,
runtime/lifecycle extensions, quotas/control reserve, retained results and Station
remain integration work within M10. Unimplemented commands fail explicitly with
`UnsupportedGrowthCommand`. The module must not be selected by a launcher before
the complete advertised profile and its proofs are ready. Existing histories are
never silently upgraded or parsed as v3.

## Initial evidence

Core tests retain 20 principals with identities above 65,535 and 70 processes,
crossing both legacy catalog limits. They check retained mailbox provenance,
historical retry after a later sequence, recovery without page writes, competing
candidate fencing, revocation before publication/disclosure, failure before
append, lost accepted acknowledgements and permanent retirement. Additional
checks reject an older materialization root attached to a newer publication and
legacy genesis versions. Clock uncertainty, rollback and elapsed work deadlines
fail closed; clock failure does not disable revocation or termination. The injected
journal/page store is deterministic test infrastructure; these checks do not
qualify Ursula integration, complete M10 or demonstrate production throughput.

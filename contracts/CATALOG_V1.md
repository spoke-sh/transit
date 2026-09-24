# Working catalog retention v1

Implemented M8 extension to [Transit v2](TRANSIT_V2.md). It changes working-set
capacity, not mailbox ordering or default history retention.

## Opt-in and authority

`catalog_retention: {pid}` records irreversible opt-in for that PID's catalog
evidence. It requires current PID-scoped admin authority, a realm configured
with `last_per_principal` receipts, and `allow_trim=true` on the process. It must
precede activation, association changes and accepted inputs (generation/admitted
both zero, no owner). Repeated enabling is rejected. Existing accepted work never
acquires this policy implicitly. `ProcessView.collection` exposes the contract.

`collect: {pid, kind, id}` requires current admin authority for that PID and its
recorded opt-in. Kinds and eligibility:

| Kind | Required evidence |
| --- | --- |
| `output` | Source PID matches; terminal phase. A delivered input either has been consumed/cancelled or retains a self-contained authenticated origin. |
| `effect` | Owning PID matches; observed, cancelled or closed-unknown. Authorized/unknown attempts remain pinned. |
| `resource` | Writer PID matches; separately retired and payload-reclaimed under its history policy; no live association or active view. Retired associations are removed atomically. |
| `payload` | Owning PID matches; physical deletion was already confirmed and recorded. |
| `process` | PID matches; permanently retired; all referencing outputs/effects/payloads and owned/written resources collected; provider binding absent or confirmed stopped. |

An unconsumed legacy admission without stored origin pins its outbox. Collection
never advances input progress or cancels work. Resource receipts still require
current resource grants: removal denies protected old receipts rather than
reconstructing permission from an obsolete snapshot. Exact last-request receipts
remain available where current authorization permits; older sequences fail the
selected receipt horizon. A collected identity is not a license to repeat a side
effect or recreate a process.

## Identity and history

PID, resource, effect and payload identities are journal positions. The durable
allocation frontier (`State.position`) advances monotonically. The live catalog
plus this frontier is compact exclusion evidence: an absent past identity cannot
be allocated again. Outputs use a separate monotonically increasing
`output_count`; that counter is a high-water mark, not an array index. Exhausting
the safe-integer identity space fails closed.

Checkpoints preserve these frontiers, live entries and principal sequences.
An unknown/collected identity is rejected (`UnknownProcess`, `UnknownOutput`,
`UnknownEffect`, or `UnknownStateResource`); these errors do not promise whether
an absent ID was never allocated or was collected. Detailed retirement reasons
remain in retained history until an independently authorized trim. After trim,
compact exclusion evidence preserves permanent non-revival, not per-identity
historical explanations. Restore of an old backup is still not live authority.

The limits remain 64 working process slots, 128 effects, 256 outputs, four state
resources and sixteen standalone payloads. Applications opting in can reuse
**slots**, never identities. Principals remain sixteen durable identities; read
views remain four concurrent leases. Arbitrary many simultaneous processes,
working entries or pending outputs are not supported.

## Background progress and limits

Maintenance commits at most one selected collection per bounded step and drains
successful control steps promptly, with idle/error backoff. Its automatic scan
collects outputs after destination progress/retirement; an explicit collection
may additionally prove the retained origin of an unread input. This keeps legacy
mailboxes safe without a new legacy-history index. A backlog can still exhaust
working slots; capacity rejection does not authorize dropping messages.

Whole-realm checkpoint/trim still requires quiescent mailboxes and all applicable
history policies. Continuous allocation with unlimited journal history can grow
physical storage even when working catalogs stay bounded. No throughput,
bounded-recovery-time, automatic disk expansion or reclamation-latency guarantee
is added.

`just test::unit` exceeds old lifetime bounds, checks pending-work/uncertain-effect
pins and default unlimited retention. `just test::storage` repeats the sustained
profile over disk Ursula, SIGKILL, checkpoint publication, trim and restart,
then rejects old identities while allocating a new PID beyond the frontier.

Inspection pages expose `last_collection`, the most recent collection operation,
not a universal history or ID floor. Current catalogs list retained entries only.
Authorized `history` queries can still read retained events for an absent past PID;
without its current catalog entry, mailbox disposition is unknown (`null`), never
invented as pending or consumed. Live-process/mailbox queries still reject absent
PIDs. Board identifies collected catalogs and displays exact lifecycle action
names, keeping historical evidence separate from current authority.

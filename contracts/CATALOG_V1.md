# Working catalog retention v1

The [native v1 authority](TRANSIT_V1.md) supports explicit collection of terminal
working records. Collection is separate from resource reclamation, journal
trimming and cache eviction. Unlimited retention is the default.

## Opt-in and authority

`spawn.allow_collection` or `create.process.allow_collection` records a PID's
collection policy at creation. Existing accepted work never acquires it
implicitly. `collect: {pid, kind, id}` requires current administrative authority
for that PID and its recorded opt-in.

| Kind | Required evidence |
| --- | --- |
| `output` | Matching source PID and terminal phase; any delivered mailbox input retains its own value and authenticated origin |
| `effect` | Matching PID and observed, cancelled or closed-unknown phase; authorized/unknown attempts remain pinned |
| `resource` | Matching writer PID, separately reclaimed resource, no retained versions or live association/view dependencies |
| `payload` | Matching PID and recorded physical deletion outcome |
| `process` | Permanently retired PID, no referenced outputs/effects/payloads or written/owned resources; provider binding absent or confirmed stopped without a pending upgrade |

Each command performs bounded work. Resource collection can require separate
steps to close view indexes, detach retired associations and remove grant pages.
Process collection can require separate steps to release retained-version indexes,
detach associations and remove mailbox pages. A successful step can therefore
leave the object in the working catalog. Callers inspect progress and continue;
they cannot infer final removal from one receipt.

Collection never advances a live process's input progress or cancels its work.
Closing old view indexes retains metadata needed for current authorization of
historical turn receipts. Resource collection removes its grants, so protected
receipt disclosure fails instead of reconstructing obsolete permissions.

## Identity, history and recovery

Process, resource, effect and payload IDs derive from journal positions. Outputs
use their own monotonically increasing frontier. These values are durable
identities, never reusable resident slots. Exhausting the numeric address space
fails closed.

Process collection leaves a permanent `RetiredProcess` tombstone. Old process
operations reject retirement even after detailed working records are removed.
Other collected records reject as unknown; no new allocation reuses their IDs.
Published roots preserve these facts across checkpoints and prefix trim. An old
backup cannot restore execution authority.

Catalogs are paged and can grow independently of the resident page cache. There
are no fixed total counts for processes, resources, outputs or retained receipts.
Explicit storage/admission quotas remain separate. Collection does not reclaim
immutable historical catalog pages or promise bounded disk usage.

## Background progress and inspection

Maintenance rotates bounded scans among processes, resources, effects, outputs,
payloads and collection. Each scan pass captures a frontier so continuous admission cannot
indefinitely postpone an earlier item. Suggestions grant no authority: signed
operations repeat current permission, lifecycle and dependency checks. Blocked
items remain durable and are revisited after bounded progress elsewhere.

The realm's `allow_history_trim` opt-in separately permits root checkpoint
publication and journal prefix trimming. Pending mailbox values and outputs are
retained in the published root and do not require quiescent queues for that trim.
Physical payload deletion has its own recorded intent and outcome. Provider
acknowledgements do not establish erasure from backups or external copies.

Inspection reports `last_collection`, the latest accepted collection position;
it is not a universal retention floor. Current catalog listings show retained
working records. Historical inspection remains subject to the journal boundary
and current permissions. Missing historical detail cannot be presented as a
new pending input or fresh execution right.

The owning implementation is
[growing_collection.zig](../packages/zig/transit-core/src/growing_collection.zig).
Executable schedules and their recorded outcomes belong in the
[proof ledger](../docs/history/qualification/README.md); planned checks do not qualify durability.

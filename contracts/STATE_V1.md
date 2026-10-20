# State resources v1

State v1 defines resource identity, associations, read views and atomic mutations
within the [native v1 protocol](TRANSIT_V1.md). The current
[public types](../packages/zig/transit-protocol/src/Growth.zig) and
[generated schema](transit-v1.schema.json) own exact fields and defaults. The
[state reference](../docs/reference/state.md) explains the programming model.

## Compatibility and persistence

All commands use the signed `/v1/command` envelope; metadata reads use
`/v1/query` and complete immutable block reads use `/v1/blocks`.
They share the native contract definition identifier, signature domains and
current authorization checks. The authority accepts only the current definition;
it does not decode previous inline-state histories or translate saved operations.
See [versioning](../docs/reference/versioning.md).

Resources, entries, associations and durable views live in immutable paged
catalogs. The current immutable-page format uses compact `TPG1` binary pages,
eight leaf entries and 32 branch children within a 24 KiB encoded bound. The
shared definition distinguishes this format from prior JSON page histories;
old heads reject before catalog access. A prepared turn stages private pages. Only a conditional journal append
publishes the resulting root, input progress, mutations, outputs and receipt.
An abandoned candidate cannot become committed state through page discovery.
Recovery opens the accepted root and loads pages on demand without invoking
application handlers or redispatching effects.

## Bounds and storage

| Item | Bound |
| --- | --- |
| Key or association name | 1–32 bytes, compared as opaque bytes |
| Value | 0–256 bytes, canonical lowercase hexadecimal encoding |
| Small metadata mutations | Four distinct keys in one resource per turn |
| Immutable block mutations | Sixteen distinct keys, 128 KiB total, at most 64 KiB per block |
| Declared views | Four per turn |
| Returned records | Eight per page |
| Durable view lifetime | At most 60 seconds, requiring trusted authority time |
| Required resources | Configured per-process validation budget; default 16 |
| Dependency traversal | Configured vertex budget; default 64, maximum 4096 |

These bounds limit individual operations and resident work. There is no fixed
realm-wide array of resource identities, keys, associations or views. Explicit
admission quotas and dependency budgets remain enforceable. The native
capabilities query reports configured limits. Large values require application
segmentation or the [immutable block contract](BLOCK_V1.md). Blocks and metadata
share the same one-resource revision, writer/view and acceptance boundary.
`Resource.entries` counts small metadata; `block_entries` counts the separate
resource-owned block index.

## Commands and rights

Commands are direct variants of the native command union, sharing principal
sequences and exact retry rules.

| Command | Meaning |
| --- | --- |
| `create_resource` | Create an empty resource with one existing writer PID, optional PID ownership and lifetime/history policy |
| `grant_resource` | Assign explicit resource permissions to an existing principal; zero revokes them |
| `associate` | Bind/remove a PID-local name against its expected association revision |
| `open_view` | Capture an associated resource revision for the current owner's next input |
| `close_view` | Close a view under its recorded caller and current execution permission |
| `turn` | Commit input progress, outputs and one resource's mutations using declared views |
| `retire_resource` | Retire a resource when no live required association prevents it |
| `expire_resource` | Record the resource's opted-in hard deadline expiry |
| `reclaim_resource` | Reclaim a retired resource in bounded steps under its history policy |

Resource rights are `inspect=1`, `read=2`, `write=4`. They are separate from native
process permissions, PID ownership and resource lifetime ownership. A writer
needs current execution ownership and resource write permission. Metadata needs
resource inspection; values additionally need resource read permission.
PID-scoped readers can access resources written by or associated with that PID.
An optional association does not grant permissions or add a required lifetime
dependency. Replacing a principal does not revive its old resource grants.

Association discovery requires both PID inspection and target resource
inspection. Hidden targets do not expose names or identifiers through discovery.
Changing required dependencies requires the quiescence and graph checks described
in the [native contract](TRANSIT_V1.md#bounded-operations-over-growing-collections).

## Read bases and atomic turns

An open view binds principal, PID, generation, next input, process revision,
resource revision and deadline to an authority-owned snapshot. Its deadline must
fit resource availability and the process settlement window. Capturing a read
is an observation; it does not require every read-only resource to remain at its
captured revision until commit.

`current_views` adds an explicit revision condition for selected members of the
turn's `views` set. Each non-null ID must occur once in that guard set and name a
declared view. Its resource must still have the captured revision at publication,
otherwise the turn rejects with `StaleStateResource`. This is useful for policy
or configuration reads whose freshness determines whether proposed work may be
published. A guard grants no write permission and does not extend a view's
deadline, ownership or lifetime. The authority's conditional journal append
fences intervening changes after validation. Ordinary unguarded views remain
frozen observations. Historical exact-retry receipt disclosure rechecks current
rights; it does not rerun a guard against later data or reverse accepted work.

A turn lists its views and optionally selects one as `write_view`. Each view must
remain authorized, unexpired and bound to that turn. The writable resource must
still have the captured revision and matching writer PID. Null mutations delete
keys, including already absent keys. A successful mutation sets the resource
revision and `last_turn` to the committing journal position.

Failed turns cannot publish mutations, outputs or effects. Successful and recorded
failed turns close their declared views. Rejected proposals publish nothing.
Ownership changes fence old views. Uncertain commits retain their exact signed
proposal, including view IDs, until reconciliation. Expiry after acceptance does
not undo a commit; retry disclosure still requires current resource rights.

Entry reads select a durable caller-owned view or an explicit current resource
revision. Point keys and exclusive continuation keys are mutually exclusive.
Current-resource continuations reject changed revisions. View reads use the
captured root but recheck current rights, ownership, dependency and view lifetime.
Catalog enumeration additionally binds continuation pages to an authority
position. Only a null continuation proves completion; filtered pages can be empty.
A final authority-tail check fences concurrent changes before disclosure.

[Retained read versions](READ_VERSIONS_V1.md) support explicit reads across inputs
and replacement activations. [Leased snapshots](INTERACTIVE_QUERY_V1.md#generic-leased-snapshots) provide
volatile native read sessions. Neither extends source lifetime or supplies access
rights. Missing keys, denial, unavailable storage/time, expired sources and stale
read bases remain distinct outcomes.

## Lifetimes, reclamation and recovery

Resource lifetime and history retention default to unlimited. `deadline_ms` is a
hard availability bound; views and retained versions cannot extend it. Required
dependency checks fence execution as soon as expiry is definite, before a
background operation materializes process retirement. Resource expiry and the
dependent process's `expire` operation are separate durable decisions.
Previously authorized external attempts retain their own settlement rules.

A PID-owned resource becomes unavailable when its owner retires; maintenance
records resource retirement when dependency checks permit it. An independent
resource retains its declared policy after writer retirement, without automatic
writer reassignment. Outages and quota pressure never authorize expiry.

`history_ms=null` prevents resource reclamation. Zero permits immediate eligible
reclamation; a positive value requires the declared age. Reclamation closes
eligible working view indexes and removes at most one entry page per operation.
It preserves resource identity/retirement metadata and historical receipt checks.
Retained read versions can pin reclamation until explicitly released.
[Catalog collection](CATALOG_V1.md) has separate opt-in and dependency requirements.

Journal prefix trimming uses the realm's explicit `allow_history_trim` policy.
Its published root retains current state, mailbox inputs, pending outputs, grants,
views and receipts. Pending work therefore survives removal of its original
journal records. Trimming does not reclaim immutable catalog pages or silently
release resource history. Restore from an old backup is not live authority.

An exact accepted turn can be reconciled after its view closes and after journal
trim. Current resource rights still govern disclosure. Revocation denies the
receipt without changing the original decision; restoring permission reveals
the same receipt. There is no alternate state endpoint or fallback decoder.

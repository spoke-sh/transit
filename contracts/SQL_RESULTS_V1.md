# SQL results v1

This contract defines logical statement outcomes and finite result consumption.
The [result library](../packages/zig/transit-sql-results/README.md) owns the shared
value types and deterministic progress rules. It has no SQL transport dependency.
The [native session contract](SQL_SESSION_V1.md) and
[database gateway contract](SQL_GATEWAY_V1.md) own concrete communication mappings.
The [shared client](../packages/zig/transit-sql-client/README.md) implements statement
submission and logical consumption for the console.

## Statements, results and observations

A statement attempt can be rejected before acceptance, resolve to a command
completion or row result, or remain unresolved. Uncertainty is an observation of
an original attempt, not a successful result and not a reason to create new work.
Execution, accepted-work settlement and result consumption have distinct lifetimes.

A command completion identifies its command kind and domain outcome. Applicable
matched/changed counts come from the owning operation; `changed <= matched`.
Inapplicable counts are absent. Zero is an authoritative count, never a substitute
for unknown. Table/schema commands preserve zero row counts and their original
operation attribution. Session settings have no durable operation ID.
Configuration reload preserves partial outcomes and pending-restart separately
from applied data mutations. Rejected/cancelled commands are not successful writes.

A result set has one identity, logical schema, observation and finite sequence of
row occurrences. Duplicates are preserved; an iteration sequence does not add
ordering guarantees to SQL without an applicable ordering clause. SELECT, SHOW,
DESCRIBE and EXPLAIN produce the same kind of result, including when empty.
A command without rows has no result schema.

Data observation identifies an explicit source cut, exact retained Table cut, or
ordered independent-Table vector. A vector is not an atomic catalog-wide cut.
Metadata observation identifies its catalog/settings/plan/probe scope, exact
known definitions, owner-supplied configuration revision where available and
session-settings commitment where relevant. Independent metadata observations do
not acquire a fictional data snapshot. EXPLAIN observes a prepared plan without
executing that plan. Hashes identify content; they grant no rights or retained pin.

## Abstract progress

Let a result's state be `(I, S, O, r, d, q, c, released)`:

- `I`, `S`, `O` identify the result, schema and observation content.
- `r` is the count of uniquely received row occurrences; `d` is delivered count.
- `q` is open, complete with terminal evidence, failed, or cancelled.
- `c` is reading, exhausted, or stopped by the consumer.
- `released` records resource closure independently of the observed outcome.

Counters are bounded unsigned 64-bit values with checked overflow. State retains
counts and attribution, not the entire row sequence. Adapters validate cell types
and ownership before applying these transitions.

| Event | Preconditions | Effect |
| --- | --- | --- |
| Open | Valid schema/observation | Zero counts, open outcome, reading consumption |
| Receive `n` rows | Same attribution, open, reading, unreleased, `n > 0` | Checked `r := r + n` |
| Deliver `n` rows | Reading, unreleased, outcome open/complete, `0 < n <= r-d` | `d := d+n`; if complete and `d=r`, consumption becomes exhausted |
| Complete with `N` | Same attribution, open, reading, unreleased, `N=r` | Record terminal evidence; exhaustion only when `d=r` |
| Fail/cancel | Before terminal evidence | Preserve prefix, record failed/cancelled, stop consumption |
| Stop/release | Any state | Stop unfinished consumption and release ownership; preserve previously verified completion |

Invalid transitions fail without advancing counters. No row can be delivered
more than once by consumption; logically duplicate rows remain distinct
occurrences. Full successful exhaustion delivers all received rows. No rows arrive
after terminal completion. The completion count is output cardinality, including
the query's SQL LIMIT, not source cardinality or number of scanned rows.

An empty result requires a schema and verified zero-row terminal. EOF, a closed
socket, cancellation, an expired cursor and a display limit cannot create it.
Receiving completion does not imply that a consumer displayed all received rows.
A caller may stop with known completion and undisplayed rows; those facts remain
separate. Closing an incomplete result never changes its outcome to complete.

## Communication projection

Communications realize the semantic events; the model does not require cursor
IDs, message encodings, fetch ordinals, sockets or a particular batch size.
A client adapter validates identity, schema, attribution and sequence before
accepting logical rows. A repeated physical batch contributes no additional
receive/deliver event. An empty terminal frame contributes only completion.

Splitting/joining physical chunks and inserting valid recovery/lease steps must
preserve the logical sequence and completion under the same owner/disclosure
outcomes. This is a conditional equivalence: revocation, cancellation, expiry or
budget exhaustion can change the actual disclosure and must stay visible.
Malformed peers are refused; their input is not normalized into a complete result.

A native adapter retains one unacknowledged batch and retries only that same
requested ordinal within the original budget and surviving session. It never
reexecutes SQL to replace a missing result or joins rows from different cuts.
A lost initial execute response is not equivalent to a lost fetch response.
Durable operation observation preserves the original account/instance/token.
Captured result reopening is explicit and begins a new consumption.

### Original workload evidence

The shared model also represents an original Stream/Queue workload through
`Observation.data.workload`: the canonical saved intent content, frozen source
schema and projection commitments, and the native append, consume or claim
receipt. Selection and delivery-position types are shared with the native result
owner. A descriptor establishes neither current rights nor continued retention.

A workload result's terminal includes the same intent content and a complete
position in that original selection. Append and claim output counts equal their
complete original row counts; their projections cannot hide accepted rows or
leases. Stream output count may be smaller than authenticated traversal coverage
because of filtering. Coverage retains the original range, cut, group and cursor
authentication; a numeric output count cannot substitute for it or authorize an
offset commit. The native owner must still authenticate any later settlement.

Missing coverage, a different intent or selection, a partial position or an
invalid output count rejects before semantic progress advances. Ordinary results
reject unsolicited workload completion evidence. Closing an incomplete result
does not manufacture coverage; closing after verified completion preserves that
evidence without claiming all rows were delivered. Neither transition ACKs,
renews, releases the native read dependency or advances a consumer group.

These are shared model and codec contracts. SQL workload admission, projection
execution and service reopening are not yet connected to these shapes.

## Ownership and consumers

Consumers read a schema, typed rows and a terminal outcome through the shared
client. Transport decoding, acknowledgement, retries, finite settlement and
remote closure belong to the adapter. Semantic failure and uncertain outcomes
remain visible; ordinary consumers do not implement raw response/status loops.

Logical row occurrences do not require row-major storage. A bounded batch can
borrow rows, column vectors or Arrow-compatible buffers without changing schema,
observation or progress. Row iteration is a convenience view; it may populate
reusable cell descriptors while borrowing variable payloads. Column/batch iteration
must not require a full row transpose. Non-copying slices preserve offset and
occurrence identity. Layout changes are not result boundaries.

An Arrow view describes compatible value buffers. Transit state tags and
error/conflict detail remain required for the complete logical cell. The nullable
Arrow value child alone cannot distinguish missing, null, type error and conflict.
Memory layout, physical value encoding and transport compression are independent
of logical type and collation. Adapters enforce both encoded and decoded budgets;
compression cannot change result truth, cardinality or cleanup rules.

Borrowed rows/chunks remain valid for the reader's documented lifetime. Retaining
nested or variable-width values requires an owned copy before the next pull can
reset scratch memory. Copies use caller-bounded storage. Streaming and bounded
materialized windows implement the same result model. A display limit does not
require draining the result to discover a count.

Resource release is deterministic locally and bounded remotely. Failure to close
a remote cursor falls back to session cleanup; durable Table pins retain their
journaled recovery owner and are not expired by a session lease. Current authority
is checked after buffering and before each bounded disclosure, including metadata,
repeats, empty responses and terminal counts. Previously received evidence cannot
grant access to another response.

## Transaction attribution

Interactive Table commands use `Operation.kind.transaction`. Every transaction
completion carries a validated `Transaction.Handle` and typed evidence. The
handle binds the current definition, native transaction identity, original begin
account/token and signed connection audience/role; it is recovery material, not
a credential or a substitute for current authorization.

A successful private INSERT/UPDATE/DELETE has outcome `provisional`, authoritative
matched/changed counts and the original transaction statement identity. It is not
an `applied` write to the public Tables. A rejected private statement carries its
typed refusal and no successful count. BEGIN carries its acquired common cut;
savepoint controls carry their original sequence, operation and completion.
COMMIT/ROLLBACK carries the actual durable decision and cleanup state. A COMMIT
that resolves to abort is rejected; requesting rollback after a committed decision
cannot turn that decision into an abort. Validation rejects missing attribution,
foreign handles, inappropriate evidence and successful counts on rejection.

A transaction row observation carries the handle, common cut, exact workspace
revision, last statement and one `ReadView` per source. Every source must match
that cut/revision/statement. The private content commitment includes the original
Table guard and private root; it is not an ordinary committed Table snapshot.
Query completion proves finite result coverage at that private revision, not
transaction commitment. Workspace advancement, rollback or closure invalidates
further disclosure from older cursors. Ordinary independent-source observations
remain independent; callers use BEGIN for a common multi-Table cut.

The service owns SQL controls and attachment in [SQL sessions](SQL_SESSION_V1.md).
External effect completion and unsupported participant kinds remain separate
from Table transaction decisions.

## Published business resource and investigation attribution

When a `ResultSet` is produced by evaluating a published business resource
([`PUBLISHED_RESOURCE_V1`](PUBLISHED_RESOURCE_V1.md)) or a statement bound to a
retained investigation basis ([`INVESTIGATION_V1`](INVESTIGATION_V1.md)), it
uses the same `ResultSet`, `Batch`, `Window`, `Progress`, five-state cell tags,
and lossless wide integer/decimal codecs without introducing a second result
protocol. `Observation.PublishedResourceObservation` binds the result stream to
`resource_object`, `publication_revision`, `definition_digest`,
`disclosure_mode`, `audience_policy_hash`, `verified_policy_epoch`,
`investigation_id`, `basis_revision`, `basis_digest`, `is_globally_atomic`, and
`attribution_receipt_digest`, re-verifying disclosure and withdrawal status
before each batch is released.

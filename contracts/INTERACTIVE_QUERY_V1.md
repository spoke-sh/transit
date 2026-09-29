# Interactive queries v1

The console supports this profile for finite Table, KV and Document queries.
Capabilities on the running authority determine native snapshot support.

## Ownership and compatibility

Each explicit SELECT starts a fresh client session and captures a fresh resource
snapshot. Fuze executes the compiled finite plan in the client, above the native
client boundary. The authority supplies generic authorized resource snapshots;
it neither parses SQL nor executes query operators. Table, KV and Document share
the source adapters, checked arithmetic, budgets and native Arrow codecs used
by [durable queries](../docs/reference/queries.md).

Interactive execution publishes no durable query progress or result segments.
It does not change input admission, turn commits, retained read versions, query
job recovery or durable caller sequences. Explicit durable submissions retain
their existing contract. Interactive sessions are not resumable after client or
authority restart. Failure never silently restarts a SELECT at a different cut.

## Generic leased snapshots

The additive growing capability `leased_snapshots` enables signed operations on
`/v3/query`, using the existing query domain and current principal identity:

| Operation | Request | Response |
| --- | --- | --- |
| `open_snapshot` | resource ID, fresh 16-byte nonce | snapshot token, captured resource metadata, lease and hard deadlines |
| `snapshot_entries` | token, optional key or exclusive after key | same snapshot identity and at most eight ordered entries |
| `close_snapshot` | token | echoed token; successful release is idempotent |

A token contains a random authority-instance epoch and monotonic instance-local
serial. It is an identity, never a bearer grant. A repeated open with the same
principal epoch, resource and nonce returns the same still-live snapshot. A
client does not retry an uncertain open after its bounded opening window; a
lost acknowledgement is cleaned up by the lease. Fresh statements use new nonces.

The initial profile admits at most 64 active snapshots per authority instance
and eight per principal, refusing additional work without evicting active work.
A snapshot's lease is 60 seconds and its hard lifetime is five minutes. Successful
reads renew the lease within the hard deadline; no operation can revive an
expired lease. The trusted clock's uncertainty interval must be strictly before
the deadline. Unavailable, uncertain or rolled-back time fails closed.

The authority holds only a catalog root and fixed metadata per active snapshot.
Expired slots are reclaimed during bounded admission/read sweeps; expiry is
effective at the deadline even without a housekeeping request. Restart drops all
slots and selects a new epoch. The append-only page profile keeps captured bytes
available independently of current root publication and journal checkpointing.
Physical page reclamation must account for these pins before it can be enabled.
This profile does not claim that releasing a snapshot deletes underlying data.

Every open/read checks current native inspect permission, resource inspect/read
permission, PID association scope, principal epoch and resource/dependency
liveness. A principal replacement cannot inherit an earlier principal's snapshot.
Source mutation does not change a captured cut. Resource retirement, expiry or
revocation still prevents subsequent disclosure. Slow materialization checks
lifetime again before returning bytes. Close only releases the authenticated
owner's slot; an unknown/expired token can be acknowledged without granting access.

## Query lifecycle, cancellation and output

The client compiles before opening a snapshot, validates the declared source
policy and requester identity, and binds the plan to the captured resource
revision and source/schema fingerprints. Source policy is rechecked before
each bounded output batch; immutable byte caches cannot substitute for it.
Page, segment and byte budgets apply as in the compiled bundle. The Table
adapter may seek or stop using an int64 primary-key comparison, including a
single-key lookup for equality. Fuze still evaluates the bound predicate. This
access optimization does not change plan fingerprints, result ordering, schema,
snapshot identity or current authorization. Other predicates use bounded scans.

Execution pulls one bounded source page at a time, computes one bounded Arrow
batch and waits for the output consumer before requesting more. Intermediate
output is a prefix. Success requires an explicit terminal completion and verified
source exhaustion or the plan's LIMIT, with contiguous batch ordinals and exact
row coverage. A transport, authorization, decoding, budget or output failure
cannot print a successful row-total footer or complete JSON frame.

Ctrl-C, console exit and output failure stop local evaluation and release the
snapshot. Client death stops local computation immediately; the lease bounds
remaining authority snapshot bookkeeping. If cancellation is observed before
terminal completion is emitted, the result is incomplete. Completion already
emitted remains complete. Cancellation does not undo a disclosed prefix or
promise recall of bytes already in transport. A blocked synchronous native call
is bounded by its configured request timeout; cleanup has the same bound and
falls back to lease expiry after failure.

Table output uses native typed Arrow batches and emits its total only on success.
JSON output uses an explicit interactive envelope with session identity, source
basis, batch ordinal, columns, typed cells and terminal completeness; it must not
fabricate a durable result manifest. A terminal empty batch is permitted.

## Required verification

Shared fixtures cover canonical signatures and response validation. Authority
tests cover stable snapshots across writes, current denial, epoch replacement,
retirement/expiry, renewal/hard deadlines, capacity, repeated close, lost-open
cleanup and restart. Real client tests cover all three sources, aggregates,
LIMIT, empty results, revocation after a prefix, interruption/output failure and
bounded memory. Performance measurements distinguish uninstrumented elapsed time
from native/provider attempt attribution and background polling.

The shared [signing fixtures](../packages/zig/transit-protocol/src/fixtures/leased-snapshots.json)
contain three independent canonical JSON/SHA-256 vectors. Fixed byte arrays use
the native typed JSON representation, including strings for valid UTF-8 byte
sequences. Inputs may use the schema's array representation; canonical signing
uses the typed encoding, not arbitrary input serialization.

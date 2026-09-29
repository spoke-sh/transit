# Transit growing profile v3

Status: implemented growing development profile. The explicitly selected node
profile, Zig client and [raw C ABI](../packages/zig/transit-client/docs/bindings.md)
support the bounded command/query boundary. Launcher defaults,
Session, the default Station interface and legacy foreign behavior bindings remain v2/state-v1. See the
[node guide](../apps/transit-node/docs/growing.md) for exact partial capabilities;
this does not authorize interpreting old history as a new profile. [The proof ledger](../tests/README.md)
records growth, integration and recovery qualification limits.

[Growth.zig](../packages/zig/transit-protocol/src/Growth.zig) owns the neutral types;
[transit-v3.schema.json](transit-v3.schema.json) is generated alongside the unchanged
[v2 schema](transit-v2.schema.json) by `just contract::generate`. Both are checked
by `just contract::check` for schema drift.

## Representation and compatibility

Every request/query carries version 3 and its realm. Principal, process, resource,
view, receipt, output and effect identities use 64-bit fields, with the public
numeric address space capped at 2^53−1. They are values, never resident array
offsets. Commands cannot infer an identity from a catalog slot. Sequence zero is
invalid for mutations; read queries use a separate signed type/domain.

Mutation signing hashes `transit.request.v3` followed by a NUL and canonical typed
JSON. Read signing uses `transit.query.v3` followed by a NUL. Ed25519 signs that
SHA-256 digest. Include defaults/nulls, retain declaration order and use compact
UTF-8 JSON with decimal integers and single-key union objects. Opaque values use
the existing owned lowercase-hex encoding. Validators reject unknown versions,
oversized integers, malformed values, duplicate mutation keys and ambiguous key/
cursor queries before signing. Encoded requests are bounded at 8 KiB.

Legacy signatures, grant identities, checkpoints, slot cursors and ABI structs
are not v3 values. A realm must select its profile explicitly; automatic migration,
mixed-profile writers and rollback into an older format are forbidden. Migration
is unimplemented; use a fresh realm for v3. Existing v2 histories and their
qualified code path remain available with their documented limits.

## Current identity observation

The additive `identity` read returns the authenticated principal, current coarse
permission bits, optional PID scope and policy revision, at the enclosing
response's authority position. It requires current `inspect` permission and
uses the normal v3 signed-query domain. It exposes no signing key or resource
grant and does not authorize a later operation by itself.

Inspection clients can require exactly read-only permissions, then request
bounded catalog pages at that same position. A grant change expires that cut;
clients must not join the old identity observation to a newer page. Current
resource grants continue to filter resource discovery independently. Earlier
query/signature encodings are unchanged; older nodes need not support this
new variant. Grant expansion and revocation invalidate existing cuts; stale cuts
fail explicitly. Board uses real signed HTTP for these observations; its scoped
inspection profile does not acquire mutation authority.

## Bounded operations over growing collections

A turn proposes up to four mutations in one writable associated resource, four
view identities and four outputs, with optional captured effect intent. Keys and
association names are 1–32 bytes; individual values retain their 256-byte bound.
These are per-operation bounds, not limits on resource rows, processes, principals,
retained calls or receipts. Large logical results require explicit segments and
complete-result evidence above these bounded records.

Capabilities must report the configured required-resource and lifetime-owner
graph validation budgets. The development profile requires quiescence of an
owner and its borrowers before changing that owner's required dependency topology;
it rejects changes that could invalidate an existing borrower's admitted work
budget. These are explicit operation/admission constraints, not limits on total
realm catalogs. The [core guide](../packages/zig/transit-core/docs/growing.md)
describes the current defaults and restrictions.

Entry reads select exactly one basis: a caller-owned durable view ID, or a resource
ID with an explicit current revision. The authority owns the root corresponding
to a view; clients never supply roots. Each view read rechecks current grants,
activation, dependencies and view lifetime. Current-resource reads recheck grants,
scope and lifetime and reject a changed resource revision. They do not pin old
state. Direct key lookup and an exclusive key continuation are mutually exclusive.

With `retained_read_versions`, a turn can atomically retain committed source
views for later inputs and replacement activations. The additive
[`turn_with_versions` contract](READ_VERSIONS_V1.md) preserves ordinary turn/query
signature bytes and supplies bounded, currently authorized historical reads.
Retaining a version does not extend owner/source expiry or grant access.

Pages contain at most eight records. A non-null cursor permits another read; only
a null cursor establishes completion. Catalog continuations require the first
response's authority position; any change expires that cut rather than mixing
revisions. Association listing uses revision IDs as cursors so filtering cannot
disclose hidden names in a continuation. Filtered pages may be empty with a
non-null cursor. Resource and association metadata require resource inspection
rights; reading values additionally requires read rights. A retained root/view is
never a bearer capability. Each successful response validates that its authority
tail still matches the policy/read basis before disclosure. The response may
arrive after a later revocation; it grants no subsequent read authority.

With the `association_lookup` capability, a query can resolve one association by
PID and exact name without a catalog continuation. It enforces current PID scope
and target inspection rights, returning null for either absence or a hidden
target. It uses the same final authority-tail fence as paged discovery. The
client validates the returned PID, name, resource and association revision.

With `resource_read_access`, the additive `read_access: resource_id` query
returns current active resource metadata only after checking both `inspect` and
`read` resource rights, the caller's current native identity/PID association
scope, and resource/dependency lifetime. It uses the normal signed-query domain
and final authority-tail fence. It neither reads entries nor retains a version.
The signature may be retained and resubmitted as evidence of the caller's
current read authority; every submission rechecks current keys and grants.
Revoking `read` denies this query even when `resource` metadata remains readable.
It grants no authority to a later read or mutation. Clients must require the
capability; older nodes may reject the new variant. Existing query and signature
encodings remain unchanged.

With `resource_read_batch`, `read_entries` acquires one to eight distinct keys
from one resource in a single authorized observation. Its fixed eight-slot
`keys` array is a nonempty contiguous prefix followed by nulls. The response
contains active resource metadata and eight corresponding optional entries;
null at a requested slot means that key was absent at the returned revision.
Unrequested slots are null. Input order is preserved, without sorting or a
continuation. Optional `revision` requires that exact current revision; null
selects the current cut. This does not retain a version or permit stale reads.

The query uses the existing signed-query domain, native PID association scope,
current resource inspect/read permissions, dependency/lifetime checks and final
authority-tail fence. Its memory and read work use the existing eight-entry
page budget; mutation limits are unchanged. Clients validate slot/key identity,
entry revisions and active resource metadata. They require the new capability;
older nodes reject this additive variant. Acquired bytes are one observation,
not an authorization cache for later disclosure.

Process lists expose recorded metadata. An individual process read checks current
execution eligibility before releasing its next mailbox input. Required dependency
expiry may fence execution before background work materializes terminal metadata;
these two observations must not be presented as equivalent readiness claims.

With `scoped_retry`, a current PID-scoped administrator can retry a blocked input
using `retry: {pid, expected_generation, failure_input}`. `Process.failure`
identifies the failed input in this profile; the generation distinguishes repeated
failed attempts at that same input. Retry clears the block, advances the generation
and removes ownership without consuming input or publishing application state.
It rechecks current work lifetime and required dependencies, cannot revive a
retired process, and does not authorize execution. Fresh ownership is a separate
operation. Permission, generation or failure-identity mismatches reject atomically.
Current inspection may disclose blocked process metadata with `input: null`;
that observation grants no permission to execute the retained head input.
A blocked handler does not close its mailbox: current send permission, work
lifetime and required state still govern admission behind the failed head.
Retry cannot move those later messages ahead of it.

Framework code should read individual keys or bounded batches through this
interface, retaining private mutations for one final authority decision. It must
not fetch the entire resource as a prerequisite to invoking a handler. Query
computation remains in the caller. The kernel validates dependencies and effects;
it does not execute application computations.

## Integration obligations

Finite deployments may configure a journal admission ceiling and a separate
control-reserve band in genesis. These fields are exposed in signed capabilities;
they are independent of row cardinality, retention and resident pages. At the
ceiling new obligations fail with `AdmissionClosed`; at the end of the reserve
new control mutations also fail with `ControlCapacity`. Exact accepted retries
and currently authorized reads remain available. Neither trim nor restart resets
this accounting. The [authority guide](../packages/zig/transit-core/docs/authority.md#growing-profile-an-explicit-control-reserve-not-a-derived-one)
owns allowed reserve operations and the finite physical qualification.

Delivery resolves one retained output under current courier authority. Pending
route order is per source/destination pair; a later output cannot bypass an
unresolved predecessor. Admission or terminal disposition releases that route.
Process termination/known expiry immediately fences unattempted work; individual
outbox/effect metadata may await bounded disposition. `cancel_effect` is an
administrative operation restricted to an unattempted intent of a terminal caller.
It cannot cancel an authorized attempt or claim that external work stopped.

Authorized effects retain their executor, attempt, observation budget and optional
deadline independently of caller retirement. Finite callers require a finite
reconciliation deadline. The executor's current effect permission is required
for new observations; an administrator with effect permission can close an orphaned
attempt. A result after caller retirement remains evidence and cannot revive that
PID. Closed attempts reject new results; exact historical retries still require
current permission. The growing engine currently enforces these rules internally;
the explicit HTTP profile exposes them. A separate node maintenance process
materializes terminal dispositions with bounded scans. Provider deployment and
large-catalog maintenance lag remain unqualified.

The [immutable catalog](../packages/zig/transit-core/docs/pages.md#typed-catalog)
is the storage basis. One conditional journal decision must publish state roots,
mailbox progress, outputs, principal sequence and retry evidence together. Staging
does not accept work. Recovery must consume published roots without dispatching
effects or executing handlers. Unlimited retention requires growing durable
receipt, wait and result history; cache eviction cannot authorize deletion.

The development `checkpoint` command requires explicit realm/application
`allow_history_trim` genesis opt-in; unlimited journal history remains the default.
Capabilities distinguish support for root-history reclamation from the selected
retained-history policy. The checkpoint publication records a monotonic floor
that retains its own complete root-bearing journal entry. Trusted maintenance
verifies committed intent and root snapshot before advancing that floor. It does
not delete catalog pages, receipts, accepted inputs, values or captured roots.
This does not add a public history query or page-GC capability.

### Conditional local worker replacement

`create_principal` and capability-gated `rotate_worker` both require
root authorization. `create_principal` takes the existing Grant fields but
refuses any previously allocated subject, including a revoked one. Exact retries
retain their original receipt; a fresh operation cannot overwrite another
installation's identity.

`rotate_worker` requires an executable PID, its exact prior generation and a
PID-scoped worker with the expected current public key and permission mask.
The worker must retain inspect/execute rights. One native decision replaces its
key, advances ownership and records its policy revision. Its signed sequence
and resource-grant epoch remain unchanged: rotation cannot renew a removed
resource permission. It rejects an unchanged key, revoked worker, foreign scope,
stale generation, blocked process or permanent retirement. A revocation racing
prepared activation fences its conditional journal append.

This operation preserves PID, resources, mailbox, state, permit and outputs;
it is eligible for the existing finite control reserve. It neither launches a
worker nor declares application compatibility. The local manager attributes
bootstrap evidence and checks artifact/configuration compatibility separately.
Ordinary grant replacement still advances the grant epoch and invalidates old
resource grants. Existing command signing bytes remain unchanged.

The declared capabilities expose unsupported runtime-binding and Station
extensions explicitly. The service reports history-reclamation support separately
from its selected unlimited/checkpointed policy; only genesis opt-in allows a
public `checkpoint`. A trusted `--maintain` process authenticates current
realm-wide control authority, verifies committed intent and performs physical
trimming. Its optional interval cannot authorize retention on its own.
Qualification is scoped to the exercised authority transitions, provider
persistence, current read/receipt authorization, finite lifetime/settlement
behavior, quotas/control reserves, client/Station usage and failure schedules
recorded in the proof ledger. Matching command names do not establish feature
equivalence with v2.


## HTTP boundary

`POST /v3/command` accepts `SignedRequest` and returns the shared positive-position
`Receipt`. `POST /v3/query` accepts the separately signed `SignedQuery` and returns
`Response`. Generated route/type metadata owns both. Requests remain bounded by
the service body/deadline limits, and no legacy-route fallback occurs. Typed
rejection responses distinguish conflict, denial, invalid proposals and uncertain
service/clock failures. Transport loss, malformed success and response allocation
failure after acceptance cannot authorize a new mutation sequence.

Client response validation checks version/realm, query variant, requested IDs,
resource/view revision basis, safe integer range, dense ordered pages and advancing
continuations. Empty filtered catalog pages can legitimately advance. Output IDs
have their own sequence and are not journal coordinates. These checks reject a
malformed response; they do not replace an authenticated deployment boundary or
prove that a compromised authority reports truthful application data.

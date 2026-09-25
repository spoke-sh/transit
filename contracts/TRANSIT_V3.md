# Transit growing profile v3

Status: M10 development contract. The wire types and generated schema exist;
the running node/client/Station continue to use v2 and state-v1. This document
does not advertise a deployed v3 capability or authorize interpreting old history
as a new profile. [M10](../docs/roadmap/M10.md) retains the integration gates.

[Growth.zig](../packages/zig/transit-protocol/src/Growth.zig) owns the neutral types;
[transit-v3.schema.json](transit-v3.schema.json) is generated alongside the unchanged
[v2 schema](transit-v2.schema.json) by `just contract::generate`. Both are checked
by `just contract::check` before transport integration.

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
mixed-profile writers and rollback into an older format are forbidden. Explicit
migration remains an M10 integration obligation. Existing v2 histories and their
qualified code path remain available with their documented limits.

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

Entry reads use a durable view ID and an optional exclusive key cursor. The
authority owns the root corresponding to that view; clients never supply roots.
Each read must recheck current grants, activation, dependencies and view lifetime.
Pages contain at most eight records. A non-null cursor permits another read; only
a null cursor establishes completion. Direct key lookup and pagination are
mutually exclusive. Catalog listing cuts use the authority position and must
fail if that cut can no longer be honored, rather than mix revisions.

Framework code should read individual keys or bounded batches through this
interface, retaining private mutations for one final authority decision. It must
not fetch the entire resource as a prerequisite to invoking a handler. Query
computation remains in the caller. The kernel validates dependencies and effects;
it does not execute application computations.

## Integration obligations

The [immutable catalog](../packages/zig/transit-core/docs/pages.md#typed-catalog)
is the storage basis. One conditional journal decision must publish state roots,
mailbox progress, outputs, principal sequence and retry evidence together. Staging
does not accept work. Recovery must consume published roots without dispatching
effects or executing handlers. Unlimited retention requires growing durable
receipt, wait and result history; cache eviction cannot authorize deletion.

The declared capabilities expose unsupported runtime-binding and history-
reclamation extensions explicitly. These fields currently describe the contract
shape, not a live capability response. Before service qualification, M10 must
qualify all authority transitions, provider persistence, current read/receipt
authorization, finite lifetime/settlement behavior, quotas/control reserves,
client/Station usage, failure schedules and compatibility tests. There is no
implicit feature equivalence with v2 merely because command names resemble it.

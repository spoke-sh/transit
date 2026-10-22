# State resources and associations

Store durable values in versioned resources. Read the keys or bounded pages a
turn needs, then propose mutations together with input progress and outputs.
Worker fields and caches are volatile; they are not the resource or its lifetime.

## State and higher-level resources

Native v1 uses immutable roots and bounded catalog/resource pages. Retained size
is independent of resident cache, subject to explicit operation, admission and
storage bounds. A turn mutates one resource owned by its writer PID. It does not
supply arbitrary transactions across resources.

Station Tables add typed schemas and rows within that commit boundary. Station
Documents add accepted structured/text changes and immutable indexes. Neither
introduces an alternate state authority or silently converts old history. Named
KV and Document objects can also be registered in a shared catalog namespace
through `DeclarativeCatalog`: `Declaration.compile` validates `CREATE KV` and
`CREATE DOCUMENT` definitions and lowers them to two-phase catalog operations
(`initializing` reservation followed by `live` resource binding and publication),
with `rename`, `DROP RESTRICT` dependency enforcement, permanent retirement of
dropped object IDs, and shared `inspectLifecycle` / `policyReferences` inspection.

## Identity, access and ownership

A resource has a realm-qualified identity and revision. A process association
records its access/dependency relationship to that resource. These are separate
from the writer PID, resource lifetime owner and current grant.

Association changes cannot grant access, transfer writer authority or keep an
expired resource alive. A process can be allowed to inspect metadata without
reading entries. A grant can be revoked even while an association or read-view
handle still exists. Check [current authorization](security.md) for every read,
commit and receipt reconciliation.

## Read and commit

Open an authorized view against the declared resource revision. Bound page sizes,
scan work and active views. Preserve its continuation and source evidence when
paging; do not merge pages from different cuts into an invented snapshot.
Views and borrowed buffers have explicit lifetimes in the [caller API](callers.md).

Read-only views preserve their cut when a resource advances. A turn can explicitly
list a view in `current_views` when a policy or configuration read must remain at
that resource revision until publication. A changed guarded resource rejects the
whole proposal without consuming the input. Guards do not grant mutation rights;
the one writable resource still has its own revision and owner checks. Station's
Zig `Captured.requireCurrent()` records this condition. Current grants and
lifetimes apply to guarded and unguarded reads alike.

A turn validates its read/dependency basis and one mutated resource alongside
input progress and outputs. Per-turn KV mutation/value limits apply; larger data uses staged [immutable publication](../../../contracts/STATION_PUBLICATION_V1.md).
Staging publishes bytes incrementally, but only the final accepted head makes the
new logical value visible. A staging acknowledgement is not final acceptance.

Publication can bind a descriptor, application head and reply in one final turn.
It verifies byte completeness, not honest computation or Document merge validity.
Interrupted staging remains recoverable or explicitly abandoned, with declared
quotas and identity evidence; pressure never silently accepts a prefix.

## Data and history lifetimes

Current state can survive trimming old history through a validated checkpoint.
A live value does not expire merely because its last write is old. Retention is
unlimited by default; finite policies need explicit opt-in.

A required resource limits the dependent process's recovery lifetime. An optional
resource's expiry is an explicit read outcome. Inline bytes that happen to encode
a reference do not create an implicit dependency. Neither associations nor old
root references grant arbitrary retention pins.

Capacity bounds active work and physical storage; it does not authorize expiry.
The native protocol separates collection size from resident memory. Configure
disk capacity and admission quotas through [retention and capacity](retention.md).

For exact fields, values and compatibility use [state v1](../../../contracts/STATE_V1.md)
and [native v1](../../../contracts/TRANSIT_V1.md). For runnable APIs use the
[native client](../../../packages/zig/transit-client/docs/growing.md),
[Tables](tables.md) and [Documents](documents.md).

# General Table metadata

A Table name resolves to a stable object and an accepted immutable
interpretation. The direct catalog connection identifies a realm, catalog
lifetime resource, catalog ID, branch, audience, principal and selected role.
The lifetime resource does not contain Table rows. Each Table uses its own
acceptance log and paged row, operation and pin indexes.

`DirectTableProtocol.lookup` returns the full prepared binding, logical schema,
authorization object, current position, changed position and row count. Reading
metadata starts no work and grants no future access. Names can be reused after
DROP; a saved operation or dependent definition still names its original object.

CREATE reserves its name during catalog admission. Native registration and Table
acceptance must finish before lookup exposes it. ALTER preserves column identity
and distinguishes metadata changes from bounded validation or rewrites. RENAME
retains the object; DROP requires dependencies to be closed and preserves exact
historical receipts. These operations share the
[declarative catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md).

Point and finite batch DML freeze the complete operation binding and typed
intent. Accepted data and row/index changes publish with matched/affected counts
at one Table position. Private staging is not a visible statement prefix.
Catalog progress, Table acceptance and a caller's receipt are separate evidence.

## Inspection and retained interpretation

Directory pages contain up to eight visible entries. Their continuation binds
the current contract definition, connection, selection and directory position.
A changed directory requires a fresh listing. Each Table position is an
independent observation; enumeration does not create a cross-Table snapshot.
Empty filtered pages can have a continuation.

An explicit read pin retains an accepted Table position, original schema and
unflushed accepted data. Save the pin owner before acquisition. After a lost
reply, inspect that owner instead of allocating a replacement. Retained metadata
and reads recheck current source rights and lifetime, including after DROP and
name reuse. Release addresses the original pin and does not imply physical
reclamation. An arbitrary staged schema is not accepted historical evidence.

Retained source inspection resolves the original interpretation and current
native authority objects through one request-local Table owner. Snapshot and
history responses retain their existing wire evidence. Historical delegation
still validates the original grant before opening a selected successor; each
storage read checks its live lease, and the authenticated service checks all
observed rights after encoding the reply. This reuses one recovery within a
request without treating cached metadata as permission for another request.

`DirectTableReader.selectPlan` freezes a schema-bound finite plan before traversing
an ordinary retained snapshot. The reader owns its canonical bytes, literals and
physical column selection. `next` returns owned batches with original source
ordinals and an optional deferred predicate failure. Empty batches may be
nonterminal; only verified complete coverage establishes exhaustion. Decode or
attribution failure leaves traversal unchanged. The copied failure follows the
batch's earlier rows and never means completion. Local destruction releases these
buffers without releasing the durable pin. [Finite execution](../../transit-query/README.md)
consumes this evidence and rechecks current rights after computation.

## Neutral general Table callers

The ABI, port and language SDKs share `DirectTableBridge.Session`. SQL compilation
and typed preparation produce independently owned saved work. Loading saved
bytes performs no I/O; admission, execution and cancellation are explicit.
Closing a handle has no remote cancellation or pin-release effect.

Full-width data identities and positions use canonical decimal strings; native
counters remain bounded JSON numbers. Mandatory contract identifiers reject
missing or foreign artifacts. Every returned allocation belongs to its caller.
The [caller guide](../../transit-station-bindings/docs/catalog.md) documents
configuration, exact actions, error evidence and ownership.

Use the [direct owner guide](direct-catalog.md) for construction and recovery,
the [direct request contract](../../../../contracts/DIRECT_TABLE_V1.md) for exact
request/response semantics, and the
[data lifecycle contract](../../../../contracts/DATA_LIFECYCLE_V1.md) for identity,
acceptance and isolation rules. [Executed proofs](../../../../tests/README.md)
distinguish volatile component schedules from disk and installed caller evidence.

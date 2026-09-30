# State, publication and lifetime

This account explains how durable state, bounded resident work and recovery
evidence fit together. It consolidates resource, Table, Document and retention
reasoning. The [state](../reference/state.md), [Table](../reference/tables.md),
[Document](../reference/documents.md) and [retention](../reference/retention.md)
references own APIs, supported types and numeric bounds.

## Model

A resource has a realm-qualified identity and immutable committed revisions.
An association records a process's declared access/dependency relationship.
Writer identity, lifetime ownership and permission remain independent facts.
The supported turn boundary mutates one resource with input progress and outputs;
reading other resources does not create a global snapshot or transaction.

The paged representation separates retained data from the pages, operation
batches and active views held in memory. This distinction depends on bounded
access at every layer; placing a paged backend beneath a caller that loads the
entire collection would not establish a bounded working set.

## Visibility and publication

Larger logical values are staged as bounded immutable pieces. Staging establishes
the existence of those bytes, while a final validated head/root establishes their
logical visibility. A crash before that decision can leave staged data but must
not expose a partially accepted value. A crash after acceptance must recover the
same head and required dependencies.

This separates byte completeness from semantic validity. Publication can verify
pieces and commitments; a Document owner must still validate change dependencies,
merge rules and the accepted index. The
[publication contract](../../contracts/STATION_PUBLICATION_V1.md) and
[Document contract](../../contracts/STATION_DOCUMENT_V1.md) own those different checks.

## Typed state and causality

| Representation | Additional meaning | Boundary it does not remove |
| --- | --- | --- |
| KV | Explicit opaque keys and values | Current access and revision basis |
| Table | Declared schema, primary keys and typed row encoding | One-resource turn atomicity |
| Document | Stable object/operation identities, observed dependencies and explicit conflicts | Fenced acceptance and current write permission |

Document mergeability is a property of changes under declared rules, not
permission to publish them. Visible values alone are insufficient recovery state:
causal dependencies, deletions and history floors prevent stale changes from
resurrecting removed content. Missing, null and conflict therefore remain distinct
through reads and query projections.

## Retention argument

Checkpoint publication must precede trimming the history it replaces. The
checkpoint and retained tail must preserve the specified recovery projection,
including unfinished work and identity/rejection evidence. Once that prefix is
removed, the checkpoint is essential data rather than an optional cache.

Logical expiry, terminal closure and physical cleanup have separate conditions.
A late physical delete must not target a replacement identity. An old reference
must not renew permission, revive a retired resource or pin arbitrary history.
Unlimited retention is the default; capacity pressure can refuse new admission
but cannot supply application consent to expiry.

## Tradeoffs, evidence and limits

Keeping every retained value resident would make memory proportional to durable
cardinality. Bounded pages avoid that dependency but introduce indirection,
cache misses and staging/cleanup work. The
[storage account](storage-runtime.md) and [measured costs](../reference/performance.md)
explain those costs without treating configured cache size as measured peak RSS.

[State-resource evidence](../../tests/README.md#m7-state-resources),
[publication evidence](../../tests/README.md#m14-immutable-publication) and
[Document qualification](../../tests/README.md#m17-qualification) record the
applicable contracts, crash schedules, commands and limits. They do not establish
arbitrary multi-resource transactions, generic dependency deletion or erasure
from every external copy. Historical details remain in the
[state](../history/STATE.md), [Tables](../history/TABLES.md),
[Documents](../history/DOCUMENTS.md) and [retention](../history/RETENTION.md) records.

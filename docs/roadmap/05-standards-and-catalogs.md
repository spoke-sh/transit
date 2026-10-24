# 5. Standards, collations and historical catalogs

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Establish historical query, collation/encoding fidelity, multi-model and branch
semantics using the [grammar inventory](../handbook/reference/sql/grammar-surface.md),
[query model](../handbook/internals/query-engine.md) and
[state model](../handbook/internals/state-model.md).

Extend the [shared data lifecycle](01-declarative-data-lifecycle.md) and
[manifest-backed storage hierarchy](02-storage-and-query-performance.md).
Historical inspection must answer which definition, physical encoding and
collation interpreted the data, which immutable Manifest (`manifest/v{N}`) and
`.tseg` segments formed the snapshot, what a derived result depended on and
which current policy (`policy_epoch`) permits disclosure. Do not introduce a
second catalog identity or confuse a historical definition with current rights.

## Delivery sequence

The catalog/snapshot contract in
[#125](https://github.com/spoke-sh/transit/issues/125), retention/pins in
[#127](https://github.com/spoke-sh/transit/issues/127), and exact codec/collation
and layout identities in [#118](https://github.com/spoke-sh/transit/issues/118)
and [#128](https://github.com/spoke-sh/transit/issues/128) are foundations from
milestones 1–2. This milestone implements historical binding and conformance
over those contracts, rather than introducing a second snapshot representation.

1. **Publish a machine-readable standards and collation ledger:** edition/correction,
   feature, owner, dependencies, deviations and separate
   `parse`/`lower`/`execute`/`recover`/`transport` states. Include explicit
   collation descriptors (`UCS_BASIC`, `EBCDIC_037_PAD`, `EBCDIC_1047_NOPAD`,
   `ASCII_CI`, versioned `UCA`) and physical encoding rules (`COMP-3`, `ZONED`,
   `COMP`/`COMP-4`, `IBM_HFP`, `EBCDIC`). Generate capabilities and licensed
   positive/negative fixtures.
2. **Define shared operators and read/mutate/capture/dispatch effects:** propagate
   determinism, fallibility, 5-state cell tags (`value`, `null`, `missing`,
   `type_error`, `conflict`), collation rules, change mode and work bounds.
   Explanation (`EXPLAIN`) does no work.
3. **Define manifest-backed historical catalogs:** bind stable catalog/column
   identities (`CatalogId`, `DefinitionId`, `ColumnId`), ancestry, column
   encodings and collations, immutable `.tseg`/`.tdel` inclusion lists,
   consistency basis (durable manifests and retained `TransitLog` frontiers,
   including accepted unflushed data), typed
   selectors, current access (`policy_epoch`) and conditional head publication.
4. **Bind historical schemas, collations, views, graph mappings and decoders before resolving names or compiling:**
   ensure `FOR SYSTEM_TIME AS OF` queries evaluate comparisons, zone-map pruning,
   sort orders and foreign/mainframe decodings against the exact definition and
   collation recorded at the snapshot manifest, while checking authorization
   against the current `policy_epoch`. Moving a branch cannot change an accepted
   request's basis.
5. **Expose historical inspection and explicit projections through shared operations:**
   distinguish metadata permission from row/segment access and report exact
   manifest provenance.

## Boundaries and evidence

Target selected SQL:2023, SQL/JSON, SQL/PGQ and SQL/MED features explicitly.
GQL, Cypher and PGQL need separate frontend/compatibility evidence. Reserve
system-time syntax for temporal semantics; resource revisions, application
revisions, `TransitLog` LSNs and snapshot manifest versions remain distinct types.

Qualify rename/drop/recreate, changed historical views, collation-sensitive
historical comparisons (`EBCDIC` versus `UCS_BASIC`), unavailable/expired
`.tseg` history, old-column success/new-column rejection, explicit projections,
metadata-only rights, revocation after a prefix and branch movement after
admission. Publish independent transition/canonical fixtures before implementing
branch storage.

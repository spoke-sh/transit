# Define Initial Replication Model And Boundaries - SRS

## Summary

Epic: VDd1J2IDM
Goal: Define the first clustered replication model, explicit durability boundaries, and the initial execution slice below consensus and multi-primary semantics.

## Scope

### In Scope

- [SCOPE-01] Select the first replication design center for clustered `transit`, including the concrete replication unit and ownership model.
- [SCOPE-02] Define explicit acknowledgement and durability boundaries across local, replicated, and tiered modes for the first clustered slice.
- [SCOPE-03] Capture the invariants the clustered design must preserve around ordering, lineage, object storage, and single-engine semantics.
- [SCOPE-04] Decompose the chosen clustered model into the first executable voyage and initial stories without crossing into consensus or multi-primary semantics.

### Out of Scope

- [SCOPE-05] Implementing replication, follower catch-up, or lease transfer code in the engine or server.
- [SCOPE-06] Full distributed consensus, quorum writes, or multi-primary conflict resolution.
- [SCOPE-07] Any server-only storage, lineage, or manifest semantics that diverge from the shared engine.
- [SCOPE-08] Browser/public ingress, operator UX, or client-surface work unrelated to clustered replication boundaries.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Choose and document the first clustered replication model, explicitly naming the replication unit and ownership rules the initial slice will use. | SCOPE-01 | FR-02 | manual |
| SRS-02 | Define explicit acknowledgement and durability semantics for the first clustered model, distinguishing local acceptance, replicated acceptance, and tiered/object-store publication. | SCOPE-02 | FR-03 | manual |
| SRS-03 | Publish the ordering, lineage, and storage invariants that the clustered model must preserve so future delivery cannot drift into server-only semantics. | SCOPE-03 | FR-01 | manual |
| SRS-04 | Decompose the selected model into at least one follow-on execution voyage and initial story slices that stay below consensus and multi-primary scope. | SCOPE-04 | FR-03 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must preserve the one-engine thesis: clustered planning cannot introduce a separate server-only storage or lineage model. | SCOPE-01, SCOPE-03, SCOPE-04 | NFR-01 | manual |
| SRS-NFR-02 | The selected first slice must remain explicitly below consensus, quorum writes, and multi-primary behavior. | SCOPE-01, SCOPE-04 | NFR-02 | manual |
| SRS-NFR-03 | Durability and acknowledgement language must remain explicit enough for operators to distinguish local, replicated, and tiered guarantees. | SCOPE-02, SCOPE-03 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Guarantee Surface

The first clustered slice uses three operator-facing commitment boundaries:

| Boundary | Meaning | Required Condition | Explicit Non-Claim |
|----------|---------|--------------------|--------------------|
| `local` | The primary node has durably accepted the append on its writable local head. | The append is committed under the existing local durability contract on the primary. | The record is not yet promised to followers or to object-store-backed restore. |
| `replicated` | The append has crossed the first clustered handoff surface and is available for follower catch-up. | The primary has rolled the relevant immutable segment and published that segment plus the manifest update through the remote tier so followers can restore from published history. | This does not mean a follower has already hydrated the segment, accepted writes, or assumed ownership. |
| `tiered` | The append is durable as object-store-backed history under the tiered-storage contract. | The relevant immutable segment, manifest update, and referenced objects are durable in the remote tier and can seed cold restore independently of the primary's hot local state. | This does not imply consensus, quorum acknowledgement, or multi-primary failover semantics. |

For the first clustered model, `replicated` and `tiered` can be satisfied by the same publish path, but they remain distinct operator meanings: `replicated` describes clustered handoff for follower catch-up, while `tiered` describes remote durability and restore.

## Preserved Invariants

- Append ordering remains defined by the primary's single writable stream head; replication and restore must not reorder acknowledged history.
- Rolled segments and manifest updates are immutable replication units; clustered delivery must not rewrite acknowledged records in place.
- Branch, merge, and lineage semantics stay identical to the shared engine; followers consume published lineage rather than inventing a second branch model.
- The remote tier remains the publication and restore substrate for clustered history; the first slice cannot introduce a separate server-only replication log or storage format.
- Large object payloads remain referenced artifacts whose durability must line up with manifest publication instead of being forced through a distinct replicated hot path.

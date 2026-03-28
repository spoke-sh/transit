# VOYAGE REPORT: Deliver Remote-Tier Replication Handoff Foundations

## Voyage Metadata
- **ID:** VF7VP3H4s
- **Epic:** VDd1J2IDM
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Bootstrap Read-Only Follower Catch-Up
- **ID:** VF7VSpveo
- **Status:** done

#### Summary
Bootstrap the first follower path by restoring and advancing from published remote-tier history while keeping followers explicitly read-only and aligned with the shared engine.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] Allow a follower to bootstrap from published remote-tier history using the shared restore path while remaining read-only. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-1.log -->
- [x] [SRS-02/AC-02] Define follower catch-up in terms of published frontier advancement rather than direct record fan-out or follower-local writes. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] Keep follower behavior below consensus, failover, and ownership-transfer semantics. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->

### Expose Replicated Acknowledgement Mode
- **ID:** VF7VSqlep
- **Status:** done

#### Summary
Expose an explicit `replicated` acknowledgement mode that waits for publication of the clustered handoff frontier and keeps operator proof surfaces clear about what has, and has not, been guaranteed.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Add an explicit `replicated` acknowledgement path that waits for publication of the handoff unit rather than reporting success on local durability alone. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [x] [SRS-04/AC-01] Extend proof or inspection surfaces so operators can distinguish `local`, `replicated`, and `tiered` commitments for the clustered slice. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log -->
- [x] [SRS-NFR-03/AC-01] Keep guarantee language explicit about publication, follower hydration, and the absence of failover or quorum claims. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log -->

### Surface Published Replication Frontier
- **ID:** VF7VSqtej
- **Status:** done

#### Summary
Surface the published segment-plus-manifest frontier that defines the clustered handoff boundary so follower catch-up, replicated acknowledgements, and proof surfaces all share one inspectable replication unit.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Expose the published segment and manifest frontier as the first clustered handoff surface without creating a separate replicated log. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-01/AC-02] Make frontier metadata explicit enough for follower catch-up and proof surfaces to identify the published positions and manifest state in play. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, SRS-01:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] Preserve shared-engine lineage and object-store semantics in the surfaced frontier. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->



# VOYAGE REPORT: Object-Store Authority With Warm Cache

## Voyage Metadata
- **ID:** VGh5BgrVO
- **Epic:** VGh59soBt
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Define Object-Store Authority And Warm-Cache Configuration Surface
- **ID:** VGh5uL5xM
- **Status:** done

#### Summary
Define the server configuration and operator contract that makes object storage authoritative for tiered durability while treating local filesystem state as warm cache and working set only.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] The server configuration contract names the object-store authority inputs and the warm-cache inputs needed for hosted tiered durability. <!-- verify: manual, SRS-01:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-01/AC-01] The design keeps server authority aligned with the shared manifest and lineage model instead of inventing a server-only durability semantic. <!-- verify: manual, SRS-NFR-01:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5uL5xM/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5uL5xM/EVIDENCE/ac-2.log)

### Hydrate Transit Server From Object-Store Authority When Warm Cache Is Missing
- **ID:** VGh5wGFJz
- **Status:** done

#### Summary
Implement the hydrate path that rebuilds server working state from authoritative remote manifests and segments when the warm cache is absent or stale.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] transit-server can rebuild its working state from the authoritative remote tier when warm local state is missing or discarded. <!-- verify: cargo test -p transit-server hydrate_from_object_store_ -- --nocapture, SRS-02:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] The hydrate path preserves acknowledged tiered history even when the warm cache has been removed. <!-- verify: cargo test -p transit-server hydrate_from_object_store_ -- --nocapture, SRS-NFR-02:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5wGFJz/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5wGFJz/EVIDENCE/ac-2.log)

### Prove Hosted Restart And Warm-Cache Recovery Through Just Screen
- **ID:** VGh5xG0Td
- **Status:** done

#### Summary
Extend the human proof path so operators can watch tiered publication, warm-cache loss, server restart, and authoritative recovery without guessing whether the result is only local or truly tiered.

#### Acceptance Criteria
- [x] [SRS-04/AC-01] `just screen` or its equivalent proof surface demonstrates restart or deliberate cache-loss recovery from the authoritative remote tier. <!-- verify: nix develop --command just screen, SRS-04:start:end, proof: ac-1.log-->
- [x] [SRS-03/AC-01] The proof output distinguishes `local` from `tiered` posture so the recovery claim stays explicit. <!-- verify: nix develop --command just screen, SRS-03:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5xG0Td/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5xG0Td/EVIDENCE/ac-2.log)



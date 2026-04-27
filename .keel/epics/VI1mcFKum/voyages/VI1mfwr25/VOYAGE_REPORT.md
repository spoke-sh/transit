# VOYAGE REPORT: Harden Hosted Protocol Auth And Lease Fencing

## Voyage Metadata
- **ID:** VI1mfwr25
- **Epic:** VI1mcFKum
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Enforce Hosted Auth Posture In Server Protocol
- **ID:** VI1mjhoAK
- **Status:** done

#### Summary
Enforce hosted token auth at the framed protocol boundary while preserving explicit local `none` mode and remote error envelopes.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] A server configured for token auth rejects unauthenticated framed requests before shared-engine mutation, while `none` mode remains available for local development. <!-- [SRS-01/AC-01] verify: cargo test -p transit-core auth, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] Auth failures return remote error envelopes with request id, topology, stable error code, and actionable message. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core token_auth_rejects_unauthenticated_requests_before_shared_engine_mutation, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Auth enforcement is a server boundary concern and does not introduce server-only storage or lineage semantics. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VI1mjhoAK/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VI1mjhoAK/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VI1mjhoAK/EVIDENCE/ac-3.log)

### Replace Object Store Lease Writes With Conditional Fencing
- **ID:** VI1mjiCB8
- **Status:** done

#### Summary
Replace plain object-store lease overwrites with conditional fencing or an explicit weaker-backend contract for acquire, heartbeat, handoff, and manifest publication.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Object-store consensus uses conditional writes or equivalent generation checks for acquire, heartbeat, and handoff where the backend supports it. <!-- [SRS-03/AC-01] verify: cargo test -p transit-core consensus::tests::object_store_consensus, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [x] [SRS-04/AC-01] Manifest publication fails closed when the current remote lease proof cannot be verified against the object-store authority. <!-- [SRS-04/AC-01] verify: cargo test -p transit-core manifest_publication_enforces_distributed_fencing, SRS-04:start, SRS-04:end, proof: ac-2.log-->
- [x] [SRS-NFR-02/AC-01] Tests cover stale owner overwrite attempts and prove Transit rejects overstated ownership or durability claims. <!-- [SRS-NFR-02/AC-01] verify: just test, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VI1mjiCB8/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VI1mjiCB8/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VI1mjiCB8/EVIDENCE/ac-3.log)

### Define Blockchain-Style Finality And Fork Proof Contract
- **ID:** VI1mjiIBI
- **Status:** done

#### Summary
Define the blockchain-style finality and fork proof contract that maps records, branches, checkpoints, and explicit merge or selection artifacts onto Transit lineage without claiming a full chain runtime.

#### Acceptance Criteria
- [x] [SRS-05/AC-01] A public contract documents blocks as records, forks as branches, finality as checkpoints, and reorg handling as explicit merge or canonical-selection artifacts. <!-- [SRS-05/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n "Block|Fork|Finality marker|Reorg decision|canonical-selection" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-05:start, SRS-05:end, proof: ac-1.log-->
- [x] [SRS-05/AC-02] Proof envelope examples bind stream id, head offset, manifest root, parent heads, checkpoint kind, and optional application block metadata. <!-- [SRS-05/AC-02] verify: root=$(git rev-parse --show-toplevel) && rg -n "stream_id|head_offset|manifest_root|parent_heads|checkpoint_kind|application_block" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-05:start, SRS-05:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] Documentation clearly states that Transit supplies lineage and finality primitives, not a complete blockchain consensus runtime. <!-- [SRS-NFR-03/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n "not a complete blockchain consensus runtime|does not provide|applications still own consensus" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VI1mjiIBI/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VI1mjiIBI/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VI1mjiIBI/EVIDENCE/ac-3.log)



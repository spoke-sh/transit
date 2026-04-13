# VOYAGE REPORT: Remote Authority Contract And Consumer Wiring

## Voyage Metadata
- **ID:** VGh5B5qMT
- **Epic:** VGh59soBt
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Document Hosted Authority Contract For External Workload Consumers
- **ID:** VGh5rrKTY
- **Status:** done

#### Summary
Author the canonical hosted-authority contract for Hub-like consumers so endpoint selection, access-token usage, and durability posture are explicit and local embedded authority is called out as the wrong model for hosted consumer-owned workloads.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] The authored contract explains how external workload consumers target transit-server for hosted append and replay, including endpoint, token, and durability posture expectations. <!-- verify: manual, SRS-01:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-01/AC-01] The contract keeps hosted authority framed as a thin remote protocol and server contract rather than a second storage engine embedded in the consumer. <!-- verify: manual, SRS-NFR-01:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5rrKTY/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5rrKTY/EVIDENCE/ac-2.log)

### Add Hosted Authority Proof For External Producers And Readers
- **ID:** VGh5sVPck
- **Status:** done

#### Summary
Add a repo-native hosted-authority proof that writes representative consumer-owned records through a running transit-server, replays the acknowledged history back, and proves the workflow does not rely on a local embedded authority store.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] A proof path appends representative consumer-owned records to transit-server and replays the acknowledged history back through the hosted contract only. <!-- verify: cargo test -p transit-client hosted_authority_ -- --nocapture && cargo run -q -p transit-cli -- mission hosted-authority-proof --root target/transit-mission/hosted-authority, SRS-02:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] The proof output keeps durability posture explicit and does not claim `tiered` safety before the hosted authority path actually publishes to the remote tier. <!-- verify: cargo test -p transit-client hosted_authority_ -- --nocapture && cargo run -q -p transit-cli -- mission hosted-authority-proof --root target/transit-mission/hosted-authority --json, SRS-NFR-02:start:end, proof: ac-2.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5sVPck/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5sVPck/EVIDENCE/ac-2.log)

### Expose Thin Client Acknowledgement Guidance For Hosted Authority
- **ID:** VGh5t7Eih
- **Status:** done

#### Summary
Document the acknowledgement, error, and durability-posture guidance that thin clients and operators need when hosted Transit becomes the authority for downstream consumer workloads.

#### Acceptance Criteria
- [x] [SRS-03/AC-02] Operator-facing guidance explains how hosted authority acknowledgements, errors, and durability posture should be interpreted without reinterpreting server semantics in the client. <!-- verify: manual, SRS-03:start:end, proof: ac-1.log-->
- [x] [SRS-04/AC-01] The authored docs state that local embedded Transit storage is not the authority for hosted consumer-owned workloads and describe the cutover boundary for Hub-like consumers. <!-- verify: manual, SRS-04:start:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] The guidance keeps hosted authority integration focused on remote contracts and operator posture rather than moving consumer-owned policy into Transit core. <!-- verify: manual, SRS-NFR-03:start:end, proof: ac-3.log-->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGh5t7Eih/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGh5t7Eih/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VGh5t7Eih/EVIDENCE/ac-3.log)



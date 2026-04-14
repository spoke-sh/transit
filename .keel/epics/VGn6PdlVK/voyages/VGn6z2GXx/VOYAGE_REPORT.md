# VOYAGE REPORT: Hosted Tiered Durability Proof

## Voyage Metadata
- **ID:** VGn6z2GXx
- **Epic:** VGn6PdlVK
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Keep Storage Probe Honest For Hosted Providers
- **ID:** VGn7fT2QB
- **Status:** done

#### Summary
Update the storage probe so it tells the truth for hosted providers and tiered
config. It should surface explicit guarantee and non-claim language instead of
pretending the old local-only probe contract still applies.

#### Acceptance Criteria
- [x] [SRS-02/AC-01] `transit storage probe` reports hosted-provider guarantee and non-claim language that matches the actual runtime posture. <!-- verify: manual, SRS-02:start:end -->
- [x] [SRS-NFR-01/AC-02] Probe output uses the same durability vocabulary as the hosted server and proof surfaces. <!-- verify: manual, SRS-NFR-01:start:end -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGn7fT2QB/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGn7fT2QB/EVIDENCE/ac-2.log)

### Prove Hosted Warm-Cache Recovery From Authoritative Remote Storage
- **ID:** VGn7gLxpC
- **Status:** done

#### Summary
Add the proof coverage for hosted restart and cache-loss recovery from the
authoritative remote tier so operators can verify that local cache is
replaceable and not the hidden source of truth.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Hosted proof coverage demonstrates warm-cache recovery from authoritative remote storage after local cache loss. <!-- verify: manual, SRS-03:start:end -->
- [x] [SRS-NFR-02/AC-02] The proof output makes it explicit that local cache was discarded and rebuilt from remote authority. <!-- verify: manual, SRS-NFR-02:start:end -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGn7gLxpC/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGn7gLxpC/EVIDENCE/ac-2.log)

### Keep Hosted Ack Durability Truthful
- **ID:** VGn9VkdSt
- **Status:** done

#### Summary
Make the hosted server and recovery paths tell the truth about durability. A
configured `tiered` posture cannot show up as an acknowledgement label unless
the runtime has actually reached the remote authority boundary required by that
claim.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Hosted append or recovery paths never label responses `tiered` unless the runtime has actually reached the authoritative remote tier required by that claim. <!-- verify: manual, SRS-01:start:end -->
- [x] [SRS-NFR-01/AC-02] The durability vocabulary used by hosted acknowledgements stays aligned with the proof and probe surfaces. <!-- verify: manual, SRS-NFR-01:start:end -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGn9VkdSt/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGn9VkdSt/EVIDENCE/ac-2.log)



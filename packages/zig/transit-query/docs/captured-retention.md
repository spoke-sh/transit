# Captured Table retention

`CapturedTablePin` owns one direct Table pin in a computation's native state
resource. The caller supplies an admitted job identity, source ordinal and the
original caller's `DirectReadDelegation`. The declaration's catalog resource is
independent of this job state resource. The configured worker principal must
match the grant's executor; process IDs are never substituted for principals.
`UnifiedCapture` uses these transitions for explicit admission, bounded direct
source traversal and verified result publication.

## Commit boundaries

1. Admit the job and freeze its request. Verify the grant's purpose against that
   request and its intended worker/resource before preparing retention.
2. `prepare` stages three metadata mutations: two grant fragments and a permanent
   pin-owner claim. Commit these with the admitted job's acquisition eligibility.
   A second job cannot reuse that pin owner. Preparation performs no remote work.
3. `acquire` reads only committed eligibility before calling the direct owner.
   It retains the original signed grant, selection and pin owner. `exact`
   selection requires the signed frontier; `current` selection permits the first
   acquisition to freeze the current root at or above the signed frontier in
   the same partition, under the exact interpretation. Both selections recover
   that same root after a lost reply; neither can reopen a released pin. It also
   obtains the data owner's exact native database/schema/Table authority
   references. Its handle and authority
   become a native metadata mutation together with the actual accepted frontier;
   publish that evidence with the job's source
   evidence before starting traversal. A lost reply or failed native commit is
   recovered by repeating this exact acquisition. A signed lower bound is not
   reported as a captured source position.
   Before publishing each subsequent native progress/result commit,
   `authorizeExecution` checks those references under the bundle's independently
   bound execution subject. The subject must retain the original caller, role
   and credential epoch; its audience belongs to the query worker. This supplies
   the native commit fence even when the preceding direct read has already
   returned rows. Current result disclosure remains a separate authorization.
   The direct catalog requires these authority domains to bind its native
   resource lifetime. The native guard therefore checks that source prerequisite
   independently of the computation's state resource and without raw source
   access. Native preparation uses its recorded time sample; a changed policy or
   resource state invalidates the prepared commit through the existing fence.
4. Commit `beginClose` with or after the job's transition away from reading its input.
   Unified Table traversal commits its final segment and checkpoint first, then
   records closure eligibility in a separate turn to preserve the four-mutation
   limit. A captured job never resumes source traversal during this interval.
   This one metadata mutation also handles an acquisition with an unknown reply.
   A worker restart alone cannot make this transition.
5. `settle` reads the committed closing decision and reconciles the remote pin
   through `DirectTableClient.closeOriginalPin`. Success stages a closed record;
   commit it before claiming cleanup is complete. Lost replies and lost native
   commits repeat the original closure. Current denial or unavailable storage
   leaves the closing record pending.

Credential rotation does not replace an accepted query's execution proof.
`UnifiedClient.prepareCleanup` instead signs a separate `DirectReadDelegation.Closure`
over the exact original grant. The authenticated requester forwards it only for
a terminal job. `authorizeCleanup` verifies current permission through a pure
pin-status read and commits the compact closure proof separately. A later turn
uses that proof to reconcile the original acquisition and release. This permits
no schema or row reads; it cannot resume the query or capture a different cut.
Save the prepared command for uncertain retries. A later rotation requires
another explicit cleanup authorization, while unavailable storage or denied
current access leaves closure pending.

An invalid fresh cleanup proof records a rejected control without replacing the
saved execution grant or blocking later controls. A job denied before committed
acquisition eligibility has no pin to settle. Terminal cleanup preserves that
absence and its original failure; it does not create an acquisition record.

Native admission and direct pin acquisition are independent commits. There is
no cross-owner atomicity claim: the first establishes recovery ownership before
the second can retain data. A stale worker may repeat the same direct operation,
but it cannot replace the grant or reopen a terminal pin. Native fencing still
governs its proposed job-state changes. The requester may disappear without
removing the grant needed for cleanup; these records live with the computation.

## Bounds and inspection

Retained Table traversal preserves the original schema through ALTER, DROP and
name reuse. A predicate containing exactly one equality for each primary-key
column can use a direct `read_key` lookup with that schema's collation keys.
Fuze still evaluates the original predicate. Other predicates scan in bounded
row-identity pages. A key lookup completes only that selection, leaves the
sequential reader cursor unchanged, and rechecks current rights before returning
either a row or an empty result.

Each source has two fixed grant fragments, one optional handle record, one
optional 72-byte cleanup proof and one permanent owner claim. The source ordinal is a durable key, not an in-memory
array index. The owner claim stores the complete identity alongside a hashed
lookup key; a collision rejects instead of sharing a pin. Preparation uses
three of the four native metadata mutations, acquisition at most one, and each
closing transition one. No rows or result bytes pass through these records.

`inspect` reads committed state and performs no acquisition or release.
`acquiring` can include a remotely accepted pin whose handle publication is
uncertain; it is not evidence that no pin exists. `closing` permits cleanup and
`closed` records its observed remote settlement. Grant and handle records remain
available for exact inspection/retry; this component performs no physical
collection and imposes no expiry. Calling code must retain these records until
its explicit retention policy permits cleanup.

The original grant uses the mandatory current-definition `TRG1` encoding.
`QTP1` stores phase, resource, worker, job and source ordinal with that grant;
`QTH1` stores a mandatory current definition, the original pin content
length/digest, three native authority IDs, declaration length, schema fingerprint,
logical-change frontier and row count. Reads reject partial fragments,
identity changes and incompatible
definitions. Loading a record carries no permission: remote actions authenticate
the worker's own key and recheck the original caller's current authority.

# Captured Table retention

`CapturedTablePin` owns one direct Table pin in a computation's native state
resource. The caller supplies an admitted job identity, source ordinal and the
original caller's `DirectReadDelegation`. The declaration's catalog resource is
independent of this job state resource. The configured worker principal must
match the grant's executor; process IDs are never substituted for principals.
This component supplies retention transitions. The captured-query behavior still
needs admission, source traversal and result publication integration.

## Commit boundaries

1. Admit the job and freeze its request. Verify the grant's purpose against that
   request and its intended worker/resource before preparing retention.
2. `prepare` stages three metadata mutations: two grant fragments and a permanent
   pin-owner claim. Commit these with the admitted job's acquisition eligibility.
   A second job cannot reuse that pin owner. Preparation performs no remote work.
3. `acquire` reads only committed eligibility before calling the direct owner.
   It retains the original signed grant, exact frontier and pin owner. It also
   obtains the data owner's exact native database/schema/Table authority
   references. Its handle and authority
   become a native metadata mutation; publish that handle with the job's source
   evidence before starting traversal. A lost reply or failed native commit is
   recovered by repeating this exact acquisition.
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
4. Commit `beginClose` with the job's transition away from reading its input.
   This one metadata mutation also handles an acquisition with an unknown reply.
   A worker restart alone cannot make this transition.
5. `settle` reads the committed closing decision and reconciles the remote pin
   through `DirectTableClient.closeOriginalPin`. Success stages a closed record;
   commit it before claiming cleanup is complete. Lost replies and lost native
   commits repeat the original closure. Current denial or unavailable storage
   leaves the closing record pending.

Native admission and direct pin acquisition are independent commits. There is
no cross-owner atomicity claim: the first establishes recovery ownership before
the second can retain data. A stale worker may repeat the same direct operation,
but it cannot replace the grant or reopen a terminal pin. Native fencing still
governs its proposed job-state changes. The requester may disappear without
removing the grant needed for cleanup; these records live with the computation.

## Bounds and inspection

Each source has two fixed grant fragments, one optional handle record and one
permanent owner claim. The source ordinal is a durable key, not an in-memory
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
length/digest and the three native authority IDs. Reads reject partial fragments,
identity changes and incompatible
definitions. Loading a record carries no permission: remote actions authenticate
the worker's own key and recheck the original caller's current authority.

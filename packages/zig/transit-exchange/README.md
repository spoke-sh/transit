# transit-exchange

Shared Zig capture over Station's growing immutable publication. HTTP consumes
this package; it has no sockets, credentials, HTTP parser or remote retry loop.
[M15](../../../docs/roadmap/M15.md) is in progress. The initial unit checks do not
qualify the complete connector, deployment, SDK or disk-recovery obligations.

Each `Exchange` owns one publication namespace in a writer-owned resource.
`create` fixes caller/input/parent lineage, protocol, finite capture budgets and
the original reconciliation deadline. Stage chunks with `beginSegment`/`append`,
then `sealSegment`: exactly four mutation slots atomically publish bytes, member
identity and the new coverage commitment. Empty segments are explicit.

`commitIntent` freezes request coverage with a kernel effect in one turn. The
resulting ready state prevents duplicate effect creation. `bind` checks the
authorized effect's identity, exact request coverage and deadline before response
capture. Neither method performs or authorizes socket I/O itself. `finish` seals
protocol completion; `closeUnknown` preserves uncertainty and partial evidence.
Kernel observation/closure is a separate authority decision. `settle` records
that terminal decision against the preserved frozen intent; incomplete or
possibly-in-flight effects cannot be retired by claiming capture is terminal.

Roots default to one attempt. `configureAttempts` fixes a finite total budget
before intent publication; `followup` atomically allocates a linked child under
the original caller/input/deadline and records a versioned adapter-policy
decision. Retries, redirects, reconciliation and cancellation all consume this
budget. The adapter must prove remote safety and scope first; the common API
does not choose or dispatch a retry.

`followupWithContext` additionally freezes at most 214 adapter-owned bytes in
the lineage record, preserving the four-mutation allocation. `lineage` reads
that context with the original root/parent/policy. Context has no authority and
cannot be changed on duplicate allocation. Empty context retains EXL1; nonempty
context uses the additive EXL2 layout. HTTP's planned public followups use it for reply routing;
public followup service qualification remains M15 work.

`open`/`read` stream complete coverage with digest checks. Supply fresh current
authority separately from the retained source on every bounded read. Cursors
are trusted native continuation state. They cannot be exposed as bearer tokens.
`inspect`/`member` expose partial metadata without claiming replay completeness.

`Client` supplies the public read adapter. It obtains a fresh authorized resource
cut for every call and verifies the immutable complete group/member commitments
before resuming a chunk cursor across otherwise unrelated resource changes.
This does not expose owner-only retained execution versions or grant execution
rights to a reader. Partial bytes remain provisional until coverage verifies.

`commitIntent` automatically holds caller replay. Release it explicitly with
`releaseCaller` after terminal settlement and acknowledgement or authorized
disposal. `retain`/`release` track additional consumers using permanent token/holder
identities, two mutations per operation and a durable count. Authenticate holders
and validate resource lifetimes in the admitting handler. These records confer no
read rights and never expire implicitly. Released tokens cannot be reacquired.

Retirement enforces settlement and the absence of caller/consumer holds.
It closes current availability before `collect` visits member publications with
at most two chunk deletions per call. Permanent descriptors prevent ID reuse.
Historical roots remain protected until explicitly released. Resource quotas,
current grants and immutable namespace allocation remain mandatory; there is no
automatic expiry, dependency discovery or whole-history resident array.

See the [versioned contract](../../../contracts/STATION_EXCHANGE_V1.md). Run
`nix develop --command bash -c 'cd packages/zig/transit-exchange && zig build test'`
for publication composition, coverage, duplicate/conflict, quota/rollback,
retirement and cleanup checks.

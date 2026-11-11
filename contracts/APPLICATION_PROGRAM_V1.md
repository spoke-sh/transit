# Ordered application programs v1

This contract defines the ordered Queue program profile coordinated by
[DATAFLOW_V1](DATAFLOW_V1.md), [MIGRATION_V1](MIGRATION_V1.md) and
[BROWSER_V1](BROWSER_V1.md). It introduces no independent catalog, permission
authority, transaction log or effect ledger.

**Implementation status:** bounded source framing, instruction parsing, retained
instruction encoding and local schema binding are implemented in Fuze's
`ApplicationProgram`, together with its host-driven expression evaluator,
scoped continuation codec and typed instruction operands.
`transit-query-direct.ApplicationData` supplies native data conversion and
read/mutation preparation for these operands.
Native resource binding and typed publication/control are implemented in
`ApplicationBinding`, `ApplicationDeclaration` and `ManagedApplication`.
`ApplicationInvocation` attaches original work, acquires Queue input and retains
its initial protected environment. `ApplicationExecution` composes data
instructions, exact input ACK, guarded checkpoints and bounded failure
continuations through native serializable transactions. The signed component
proof covers mixed Table/KV/Stream commit/abort, original lost replies, native
process replacement and cancellation cleanup; it does
not qualify the complete browser application. `ApplicationRecovery` reopens
original invocations for the database service's bounded discovery sweeps.
An explicitly composed physical HTTP effect worker is implemented in
`transit-serving-http.ApplicationEffectRuntime`. Native cohosted SQL composes
publication, explicit role controls, publisher inspection and the database
service's default public-data host. Deployed effect-host composition, ingress,
response operations and migration binding remain integration work tracked by
[#430](https://github.com/spoke-sh/transit/issues/430). The installed SQL profile
is narrower than the typed instruction/runtime contract below.

## Installed SQL profile

`ManagedSql` delegates complete Queue bodies to `ApplicationProgram`.
`ApplicationSql` resolves exactly the referenced native definitions through
signed metadata calls and binds them with `ApplicationDeclaration`; preparation
performs no acquisition, publication or effects. Unsupported host requirements
and input Queues with more than one partition reject before admission.
`ManagedOperations` retains the typed declaration or exact saved control request
in its existing `DFS1` SQL operation envelope, using additive `publish_program`
and `control_program` action variants. Existing finite actions retain their
encoding and meaning. Recovery does not reparse SQL or choose another role.

CREATE publishes an inactive definition. AUTHORIZE requires `AS ROLE` with a
named role, `CURRENT_ROLE`/`CURRENT_USER` or `SESSION_USER`, resolved through the
current native authorization owner. ACTIVATE, SUSPEND, RESUME and RETIRE use the
saved definition and expected control. REFRESH is refused. Native name acceptance
selects the control object; a token-account lookup cannot override that choice.
A rejected control-object publication retains its original refusal and stops
publication retries. Successful publication remains permanently retained.

SHOW uses the original publisher connection, current resource metadata checks
and control KV reads. Buffered and terminal disclosure repeat those checks.
It returns the frozen declaration and observed head, including executor role,
pending invocation, checkpoint reference and completion/refusal counters.
These counters describe recorded invocations, not Queue emptiness or worker
idleness. An active program can retain a pending acquisition while its Queue is
empty; cancelling that acquisition through SUSPEND or RETIRE records a refusal
even though it consumed no input.
It does not resolve checkpoint payloads into historical results or enable
independent-reader inspection. EXPLAIN binds definitions and returns dependency
uses and limits without allocating a durable identity or running a program.

SQL freezes per-invocation limits of 10,000 requests, 10,000 scanned rows,
1 MiB each for result/continuation encodings and 16 MiB retained bytes, plus
`DirectTransaction.default_limits`. Existing source, node, dependency and native
saved-record limits apply together. The installed host rejects effects,
protected values/responses, response pages, handoffs and deadlines. Explicit
transactions, database-wire/remote gateway admission, Queue program migrations
and definition replacement are unsupported. The source compiler's existing
Table profile is unchanged; this interface consumes executable lowered SQL.

## Definition and compilation

LET bindings are lexical. In a SELECT predicate, an existing program binding
takes precedence over a bare column name; column lookup occurs only when that
name is absent from the lexical environment. Use distinct local names when a
predicate must address the current row's column.

A definition has a scoped catalog identity, immutable source digest, exact
resource definitions, publication connection, input Queue and acquisition
predicate, budgets and native contract definition. Node identities belong to
that frozen definition. A later declaration cannot reinterpret an accepted
invocation or its continuation.

The typed declaration reconstructs each resource's native definition from its
schema and immutable properties. Data positions, row counts and transient read
views do not enter its identity. It binds exactly the used resources, with a
maximum of 13 per program so their values and the control object fit the existing
native authorization budget. Queue acquisition/settlement and append are distinct
required actions. Row Document policy and native browser bindings remain part of
the resource definition. This binder currently admits native Table, row Document,
typed KV, Stream and Queue definitions, including typed capability handles in
Queue records. Sink and protected-host integration remains required for the
complete browser application.

The input predicate lowers from the retained instruction tree into the native
`QueuePredicate`, bound to the exact schema and selected partition. The current
acquisition profile accepts literal comparisons, Boolean combinations, Boolean
columns and null tests, with the column's declared comparison semantics. Host
functions and lease metadata are excluded. Unsupported predicates reject before
publication. Preparing a claim selects at most one input under its frozen
operation identity and declared lease policy; it performs no acquisition.

`ManagedApplication.publish` retains the canonical declaration through the owned
original-record protocol before initializing its named KV control and dependency
edges. Repeating publication uses the same original identity and does not reset
the lifecycle. An application dependency permits shared transactional writers;
finite Table recomputation retains its writer-exclusion rule. The native
`check_set` dependency check verifies registered edges, exact live definitions
and current action privileges without admitting work. The control KV has a
registered read/write dependency too; an executor cannot become ready with only
metadata access to its checkpoint. Metadata inspection alone
does not establish readiness, and successful checks confer no future authority.

Publication does not select an executor role. Authorization explicitly selects a
nonzero role in the control head without changing the immutable definition;
activation and resume recheck its rights through native policy. Each original
invocation retains that selected role. Its input, transaction and effect keys use
the retained role, and current execution checks it against the authorized head.
Recovery and cleanup never substitute another role or infer a missing role from
current control. The permanent original token fingerprint commits the definition,
declaration reference, selected role, computation lease and input claim. Loading,
advancing or executing progress checks that commitment, including after the
original payload closes. Missing or changed persisted origin evidence is rejected.
Saved control mutations preserve original operation identity and fence the control
row's observed position. Suspend and retire first cancel the exact pending work
token saved in the control request. Native data calls combine its progress fence
with the service generation fence, so replacing either record excludes delayed
calls before native admission. A failed control-row CAS may leave that original
invocation cancelled; retrying the saved control never cancels a newer invocation.
Service discovery schedules these typed declarations;
publication and activation alone do not prove an invocation has completed.

Input acquisition attaches an immutable work record before its original claim.
A bounded nonempty wait preserves that claim identity on timeout. The claim
receipt is retained before reading its original selection. An initial environment
is stored with the original enqueue operation, row ordinal and exact Queue
partition in an immutable owned record guarded by current input and control KV
read rights, then referenced from the work's recovery metadata. Recovery can use
that retained input if the reply was lost before the reference advanced. Safe
work metadata contains identities, receipts and references, without payloads.
Acquiring or retaining input does not ACK it, execute instructions or complete an
invocation. The low-level caller selects the partition; automatic service
scheduling currently requires a single-partition input Queue. Response settlement
remains required integration work.

The compiler accepts one `CREATE DATAFLOW name FROM QUEUE name AS input`
declaration. A block contains immutable `LET` bindings, TRUE-only `REQUIRE`,
`IF ... THEN ... ELSE ... END IF`, `BEGIN ATOMIC`, conditional KV writes,
Table insertion with exact row assertion, Stream/Queue append, response handoff
and response operations. A sink invocation requires an explicit effect identity,
guard and `ON REPLAY OBSERVE ONLY`. The paged form selects a declared projection
and names its native response profile. These forms are distinct from finite
Table recomputation.

Source is bounded at 64 KiB, syntax nodes at 4,096, parser/binder nesting at 32,
argument lists at 64 and response cookies at eight. Lexical source framing has
its own 64-level bound. A complete compound declaration is one migration step;
its internal nodes are not separate migrations. All statements and dependencies
must bind before any migration step is admitted. Compilation performs no network
dispatch, activation or mutation.

`ApplicationProgram.Codec` retains the instruction tree and source digest under
the mandatory current native contract definition. Recovery decodes those exact
instructions without parsing SQL. The encoding is bounded to 1 MiB; its JSON
syntax depth is checked before recursive decoding, and node identities must be
unique and cover the declared count. Structural validation rejects cycles,
aliases, effects inside atomic blocks, mutations outside them, duplicate fields
and malformed response cookies. Resource and protected-value binding still uses
the definition's frozen schema inputs; decoding alone establishes neither
catalog authority nor permission to execute. The exact consumer-source oracle
checks all six instruction trees and their type bindings after reload.

Bindings are lexical and immutable. Duplicate names in a live scope are rejected.
Branch and atomic-block locals do not escape their block. A failure continuation
receives the original input and a typed failure; it cannot depend on a partially
executed body's locals. Ordinary row fields and `_revision` remain distinct.
Missing point reads and zero-row single-record SELECT return a nullable record;
more than one SELECT row is a cardinality failure. Field access on a missing
record produces NULL. Conditions follow SQL three-valued Boolean semantics;
only TRUE satisfies `REQUIRE` or selects an IF branch. A required target field
rejects NULL at the authoritative write boundary.

`ApplicationProgram.Cursor` advances explicit branch and atomic-block frames.
`Environment` retains only live lexical bindings and validates their instruction
identities, types and scope against the frozen definition when restored. Its
canonical encoding includes the mandatory native definition and an exact
binding digest, with a 1 MiB ceiling. Binary values and secret revision identifiers
use lowercase hex strings, independent of whether those bytes form valid UTF-8.
Decoding owns its bytes. Prepared operands
borrow the input, definition or caller's reusable turn arena. The host must
retain the successor before resetting that arena. A continuation is not an
authorization ticket or evidence of a committed transaction.

`ApplicationProgram.Step` evaluates one instruction into typed operands. Reads,
mutations, effects, response operations and common transaction entry/commit are
explicit host actions. A LET cannot advance without a type-checked result; a
stale local completion cannot advance a newer cursor. `Step.propose` creates an
independent proposed successor for retention before native admission; it does
not mark the active instruction complete. Failure entry discards body locals
and preserves monotonically increasing instruction identities. The native owner
must verify the original block's abort before entering failure from an atomic
scope. Failure inside `ON FAILURE` terminates that handler without recursively
entering it again. These local checks do not replace durable fencing,
transaction recovery or dispatch authorization.

## Protected values

Secret bytes, protected JSON and response/request capabilities have separate
types. They cannot become ordinary persisted values through casts, concatenation,
JSON construction, logging, captures, queries or export. Compiler checks are
repeated by native operations at the actual persistence/disclosure boundary.
Public receipts contain typed status, commitments and original identities.

The local evaluator represents secrets and protected JSON with opaque references.
Protected scalar projections use a reference plus their logical kind. Native
helper results are checked against the bound type; a helper cannot return a
plain string where a protected value is required. Short-circuit and conditional
evaluation preserve that classification. Only the native host redeems references;
the reference itself confers no authority. The expression evaluator performs no
durable acceptance or continuation recovery.

A Queue capability field stores a non-authorizing handle. Its native binding
includes purpose, scope, original request, current owner and expiry. Possessing
the stored handle alone grants no redemption rights. Protected bytes remain in a
bounded native transient reservation; completion, expiry or loss destroys them.
Losing bytes cannot authorize another effect, another random value or a fresh
write under a new identity.

Approved operations are explicit: secret lookup/current-revision checks,
domain-separated derivation, commitments, S256, constant-time equality,
purpose-bound HTTP fields, sink operands and secure host cookies. Ordinary HTTP
query access admits public `state` and `error` fields; credential and cookie
access requires a protected operation. `JSON_VALUE` of protected JSON remains
protected. `SECRET_JSON_VALUE` returns a secret. The admitted numeric subject
projection is `JSON_INTEGER(..., '$.id')`, with exact integer conversion; it
does not release strings, containers, headers or the response body. Native
provider identity checks still bind issuer, client and subject.

`SECRET` and `SECRET_CURRENT` require the executable declaration to retain the
canonical `transit.secret_references` KV binding. This implicit dependency is
merged with explicit resource uses, requires READ and `use_secret`, and joins
the common serializable transaction. Missing, duplicate and ordinary lookalike
owners are rejected before publication. The native metadata contains only a
logical name, single-component file label, exact SHA-256 content commitment and
enabled flag. Secret revisions retain the mandatory native definition, immutable
binding and original KV row identity; rotation, disable and privilege revocation
remain visible at the common commit decision. The component does not yet connect
the existing browser secret administration and live gateway to this owner.

Time and randomness enter through native observations. Public observations and
their step identities are retained where continuation requires them. Secret
random material remains transient. Replay cannot generate a replacement secret
to disguise the loss of an original outcome.
Program timestamps use SQL's UTC microseconds since epoch; durations use signed
microseconds. Seconds conversion and timestamp arithmetic must reject overflow.

`WITH (DEADLINE = '5s')` accepts a positive integer followed by `ms`, `s`, `m`,
`h` or `d` (case-insensitive). Parsing and decoded-plan validation reject zero,
fractional, unknown-unit and overflowing durations. The shared
`ApplicationDeadline` component derives the absolute cutoff from the original
accepted claim's `observed_ms`; another effect, input ACK or worker replacement
cannot choose a new origin. It uses Queue `current_time`'s upper bound and
charges the entire native read duration when projecting onto local monotonic
time. Rechecks only shorten the budget; the sink timeout and transient request
expiry may shorten it further. Missing/regressing clocks or expiry refuse work.
This component does not itself activate HTTP execution or authorize dispatch;
the enclosing worker must bound and join its I/O and repeat current guards.
Both the default application host and the explicit HTTP host reject programs
declaring a deadline. The physical HTTP worker bounds each exchange by its sink
timeout and transient request expiry; the whole-program path across native
preflight and successive atomic blocks remains unqualified. Generic native
transaction deadlines do not establish that integration.

`NOW()` currently observes the host wall clock and retains its original candidate.
It is not the native Queue clock interval or a trusted policy-time observation.

The native public helper owner implements host time, secure random public tokens,
checked seconds conversion, Unicode code-point length, SHA-256 digests and
unpadded base64url S256. `RANDOM_TOKEN(n)` encodes `n` random bytes, with
`16 <= n <= 64`. `IDENTITY_DIGEST` uses the browser identity owner's
domain-separated, length-prefixed issuer/client/subject digest and renders it as
lowercase hex. `OPERATION_ID` hashes the domain
`transit.application.operation-id.v1\0`, the 16 input UUID bytes, an unsigned
eight-byte big-endian label length and the UTF-8 label. Its first 16 digest bytes
carry UUID version 8 and the RFC variant. Host observations remain proposals
until their original candidate is retained; recovery never replaces a retained
observation. Protected helpers require their separate native redemption owner.

Public JSON helpers use the shared lossless, duplicate-rejecting parser and a
64 KiB result/input budget, with bounded depth, fields and tokens. Paths contain
one to sixteen dot-separated ASCII identifiers after `$.`; array subscripts and
wildcards are outside this profile. Missing fields and JSON null return NULL.
`JSON_VALUE` returns scalar text, preserving number lexemes; containers refuse.
`JSON_INTEGER` accepts decimal integer tokens within signed 64-bit range and
never passes through floating point. Fractional, exponent and quoted-number
representations refuse. The protected-body projection restriction above remains
independent of these conversion rules.

`JSON_OBJECT` accepts unique text keys and public NULL, Boolean, integer, text or
JSON values. It validates the complete composed value, including nested JSON;
other implicit coercions refuse. `URL` accepts an HTTPS base without credentials,
query, fragment or controls and a JSON object of scalar query parameters. It
percent-encodes each UTF-8 key/value independently, omits NULL members and rejects
containers. Construction grants no permission to dispatch or deliver a redirect.
`SECURE_EQUAL` compares equal-length byte/text values without a matching-prefix
exit; unequal lengths and NULL operands return false.

`CURRENT_REVISION(document, key)` reads the exact bound versioned row Document
through its single-column primary key. Missing keys return NULL; wrong key types
and multi-column keys refuse. Inside an atomic block it uses the existing
serializable workspace and its retained source guard. Both this helper and
SELECT's `_revision` return the same 32-byte state fingerprint. The native
decision rechecks the full retained guard. Outside a block the helper
uses a current point read bound to the observed definition and data frontier;
a changed frontier refuses instead of silently choosing another observation.
The fingerprint binds the native definition, Document policy, exact resource
interpretation, storage partition and logical change LSN. Snapshot pinning and
maintenance may advance acceptance without changing this identity. It identifies
collection state, not a per-key counter, snapshot pin or authorization grant.

Each expression host is bound after the execution owner opens the current native
transaction view. The binding carries the original input record, invocation,
step, frozen declaration and fenced client. These values borrow the current
evaluation and are invalid after it returns. A host must not reuse a prior
client fence or substitute a checkpoint's payload for original input provenance.
The binding's `requireCurrent` operation checks the original invocation fence,
active head/pending key and all registered dependency privileges through the
original authorized executor role. Control observations use current committed state while
data helpers retain the original private transaction cut. A mandatory release
callback runs once after every successful bind, including evaluation or
retention failure. Failed binds clean up their own partial borrows. These checks
do not establish honest host computation or a reusable dispatch permit.

## Service discovery

### Protected handle representation

`CAPABILITY` is a distinct logical descriptor for a nonzero, opaque 32-byte
handle. Its native value atom is distinct from binary/string atoms; the bound
value encoding stores exactly those 32 bytes after its ordinary cell-state tag.
The handle contains no credential bytes, expiry claim or grant. The protected
host must independently validate its recorded owner, purpose, original request,
current authorization and live transient reservation before redemption.

Handles have no SQL literal, cast, equality/order/hash trait, map-key use, ordinary
display, JSON projection or Arrow export. Native Queue payload transport and
ordered-program continuation may preserve the opaque identity, including a
transactional handoff, without redeeming it. Expiry or loss of the transient
reservation cannot be repaired by regenerating a credential or dispatching a
replacement effect. This representation is being integrated with the protected
HTTP owner; recognizing the type alone does not activate that owner.

The local HTTP `ApplicationReservation` component binds one active request to
its exact Queue partition, original enqueue operation and row ordinal. Its
caller supplies fixed memory and slot budgets, serializes accesses and joins
borrowers before destroying it. A mandatory native verifier checks the original
invocation/acquisition and current rights on every access, including cached
observations; redemption additionally identifies its intended use. Only random
or derived secrets can be delivered as cookies. Secret and protected JSON bytes
remain inside the reservation, with separate typed handles and original
observation identities. Reusing an observation with different arguments or
material rejects rather than replacing the original value.

`ApplicationProtectedHost` composes these reservations with public observations
and native secret-resolution callbacks. Public output, retained material and
per-call private scratch have separate ownership; private scratch is erased on
success, rejection and exhaustion. Random secrets contain the unpadded base64url
encoding of 16–64 secure random bytes and reuse their original reservation.
Derivation uses HMAC-SHA256 over `transit.application.derive-secret.v1` plus a NUL,
then the public state and label, each prefixed by its little-endian u64 byte
length. Its 32-byte result is encoded as unpadded base64url. Commitments and S256
hash these exact encoded bytes, matching cookie extraction. Bearer construction
admits nonempty token68 bytes and keeps the resulting header protected.
Native secret revision authority is retained separately from the transformed
value's purpose. Derivation and Bearer formatting preserve it; random, request
and provider material retain transient observation identities. Redemption
evidence obtains this distinction from the reservation, never from a caller's
handle. A derived transient value cannot acquire native secret-current semantics.

`ApplicationSecrets` implements scoped lookup/current callbacks over
`DirectSecret` and an open trusted private mount. It accepts nonempty regular
files up to 64 KiB, detects short/growing reads, checks the exact content
commitment and erases a failed private read. Current checks reject foreign
bindings and use the current transaction client. Wiring these components into
the live request registry and executor remains separate work.

`ApplicationAuthority` implements the reservation's access and redemption
checks over the shared execution context. It rejects copied input/owner
identities and requires a native secret's exact declared binding and current
client fence/transaction. Handoff evidence currently remains unqualified and
is rejected; local access checks cannot establish a committed ownership move.

Protected scalar operators reuse the public evaluator's arithmetic, comparison
and NULL rules inside the private host and seal the result again. Request fields
retain duplicate rejection and exact original-record ownership. A cached secret
still requires current redemption authority. `SECRET_CURRENT` uses a distinct
inspection purpose so a rotated declaration can return false; its native
callback must retain the policy read in an active common transaction. These
helper tests do not establish that callback's live integration or HTTP dispatch.

This local component admits one explicit ownership handoff, bound to the source
invocation, original common transaction, effect identity and exact destination
enqueue record. The verifier must observe the matching committed enqueue,
handoff, input ACK and checkpoint before transfer. Pending or aborted work
cannot transfer ownership. Repeating the same observation cannot reset a
destination already acquired by its original invocation. Expiry, close or loss
erases bytes and forbids recreating values in that reservation. Capacity failure
erases partial copies and preserves accepted values. These local checks do not
establish the native verification callback, ingress readiness or HTTP execution;
those integrations and their live recovery proofs remain required.

### Bounded invocation scheduling

The database runtime enumerates application declarations and originals through
bounded Catalog pages under its existing account activation fence. It retains
only cursors, scheduling stripes and reusable scratch in memory. It also visits
terminal invocation records whose original closure may be unfinished. A
superseded service generation cannot advance the invocation, including cleanup.
The native original owner resolves attachment conflicts; transport uncertainty
or denial cannot close an attachment as though its CAS had failed.

Before creating or acquiring an invocation, the service checks the configured
host against requirements derived from the complete typed program, including
unreachable branches, failure continuations and protected input fields. Physical
placement may refuse readiness but cannot grant native rights. An unavailable
host parks the original without replacing its identity; native transaction
settlement and cancelled cleanup remain available. The default public host
rejects protected input, effects, responses/handoff, paging and deadline profiles.

The initial automatic profile requires a single-partition input Queue. A larger
Queue produces an explicit partitioning refusal; the service does not consume
only its first partition. Typed invocation callers retain their explicit
partition selection. An empty acquisition keeps the same original token and
claim. A bounded account retry timer rechecks pending acquisitions, including
delayed visibility and lease expiry; publication notifications interrupt it.
There is no new durable attempt per empty poll. Native Queue waits retain their
own readiness notifications and do not themselves wake application discovery.
Suspension/retirement cancels the pending original, and retirement removes
dependencies only after original input cleanup detaches it.

## Atomic decisions and continuation

The implemented typed execution owner retains proposed successors as guarded
owned records and publishes checkpoints as transaction-owned records. Native
statement completion is provisional until its common decision commits. Original
input, proposals and checkpoints count against the declaration's retained-byte
budget; each payload also has a separate continuation limit. Read request budgets
apply per SELECT, while native transaction limits bound participant expansion,
statement count and work. Transport retries do not receive new operation IDs.

The first committed boundary ACKs the exact original input lease. Subsequent
boundaries retain continuation progress without repeating that ACK. Final counts
commit with the terminal checkpoint, but the control head keeps the invocation
attached until input-read cleanup completes. Suspension during acquisition closes
the original claim and releases an accepted read without settling the message.
Cancellation arriving after a common committed decision preserves that decision,
including when the invocation has not yet observed its completion.

An atomic block uses the common direct transaction owner. It freezes exact
Table/KV/Document read guards and composes state writes, Stream/Queue outputs,
input progress/ACK, continuation and any response handoff in one decision.
Document policy guards must participate in validation of that decision; an
earlier policy read is insufficient. Exact revision expectations reject a stale
KV write even when its key is still present. Nested atomic blocks and external
effects within a transaction are rejected.

For callback admission, challenge claim, exchange enqueue, receipt, source ACK
and response handoff are one decision. A duplicate callback cannot enqueue
another exchange. For an earlier block with remaining work, the committed
continuation owns that work before the input is settled. The service discovers
continuations in bounded durable pages, independently of resident collection
size. A lease or newer worker epoch does not create new execution authority.

Before executing a failure continuation, resolve any pending transaction under
its original identity. Transport loss is not rollback. A handler cannot change
a committed success to refusal or issue replacement writes for an unresolved
decision. Pre-admission refusal, known effect refusal, unknown remote outcome,
lost protected input and unresolved commit remain distinct inspectable outcomes.
An absent user-written failure handler still has a native terminal refusal path.
Transient request loss and expiry enter failure handling after any original
transaction is resolved, retaining `ApplicationReservationLost` or
`ApplicationReservationExpired`. They do not establish durable input loss or
cancel its public failure continuation. A lost response socket cannot undo a
committed failure receipt; delivery remains separately observable.

## Effects, responses and activation

Each effect step has one original identity and recorded intent. Only a newly
accepted dispatch decision may send it. Replay observes its retained outcome;
unknown remote outcome grants no retry permission. The dispatch boundary checks
current program/sink state, role, secret revisions, policy guards and deadline.
Token and profile exchanges share the remaining invocation deadline.

The implemented `ApplicationEffect` bookkeeping component binds the dispatch
nonce in a permanent native owned-record receipt. Its key belongs to the
invocation step; the descriptor commits to the original input, frozen request,
program, sink and application effect UUID. Changed operands cannot select a new
original for that step. Only one successful live admission returns a fresh
attempt, after verifying retention of the exact guarded request. A lost
admission reply returns no permission to send; later calls
observe the original. This is a trusted host boundary, not evidence that the
native catalog performed or verified an HTTP computation.

Its retained outcome distinguishes `not_dispatched`, `unknown` and `response`.
A complete response retains status, byte count and content digest, with an
optional transient protected-body handle. Missing protected bytes do not turn a
known response into an unsent effect. Cancellation cannot erase a known outcome.
Recovery after replacement of a worker fence records unknown without another
dispatch. An unfinished native completion publication resumes the exact saved
outcome; absent publication bytes remain unresolved. Native closure can prove
that admission did not escape only while the original is unretained; the host
must first withdraw and join its live task.

The ordered runner freezes the pre-effect environment, typed request operands and
immutable instruction identity in a guarded candidate before task admission.
Recovering it never reevaluates random or protected operands. Task metadata binds
that candidate, the declaration and exact service/invocation fences. A waiting
task does not advance the invocation revision. After native effect settlement,
a separate guarded result candidate advances the environment once; adopting a
protected body requires the host to verify its original response observation.

Guard evaluation now collects exact public logical read bases, program controls,
registered dependencies and the native policy revision in a bounded read set.
Missing Document/secret rows retain evidence too. Native `check_set` validates
their coexistence under publication exclusion and current rights; a logical
change or different policy revision rejects. Acceptance-only advances are safe.
Once verified, cached operand redemptions may repeat recorded reads but cannot
add another source. The existing 16-check native limit applies, including control
and dependency entries. This evidence is ephemeral and cannot be reconstructed
from a later lookup or a private workspace; it does not itself dispatch HTTP.

The host retains a completed attempt until native settlement is observed, even
after joining it or losing a completion reply. Cancellation withdraws and joins
the original task before protected reads or native cleanup. Revocation can leave
settlement unresolved but cannot justify keeping a withdrawn local task alive.
Failure continuations retain the actual native effect outcome. The explicit
physical worker checks sink-selected dispatch authority, protected operands and
coherent read sets after TLS and before the first request write. Its task-local
clients and memory remain owned until joined cleanup. The default host continues
to refuse effect programs without this explicit composition. Deployed service
integration and whole-program deadlines remain unfinished.

A request has one response owner. Handoff transfers that owner with its commit.
Responses inside atomic blocks remain buffered until the decision commits.
Delivery checks current authority and guards immediately before disclosure.
Socket loss or expiry neither undoes committed state nor permits another effect
or session. An expired capability may prevent delivery while the original
durable outcome remains inspectable.

Publication, authorization and activation are separate lifecycle operations.
Ingress activation verifies consumer route coverage, unique ownership, sink
readiness, exact schema/binding identities and required rights. Invocation rights
do not grant backing-object reads/writes or external dispatch. Canonical browser
bindings use the declared records as the native authority's state; no shadow
store, dual writes or fixed OAuth orchestration may substitute for program
execution. Login creates identity but no native grants.

Receipt retention does not expire unresolved effects, continuations, canonical
sessions or transaction recovery evidence. Recovery, authority, revocation,
capability loss and original-effect tests are required before this profile can
be described as an executable application runtime.

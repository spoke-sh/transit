# Ordered application programs v1

This contract defines the ordered Queue program profile coordinated by
[DATAFLOW_V1](DATAFLOW_V1.md), [MIGRATION_V1](MIGRATION_V1.md) and
[BROWSER_V1](BROWSER_V1.md). It introduces no independent catalog, permission
authority, transaction log or effect ledger.

**Implementation status:** bounded source framing, instruction parsing, retained
instruction encoding and local schema binding are implemented in Fuze's
`ApplicationProgram`, together with its host-driven expression evaluator,
scoped continuation codec and typed instruction operands.
Catalog binding,
publication, activation, execution and recovery remain integration work tracked
by [#430](https://github.com/spoke-sh/transit/issues/430). Local compiler success
does not establish that a SQL service can install or run a program.

## Definition and compilation

A definition has a scoped catalog identity, immutable source digest, exact
resource definitions, executor principal/role, input Queue and acquisition
predicate, budgets and native contract definition. Node identities belong to
that frozen definition. A later declaration cannot reinterpret an accepted
invocation or its continuation.

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
binding digest, with a 1 MiB ceiling. Decoding owns its bytes; prepared operands
borrow the input, definition or caller's reusable turn arena. The host must
retain the successor before resetting that arena. A continuation is not an
authorization ticket or evidence of a committed transaction.

`ApplicationProgram.Step` evaluates one instruction into typed operands. Reads,
mutations, effects, response operations and common transaction entry/commit are
explicit host actions. A LET cannot advance without a type-checked result; a
stale local completion cannot advance a newer cursor. Failure entry discards body
locals and is refused while an atomic block remains active. The native owner
must resolve that block's original decision first. These local checks do not
replace durable fencing, transaction recovery or dispatch authorization.

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

Time and randomness enter through native observations. Public observations and
their step identities are retained where continuation requires them. Secret
random material remains transient. Replay cannot generate a replacement secret
to disguise the loss of an original outcome.
Program timestamps use SQL's UTC microseconds since epoch; durations use signed
microseconds. Seconds conversion and timestamp arithmetic must reject overflow.

## Atomic decisions and continuation

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

## Effects, responses and activation

Each effect step has one original identity and recorded intent. Only a newly
accepted dispatch decision may send it. Replay observes its retained outcome;
unknown remote outcome grants no retry permission. The dispatch boundary checks
current program/sink state, role, secret revisions, policy guards and deadline.
Token and profile exchanges share the remaining invocation deadline.

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

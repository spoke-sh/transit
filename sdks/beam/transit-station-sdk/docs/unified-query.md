# Unified state queries

Include `transit_unified_query.hrl` and call `transit_unified_query` for the explicit
v1 KV/Table/accepted-Document profile. Public records are separate from generated
wire schemas. Shared Zig owns validation, codecs, signed operations and query
semantics; the Erlang SDK owns immutable values and a bounded native-port worker.

Declare a `transit_unified_kv` with versioned key/value decoders, a
`transit_unified_table` with its direct scope, service audience, branch, namespace,
interpretation and full schema, or a `transit_unified_document` with an
accepted reference and bounded projections. `prepare/3` takes this source, a
`transit_unified_plan` and positive `transit_unified_budgets`. Ordered projection,
`all`, `{state, Column, State}` and `{compare, Column, Op, Scalar}` predicates share
one model. Predicates and parameters use the shared logical atoms, including
`{signed, N}`, `{unsigned, N}`, `{float64, F}`, `{boolean, B}`, `{utf8, Binary}`
and `{binary, Binary}`. Integers retain their full 128-bit range. Table interpretation binds the immutable declaration and full schema commitments;
an object ID alone does not bind a source definition.

Result columns use full logical descriptors with explicit nullable/optional
flags. Projections allow 128 columns and 255-byte UTF-8 output names. KV decoders
and Document `transit_unified_decoder_column` projections retain their six
scalar decoder types; Document projections remain bounded to eight columns.

`#transit_unified_predicate_program{instructions = Instructions}` composes one
to 64 postfix instructions. `{atom, Predicate}` wraps one of the atoms above;
`negate`, `conjunction` and `disjunction` apply NOT, AND and OR. For example,
`[{atom, A}, {atom, B}, negate, conjunction]` expresses `A AND NOT B`.
Programs cannot nest. Shared Zig checks stack shape, columns and scalar types
before encoding. Evaluation is eager in instruction order, preserves unknown
for null/missing, and selects only true. Immutable instruction lists and binaries
are owned BEAM values.

`open/3` takes a public client config, credential and scoped connection. It owns
no process activation. `describe/2` checks current source policy. For a positive
namespace, `prepare_next/3` returns a prepared record or `undefined`; persist its
bytes before `submit/2`. A lost response returns `{uncertain, Prepared, Error}`.
Retry that identical token, including after closing/reopening the client; do not
prepare a replacement. Other failures return `{error, #transit_error{}}`.
A receipt is admission; `observe/2` checks behavior disposition and `status/2`
checks result completion. An undefined next command means inspect status.

`compile_sql(Client, Source, Name, Sql, Budgets, Parameters)` returns
`{ok, #transit_unified_bundle{}}` or a tagged error through the owned worker.
Pass a list of the existing tagged scalars to bind placeholders. The five-argument
form or `undefined` selects ordinary SQL; `[]` selects a template without
placeholders. The immutable bundle is independent of the client lifetime.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`inspect_sql(Client, Source, Name, Sql, Budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...` through the shared Zig inspection owner.
It returns `{ok, #transit_unified_inspection{}}` with owned names, source/schema
digests, current revisions and description/list/explanation records. Explanation
predicates are `all`, `{state, ColumnName, State}` or
`{compare, ColumnName, Op, Type}`, or a program record whose atom instructions
contain these redacted forms; literal values are excluded. Operator atoms
come from a fixed allowlist, and wide integers retain all 64 bits. Inspection
rechecks current authorization, creates no snapshot and admits no query. The
Table listing covers only the configured source.

`page/2,3` checks current source grants/lifecycle and complete ordered manifest
coverage before returning owned IPC, typed provenance and an opaque cursor.
Manifest evidence includes the retained source head alongside the source and
schema digests.
Undefined continuation means verified complete coverage; cursors grant nothing.
`prepare_control/3` prepares `cancel`, `retire` or `collect` for explicit recorded
lifecycle work with the same submission/retry rules.

`decode_arrow/3` returns bounded immutable row lists with `missing`, `null`,
`{type_error, Kind}`, `{value, LogicalValue}` or `{conflict, Alternatives}` cells.
Logical values include `{atom, Atom}` and nested structures, collections and
unions. Conflict alternatives use `transit_logical_alternative`.
Alternatives preserve ordered counter/replica IDs and explicit value states.
Standalone decoding establishes shape, not current access or completion. Owned
binaries and decoded cells survive client close; no optional BEAM Arrow adapter
is selected.

One operation may be admitted. The worker retains admitted native work when a
waiting caller dies; close joins it. If the creating owner dies, monitored cleanup
closes the port after owned work. Neither lost BEAM processes nor closing a port
cancels durable work. Retain prepared bytes outside transient BEAM state whenever
recovery must survive process loss.

`just bindings::unified-beam` builds installed Erlang/Elixir artifacts and exercises
the signed Table schedule; an optional source selects KV or Document. The
[proof guide](../../../../tests/README.md) records measured qualifications.

Connections accept an optional selected native role; omission uses the login role.
Configure the optional direct Table endpoint with its URL, catalog scope, branch
and service audience when opening the query client. It uses the original caller's
credential and selected role. The native query progress resource can differ from
the Table's catalog resource in the same realm.

`lookup_table/3` returns the current direct Table source, full schema and exact
partition frontier. A missing visible name returns no definition. Lookup takes no
pin and starts no query. The definition's capture helper combines that frontier
with the executor principal and a caller-chosen pin operation identity. A
concurrent change can make the expected frontier stale before acquisition; saved
work must retain its original source and expected position.

Local preparation and SQL compilation return unsigned descriptions. Call
`authorize_bundle/3` with the explicit capture before persisting a new Table
bundle or fingerprint. The returned bytes bind the original caller, role,
credential epoch, exact source, executor, pin owner, query route and budgets.
Storage operation, partition and WAL counters retain their full uint64 range;
native principal identities retain the native counter bound. An already signed
Table bundle rejects resealing. KV and Document bundles take no direct capture.

Persist and recover the original bundle bytes unchanged, alongside every prepared
command and receipt. Current authority is checked during progress and result
reads. Credential or policy changes never justify replacing accepted work.

`prepare_cleanup/3` prepares separate terminal pin cleanup with the current
credential. Persist, submit and observe it like other controls. It preserves the
saved execution proof and cut, including after credential rotation, and grants no
scan or query resumption. The worker commits this proof before remote closure.

Manifest `source` is `{native, ReadVersion}` or `{table, Worker}`; `cut` is
`{native_revision, Revision}` or `{table, Commitment}` (Elixir uses atom tags).
A direct Table cut has no native resource revision. Verified result reads after
pin closure still check current source and result authority.

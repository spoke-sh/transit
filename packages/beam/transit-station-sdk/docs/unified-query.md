# Unified state queries

Include `transit_unified_query.hrl` and call `transit_unified_query` for the explicit
v1 KV/Table/accepted-Document profile. Public records are separate from generated
wire schemas. Shared Zig owns validation, codecs, signed operations and query
semantics; the Erlang SDK owns immutable values and a bounded native-port worker.

Declare a `transit_unified_kv` with versioned key/value decoders, a
`transit_unified_table` with its ID/schema, or a `transit_unified_document` with an
accepted reference and bounded projections. `prepare/3` takes this source, a
`transit_unified_plan` and positive `transit_unified_budgets`. Ordered projection,
`all`, `{state, Column, State}` and `{compare, Column, Op, Scalar}` predicates share
one model. Scalars are tagged `{int64, N}`, `{uint64, N}`, `{float64, F}`,
`{boolean, B}`, `{utf8, Binary}` or `{binary, Binary}`; full-width integers are
checked before crossing the boundary.

`open/3` takes a public client config, credential and scoped connection. It owns
no process activation. `describe/2` checks current source policy. For a positive
namespace, `prepare_next/3` returns a prepared record or `undefined`; persist its
bytes before `submit/2`. A lost response returns `{uncertain, Prepared, Error}`.
Retry that identical token, including after closing/reopening the client; do not
prepare a replacement. Other failures return `{error, #transit_error{}}`.
A receipt is admission; `observe/2` checks behavior disposition and `status/2`
checks result completion. An undefined next command means inspect status.

`page/2,3` checks current source grants/lifecycle and complete ordered manifest
coverage before returning owned IPC, typed provenance and an opaque cursor.
Undefined continuation means verified complete coverage; cursors grant nothing.
`prepare_control/3` prepares `cancel`, `retire` or `collect` for explicit recorded
lifecycle work with the same submission/retry rules.

`decode_arrow/3` returns bounded immutable row lists with `missing`, `null`,
`{type_error, Kind}`, `{value, Scalar}` or `{conflict, Alternatives}` cells.
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

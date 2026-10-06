# Flight wire, IPC and metadata codecs

Run `just test::flight-metadata` in the pinned development environment. The
optional `flight` shell pins PyArrow 23.0.0, protobuf and ADBC 1.12.0. The test
compiles the real native metadata producer and reads its output with PyArrow;
no Python server or alternate metadata encoder substitutes for the Zig code.

`Wire` is generated from the pinned Apache Arrow protobuf files. `Ipc.parts`
validates a finite stream containing one Schema, one RecordBatch and EOS, then
borrows its schema/batch headers and body for standard FlightData envelopes.
It does not split opaque byte fragments into invented batches. Its input is at
most 16 KiB; all decoded allocations use caller-owned bounded workspace.

`Metadata` emits the standard catalog, database-schema, Table, Table-type and
SqlInfo schemas. The latter includes six dense-union children and the required
list/map field names. At most 64 information IDs may be requested. Unknown IDs
fail explicitly. Catalog optional presence remains distinct from an empty filter;
name patterns use bounded UTF-8 `%`/`_` matching (`_` consumes one Unicode scalar). Table schema derivation invokes
the current query SQL compiler and the same `TableResult` layout used for
verified captured rows, without source reads or query admission. `TableResult`
owns up to 128 output names, preserves declared projection nullability, checks
count conversion and rejects missing,
conflicted or mistyped cells. Its workspace is 8 MiB.

`Ticket` signs bounded scope/result references with an explicit deployment key.
Tickets include the current Transit definition and immutable Table source
fingerprint. Unit tests exercise tamper detection, scope separation and expiry. Successful
verification is never authorization; the protocol adapter must check current
service and source rights at each disclosure. See [FLIGHT_V1](../../../../contracts/FLIGHT_V1.md)
for the format, lifetime and exact-retry contracts.

These codec checks do not qualify gateway RPCs, ADBC, TLS placements, durable
restart, cancellation or the outbound recorded-effect adapter.

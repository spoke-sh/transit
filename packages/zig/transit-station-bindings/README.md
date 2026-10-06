# transit-station-bindings

The shared native SDK bridge composes [Station](../transit-station/README.md),
the [client ABI](../transit-client/docs/bindings.md),
[catalog callers](../transit-catalog/README.md), and
[HTTP](../transit-station-http/README.md) and [RPC](../transit-station-grpc/README.md). It owns detached handler
operations, native handle/buffer lifetime, generated C declarations and the schemas
used by every language adapter and the [native port](../../../apps/transit-station-host/README.md).

This package composes shared Zig implementations without reversing Station's
dependency direction. It exports `station_abi`, `libtransit_station`, generated
C declarations and native-port schemas. HTTP and RPC request commitments,
publication actions, durable calls, captured replay and explicit release use
the same scoped turn and dispatch gates as ordinary Station operations.
All [public language SDKs](../../../docs/reference/callers.md) use this boundary.

See the [binding guide](docs/bindings.md) for ownership, scoped turns, explicit
dispatch, exact pending retry and query buffers. Native foreign pointers never
grant durable authority; host runtimes still own scheduling and joined destruction.

`station_logical_codec` exposes Fuze's local logical descriptors, exact values,
casts, structural operations and logical Arrow export with independently owned
buffers. Its [type contract](../../../contracts/FUZE_TYPES_V1.md) defines the
separate logical document identifiers and bounds. These operations do not admit
new native query types, stored Table schemas or file access.

Run `zig build test` here for standalone checks. From the root, use `just check`
and `just bindings::native` for generated-contract drift and real C/C++/Python
ownership/recovery proofs. `just bindings::generate` regenerates declarations
from the public Zig exports; generated resources remain separate from idiomatic
host APIs.

The bridge exports `station_document_codec` and the matching local port action. Shared Zig
prepares/validates canonical Document changes and exact accepted-state references;
SDKs receive owned buffers. Full-width counters/integers use decimal strings,
binary uses hex, and finite float64 uses eight little-endian bytes as hex to
preserve negative zero. Editable text characters are exactly one Unicode scalar,
not one byte, UTF-16 code unit or grapheme cluster. Independent SDC1/SDR1 fixtures
run through native and port surfaces. Scoped owner actions now compose bounded jobs/checkpoints and permanent lifecycle
operations. `station_growing_document_read` exposes descriptions, path/sequence
pages, accepted changes and resynchronization through current permissions, without
writer ownership. Public SDKs expose these shared operations; local capabilities identify the
loaded native implementation, independently of current authority grants.

The bridge exports `station_unified_query_codec` and `unified_query_codec` for typed v1
KV/Table/Document bundles and owned nested Arrow values. See the
[unified query guide](docs/unified-query.md) for representation, bounds and
ownership. Independent bundle and PyArrow fixtures pass through both native
transports; this alone does not qualify a language SDK or signed query lifecycle.
The query caller handle and `query_client` port profile now share signed
preparation, admission observation and current-policy verified pages. The [proof ledger](../../../tests/README.md) records executed source and
installed-language recovery schedules.

The explicit [Table mutation caller](docs/table-mutations.md) exports signed
preparation, frozen recovery and separate durable result/input-rejection reads
through its own native handle and port profile. It delegates to the shared
query package; read-query handles do not acquire mutation capability.

The [catalog caller](docs/catalog.md) exposes general typed schemas, Table DDL/DML,
conditional policy controls and separate operation/input outcomes.
Its C ABI and native port use `transit-catalog`'s shared neutral values and signed
client. Catalog identities retain their full width; preparation, admission and
application remain distinct. Generated resources do not imply idiomatic SDK
administrative methods.

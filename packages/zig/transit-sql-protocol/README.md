# transit-sql-protocol

Pure messages, logical codecs and SCRAM authentication for the
[SQL session API](../../../contracts/SQL_SESSION_V1.md). This package depends on
public protocol definitions and Fuze logical types. It has no service, storage,
account runtime or socket dependency.

`Wire` supplies common database-wire scalar types, byte decoding, bounded read
batches and session limits. PostgreSQL, MySQL and SQL execution share these
definitions without importing the execution service into a codec. The package
build walks transitive imports and rejects runtime and transport dependencies.

`Wire.Session` defines one pending host request or borrowed output at a time.
Each completion carries a connection generation and a monotonically increasing
event sequence. Wrong-generation, duplicate and cancelled completions reject
without advancing another request. Partial output retains the same immutable
buffer and receives a new sequence for each acknowledged fragment. A failed
write closes the continuation; it cannot trigger an error-frame retry.

Prepared descriptors borrow host-owned metadata until their explicit destroy
request. Read batches borrow their owner's cells until the next pull or close.
An output guard names the prepared/read owner or original mutation completion
whose current rights must be checked immediately before writing, including after
parking buffered output. A resumed mutation reply observes that original outcome;
it never re-executes SQL or assumes its execution attachment still exists.
Protected metadata, rows and terminal output carry that guard. An immediate
driver may share one check across a bounded batch; a parked continuation must
recheck before resuming disclosure. Abort suppresses further execution and output;
the host still joins any outstanding borrower and releases its handles before
freeing session memory.
Neither connection generations nor host handles replace durable SQL identities.

`Request` and `JsonResponse` own the reflected JSON control contract. `Response`
adds binary result frames through `ResultFrame`, which validates bounded aligned
framing, initial descriptors and subsequent commitments. `ResultColumns` reuses
Fuze's plain column codec: common scalar values borrow Arrow-compatible buffers;
other types retain canonical logical cells and borrow variable payloads. The full
five-state cell meaning remains available. The body owner must outlive its columns.

`ResultFrame.encodeInto` writes to caller-owned 64-byte-aligned capacity, including
initial metadata and zero padding. `encodedSize` checks the exact required bytes
without allocating; `encode` provides the explicit owned-allocation variant.
`parseInto` uses a caller-owned column directory and supplied initial-metadata
allocator. The directory, metadata and immutable input must outlive every frame
view. Columns retain their own typed validation; framing alone does not admit
values. `ResultColumns` accepts separate scratch/output allocators, which can
borrow fixed workspace leases. Reset those only after every view has ended.

`Codec` carries prepared descriptors and standalone parameters in JSON control
messages. Parameter encoding sizes the canonical value first, then writes and
expands hex in one exact-size allocation. Result payloads use binary framing.
Authentication shares the SCRAM verifier with PostgreSQL and MySQL and adds a
destination-bound native client exchange. No transport compression is admitted.

Run `zig build test` in this directory. `zig build schema` writes the generated
endpoint and message description to stdout. The independent Python wire oracle
also checks the shared SCRAM verifier fixture.

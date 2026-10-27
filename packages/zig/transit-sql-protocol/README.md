# transit-sql-protocol

Pure messages, logical codecs and SCRAM authentication for the
[SQL session API](../../../contracts/SQL_SESSION_V1.md). This package depends on
public protocol definitions and Fuze logical types. It has no service, storage,
account runtime or socket dependency.

`Request` and `JsonResponse` own the reflected JSON control contract. `Response`
adds binary result frames through `ResultFrame`, which validates bounded aligned
framing, initial descriptors and subsequent commitments. `ResultColumns` reuses
Fuze's plain column codec: common scalar values borrow Arrow-compatible buffers;
other types retain canonical logical cells and borrow variable payloads. The full
five-state cell meaning remains available. The body owner must outlive its columns.

`Codec` carries prepared descriptors and standalone parameters in JSON control
messages. Parameter encoding sizes the canonical value first, then writes and
expands hex in one exact-size allocation. Result payloads use binary framing.
Authentication shares the SCRAM verifier with PostgreSQL and MySQL and adds a
destination-bound native client exchange. No transport compression is admitted.

Run `zig build test` in this directory. `zig build schema` writes the generated
endpoint and message description to stdout. The independent Python wire oracle
also checks the shared SCRAM verifier fixture.

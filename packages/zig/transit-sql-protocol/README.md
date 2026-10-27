# transit-sql-protocol

Pure messages, logical codecs and SCRAM authentication for the
[SQL session API](../../../contracts/SQL_SESSION_V1.md). This package depends on
public protocol definitions and Fuze logical types. It has no service, storage,
account runtime or socket dependency.

`Request` and `Response` own the reflected contract. Callers bound input memory
and validate envelopes before handling an action. `Codec` carries canonical
logical descriptors and cells without JSON numeric conversion. Authentication
shares the SCRAM verifier with PostgreSQL and MySQL and adds a destination-bound
native client exchange. Cell and parameter encoding sizes the canonical value
first, then writes and expands hex in one exact-size allocation. Borrowing decode
uses caller-owned binary storage for variable payloads and an arena for recursive
metadata; both owners must outlive the decoded cell.

Run `zig build test` in this directory. `zig build schema` writes the generated
endpoint and message description to stdout. The independent Python wire oracle
also checks the shared SCRAM verifier fixture.

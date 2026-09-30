# Catalog callers

Include `transit/catalog.h` for explicit conditional Table creation and catalog
controls. Supply a client configuration, credential and realm-qualified catalog
resource/owner to `transit_station_catalog_open`. Opening checks the exact native
definition and capabilities. The shared Zig caller owns signing, recovery,
authorization and framework semantics.

`compile_sql` returns an owned typed request and canonical review bytes for the
supported two-column `CREATE TABLE` profile. `prepare_initialize`, `prepare_create`
and `prepare_policy` return opaque signed commands; save their exact bytes before
`submit`. Catalog, operation, object and policy revision identities retain the
full `uint64_t` range; native identities retain their separate safe-integer bound.
Names occupy inline terminated 17-byte arrays (at most 16 name bytes). The value
column supports `INT64`, `BOOLEAN`, `UTF8` and `BINARY` with explicit nullability.

`submit` borrows the prepared command. On `TRANSIT_SDK_UNKNOWN_OUTCOME`, retain
and retry those identical bytes, including after replacing the client. A returned
position establishes admission. `observe` reports input progress;
`input_disposition` reports control/rejection outcomes, and `status_read` matches
the original creation request and receipt. Only `TRANSIT_CATALOG_APPLIED`
establishes creation. Current native and catalog policies gate reads and retries.
Created Tables do not automatically become query sources or mutation writers.

Imports copy their inputs; byte getters borrow their owner. Compiled and prepared
handles can outlive the client and require their matching destroy functions.
Canonical review bytes are bounded to 256 bytes; saved signed commands to 8192.
Metadata, requests and statuses own their fields inline. Absent results have
`found == false`; output pointers/structures clear on failure.

`transit_station_catalog_lookup` reads an exact name, validating its binding and
live Table schema. `transit_station_catalog_definition_read` takes positive
full-width object/revision IDs and reads immutable metadata without requiring
the current Table to match. Both return an inline `transit_station_catalog_definition`
with `found`, scope, object/revision/name, Table source/schema and original
principal/operation/input attribution.

`transit_station_catalog_list` takes a null cursor for a fresh read or the exact
previous continuation. Its page owns `resource_revision`, `count` dense ordered
entries (at most eight), `has_next` and inline `next`. An empty final page is
possible. Every cursor field is required on restoration, including the exact
64-character current `definition`; never default missing compatibility fields.
The input cursor may be the output page's `next`: the caller copies continuation
before clearing outputs. Lookup similarly permits the output's name array as input.

Metadata checks current catalog inspection policy and native grants. A changed
scope/revision returns a conflict; discard the old partial result before starting
a fresh listing. Cursors confer no authority and retain no snapshot. Reads submit
no command. Returned metadata is independent of the client lifetime.

One bounded worker owns each client. Calls block; overlap returns `BUSY`; close
joins active native work. Join caller threads before destroying handles or their
borrowed inputs. Closing does not cancel accepted work. The
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) defines the
four-write boundary, independent policies and terminal conflicts. The
[proof ledger](../../../../tests/README.md) records installed coverage and limits.

# Catalog callers

Include `transit/catalog.hpp` and use `transit::sdk::station::catalog` for typed
catalog creation and controls. `Client::open` takes a client configuration,
credential and explicit catalog connection. The public
[C SDK](../../../c/transit-station/docs/CATALOG.md) owns the bounded worker and
shared Zig caller; C++ adds owned values, move-only handles and RAII cleanup.

`Scope`, `Configuration`, `CreateTable`, `Schema`, `Policy` and `PolicyChange`
retain their full-width identities and owned strings. `compile_sql` returns a
`Compiled` owner; `request()` and `canonical()` copy its typed fields and review
bytes. `prepare_initialize`, `prepare_create` and `prepare_policy` return
`Prepared` owners. Save `data()` unchanged before calling `submit`.

`submit` borrows a `const Prepared &`. An `Error` whose `detail().kind` is
`TRANSIT_SDK_UNKNOWN_OUTCOME` leaves that command available for exact retry.
`Prepared::recover` copies saved bytes; shared Zig checks them before transport.
A returned position establishes admission. `observe` reports input progress;
`input_disposition` and `status` return optional typed outcomes. Creation status
must match the original request, and current policy gates disclosure.

`Client`, `Compiled` and `Prepared` are move-only. Copied results and command
owners survive client disposal. `close()` and destruction join owned work;
overlapping calls reject with `BUSY`. Join caller threads before destroying the
client or borrowed commands. Errors preserve their native category/status;
closing does not cancel accepted work or dispatch a durable control.

`lookup(name)` and `definition(object, revision)` return optional owned
`Definition` values. Name lookup checks the current binding and live Table schema;
exact object/revision lookup reads immutable metadata without requiring the
current Table to match. Definitions retain their scope, identities, name, typed
`TableSource`/schema and original principal/operation/input attribution.

`list()` returns an owned `Page` with `resource_revision`, a dense vector of at
most eight ordered `entries` and optional `next`. Continue with `list(page.next)`
only when `next` is present. An empty final page is possible. `Cursor` contains
the mandatory current `definition`, scope, resource revision and last name; keep
all fields when persisting it. Missing/foreign definitions reject.

Each read checks current catalog inspection policy and native grants. Changed
scope/revision returns a conflict; discard the partial result before a fresh
listing. Cursors confer no authority and retain no snapshot. Metadata reads
submit no command. Copied metadata and page vectors outlive the native caller.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
supported schemas, policies, bounds and conditional publication. Installed
recovery and ownership checks are recorded in the
[proof ledger](../../../../tests/README.md).

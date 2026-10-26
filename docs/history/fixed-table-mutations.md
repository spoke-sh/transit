# Fixed Table mutation caller qualification

This is a historical record for the fixed key/value writer at
[`cc5f57e7`](https://github.com/spoke-sh/transit/tree/cc5f57e7cb32727828a4195e500fa2885cd7afbc).
Its separate CLI, native/port ABI and SDK mutation clients are removed. The
current [Catalog caller](../../packages/zig/transit-catalog/README.md) owns general
Table DDL/DML. The following task names and claims describe the earlier revision;
they are not current entry points or qualification of the replacement. The
[original contract](https://github.com/spoke-sh/transit/blob/cc5f57e7cb32727828a4195e500fa2885cd7afbc/contracts/TABLE_MUTATION_V1.md)
and [combined owner contract](https://github.com/spoke-sh/transit/blob/cc5f57e7cb32727828a4195e500fa2885cd7afbc/contracts/TABLE_QUERY_WRITER_V1.md)
preserve the exact retired definitions. The [proof ledger](qualification/README.md)
retains the executed outcomes and their limits.

`bindings::python-test` also runs installed synchronous and asynchronous Table
mutation clients through `test::table-mutation --sdk python`. Each compiles an
UPDATE, replaces its caller after an accepted-but-lost receipt, retries the
original saved bytes, observes application and rejects disclosure after current
grant revocation. `bindings::mutation-python` selects this schedule independently.

`bindings::node-sdk-test` runs the installed TypeScript mutation caller with the
same lost-receipt and current-grant schedule at namespace `18446744073709551615`.
It also checks generated response validation, byte ownership and preservation of
uncertainty on unconfirmed submit responses. `bindings::mutation-node` selects
these checks independently.

`bindings::ruby-sdk-test` adds immutable mutation values through the existing
owned Ruby worker and native port. Its installed schedule uses namespace
`9223372036854775825`, rejects an altered request commitment, replaces the caller
after receipt loss, recovers the original command and enforces current status
denial. `bindings::mutation-ruby` selects that schedule independently.

`bindings::rust-sdk-test` adds owned requests and exclusively borrowed mutation
calls through the existing native worker. The installed crate consumer uses
namespace `9223372036854775826`, rejects an altered commitment, replaces the
caller after receipt loss, recovers the original command and enforces current
status denial. A separate compiler check rejects overlapping mutable borrows.
`bindings::mutation-rust` selects this schedule independently.

`bindings::c-sdk-test` adds installed C11 and C++17 mutation callers at full-width
namespaces. It checks copied request/prepared buffers, saved commands after native
client close, cleared C failure outputs, caller replacement after receipt loss,
exact retry and current status denial. C++ copy attempts reject during compilation.
`bindings::mutation-c` selects the shared mutation schedule independently.

`bindings::java-sdk-test` adds immutable Table mutation values and bounded futures
over the existing generated-schema port. Its installed caller uses namespace
`9223372036854775829`, replaces the caller after receipt loss, recovers the exact
saved command, rejects changed request commitments and enforces current status
denial. `bindings::mutation-java` selects that schedule independently.

`bindings::dotnet-sdk-test` adds immutable Table mutation values and asynchronous
calls over the existing native worker. Its installed NuGet consumer uses namespace
`9223372036854775830`, replaces the caller after receipt loss, recovers the exact
saved command, rejects changed request commitments and enforces current status
denial. `bindings::mutation-dotnet` selects that schedule independently.

`bindings::beam-sdk-test` adds immutable Table mutation records and structs over
the existing owned worker and generated-schema port. Installed Erlang/Elixir
consumers use namespaces `9223372036854775831` and `9223372036854775832`, retain
the original prepared value in uncertain results, replace the caller, recover
the exact admitted command, reject changed commitments and enforce current
status denial. `bindings::mutation-beam` selects these schedules independently.


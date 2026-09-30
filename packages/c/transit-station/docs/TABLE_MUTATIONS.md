# Table mutation callers

Include `transit/table_mutation.h` for bounded SQL INSERT, primary-key UPDATE and
DELETE. Supply an explicit realm-qualified writer/resource/Table connection,
growing client config and credential to `transit_station_table_mutation_open`.
The writer separately authorizes each caller and operation; read-query access
does not confer mutation access. Opening checks the exact native ABI definition
and local mutation capabilities. Server operations check current authority.

`describe` returns owned inline column names, schema commitment, policy revision,
operation permissions and the optional active namespace. `compile_sql` takes
a name of at most 16 bytes, SQL of at most 4096 bytes and a positive full-width
`uint64_t` namespace. It returns an owned canonical request (at most 799 bytes)
and its complete 72-byte reference. Persist both unchanged before upload.
The [shared contract](../../../../contracts/TABLE_MUTATION_V1.md) defines the
three-row limit, scalar types, atomic application and conflict behavior.

Call `prepare_next` for one stage, persist the returned prepared bytes, then
`submit`. A prepared command holds at most 8192 bytes of opaque signed UTF-8 text.
Import functions copy inputs; shared Zig validates request commitments and saved
commands before transport. Byte getters borrow their owner's memory. Destroy each
compiled/prepared owner with its matching function; both can outlive the client.

Submission borrows the prepared command. `TRANSIT_SDK_UNKNOWN_OUTCOME` requires
resubmitting its exact saved bytes, including after replacing a client. Do not
parse/re-encode, recompile, change namespaces or prepare another stage until that
admission is resolved. There is no implicit retry or upload loop. Independent
clients using one principal still need coordinated sequence allocation.

The returned position establishes admission. `observe` distinguishes pending
from processed input. After processing, `input_rejection` reports a rejected
command independently of the request's result. A null `prepare_next` result
requires `status_read` on the full reference; only `APPLIED` establishes an
affected-row count. Explicit `prepare_control` supports APPLY and CANCEL;
cancellation cannot undo applied rows. Status and metadata reads require current
read grants. Closing does not dispatch a durable control or erase accepted work.

Each client owns one bounded native worker. Operations block, overlap returns
BUSY, and close joins owned native work. Join caller threads before destroying
handles or their borrowed inputs. Output pointers/structures clear on failure.
Metadata/status structs own their data inline and need no destruction. Importing
the library discovers no credentials and starts no client.

Installed C11/C++17 proof coverage, recovery schedules and measurements are kept
in the [proof ledger](../../../../tests/README.md).

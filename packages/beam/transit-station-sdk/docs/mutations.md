# Table mutation callers

Include `transit_mutations.hrl` and call `transit_mutations` for bounded SQL
INSERT, primary-key UPDATE and DELETE. Public records are separate from generated
wire schemas. Shared Zig owns validation, compilation, signing and recovery; the
SDK owns immutable binaries and the bounded native-port worker.

`open(Config, Credential, Connection)` takes explicit client configuration and a
`#transit_mutation_connection{writer, resource, table}`. Writer and resource refs
must share the credential's realm. The writer separately enables each operation
and authorizes the caller. Read-query access does not confer mutation access.
Opening checks the exact generated native definition and local capabilities;
server operations check current authority.

`describe(Client)` returns `{ok, #transit_mutation_description{}}` with current
resource/schema/policy, immutable names, allowed operation atoms and optional
active namespace. `compile_sql(Client, Name, Sql, Namespace)` takes a positive
uint64 namespace and returns `{ok, #transit_mutation_compiled{request, reference}}`.
Compilation does not reserve rows or establish admission. Persist both the
request and complete 68-byte `#transit_mutation_reference{bytes}` before upload.

`prepare_next(Client, Compiled)` returns a `#transit_mutation_prepared{bytes}` or
`undefined` inside `{ok, Value}`. Persist its bytes before `submit(Client, Prepared)`.
A lost response returns `{uncertain, Prepared, #transit_error{}}`, preserving the
original value. Reconstruct that record from the exact saved bytes and resubmit,
including after replacing the caller. Do not recompile, allocate a new namespace,
parse/re-encode the command or advance across unresolved admission. There is no
implicit retry/upload loop or sequence coordinator across independent clients.

Submission returns an admission receipt. `observe(Client, Prepared, Input)`
returns `pending` or `processed`. After processing, `rejection/3` reports an
optional input rejection separately from the request's result.
`status(Client, Reference)` returns a `#transit_mutation_status{}` or `undefined`.
Only `applied` establishes affected rows; an undefined next command requires
checking status. `prepare_control(Client, apply | cancel, Reference)` returns
an explicit prepared control. Cancellation cannot undo applied rows. References
and saved commands never confer authority, and every observation checks current
read grants.

One operation may be admitted. Overlapping calls return `busy`. The worker retains
admitted native work when a waiting caller dies; `close/1` joins it. If the creating
owner dies, monitored cleanup closes the port after owned work. Neither process
loss nor port closure cancels accepted work. Persist prepared bytes outside
temporary BEAM state when recovery must survive process loss. Responses contain
only atoms from fixed allowlists; external text does not create atoms.

The [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md) defines
the three-row, 799-byte request and 8192-byte saved-command limits, scalar types
and rollback/conflict behavior. The Table has a nonnull int64 key and nullable
int64, bool, UTF-8 or binary value. Executed installed-consumer coverage and
measurements belong to the [proof ledger](../../../../tests/README.md).

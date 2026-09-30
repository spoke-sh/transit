# Catalog callers

Include `transit_catalog.hrl` and call `transit_catalog` for explicit
initialization, conditional policy controls and named Table creation. Immutable
public records are separate from generated wire schemas. Shared Zig owns
compilation, signing, policy checks and recovery; the SDK owns its native port
and bounded worker.

`open(Config, Credential, Connection)` takes a `#transit_catalog_connection{owner,
scope}`. The `#transit_catalog_scope{resource, catalog}` qualifies a resource and
positive full-width uint64 catalog identity. Owner, resource and credential share
one realm. Opening validates the matching definition and local capabilities;
server operations independently check current authority.

`capabilities/1` returns a `#transit_catalog_capabilities{}` and `describe/1`
returns a `#transit_catalog_description{configuration, policy, resource_revision}`.
`compile_sql(Client, Sql, Operation, Object, Table)` returns a
`#transit_catalog_compiled{request, canonical}`. Operation/object identities and
policy revisions retain the positive uint64 range; physical Table IDs are
positive uint32 values. Native counters retain the safe-integer bounds.
The two-column Table has a nonnull int64 key and nullable int64, bool, UTF-8
or binary value. Canonical review bytes are bounded to 256 bytes.

`prepare_initialize/2`, `prepare_create/2` and `prepare_policy/2` take typed
configuration, creation and conditional policy-change records. They return
`{ok, #transit_catalog_prepared{bytes}}`. Persist the exact bytes before calling
`submit/2`. Restore that record from the saved bytes, including after caller
replacement. Commands contain at most 8192 bytes of opaque signed UTF-8 text;
shared Zig validates them before transport. Preparation does not dispatch, and
there is no automatic retry or re-signing loop.

Submission returns `{ok, #transit_admission{}}` or
`{uncertain, Prepared, #transit_error{}}`, preserving the original recovery value.
Malformed successful receipts retain uncertainty; explicit native rejections
retain their category, status and code. `observe(Client, Prepared, Input)`
returns `pending` or `processed` inside `{ok, Value}`. `input_disposition/3`
returns an optional control/rejection disposition; `status(Client, Original)`
returns the original creation receipt. Missing results use `undefined`.
Only outcome `applied` establishes creation. Keep the complete original typed
request for status matching. Current catalog and native policy gates metadata,
retries and result disclosure.

One operation may be admitted; overlap returns `busy`. A waiting process dying
does not release admitted native work. `close/1` joins that work and port cleanup.
The creating owner's death initiates monitored cleanup. Neither process loss nor
port closure cancels accepted work. Immutable records and binaries are local
values; recovery across process loss requires externally persisted commands.
External values map only to fixed allowed atoms. Created Tables do not
implicitly become query sources or mutation writers.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
policies, atomic publication and bounds. The
[proof ledger](../../../../tests/README.md) records installed recovery and
native-port fault/ownership checks with their execution limits.

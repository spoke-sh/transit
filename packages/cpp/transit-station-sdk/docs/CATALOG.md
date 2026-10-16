# General Table callers

Include `transit/catalog.hpp` and use `transit::sdk::station::catalog` for typed
catalog DDL, DML and controls. `Client::open` takes a configuration, credential
and explicit catalog connection. The [C SDK](../../../c/transit-station/docs/CATALOG.md)
owns bounded dispatch to shared Zig; C++ adds owned values and RAII handles.

`Schema` contains stable column IDs, owned names, immutable [logical types and
cells](LOGICAL.md), nullability, optional defaults/character limits and an explicit
primary-key list. `Action` selects Create, Alter, Rename, Drop, Insert, Update or
Delete. `Basis` binds existing objects to their exact revision/fingerprint.
`Change` represents ADD/DROP/RENAME COLUMN, defaults, nullability and qualified
type changes. ADD obtains its stable column ID at native admission. An absent
`Assignment::value` means DEFAULT; `logical::Cell::null()` means SQL NULL.
Optional predicates use typed postfix terms with a 64-instruction bound.

`compile_sql` and `prepare(name, identity, action)` return a move-only `Compiled`.
`intent()` copies its attribution; `saved()` returns an independent `SavedIntent`
owner. Save its exact `definition()` and `data()` before requesting progress.
Restore with `SavedIntent::recover`, then `load`. `next` returns running,
upload-cancelled, terminal, or a move-only prepared command. Persist `data()`
before `submit`. `Prepared::recover` copies saved signed bytes; native validation
checks them before transport. No operation silently rebinds saved work by name.

`submit(const Prepared &)` returns admission. An `Error` with
`TRANSIT_SDK_UNKNOWN_OUTCOME` leaves the original prepared command available for
exact reconciliation. `observe`, `input_disposition`, `progress` and `status`
distinguish input processing from the original terminal operation outcome.
Applied DML results contain committed matched/changed counts and owned diagnostic
JSON. Explicit initialize/dependency/resume/control methods return prepared
commands. Close does not cancel durable
work.

`lookup(name)` returns an optional owned live `Definition` containing metadata,
head and schema. `definition(object, revision)` returns an optional
`HistoricalDefinition` containing accepted metadata/schema without a live head.
Historical attribution remains tied to the original object after DROP/name reuse.
`list` returns a dense ordered vector of at most eight entries and optional
`next`. An empty page can have a continuation. Preserve its mandatory definition,
scope, resource revision and last object. Changed cuts conflict; discard the
partial listing before starting fresh. Every read checks current authority.

Table/catalog/application identities retain all 64 bits; native identities keep
their separate safe-integer bound. Names admit 255 UTF-8 bytes. Schemas admit
128 columns, inserts 1,024 rows, SQL 4,096 bytes, saved intents 4,327,031 bytes and
signed progress commands 8,192 bytes. Complete catalog actions remain bounded to
16,777,216 bytes independently of each logical cell; responses admit 16,793,600
bytes. One native intent is resident per client. Aggregate action construction
rejects before dispatch on overflow.

`Client`, `Compiled`, `SavedIntent` and `Prepared` are move-only. Copied metadata,
schemas and immutable logical trees outlive clients. Preparation copies the input
before dispatch; subsequent edits cannot change prepared work. `close` and
destruction join active work; overlap returns `BUSY`. Join caller threads before
destroying their borrowed owners. POSIX cancellation waits for the owned call;
it does not establish remote cancellation.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns native
semantics. Installed recovery and boundary evidence is recorded in the
[proof ledger](../../../../tests/README.md).

Metadata retains the immutable publication commitment: its byte length and
32-byte digest. Lookup, listing and history reject missing or malformed
commitments. C metadata copies this evidence inline; C++ metadata retains it
in `MetadataCommitment` independently of its client lifetime.

Connections select an optional native role and a positive schema namespace.
C sets `has_role`, `role` and `namespace_id` explicitly; C++ defaults to the login
role and namespace 1. `open` takes an optional Table-service URL (NULL in C,
absent optional in C++ for direct infrastructure access). Mediation retains the
caller's signing identity; the service's private resource identity is separate.

Initialization requires the six-ID native authority profile and database name.
Descriptions return the authenticated subject, credential epoch, selected role,
audience, owned context digest and observed authorization revision. Returned
subjects must match the connection. Live definitions include the native object
identity; metadata includes its schema namespace and a commitment bounded to
444 bytes. Lookup/list reject foreign namespaces. Historical definitions retain
original object attribution and require its current disclosure privileges.

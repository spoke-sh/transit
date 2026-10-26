# General Table callers

Include `transit/catalog.h` for direct catalog inspection, Table DDL/DML and
explicit snapshot retention. `transit_station_catalog_open` takes a client
configuration, credential, connection and optional service URL. The connection
identifies a catalog scope, branch, audience and optional role. Each operation
selects its schema namespace. Shared Zig owns authorization, compilation,
signing and storage publication; C owns bounded values and synchronous worker
dispatch. The generated definition must match the installed native library.

`describe`, `namespace_read`, `namespaces`, `tables` and `lookup` inspect the
current catalog through its public owner. Descriptions include the configuration,
authenticated subject and observed policy revision. Lookup returns an owned
metadata handle or NULL. Its basis includes the complete connection, namespace,
name, stable object, definition revision, content digest and schema fingerprint.
Changing a definition makes the old basis stale; reusing a name cannot retarget
saved work. Namespace administration, dependency controls and named KV/Document
publication use their owning public interfaces and have no typed catalog wrappers
in this package.

`compile_sql` accepts SQL, an operation/namespace identity, dialect and ingestion
mode. Supply a new stable object identity for CREATE. `prepare` accepts a typed
request. CREATE carries a schema; ALTER, RENAME and DML carry an owned basis;
DROP carries a basis or the explicit absent-name `IF EXISTS` case. These operations
prepare work without publishing a change. `compiled_get` borrows the intent and
saved-intent handles from their compiled owner.

Persist `saved_intent_export` before staging. `stage` returns a complete operation
reference; persist `reference_export` before admission. `admit`, `inspect`,
`execute` and `cancel` distinguish unobserved, admitted, rejected, cancelled,
committed and unchanged outcomes. Committed row results distinguish matched,
affected and live row counts. `execute` takes a positive, bounded step budget;
callers inspect or advance the original reference explicitly. Closing the client
does not cancel durable work.

`TRANSIT_SDK_UNKNOWN_OUTCOME` leaves all input handles intact and clears output
pointers. Keep the original saved intent for staging uncertainty, reference for
operation uncertainty, acquisition for pin uncertainty and snapshot for release
uncertainty. Restore their complete JSON with the corresponding `*_restore`
function; each restore copies and checks its mandatory definition and binding.
Load a saved intent into a fresh client with `load`. Recovery never resolves an
old operation through a current name, automatically retries it or changes its
identity.

`prepare_snapshot` constructs an explicit owner and expected data position from
metadata. Persist its exported acquisition before `acquire_snapshot`. If the
reply is lost, use `snapshot_status_read` with the same owner to discover its
handle. `snapshot_metadata_read` returns the retained definition, schema and
accepted position even after ALTER, DROP or name reuse. Every disclosure still
checks current database, schema and Table authority. Persist the handle before
`release_snapshot`; status distinguishes released ownership after an uncertain
reply. Client destruction does not release a durable pin. This catalog interface
reads retained metadata; interactive relational SQL has no C catalog wrapper.

Metadata pages contain at most eight ordered entries. Preserve the complete
cursor, including selection, connection and position. Empty pages can have a
continuation. A changed directory cut conflicts; discard the partial listing
before starting again. Table entries carry independent accepted data positions,
so a directory page does not establish a common data snapshot.

Schemas admit 128 columns with stable IDs, [logical types and cells](LOGICAL.md),
nullability, defaults, character limits and primary keys. Encoding and collation
are independent column descriptors. Creation, ADD and metadata preserve them;
`TRANSIT_CATALOG_PHYSICAL` changes them through native validation. Missing or
unknown wire descriptors reject. An empty primary-key list preserves duplicates
using stable row identities. ADD obtains its column ID at native admission.

Construction views borrow input trees for the call. A NULL assignment value means
DEFAULT; a non-NULL logical NULL means SQL NULL. INSERT admits 1,024 rows with
128 assignments each. UPDATE/DELETE use optional postfix predicates of at most
64 terms. Select `TRANSIT_CATALOG_POINT` or `TRANSIT_CATALOG_BULK` explicitly for
typed DML. The serializer checks the complete action bound while appending values;
finite row counts do not allow unbounded aggregate allocation.

Catalog, branch, object, operation and accepted positions use all 64 bits. Native
realm/resource/principal/audience/namespace identities retain their safe-integer
bound. Names admit 255 UTF-8 bytes; SQL admits 4,096 bytes. Native encoded intents
admit 8,388,644 bytes, complete actions 16,793,672 bytes and responses 16,810,056
bytes. One installed intent is resident per client. Other SDK routes retain their
own limits.

Opaque handles require their matching destroy function. Exports and typed views
borrow from their owner; owners survive client closure. One bounded worker owns
each client. Calls block, overlap returns `BUSY`, and close joins active work.
Deferred POSIX cancellation stays masked through receipt publication. Join caller
threads before destroying clients or their borrowed inputs. Definition-bound C
symbols reject mismatched headers and installed libraries before ABI use.

The [direct catalog contract](../../../../contracts/DIRECT_TABLE_V1.md) owns
publication and authorization. The [proof ledger](../../../../docs/history/qualification/README.md)
records installed recovery and boundary evidence.

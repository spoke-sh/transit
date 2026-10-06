# General Table callers

Include `transit/catalog.h` for catalog-based CREATE, ALTER, RENAME, DROP and
typed INSERT/UPDATE/DELETE. Opening takes a configuration, credential and explicit
realm-qualified catalog scope/owner. The native definition and capabilities must
match. Shared Zig owns authorization, schema validation, signing, publication
and recovery; C owns bounded values and synchronous worker dispatch.

`compile_sql` accepts a statement and operation/namespace identity. Supply a
new object identity for CREATE. `prepare` accepts a typed request: CREATE carries
a schema; ALTER/RENAME/DML carry an exact object/revision/fingerprint basis;
DROP carries that basis or the explicit absent-name `IF EXISTS` case. Neither
preparation operation submits work. Schemas admit 128 named columns, stable
column IDs, [logical types and cells](LOGICAL.md), nullability, defaults,
VARCHAR character limits and an explicit primary-key column list. An empty
key list preserves duplicate rows using native row identities.

Construction views borrow their trees for the duration of a call. A NULL
assignment pointer means DEFAULT; a logical NULL uses a non-NULL cell view.
INSERT admits 1,024 rows with 128 assignments each. UPDATE/DELETE take an optional
postfix predicate with at most 64 terms. Logical and complete action bounds
still apply: the serializer stops at the aggregate bound before dispatch.
ADD COLUMN uses a column specification; native admission assigns the new stable
ID. ALTER also represents DROP/RENAME COLUMN, SET/DROP DEFAULT, nullability and
qualified type changes. Type conversions and key restrictions remain native
Table semantics, not C casts. `rights.remove` is the SQL DELETE permission.

`compiled_get` copies the intent summary and borrows its saved-intent owner.
Persist the saved definition and exact bytes before requesting progress.
`saved_import` copies both; missing or foreign definitions reject. `load` binds
the original intent to a fresh client. `next_read` returns running,
upload-cancelled, terminal, or a prepared signed command. Persist each prepared
command before `submit`. On `TRANSIT_SDK_UNKNOWN_OUTCOME`, keep those exact bytes
for reconciliation. A position establishes admission; `observe` reports input
progress; `input_disposition` reports controls/rejections; `progress_read` and
`status_read` carry the original operation result. Only a terminal applied result
establishes a committed change. DML counts distinguish matched and changed rows.

Initialize, policy, dependency, resume and cancellation/cleanup controls use
their explicit preparation functions. Closing a client does not dispatch a
durable cancellation. Current native grants and independent inspect/create/read/
insert/update/delete/alter/drop rights govern operations and disclosures.

`lookup` returns an owned live definition or NULL. It includes metadata, head and
the exact typed schema. `definition_read` returns a separate owned historical
definition without a live head, using accepted historical evidence. DROP/name
reuse cannot redirect it to a replacement object. Definition views borrow their
opaque owner; destroy them with their matching function. Owners survive client
closure. Outcome diagnostics own a validated, bounded diagnostic envelope.

`list` returns at most eight ordered entries and an optional continuation. An
empty page may still have a continuation. Preserve every cursor field, including
the mandatory current definition, scope, resource revision and last object.
The cursor may alias the output page's `next`. A changed cut returns a conflict;
discard the partial listing before starting fresh. Metadata reads submit no
command and still require current inspection authority. Cursors confer none.

Table/catalog/application identities use the full `uint64_t` range. Native
realm/resource/process/principal/input identities retain their safe-integer
bound. Names admit 255 UTF-8 bytes. SQL is bounded to 4,096 bytes, saved intents
to 4,327,031 bytes, signed progress commands to 8,192 bytes and catalog actions
to 16,777,216 bytes. Catalog responses admit 16,793,600 bytes. The native caller
holds one installed intent. Other raw and Station routes keep their own bounds.
Public definition-bound symbols reject incompatible installed artifacts.

Imports copy inputs; byte getters borrow their owner. Opaque handles require
their matching destroy function. Output pointers/structures clear on failure.
One bounded worker owns each client. Calls block; overlap returns `BUSY`; close
joins active work. POSIX thread cancellation is deferred until the owned call
finishes. Join caller threads before destroying handles or borrowed inputs.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
publication and authorization. The [proof ledger](../../../../tests/README.md)
records installed lifecycle, receipt-loss and boundary checks.

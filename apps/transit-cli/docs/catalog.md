# Explicit catalog operations

`transit catalog` uses the shared general Table caller for SQL or typed intent,
private saved steps, exact submission and outcome inspection. Provision the
[catalog host](../../transit-query-host/README.md), resource, caller grants and
worker ownership explicitly. CREATE, ALTER, DROP and typed DML share this owner;
inspect, create, read, insert, update, delete, alter and drop remain separate rights.

## Connection and local preparation

Use version-1 YAML or an explicit `.json` file with the provisioned identities:

```yaml
version: 1
url: http://127.0.0.1:19105
seed_file: caller.seed
connection:
  scope:
    realm: 46
    resource: 3
    catalog: '42'
  owner: 2
  principal: 1234
request_timeout_ms: 5000
```

The catalog ID is a canonical positive uint64 decimal string; native identities
remain bounded JSON numbers. `seed_file` resolves relative to the configuration
file. Other paths resolve from the working directory. Configuration is at most
64 KiB; timeout is 1–60000 ms, default 5000. HTTP/HTTPS URLs cannot contain
credentials, a query or a fragment. There is no configuration discovery or
environment overlay for these commands.

```sh
transit catalog capabilities
transit catalog compile --config catalog.yaml --operation 71 --namespace 71 --object 81 --file create.sql --output compiled.json
```

`capabilities` is local. CREATE compilation is offline: configuration containing
only version and connection suffices. The SQL file may contain, for example:

```sql
CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200), tags LIST(TEXT));
```

The [Table SQL reference](../../../docs/reference/sql/create-table.md) specifies
all admitted types, aliases, defaults and constraints. Compilation reserves no
identity and grants no permission. Operation, upload namespace and object flags
are canonical positive uint64 values. `--object` supplies a new identity only
for CREATE; other statements resolve their original object from current metadata.

For INSERT/UPDATE/DELETE/ALTER/DROP, compilation reads authorized catalog metadata
and therefore needs the endpoint and signing identity. It freezes the original
object, schema and full intent; recovery never recompiles that SQL. `prepare`
takes the [shared typed request](../../../packages/zig/transit-catalog/docs/table-metadata.md#neutral-general-table-callers)
as JSON instead of SQL. Typed CREATE also compiles offline; other typed requests
must match their explicit original basis.

```sh
transit catalog compile --config catalog.yaml --operation 72 --namespace 72 --file insert.sql --output insert-intent.json
transit catalog prepare --config catalog.yaml --file typed-request.json --output typed-intent.json
```

SQL is bounded to 4096 bytes. Typed intent retains its separate operation/value
limits; input and output artifacts are bounded to 16 MiB. A compiled envelope
contains an intent summary and exact saved bytes, both bearing the mandatory
current definition. Subsequent commands restore the bytes and require the full
summary to agree before loading credentials. Foreign or missing definitions
never default to the current format.

## Execute and recover one intent

```sh
transit catalog next --config catalog.yaml --file compiled.json --output step-1.json
transit catalog submit --config catalog.yaml --file step-1.json
transit catalog progress --config catalog.yaml --intent compiled.json --file step-1.json --input 17
transit catalog status --config catalog.yaml --file compiled.json
```

Use the actual receipt position in place of `17`. `next` saves a `prepared`
envelope when another signed step is needed. Otherwise it reports a running,
terminal or upload-cancelled state under `next`; these are not submit inputs.
After a processed nonterminal step, call `next` again with a new output filename.
A running operation uses the owner's durable continuation. `prepare-resume`
can explicitly prepare its qualified recovery continuation.

Only `submit` sends a native command. A native receipt proves input admission.
`observe` reports pending/processed input; `disposition` reports the separate
control or rejected-input result. `progress` checks the original intent, saved
command and admitted input together. `status` returns separate upload and domain
outcomes. Only a terminal domain outcome establishes applied, unchanged,
rejected or cancelled work, with committed matched/changed counts where applicable.

```sh
transit catalog observe --config catalog.yaml --file step-1.json --input 17
transit catalog disposition --config catalog.yaml --file step-1.json --input 17
transit catalog prepare-resume --config catalog.yaml --file compiled.json --output resume.json
transit catalog cancel --config catalog.yaml --file compiled.json --output cancel.json
transit catalog cleanup --config catalog.yaml --file compiled.json --output cleanup.json
transit catalog cancel-upload --config catalog.yaml --file compiled.json --output cancel-upload.json
transit catalog collect-upload --config catalog.yaml --file compiled.json --output collect-upload.json
```

These control commands prepare files; submit them explicitly. Operation
cancellation cannot undo publication. Upload cancellation is separate from a
Table outcome. Cleanup follows the owner's bounded candidate/closed-upload
rules; it does not erase accepted history or original receipts.

Every preparation requires a new output path. The CLI atomically creates a
0600 file, synchronizes file and directory, refuses replacement, then prints the
same envelope. Keep intent and prepared files private. They contain application
values or signed requests, but never the signing key.

After an unknown send outcome, retry the exact prepared file under the same
connection and signing identity. A lost reply, process exit or failed stdout
write cannot establish failure or make replacement work safe. A new CLI process
restores the original intent before observing or continuing it. Name reuse and
schema changes cannot retarget that saved work. Callers sharing a principal must
coordinate native sequences; the CLI does not supply an automatic send retry or
session coordinator. Deleting files does not remove accepted work.

## Initialization and dependency controls

`prepare-initialize` and `prepare-dependency` accept the shared
neutral configuration or conditional control JSON and save one signed step:

```sh
transit catalog prepare-initialize --config catalog.yaml --file initialize.json --output initialize-prepared.json
transit catalog prepare-dependency --config catalog.yaml --file dependency.json --output dependency-prepared.json
```

Initialization includes the exact scope, owner, administrator and explicit
Table publication quotas plus the mandatory native authorization profile.
Provision the database and initial schema bindings through native authorization
before initialization. Dependency controls carry expected revisions; the owner
checks them again when applying the command. Roles, membership and Table grants
use native authorization operations. Matching repeated initialization cannot
restore grants. Inspect each admitted control's separate
input disposition. These operations do not implement SQL GRANT or REVOKE.

## Metadata and saved pages

```sh
transit catalog describe --config catalog.yaml
transit catalog lookup --config catalog.yaml --name people
transit catalog definition --config catalog.yaml --object 81 --revision 1
transit catalog list --config catalog.yaml --output page-1.json
transit catalog list --config catalog.yaml --file page-1.json --output page-2.json
```

`lookup` resolves an exact UTF-8 name of 1–255 bytes and returns a live definition.
`definition` returns an immutable historical definition by object/revision,
without inventing a current head. Absent definitions are null. Quoting and case
normalization happen in SQL; a lookup name is already decoded.

`list` returns at most eight entries ordered by stable object identity, a
resource revision and an optional current-definition cursor. Saved continuation
binds that exact resource cut; `CatalogCursorChanged` requires a fresh listing.
A saved final page rejects continuation instead of silently restarting. Page
artifacts are limited to 64 KiB and validate shape, identity order, scope and
continuation consistency before credentials. No metadata read confers authority.
Current native grants and catalog inspection rights apply on every invocation.

Commands validate options even with `--help`. Results are one neutral JSON
envelope on stdout; diagnostics use stderr. Invocation/configuration failures
exit 2, runtime failures exit 1 and successful commands exit 0. See the
[CLI reference](../../../docs/reference/cli.md) and
[proof ledger](../../../tests/README.md) for interface and executed evidence.

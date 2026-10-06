# Unified SQL shell

With `transit` on `PATH`, run `transit query query.json`. Provision the
[v1 query behaviors](../../transit-query-host/README.md) and current caller grants
first. The configuration contains `url`, `seed_file`, `connection` (realm,
principal, source, resource, requester, requests), optional `request_timeout_ms` (1–60000; default 5000), and `workspace`:

```json
{
  "name": "items",
  "source": {
    "version": 1,
    "resource": 7,
    "source": {"kv": {"prefix": "646174612f", "key": {"version": 1, "type": "binary"}, "value": {"version": 1, "type": "utf8"}}}
  },
  "limits": {"pages": "1000", "segments": "100", "result_bytes": "1048576"}
}
```

This is an example workspace fragment, not a provisioned connection. The source
must match the configured resource and source policy. Table/Document declarations
use the same neutral `Values.Source` as SDKs, with exact schemas, declared paths,
accepted references and decoder versions. Limits are explicit positive decimal
u64 strings. No names or values infer a decoder or grant access.

```text
.sources
.new 42
SELECT value FROM items LIMIT 33
.status
.next
```

SQL compiles through the [shared v1 compiler](../../../packages/zig/transit-fuze/docs/unified-sql.md).
Each statement freezes a finite bundle and advances its upload, committing each
input before preparing its successor. A receipt means input admission. A command
waits at most 30 seconds for input progress before returning `waiting_for_input`;
`.advance` resumes that observation/upload. Each network attempt also has its
configured timeout. Result completion is separate; `.next` reads one verified
segment only after a complete manifest exists.

| Command | Meaning |
| --- | --- |
| `.sources`, `.schema` | Current authorized declaration, SQL capabilities and budgets |
| `.new ID` | Select an unused positive u64 namespace before entering SQL |
| `.execute FILE` | Compile and upload a JSON query object with `sql` and optional typed `parameters` |
| `.resume ID` | Observe an existing namespace without executing SQL again |
| `.status`, `.info` | Durable status or bounded local session state |
| `.advance` | Observe admitted input, then continue the same finite upload |
| `.bundle`, `.restore-bundle HEX` | Export/import the canonical finite bundle for interrupted uploads |
| `.pending` | Explicitly export the exact pending token for recovery |
| `.restore TOKEN`, `.retry` | Import a canonical token and resubmit exactly its signed bytes |
| `.next` | Render one owned typed result page and exact source/plan evidence |
| `.cancel` | Record cancellation; a local disconnect cannot cancel durable work |
| `.retire`, `.collect` | Withdraw a terminal request and reclaim it in bounded steps |
| `.quit` / EOF | Disconnect without changing durable state |

`.execute query.json` uses the same shared compiler and exact scalar codec as
the client and SDKs. For example, after `.new 42`, this file binds a uint64 LIMIT:

```json
{"sql":"SELECT * FROM items LIMIT $1","parameters":[{"unsigned":"3"}]}
```

Omitted/null bindings select ordinary SQL; `[]` selects a template without
placeholders. Paths resolve against the working directory; quoted paths support
spaces. Input files are limited to 131072 bytes, statements to 4096 bytes, and
bindings to at most 65 exact scalars. Compilation retains current source/budget checks
and cannot execute mutation or administrative SQL. The
[parameter contract](../../../contracts/SQL_PARAMETERS_V1.md) defines types
and grammar sites. Inputs are owned only for that command; values are never
substituted into text or retained as default bindings.

An unconfirmed submission stays pending. Never replace it with new SQL. Save the
canonical bytes returned by `.bundle` and the opaque token returned by `.pending`
if recovery must survive shell exit; the shell does not write history or credentials.
In a fresh shell, `.resume ID`, `.restore-bundle HEX`, `.restore TOKEN` and `.retry`
reconcile the original input and continue the original upload. Recovery does not
read query input files again; changing or deleting them cannot rebind saved work.
Import rechecks
the configured source, budgets, durable identity and current policy. Without an
uncertain input, `.advance` continues the imported bundle. Keep exported material
private: bundles can contain query literals. Never reconstruct a lost bundle from SQL. Commands and results use escaped JSON, wide
scalars stay decimal strings, binary stays hex and float bits remain lossless.
Missing, null, type error and conflict alternatives are explicit.

Only one finite bundle, frozen command and cursor remain resident. Rows die with
the command arena. Observed denial, retirement or a Document history gap clears
the result cursor and completion state. The original bundle and pending signed
command remain available for exact recovery; losing read access does not cancel
or discard accepted work. Prior terminal output was already disclosed. A cursor is
not a grant. Request retirement does not erase the source's independent result
publication or permanent identity facts.

Use `transit --diagnostics=json query FILE` for shared error records on stderr.
The default shell retains its JSON stdout error records. The optional stderr
mode preserves compiler coordinates and saved recovery identity; ordinary result
and shell banner output retains its existing format.

The [proof guide](../../../tests/README.md) records commands and completed
measurements for the real shell with all three source daemons and recovery.

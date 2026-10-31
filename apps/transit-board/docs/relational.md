# Relational worksheet

Board's Operations screen contains an explicit-submit relational worksheet.
It uses the shared Zig [interactive caller](../../../packages/zig/transit-query/docs/relational-callers.md)
for one or two Tables, one inner/left int64 or UTF-8 equijoin, int64/UTF-8 projection/grouping,
COUNT and ordered checked int64 SUM. SQL declares int64 as `BIGINT`.
The [relational contract](../../../contracts/RELATIONAL_V1.md) defines exact
ordering, nulls, multiplicity, limits and unsupported forms.

## Configuration and access

Enable the route with a separate query identity and explicit catalog connections:

```json
{
  "relational": {
    "seed_file": "/run/board/relational-seed",
    "recovery_directory": "/var/lib/transit-board/query-recovery",
    "query": {
      "definition": "04cd820c132773e6cd69e1d4174f1dff012f8e0f286a82dc35512327a252c6d6",
      "service_url": "http://127.0.0.1:9400",
      "catalogs": [
        {
          "scope": { "realm": 71, "resource": 3, "catalog": "1" },
          "branch": "1",
          "audience": 100,
          "principal": 1234,
          "role": null
        }
      ],
      "spill_directory": "/var/lib/transit-board/query-spill",
      "options": {
        "consistency": "independent_table_snapshots",
        "resident_bytes": "16777216",
        "spill_bytes": "16777216",
        "result_bytes": "8388608",
        "output_rows": "1000",
        "work_steps": "100000",
        "source_pins": 2,
        "requests": "100000",
        "spill_work": "100000"
      }
    }
  }
}
```

Use the current shared definition from the installed build and the realm,
resource, catalog, branch, audience and principal provisioned by your installation.
The direct service URL defaults to Board's native upstream. One or two configured
routes must identify the same direct catalog connection and signing identity;
SQL selects Tables within that catalog. The query principal differs from the
inspection principal and application operators. Provision database CONNECT,
schema USAGE and Table SELECT through public authorization operations. An explicit
`role` requires a current SET path from the login role. Configuration grants no
access.

Both directories must exist and be private to the service. Spill files are
immediately unlinked. The recovery directory holds a bounded 32 KiB journal and
an exclusive process lock; another Board using that journal rejects at startup.
Keep the recovery directory across service replacement. It contains the original
SQL, source definitions, accepted positions and pin identities, but no result rows
or credentials. A missing or foreign contract definition or changed connection
rejects startup; it never resets accepted work. After a key rotation, the new
credential for the same principal can close that principal's original pins.

Every viewer admitted by the private deployment boundary shares this query
identity and one active relational query. Board adds no viewer sessions or keys.
Current native and catalog rights govern every read, including cached and
terminal pages. The identity key is loaded when Board starts; replacing its seed
file requires a restart. A restart loses the interactive executor and marks its journal for explicit cleanup. Use separately
configured instances when viewers need independent query slots or scopes.

## Explicit operations

**Inspect relational workspace** reads current catalog metadata and the active
query, if present. It opens no query and advances no page. The active observation
includes the exact reference, source cuts and current ordinal, under every
source's current rights. It can recover the same host's active query after a
lost response or browser reload. It cannot recover execution lost with Board.

Select a catalog route for each `FROM`/`JOIN` target. Two targets may both select
route zero. **Explain relational query** returns a proposed plan, sources and
output columns without data cuts or execution. Editing SQL or routes does not
open a query. **Run relational query** first saves the explained definitions and accepted
positions with a fresh ID, then asks the service to acquire those exact source
cuts. The service journals each original pin owner before dispatch and every
received handle before opening execution. A changed source rejects instead of
silently selecting newer data. Each Table has its own accepted position; the
cuts do not form a global transaction.

The active reference and source cuts remain distinct from the draft and proposed
plan. **Read current relational page** reads or repeats the current ordinal.
**Next relational page** advances by one after a row. The view holds one row,
with exact decimal integers and explicit nulls. Every row is an **Incomplete
prefix** until the empty terminal page establishes **Complete coverage**.
Errors never convert a partial result into an empty successful result.

The browser repeats the visible current-page read every five seconds to recheck
authority. It clears rows and metadata on read failure or hiding, and rechecks
the active observation on return. Current denial also clears the SQL draft and
prior diagnostic detail. **Close relational query** records closure before
releasing the original pins and spill. Cleanup requires the original owner's
current credential and CONNECT/USAGE/SELECT rights, including release. Revocation
keeps the saved closure pending until an operator restores those rights; it does
not silently discard the original pins.
Unknown open/close responses preserve their identities for exact retry in both
the service journal and the live browser's memory. After a service restart,
**Inspect relational workspace** exposes interrupted ownership and **Close
interrupted query** reconciles and releases its original pins, including an
acquisition whose reply never arrived. It closes no replacement query and does
not resume lost execution. New work waits until that cleanup completes. No result pages,
credentials or recovery identities are written to browser storage.

## HTTP boundary

`POST /api/v1/relational` accepts `RelationalWorkspace.Request` and returns its typed
response. `{"describe":{}}` reads the current workspace and pending recovery.
`{"query": action}` accepts capabilities, explain, open, page or close.
Open contains `{id, statement, sources}` with the complete source bindings and
positions from explanation. Page and close use the shared interactive reference.
`{"recover":{"id":"…"}}` explicitly closes the matching original journal entry;
repeating recovery for the most recently closed ID succeeds. The [generated OpenAPI](../../../contracts/transit-board-v1.openapi.json)
and browser validators derive from those Zig types.

Requests require an `Origin` matching the admitted Host and scheme, and JSON content type. The body
limit is 16 KiB; responses use the browser's 256 KiB decoded limit. One page has
at most 128 int64/uint64/UTF-8/null cells. Existing Board deadlines, shared read throttle
and serialized query lock apply. The browser retries an identical pre-dispatch
429 refusal at most three times, 250 ms apart. Other errors require explicit
caller action. A disabled route returns `404 QueryDisabled`.

This route executes interactive queries only. It does not activate captured jobs,
maintained results, subscriptions, administrative SQL or external effects.
Closing a browser tab leaves the bounded active query on Board; another authorized
viewer can inspect and close it. Stopping Board destroys its local session and performs no network cleanup.
The persisted original pin requests remain for explicit recovery by its next
owner. Retention has no implicit expiry; losing or deleting this journal can
leave pins that require separate operator reconciliation.


The configured relational workspace also accepts the read-only `storage`
request with a configured catalog route and exact prepared Table binding. It
uses the signed direct Table storage operation, checks the current name and
definition, and applies the workspace identity's current object permissions.
This identity is separate from Board's node inspection identity. The response
contains exact decimal strings for positions, row/byte counts, history floors
and maintenance targets. The backlog is bounded to 1024 inspected current rows;
`pending_complete` distinguishes a full count from a prefix. These are current
independent facts, not the proposed query's snapshot. The read neither opens a
query nor writes its pin journal. The proposed-plan view exposes this read per
source and clears the displayed facts on read failure or lost visibility.

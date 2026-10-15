# Relational worksheet

Board's Operations screen contains an explicit-submit relational worksheet.
It uses the shared Zig [interactive caller](../../../packages/zig/transit-query/docs/relational-callers.md)
for one or two Tables, one inner/left int64 equijoin, int64 projection/grouping,
COUNT and ordered checked int64 SUM. SQL declares int64 as `BIGINT`.
The [relational contract](../../../contracts/RELATIONAL_V1.md) defines exact
ordering, nulls, multiplicity, limits and unsupported forms.

## Configuration and access

Enable the route with a separate query identity and explicit catalog connections:

```json
{
  "relational": {
    "seed_file": "/run/board/relational-seed",
    "query": {
      "catalogs": [
        {"scope": {"realm": 71, "resource": 3, "catalog": "1"}, "owner": 1, "principal": 1234},
        {"scope": {"realm": 71, "resource": 7, "catalog": "2"}, "owner": 6, "principal": 1234}
      ],
      "spill_directory": "/var/lib/transit-board/query-spill",
      "options": {
        "consistency": "per_resource_snapshot_vector",
        "resident_bytes": "16777216", "spill_bytes": "16777216",
        "result_bytes": "8388608", "output_rows": "1000",
        "work_steps": "100000", "source_pins": 2,
        "requests": "100000", "spill_work": "100000"
      }
    }
  }
}
```

Use the realm, resources, catalog IDs, owners and principal provisioned by your
installation. All connections use Board's configured upstream and realm, one
principal and the same signing key. The query principal differs from the
inspection principal and application operators. Provision its native resource
read grants and native database CONNECT, schema USAGE and Table SELECT through
the public authorization operations. Each catalog connection can explicitly
select its `role`; that role requires a current SET path from the login role.
Configuration does not grant access. The spill directory must exist; the query
owner creates a private file and immediately unlinks its name.

Every viewer admitted by the private deployment boundary shares this query
identity and one active relational query. Board adds no viewer sessions or keys.
Current native and catalog rights govern every read, including cached and
terminal pages. The identity key is loaded when Board starts; replacing its seed
file requires a restart. A restart loses this interactive query. Use separately
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
open a query. **Run relational query** uses a fresh ID and captures the explicit
resource vector. Aliases on one resource share its cut; different resources do
not form a global transaction.

The active reference and source cuts remain distinct from the draft and proposed
plan. **Read current relational page** reads or repeats the current ordinal.
**Next relational page** advances by one after a row. The view holds one row,
with exact decimal integers and explicit nulls. Every row is an **Incomplete
prefix** until the empty terminal page establishes **Complete coverage**.
Errors never convert a partial result into an empty successful result.

The browser repeats the visible current-page read every five seconds to recheck
authority. It clears rows and metadata on read failure or hiding, and rechecks
the active observation on return. Current denial also clears the SQL draft and
prior diagnostic detail. **Close relational query** releases its own pins and
spill even after source payload access is denied. Unknown open/close responses
retain their original in-memory identity for exact retry. No result pages,
credentials or recovery identities are written to browser storage.

## HTTP boundary

`POST /api/v1/relational` accepts `RelationalCaller.Request` and returns its typed
response. `{"describe":{}}` reads the current workspace. `{"query": action}`
wraps a shared `RelationalBridge.Action`: capabilities, explain, open, page or
close. The [generated OpenAPI](../../../contracts/transit-board-v1.openapi.json)
and browser validators derive from those Zig types.

Requests require the exact configured `Origin` and JSON content type. The body
limit is 16 KiB; responses use the browser's 256 KiB decoded limit. One page has
at most 128 int64/uint64/null cells. Existing Board deadlines, shared read throttle
and serialized query lock apply. The browser retries an identical pre-dispatch
429 refusal at most three times, 250 ms apart. Other errors require explicit
caller action. A disabled route returns `404 QueryDisabled`.

This route executes interactive queries only. It does not activate captured jobs,
maintained results, subscriptions, administrative SQL or external effects.
Closing a browser tab leaves the bounded active query on Board; another authorized
viewer can inspect and close it. Stopping Board destroys its local session and
attempts source lease cleanup.

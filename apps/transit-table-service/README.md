# transit-table-service

Schema lookup/list/status and schema preparation use the same original-subject
boundary as Table operations. `compile_authorization` resolves selected SQL to
a neutral typed plan. `schema_plan_prepare` checks its policy basis and returns
an unsigned candidate; the original caller signs and explicitly submits it.
Native role/grant plans use the separate shared authorization administration
client. The service neither signs user commands nor applies policy on startup.

`transit-table-service CONFIG.json` exposes authenticated Table operations at
`POST /table/v1`. Build it with `zig build transit-table-service`. It listens on
IPv4 loopback; a configured TLS ingress can proxy this private hop. This binary
does not provision roles, restore grants or start PostgreSQL/MySQL listeners.

The service uses a private native principal with process inspection and read
access to one catalog resource. Callers supply a signed original-subject proof
bound to the complete action, connection, nonce and current contract definition.
Native authority checks the credential epoch, selected role and current grants.
The service's storage credentials never become caller credentials.

Configuration requires `upstream`, `realm`, non-root `principal`, `seed_file`,
`scope` (`realm`, `resource`, decimal-string `catalog`), catalog `owner` PID and
`port`. Optional `limits`, `http` and `upstream_timeout_ms` bound admitted work.
The seed file contains a 32-byte Ed25519 seed as hexadecimal and stays private.
The configured identity needs native inspection of the catalog PID and native
inspection/read of its resource. A caller with only Table privileges receives
neither raw resource permission nor service credentials.

`describe`, `list`, `lookup`, historical `definition`, SQL `compile`, typed
`prepare`, `next`, `status`, `control` and finite single-Table `query` use the
shared Catalog and Fuze implementations. The reflected Zig types in
[`TableService.zig`](../../packages/zig/transit-query/src/TableService.zig) own
the request and result shapes. List pages filter Tables through current
visibility. Query results contain typed columns and cells, with `complete: true`
only after the complete query and its final authorization checks succeed.
There is no partial successful result when a query exceeds its budget.

Mutations remain native, durable catalog commands. `next` returns a reviewable
unsigned candidate with the caller-supplied next sequence. The caller validates
it against the saved intent, signs it with its own key, persists the exact bytes
and submits to native authority. After an uncertain send it retries those same
bytes; it does not ask for a replacement sequence. Service restart does not
erase accepted native work or its catalog outcome.

Default limits per request are 1 MiB input, 1 MiB output, 32 MiB resident
workspace, 1,024 result rows and 4,096 native scan reads. HTTP defaults admit two
data requests concurrently, four connections and one control slot, with a
30-second request deadline. Queries may request smaller row/read limits.
The service serializes its response before its final current grant check.
Revocation does not recall bytes already disclosed. Browser Origin headers are
rejected; this endpoint uses signed requests and no browser cookies or sessions.

`GET /health` reports the listener. It does not certify catalog provisioning or
effective user privileges. The [authorization contract](../../contracts/AUTHORIZATION_V1.md)
defines those boundaries; [proof evidence](../../tests/README.md) records actual
executions and their limits.

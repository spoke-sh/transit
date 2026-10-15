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
An optional `spill_directory` names an existing private directory for relational
joins and aggregates. The executor creates mode-0600 spill files and immediately
unlinks them; service shutdown does not leave query files for another caller.
Without this directory, the service admits finite single-Table queries only.
The seed file contains a 32-byte Ed25519 seed as hexadecimal and stays private.
The configured identity needs native inspection of the catalog PID and native
inspection/read of its resource. A caller with only Table privileges receives
neither raw resource permission nor service credentials.

`describe`, `list`, `lookup`, historical `definition`, SQL `compile`, typed
`prepare`, `next`, `prepare_resume`, `status`, `observe`, `disposition`, `progress`,
`control` and finite `query` use the
shared Catalog and Fuze implementations. The reflected Zig types in
[`TableService.zig`](../../packages/zig/transit-query/src/TableService.zig) own
the request and result shapes. List pages filter Tables through current
visibility. Query results contain typed columns and cells, with `complete: true`
only after the complete query and its final authorization checks succeed.
There is no partial successful result when a query exceeds its budget.
The relational profile accepts the shared Fuze int64 joins and grouped COUNT/SUM
forms with at most two Table sources in the configured catalog and namespace.
It acquires one shared resource snapshot and checks current privileges on every
source, including empty and noncontributing inputs, through completion. It does
not imply cross-database queries or an atomic snapshot across resources.
The [generated service schema](../../contracts/table-service-v1.schema.json)
reflects those same public types. `just contract::table-service-check` verifies
that the published schema matches the implementation.

Mutations remain native, durable catalog commands. `next` returns a reviewable
unsigned candidate with the caller-supplied next sequence. The caller validates
it against the saved intent, signs it with its own key, persists the exact bytes
and submits to native authority. After an uncertain send it retries those same
bytes; it does not ask for a replacement sequence. Service restart does not
erase accepted native work or its catalog outcome.

`MediatedTableClient` and `MediatedTableBridge` provide the shared Zig caller and
neutral catalog lifecycle. The catalog CLI selects this boundary with
`table_service_url`. It authenticates each action using the caller's current
credential and retains owned response strings/rows until the response is freed.
Status and recovery use current object visibility and the original saved bytes.
Callers need no native process inspection or raw-resource reads. Writers require
an explicit native send capability to the catalog PID in addition to their Table
privileges. `transit catalog receipt` recovers exact native admission with the
current credential, including after rotation; an absent receipt leaves the
pending command unchanged. The service does not expose initialization or raw
dependency provisioning to restricted callers.
Recovery verifies the complete retained send against its native receipt before
reporting processing. A supplied position alone cannot establish admission or
completion, even when the mailbox has already advanced beyond it.

Default limits per request are 1 MiB input, 1 MiB output, 32 MiB resident
workspace, 1,024 result rows and 4,096 native scan reads. HTTP defaults admit two
data requests concurrently, four connections and one control slot, with a
30-second request deadline. Queries may request smaller row/read limits.
Relational defaults allow 64 MiB of spill, 1,048,576 execution steps and
1,048,576 spill operations; their maximums are 4 GiB, 16,777,216 and 16,777,216.
These bounds limit one finite request, independently of durable Table size.
The service serializes its response before its final current grant check.
Revocation does not recall bytes already disclosed. Browser Origin headers are
rejected; this endpoint uses signed requests and no browser cookies or sessions.

`GET /health` reports the listener. It does not certify catalog provisioning or
effective user privileges. The [authorization contract](../../contracts/AUTHORIZATION_V1.md)
defines those boundaries; [proof evidence](../../tests/README.md) records actual
executions and their limits.

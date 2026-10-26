# Settings and reload

The console and configured PostgreSQL/MySQL gateways execute settings SQL
through one shared compiler and authorized configuration service. The
[configuration reference](../configuration.md) owns file discovery, precedence,
keys, permissions and lifecycle. Query-only, Board and Flight interfaces do not
execute these administrative statements.

## Settings metadata

```sql
SHOW ALL;
SHOW query.statement_timeout;
SELECT name, value, configured_value, source, pending_restart
FROM transit_settings() WHERE pending_restart = true ORDER BY name;
```

`SHOW ALL` returns `name`, nullable `value` and `description`. Exact keys return
one nullable UTF-8 `value`. Unknown keys reject. The metadata relation exposes
registered defaults, accepted configured values, effective values, kind, units,
bounds, owner, instance, scope, change policy, session eligibility, generation,
session generation, source and pending restart. Values use canonical text;
Boolean flags and counters retain their SQL Boolean/unsigned types. Enum lists
and component lists are JSON text. Redacted values are NULL with `redacted=true`.

Projection, typed Boolean predicates and LIMIT use Fuze's Table compiler. ORDER
BY accepts one metadata column and optional ASC/DESC. Reload-history ordering
requires LIMIT at most 256; reads use eight-row pages and a 10,000-page work
budget. A changed generation/revision rejects continuation; discard partial
output and retry. Joins, aggregates and arbitrary scalar expressions reject.

SQL sessions retry temporary transport failures during settings authorization
and page reads within the configured request and statement deadlines. A page
retry retains its exact continuation and already collected rows; it cannot
switch to a newer configuration generation. Permission denial and changed
snapshots stop the read. These observation retries do not resubmit reloads.

## Reload and retained outcomes

```sql
SELECT transit_reload_conf();
SELECT operation, phase, generation, error_code, error_field
FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 20;
```

The first statement is an administrative operation with a single text operation
ID result. History uses the same lower-case hexadecimal ID in its `operation`
column, so an exact operation can be filtered by that value. It accepts no arguments and cannot appear inside another expression,
subquery or query source. Preparation and description do not dispatch it. A
validation failure returns an error and retains a rejected outcome. Active
values remain unchanged. There is no separate configuration check function.

The SQL service saves the original reload request before sending it. The console
checks that exact request internally after an uncertain response. SQL gateways save
one serialized reload lane per account; the next reload reconciles an unresolved
request before creating another identity. Current authorization is checked on
every attempt. A connection loss or statement timeout does not cancel acceptance.
Completed reload controls yield to subsequently submitted query or Table work.

History includes operation, ordinal, initiating principal, generation, phase,
per-owner component outcomes and sanitized diagnostic fields. An `applied`
outcome means all changed values in this local owner applied; `pending_restart`
means at least one changed owner requires a normal restart. There is no automatic
restart or distributed rollout.

## Session controls

```sql
SET query.statement_timeout = '2s';
SET query.statement_timeout TO DEFAULT;
RESET query.statement_timeout;
RESET ALL;
```

Only `query.statement_timeout` is session mutable. Integer values are milliseconds;
strings require explicit units. Zero removes the additional deadline when the
captured ceiling permits it; values above the ceiling or 24 hours reject. RESET
uses the session's captured default. RESET ALL changes neither login identity
nor role, database selection, fixed protocol settings or accepted work. Connection
reset clears the override. A new connection captures the current host defaults.

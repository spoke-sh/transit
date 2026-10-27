# Configuration and settings

Transit reads YAML configuration and exposes active settings through SQL. The
local server, SQL console and configured PostgreSQL/MySQL adapters share typed
settings and validation. The [registry](../../../contracts/configuration-settings-v1.json)
contains every local key, default, type, bound and owner; the
[service contract](../../../contracts/CONFIGURATION_V1.md) defines authorization,
pagination and recovery.

The annotated [transit.yaml.example](../../../transit.yaml.example) covers all local
server settings, including independently enabled PostgreSQL/MySQL listeners,
accounts and TLS. Copy it to `transit.yaml`; the repository ignores that local
file. Every setting is commented out, so the unchanged file supplies no overrides.
Uncomment only the desired keys and their parent sections, retaining the shown
indentation. Omitted settings use built-in defaults, subject to environment
overrides. Leaving a section commented out does not disable a service that starts
by default. Values shown are defaults unless labeled as optional examples,
including listener, account and executable-path examples. SQL accounts require
explicit authentication and authority: choose one-time `bootstrap_owner`
enrollment or the scoped grant workflow in the
[local database guide](../../../apps/transit-cli/docs/sql.md).

## File selection and precedence

The server selects one source in this order:

1. The existing `--config FILE` option.
2. `TRANSIT_CONFIG`.
3. `transit.yaml` in the startup working directory.
4. `$XDG_CONFIG_HOME/transit.yaml`, or `~/.config/transit.yaml` when XDG is unset.
5. `/etc/transit/transit.yaml`.
6. Built-in defaults.

An explicitly selected missing file fails. Discovered files are not merged.
Reload retains the absolute filename, including through atomic file replacement;
it does not repeat discovery. A startup without a file remembers its project
filename for later creation. Once a file has supplied an accepted configuration,
its disappearance is an error.

Defaults precede file values and captured startup environment overrides.
`TRANSIT_PORTS__GATEWAY=19205` overrides `ports.gateway`;
`TRANSIT_QUERY__STATEMENT_TIMEOUT=5s` overrides `query.statement_timeout`.
Double underscores separate path segments. Parent object overrides precede more
specific leaf overrides. Lists replace as a whole. Unknown names, duplicate
mapping keys, invalid types and invalid effective combinations fail. Reload
retains startup environment values; changing another shell's environment does
not change the running process.

`TRANSIT_CONFIG` and `TRANSIT_CONSOLE_CONFIG` select input files rather than
settings. Tooling variables such as `TRANSIT_SQL_TOOLS`, `TRANSIT_DOCS_BASE_URL`,
`TRANSIT_DOCS_URL` and `TRANSIT_KUBECONFIG`, and the exact development launcher
names described in the [launcher guide](../../../launchers/README.md), are excluded
from server settings. For example, `TRANSIT_BOARD_PORT` configures the development
launcher, while `TRANSIT_BOARD__PORT` overrides `board.port` for `transit server`.
Known per-service launcher log variables are also excluded. Other unknown
`TRANSIT_` names still fail; these exceptions do not reserve whole prefixes.

The data-only YAML profile supports block mappings, sequences including mapping
items, quoted/plain scalars and JSON flow values. Anchors, aliases, tags, merge
keys, multiline scalars and multiple documents are rejected. Input is limited
to 64 KiB, 96 levels and 65,536 nodes. Duration strings use explicit `ms`, `s`,
`min` or `h`; integer durations are milliseconds. Relative file paths are resolved
against the selected configuration directory. There is no shell interpolation.

```yaml
ports:
  gateway: 19205
query:
  statement_timeout: 5s
  statement_timeout_ceiling: 30s
gateway_allowed_hosts:
  - transit.example:443
```

`logging.format` defaults to `text`; `json` selects structured operational logs.
`logging.level` defaults to `info` and accepts `debug`, `info`, `warn`, `error`
and `off`. `TRANSIT_LOGGING__FORMAT=json` selects JSON through the same override
rules. Both settings require restart, including for supervised Transit children.
See [observability](observability.md) for stderr, terminal and machine output.

The `sql.postgres` and `sql.mysql` objects are independently nullable and default
to null. A configured object selects its loopback listener; its `port` defaults
to 15432 or 13306 respectively. `TRANSIT_SQL__POSTGRES__PORT=15432` selects the
PostgreSQL listener through the same typed override rules. `sql.accounts` is a
bounded list of typed account declarations, replaced as a whole by an environment
override. Account declarations and TLS file references are redacted from settings
inspection. SQL placement settings require restart; reload records a validated
pending value without changing listening sockets. An enabled listener requires an
enabled account. `sql.tls.mode` selects `disabled`, `optional` or `required`
(default), independently of each account's `authentication` (`password` by
default, or explicit loopback `trust`). `bootstrap_owner: true` on a newly
enrolled `local_owner` account records its initial binding automatically; it
never restores revoked access. Password accounts require `password_file`;
trust accounts omit it. MySQL password authentication requires TLS.

`executables.sql_gateway` identifies the matching gateway artifact in the local
bundle. The installation fingerprints that artifact even while both protocols
are disabled, so enabling a listener does not change its immutable artifact
identity. Listener settings do not grant native, catalog or data access. The
[local database guide](../../../apps/transit-cli/docs/sql.md) describes enrollment,
trust and retained-worker lifecycle. `sql.command_ms` bounds each SQL statement
and defaults to 30 seconds, with a maximum of 270 seconds. A session statement
timeout can further shorten the wait.

`sql.idle_ms` controls idle PostgreSQL/MySQL connections. Its default is `0`,
which keeps an idle connection open. A positive duration enables automatic
closure, up to 4294967295 milliseconds. Existing files with `idle_ms: 30s` still
request a 30-second timeout; set `idle_ms: 0` to disable it. An expired PostgreSQL
connection receives SQLSTATE `57P05`; MySQL receives error `4031` (`HY000`).

`sql.native.session_lease_ms` independently bounds a native HTTP session between
requests or authorized `touch` renewals. It defaults to 30 seconds and permits
1–270000 milliseconds. A native session can survive an HTTP socket closing,
so its lease remains finite. Idle wire connections remain subject to connection
and memory quotas. Incoming partial frames, TLS records, handshakes, execution
and output retain finite deadlines.

## Startup policy

`transit server` initializes a missing or empty installation directory and opens
or resumes an existing installation. `startup.require_existing` defaults to
false. Set it to true after provisioning a managed deployment to refuse a missing
or empty installation, including a missing volume or mistaken path. Its
environment override is `TRANSIT_STARTUP__REQUIRE_EXISTING=true`; changes require
restart and are visible through `SHOW startup.require_existing`.

A populated directory never becomes a new installation because a record or
storage file is missing. Invalid contents, files, symbolic links and incompatible
definitions reject without automatic repair. The [server guide](../../../apps/transit-cli/docs/server.md#first-startup-and-recovery)
describes creation, interrupted setup, storage layout and startup notices.

## Inspect, change and reload

```sql
SHOW ALL;
SHOW ports.gateway;
SHOW query.statement_timeout;
SELECT name, value, configured_value, change, pending_restart
FROM transit_settings() WHERE owner = 'gateway' ORDER BY name;
SELECT transit_reload_conf();
SELECT operation, phase, error_code, error_field
FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 20;
```

`SHOW ALL` returns name, value and description. Exact keys return one value;
unknown keys fail. `transit_settings()` exposes metadata as typed columns.
`source` describes the active value; `configured_source` describes the latest
accepted candidate. `configured_value` can differ from the active `value` when
restart is pending. File/environment names and block-YAML source coordinates
require provenance permission. JSON flow input has no per-key coordinates.
Secret-valued descriptors are redacted for every caller.

The metadata relations support Fuze column projection, typed predicates and
LIMIT. ORDER BY accepts one column with optional ASC/DESC. Ordered reload history
requires an explicit LIMIT of at most 256. History is read in pages of eight,
with a 10,000-page work budget; a changed revision requires starting a new read.
There are no joins, arbitrary expressions or aggregate calls over these relations.
Read metadata through the configured endpoint; it does not imply a realm-wide
configuration catalog.

Reload is a standalone statement, including when prepared by a database driver.
Preparation does not dispatch it. It returns an operation ID; inspect history for
its outcome. Validation failures retain an operation and return an error without
changing active values. Reusing an exact saved operation returns its retained
outcome. The Transit console waits for the original reload and reports its completion,
partial application or unconfirmed outcome without selecting a new source.
An unresolved reload prevents a new console mutation. A timeout or lost reply
does not prove that reload failed.

`gateway_allowed_hosts` changes on reload. Query defaults change for new
sessions. Ports, executable paths, Board configuration and application management
configuration require a normal server restart; reload reports them as pending.
Version, installation directory, realm and native admission/control quotas are
initialization-only. Startup retains executable compatibility checks. Reload
never restores revoked grants or activates database listeners.

The console uses the installation's recorded active endpoint, so a pending port
edit does not redirect it. If malformed configuration prevents finding a custom
installation, use an existing explicit console connection file. A conventional
`.transit` installation remains discoverable without parsing the bad candidate.

## Session settings and catalog discovery

```sql
SET query.statement_timeout = '2s';
RESET query.statement_timeout;
RESET ALL;
SHOW DATABASES;
SHOW SCHEMAS;
SHOW TABLES;
```

Wire sessions capture their default timeout and administrator ceiling when opened. The console captures them on its first SQL statement, keeping local help available without a connection.
Zero means no additional statement deadline; a nonzero ceiling disallows zero
and larger values. The setting is limited to 24 hours. SET changes only the
current session; RESET restores its captured default. Metadata includes
`session_generation` to distinguish captured defaults from a later host
configuration. Existing protocol, request, work and output budgets still apply.
Statement expiry ends the local wait, joins local work and preserves accepted
mutation/reload identity for recovery; it does not undo accepted work.

`SHOW DATABASES` lists authorized configured database bindings. The local console
has one selected database. `SHOW SCHEMAS` lists visible schemas in that database;
`SHOW TABLES` uses the selected Table catalog. The existing single-source query
profile retains its scoped Table listing. Each page uses current authorization.

PostgreSQL and MySQL retain their fixed encoding and autocommit settings. A wire
gateway needs an explicit `settings` service binding for host settings and
reload; its authenticated account and selected role remain the caller. Board,
Flight and query-only SDK methods do not acquire an administrative route.
With that binding configured, accounts need configuration inspection permission
to capture defaults and ceilings at login. Denial or an unavailable settings
owner fails login rather than substituting unrestricted defaults. The local
console makes this check on its first SQL statement.

## Permissions and diagnostics

The installation's registered configuration domain has three independent
privileges: inspection (bit 1), protected provenance (bit 2) and reload (bit 4).
The initial local owner owns this object; normal starts never restore grants.
Use the existing [authorization administration](../../../packages/zig/transit-client/docs/authorization.md)
workflow to prepare/apply native domain grants or revocations. The explicit
management binding names the domain object. No new GRANT/REVOKE configuration
syntax or CLI command is introduced.

A caller with inspection alone sees values and their source classes, without
file/environment names or historical error coordinates. Reload permission
allows that caller to receive sanitized coordinates for its own validation
failure; values and unknown field names are omitted. Historical coordinates
require provenance. Registered sensitive values are always redacted.

Artifact paths can change only to executables matching the installation's
recorded hashes. Reload validates them before accepting the candidate; a mismatch
rejects the candidate. Startup preserves the same identity protection. Storage
errors never initialize or clear the installation. A completed installation
requires its retained configuration checkpoint before any child starts; missing
state is not replaced with defaults. Keep the checkpoint and history together
when restoring a trusted local backup.


## Immutable storage

`storage.limits.bytes`, `storage.limits.control_bytes` and
`storage.limits.candidate_bytes` configure ordinary allocation quota, separate
control/collection reserve and the private candidate buffer. Defaults are 8 GiB,
64 MiB and 8 MiB. Byte quantities accept the same units as other byte settings.
Changes require restart. `SHOW storage.limits.bytes` reports the configured quota,
not current filesystem usage.

`storage.maintenance.flush.enabled` enables automatic local Table flushing and
defaults to true in `transit server`. A bare node defaults it to false and
requires both a configured Table host and maintenance principal when enabled.
The other flush settings are:

| Setting suffix | Default | Valid range | Meaning |
| --- | --- | --- | --- |
| `rows` | 256 | 1–1,024 | Current WAL row threshold |
| `work_rows` | 32 | 1–1,024 | Maximum current WAL rows relocated per turn |
| `bytes` | 256 KiB | 1–9,007,199,254,740,991 bytes | Encoded current WAL row threshold |
| `age_ms` | 5,000 ms | 1–60,000 ms | Maximum known pending age before eligibility |
| `resident_bytes` | 128 MiB | 32–512 MiB | Aggregate private Table maintenance workspace |

These settings use the `storage.maintenance.flush.` prefix and require restart.
Either row/byte threshold or age makes a Table eligible. The owner keeps at most
64 volatile age hints; unknown ages after restart or eviction are immediately
eligible. A prior empty observation conservatively bounds when rows became
pending. Age controls eligibility, not a completion deadline under competing
Tables or unavailable storage. One executor alternates lifecycle work and
physical work, visiting one persisted object entry per Table turn. A fixed pass
boundary prevents new high-ID Tables from extending the pass indefinitely.

The private workspace includes catalog/Table owners, read caches, index staging
and encoding. Native authority caches and bounded backend I/O buffers retain
their separate limits. The node's maintenance operation deadline bounds each
turn. Timeout, revocation, allocation budget or disk quota refusal leaves accepted
rows recoverable; subsequent turns advance through the other Tables. No flush
setting expires history, releases a read pin or grants a privilege.

All allocations use ordinary capacity when available. Eligible control and
collection work can use the separate reserve when ordinary capacity is exhausted;
routine eligible turns do not consume the reserve while they fit the ordinary
budget. Each reservation records which budget owns its bytes until collection
releases them. Neither quota pressure nor reserve exhaustion expires data.

The existing maintenance process begins another physical pass after
`storage.maintenance.collection_every_records` allocation-ledger records
(default 1,024). `storage.maintenance.compact` enables bounded relocation before
collection and defaults to false. Retention remains independent: unlimited
history keeps its original roots, even after compaction. See
[storage](storage.md#failure-and-maintenance) for ownership, recovery and the
separate provider/disk costs excluded from these allocation counters.

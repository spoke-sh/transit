# Database protocol checks

Read the [protocol reference](../../../docs/handbook/reference/database-protocols.md),
[gateway contract](../../../contracts/SQL_GATEWAY_V1.md) and
[contribution instructions](AGENTS.md).

| Responsibility | Driver |
| --- | --- |
| Wire contract and logical values | [contracts.py](contracts.py), [values.py](values.py), [schema.py](schema.py) |
| Installed gateway and independent clients | [gateway.py](gateway.py), [clients.py](clients.py), [psql.py](psql.py) |
| Scalar parity, aliases and admission | [Independent corpus](type_cases.py), [driver matrix](types.py), [inventory and negative controls](type_inventory.py), [installed smoke](../installation/server_sql_types.py) |
| Authorization, lifecycle and lost replies | [authority.py](authority.py), [lifecycle.py](lifecycle.py), [faults.py](faults.py) |
| TLS and connection settings | [tls.py](tls.py), [settings.py](settings.py) |
| Explicit reference deployment | [reference.py](reference.py) |
| Phase and transport measurements | [measure.py](measure.py), [phases.py](phases.py), [costs.py](costs.py) |

Run the owning `just test::sql-wire-*` task with pinned clients; recipes identify
the `sql-wire` shell and native binary inputs. Protocol acceptance and performance
measurements have separate expectations. Reference deployment requires its own
available infrastructure and cannot be inferred from local gateway checks.

For scalar changes, run `just test::sql-wire-contracts`, then
`just test::sql-wire-types` and `just test::server-sql-types`. The `types` slice
checks all declared scalar aliases using psycopg text/binary and mysql-connector
text/prepared paths, empty metadata, NULLs, exact decimals, numeric failures and
unsupported DDL without durable acceptance. Pinned libpq/libmysqlclient additionally
check INT/REAL/DECIMAL prepared metadata and exact values. `all` runs this slice
with fresh state after its existing fault and CLI schedules.

The installed smoke copies one ReleaseSafe executable outside the checkout and
uses the native console plus real psql/mysql clients. It checks the employees
declaration, 3-by-3 cross-interface CRUD, 0/1/32/33/65 rows, scalar boundaries,
unsupported declarations/projections and exact values after a disk restart.
The no-primary-key employees rowset is compared as a complete multiset; the
fixture does not invent ORDER BY support. Each invocation retains a distinct
sanitized `.cache/sql-types/smoke-*.json` manifest with source, binary digest,
client versions, definition, expected/executed cases and terminal completion.
CI and release run it serially after the console latency measurement, before
dependent qualification, using the same optimized binary. Missing clients or
incomplete cases fail. Fast inventory checks classify every native logical kind
and SQL scalar alias, so a new type requires a reviewed interface disposition.

The gateway `cli` and `all` slices run `psql.py` with the pinned psql 18 client.
It checks catalog pagination and ordering, literal/wildcard and quoted Unicode
names, multi-batch Table descriptions and primary keys, unsupported-query refusal,
absence of durable inspection operations and selected-role revocation while a
metadata portal is suspended. Production query templates are not its oracle.

`just test::sql-wire-contracts` includes the pure PostgreSQL/MySQL continuation
checks and the host-owned session engines. The framing schedules split at every
byte boundary, retain coalesced tails, reject sequence/length errors before body
capacity, and refuse truncated input. Host checks cover borrowed-frame reuse,
allocation failure cleanup and 100 alternating large/small frames with the input
allocator sealed after warmup. This counts framing allocations only, not SQL
execution, TLS or result encoding.

The installed gateway fixture joins its processes before retaining a failed
installation privately at its original `/var/tmp` path. It preserves durable
state, configuration and copies of the supplied executables with source and
binary identities. Inspect original operations there without resubmitting SQL;
these private files contain fixture credentials and are not CI upload artifacts.
Successful installations are removed after cleanup.

`just test::sql-wire-tls` also admits a fixed 16 MiB OpenSSL reserve and four
I/O workers before creating the TLS context. A sealed backing allocator covers
100 successive connections per database upgrade, alternating TLS 1.2/1.3 with
independent exact-payload checks. Every successful exchange expires the deadline
after consuming one plaintext byte, rejects a buffered read and a write, then
restores the test deadline and verifies the complete original echo. This pins
both unread plaintext and the TLS output sequence without sleeping or retransmitting.
Unit checks cover exhausted reallocations,
concurrent borrowers, erased releases and one cleanup callback per distinct
worker before its foreign memory owner is freed. These checks cover the named
reserves; they do not count unrelated gateway, libc or OS allocation paths.

The reference task prints sanitized observations for its actual run. Its
[earlier saved transcript](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/sql_wire/reference-transcript.json)
is a historical observation, not an executable input or current passing result.

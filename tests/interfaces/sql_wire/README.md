# Database protocol checks

Read the [protocol reference](../../../docs/handbook/reference/database-protocols.md),
[gateway contract](../../../contracts/SQL_GATEWAY_V1.md) and
[contribution instructions](AGENTS.md).

| Responsibility | Driver |
| --- | --- |
| Wire contract and logical values | [contracts.py](contracts.py), [values.py](values.py), [schema.py](schema.py) |
| Installed gateway and independent clients | [gateway.py](gateway.py), [clients.py](clients.py) |
| Authorization, lifecycle and lost replies | [authority.py](authority.py), [lifecycle.py](lifecycle.py), [faults.py](faults.py) |
| TLS and connection settings | [tls.py](tls.py), [settings.py](settings.py) |
| Explicit reference deployment | [reference.py](reference.py) |
| Phase and transport measurements | [measure.py](measure.py), [phases.py](phases.py), [costs.py](costs.py) |

Run the owning `just test::sql-wire-*` task with pinned clients; recipes identify
the `sql-wire` shell and native binary inputs. Protocol acceptance and performance
measurements have separate expectations. Reference deployment requires its own
available infrastructure and cannot be inferred from local gateway checks.

`just test::sql-wire-tls` also admits a fixed 16 MiB OpenSSL reserve and four
I/O workers before creating the TLS context. A sealed backing allocator covers
100 successive connections per database upgrade, alternating TLS 1.2/1.3 with
independent exact-payload checks. Unit checks cover exhausted reallocations,
concurrent borrowers, erased releases and one cleanup callback per distinct
worker before its foreign memory owner is freed. These checks cover the named
reserves; they do not count unrelated gateway, libc or OS allocation paths.

The reference task prints sanitized observations for its actual run. Its
[earlier saved transcript](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/sql_wire/reference-transcript.json)
is a historical observation, not an executable input or current passing result.

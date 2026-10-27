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
| Explicit reference deployment | [reference.py](reference.py), [reference input](reference-transcript.json) |
| Phase and transport measurements | [measure.py](measure.py), [phases.py](phases.py), [costs.py](costs.py) |

Run the owning `just test::sql-wire-*` task with pinned clients; recipes identify
the `sql-wire` shell and native binary inputs. Protocol acceptance and performance
measurements have separate expectations. Reference deployment requires its own
available infrastructure and cannot be inferred from local gateway checks.

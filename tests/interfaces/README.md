# Public interface checks

These suites exercise how callers declare, inspect and control Transit through
public interfaces. Domain fixtures own catalog, query, storage and application
semantics; these drivers add protocol, presentation and installation boundaries.

| Interface | Entry points |
| --- | --- |
| Native protocol, schemas and signed fixtures | [native/](native/), [fixture validator](native/native_fixtures.py) |
| Read-only inspection and telemetry | [inspection/](inspection/), [original-request retry controls](inspection/inspection_retry_test.py), [Board](board/) |
| CLI diagnostics and interactive console | [cli/](cli/), [console](cli/console.py), [diagnostic inventory](cli/diagnostic_inventory.py) |
| Isolated application tests | [Offline CLI and installed SQL oracle](cli/application_test.py), [real local authority and failure schedules](cli/application_test_host.zig) |
| Application source builds | [Locked offline modules, source-free SQL, restart and revocation](cli/application_build.py) |
| Native operation-driver composition | [Private driver](cli/operations/main.zig), [shared module imports](../../build/README.md) |
| SQL sessions and PostgreSQL/MySQL protocols | [Session checks](sql_sessions/README.md), [wire checks](sql_wire/README.md) |
| HTTP serving and reactive sessions | [http/](http/), [reactive/](reactive/) |
| Declarative browser providers, sessions and publications | [Real listener and provider peers](http/declarative_browser.py), [buffered-read fault host](http/browser_fault_host.zig), [generated contract check](http/browser_contract.py), [runnable example](../../examples/declarative-browser/README.md) |
| gRPC and Arrow Flight | [grpc/](grpc/), [Flight guide](flight/README.md) |
| Installed server lifecycle and configuration | [installation/](installation/), [server schedule](installation/server.py), [filesystem publication and EFS acceptance](installation/filesystems.md), [data workbench](installation/board_workbench.py), [retained-history recovery controls](installation/board_history_test.py), [shared process/setup mechanics](../harness/local_installation.py) |
| Installed scalar parity | [Console/psql/mysql smoke](installation/server_sql_types.py), [shared corpus and deeper driver loop](sql_wire/README.md) |
| Installed SOURCE declarations | [Native publication, scoped inspection, original recovery, retirement and zero-dispatch proof](installation/server_sources.py) |
| Installed webhook/Dataflow/HTTP journey | [Application adapter](installation/webhook.py), [scenario runner and limits](../performance/load/scenarios.md) |
| Launchers and reference deployment | [deployment/](deployment/), [launcher tasks](../../tasks/launchers.just) |

The [test task module](../../tasks/test.just) supplies required binaries and
environments. Use `python3 -B tests/runner/launch.py tests/interfaces/AREA/DRIVER.py`
for repository Python entry points. [Execution inventory](../runner/suite.json)
distinguishes ordinary, browser and external-provider requirements; a contract
validator does not qualify a live session or deployment.

Read the [contribution rules](AGENTS.md) and the owning public contract before
changing expectations. Browser checks use Board's task module; independent SQL
clients use the pinned `sql-wire` shell. Failed, canceled or unavailable profiles
remain incomplete in automatic runner output.

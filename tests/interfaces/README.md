# Public interface checks

These suites exercise how callers declare, inspect and control Transit through
public interfaces. Domain fixtures own catalog, query, storage and application
semantics; these drivers add protocol, presentation and installation boundaries.

| Interface | Entry points |
| --- | --- |
| Native protocol, schemas and signed fixtures | [native/](native/), [fixture validator](native/native_fixtures.py) |
| Read-only inspection and telemetry | [inspection/](inspection/), [Board](board/) |
| CLI diagnostics and interactive console | [cli/](cli/), [console](cli/console.py), [diagnostic inventory](cli/diagnostic_inventory.py) |
| Native operation-driver composition | [Private driver](cli/operations/main.zig), [shared module imports](../../build/README.md) |
| SQL sessions and PostgreSQL/MySQL protocols | [Session checks](sql_sessions/README.md), [wire checks](sql_wire/README.md) |
| HTTP serving and reactive sessions | [http/](http/), [reactive/](reactive/) |
| Declarative browser providers, sessions and publications | [Real listener and provider peers](http/declarative_browser.py), [buffered-read fault host](http/browser_fault_host.zig), [generated contract check](http/browser_contract.py), [runnable example](../../examples/declarative-browser/README.md) |
| gRPC and Arrow Flight | [grpc/](grpc/), [Flight guide](flight/README.md) |
| Installed server lifecycle and configuration | [installation/](installation/), [server schedule](installation/server.py), [data workbench](installation/board_workbench.py), [shared process/setup mechanics](../harness/local_installation.py) |
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

# Shared test harness

Use this directory for reusable process and transport mechanics. Keep semantic
assertions in domain scenarios and provider setup in explicitly named fixtures.

| Owner | Responsibility |
| --- | --- |
| [services.py](services.py) | Loopback port selection and bounded HTTP readiness while observing the owned process |
| [ursula.py](ursula.py) | Isolated disk-backed Ursula configuration, startup, SIGKILL/restart and joined cleanup |
| [test_services.py](test_services.py) | Real HTTP readiness/retry, early process exit and deadline controls |

Test drivers on the `tests/` import path use `harness.services` for generic
helpers. Select `harness.ursula.Fixture` only when the scenario requires Ursula.
The [storage conformance driver](../storage.py) owns its disk recovery schedules;
the [direct Table driver](../direct_table_service.py) owns local Table scenarios.
Sharing port/readiness helpers does not give either driver the other's backend
or durability claim.

`free_port()` finds an available loopback port and closes the temporary socket;
it does not reserve that port until a service binds it. `wait_ready()` requires
HTTP 200, observes early process exit, uses a 30-second deadline and bounds each
request to 0.5 seconds. Callers own process termination and joining, including
startup failure. Readiness does not establish durable acceptance or recovery.

Run `python3 -B tests/harness/test_services.py` inside `nix develop`; the fast
check includes these controls. Fixture changes also require the affected real
backend schedules, such as `just test::storage` and
`just test::direct-table-service`. Preserve physical-disk and process-death
qualification separately from model exploration and fake transports.

[Process helpers](processes.py) discover Linux children and join owned processes
with a finite deadline. [Process controls](test_processes.py) check live-child
refusal and reaping a grandchild after its manager is killed. Domain fixtures
retain startup, activation and recovery assertions.

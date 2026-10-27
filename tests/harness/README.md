# Shared test harness

Use this directory for reusable process and transport mechanics. Keep semantic
assertions in domain scenarios and provider setup in explicitly named fixtures.

| Owner | Responsibility |
| --- | --- |
| [services.py](services.py) | Loopback port selection and bounded HTTP readiness while observing the owned process |
| [ursula.py](ursula.py) | Isolated disk-backed Ursula configuration, startup, SIGKILL/restart and joined cleanup |
| [test_services.py](test_services.py) | Real HTTP readiness/retry, early process exit and deadline controls |
| [abi_support.py](abi_support.py) | Generated native ABI dispatch, bounded handle ownership and exact saved bytes for cross-component fixtures |
| [operation_helpers.py](operation_helpers.py) | Explicit private operation-driver location; never substitute the installed CLI |
| [recovery_fixture.py](recovery_fixture.py) | Preserve owned failed state after joining its supplied provider fixtures |
| [local_installation.py](local_installation.py) | Private native-local installation configuration, frozen executable copies, manager startup and joined cleanup |
| [test_local_installation.py](test_local_installation.py) | Real child startup/exit, private state, restart and immutable executable-copy controls |
| [native_artifacts.py](native_artifacts.py) | Resolve complete native client/authority sets through Zig's build cache, with source, profile, target, definition and output identities |
| [test_native_artifacts.py](test_native_artifacts.py) | Reject changed source, wrong profiles/definitions and failed or partial native publications |
| [operations/RecoveryFiles.zig](operations/RecoveryFiles.zig) | Private recovery-file I/O for domain-owned native operation scenarios |

Test drivers on the `tests/` import path use `harness.services` for generic
helpers. Select `harness.ursula.Fixture` only when the scenario requires Ursula.
The [storage conformance driver](../storage/providers/storage.py) owns its disk recovery schedules;
the [direct Table driver](../storage/tables/direct_table_service.py) owns local Table scenarios.
Sharing port/readiness helpers does not give either driver the other's backend
or durability claim.

The installed [server fixture](../interfaces/installation/server.py) extends the
local installation mechanics with assertions about readiness, renewed activation,
current authorization and SQL outcomes. The harness does not decide those
outcomes or share a mutable installation between independent scenarios. A caller
owns whether successful state is removed or failed state retained after cleanup.

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

The [external fault profile guide](fault-profiles.md) describes owned physical
process and transport experiments, their prerequisites, deadlines and limits.
It distinguishes those schedules from deterministic implementation simulation.

[HTTP attempt instrumentation](http_probe.py) records bounded counts and timings
for owned transport fixtures. Its [controls](test_http_probe.py) check actual
connection reuse and completion accounting. Instrumented timing is a distinct
profile; the proxy keeps credentials and payloads out of retained events.

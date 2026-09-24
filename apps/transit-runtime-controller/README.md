# transit-runtime-controller

Reconciles a Transit PID's durable execution intent with Substrate. It composes
[transit-client](../../packages/zig/transit-client/README.md) and
[transit-runtime-substrate](../../packages/zig/transit-runtime-substrate/README.md).
Substrate places sandboxes; Transit grants execution authority. A running Actor
or pod never grants ownership by itself.

## Build and configure

From the repository root in `nix develop`:

```sh
just build::debug apps
zig-out/bin/transit-runtime-controller CONFIG.json
zig-out/bin/transit-runtime-controller CONFIG.json --once
```

The [reference runbook](../../deploy/reference/README.md) provisions a complete
working configuration. [main.zig](main.zig) defines these top-level JSON fields:

| Field | Meaning |
| --- | --- |
| `url`, `realm` | Transit authority endpoint and realm |
| `principal`, `seed_file` | Controller principal and private signing-seed file |
| `pid` | Single PID managed by this controller |
| `worker` | Separately provisioned worker principal to activate |
| `provider` | [Substrate adapter configuration](../../packages/zig/transit-runtime-substrate/README.md#configuration) |

The controller needs PID-scoped `admin` and `inspect`. A root operator first
establishes the worker's PID-scoped `execute`/`inspect` grant. Provider credentials
remain in the controller environment, outside worker sandboxes and stream history.

## Reconciliation and scaling

Each scan advances at most one step; continuous mode scans at one-second
intervals, including after a recoverable error. `--once` runs one scan and prints
the resulting step. It is useful for fault injection and deliberate reconciliation,
not a command to complete an entire activation synchronously.

The sequence records intent (fencing the old owner), creates or rediscovers the
Actor, establishes egress policy, resumes it, records readiness, then verifies
public worker bootstrap evidence before atomically rotating key and generation.
A lost provider receipt is reconciled against the same scoped resource.
Backlog scanning recovers missed wakeups. Worker loss preserves PID/Actor while
creating a fresh activation; blocked failure or retirement drives shutdown.

Current scope is one configured PID per controller process and one PID per Actor.
There is no shared controller pool or multiplexing implementation. Distinct
controllers need coordinated principal sequences; adding replicas cannot safely
create independent writers under the same signing principal. A previously bound
Actor disappearing fails closed rather than recreating its name.

The [runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) specifies the
complete ordering, identity checks, snapshot assumptions, and unsupported cases.
The adapter README owns provider-specific behavior.

## Verification

`just launchers::reference::test` interrupts the actual controller after Actor creation,
kills a worker, and checks recovery, fresh ownership, and blocked/retired shutdown.
Unit and storage proofs cover the underlying binding protocol separately.
See [test coverage](../../tests/README.md) for evidence and limits.

## Service diagnostics

`LOG_LEVEL` / `LOG_FORMAT` configure the shared
[bounded telemetry runtime](../../packages/zig/telemetry/README.md). Reconciliation
emits `transit.runtime.step` with the current PID, generation and binding revision
when observed. Progress is info, idle is debug, and failures are warnings.
Provider invocations and public client requests have separate related spans;
provider arguments, raw stdout/stderr and credentials are never logged.
Continuous diagnostics go to stderr. `--once` keeps its single disposition on
stdout. Provider progress is not proof of Transit ownership or remote cancellation.

## Workload updates

`transit-runtime-controller CONFIG --check` validates provider trust/template
configuration, current Transit read access and any existing binding's identity.
It performs no protocol or provider mutations. The chart uses it for readiness;
a running container alone cannot establish that its provider client works.
Readiness remains an observation, not a grant of execution authority.

The controller reconciles a recorded `runtime_upgrade`; it never infers upgrade
authority from a changed configuration. Set the target provider template/UID/image
and `previous_workload: {template, template_uid, image}` while that transition is
pending. A switched Actor remains stopped until an operator records running
intent. See the [runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md#same-pid-workload-changes).

`just test::runtime-upgrade` checks the real node/controller with a faultable CLI
boundary: stale controller, wrong Actor UID, lost switch response and idempotent
readback. It complements, rather than substitutes for, the real Substrate proof.

M8 initialization and suspension phases also stop activation. A recorded retry or
resume requires a confirmed stopped binding, then records a fresh running intent
for this controller to reconcile. See [lifecycle controls](../../contracts/LIFECYCLE_V1.md).

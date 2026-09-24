# Launchers

Launchers give humans and agents a system they can run, inspect, stop, and return
to. `just launchers` lists the environments; `just launchers::local` lists one
environment's tasks. Use double colons between task groups.

| Environment | Purpose | Services and limits |
| --- | --- | --- |
| `local` | Fast iteration without Docker or Kubernetes | Native disk Ursula, Transit node, maintenance, counter example and embedded Board, managed by Process Compose |
| `compose` | Check container packaging, mounts, service discovery and restart | The same scenario in Docker Compose; official pinned Ursula image and static Zig images |
| `reference` | Qualify the deployment target | Kubernetes/Substrate, real provider controller, gVisor workers and recovery/isolation proofs; [reference runbook](../deploy/reference/README.md) |

Local and Compose are persistent development installations, with separate data
and realms. Moving between them means running the same scenario against another
environment; copying a live realm or migrating storage is not implemented.
The reference remains an owned cluster **proof harness**: `up` provisions
infrastructure, `images` builds runtime artifacts, and `test` exercises the
workload. It is not yet a persistent reference application launcher.

## Start locally

From the repository root:

```sh
nix develop
just board::install
just launchers::local::up
just launchers::local::status
just launchers::local::inspect
```

Open the printed Board URL (by default `http://127.0.0.1:18102`). Read the
printed access-key **file** locally and paste its contents into Board's sign-in
form. The launcher never prints credentials or puts them in URLs. Board remains
inspection-only; development inputs go through the separately privileged
launcher CLI, not through Board.

`up` builds the native binaries, provisions the installation on first use, and
starts services in the background. Closing the terminal leaves them running.
The counter receives `7` and `5` once, reaches state `12`, then waits for input.
Native processes are managed by the Nix-pinned
[Process Compose](https://f1bonacc1.github.io/process-compose/), using a private
Unix socket; its control API is not exposed on a TCP listener.

```sh
just launchers::local::send 3 my-input
just launchers::local::inspect
just launchers::local::logs counter
just launchers::local::restart counter
just launchers::local::attach
just launchers::local::down
just launchers::local::up
```

`send` reports durable admission, not turn completion. Repeating the same input
and request ID returns the same receipt. Reusing the ID with different content
fails. Omitting the ID generates and prints one before submission; save it to
retry an uncertain result. `inspect` reads through Board's authenticated API;
the UI also shows the current state and retained history.

`attach` opens Process Compose's service/log TUI; use its detach action to leave
services running. Stopping the project there has the same data semantics as
`down`. Use the launcher tasks for replacement so the counter gets a fresh key
and ownership generation. A running OS process or container is not proof of
current Transit permission or progress.

## Use Compose

Install/run Docker Engine or Docker Desktop with the Compose v2 plugin. The
Nix shell supplies build tools, not a Docker daemon. Then:

```sh
just launchers::compose::up
just launchers::compose::status
just launchers::compose::send 3 my-input
just launchers::compose::inspect
just launchers::compose::logs board
just launchers::compose::restart counter
just launchers::compose::down
```

Board defaults to `http://127.0.0.1:18202`. Provisioning uses host-side `rey-cli`
and explicit initialization; runtime containers contain Zig binaries and the
upstream Ursula image, with no Node.js or Python application runtime. The
launcher builds static Linux binaries for the Docker engine architecture.
The official Ursula digest comes from the same
[version pins](../deploy/reference/versions.json) as the reference deployment.

Generated `compose.json` is a Docker Compose document (JSON is accepted as YAML).
The printed state directory contains it, the service configurations, and disk
WAL. Project names are unique and persisted. Containers run with the invoking
user's numeric UID/GID so private bind mounts remain owner-readable. Rey
containers have read-only root filesystems, dropped capabilities, and only their
own configuration/credential mounts. The root signing seed is never mounted.

Storage and client services use separate bridge networks. Published Ursula,
Transit and Board ports bind to host loopback. These are **trusted development
workloads**, with ordinary Docker egress; network segmentation is not the
reference sandbox or a hostile-workload isolation proof. Docker's internal-only
networks did not support the required host port publication in our tested setup,
so the launcher uses regular bridges explicitly.

## Lifecycle and ownership

| Task | Local and Compose behavior |
| --- | --- |
| `up` | Create an installation once, or recover its saved history; fail if it is already running or resources need cleanup |
| `status` | JSON endpoints, realm/PID, state path and manager/container observations; these observations do not grant authority |
| `endpoints` | JSON URLs and credential-file location, without secrets |
| `inspect` | Authenticated current Board discovery; unavailable/denied reads fail |
| `logs SERVICE` | Recent service output; native files survive `down`, container logs disappear when Compose removes containers |
| `restart SERVICE` | Replace that service; replacing `counter` rotates credentials and records fresh ownership for the same PID |
| `down` | Stop owned services; preserve WAL, configuration, keys, PID and admitted work |
| `reset` | Delete that stopped installation's data and keys permanently; refuses while managed resources exist |
| `test` | Create an isolated installation and prove recovery, retry and refusal behavior |

State lives under ignored `.cache/launchers/PROFILE/NAME/`, with private directory
and key permissions. A missing established WAL is an error, not permission to
bootstrap. Initialization is explicit and recorded outside the WAL, while Transit
validates the expected genesis. Setup persists requests before submission and
retries their exact identity after a lost response. The operator files contain
retry material, not an alternative execution history. Losing them requires
operator recovery; deleting them is not a way to recreate a live installation.

The default process and history have unlimited retention. Stopping services does
not retire a PID or opt into history deletion. `reset` destroys a disposable
development installation; it is not Transit's retention mechanism. Do not use
these launchers with production data or restore rolled-back directories as live
authority. Failed starts preserve state and logs for inspection; run `down` before
trying `up` again. No launcher kills arbitrary processes to free a port.

The counter has PID-scoped execute/inspect permission. Board has a separate
realm-wide inspection-only principal, and maintenance has its separate
admin/effect principal. The host provisioner retains the root seed and serializes
its signed operations. Do not concurrently issue unrelated commands with that
root identity. Native programs run as your user and share that user's filesystem
and network access: their credential files are not a sandbox boundary.

Local and Compose use direct, recorded `own` operations for the example caller;
the process has **no provider binding**. They do not run
`transit-runtime-controller`, fabricate Substrate observations, or implement a
local Station supervisor. The reference runs the real Substrate controller.
Protocol legality is common across environments; provider placement, sandboxing,
clock, capacity, and disaster-recovery guarantees still need their own proofs.

## Configuration and implementation

To run another independent installation, set `REY_LAUNCHER_NAME` and
`REY_LAUNCHER_BASE_PORT` before its first `up`, and use that name for subsequent
commands. The three consecutive ports are Ursula, Transit and Board. The name
and ports are persisted; an occupied port fails rather than adopting a service.
The selected checkout must have a path short enough for the local Unix socket.
Linux x86_64 is qualified here; other host/engine combinations remain unverified.

```sh
REY_LAUNCHER_NAME=experiment REY_LAUNCHER_BASE_PORT=18300 just launchers::local::up
REY_LAUNCHER_NAME=experiment just launchers::local::down
```

[main.py](main.py) implements the command boundary;
[common.py](common.py) owns provisioning, private files and exact operator retries;
[local.py](local.py) and [compose.py](compose.py) wire their process managers.
Python is development infrastructure glue; the actual services and caller stay
in Zig. Service config semantics belong to the
[node](../apps/transit-node/README.md), [Board](../apps/board/README.md), and
[counter](../examples/counter/README.md) guides.

Keep defaults and scenario provisioning shared rather than maintaining divergent
demo realms. A second runtime adapter, persistent Substrate application launcher,
hot frontend development proxy, and configurable application catalogs are future
work. The current launcher exercises the kernel and Board before Station lands.

After editing Zig or frontend code, use `just launchers::local::build` then
`just launchers::local::restart SERVICE` to load the new native binary. Compose
`up` builds its images: use Compose `down` followed by `up` for code changes. A plain
container `restart` keeps its existing image. `compose::build` only builds the
host provisioning tools used by `up`; it does not recreate running containers.

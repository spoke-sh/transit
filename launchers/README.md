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
# In another terminal:
just launchers::local::status
just launchers::local::inspect
```

Open the printed Board URL (by default `http://127.0.0.1:18102`). Read the
printed access-key **file** locally and paste its contents into Board's sign-in
form. The launcher never prints credentials or puts them in URLs. Board remains
inspection-only; development inputs go through the separately privileged
launcher CLI, not through Board.

`up` builds the native binaries, provisions the installation on first use, and
stays in the foreground streaming service logs plus manager startup/exit events.
Ctrl-C stops the owned services in dependency order and preserves data and keys;
SIGTERM and terminal hangup also request shutdown. Use another terminal for
inspection and commands, or run `just launchers::local::up --detach` (`-d`) to
start in the background. Detached services remain running when that terminal closes.
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

A service exit remains visible in the foreground even when it produces no stderr.
As with Compose's attached logs, other services keep running so you can inspect
and restart the failed service; there is no automatic restart policy. Startup
failure exits nonzero, and foreground startup cleans up its own manager. Use
`logs SERVICE` for recent output, including manager-generated probe failures,
and `logs manager` for the native manager's persisted lifecycle events. Status
and other control calls use a separate client log so they cannot erase that evidence.

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
This launcher currently starts Compose detached; the foreground default described
above applies to the native local launcher.

Generated `compose.json` is a Docker Compose document (JSON is accepted as YAML).
The printed state directory contains it, the service configurations, and disk
WAL. Project names are unique and persisted. Containers run with the invoking
user's numeric UID/GID so private bind mounts remain owner-readable. Rey
containers have read-only root filesystems, dropped capabilities, and only their
own configuration/credential mounts. The root signing seed is never mounted.

Storage and client services use separate bridge networks. Published Ursula and
Transit ports bind to host loopback. Board defaults to loopback and can be
configured separately for remote development. These are **trusted development
workloads**, with ordinary Docker egress; network segmentation is not the
reference sandbox or a hostile-workload isolation proof. Docker's internal-only
networks did not support the required host port publication in our tested setup,
so the launcher uses regular bridges explicitly.

## Lifecycle and ownership

| Task | Local and Compose behavior |
| --- | --- |
| `up` | Create an installation once, or recover its saved history; local streams logs until stopped (`--detach` opts out), Compose starts detached; fail if already running or resources need cleanup |
| `status` | JSON endpoints, realm/PID, state path and manager/container observations; these observations do not grant authority |
| `endpoints` | JSON URLs and credential-file location, without secrets |
| `inspect` | Authenticated current Board discovery; unavailable/denied reads fail |
| `logs SERVICE` | Recent service output; local also accepts `manager` for lifecycle/probe evidence. Native files survive `down`; container logs disappear when Compose removes containers |
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

### Local development configuration

[.envrc](../.envrc) loads an optional, Git-ignored `.env` after entering the Nix
shell. Copy [.env.example](../.env.example) and edit it, then run `direnv allow`
when accepting the changed `.envrc`. Subsequent `.env` changes reload through
direnv. For your browser on another machine:

```dotenv
REY_BOARD_HOST=0.0.0.0
REY_BOARD_PORT=18102
REY_BOARD_PUBLIC_ORIGIN=http://devbox.local:18102
REY_BOARD_ALLOW_INSECURE_HTTP=true
```

| Setting | Meaning |
| --- | --- |
| `REY_BOARD_HOST` | IPv4 bind address; `0.0.0.0` listens on all IPv4 interfaces |
| `REY_BOARD_PORT` | Board listener/published port; independent of Ursula/Transit ports |
| `REY_BOARD_PUBLIC_ORIGIN` | Exact browser URL origin, used for Host/Origin checks and printed links |
| `REY_BOARD_ALLOW_INSECURE_HTTP` | Explicit `true`/`false` development HTTP opt-in; default false |

Apply changed settings with `just launchers::local::down` followed by
`just launchers::local::up`. The same settings work for Compose with its task
group. Stopping and starting preserves realm, PID, mailbox, committed state and
credentials. Settings are saved in the installation; unset variables keep saved
values. Set explicit loopback values and `false` to revert. A running installation
rejects `up` without rewriting its current settings. `restart` uses the saved
configuration; it does not apply `.env` changes.

The bind address and browser origin are distinct: `0.0.0.0` is not a URL host.
Health probes and agent inspection use the listener's local address with the
configured Host header, so the server does not need to resolve the browser's DNS
name or contact a TLS proxy to check its own health. The native manager uses an
exec probe because its pinned HTTP checker cannot override the Host header;
startup waits for the manager's readiness result. Ursula and Transit remain
private. Remote HTTP still requires Board sign-in, but credentials and sessions
are unencrypted; this option is for a trusted development network. Use a trusted
TLS ingress with an `https://` origin for other remote use.

Direnv is optional: exported environment variables or inline assignments work
with `nix develop --command just …` too. `nix develop` by itself does not load
`.env`. These settings apply to the selected launcher; when running local and
Compose simultaneously, give their Board instances distinct ports/origins.

### Service diagnostics

Board logs completed HTTP requests at `info`, including route templates, elapsed
time and local response outcome. Successful health probes and frequent Transit
reads are `debug`. Failures remain visible at normal verbosity. For correlated
Board/client/node/storage detail, set these in `.env` before the next `up`:

```dotenv
REY_BOARD_LOG_LEVEL=debug
REY_NODE_LOG_LEVEL=debug
```

`REY_LOG_LEVEL` and `REY_LOG_FORMAT` set installation-wide defaults. Override
either field per service with `REY_BOARD_LOG_*`, `REY_NODE_LOG_*`,
`REY_MAINTENANCE_LOG_*`, or `REY_COUNTER_LOG_*`. Levels are `debug`, `info`,
`warn`, `error`, and `off`; formats are `text` and `json`. Precedence is the
per-service variable, global variable, saved service value, then the default:
`info` with text locally and JSON in Compose. As with listener settings, `up`
validates and persists these choices; `restart` uses the saved configuration.
The launcher maps them to each executable's `LOG_LEVEL` and `LOG_FORMAT`.
Ursula and the process/container managers keep their upstream logging controls.

Services write diagnostics to stderr; bootstrap and CLI results keep their
machine-readable stdout. The native launcher merges each managed service's
stdout/stderr for display so Process Compose colors the service prefix without
painting all diagnostics red. Severity comes from the service's log fields;
Process Compose's outer stream classification is not severity. Direct binary
and CLI output interfaces keep their separate streams.
The private node accepts validated diagnostic trace
parents so Board calls can be followed across services. Public Board ingress
starts its own context. Neither trace context nor logs grant Transit permission.
See the [signal contract and bounds](../packages/zig/telemetry/README.md) and
[Transit event vocabulary](../packages/zig/transit-observability/README.md).

### Log storage and rotation

Local service files use Process Compose's
[rotation settings](https://github.com/F1bonacc1/process-compose/blob/v1.110.0/www/docs/logging.md):
5 MiB per file, two backups, and a seven-day backup age limit. The separate
`log-retention` process checks `manager.log` and `manager-client.log` every second,
keeping two backups of at most 5 MiB each. It preserves the manager's open file
by copying a bounded tail and truncating in place. The active file can exceed
5 MiB between checks, and writes racing the copy/truncate can be lost. These
are rotation targets, not a hard filesystem quota. No protocol data is removed.

`logs manager` shows current manager output; older files remain in the private
installation directory after `down`. A new start archives the previous manager
log before Process Compose opens it. Rotation failure is visible as a service
exit; inspect `logs log-retention` and use `restart log-retention` after resolving
the cause. Diagnostic retention failure does not stop Transit control work.

Compose configures Docker's `json-file` driver with `max-size=5m` and `max-file=2`
for every service. Logs survive container restart but disappear on Compose
`down`; export any needed diagnostics first. External collectors, crash dumps,
build/test logs and Substrate-owned storage need separate operator policies.
Never publish installation directories containing credentials with diagnostic
reports. These budgets are independent of mailbox/history retention.

### Installation selection

To run another independent installation, set `REY_LAUNCHER_NAME` and
`REY_LAUNCHER_BASE_PORT` before its first `up`, and use that name for subsequent
commands. By default, the three consecutive ports are Ursula, Transit and Board.
The name and internal base port are persisted; use a new name to change the
Ursula/Transit ports. Board's settings can change as described above. An occupied
port fails rather than adopting a service.
The selected checkout must have a path short enough for the local Unix socket.
Linux x86_64 is qualified here; other host/engine combinations remain unverified.

```sh
REY_LAUNCHER_NAME=experiment REY_LAUNCHER_BASE_PORT=18300 just launchers::local::up
REY_LAUNCHER_NAME=experiment just launchers::local::down
```

[main.py](main.py) implements the command boundary;
[settings.py](settings.py) validates Board listener, public-origin and diagnostic settings;
[common.py](common.py) owns provisioning, private files and exact operator retries;
[local.py](local.py) and [compose.py](compose.py) wire their process managers.
[logs.py](logs.py) owns native manager-log rotation.
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

# Launchers

Launchers give humans and agents a system they can run, inspect, stop, and return
to. `just launchers` lists the environments; `just launchers::local` lists one
environment's tasks. Use double colons between task groups.

| Environment | Purpose | Services and limits |
| --- | --- | --- |
| `local` | Fast iteration without Docker or Kubernetes | Native disk Ursula, Transit node, maintenance, delivery courier, selected example and embedded Board, managed by Process Compose |
| `compose` | Check container packaging, mounts, service discovery and restart | The same scenario in Docker Compose; official pinned Ursula image and static Zig images |
| `reference` | Qualify the deployment target | Kubernetes/Substrate, real provider controller, gVisor workers and recovery/isolation proofs; [reference runbook](../deploy/reference/README.md) |

All three profiles have persistent, separate installations. Moving between them
means running the same scenario against another environment; copying a live
realm or migrating storage is not implemented. Reference `up` installs a usable
Transit application, including Board and an in-cluster runtime controller.
Its recovery/isolation tests use separate installations.

The default example is the small counter. Select `--example station` on the
first `up` of a named installation to run the three-process
[Station ledger](../examples/station-ledger/docs/running.md): behaviors with
associated Tables, a requester, scoped registry/supervision, separate framework
controllers, and Board. The choice is persisted; later commands use that same
example. Use a different name to run both, with non-overlapping base ports.
Its checked-in Process Compose and Docker Compose topologies live beside the
example; the reference uses the shared [Transit chart](../charts/transit/README.md).

## Incremental development

The command meanings are shared across all three profiles:

```sh
just launchers::local::build board
just launchers::local::update board --no-build
just launchers::local::update counter
just launchers::local::restart board
# Substitute compose or reference for the same development loop.
```

`build [SERVICE...]` produces candidates without changing running services or
the selected version. `update` builds, applies affected services and verifies
readiness; `--no-build` selects saved candidates. `restart` uses the selected
artifact/configuration. Omit names to select all application services. Node and
maintenance share an executable and update together. Ursula and provider
infrastructure are separately pinned and excluded from application builds.
For Station, `update ledger` updates all three workers because they share one
executable. The two framework controllers also share an artifact. Each reference
worker retains its PID and Actor identity through a separately recorded upgrade.

Native binaries live at identified paths under ignored
`.cache/launcher-artifacts/PROFILE/NAME/`; services no longer execute shared
`zig-out` files. Compose selects image IDs, and reference pushes images and
selects registry digests. Builds use ReleaseSafe, with Zig/Vite+ caching their
source dependencies. Board builds its frontend and embedded API together.
`status` reports candidates, selections, service observations and pending updates.
Build provenance describes the latest candidate build; artifact hashes identify
the actual selected bytes.

Identical artifacts/configuration are a no-op. Build failure leaves live
services alone. A failed deployment keeps `update.json` and its exact target;
retrying `update` resumes that plan, even if newer candidates exist. To deploy a
corrected candidate after failure, use `update SERVICE --replace-pending`.
This archives the previous plan, flushes uncertain signed requests, and refuses
to replace an unresolved recorded template switch. It cannot roll back history.
Restart is refused while an update is pending. Readiness failure remains visible;
there is no automatic image/history rollback.

Updates read supported `.env` settings for the selected roles. Restarts reuse
saved configuration. General topology changes to Process Compose require `down`/`up`.
The coordinated M8 upgrade explicitly replaces a pre-M8 manager to add delivery;
its foreground attachment ends, so use `attach` afterward. Source
watching and frontend HMR remain future work.

The example counter's update contract is `code=1` with the same state encoding.
Updates preserve its PID/state and pending inputs. This is a caller/deployer
compatibility declaration, not proof that arbitrary edited code understands
old state. Retired or blocked processes and changed declared contracts are
rejected; no state conversion is provided.
Local/Compose replace direct owners; reference uses the
[recorded workload upgrade](../contracts/RUNTIME_SUBSTRATE_V1.md#same-pid-workload-changes),
retaining the Actor UID, reconciling a suspended template switch, and activating
a fresh pod/key/generation. Retrying does not redispatch effects.

An existing local/Compose installation from before identified artifacts needs
one `down`/`up` cycle to select binaries and load the new manager configuration.
Its durable data and keys are retained.

Pre-M8 identified installations need a coordinated `update` with no service
names: read envelopes changed and node, callers, Board and the courier must match.
Partial upgrades are refused until delivery is selected. Run this while the
reference installation is running on its previous version; a stopped reference
installation must first be started with that version, because its bound workload
requires the recorded image-upgrade protocol. Stopped local/Compose installations
can run `update` to select compatible artifacts, then `up`. Existing genesis,
state and creation policy stay unchanged; new installations opt into the M8
initialization barrier. Downgrading a realm that accepted M8 commands is unsupported.

## Start locally

From the repository root:

```sh
nix develop
just transit-board::install
just launchers::local::up
# In another terminal:
just launchers::local::status
just launchers::local::inspect
```

Open the printed Board URL (by default `http://127.0.0.1:18102`) directly.
Board has no access key or sign-in; everyone who can reach its private listener
shares the configured inspection scope. Board remains inspection-only; development inputs go through the separately privileged
launcher CLI, not through Board.

`up` builds/selects binaries on first use, recovers saved selections later, and
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
retry an uncertain result. `inspect` reads through Board's read-only API;
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
# In another terminal:
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

`up` stays in the foreground, following Docker Compose service logs and reporting container exits. Startup first brings up Ursula and the node for ordered
provisioning, then attaches to all services as the application containers start.
Earlier startup logs are included; failures before attachment print recent
container logs before cleanup. An individual service exit leaves the others
running for inspection and explicit restart.

Ctrl-C, SIGTERM and terminal hangup stop this invocation's containers and remove
its Compose resources while preserving the installation's WAL, configuration
and keys. A subsequent `up` recovers the same realm. Other terminals can run
`status`, `send`, `restart` or `down` while logs stream. Cleanup checks the installation session so deliberate updates stay attached,
while an old foreground session cannot stop a later `down`/`up` stack. Log
followers reattach to replacement containers.
Use `just launchers::compose::up --detach` (or `-d`) for background use; then
`just launchers::compose::down` stops the installation.

The checked-in [docker-compose.yaml](../docker-compose.yaml) defines the services,
mounts, networks and log budgets. The printed state directory contains saved
interpolation values (`compose.env.json`), service configurations, and disk
WAL. Project names are unique and persisted. Containers run with the invoking
user's numeric UID/GID so private bind mounts remain owner-readable. Transit
containers have read-only root filesystems, dropped capabilities, and only their
own configuration/credential mounts. The root signing seed is never mounted.

Storage and client services use separate bridge networks. Published Ursula and
Transit ports bind to host loopback. Board defaults to loopback and can be
configured separately for remote development. These are **trusted development
workloads**, with ordinary Docker egress; network segmentation is not the
reference sandbox or a hostile-workload isolation proof. Docker's internal-only
networks did not support the required host port publication in our tested setup,
so the launcher uses regular bridges explicitly.

## Run the reference installation

On the supported Linux x86_64 host with Docker:

```sh
just launchers::reference::up
just launchers::reference::status
kubectl transit get installations -A
just launchers::reference::attach
just launchers::reference::update board
just launchers::reference::update counter
just launchers::reference::down
```

`up` reuses the owned Kind/Substrate cluster or creates it when absent, installs
a uniquely named `transit-NAME-ID` namespace and Helm release `transit`, and
returns after Board and the example's activation are ready. Board defaults to
`http://127.0.0.1:18302`. The configured host/port/origin apply to its host forward.
[Process Compose](../deploy/reference/process-compose.yaml) keeps forwards and
remote log followers running; `attach` opens that manager. Kubernetes services
and the controller continue independently of this attachment.

`down` records a stopped runtime intent, waits for Actor suspension, and scales
application services/worker capacity to zero. PVCs, credentials, PID and Actor
remain; `up` recovers them. A missing bound Actor or namespace is an error.
`restart counter` also records suspension and replaces worker capacity before a
fresh activation; it does not select new code. `reset` deletes only this stopped
installation and its provider resources. It is destructive to its data.
Counter logging is part of the immutable Actor template: a later `up` retains
its saved logging and reports any deferred change. Use `update counter` to apply
new settings through the recorded workload transition.

Logical `lifecycle.suspend/resume` is separate from these launcher stop/start
operations. The reference activation profile requires a fresh worker pod after
confirmed suspension. Substrate cold boot can reuse its pod, so placement must
replace prior worker capacity before logical resume; the controller reports
`StaleWorkerIncarnation` otherwise. `restart counter` performs the explicit
capacity replacement. The controller itself does not have pod-deletion rights.

`infra-up` creates only Kind/Substrate; `infra-down` destroys the entire owned
cluster and registry, including every application and proof namespace. The
separate `images`/`test` commands build and run the destructive M1 proof. See the
[reference runbook](../deploy/reference/README.md). Ordinary updates do not rebuild
Kind, Ursula or Substrate. The pinned Substrate worker runtime image is built and
cached once per owned registry/pin.

Provider credentials belong to the in-cluster controller. It has its own
PID-scoped Transit principal, rotating projected provider tokens, namespace-local
worker-log reads and access to public trust roots. It does not mount a personal
kubeconfig. The pinned provider API lacks per-Actor authorization; this remains
a trusted controller boundary. Kind's default CNI does not enforce the chart's
NetworkPolicies. The separate adversarial proof qualifies worker/Board isolation;
this development launcher's Board pod does not imply that proof's additional
network-isolation fixture.

## Lifecycle and ownership

| Task | Shared behavior (foreground attachment differs for reference) |
| --- | --- |
| `up` | Create once or recover saved history/artifacts; local/Compose stream logs (`--detach` opts out), reference returns after readiness |
| `status` | JSON endpoints, realm/PID, state path and manager/container observations; these observations do not grant authority |
| `endpoints` | JSON URLs and listener settings, without secrets |
| `inspect` | Current Board discovery under its Transit read grant; unavailable/denied reads fail |
| `logs SERVICE` | Recent service output; local also accepts `manager` for lifecycle/probe evidence. Native files survive `down`; container logs disappear when Compose removes containers |
| `build [SERVICE...]` | Build candidates without deploying |
| `update [SERVICE...]` | Apply compatible candidates/configuration and verify readiness |
| `restart SERVICE` | Replace the selected version of that service; replacing `counter` rotates credentials and records fresh ownership for the same PID |
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
authority. Foreground startup failures clean up their own services and preserve
state; Compose prints recent container diagnostics before removal. Detached
startup failures can leave resources for inspection; run `down` before trying
`up` again. No launcher kills arbitrary processes to free a port.

The counter has PID-scoped execute/inspect permission. Board has a separate
realm-wide inspection-only principal, and maintenance has its separate
admin/effect principal. Delivery uses principal 5 with delivery/send only and
receives no storage credentials. It runs in every profile, has a signed status
probe, and resumes committed outboxes after restart. The host provisioner retains the root seed and serializes
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

### Checked-in topology

| Environment | Definition | Installation-specific inputs |
| --- | --- | --- |
| Local | [process-compose.yaml](../process-compose.yaml) | Private `process-compose.vars.json` overlay: paths, ports and log settings |
| Compose | [docker-compose.yaml](../docker-compose.yaml) | Private `compose.env.json`: paths, image names, ports, UID/GID and log settings |
| Reference | [charts/transit](../charts/transit/README.md) | Saved Helm values, separately provisioned Secrets and protocol grants; host access uses [Process Compose](../deploy/reference/process-compose.yaml) |

Edit the checked-in files to change service topology, dependencies, probes,
mounts or resource/log limits. Local and Compose `down` followed by `up` load
those definitions with saved installation settings. `restart` replaces a service
using its current manager/container configuration. The local manager is started
in the installation directory, including for probes.

Launchers still provision identity, configuration and durable state through the
public API; these are not safe to express as automatic service restarts. They
generate only environment-specific inputs, not a second copy of the topology.
Use the launcher tasks to supply these inputs and preserve bootstrap/recovery
ordering. Bare `process-compose up` or `docker compose up` is not the provisioning
entry point. Ambient dotenv expansion is disabled in both managers; `.envrc`
loads the supported development settings before the launcher validates them.

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

Apply changed settings with `just launchers::local::update board`, or a
`down`/`up` cycle. The same settings work for Compose and reference with their
task groups. These operations preserve realm, PID, mailbox, committed state and
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
private. Board has no viewer authentication; the network/deployment boundary
controls who can read its inspection data. Remote HTTP sends that data without
encryption; this option is for a trusted development network. Use a trusted
TLS ingress with an `https://` origin for other remote use.

Direnv is optional: exported environment variables or inline assignments work
with `nix develop --command just …` too. `nix develop` by itself does not load
`.env`. These settings apply to the selected launcher; when running local and
Compose simultaneously, give their Board instances distinct ports/origins.

### Service diagnostics

Board logs completed HTTP requests at `info`, including route templates, elapsed
time and local response outcome. Successful health probes and frequent Transit
reads are `debug`. Failures remain visible at normal verbosity. For correlated
Board/client/node/storage detail, set these in `.env` before the next `update`
or `up`:

```dotenv
REY_BOARD_LOG_LEVEL=debug
REY_NODE_LOG_LEVEL=debug
```

Periodic `telemetry.metrics` snapshots are also debug-only. Their outcomes and
duration buckets are named JSON objects; counters still accumulate at every
log level. `telemetry.loss` warnings indicate diagnostic records were dropped
or rate-limited.

`REY_LOG_LEVEL` and `REY_LOG_FORMAT` set installation-wide defaults. Override
either field per service with `REY_BOARD_LOG_*`, `REY_NODE_LOG_*`,
`REY_MAINTENANCE_LOG_*`, `REY_DELIVERY_LOG_*`, `REY_COUNTER_LOG_*`, or reference `REY_CONTROLLER_LOG_*`.
Levels are `debug`, `info`,
`warn`, `error`, and `off`; formats are `text` and `json`. Precedence is the
per-service variable, global variable, saved service value, then the default:
`info` with text locally and JSON in Compose/reference. `update` validates and
persists settings for its selected roles; `up` applies them when starting a
stopped installation. `restart` uses the saved configuration.
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
`down` or foreground shutdown; capture terminal output or export any needed
diagnostics first. External collectors, crash dumps,
build/test logs and Substrate-owned storage need separate operator policies.
Never publish installation directories containing credentials with diagnostic
reports. These budgets are independent of mailbox/history retention.

### Installation selection

To run another independent installation, set `REY_LAUNCHER_NAME` and
`REY_LAUNCHER_BASE_PORT` before its first `up`, and use that name for subsequent
commands. Locally and in Compose, the three consecutive ports are Ursula,
Transit and Board. Reference forwards only Transit and Board on base+1/base+2.
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
[local.py](local.py), [compose.py](compose.py) and [kubernetes.py](kubernetes.py)
wire their managers and providers. [artifacts.py](artifacts.py) stages identified
builds; [updates.py](updates.py) saves and resumes deployment plans.
[logs.py](logs.py) owns native manager-log rotation.
Python is development infrastructure glue; the actual services and caller stay
in Zig. Service config semantics belong to the
[node](../apps/transit-node/README.md), [delivery](../apps/transit-delivery/README.md),
[Board](../apps/transit-board/README.md), and
[counter](../examples/counter/README.md) guides.

Keep defaults and scenario provisioning shared rather than maintaining divergent
demo realms. Other runtime adapters, frontend HMR, automatic source watching,
artifact garbage collection and configurable application catalogs are future
work. The current launcher exercises the kernel and Board before Station lands.

## Example state resources

New installations provision a PID-owned, required KV resource named `counter`
before the first activation. New manifests additionally record `runtime_profile: 1`:
creation declares the required name, provisioning retries exact requests, and an
explicit initialization operation releases the handler barrier. Lifetime and
history retention remain unlimited; launchers do not opt applications into catalog
collection. Manifests predating that profile retain their original creation request.
The caller receives resource inspect/read/write; Board receives metadata inspect
only. The process **State** tab links to its resource, and Board does not decode
the counter value. Operator scripts can use the signed CLI state endpoint to
read the application's `value` key under the root resource grant.

The manifest records `state_profile: 1`; the realm enables the Linux synchronized
clock with a maximum reported error of 10 seconds for bounded read views. An
unsynchronized clock stops view acquisition/commits explicitly. This first
resource-backed launcher profile therefore requires Linux, including for the
native launcher; it does not simulate trusted time on other hosts.

Existing manifests without this field continue using inline state. Updating
binaries does not change genesis, allocate a resource, or migrate old values.
Create a separately named installation to try the resource profile. Direct-owner
replacement reissues resource grants with the fresh key; Substrate activation
rotation preserves the existing resource grants. Compatible upgrades preserve
the resource ID, association, data and pending mailbox under the same PID.

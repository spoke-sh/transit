# kubectl-transit

Zig inspection CLI for Transit installations on Kubernetes. The Nix shell installs
it on PATH, so kubectl discovers it as `kubectl transit`. It delegates Kubernetes
authentication and transport to the pinned `kubectl`; no Transit credentials,
raw Ursula access, or provider execution privileges are required or acquired.
The [full plugin plan](../../docs/roadmap/M5.md) covers future logical
inspection and operator controls. Only its first phase is implemented.

## Use

```sh
nix develop
kubectl transit --help
kubectl transit get installations -A
kubectl transit status --namespace demo --release transit
kubectl transit get workloads --namespace demo --release transit --output json
kubectl transit logs node --namespace demo --release transit --follow --tail 100
kubectl transit board --namespace demo --release transit
kubectl transit board --namespace demo --release transit --port-forward
```

The [project environment](../../nix/README.md#kubernetes-tools) selects the
reference kubeconfig automatically. Reference `up` deploys the persistent Transit
application; `infra-up` creates only provider infrastructure. Transit discovery
lists deployed chart releases. Recovery proofs use separate temporary releases.

Put `--kubeconfig`, `--context`, `--namespace` / `-n`, and plugin options **after
`transit`**. They may precede or follow the subcommand. Namespace defaults to the
selected context; the plugin never changes that context. `-A` is only available
for discovery, and cannot be combined with a namespace. Every installation-specific
command requires `--release`; there is no implicit choice of the first installation.

Use the discovery table's **NAMESPACE** for `--namespace` and **RELEASE** for
`--release`. For example, a row with namespace `transit-sample-abc123` and release
`transit` is selected with:

```sh
kubectl transit get workloads -n transit-sample-abc123 --release transit
```

The namespace suffix `abc123` is not a Helm release name. Discovery with `-A`
does not select a namespace for later commands. An empty targeted result reports
the requested release and namespace scope, with guidance for finding the pair.

## Views and diagnostics

Discovery selects node Deployments with the [chart's](../../charts/transit/README.md)
`app.kubernetes.io/name=transit` and component labels. Release selection adds
`app.kubernetes.io/instance`. Resource names can be overridden in the chart.
These labels are operational associations, never authenticated Transit identities.

`status` reads Deployments, StatefulSets, Jobs, Pods, Services, and PVCs.
`get workloads` limits that list to workload controllers and Pods. Human tables
use aligned spaces rather than terminal tab stops and
identify namespace, release, component, kind, name, and observed readiness or
phase. Replica counts are Kubernetes observations; they do not assert current
ownership, caught-up protocol state, or a healthy end-to-end system. `--output
json` / `-o json` returns Kubernetes' native list unchanged for `get` and `status`.
Empty discovery succeeds; an empty targeted status/view fails. Denied reads and
connection failures preserve kubectl's diagnostic and exit status.

`logs` supports `node`, `board`, `maintenance`, `controller`, `ursula`, and `initialize`.
It prefixes pod/container names, includes all containers, and defaults to 100
lines per container. `--tail` accepts 0–10000; live follow allows at most five
concurrent streams. Kubernetes log rotation and deletion still apply. `controller`
reads the optional in-cluster controller; the isolated recovery proof keeps its
fault-injected controller on the host. Substrate Actor/worker diagnostics remain
available through `kubectl ate`. Service logs are not durable protocol history.

## Board access

`board` reads the labelled ConfigMap's configured `public_origin` and prints it.
It never fetches Secrets, access keys, signing seeds, or service credentials.
Multiple matching configurations/services fail as ambiguous.

`--port-forward` requires a configured `http://127.0.0.1[:PORT]` origin. It finds
the labelled Service's `http` port, honors name overrides, and forwards the exact
origin port on `127.0.0.1`. This needs Kubernetes port-forward RBAC in addition to
read permissions. A port conflict remains a visible kubectl failure. Ctrl-C
closes the foreground tunnel. Existing Board sign-in remains required.

Remote or HTTPS origins must be accessed through their advertised ingress. A TCP
tunnel does not rewrite Host/Origin or terminate TLS; the plugin rejects that
mismatch instead of changing Board configuration or weakening its checks.

## Bounds, permissions and limits

Queries have a 15-second whole-command deadline (`--timeout 1..120`), a 1 MiB
stdout limit and a 32 KiB stderr limit. Exceeding a bound fails without emitting
partial JSON; narrow discovery by namespace/release. The deadline includes
credential helpers and waiting for kubectl to exit. Query failures kill the owned process group and reap kubectl. Interactive credential prompts are unsupported for captured
queries: establish credentials through your normal Kubernetes login first.
Human table fields are limited to 253 printable ASCII bytes; malformed fields
fail before emitting a partial table or terminal control sequences.

Logs and port-forwards replace the plugin process with kubectl, preserving
terminal I/O, signals and exit status without detached tunnels. Their intentional
streams have no total query deadline. Standard Kubernetes RBAC still applies;
no credentials are provisioned by this plugin. It cannot send messages, retire
processes, alter grants, provision a release, or infer logical process state.

## Build and verification

```sh
just build::debug kubectl-transit
zig-out/bin/kubectl-transit get installations -A
just test::kubectl-transit
nix build .#kubectl-transit
```

Root `apps` builds also install the executable. The Nix package builds this
stdlib-only app without fetching the kernel's dependencies. Reenter `nix develop`
after changing its source to refresh the packaged command. With direnv, the
checked-in `.envrc` watches the plugin source and package definition so the
cached shell refreshes when they change; approve `.envrc` changes with
`direnv allow` after reviewing them. The `zig-out` executable is useful during
iteration. No language bindings or protocol dependencies are
introduced for this infrastructure-only slice.

The [offline proof](../../tests/kubectl_transit.py) exercises selection, native
JSON, error propagation, output/deadline bounds, Board origin checks, argument
boundaries and streaming signals. Cluster qualification is separate; see the
[test guide](../../tests/README.md#kubernetes-tooling-qualification).

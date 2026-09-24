# transit-runtime-substrate

Substrate provider adapter, exported as `transit_runtime_substrate`. This Zig
library depends on [transit-observability](../transit-observability/README.md)
for optional instrumentation. It invokes the pinned upstream
`kubectl-ate` CLI for authenticated TLS/gRPC and Kubernetes log access; it does
not grant Transit ownership or implement a second task queue.

The [controller](../../../apps/transit-runtime-controller/README.md) composes
this adapter with the public Transit client. [src/root.zig](src/root.zig) exports
`Adapter`, `Config`, Actor observations, and public bootstrap evidence. Calls use
explicit argument arrays, bounded output (64 KiB stdout / 8 KiB stderr), and a
30-second I/O deadline. Provider errors must not disclose credentials or payloads.

## Configuration

`Config` is the controller's `provider` JSON object:

| Field | Meaning |
| --- | --- |
| `cli` | Pinned `kubectl-ate` executable path |
| `kubeconfig`, `context` | Explicit Kubernetes credentials and context |
| `instance` | Runtime instance UUID encoded as 16 bytes |
| `atespace`, `actor` | Exclusive, never-reused scoped Actor name |
| `template`, `template_uid` | Expected template name and 16-byte incarnation UUID |
| `image` | Immutable workload image reference with `@sha256:` digest |
| `egress_policy_file`, `authority_host` | Default-deny policy and allowed Transit hostname |
| `endpoint`, `token_file` | Optional direct Substrate API endpoint and token file; supply both together |
| `previous_workload` | Optional prior template/UID/image during an authorized same-PID upgrade |

The exact CLI revision is enforced by the adapter and tracked with the
[reference pins](../../../deploy/reference/versions.json). A changed or dirty
CLI build fails validation. The reference resolves the Nix-packaged executable
on PATH and stores its absolute path in controller configuration; interactive
`kubectl ate` uses that same build. Do not infer provider compatibility from CLI
startup.

## Provider mapping and limits

Substrate separates an Actor `(atespace, name)` from its current worker pod.
An atespace is not a Kubernetes namespace; ActorTemplates use Substrate's API.
The binding hashes the scoped resource and template/image identity. Transit
records the provider instance, incarnation, operation, and activation separately.
See the upstream [glossary](https://github.com/agent-substrate/substrate/blob/main/docs/glossary.md),
[architecture](https://github.com/agent-substrate/substrate/blob/main/docs/architecture.md),
and [resource API](https://github.com/agent-substrate/substrate/blob/main/docs/api-guide.md)
for provider terminology; the [runtime profile](../../../contracts/RUNTIME_SUBSTRATE_V1.md)
is the normative integration contract.

Template validation requires one fixed container, DATA snapshots with COLD_BOOT
resumption, and exactly one `runtime-data` durable directory mounted at
`/runtime-data`. Additional/external volumes and FULL memory snapshots are
unsupported. The worker keeps neither signing keys nor execution authority in
that directory. Recover application state from Transit after resumption.

A CRASHED Actor must revert to its last committed snapshot before resume. The
controller records a fencing intent first and performs revert/resume in separate
scans. Only the pinned CLI's explicit not-found result permits first creation;
a missing bound incarnation is an error. Missing egress policy uses a separate,
version-specific success/empty-output convention normalized inside this adapter.

Provider observations and log attribution are trusted controller inputs. No
transaction spans provider state and Transit. Arbitrary provider replacement,
state migration, multiple PIDs per Actor, and out-of-band privileged provider
administration are outside the supported profile.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-runtime-substrate && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

Real provider behavior and egress isolation require `just launchers::reference::test` on the
[pinned reference deployment](../../../deploy/reference/README.md).

## Instrumentation

`Adapter.observer` and `parent_context` optionally borrow the host's telemetry
runtime/context through [transit-observability](../transit-observability/README.md).
`transit.provider.operation` measures bounded CLI calls using a finite operation
vocabulary. It excludes provider args/configuration, raw output and credentials.
Success is debug; failures are warnings. A failed invocation can follow a remote
change: diagnostics do not resolve uncertain provider intent or authorize retries.

Same-PID compatible template changes use `reconcileUpgrade` only after a durable
upgrade transition. `Config.previous_workload` supplies old template identity;
the adapter checks it against the recorded hash, and the packaged CLI supplies
UID/version guarded UpdateActor. Readback, not the CLI exit status, closes the
provider operation. See the [upgrade contract](../../../contracts/RUNTIME_SUBSTRATE_V1.md#same-pid-workload-changes).

# Experimental Substrate runtime profile

The Zig `runtime-substrate` adapter and `runtime-controller` reconcile one
configured PID against the [pinned reference baseline](../deploy/reference/versions.json).
They use the upstream `kubectl-ate` executable for authenticated TLS/gRPC and
Kubernetes log access. The adapter requires its exact source revision; a changed
or dirty client build fails validation. Substrate, its CLI, and Kubernetes are
external infrastructure, not a second source of Transit task authority.

`runtime-controller CONFIG.json [--once]` reads a bounded authenticated process
view and advances at most one step per scan. Configuration supplies the protocol
URL/realm, controller principal and private seed file, PID, worker principal,
and provider settings: explicit CLI/kubeconfig/context, runtime-instance UUID,
atespace, unique Actor name, template name/UID, immutable image digest, authority
hostname, and egress-policy file. The controller needs `admin` and `inspect`
scoped to the PID; a root operator first establishes the worker's scoped
`execute`/`inspect` grant. Provider credentials never enter protocol history.

The binding records opaque hashes of the scoped resource and template/image
identity. The adapter validates the template UID and image, requires DATA
snapshots with COLD_BOOT resumption, and rejects a changed Actor incarnation.
Names belong exclusively to this controller's reference namespace and are never
reused. An unknown/absent API response is not an empty installation; only the
pinned CLI's explicit not-found outcome permits creation for a first binding.

The sequence is:

1. Discover backlog and record `runtime_intent`, fencing the preceding owner.
2. Create the uniquely named Actor if absent, then yield. A controller can die
   here; the next scan discovers and validates that same resource.
3. Establish and verify a default-deny egress policy allowing only the authority
   hostname, resume the Actor, and record its observed UID/readiness.
4. Read public bootstrap evidence from that Actor/container's current worker
   logs and recheck the Actor and worker UID. No private key is transferred.
5. Submit `activate`, atomically rotating the existing worker grant and ownership
   generation. The worker learns and pins that generation only once.

Subsequent scans compare the assigned worker UID with durable activation
evidence. Worker loss with pending input triggers another recorded intent and
fresh activation for the same PID/Actor. Lost notifications do not strand work.
Retirement prevents further activation; suspension is separate provider cleanup.
After worker loss, Substrate requires reverting a CRASHED Actor to its last
committed snapshot before resuming it. The controller first records the new
intent to fence the old activation, then reverts and resumes in separate scans.
DATA-only snapshots restore no worker private key or execution authority;
the fresh worker recovers current state from Transit. An interrupted revert is
reconciled from the same Actor's observed state.
Uncertain creation/revert/resume calls are reconciled against the scoped identity.
An operation in progress is not permission to create another executor.

Provider observations and log attribution are trusted controller inputs. There
is no transaction spanning provider state and Transit: a provider can fail after
inspection, but only the committed activation grants execution. The next scan
fences a displaced activation. Out-of-band provider administration is outside
this workload-adversary boundary. Arbitrary provider replacement, template
migration, FULL memory snapshots, and multiple processes per Actor remain
unsupported. A missing previously bound Actor fails closed instead of silently
recreating its name.

CLI calls use explicit argument arrays, bounded output (64 KiB stdout/8 KiB
stderr), and a 30-second I/O deadline. Version-specific CLI conventions are
inside this adapter, including its success/empty-output representation of a
missing egress policy. Provider errors are not printed with credentials or
submitted payloads. Cluster recovery and egress bypass checks are separate from
the unit, loopback, and disk proofs; the reference harness records their actual
outcome rather than treating infrastructure startup as conformance.

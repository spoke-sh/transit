# Experimental Substrate runtime profile

The Zig `transit-runtime-substrate` adapter and `transit-runtime-controller`
reconcile one configured PID against the [pinned reference baseline](../deploy/reference/versions.json).
They use the Nix-packaged `kubectl-ate` executable for authenticated TLS/gRPC and
Kubernetes log access. The adapter requires its exact source revision; the optional template-switch operation additionally requires the explicitly
identified `transit-upgrade-v1` CLI extension. The
[extension](../nix/ate-upgrade/README.md) calls the existing server API. Substrate, its CLI, and Kubernetes are
external infrastructure, not a second source of Transit task authority.

The [controller README](../apps/transit-runtime-controller/README.md) owns
configuration, credentials, scan operation, and scaling limits. The
[adapter README](../packages/zig/transit-runtime-substrate/README.md) owns the
provider API/configuration mapping. The contract below defines required ordering
and validation independently of command-line usage.

The binding records opaque hashes of the scoped resource and template/image
identity. The adapter validates the template UID and image, requires DATA
snapshots with COLD_BOOT resumption, and rejects a changed Actor incarnation.
The template's single container must match the configured `container` name
(`counter` for existing installations, `station` for the Station example). That
same name selects the provider-attributed bootstrap logs; a mismatch fails before
activation. The template must declare one `durableDir` volume named `runtime-data`, mounted
at `/runtime-data`; Substrate refuses DATA suspension without a durable directory.
The fixed worker stores no signing keys or authority there. Additional or
external volume mounts are rejected by this profile's template validation.
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
A recorded handler failure also drives provider shutdown without retiring the
PID or consuming its failed input. Controllers must not turn that visible blocked
state into repeated activation attempts.
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
this workload-adversary boundary. Arbitrary provider replacement, state migration, FULL memory snapshots, and multiple processes per Actor remain
unsupported. A missing previously bound Actor fails closed instead of silently
recreating its name.

## Same-PID workload changes

Stop and fence the old activation with `runtime_intent`, then reconcile a
stopped observation. An authorized operator commits `runtime_upgrade` with the
old/new workload hashes and expected application/state contract. Only then may
the controller switch templates on the existing Actor. Its target configuration
must include `previous_workload` (old template name, UID and image); its hash must
match the durable `upgrade_from`. A stale controller targeting the old workload
fails before provider mutation.

The adapter requires SUSPENDED provider state (reverting CRASHED first), checks
the recorded Actor UID, and calls `update actor` with expected UID and old
template. The CLI reads the Actor and carries its UID/version into the server's
atomic UpdateActor preconditions. Substrate checks compatible sandbox config,
volumes and mounts. Unknown outcomes are reconciled by same-UID target-template
readback on a later scan. Only that stopped observation completes the switch.
An explicit running intent follows; activation still requires a new worker pod
UID and signing key. Version-specific WorkerPools provide that fresh incarnation.

This preserves opaque Transit state and pending protocol work, not arbitrary
application schema compatibility. Expiry or termination during the switch can
settle provider evidence but cannot resume execution. Template switching is not
an image rollback of history or an authorization to repeat external effects.

CLI calls use explicit argument arrays, bounded output (64 KiB stdout/8 KiB
stderr), and a 30-second I/O deadline. Version-specific CLI conventions are
inside this adapter, including its success/empty-output representation of a
missing egress policy. Provider errors are not printed with credentials or
submitted payloads. Cluster recovery and egress bypass checks are separate from
the unit, loopback, and disk proofs; the reference harness records their actual
outcome rather than treating infrastructure startup as conformance.

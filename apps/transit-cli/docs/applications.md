# Local applications

Install a separately compiled application into a trusted local Linux neighborhood.
The server implements the [language-neutral installation contract](../../../contracts/APPLICATION_INSTALLATION_V1.md).
The supervisor hosts Zig workers; other language hosts and distributed placement
are unsupported. See the [test guide](../../../tests/README.md)
for executed evidence.

## Start and install

Use the version-1 configuration and executable paths in
[server configuration](server.md). For a new application-capable installation, add:

```json
"applications": { "port": 19106, "max_applications": 8, "max_roles": 32 }
```

The five service ports, application management port and Board port must differ. Start with
`transit server --config transit.yaml` for both first startup and restarts. The ready record includes
`management_config`. Application management uses the shared client library's
`Application.Request`, `Application.sign` and `Application.Client.call` with the
[installation contract](../../../contracts/APPLICATION_INSTALLATION_V1.md).
There is no application-management command in `transit`. The caller loads the
private management profile, constructs a typed request and retains its exact
signed bytes before submission. The server returns typed status or connection
values. This is not an
in-place conversion of an existing installation: neighborhood configuration and
Transit/provider artifact hashes remain pinned. Application replacement is a
separate operation.

Build the work-item consumer through its own package manifest:

```sh
cd examples/work-items
zig build -Doptimize=ReleaseSafe
./zig-out/bin/work-items manifest "$PWD/zig-out/bin/transit-work-items" > application.json
```

Build with the repository’s [pinned Zig toolchain](../../../nix/README.md). The
separately built package depends on public Transit packages, not private CLI/server code.
The server executes the artifact directly, without a compiler, shell, Python,
source checkout or downstream supervisor. It starts roles in declared dependency
order. `installed` means all native provisioning receipts have been checkpointed;
`ready` is an observed worker activation. Neither proves domain initialization
or a completed application command. Poll status until `installed` is true and
all roles are `ready` before continuing with the connection-export steps.

Application-enabled neighborhoods configure their dedicated courier to deliver
all pending recorded outputs in the realm. This includes application self-messages
and inter-role messages after new PIDs are installed. It walks bounded native
output pages and retains an exact uncertain delivery request; worker and resource
grants remain separate. Neighborhoods without application hosting use the built-in
query owner/requester destination list.

A declaration names roles, executable artifacts, compatibility contracts,
configuration, resources, named associations, explicit grants, callers and
initial domain frames. The caller resolves artifact paths and computes their
SHA-256 hashes before freezing the signed request.
Install again with the same complete declaration to attach to the retained IDs.
A changed declaration fails; it cannot silently change topology or broaden grants.
Admission also reserves checkpoint space for the next native request. A replacement
that exceeds the remaining encoded checkpoint budget fails before acceptance,
without disturbing installed workers.

## Caller connections and domain commands

The management `connect` request selects an application and a declared caller.
Its `Application.Connection` response references that caller's private seed file;
it does not export the installer key. Save the response privately for the
application's own client. The work-item example accepts this neutral JSON
connection and exposes its own domain commands. See its
[local guide](../../../examples/work-items/docs/local.md).

Installation acceptance, worker readiness and domain initialization are distinct.
Use management `status` for deployment observations and the application's own
inspection operation for domain progress.

## Replace a worker

Build the new executable to a separate immutable path. Obtain the current
role `revision` from a management `status` response. Write a replacement JSON object with
`application`, `role`, that `expected_revision`, the unchanged `contract`,
`artifact` (`path` and `sha256`) and `configuration`. Sign a management `replace`
request with a fresh operation identity, persist it, and submit it through
`Application.Client.call`. Observe the resulting deployment with `status`.

The manager atomically fences the old worker before stopping its dependent
roles. The new process generates its own key, and native rotation installs it
with fresh ownership while preserving the worker's principal, permission epoch,
resource grants, PID, resources, input history and request sequence. Replacement
cannot renew revoked permissions. Unrelated applications and neighborhood roles
continue running. A matching contract string is a declared compatibility promise;
Transit cannot prove an application's transform or computation is correct.

Rewriting the old artifact in place makes its recorded digest stale. The manager
refuses to start a changed artifact under an old revision. Deploy a distinct
path and an explicit replacement instead. Automatic watch/rebuild, hot code
loading, rollback to older data contracts and Transit upgrades are outside v1.

## Recovery and limits

On a lost management response, resubmit the original frozen signed request.
A returned status is the current observed
state, not a new provisioning receipt. Reusing an operation ID for changed intent
fails. A pending native request is recovered before any fresh root operation,
including activation of built-in neighborhood workers. Application receipt floors
also detect rollback across an interrupted local checkpoint. Ordinary startup
never deletes history, resets grants, or creates replacement resources.

SIGINT/SIGTERM stop and join owned children; manager SIGKILL triggers the Linux
parent-death contract. Restart with the same server command and configuration.
Worker-only interruption restarts its required dependency closure.
Storage/authority interruption restarts the pinned neighborhood on retained disk.
Temporary authority liveness-read failures require three consecutive failed
observations before restarting live roles; current denials fail immediately.
An explicitly denied app is reported `failed`; automatic recovery does not
restore its rights. Inspect the named failure and retained evidence before an
operator repair. v1 has no automatic permission-repair or history-reset command.

| Bound | v1 limit |
| --- | --- |
| One declaration | 8 roles, 16 resources, 8 callers, 16 initialization frames |
| Deployment quota | Default 8 applications / 32 roles; configurable up to 64 / 256 |
| Management request/reply | 64 KiB; names 64 bytes, association names 32 bytes, paths 4096 bytes, role configuration 8192 UTF-8 bytes |
| Resident checkpoint read | One application record, at most 256 KiB; retained requests/receipts are separate files |
| Receipt status page | 8 receipts; the request's `after` field accepts the previous `next` cursor |
| Reconciliation | One application step per 100 ms; one frozen native operation at a time |
| Management HTTP | 6 sockets, 2 data requests plus 1 health request; 500 ms headers, 4 s whole request |
| Worker lifecycle | 10 s registration, 30 s activation; 3 exit restarts per manager invocation; 1 s graceful shutdown per child |
| Child diagnostics | Two drained 64 KiB prefixes per active child; payloads/keys are not manager diagnostics |

The public status is an authorized, sampled deployment observation. Read domain
state through the caller's current native/resource grants. Repeated operation
history grows on disk, with unlimited retention by default; active quotas and
bounded record/page reads do not turn that history into a resident queue.


## Board inspection

A version-1 server starts Board by default. A declaration with `version: 1` may
include `"inspection": [{"resource":"data","permissions":3}]`, where `data`
is one of its declared resource names. Permission `1` allows metadata; `3` also
allows bounded entry/framework inspection. Write bits, unknown resources and
duplicates reject before provisioning. Omitting this list grants no resources.
The installation, management and bootstrap contracts all use v1. Incompatible
definitions require a new installation; version labels alone do not prove compatibility.

The trusted installer authorizes this declaration; Board receives its own
inspection-only principal, never a caller's signing seed. Accepted resource grants
have exact pending requests and retained receipts in the application's existing
journal. Headless installation may precede Board's first enablement. Subsequent
restart, replacement and re-enablement do not repeat completed grants or restore
revoked access. Board's realm-wide process metadata remains visible; resource
visibility is independently filtered by its current grants.

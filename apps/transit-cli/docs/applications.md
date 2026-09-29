# Local applications

Install a separately compiled application into a trusted local Linux neighborhood.
The CLI implements the [language-neutral installation contract](../../../contracts/APPLICATION_INSTALLATION_V1.md).
The supervisor hosts Zig workers; other language hosts and distributed placement
are unsupported. See the [test guide](../../../tests/README.md)
for executed evidence.

## Start and install

Use the version-3 configuration and executable paths in
[server configuration](server.md). For a new application-capable installation, add:

```json
"applications": { "port": 19106, "max_applications": 8, "max_roles": 32 }
```

The five service ports, application management port and Board port must differ. Start with
`transit serve --config server.json --initialize`; subsequent starts omit
`--initialize`. The ready record includes `management_config`. This is not an
in-place conversion of an existing installation: neighborhood configuration and
Transit/provider artifact hashes remain pinned. Application replacement is a
separate operation.

Build the work-item consumer through its own package manifest:

```sh
cd examples/work-items
zig build -Doptimize=ReleaseSafe
./zig-out/bin/work-items manifest "$PWD/zig-out/bin/transit-work-items" > application.json
transit app install --config /absolute/local-transit/management.json \
  --file application.json --operation install-1
transit app status --config /absolute/local-transit/management.json --application work-items
```

Run these commands in the pinned Nix development environment. The separately
built package depends on public Transit packages, not private CLI/server code.
The server executes the artifact directly, without a compiler, shell, Python,
source checkout or downstream supervisor. It starts roles in declared dependency
order. `installed` means all native provisioning receipts have been checkpointed;
`ready` is an observed worker activation. Neither proves domain initialization
or a completed application command. Poll status until `installed` is true and
all roles are `ready` before continuing with the connection-export steps.

A declaration names roles, executable artifacts, compatibility contracts,
configuration, resources, named associations, explicit grants, callers and
initial domain frames. Relative artifact paths resolve against the declaration
file. An omitted hash is computed before the CLI freezes the signed request.
Install again with the same complete declaration to attach to the retained IDs.
A changed declaration fails; it cannot silently change topology or broaden grants.
Admission also reserves checkpoint space for the next native request. A replacement
that exceeds the remaining encoded checkpoint budget fails before acceptance,
without disturbing installed workers.

## Export connections and use domain commands

```sh
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller writer --output writer.json
transit app connect --config /absolute/local-transit/management.json \
  --application work-items --caller inspector --output inspector.json
./zig-out/bin/work-items inspector.json inspect
./zig-out/bin/work-items writer.json put put-1.json 1 0
```

The initial `inspect` must observe the initialized domain head before the first
write. If initialization is still pending, retry the read; physical readiness
does not imply that the initialization frame has committed.

Connection files contain endpoint, named bindings and a private seed-file
reference. They contain no realm-root or worker key. Do not publish these files
or their credentials. Installer, domain operator, domain writer and inspector
have separate identities. The example's `operator` authorizes and advances its
migration; it cannot install applications or rotate workers. The inspector has
native/resource reads only. All roles share one trusted OS user: credential-file
separation is not a filesystem sandbox.

The domain CLI freezes signed sends and records acceptance before awaiting a
committed disposition. Reuse the same recovery filename after a lost response.
A receipt proves acceptance; a domain command can still fail with a retained
application disposition. Migration commands and target verification belong to
the [application](../../../examples/work-items/docs/local.md).

## Replace a worker

Build the new executable to a separate immutable path. Obtain the current
role `revision` from `transit app status`. Write a replacement JSON object with
`application`, `role`, that `expected_revision`, the unchanged `contract`,
`artifact` (`path` and optional `sha256`) and `configuration`, then run:

```sh
transit app replace --config /absolute/local-transit/management.json \
  --file replacement.json --operation replace-1
transit app status --config /absolute/local-transit/management.json --application work-items
```

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

On a lost management response, run:

```sh
transit app retry --config /absolute/local-transit/management.json --operation replace-1
```

This reuses the exact frozen request. A returned status is the current observed
state, not a new provisioning receipt. Reusing an operation ID for changed intent
fails. A pending native request is recovered before any fresh root operation,
including activation of built-in neighborhood workers. Application receipt floors
also detect rollback across an interrupted local checkpoint. Ordinary startup
never deletes history, resets grants, or creates replacement resources.

SIGINT/SIGTERM stop and join owned children; manager SIGKILL triggers the Linux
parent-death contract. Restart the same server configuration without
`--initialize`. Worker-only interruption restarts its required dependency closure.
Storage/authority interruption restarts the pinned neighborhood on retained disk.
An explicitly denied app is reported `failed`; automatic recovery does not
restore its rights. Inspect the named failure and retained evidence before an
operator repair. v1 has no automatic permission-repair or history-reset command.

| Bound | v1 limit |
| --- | --- |
| One declaration | 8 roles, 16 resources, 8 callers, 16 initialization frames |
| Deployment quota | Default 8 applications / 32 roles; configurable up to 64 / 256 |
| Management request/reply | 64 KiB; names 64 bytes, association names 32 bytes, paths 4096 bytes, role configuration 8192 UTF-8 bytes |
| Resident checkpoint read | One application record, at most 256 KiB; retained requests/receipts are separate files |
| Receipt status page | 8 receipts; `--after` accepts the previous `next` cursor |
| Reconciliation | One application step per 100 ms; one frozen native operation at a time |
| Management HTTP | 6 sockets, 2 data requests plus 1 health request; 500 ms headers, 4 s whole request |
| Worker lifecycle | 10 s registration, 30 s activation; 3 exit restarts per manager invocation; 1 s graceful shutdown per child |
| Child diagnostics | Two drained 64 KiB prefixes per active child; payloads/keys are not manager diagnostics |

The public status is an authorized, sampled deployment observation. Read domain
state through the caller's current native/resource grants. Repeated operation
history grows on disk, with unlimited retention by default; active quotas and
bounded record/page reads do not turn that history into a resident queue.


## Board inspection

A version-3 server starts Board by default. A declaration with `version: 2` may
include `"inspection": [{"resource":"data","permissions":3}]`, where `data`
is one of its declared resource names. Permission `1` allows metadata; `3` also
allows bounded entry/framework inspection. Write bits, unknown resources and
duplicates reject before provisioning. Omitting this list grants no resources.
Version-1 declarations keep their original canonical signed bytes and cannot
request this field with a nonempty value. Management and bootstrap remain v1.

The trusted installer authorizes this declaration; Board receives its own
inspection-only principal, never a caller's signing seed. Accepted resource grants
have exact pending requests and retained receipts in the application's existing
journal. Headless installation may precede Board's first enablement. Subsequent
restart, replacement and re-enablement do not repeat completed grants or restore
revoked access. Board's realm-wide process metadata remains visible; resource
visibility is independently filtered by its current grants.

# transit-station-document-worker

Finite fenced Document worker over public Station calls. It composes the
[Document package](../../packages/zig/transit-station-document/README.md) and
bounded telemetry; it has no raw storage or effect connector access. The
[two-client disk proof](../../examples/station-document/README.md) passes;
isolated Compose and reference placement proofs also pass.

Build with `zig build transit-station-document-worker`, then run
`zig-out/bin/transit-station-document-worker CONFIG.json`. Required configuration:
`url`, `realm`, non-root `principal`, `seed_file`, `pid`, `generation`,
`activation_directory` and `document`. The process needs a writer association
named `state` (override with `association`) and current resource grants.

Provision the resource and run `mode: "create"` before delivering calls. Creation
uses `type_revision: 1`, 4096-byte Publication records, one staged record and
4096 staging bytes. `mode: "run"` drains calls and advances the active job until
complete or its explicit `max_steps` budget (default 1024, maximum 10000).
The JSON result reports `phase: "progress"` if bounded work remains. This is
not a background daemon; a scheduler must deliver calls and invoke fresh runs.

`policies` contains at most 64 explicit `{caller, resource, replica, revision}`
bindings, with unique callers and replicas. They do not grant access: the worker
also needs read grants to each caller publication resource. `node_limit` bounds
one candidate's reserved nodes (default 512, maximum 65536), not total Document
size. For a PID-scoped principal, associate each request resource with that PID
as an optional read dependency; that scope does not replace its explicit grant.
Current policy is checked on every candidate step. A removed policy or
source read error leaves the input uncommitted for recovery.

Maintenance modes are `window` (`merge_window`, zero means unlimited),
`checkpoint` (`job`, nonzero and below bit 63), `reject` (remote `job`), `retire`,
and `collect` (`job`, `retired_cleanup`, `checkpoint_cleanup`). They require the
same current execution/resource authority. No mode expires work due to pressure.
Control arguments are recorded in authenticated self-inputs, so recovery never
reinterprets an older control tick using a newer local command.

Every invocation requires fresh fenced ownership, including after clean exit.
Preserve the activation directory: an existing marker returns
`FreshOwnershipRequired`. The worker neither acquires ownership nor repairs
grants itself. Exact pending signed requests retry in memory; after host loss,
fresh ownership reopens durable jobs and original reply routes. A replacement PID
cannot adopt another writer's route. Stop-policy errors preserve the uncommitted
input instead of permanently blocking its history.

Machine stdout contains only a bounded metadata result. Shared telemetry records
lifecycle events, public-client attempts and one `document.worker.operation`
summary with a finite operation label, duration and outcome. It excludes change
bytes, document values and credentials. Progress summaries and logs do not prove
caller receipt or confer execution authority.

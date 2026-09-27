# Finite public HTTP admission

The M15 worker supports one root call per provisioned connector PID. Provision
its `state` association to an independent resource (`owned: false`) with no
deadline. The connector PID writes capture and owns the effect; an application
caller uses a different PID and resource. The worker principal needs read/inspect
on the configured request resource in addition to its capture and execution
rights. A PID-scoped principal also needs an optional (`required: false`)
association from its PID to each foreign resource it reads. Use an optional
request association on the connector and optional capture association on the
caller. Required request dependencies would incorrectly tie reconciliation to
caller lifetime. Associations and HTQ1 references grant no access by themselves.
Provision both associations before assigning initial ownership: growing-profile
association changes require a quiescent, unowned PID. Each association advances
its PID's generation; acquire ownership using that resulting generation.

The Zig caller uses `RequestRecord.prepare`, publishes its returned metadata as
Publication record 1 and its exact body as record 2 in the referenced namespace,
then calls the connector PID with `reference.encode()`. Publication and call
remain ordinary fenced turns. Keep source records available until the worker
copies them. The worker checks that the resource writer is the recorded caller;
request resources cannot be substituted by untrusted reference fields.

Use `mode: "accept"` and configure the scope alongside the usual endpoint,
credential bindings, finite `max_attempts` and `reconcile_before_ms`:

```json
{
  "admission": {
    "caller": 123,
    "resource": 124,
    "scope": {
      "method": "POST",
      "target": "/operations",
      "headers": ["authorization", "idempotency-key"]
    }
  }
}
```

This is an additional configuration fragment, not a complete runnable config.
Method/target must match the serialized request exactly; header names are
case-insensitive. There are no path-prefix grants. The endpoint revision must
match; the requested original deadline and attempt count cannot exceed policy.
No `request` or `body_file` is needed in accept mode. The
[wire contract](../../../contracts/STATION_HTTP_V1.md#finite-public-admission-and-outcomes)
defines request/reply formats and rejection states.

After preparation, use a fresh owned generation in `execute` mode with the same
admission configuration. The worker rechecks current policy and sends only if the
effect is still pending. It atomically publishes one correlated Station reply
after terminal settlement. An observed reply has an immutable complete capture
reference; closed unknown preserves effect/attempt identity without a complete
body. The caller still needs current capture grants for replay.

If admission succeeds but copying or validation fails, the route remains durable.
Restore allowed access/configuration and resume with fresh ownership, or explicitly
abandon preparation in `release` mode. Abandonment before intent replies
not_dispatched; it cannot cancel a pending or possibly sent effect. Recovery never
reconstructs lost response bytes or resends an authorized request.

The connector PID survives caller termination and can close uncertainty after
worker/node/store recovery. Its reply remains addressed to the original PID;
delivery records a retired destination. Names and replacement PIDs cannot redirect
that reply. Capture itself is independent of the caller resource's lifetime.
The caller can explicitly dispose its durable hold with a separately correlated
`Service.Release{resource, exchange}.encode()` call to the connector. Run a fresh
worker activation in `poll` mode with the same admission policy to process this
call without another HTTP attempt. Accept `Service.Released` only from the
recorded connector and correlation. The shared handler commits the release and
acknowledgement atomically; repeated requests are safe after restart or cleanup.
`poll` drains at most 64 pending inputs and retains the worker's usual endpoint
configuration, but never resolves credentials or opens HTTP transport.

Release requires a published terminal outcome. It does not retire availability;
the controller still explicitly selects `release` mode for retirement and bounded
cleanup. The controller can also dispose the hold on the caller's behalf under
its administrative authority. Caller termination, receipt acceptance, local SDK
reader close and quota pressure are not disposal instructions.

## Explicit caller followups

The original caller can request a linked attempt with
`Service.Followup{resource, parent, reason, request}.encode()`. `resource` and
`parent` identify the capture and terminal parent exchange; `request` contains
the new published HTQ1 reference. Its deadline and total attempt limit must match
the original request exactly. Retry reuses the identical published request.
Redirect, status and cancellation publish new request records under the parent's
frozen policy. Each request gets its own durable call correlation.

Select a fresh child `exchange` and `followup: {parent, reason}` in the worker
configuration alongside current admission scope. In `accept` mode the worker
authenticates the original caller, requires the parent's published terminal
outcome, reads the proposed request under current grants and validates the frozen
endpoint policy before allocating a child. Wrong policy or request bytes receive
a correlated rejection without spending an attempt. Read failures leave the input
pending; restore access and resume with fresh ownership. Allocation and the
immutable reply route share one four-mutation turn, so lost receipts cannot
allocate twice or detach the reply destination.

After acceptance, `execute` requires another fresh activation and current dispatch
authority. Its outcome uses the followup correlation while retaining the original
caller, lineage, deadline and total attempt budget. Closing a parent unknown does
not automatically request a child; a successful child does not rewrite its parent.
Controller followups remain available for trusted orchestration. `poll` can admit
a configured followup, including authorized publication/CA reads, but never opens
HTTP transport or resolves credential values.
If no child was admitted, `poll` reports `phase: "not_admitted"` and
`outcome: "not_committed"`; the correlated rejection remains in the durable outbox.
Handler read failures stop the activation without blocking the process or advancing
its input, allowing fresh ownership after access is restored.

All ten SDKs expose durable disposal. Language-native followup helpers, general
queue scheduling and managed credential providers remain outside this qualified
surface. The real-binary proof is `just test::http-worker`; remaining SDK and
deployment work is tracked in M15.

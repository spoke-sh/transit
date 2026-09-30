# Names, waits and supervision

These policies run above the kernel through [Station](../README.md). The
[controller](../../../../apps/transit-station-controller/README.md) supplies
trusted time/lifecycle observations and separately authorized administrative
actions. No additional durable queue or naming store is introduced.

## Scoped registry

A scope is `(registry PID, scope u32)`. It shares the registry's required
resource lifetime; no worker-local, Kubernetes or global-cluster namespace is
implied. `Registry.create/grant` are trusted provisioning operations. The service
separately authorizes lookup and mutation from the input's authenticated process
or external-principal origin. A caller that can send is not thereby allowed to
lookup or mutate names.

`Request` encodes a versioned lookup/register/rebind/unregister operation, a
UTF-8 name of 1–24 bytes, expected revision and destination. Mutations serialize
in the registry's mailbox. Stale revisions fail, unregister retains a tombstone,
and recovery preserves both bindings and revision evidence. Default retention is unlimited. Records occupy paged durable state; resident
pages remain bounded and tombstones are not automatically evicted.
`Registry.route` consumes an authenticated lookup reply, records the registry
PID/binding revision/resolved PID and commits delivery to that fixed PID. A
later rebind never redirects the committed output or retry. A retired destination
receives the kernel's terminal delivery disposition.

Scope descriptors use `00 s <scope:u32le>`/`RGS1`; bindings use
`00 n <scope:u32le> <name>`/`RGR1`. Grants use a distinct subject-kind and ID.
These records and schemas are explicit framework declarations, not authority
inferred from application names. `Registry` owns the bounded binary codecs.

Authorization and lookup use three fallible point reads, independent of retained
name count; each mutation updates one binding. Principal IDs use the eight-byte
grant-key field across the native 53-bit range. Read and reply failures roll back
the private proposal. The shared native ABI exposes these same helpers.

## Waiting and time

`Turn.call` creates an unlimited wait. Finite waits use `callWithTimer`, naming
a deadline and dedicated observer principal. Requested deadlines must fit known
process and required resource bounds; finite lifetimes cannot silently create
unlimited waits. The waiter record commits with the request and acts as a durable
timer subscription. Its v1 record includes an optional full-width observer identity. The observer sends `TMO1` time evidence only after the recorded deadline.

Reply, timeout and explicit `Waiting.cancel` close a wait in mailbox order.
The first closure wins. Late outcomes have recorded dispositions without another
application callback. A timeout callback can update application state in its
closing turn. Closure also commits an advisory cancellation to the peer; an
accepted request or external side effect can still finish. Captured queries
honor cancellation before publication, and already published fragments remain
copies whose arrival cannot reopen a closed wait.

A scheduler delay may postpone the timer observation. These are ordered timeout
semantics; process/mailbox/resource hard expiry remains enforced by Transit
without requiring the timer worker. Suspend/resume uses the existing generation-
fenced lifecycle API and its validated `resume_before_ms`; a known-expired PID
cannot be recovered by issuing another call or creating empty associated state.

## Minimal supervisor

`Supervisor.register` records an existing child's durable PID and observer,
retry limit (0–16) and fixed backoff (0–60000 ms). At most four retained child
records fit this profile; they share the supervisor's state resource. Provision
and initialize a child through the public lifecycle/state API with a separate
trusted provisioner before attaching it. Ordinary handlers never receive root
credentials or implicitly acquire resource grants. Registration is conditional
on absence and recovery reads the existing child records, so restarting the
supervisor cannot allocate duplicate children.

The policy is one-for-one, preserving the PID and failed head input. An
authenticated failure observation records backoff and one retry intent. A
separately scoped admin executes it; changed generations fence stale actions.
The failure reference is the failure record ID, distinct from the input ID.
Attempts remain bounded across supervisor/child recovery. Exhaustion keeps the
child visibly blocked. Activation loss, suspension, provider unavailability and
permanent retirement remain distinct observations; none means accepted messages
were discarded. Provider stop/restart cannot reuse execution authority.

The supervisor never automatically replaces a retired PID. A trusted provisioner
may explicitly create and initialize a new PID; `replace` conditionally records
that successor against the old retirement observation. Old mailbox/effects stay
with the old PID. Required PID-owned resources survive worker replacement and
retire with their logical owner under the kernel's dependency rules. Registry
rebinding is a separate ordered action. General restart trees, automatic child
allocation and cluster-wide registry arbitration are not advertised by this
minimal profile.

`SUC1` child records use `00 c <pid:u64le> 00`; `SUP1` observations arrive as
casts. `just test::station` checks a registry rebind before delivery, timeout
across worker replacement, late reply closure, separate observer/admin grants,
supervisor restart, bounded poisoned-input retry and permanent retirement.

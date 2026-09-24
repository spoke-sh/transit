# transit-station-controller

Carries out Station's durable timer/lifecycle subscriptions through the public
client. It is separate from the generic
[`transit-runtime-controller`](../transit-runtime-controller/README.md), which
reconciles provider placement. Ordinary GenServer workers receive neither
controller's credentials.

```sh
zig build transit-station-controller
zig-out/bin/transit-station-controller controller.json
zig-out/bin/transit-station-controller controller.json --once
```

Configuration contains `url`, `realm`, non-root `principal`, `seed_file`,
`mode` (`observe` or `lifecycle`), and one to four `watches`. Each watch identifies
the writer `pid` and its associated `resource`; optional `child` limits a
supervisor watch to one child. `interval_ms` defaults to 100 and
`request_timeout_ms` to 5000; both allow 1–60000.

In `observe` mode, use a dedicated send/inspect principal (20) and explicit
read/inspect resource grants (3). The controller reads durable waiting records
and child subscriptions. Due timers name the recorded correlation and carry a
trusted wall-clock observation to the caller's mailbox. Lifecycle messages name
the child PID, generation, failure **record ID**, observation cut and time.
Workers validate the configured observer's authority-derived origin. This
identity and clock are a trusted framework boundary; telemetry does not supply
these observations.

In `lifecycle` mode, use a separate admin/inspect principal (17), scoped to the
child PID, with read/inspect rights to the supervisor resource. The controller
only acts on a recorded retry intent. It verifies the current generation and
exact failure record, then submits the kernel retry operation. A bound child
first gets a recorded provider-stop intent; the runtime adapter must confirm
stopped before retry can request fresh placement. Pending/unknown placement
remains unavailable; it never grants an activation. Additional provider images
still require their own bootstrap/recovery qualification.

Use one controller per mutation identity. A pending submission retains exact
signed bytes on transport failure. After controller loss, current durable state
determines whether the administrative transition already occurred. Observations
may repeat after host loss; mailbox transitions handle duplicates. The bounded
in-memory seen cache only reduces duplicate observations and never owns waiting
or child state. Read continuations may expire during concurrent activity; the
controller restarts the observation without stitching inconsistent pages.

Timers close waits by admitted sequence, not by promising an instantaneous
wall-clock cutoff. A process/resource deadline is independently kernel-enforced.
Cancelling a wait cannot undo work already accepted by its peer. Supervisor
retry limits, terminal retirement and replacement policy live in the
[Station services guide](../../packages/zig/transit-station/docs/services.md).
`just test::station` runs both modes with the real example and disk-backed
authority, including distinct credentials and recovery.

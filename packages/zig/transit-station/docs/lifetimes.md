# State and process lifetimes

A Station behavior uses a named resource association. Its provisioner creates
the PID, declares required associations, creates/grants/associates the resource,
then explicitly initializes the PID. An association grants neither access nor
ownership. Station opens bounded read views and commits mutations, input
progress and outgoing intents together through the public client.

Retention defaults to unlimited. Choose finite policies explicitly through the
[state](../../../../contracts/STATE_V1.md) and
[lifecycle](../../../../contracts/LIFECYCLE_V1.md) commands. A PID-owned resource
survives worker loss; logical owner termination/expiry retires it. Physical
reclamation follows the resource's selected history policy. Independently owned
resources have their own lifetime. Neither case makes a replacement PID inherit
the old process's state or pending work automatically.

Suspension fences the current activation and records `resume_before_ms`.
Transit rejects a bound beyond required resource/process lifetime. Resume before
that bound still requires current grants, usable dependencies and a new owner.
For runtime-bound processes, confirm provider stop and arrange fresh placement;
the [services guide](services.md) explains the supervisor's separate roles.

A trusted clock may report `DeadlineUncertain` around a cutoff. Retryable time
or storage failures do not authorize retirement. Once expiry is durably known,
`Session.receive` reports `ProcessExpired`; termination reports
`ProcessTerminated`. Station's C ABI reports status `rejected` (3) with that
detail, separately from `stale_activation` (11). Stop attempting same-PID
recovery. Supervision records a terminal child observation; a replacement is an
explicit new spawn with a new identity and application-chosen state policy.

Tables, descriptors, waits, registry entries and captured query results share the
resource's 32-entry capacity. Unlimited retention does not promise unlimited
resident state. Capacity errors leave the private proposal uncommitted; Station
does not evict records or invent a reclamation policy. Workload lifetime expiry
does not imply rollback of an already authorized external effect.

`just test::station` proves suspension within dependencies, worker/store recovery
and permanent retirement/reclamation of PID-owned Table state.
`just bindings::native` proves distinct foreign-caller retirement errors and
Table update/delete/reinsert recovery from a checkpoint and its retained tail.

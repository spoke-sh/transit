# Working on shared fixtures

Follow the [test rules](../AGENTS.md) and [harness index](README.md). Share ports,
readiness, process ownership and artifact capture here; keep expected semantics
and fault schedules in their domain owners.

Generic helpers must not import provider fixtures. Select Ursula explicitly via
`harness.ursula`; local WAL/Table checks use their own storage configuration.
Do not add a default backend or fallback that changes a scenario's evidence.

Keep finite deadlines, process-exit detection and joined cleanup. A successful
HTTP readiness probe does not prove authority or accepted-write recovery. A
returned free port is not a reservation. Preserve failure evidence and exclude
credentials from logs. Do not introduce global services shared by otherwise
isolated tests to improve timing.

When moving a helper, migrate every caller, including examples and nested test
directories. Check failure controls and execute affected real fixtures from
committed source. Fast harness controls do not replace backend qualification.

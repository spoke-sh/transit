# Production guard mutation campaigns

[Verification](../README.md) · [Contribution rules](AGENTS.md)

[mutations.py](mutations.py) clones committed HEAD, checks an unmodified baseline,
then removes one reviewed production guard at a time. A mutant must compile and
trigger the owning executed assertion. Build errors, timeouts, missing artifacts
and a failed unmodified baseline remain inconclusive failures.

| Campaign | Command | Owning schedules |
| --- | --- | --- |
| Generation, revision, permission and captured-view deadline | `just test::mutations` | [transitions](../simulation/transitions/transitions.py) |
| Route ordering and destination provenance | `just test::simulation-mutations` | [delivery](../simulation/storage/simulation.py) |
| Resource mutation and input progress | `just test::resource-simulation-mutations` | [resources](../simulation/resources/resource_simulation.py) |
| Pending courier identity and Session activation | `just test::scheduler-simulation-mutations` | [scheduler](../simulation/scheduler/scheduler_simulation.py) |
| Document, Exchange, refresh, runtime and catalog contracts | `just test::domain-simulation-mutations` | [components](../simulation/domains/domain_simulation.py) |

Campaigns keep the original and minimized failures under `.cache/verification/`.
The source-edit patterns must match exactly once. A changed production guard
requires review of the mutation and assertion; it cannot silently skip detection.
The working checkout is never the mutation target. Model-only negative controls
remain beside their [formal runners](../models/README.md).

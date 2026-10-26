# Resource publication simulation

`just test::resource-simulation-smoke` replays six saved storage-fault schedules.
`just test::resource-simulation --seeds 2` also explores first/middle/last I/O
boundaries of generated two-turn control schedules. `--exhaustive` enumerates
every observed I/O call; select it explicitly because page reads multiply runs.
`--trace PATH` replays concrete events independently of generator changes.
`just test::resource-simulation-mutations` uses committed isolated clones to omit
resource writes or input progress and requires actual correspondence failures.

The Zig driver uses the real core, four frozen decision slots, one resource/key,
captured views, a self-directed outbox, and a two-page provider cache. Stage faults
apply inside the real tree's individual/batch path; an after-stage fault may leave
orphan bytes without publishing a root. Read unavailability, pre/post-append
faults, explicit cache eviction and interrupted prefix trimming have distinct
trace events. Atomic conditional append and durable immutable pages are premises.
There is no disk, physical page deletion, provider rollback or corruption model.

The logical oracle checks state/input/output atomicity, captured values, exact
retry and accepted history floors. Recovery must stage no pages and match the
live engine. Generated healthy suffixes restore required permissions/time,
consume eligible input and check recovery after checkpoint/trim; pending outputs
remain recorded rather than implicitly delivered. The trace cap is 512 events
and 1 MiB, with 1..64 seeds and a 90-second per-driver deadline. Failures that did
not exercise their requested fault cannot pass. Every trace runs twice; checker
controls alter resource state, input progress, outputs and view evidence, omit
observations and leave input undrained.

`.cache/verification/resource-simulation.json` records completion, source/dirty
status, compiler/binary/oracle hashes, generator/configuration, fault counts,
trace hashes and duration. Failure details, concrete replay and bounded minimized
counterexamples live in `.cache/verification/resource-simulation/`. Numbered I/O
coordinates can change with implementation changes; a fault that no longer fires
requires an explicit corpus review, not silently accepting the run.


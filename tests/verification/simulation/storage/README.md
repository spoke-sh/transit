# Authority and delivery simulation

```sh
just test::simulation
just test::simulation --seeds 64 --steps 128
just test::simulation --trace .cache/verification/simulation/minimized.json
just test::simulation-mutations
```

[delivery_simulation.zig](delivery_simulation.zig) executes real signed authority
and outbox transitions with producer PIDs 4 and 5, worker principals 1 and 2,
destination PID 6 and courier principal 3. Root principal 0 owns provisioning and
policy changes. The fixed topology and eight delayed-decision slots bound this
test, not production cardinality. A synthetic turn copies one admitted integer
into one committed output. No application handler, resource, HTTP or effect runs.

[simulation.py](simulation.py) independently checks operation outcomes, sequences,
ownership, lifecycle, output phases, values and destination-input provenance after
every event. A separately recovered engine must match the live engine's selected
logical state without staging pages. The live engine/cache survive until explicit
restart. Delayed slots retain immutable prepared decisions and exact signed
requests; they are controlled pending work, not recovered worker memory.

The store injects `before_append` or `after_append` on one commit/retry event.
Failed validation or receipt deduplication cannot leak that fault into the next
operation. Conditional append is assumed atomic and immutable pages stay
available. Page faults, capacity, checkpoint/trim, time and real disk/network
behavior remain separate proofs. No physical durability claim follows.

The generator is `xorshift64-delivery-v1`. Defaults run eight 48-step schedules
alongside six saved cases for reply loss, independent routes, stale proposals,
competing principals, denied/retired outputs and failed preparation. Every trace
runs twice with identical observations. Generated traces append a healthy progress
phase: restore permissions, admit no fresh input, consume eligible producer input,
resolve pending routes and check drain before and after restart. Retirement stays
terminal. This checks the finite explicit schedule, not automatic worker fairness.

Test-format-1 traces contain at most 4,096 actions. Discovery permits 1–10,000
seeds and 1–512 random steps per seed, plus the healthy suffix. Each driver run
has a 90-second deadline. Delta debugging tries at most 96 reductions while
preserving failure category. Driver errors, malformed/incomplete output and
timeouts fail without becoming minimized invariant counterexamples. The store
and oracle retain bounded test history in memory; they do not measure production
resident-memory independence.

The runner also intentionally leaves one input undrained and requires the actual
driver's failed progress check to fail the task's checker, even though it agrees
with the oracle. Removing the final observation must classify the trace as
incomplete. These negative controls are counted separately from explored events.

`.cache/verification/simulation.json` records revision/dirty status, compiler,
binary/oracle hashes, generator, trace digests, counts, outcome coverage and time.
Each invocation marks completion false before running, preventing an interrupted
run from leaving an earlier success as its result. Failures retain `failure.json`,
`failure-evidence.json` and, for correspondence/progress failures, `minimized.json`
under `.cache/verification/simulation/`. Traces use synthetic keys and values.

The mutation task requires committed HEAD and a passing baseline. In an isolated
clone it separately removes real core route ordering and corrupts destination
provenance. Both must compile, execute and yield a minimized correspondence failure;
compile errors/timeouts do not count. Artifacts are under
`.cache/verification/simulation-mutations/`.

The ordinary core lane owns the small task. Weekly discovery runs 64 seeds with
128 steps and both delivery mutants. Earlier hosted budgets do not qualify these
additions; local timings and hosted cost evidence remain separate. Real disk,
service, SDK, browser and provider suites retain their independent obligations.


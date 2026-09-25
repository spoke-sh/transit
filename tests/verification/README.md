# Verification foundation

[Strategy](../../docs/TESTING.md) · [M10](../../docs/roadmap/M10.md)

This is executable test infrastructure, not an alternate authority. The existing
disk, native scheduling, browser, launcher and provider proofs remain necessary.

## Inventory

[suite.json](suite.json) is the task inventory used by local and hosted CI.
[invariants.json](invariants.json) maps stable claims to design/implementation
owners, exercised schedules and qualification limits. A null model means no
formal model currently covers that claim. Tasks name executable checks, not an
assertion that every possible violation is detected.

[limits.json](limits.json) distinguishes total-cardinality ceilings from operation
budgets, encodings, working sets and quota ceilings in the legacy profile. The
checker rejects unreviewed changes to these constants and new `max_*` declarations
in the audited files. Other component-specific transport/parser bounds still
require review when those components change. It does not infer that a fixed
array is scalable because its memory use is bounded.

`python3 -B tests/verification/check.py` validates owners, links, classifications
and drift; `just check` includes it. Missing tasks and unreviewed limit changes
are negative controls. This catalog does not claim the growing profile exists.

## Generated transitions

```sh
just test::properties
just test::properties --seeds 128 --steps 128
just test::properties --trace .cache/verification/transitions/failure.json
```

[transition_driver.zig](../transition_driver.zig) executes `Engine(Store)` with
real signatures, caller proposals and replay. Its test-only store separates
failure before append from lost acknowledgement after append. Each step recovers
the durable history and compares its logical state with the live engine. It does
not run application handlers or make network calls.

[transitions.py](transitions.py) independently tracks one PID, caller permission,
ownership, mailbox progress, retained receipts and caller-supplied opaque results.
It compares every boundary against the driver, including preparations that never
publish. Generation uses a fixed xorshift64 algorithm; failure evidence saves the
actual action list as well as the seed. Bounded delta debugging removes irrelevant
actions and writes a replayable trace. Corpus cases cover competing same-principal
proposals, lost acknowledgements, historical retries, revocation and stale owners.

This first generator does not model resource views, finite lifetimes, external
settlement, checkpoint pages or concurrent native handles. Existing focused
tests still own those obligations; M10 must extend the harness before closing
its generated-schedule gate. The in-memory fault store assumes conditional
append atomicity and is not a substitute for Ursula disk qualification.

## Model and guard qualification

The [finite TLA+ model](models/README.md) checks publication, retry and closure
safety and replays four removed-guard counterexamples against the real engine.
`just test::model` is part of the bindings lane so ordinary core/frontend checks
do not acquire a Java dependency. Its tools use the existing nixpkgs lock.

`just test::mutations` requires committed HEAD, clones it independently and removes
one actual generation, revision or permission guard at a time. The unmodified
baseline must pass; a compiling mutant must trigger a minimized property failure.
Build errors/timeouts do not count as detection. It retains evidence and never
edits production source in the working tree. Weekly CI runs this larger budget.

[scale.json](scale.json) defines progressive experiment sizes and required
measurements for the growing profile. These are test datasets, not service SLOs
or claims that the legacy profile supports them.

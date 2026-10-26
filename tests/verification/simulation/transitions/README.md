# Generated transitions

```sh
just test::properties
just test::properties --seeds 128 --steps 128
just test::properties --trace .cache/verification/transitions/failure.json
```

[transition_driver.zig](transition_driver.zig) executes `Engine(Store)` with
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

The additive `resource` trace profile also generates captured-view opening and
closure, independent resource grants, atomic KV/input publication, clock rollback,
uncertainty and expiry. Its separate oracle tracks one value and one view; replay
compares the entire actual authority after every boundary. Saved schedules check
that prepared publication can win after its validation deadline at an unchanged
tail, while fresh retry must validate current time. Lost-reply retries disclose
only the original receipt under current resource rights, even after view release.
Generation preserves the original inline xorshift sequence and names the added
resource generator separately. Failure artifacts retain both the original and
minimized actions; successful evidence identifies the revision and binary hash.

The generator does not model finite process settlement, checkpoint pages or
concurrent native handles. Existing focused tests still own those obligations.
The in-memory fault store assumes conditional
append atomicity and is not a substitute for Ursula disk qualification.


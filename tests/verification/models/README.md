# Finite authority model

Run `just test::model`; use `just test::model --tail 5` for the larger exploration.
TLC comes from the repository's locked nixpkgs (TLA+ 1.7.4, TLC 2.19). It runs
with one worker, fixed fingerprint/seed, a 512 MiB heap and a 60-second limit per
configuration. Tool errors, timeout, missing queue completion or unmapped traces
are inconclusive failures, never proof success.

## Meaning and bounds

[Authority.tla](Authority.tla) models two preparation slots sharing one principal,
two ordered inputs, replaceable activation generations, current permission,
conditional journal publication, lost acknowledgements and exact receipt retry.
Logical time has three values: before work cutoff, settlement only, and closed
settlement time. Process retirement and connector attempt closure are distinct.
An authorized external attempt may still run remotely after local closure.

Validation happens during preparation. Advancing time alone does not cancel a
prepared append; a competing durable closure invalidates its compared tail.
This matches Transit's validation-at-tail contract rather than promising an
atomic wall-clock check in Ursula. The effect submodel checks authorized result
acceptance and terminal closure; it omits transport and remote-system behavior.

The normal configuration bounds journal-changing actions at three. It exhausts
7,867 distinct states; four permits 30,140. These counts include observations and
preparation changes that do not advance the journal. Deadlock checking is disabled
because reaching the exploration bound is an intentional terminal condition.
No liveness theorem is claimed. Progress would require explicit fairness,
available storage/control capacity and connector assumptions.

## Negative controls and implementation correspondence

[model.py](../model.py) also removes the tail, generation, permission and closure
guard independently. Every variant must produce an invariant violation, not a
parser/build error. The pinned TLC emits text counterexamples; the runner
extracts the explicit `last` action from each state, converts scheduler-slot
actions into the concrete trace format, and runs those schedules against the real
Zig engine. The normal implementation must reject the bad path and agree with
the independent state projection. Trace translation fails on unknown actions.

The bridge currently covers those four authority counterexamples. It does not
claim a refinement proof, conformance for every effect/time path, view expiry,
authenticated network traffic, WAL durability, checkpoints, paged materialization,
host-language ownership or arbitrary cluster size. Those remain separately owned
proofs in the [inventory](../invariants.json). State hashes have TLC's documented
collision limits. See the [TLC documentation](https://docs.tlapl.us/using:tlc:start)
for model-checking scope and [the pinned release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4).

Logs, completion evidence and concrete counterexamples are retained under
`.cache/verification/model/`. The ordinary bindings lane runs the small model;
weekly discovery expands it and runs targeted mutations of the actual Zig guards.

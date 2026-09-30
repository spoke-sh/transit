# Verification and the limits of evidence

The question for an architectural claim is which observation or argument could
support or refute it. This account consolidates testing and conformance reasoning.
The [verification reference](../reference/verification.md) describes user-relevant
guarantees, while the [proof ledger](../../tests/README.md) owns executed commands
and results. The [scientific standard](standard.md) governs how accounts present
that evidence.

## From claim to experiment

An invariant needs an owner, explicit preconditions, a supported profile and
observable forbidden outcomes. A useful scenario specifies the action/fault
schedule and inspects durable consequences, not just eventual output. For
example, a lost-acknowledgement test must distinguish duplicate admission from
two observations of the same accepted identity.

The [machine-readable inventory](../../tests/verification/invariants.json) maps
claims to implementation and scenarios. It prevents a large test count from
substituting for coverage of a particular failure boundary.

## Evidence layers

| Method | What it can establish | Correspondence or limit to state |
| --- | --- | --- |
| Schema/ABI drift and static checks | Agreement between generated boundaries and their owners | Agreement alone does not prove runtime behavior |
| Deterministic units | Transition, rollback, codec, allocation and bound behavior for tested inputs | Test stores and clocks model assumptions supplied elsewhere |
| Generated schedules and saved counterexamples | Invariants over explored stateful traces | Generator version, seed/trace, bounds and search completeness |
| Finite models and selected theorems | Properties of the stated formal model | Model/implementation correspondence and explicit assumptions |
| Independent client/codec fixtures | Agreement across a separately encoded boundary | Qualified values, malformed cases, hosts and ownership scopes |
| Real service/storage/provider faults | Behavior of the actual tested integration | Revision, topology, durable store, fault schedule and cleanup |
| Browser and installed-consumer checks | Observable UI/host behavior and packaging boundaries | Selected routes, platforms and scenarios, not universal compatibility |

These methods complement one another. A deterministic fake cannot establish
disk durability, while a successful disk run cannot exhaust all interleavings.
A theorem about a query rewrite cannot establish the safety of every engine
operation or enable an optimizer transformation by implication.

## Reproducibility

Record the source/toolchain/provider revisions, commands, environment, workload,
configuration, topology and seeds or saved traces. Keep expected and observed
outcomes separate. Preserve failures and incomplete runs alongside final results;
changing a fixture or bound changes the experiment.

Fault injection should distinguish preparation, conditional acceptance,
acknowledgement loss, restart and observation. Negative controls must make a
forbidden outcome observable. Replay/checkpoint comparisons should use the
specified recovery projection, since maintenance may legitimately change
physical records without changing accepted application work.

Measurements also require units, sampling/repetition and variability. Separate
setup from scenario time, cold from warm behavior and local cost from hosted
cost. A single observed duration is neither a distribution nor a service target.

## Verification cost and limits

Small finite scenarios can explore boundaries efficiently, but their bounds must
not become fixed total-capacity limits in production. Keep deterministic checks,
host matrices and physical recovery tests independently selectable. Reuse built
artifacts where safe while keeping mutable authority isolated between scenarios.
Clean-checkout and installed-consumer checks expose dependencies hidden by local
outputs; they are distinct from ordinary incremental tests.

Use the [verification harness guide](../../tests/verification/README.md),
[test commands](../../tests/README.md#running-checks) and
[evidence-recording rules](../../tests/README.md#recording-new-evidence) to reproduce
or extend a claim. This documentation consolidation adds no runtime qualification.
Historical [testing](../history/TESTING.md) and
[conformance](../history/CONFORMANCE.md) records preserve earlier scope and
unexecuted requirements; requirements are not passing evidence.

# Verification and the limits of evidence

The question for an architectural claim is which observation or argument could
support or refute it. This account consolidates testing and conformance reasoning.
The [verification reference](../reference/verification.md) describes user-relevant
guarantees, while the [proof ledger](../../../tests/README.md) owns executed commands
and results. The [scientific standard](standard.md) governs how accounts present
that evidence.

## From claim to experiment

An invariant needs an owner, explicit preconditions, a supported profile and
observable forbidden outcomes. A useful scenario specifies the action/fault
schedule and inspects durable consequences, not just eventual output. For
example, a lost-acknowledgement test must distinguish duplicate admission from
two observations of the same accepted identity.

For a data operation, start with the declared schema or computation, its policy
and bound inputs. Inspect the accepted definition, complete data/result and
attributed progress before and after the fault. An independent oracle can
challenge the relationship between those observations. Compiler acceptance,
worker health and a successful HTTP response each test a narrower boundary;
none alone establishes that Transit fulfilled the declaration. A maintained
result needs comparison with finite recomputation at the same source basis.

The [machine-readable inventory](../../../tests/verification/invariants.json) maps
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

## Simulation model and progress

The [authority/delivery driver](../../../tests/delivery_simulation.zig) runs the actual
Zig engine for two producer PIDs and one destination. Eight test-only slots hold
frozen signed requests and prepared decisions; event order controls when those
decisions publish, retry or become stale. These slots model delayed work, not a
production queue or a durable worker stack. The in-memory journal assumes atomic
conditional append and distinguishes failure before acceptance from response loss
after acceptance. Its immutable page store does not model disk faults.

After each event, the driver refreshes the live engine and compares its logical
projection with a separately recovered engine, retaining the original live cache.
The [independent oracle](../../../tests/verification/simulation.py) tracks mailbox
progress, ownership, current permissions, signed-operation identity, route order
and output provenance without sharing the core's page tree or route indexes.
A disagreement in either comparison refutes correspondence for that trace.
Replaying the same concrete events must produce identical observations.

Generated traces end with an explicit progress phase. It restores worker/courier
permissions, admits no new input, schedules every eligible producer turn, and
resolves pending routes in order. Retired producers stay retired; their pending
outputs receive terminal disposition. Storage is available and each selected
operation receives a scheduling opportunity. Failure to drain refutes bounded
progress under those assumptions. This does not establish automatic scheduler
fairness, continuous-load progress, timer delivery or a liveness theorem.

The modeled storage boundary allows fast reproducible schedules but excludes
real transport, provider persistence and host-runtime behavior. External testing
of compiled binaries addresses those separate obligations. TigerBeetle describes
the same complementary motivation in its
[Vortex account](https://tigerbeetle.com/blog/2025-02-13-a-descent-into-the-vortex/),
while its [liveness account](https://tigerbeetle.com/blog/2023-07-06-simulation-testing-for-liveness/)
motivates stabilizing required dependencies before expecting progress. Transit's
finite explicit scheduler is narrower than that cluster simulation.

The [harness guide](../../../tests/verification/README.md#authority-and-delivery-simulation)
owns bounds, reproduction and negative controls. The
[simulation evidence](../../../tests/README.md#authority-and-delivery-simulation)
records executed results; no timing here establishes deployed throughput or latency.

## Resource publication under I/O faults

The question is whether interruption between immutable staging and authoritative
publication can expose only part of a turn. The
[resource driver](../../../tests/resource_simulation.zig) executes the real core with
one resource writer, a single key, captured views and an output to the same PID.
Its [provider model](../../../tests/simulation_store.zig) has an atomic journal,
retained immutable pages and a two-slot volatile page cache. It includes the
batched staging interface: an interrupted batch can retain orphan pages while
returning no successful publication. Neither journal trimming nor eviction
removes required immutable pages.

The [independent oracle](../../../tests/verification/resource_simulation.py) extends
the existing logical resource model with captured values, output provenance and
the accepted history floor. Rejected staging must leave all published projections
unchanged. Lost journal acknowledgements retain accepted state and the original
retry identity. The driver compares live observations with cold recovery after
every event and rejects any recovery-time staging. These comparisons can refute
atomic publication or retained-root recovery within the modeled boundary.

A successful control trace measures reachable I/O call coordinates. Exploration
injects a fault at the first, middle and last call of each eligible event; an
explicit exhaustive mode visits every measured call. Each requested fault must
fire. Coordinates choose the disturbance only: expected logical state comes from
the separate oracle, never from the control run's state. Faults last one event;
an explicit available-storage suffix drains accepted producer input and repeats
checkpoint/trim/recovery. Pending outputs remain recorded for separate delivery
checks. This is a finite recovery schedule, not scheduler fairness.

Saved traces keep a small ordinary regression budget; broader enumeration is a
focused experiment. Full traces, bounded minimized correspondence failures,
source/compiler/binary/oracle identity and incomplete-run status are retained.
Mutation checks omit actual resource writes or input progress to challenge the
oracle. Physical WAL, page deletion/GC and arbitrary corruption remain outside
this model. See the [harness guide](../../../tests/verification/README.md#resource-publication-simulation)
for reproducible commands and the [proof ledger](../../../tests/README.md) for executed
results and costs.

## Shared-client scheduling

The [scheduler driver](../../../tests/scheduler_simulation.zig) instantiates the
production `SessionWithTransport` with a signed in-process transport and invokes
the same courier step as the delivery executable. A worker event either captures
a private proposal or submits its previously frozen request. Scheduling can
interleave other actors, policy/ownership changes or restart between those steps.
The transport distinguishes loss before a query/submit from loss after processing;
it validates responses but does not implement HTTP or native client deadlines.

The [checker](../../../tests/verification/scheduler_simulation.py) constructs admitted
input sequences from trace commands independently of the core. Each consumed
prefix must account for the original outputs; each delivered output must account
for exactly one destination input with its original provenance. Denials cannot
advance authority, terminal output dispositions cannot reopen, and an uncertain
pending request must retain its digest until reconciliation or explicit host loss.
Saved rejection schedules challenge Session fencing and current authorization.
A separate finite-lifetime schedule exercises recorded turn permits through the
work cutoff, expiry maintenance, trim/recovery and untrusted/rolled-back clocks.

Generated fault-heavy schedules stop admitting work, then explicitly grant twenty
round-robin opportunities to the two Sessions and courier. Each has a bounded
initial workload of four inputs; preparation and submission take separate
opportunities. A final drain assertion tests progress under that supplied fair
schedule. It establishes neither OS fairness nor async cancellation/join safety.
Cold recovery and complete replay must agree after every event. Shared-code
mutations remove Session activation validation or discard an uncertain courier
request, challenging the checks separately from transport fidelity. The real
caller/courier integration proof retains responsibility for the actual binaries.

## Reproducibility

The [external supervisor](../../../tests/verification/vortex.py) tests whether those
boundaries compose in real processes. An HTTP peer records signed requests and
actual replies while injecting loss or delay. The same accepted principal/sequence
must have the same request digest and receipt. A killed worker may lose its local
pending bytes; recovery reads current history before any subsequent work.
The courier must retry the deliberately lost receipt before its next restart.
Public observations after each bounded round check the independent cumulative
counter, one original output per input and one destination admission per output.
Pagination fixes one authority position; rows cannot mix successive cuts.

The supervisor uses owned processes and the existing disk Ursula fixture. It
records requested signals separately from observed stops/exits, joins its proxy
and children, and retains history, logs, binary identities and incomplete status.
Its four-round ordinary workload always exercises all four network fault classes;
the bounded extended workload repeats those classes with seeded values/delays.
Observation occurs after workers stop, so this oracle establishes quiescent
atomic correspondence, not a linearizability proof for arbitrary concurrent reads.
SIGKILL establishes process-crash recovery under the provider contract, not power
loss, corrupt media or rollback restoration.

The [profile runner](../../../tests/verification/external_profiles.py) keeps installed
SDK, application, query and browser/reactive experiments separate. Existing rigs
own their public operations, assertions and cleanup; the runner records exact
commands, deadlines, logs and stage completion. Python and Node drivers additionally
retain signed request/reply histories and actual host-ownership observations.
Installing their artifacts outside the repository challenges packaging assumptions
that shared Zig simulation cannot reach. Provider adapter fixtures do not certify
an actual Kubernetes placement. An interrupted or skipped profile remains incomplete.

The [component runner](../../../tests/verification/domain_simulation.py) asks a
narrower question: do independently stated contract properties survive reordered
edits, discarded private turns and repeated recovery boundaries in each owner?
It invokes filtered tests in the real Document, Exchange, serving and core packages.
The Document oracle expects an explicit four-assignment set independent of arrival
order; its checkpoint oracle holds the old revision/floor until final publication.
Exchange tests distinguish complete captured bytes from a closed-unknown native
outcome and refuse retirement until replay holds are released. Refresh tests
compare exact source identity and data coverage across in-flight mutations, and
reject stale acknowledgements after selection replacement. Runtime tests require
an accepted activation after provider readiness; repeated unknown observations
cannot acquire ownership or consume backlog.

The bounded schedules use the pinned compiler's PRNG, record their actual choices,
and replay twice. Component-specific compiling mutations challenge each oracle.
They are seeded package experiments, not the general JSON event simulator: replay
requires the recorded seed and same binary; arbitrary event editing and automatic
minimization are not implemented for this profile. Private-turn stores assume
atomic publication. Application installation, physical placement, host scheduling
and real transport retain their separate integration proofs.

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

Use the [verification harness guide](../../../tests/verification/README.md),
[test commands](../../../tests/README.md#running-checks) and
[evidence-recording rules](../../../tests/README.md#recording-new-evidence) to reproduce
or extend a claim. This documentation consolidation adds no runtime qualification.
Historical [testing](../../history/TESTING.md) and
[conformance](../../history/CONFORMANCE.md) records preserve earlier scope and
unexecuted requirements; requirements are not passing evidence.

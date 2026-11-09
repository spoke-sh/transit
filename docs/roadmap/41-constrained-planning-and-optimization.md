# 41. Constrained planning and attributable optimization

[Roadmap](README.md) · **Status:** Planned

Let applications evaluate proposed schedules, allocations or routes against
versioned constraints and objectives, inspect candidate quality and termination
evidence, then review publication separately from operational execution. Initial
workloads include production/maintenance scheduling and capacity planning.

This is planned computation-lifecycle work. A completed query, branch or worker
does not establish a feasible plan, an optimal solution or safe external action.

## Prerequisites and ownership

Consume [captured/managed computations](13-sql-and-dataflows.md),
[bounded execution](14-data-structures-and-performance.md),
[branches](21-branches-merges-and-restore.md),
[investigations](29-published-resources-and-investigations.md),
[reviewed publication](30-reviewed-data-collaboration.md),
[numerical/derivation contracts](36-scientific-arrays-and-measurements.md),
[deductive rules and Datalog fixpoints](42-deductive-rules-datalog-and-equivalence-graphs.md) and
[hardware design and EDA verification](43-hardware-design-rtl-and-eda-verification.md).
Spatial routing additionally requires the qualified M17/M18 operators; hardware floorplanning, placement, routing and timing-closure optimization combine this milestone's candidate/bound lifecycle with M41's deductive constraint pruning and M42's `.layout_manhattan` and netlist verification rules.
Reuse [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md),
[investigation](../../contracts/INVESTIGATION_V1.md) and
[branch publication](../../contracts/BRANCH_V1.md) contracts; follow public
[queries](../handbook/reference/queries.md),
[applications](../handbook/reference/applications.md) and
[effects](../handbook/reference/connectors.md).

Applications own domain constraints, objectives, solver selection and operational
policy. Transit owns generic accepted-work recovery, bound inputs, candidate
storage and publication. Specialized solvers run in qualified application workers;
the kernel gains no solver or trading policy. External solver services use the
recorded connector boundary.

## Delivery sequence

1. **Freeze the problem and run.** Bind variables/domains, constraints, objective
   direction/priority, units, input basis, solver/executable/version, tolerances,
   seed, resource limits and warm-start/checkpoint references. Reject incompatible
   units or interpretations before dispatch. Problem, run, attempt and candidate
   identities remain separate; changed inputs create a successor problem/run.
2. **Define typed optimization outcomes.** Distinguish feasible candidate,
   certified optimal under declared tolerances, proven infeasible, unbounded where
   applicable, invalid problem and unknown/incomplete search. Bind candidate
   objective, best known bound/gap, verification evidence and termination reason
   when available. Budget exhaustion or a worker's successful exit cannot upgrade
   feasibility to optimality or unknown to infeasible. Keep solver claims separate
   from independently checked feasibility/certificates and their trust scope.
3. **Publish bounded progress and recoverable candidates.** Store immutable
   incumbents, explicit source basis and checkpoint compatibility. Replace a
   visible candidate only after complete publication; retain the prior complete
   candidate while a successor is pending. Define early close, cancellation races,
   failed attempts and original-operation settlement. A resumable checkpoint must
   bind the same problem and compatible executor; never splice a new problem
   into earlier progress or blindly repeat uncertain remote requests.
4. **Compare scenarios and validate candidates.** Use branches for proposed data
   changes, shared constraints and independent feasibility checking. Incremental
   preprocessing or warm starts require their own validity conditions; arbitrary
   optimization is not a linear DBSP update. Show which constraints changed and
   why a candidate became invalid. Report conflicts and incomplete explanations
   rather than inventing a minimal unsatisfiable subset or causal explanation.
5. **Review publication and record consequences.** Bind approval to the exact
   candidate, problem and destination expectations. Revalidate applicable live
   constraints before conditional publication; a moved destination can stale the
   review. Publishing a plan does not dispatch machines, staff or shipments.
   External actions have separately authorized recorded intents and outcomes.
   Later observations compare actual outcomes with the original prediction.

## Transport and orbital planning

[Issue #358](https://github.com/spoke-sh/transit/issues/358) adds FLIGHTPLAN
intermodal/cold-chain transport and D.A.L.E cislunar/interplanetary logistics to
this milestone's planned workload. Consume the exact
[M19 TD-RCSP transition/search contract](19-multi-model-and-foreign-relations.md#time-dependent-resource-constrained-routing),
[M18 frame/trajectory profile](18-geospatial-and-spatio-temporal-computing.md#celestial-frames-and-orbital-logistics--issue-358)
and [M13 knowledge/propagation-time joins](13-sql-and-dataflows.md#propagation-delay-and-knowledge-time-joins).
Generic route search does not depend on this whole milestone; coupled fleet,
capacity, depot and mission optimization adds the candidate/bound lifecycle here.

Freeze time-window and resource-transition definitions with the problem. Include
branch-and-bound frontier/incumbent state, bound validity and original-run
checkpoint recovery for time- and vehicle-state-dependent costs. Reuse M18's
proved dominance conditions; replenishment, waiting and duty resets can invalidate
simple resource ordering. Changed forecasts, ephemerides, vehicle mass, constraints
or solver semantics create a successor problem instead of retargeting a run.

Define shared deterministic numerical helper contracts before Fuze/solver
adapters. Bind units, domains, rounding, overflow, accumulation and error rules
for Tsiolkovsky burn
`delta_m = m0 * (1 - exp(-delta_v / (Isp * g0)))`, cryogenic boil-off integration
and cumulative degree-minute cold-chain excursions. Evaluate transcendental
terms with a pinned, error-bounded method, then explicitly round to the declared
integer/fixed-point ledger quantum. Preserve exact ledger balance
`m_before = m_after + m_consumed`, nonnegative propellant and the dry-mass floor;
fixed-point storage does not make the physical model or exponential exact.
Specify residual handling across repeated burns, no-op burns, infeasible burns,
signed-velocity versus nonnegative delta-v magnitude, and invalid `Isp`/time/rate.
Boil-off and thermal integration bind the sampled/interpolated rate model,
threshold, interval coverage and integration error, including gaps and resets.
Near a feasibility threshold, refine or report unknown if error bounds straddle
the constraint; rounding must not manufacture a feasible route.

Qualify Hohmann/Lambert transfer-cost profiles with explicit central-body model,
time of flight, solution branch, units and tolerances. Bound iterations and
report absent/ambiguous/unconverged solutions. These are pure model evaluations
in Fuze or qualified application workers, not kernel policy or external dispatch.
Three-body and powered-flight models require their own declared evidence.

Independently check small multimodal schedules and orbital depot/transfer plans,
including waiting costs, HOS resets, boil-off, dry-mass exhaustion and cold-chain
limits. Compare numerical helpers to high-precision independent calculations and
route candidates to M18's exhaustive oracle; verify conservation after every
transition. Kill/restart search before and after an incumbent, lose publication
replies and race cancellation with completion. Preserve the original candidate,
bound and termination evidence. Approval and publication never dispatch a flight,
shipment or spacecraft; separately authorized effects retain their own outcomes.

## Acceptance and qualification

An application captures machine availability and maintenance constraints, proposes
a schedule on a branch, obtains a feasible candidate within a budget and shows its
bound/termination evidence. A source change invalidates that candidate; a successor
is evaluated and reviewed without relabeling the earlier result. Publish only
against the approved destination basis, then capture execution observations.

- Use small independently enumerable problems to check candidate feasibility,
  objective direction, bounds, infeasibility and selected optimality claims.
  Verify numeric rounding/tolerance and multi-objective interpretation explicitly.
- Stop runs before any candidate and after a feasible incumbent; expose unknown
  or budget termination without false infeasibility/optimality. Challenge invalid
  bounds, corrupted certificates and incompatible warm starts/checkpoints.
- Lose submission/publication replies, kill workers and race cancellation with
  completion. Recover the original outcome; no partial candidate becomes complete.
- Exercise stale approvals, revocation after buffering, conflicting source edits,
  missing retained inputs and memory/time/storage exhaustion under mixed load.
- Record time to first feasible candidate, verified objective/bound/gap at fixed
  budgets, recovery costs and publication latency. Compare solver results only
  for identical problems, resource limits and numerical semantics.

## Primary reference

[CP-SAT solver outcomes](https://developers.google.com/optimization/cp/cp_solver)
illustrate the distinction among feasible, optimal, infeasible, invalid and
unknown results. This is a contract reference, not a mandated solver dependency
or a claim that every solver supplies verifiable optimality certificates.

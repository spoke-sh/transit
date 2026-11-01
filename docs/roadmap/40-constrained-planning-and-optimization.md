# 40. Constrained planning and attributable optimization

[Roadmap](README.md) · **Status:** Planned

Let applications evaluate proposed schedules, allocations or routes against
versioned constraints and objectives, inspect candidate quality and termination
evidence, then review publication separately from operational execution. Initial
workloads include production/maintenance scheduling and capacity planning.

This is planned computation-lifecycle work. A completed query, branch or worker
does not establish a feasible plan, an optimal solution or safe external action.

## Prerequisites and ownership

Consume [captured/managed computations](12-sql-and-dataflows.md),
[bounded execution](13-data-structures-and-performance.md),
[branches](20-branches-merges-and-restore.md),
[investigations](28-published-resources-and-investigations.md),
[reviewed publication](29-reviewed-data-collaboration.md) and
[numerical/derivation contracts](35-scientific-arrays-and-measurements.md).
Spatial routing additionally requires the qualified M17/M18 operators.
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

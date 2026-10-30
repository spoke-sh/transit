/-
Candidate rewrite-safety theorem for Fuze's planner, per docs/history/TESTING.md's
Lean scoping ("a Fuze rewrite with exact error semantics") and
docs/history/QUERY_LANGUAGE.md. This formalizes the SPECIFICATION in UNIFIED_QUERY_V1.md
("Filter precedes limit; aggregates consume that limited selection") at the
row-selection level, not the Zig implementation. Model/implementation
correspondence is a separate, stated assumption here, exactly as
Authority.tla's relationship to the real engine is stated separately from
the model itself — this file proves nothing about `transit-fuze`'s Zig code.

The first property reorders two total row-selecting predicates. Additional
M12 theorems below cover projection pruning, filter pushdown through a total
projection with an explicit first-error model, and an unchanged downstream
consumer. They do not model Fuze's actual typed Cell/comparison implementation.

A row is left abstract: the property holds for any row type, independent of
Fuze's actual typed key/value representation. Predicates are total boolean
tests per row (no unknown/three-valued logic at this level of abstraction;
UNIFIED_QUERY_V1.md's "comparison with null is unknown and does not select the row"
is already folded into a predicate returning `false` for that case).
-/

variable {Row : Type} (p q : Row → Bool)

/-- Selecting with `p` then `q` selects exactly the rows selecting with
    `q` then `p`, in the same order. This is the safety condition a rule
    reordering two filter stages (a pushed-down predicate ahead of, or
    behind, another) must satisfy to preserve FUZE.md's "specified result
    schema... and ordering" requirement on every rewrite. -/
theorem filter_reorder_preserves_selection (rows : List Row) :
    (rows.filter p).filter q = (rows.filter q).filter p := by
  induction rows with
  | nil => rfl
  | cons r rs ih =>
    simp only [List.filter_cons]
    by_cases hp : p r <;> by_cases hq : q r <;> simp_all

#print axioms filter_reorder_preserves_selection

/-
Projection pruning is safe only when the final output factors through the
retained fields. This premise includes output schema/field order, not merely
set membership. Projection here is total after schema validation; it performs
no decoding, allocation, authorization or effects.
-/
theorem projection_pruning_preserves_rows
    {Input Pruned Output : Type}
    (prune : Input → Pruned) (finish : Pruned → Output) (project : Input → Output)
    (keeps_output : ∀ row, finish (prune row) = project row)
    (rows : List Input) :
    (rows.map prune).map finish = rows.map project := by
  induction rows with
  | nil => rfl
  | cons row rest ih => simp only [List.map_cons, keeps_output, ih]

/-- Deterministic left-to-right filtering with explicit first-error semantics.
    Unlike List.filter, the predicate may fail. Null/unknown selection can be
    represented by .ok false. A failure discards every successful prefix. -/
def selectChecked {Input Failure : Type} (predicate : Input → Except Failure Bool) :
    List Input → Except Failure (List Input)
  | [] => .ok []
  | row :: rest =>
      match predicate row with
      | .error failure => .error failure
      | .ok keep =>
          match selectChecked predicate rest with
          | .error failure => .error failure
          | .ok selected => .ok (if keep then row :: selected else selected)

/-- Push filtering before a total projection only if the predicate factors
    through that projection. Both row order and the exact first error survive.
    No premise permits dropping columns required by the predicate. -/
theorem predicate_pushdown_through_projection
    {Input Output Failure : Type}
    (project : Input → Output)
    (before : Input → Except Failure Bool)
    (after : Output → Except Failure Bool)
    (keeps_predicate : ∀ row, before row = after (project row))
    (rows : List Input) :
    (selectChecked before rows).map (List.map project) =
      selectChecked after (rows.map project) := by
  induction rows with
  | nil => rfl
  | cons row rest ih =>
    simp only [selectChecked, List.map_cons, keeps_predicate]
    cases hp : after (project row) with
    | error failure => rfl
    | ok keep =>
      cases hr : selectChecked before rest with
      | error failure =>
        simp only [hr, Except.map] at ih ⊢
        rw [← ih]
      | ok selected =>
        simp only [hr, Except.map] at ih ⊢
        rw [← ih]
        cases keep <;> rfl

/-- Any identical downstream consumer receives identical ordered rows or the
    same earlier failure. This includes a fixed limit and a checked sum fold;
    it does not justify moving either operator across a filter or projection. -/
theorem pushdown_preserves_downstream_errors
    {Input Output Failure Result : Type}
    (project : Input → Output)
    (before : Input → Except Failure Bool)
    (after : Output → Except Failure Bool)
    (keeps_predicate : ∀ row, before row = after (project row))
    (consume : List Output → Except Failure Result)
    (rows : List Input) :
    ((selectChecked before rows).map (List.map project)).bind consume =
      (selectChecked after (rows.map project)).bind consume := by
  rw [predicate_pushdown_through_projection project before after keeps_predicate rows]

#print axioms projection_pruning_preserves_rows
#print axioms predicate_pushdown_through_projection
#print axioms pushdown_preserves_downstream_errors

/-- Deterministic security-barrier RLS filter evaluated before user predicates (`A6`). -/
def filterRlsBarrier {Input : Type} (rlsBarrier : Input → Bool) : List Input → List Input
  | [] => []
  | row :: rest =>
      match rlsBarrier row with
      | true => row :: filterRlsBarrier rlsBarrier rest
      | false => filterRlsBarrier rlsBarrier rest

/-- Security-barrier Row-Level Security (RLS) non-interference (`A6`, `CONTROL_POLICY_PLANE_V1`).
    Evaluating a fallible user predicate (`selectChecked`) after `filterRlsBarrier`
    depends only on rows where `rlsBarrier row = true`. Even if `userPred1` fails with
    `.error failure` (e.g., division-by-zero or 5-state `type_error`) on unauthorized
    rows where `rlsBarrier row = false`, those errors can never leak across the barrier. -/
theorem security_barrier_rls_non_interference
    {Input Failure : Type}
    (rlsBarrier : Input → Bool)
    (userPred1 userPred2 : Input → Except Failure Bool)
    (agrees_on_authorized : ∀ row, rlsBarrier row = true → userPred1 row = userPred2 row)
    (rows : List Input) :
    selectChecked userPred1 (filterRlsBarrier rlsBarrier rows) =
      selectChecked userPred2 (filterRlsBarrier rlsBarrier rows) := by
  induction rows with
  | nil => rfl
  | cons row rest ih =>
    unfold filterRlsBarrier
    have h_eq := agrees_on_authorized row
    cases h : rlsBarrier row with
    | false => exact ih
    | true =>
      have hp : userPred1 row = userPred2 row := h_eq h
      unfold selectChecked
      rw [hp, ih]

/-- Multi-hop delegation attenuation (`A6`, `CONTROL_POLICY_PLANE_V1`):
    an action is permitted across a delegation chain only if the represented
    subject permits it and every delegation hop permits it. -/
def evaluateDelegated {Action : Type}
    (subjectPermits : Action → Bool)
    (hopPermits : Action → Bool)
    (a : Action) : Bool :=
  subjectPermits a && hopPermits a

theorem delegation_attenuation_sound
    {Action : Type}
    (subjectPermits : Action → Bool)
    (hopPermits : Action → Bool)
    (a : Action)
    (h_ok : evaluateDelegated subjectPermits hopPermits a = true) :
    subjectPermits a = true ∧ hopPermits a = true := by
  unfold evaluateDelegated at h_ok
  cases hs : subjectPermits a <;> cases hh : hopPermits a <;> simp_all

/-- Human-only approval non-delegability (`A6`, `CONTROL_POLICY_PLANE_V1`):
    any request carrying a delegation (`hasDelegation = true`) cannot exercise
    human-only approval authority, regardless of multi-factor assurance. -/
def canExerciseHumanOnlyApproval (hasDelegation isHumanMultiFactor : Bool) : Bool :=
  (!hasDelegation) && isHumanMultiFactor

theorem delegated_agent_cannot_approve (isHumanMultiFactor : Bool) :
    canExerciseHumanOnlyApproval true isHumanMultiFactor = false := by
  rfl

#print axioms security_barrier_rls_non_interference
#print axioms delegation_attenuation_sound
#print axioms delegated_agent_cannot_approve

/-
Model/implementation correspondence assumptions:
* Plan.bind / Stream.Plan.bind validate column identities and literal types
  before execution. Schema and source revision remain fixed; current authority
  is supplied/revalidated by Station, not by these functions or this proof.
* Plan.matches implements a total row predicate on those validated Cells.
  A comparison involving null selects false; is_null is a separate predicate.
  The abstract filter_reorder theorem applies only to that total domain.
* Row projection copies selected cells in declared order after filtering.
  Projection pruning must retain predicate dependencies until their last use.
* Stream.step retains primary-key order and applies the whole-query limit
  after filtering; its sum includes the previous page's carry in ordered input.
  The downstream theorem preserves an unchanged fallible fold, not arithmetic
  reassociation, page-sum combination, or Postgres's numeric SUM semantics.
* Allocation failure, cancellation checkpoints, read permissions and retained
  source availability are not modeled. A real rewrite must separately preserve
  those behaviors; no optimizer rewrites are enabled by this proof.

Deferred: limit pushdown (generally false across filtering), sum reassociation
(false for checked int64 overflow), rewrites of partial/effectful projections
(require additional error/order premises), and mechanized correspondence with
Zig/Arrow. There are no sorry placeholders for any of these non-claims.
-/

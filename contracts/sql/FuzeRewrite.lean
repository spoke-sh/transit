/-
Candidate rewrite-safety theorem for Fuze's planner, per docs/TESTING.md's
Lean scoping ("a Fuze rewrite with exact error semantics") and
docs/QUERY_LANGUAGE.md. This formalizes the SPECIFICATION in FUZE_V1.md
("Filter precedes limit; aggregates consume that limited selection") at the
row-selection level, not the Zig implementation. Model/implementation
correspondence is a separate, stated assumption here, exactly as
Authority.tla's relationship to the real engine is stated separately from
the model itself — this file proves nothing about `transit-fuze`'s Zig code.

Scope: one property — reordering two sequential row-selecting predicates
(e.g. a pushed-down filter applied before or after another) never changes
the selected rows or their order. This is the correctness argument a real
predicate-pushdown rewrite rule needs; it does not model projection,
aggregation, limits, or Fuze's actual typed Cell/comparison semantics.

A row is left abstract: the property holds for any row type, independent of
Fuze's actual typed key/value representation. Predicates are total boolean
tests per row (no unknown/three-valued logic at this level of abstraction;
FUZE_V1.md's "comparison with null is unknown and does not select the row"
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

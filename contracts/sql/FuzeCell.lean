/-
Formal specification of Fuze's 5-state Cell lattice (value, null, missing,
type_error, conflict) and 3-valued Kleene/SQL predicate evaluation, per
packages/zig/transit-fuze/src/Types.zig and TablePredicate.zig (FUZE-CELL-01,
FUZE-PRED-01).
-/

inductive Cell (Val Err : Type) where
  | value : Val → Cell Val Err
  | null : Cell Val Err
  | missing : Cell Val Err
  | typeError : Err → Cell Val Err
  | conflict : Err → Cell Val Err
  deriving DecidableEq, Repr

inductive CellFailure (Err : Type) where
  | typeError : Err → CellFailure Err
  | conflict : Err → CellFailure Err
  deriving DecidableEq, Repr

inductive Truth3 where
  | tTrue : Truth3
  | tFalse : Truth3
  | tUnknown : Truth3
  deriving DecidableEq, Repr

def Truth3.not : Truth3 → Truth3
  | .tTrue => .tFalse
  | .tFalse => .tTrue
  | .tUnknown => .tUnknown

def Truth3.and : Truth3 → Truth3 → Truth3
  | .tFalse, _ => .tFalse
  | _, .tFalse => .tFalse
  | .tTrue, .tTrue => .tTrue
  | _, _ => .tUnknown

def Truth3.or : Truth3 → Truth3 → Truth3
  | .tTrue, _ => .tTrue
  | _, .tTrue => .tTrue
  | .tFalse, .tFalse => .tFalse
  | _, _ => .tUnknown

def Truth3.toWhereBool : Truth3 → Bool
  | .tTrue => true
  | .tFalse => false
  | .tUnknown => false

/-- Map a boolean-typed 5-state Cell to 3-valued Kleene truth or an explicit
    diagnostic failure. Both `null` and `missing` evaluate to `tUnknown`, while
    `typeError` and `conflict` never silently coerce to `false` or `null`. -/
def Cell.toTruth3 {Err : Type} : Cell Bool Err → Except (CellFailure Err) Truth3
  | .value true => .ok .tTrue
  | .value false => .ok .tFalse
  | .null => .ok .tUnknown
  | .missing => .ok .tUnknown
  | .typeError e => .error (.typeError e)
  | .conflict e => .error (.conflict e)

/-- Kleene AND is commutative on all 3-valued inputs (including `null` and `missing`). -/
theorem kleene_and_comm (a b : Truth3) : Truth3.and a b = Truth3.and b a := by
  cases a <;> cases b <;> rfl

/-- Kleene OR is commutative on all 3-valued inputs. -/
theorem kleene_or_comm (a b : Truth3) : Truth3.or a b = Truth3.or b a := by
  cases a <;> cases b <;> rfl

/-- De Morgan duality holds across the 3-valued Kleene lattice. -/
theorem kleene_de_morgan_and (a b : Truth3) :
    Truth3.not (Truth3.and a b) = Truth3.or (Truth3.not a) (Truth3.not b) := by
  cases a <;> cases b <;> rfl

/-- `typeError` and `conflict` cells never masquerade as a valid WHERE selection
    outcome (neither `true` nor `false`). -/
theorem cell_error_never_selects {Err : Type} (c : Cell Bool Err)
    (h : ∀ b, c ≠ .value b ∧ c ≠ .null ∧ c ≠ .missing) :
    ∀ t, c.toTruth3 ≠ .ok t := by
  intro t
  cases c with
  | value b => exact False.elim ((h b).1 rfl)
  | null => exact False.elim ((h true).2.1 rfl)
  | missing => exact False.elim ((h true).2.2 rfl)
  | typeError e => intro hc; injection hc
  | conflict e => intro hc; injection hc

/-- SQL equality on non-error cells returns `tUnknown` when either operand is
    `null` or `missing`, whereas `IS NOT DISTINCT FROM` is reflexive across
    `value`, `null`, and `missing`. -/
def cellEq {Val Err : Type} [DecidableEq Val] :
    Cell Val Err → Cell Val Err → Except (CellFailure Err) Truth3
  | .typeError e, _ => .error (.typeError e)
  | .conflict e, _ => .error (.conflict e)
  | _, .typeError e => .error (.typeError e)
  | _, .conflict e => .error (.conflict e)
  | .value a, .value b => .ok (if a = b then .tTrue else .tFalse)
  | _, _ => .ok .tUnknown

def isNotDistinctFrom {Val Err : Type} [DecidableEq Val] :
    Cell Val Err → Cell Val Err → Except (CellFailure Err) Bool
  | .typeError e, _ => .error (.typeError e)
  | .conflict e, _ => .error (.conflict e)
  | _, .typeError e => .error (.typeError e)
  | _, .conflict e => .error (.conflict e)
  | .value a, .value b => .ok (a = b)
  | .null, .null => .ok true
  | .missing, .missing => .ok true
  | _, _ => .ok false

theorem is_not_distinct_from_refl {Val Err : Type} [DecidableEq Val]
    (c : Cell Val Err)
    (h_no_err : ∀ e, c ≠ .typeError e ∧ c ≠ .conflict e) :
    isNotDistinctFrom c c = .ok true := by
  cases c with
  | value v => simp [isNotDistinctFrom]
  | null => rfl
  | missing => rfl
  | typeError e => exact False.elim ((h_no_err e).1 rfl)
  | conflict e => exact False.elim ((h_no_err e).2 rfl)

theorem toWhereBool_and (a b : Truth3) :
    (Truth3.and a b).toWhereBool = (a.toWhereBool && b.toWhereBool) := by
  cases a <;> cases b <;> rfl

/-- Coalescing 3-valued truth at the `WHERE` filter boundary turns `tUnknown`
    into `false`, so filtering by `Truth3.and (p r) (q r)` selects the exact
    same rows as sequential `WHERE` filtering by `p` then `q`. -/
theorem where_and_equiv_sequential {Row : Type} (p q : Row → Truth3) (rows : List Row) :
    rows.filter (fun r => (Truth3.and (p r) (q r)).toWhereBool) =
      (rows.filter (fun r => (p r).toWhereBool)).filter (fun r => (q r).toWhereBool) := by
  induction rows with
  | nil => rfl
  | cons r rs ih =>
    simp only [List.filter_cons]
    rw [toWhereBool_and (p r) (q r)]
    by_cases hp : (p r).toWhereBool <;> by_cases hq : (q r).toWhereBool <;> simp_all

#print axioms kleene_and_comm
#print axioms kleene_or_comm
#print axioms kleene_de_morgan_and
#print axioms cell_error_never_selects
#print axioms is_not_distinct_from_refl
#print axioms where_and_equiv_sequential

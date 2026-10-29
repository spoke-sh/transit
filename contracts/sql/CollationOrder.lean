/-
Formal specification of Collation-governed total preorders, Umbra 4-byte prefix
monotonicity, and zone-map range pruning soundness, per
packages/zig/transit-fuze/src/Collation.zig, OrderedKeyIndex.zig, and
SegmentFormat.zig (COLLATION-01).
-/

/-- A collation `κ` maps each logical value to a canonical sort key in `Nat`. -/
structure Collation (Val : Type) where
  sortKey : Val → Nat

def Collation.le {Val : Type} (κ : Collation Val) (a b : Val) : Prop :=
  κ.sortKey a ≤ κ.sortKey b

def Collation.lt {Val : Type} (κ : Collation Val) (a b : Val) : Prop :=
  κ.sortKey a < κ.sortKey b

def Collation.eq {Val : Type} (κ : Collation Val) (a b : Val) : Prop :=
  κ.sortKey a = κ.sortKey b

theorem collation_le_refl {Val : Type} (κ : Collation Val) (a : Val) :
    κ.le a a := Nat.le_refl (κ.sortKey a)

theorem collation_le_trans {Val : Type} (κ : Collation Val) {a b c : Val}
    (hab : κ.le a b) (hbc : κ.le b c) : κ.le a c :=
  Nat.le_trans hab hbc

theorem collation_le_total {Val : Type} (κ : Collation Val) (a b : Val) :
    κ.le a b ∨ κ.le b a :=
  Nat.le_total (κ.sortKey a) (κ.sortKey b)

/-- A monotone 4-byte Umbra prefix extraction (`prefix4`) preserves non-strict
    inequality and reflects strict inequality back to the full collated sort key. -/
theorem umbra_prefix_reflects_lt {Val : Type} (κ : Collation Val)
    (prefix4 : Nat → Nat)
    (h_mono : ∀ x y : Nat, x ≤ y → prefix4 x ≤ prefix4 y)
    {a b : Val}
    (h_lt : prefix4 (κ.sortKey a) < prefix4 (κ.sortKey b)) :
    κ.lt a b := by
  rcases Nat.lt_or_ge (κ.sortKey a) (κ.sortKey b) with h | h_ge
  · exact h
  · have h_pref := h_mono (κ.sortKey b) (κ.sortKey a) h_ge
    exact False.elim (Nat.not_le_of_gt h_lt h_pref)

/-- Zone-map lower-bound pruning soundness: if every row `r` in a `.tseg`
    segment has collated sort key at least `minVal`, then any query predicate
    requiring `κ.le r q` (including `r =_κ q` or `r <=_κ q`) cannot match when
    `κ.lt q minVal`. -/
theorem zonemap_min_pruning_sound {Val : Type} (κ : Collation Val)
    (segment : List Val) (minVal q : Val)
    (h_min : ∀ r ∈ segment, κ.le minVal r)
    (h_below : κ.lt q minVal) :
    ∀ r ∈ segment, ¬ κ.le r q := by
  intro r hr h_rq
  have h_mr : κ.le minVal r := h_min r hr
  have h_mq : κ.le minVal q := Nat.le_trans h_mr h_rq
  exact Nat.not_lt_of_ge h_mq h_below

/-- Zone-map upper-bound pruning soundness: if every row `r` in a `.tseg`
    segment has collated sort key at most `maxVal`, then any query predicate
    requiring `κ.le q r` (including `r =_κ q` or `r >=_κ q`) cannot match when
    `κ.lt maxVal q`. -/
theorem zonemap_max_pruning_sound {Val : Type} (κ : Collation Val)
    (segment : List Val) (maxVal q : Val)
    (h_max : ∀ r ∈ segment, κ.le r maxVal)
    (h_above : κ.lt maxVal q) :
    ∀ r ∈ segment, ¬ κ.le q r := by
  intro r hr h_qr
  have h_rm : κ.le r maxVal := h_max r hr
  have h_qm : κ.le q maxVal := Nat.le_trans h_qr h_rm
  exact Nat.not_lt_of_ge h_qm h_above

#print axioms collation_le_refl
#print axioms collation_le_trans
#print axioms collation_le_total
#print axioms umbra_prefix_reflects_lt
#print axioms zonemap_min_pruning_sound
#print axioms zonemap_max_pruning_sound

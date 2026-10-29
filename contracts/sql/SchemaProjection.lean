/-
Formal specification of multi-version Table schema evolution and physical-to-logical
projection (ADD COLUMN, DROP COLUMN, and compaction segment rewrite), per
packages/zig/transit-fuze/src/TableSchemaProjection.zig (SCHEMA-PROJ-01).
-/

abbrev ColId := Nat

structure ColumnDecl (Val : Type) where
  id : ColId
  absentDefault : Option Val
  deriving DecidableEq, Repr

abbrev PhysRow (Val : Type) := List (ColId × Option Val)

def lookupPhys {Val : Type} (id : ColId) : PhysRow Val → Option (Option Val)
  | [] => none
  | (cid, v) :: rest => if cid = id then some v else lookupPhys id rest

def projectColumn {Val : Type} (col : ColumnDecl Val) (row : PhysRow Val) : Option Val :=
  match lookupPhys col.id row with
  | some v => v
  | none => col.absentDefault

def projectRow {Val : Type} (schema : List (ColumnDecl Val)) (row : PhysRow Val) :
    List (ColId × Option Val) :=
  schema.map (fun col => (col.id, projectColumn col row))

/-- `ADD COLUMN` appends a new column declaration without mutating the projected
    values of any existing columns in historical physical segments. -/
theorem add_column_preserves_existing_projection {Val : Type}
    (schema : List (ColumnDecl Val)) (newCol : ColumnDecl Val) (row : PhysRow Val) :
    projectRow (schema ++ [newCol]) row =
      projectRow schema row ++ [(newCol.id, projectColumn newCol row)] := by
  simp [projectRow, List.map_append]

/-- `DROP COLUMN` (filtering the target schema by retained column IDs) commutes
    with physical-to-logical row projection. -/
theorem drop_column_commutes_with_projection {Val : Type}
    (keep : ColumnDecl Val → Bool) (schema : List (ColumnDecl Val)) (row : PhysRow Val) :
    projectRow (schema.filter keep) row =
      (schema.filter keep).map (fun col => (col.id, projectColumn col row)) := by
  rfl

theorem lookupPhys_map_self {Val : Type} (schema : List (ColumnDecl Val))
    (row : PhysRow Val) (c : ColumnDecl Val)
    (h_mem : c ∈ schema)
    (h_nodup : ∀ c1 ∈ schema, ∀ c2 ∈ schema, c1.id = c2.id → c1 = c2) :
    lookupPhys c.id (projectRow schema row) = some (projectColumn c row) := by
  induction schema with
  | nil => contradiction
  | cons hd tl ih =>
    simp only [projectRow, List.map_cons, lookupPhys]
    by_cases h_eq : hd.id = c.id
    · simp only [h_eq, ↓reduceIte]
      have h_same : hd = c := h_nodup hd List.mem_cons_self c h_mem h_eq
      rw [h_same]
    · simp only [h_eq, ↓reduceIte]
      cases h_mem with
      | head => exact False.elim (h_eq rfl)
      | tail _ h_in_tl =>
        exact ih h_in_tl (fun c1 hc1 c2 hc2 heq =>
          h_nodup c1 (List.mem_cons_of_mem hd hc1) c2 (List.mem_cons_of_mem hd hc2) heq)

theorem projectRow_cons {Val : Type} (col : ColumnDecl Val) (rest : List (ColumnDecl Val)) (r : PhysRow Val) :
    projectRow (col :: rest) r = (col.id, projectColumn col r) :: projectRow rest r := rfl

/-- Compaction rewrites an older physical row into a new segment materialized
    under `schema`. Any subsequent projection over a sub-schema `subSchema`
    (such as after a later `DROP COLUMN`) yields the exact same cells as
    projecting directly from the original historical physical row. -/
theorem compaction_rewrite_preserves_projection {Val : Type}
    (schema subSchema : List (ColumnDecl Val)) (row : PhysRow Val)
    (h_sub : ∀ c ∈ subSchema, c ∈ schema)
    (h_nodup : ∀ c1 ∈ schema, ∀ c2 ∈ schema, c1.id = c2.id → c1 = c2) :
    projectRow subSchema (projectRow schema row) = projectRow subSchema row := by
  induction subSchema with
  | nil => rfl
  | cons col rest ih =>
    simp only [projectRow_cons]
    have h_in : col ∈ schema := h_sub col List.mem_cons_self
    have h_look := lookupPhys_map_self schema row col h_in h_nodup
    have h_col : projectColumn col (projectRow schema row) = projectColumn col row := by
      simp [projectColumn, h_look]
    have h_rest := ih (fun c hc => h_sub c (List.mem_cons_of_mem col hc))
    rw [h_col, h_rest]

#print axioms add_column_preserves_existing_projection
#print axioms drop_column_commutes_with_projection
#print axioms compaction_rewrite_preserves_projection

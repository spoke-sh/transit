/-
  Source-only typed-target fragment. Types contain explicit domain identity;
  variables use de Bruijn indices, and the checked arm table is total on Fin n.
  This models one scalar payload per constructor and ordered Table inserts.
  It does not prove parsing, SQL binding, bounded evaluation, database execution,
  authorization, resource existence, effects, or the complete Zig compiler.
-/
inductive Base where
  | integer | text | boolean
  deriving DecidableEq, Repr

inductive Scalar where
  | integer (value : Int)
  | text (value : String)
  | boolean (value : Bool)
  deriving DecidableEq, Repr

def Scalar.base : Scalar → Base
  | .integer _ => .integer
  | .text _ => .text
  | .boolean _ => .boolean

structure SourceType where
  base : Base
  domain : Option String
  deriving DecidableEq, Repr

structure Value (type : SourceType) where
  scalar : Scalar
  valid : scalar.base = type.base

inductive Var : List SourceType → SourceType → Type where
  | head : Var (type :: context) type
  | tail : Var context type → Var (other :: context) type

abbrev Env (context : List SourceType) := {type : SourceType} → Var context type → Value type

def extend (value : Value type) (env : Env context) : Env (type :: context)
  | _, .head => value
  | _, .tail var => env var

inductive Expr (context : List SourceType) : SourceType → Type where
  | literal : Value type → Expr context type
  | var : Var context type → Expr context type
  | equal : Expr context type → Expr context type → Expr context ⟨.boolean, none⟩

def Expr.eval (env : Env context) : Expr context type → Value type
  | .literal value => value
  | .var index => env index
  | .equal left right => ⟨.boolean (decide ((left.eval env).scalar = (right.eval env).scalar)), rfl⟩

def Expr.substitute (value : Value parameter) : Expr (parameter :: context) type → Expr context type
  | .literal v => .literal v
  | .var .head => .literal value
  | .var (.tail index) => .var index
  | .equal left right => .equal (left.substitute value) (right.substitute value)

/-- A substitution must have the exact source type, including domain identity.
    It preserves both typing (the result index) and expression meaning. -/
theorem nominal_substitution (env : Env context) (value : Value parameter)
    (expr : Expr (parameter :: context) type) :
    (expr.substitute value).eval env = expr.eval (extend value env) := by
  induction expr with
  | literal => rfl
  | var index => cases index <;> rfl
  | equal left right ihl ihr => simp only [Expr.substitute, Expr.eval, ihl, ihr]

structure Table (type : SourceType) where
  binding : String

inductive Write (context : List SourceType) where
  | insert {type : SourceType} (table : Table type) (value : Expr context type)

structure BoundAction where
  table : String
  type : SourceType
  value : Scalar
  deriving DecidableEq, Repr

def Write.eval (env : Env context) : Write context → BoundAction
  | .insert (type := type) table value => ⟨table.binding, type, (value.eval env).scalar⟩

def Write.substitute (value : Value parameter) : Write (parameter :: context) → Write context
  | .insert table expr => .insert table (expr.substitute value)

structure Variant (signature : Fin n → SourceType) where
  tag : Fin n
  payload : Value (signature tag)

abbrev Arms (context : List SourceType) (signature : Fin n → SourceType) :=
  (tag : Fin n) → List (Write (signature tag :: context))

/-- Complete unique constructor labels select exactly one arm, regardless of
    source order. Its fresh head variable has the selected payload's exact type. -/
theorem exhaustive_selection {n : Nat} {signature : Fin n → SourceType}
    (value : Variant signature) (arms : Arms context signature) (labels : List (Fin n))
    (complete : ∀ tag, tag ∈ labels) (unique : labels.Nodup) :
    labels.filter (fun tag => decide (tag = value.tag)) = [value.tag] ∧
      ∃ body : List (Write (signature value.tag :: context)), body = arms value.tag := by
  constructor
  · rw [List.filter_eq, unique.count]
    simp only [complete value.tag, if_true, List.replicate_one]
  · exact ⟨arms value.tag, rfl⟩

/-- Source interpretation extends the environment with the selected payload. -/
def sourceActions (env : Env context) (value : Variant signature) (arms : Arms context signature) :
    List BoundAction := (arms value.tag).map (Write.eval (extend value.payload env))

/-- Specialization eliminates the binder by substitution before action binding. -/
def specialize (value : Variant signature) (arms : Arms context signature) : List (Write context) :=
  (arms value.tag).map (Write.substitute value.payload)

/-- Action interpretation is independent of constructor/MATCH selection. -/
def boundActions (env : Env context) (program : List (Write context)) : List BoundAction :=
  program.map (Write.eval env)

/-- Exact ordered actions, Table bindings, domain identities and scalars agree.
    Erasure to SQL is a separate correspondence check, not this theorem. -/
theorem specialization_preservation (env : Env context) (value : Variant signature)
    (arms : Arms context signature) :
    boundActions env (specialize value arms) = sourceActions env value arms := by
  unfold boundActions specialize sourceActions
  generalize arms value.tag = actions
  induction actions with
  | nil => rfl
  | cons action rest ih =>
    cases action with
    | insert table expr =>
      simp only [List.map_cons, Write.substitute, Write.eval, nominal_substitution, ih]

#print axioms nominal_substitution
#print axioms exhaustive_selection
#print axioms specialization_preservation

/- A second, deliberately small fragment models nominal record projection and
   ordered acquisition/read/guard/atomic/write events. Physical typing and
   nullability are premises supplied by the ordinary binder. This proves neither
   runtime atomicity nor correspondence for all program expressions. -/
abbrev RecordExpr (context fields : List SourceType) :=
  {type : SourceType} → Var fields type → Expr context type

def RecordExpr.substitute (record : RecordExpr (parameter :: context) fields)
    (value : Value parameter) : RecordExpr context fields :=
  fun index => (record index).substitute value

/-- Projection keeps the field's exact source type, including its domain, when
    a concrete parameter is substituted. It cannot reinterpret another field. -/
theorem projection_substitution (env : Env context) (value : Value parameter)
    (record : RecordExpr (parameter :: context) fields) (index : Var fields type) :
    ((record.substitute value) index).eval env = (record index).eval (extend value env) := by
  exact nominal_substitution env value (record index)

inductive EventKind where
  | acquire | read | require | atomicBegin | atomicEnd | insert | append
  deriving DecidableEq, Repr

structure BoundEvent where
  kind : EventKind
  binding : String
  type : Option SourceType
  value : Option Scalar
  deriving DecidableEq, Repr

inductive SourceEvent (context : List SourceType) where
  | boundary (kind : EventKind) (binding : String)
  | guard (condition : Expr context ⟨.boolean, none⟩)
  | write {type : SourceType} (kind : EventKind) (target : Table type) (expr : Expr context type)

def SourceEvent.eval (env : Env context) : SourceEvent context → BoundEvent
  | .boundary kind binding => ⟨kind, binding, none, none⟩
  | .guard condition => ⟨.require, "", some ⟨.boolean, none⟩, some (condition.eval env).scalar⟩
  | .write (type := type) kind target expr => ⟨kind, target.binding, some type, some (expr.eval env).scalar⟩

def SourceEvent.substitute (value : Value parameter) : SourceEvent (parameter :: context) → SourceEvent context
  | .boundary kind binding => .boundary kind binding
  | .guard condition => .guard (condition.substitute value)
  | .write kind target expr => .write kind target (expr.substitute value)

/-- Substitution preserves the complete ordered trace, including guards and
    atomic markers, not just the multiset of writes. -/
theorem program_substitution (env : Env context) (value : Value parameter)
    (events : List (SourceEvent (parameter :: context))) :
    (events.map (SourceEvent.substitute value)).map (SourceEvent.eval env) =
      events.map (SourceEvent.eval (extend value env)) := by
  induction events with
  | nil => rfl
  | cons event rest ih =>
    cases event <;> simp only [List.map_cons, SourceEvent.substitute, SourceEvent.eval,
      nominal_substitution, ih]

structure ErasedEvent where
  kind : EventKind
  binding : String
  base : Option Base
  value : Option Scalar
  deriving DecidableEq, Repr

def BoundEvent.erase (event : BoundEvent) : ErasedEvent :=
  ⟨event.kind, event.binding, event.type.map SourceType.base, event.value⟩

/-- Domain erasure keeps the exact event order and bindings. This is a law of
    this trace model; independent finite comparisons connect it to emitted SQL. -/
theorem ordered_erasure (events : List BoundEvent) :
    (events.map BoundEvent.erase).map (fun e => (e.kind, e.binding, e.value)) =
      events.map (fun e => (e.kind, e.binding, e.value)) := by
  induction events with
  | nil => rfl
  | cons event rest ih => simp only [List.map_cons, BoundEvent.erase, ih]

#print axioms projection_substitution
#print axioms program_substitution
#print axioms ordered_erasure

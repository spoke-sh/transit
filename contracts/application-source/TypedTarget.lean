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
  deriving DecidableEq

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

/- A third fragment models five-state pure function substitution, ordered guard
   refusal precedence (including non-commutativity under reordering), and
   hygienic inline atomic procedure expansion with single-decision rollback. -/
inductive FiveVal (type : SourceType) where
  | value (v : Value type)
  | null
  | missing
  | typeError
  | conflict
  deriving DecidableEq

abbrev FiveEnv (context : List SourceType) := {type : SourceType} → Var context type → FiveVal type

def extendFive (v : FiveVal type) (env : FiveEnv context) : FiveEnv (type :: context)
  | _, .head => v
  | _, .tail var => env var

inductive FiveExpr (context : List SourceType) : SourceType → Type where
  | const : FiveVal type → FiveExpr context type
  | var : Var context type → FiveExpr context type
  | isNull : FiveExpr context operand → FiveExpr context ⟨.boolean, none⟩
  | equal : FiveExpr context type → FiveExpr context type → FiveExpr context ⟨.boolean, none⟩
  | branch : FiveExpr context ⟨.boolean, none⟩ → FiveExpr context type → FiveExpr context type → FiveExpr context type

def evalIsNull (v : FiveVal operand) : FiveVal ⟨.boolean, none⟩ :=
  match v with
  | .value _ => .value ⟨.boolean false, rfl⟩
  | .null => .value ⟨.boolean true, rfl⟩
  | .missing => .missing
  | .typeError => .typeError
  | .conflict => .conflict

def evalEqual (l r : FiveVal type) : FiveVal ⟨.boolean, none⟩ :=
  match l, r with
  | .missing, _ => .missing
  | _, .missing => .missing
  | .typeError, _ => .typeError
  | _, .typeError => .typeError
  | .conflict, _ => .conflict
  | _, .conflict => .conflict
  | .null, _ => .null
  | _, .null => .null
  | .value lv, .value rv => .value ⟨.boolean (decide (lv.scalar = rv.scalar)), rfl⟩

def evalBranch (c : FiveVal ⟨.boolean, none⟩) (y n : FiveVal type) : FiveVal type :=
  match c with
  | .value ⟨.boolean true, _⟩ => y
  | .value ⟨.boolean false, _⟩ => n
  | .value ⟨.integer _, h⟩ => nomatch h
  | .value ⟨.text _, h⟩ => nomatch h
  | .null => n
  | .missing => .missing
  | .typeError => .typeError
  | .conflict => .conflict

def FiveExpr.eval (env : FiveEnv context) : FiveExpr context type → FiveVal type
  | .const v => v
  | .var index => env index
  | .isNull operand => evalIsNull (operand.eval env)
  | .equal left right => evalEqual (left.eval env) (right.eval env)
  | .branch cond yes no => evalBranch (cond.eval env) (yes.eval env) (no.eval env)

def FiveExpr.substExpr (arg : FiveExpr context parameter) :
    FiveExpr (parameter :: context) result → FiveExpr context result
  | .const v => .const v
  | .var .head => arg
  | .var (.tail index) => .var index
  | .isNull operand => .isNull (FiveExpr.substExpr arg operand)
  | .equal left right => .equal (FiveExpr.substExpr arg left) (FiveExpr.substExpr arg right)
  | .branch cond yes no => .branch (FiveExpr.substExpr arg cond) (FiveExpr.substExpr arg yes) (FiveExpr.substExpr arg no)

/-- Pure function call expansion preserves exact five-state meaning across
    zero, one or multiple parameter occurrences without rebinding caller names. -/
theorem function_substitution (env : FiveEnv context) (arg : FiveExpr context parameter)
    (body : FiveExpr (parameter :: context) result) :
    (FiveExpr.substExpr arg body).eval env = body.eval (extendFive (arg.eval env) env) := by
  induction body with
  | const => rfl
  | var index => cases index <;> rfl
  | isNull operand ih =>
    change evalIsNull ((FiveExpr.substExpr arg operand).eval env) = _
    rw [ih]; rfl
  | equal left right ihl ihr =>
    change evalEqual ((FiveExpr.substExpr arg left).eval env) ((FiveExpr.substExpr arg right).eval env) = _
    rw [ihl, ihr]; rfl
  | branch cond yes no ihc ihy ihn =>
    change evalBranch ((FiveExpr.substExpr arg cond).eval env) ((FiveExpr.substExpr arg yes).eval env) ((FiveExpr.substExpr arg no).eval env) = _
    rw [ihc, ihy, ihn]; rfl

inductive GuardOutcome where
  | accept
  | refuse (code : String)
  deriving DecidableEq, Repr

structure GuardCheck (context : List SourceType) where
  condition : Expr context ⟨.boolean, none⟩
  code : String

def GuardCheck.run (env : Env context) (g : GuardCheck context) : GuardOutcome :=
  match (g.condition.eval env).scalar with
  | .boolean true => .accept
  | _ => .refuse g.code

def runGuards (env : Env context) : List (GuardCheck context) → GuardOutcome
  | [] => .accept
  | g :: rest =>
    match g.run env with
    | .accept => runGuards env rest
    | .refuse code => .refuse code

/-- Lexical expansion of nested or sequential guards preserves the first
    failing refusal code and evaluates subsequent guards only on acceptance. -/
theorem guard_sequence_refusal (env : Env context)
    (first second : List (GuardCheck context)) :
    runGuards env (first ++ second) =
      match runGuards env first with
      | .accept => runGuards env second
      | .refuse code => .refuse code := by
  induction first with
  | nil => rfl
  | cons g rest ih =>
    simp only [List.cons_append, runGuards]
    cases g.run env with
    | accept => exact ih
    | refuse code => rfl

def emptyGuardEnv : Env [] := fun index => nomatch index

/-- Guard composition is non-commutative: reordering failing guards with
    distinct refusal codes changes the observable refusal outcome. -/
theorem guard_reorder_non_equivalent :
    ∃ (g1 g2 : GuardCheck []),
      runGuards emptyGuardEnv [g1, g2] ≠ runGuards emptyGuardEnv [g2, g1] := by
  refine ⟨⟨.literal ⟨.boolean false, rfl⟩, "MissingAccount"⟩,
          ⟨.literal ⟨.boolean false, rfl⟩, "InactiveAccount"⟩, ?_⟩
  decide

inductive AtomicStep (context : List SourceType) where
  | check (guard : GuardCheck context)
  | mutate (write : Write context)

inductive TxDecision where
  | commit (writes : List BoundAction)
  | rollback (code : String)
  deriving DecidableEq, Repr

def AtomicStep.substitute (value : Value parameter) :
    AtomicStep (parameter :: context) → AtomicStep context
  | .check ⟨cond, code⟩ => .check ⟨cond.substitute value, code⟩
  | .mutate w => .mutate (w.substitute value)

def prependAction (action : BoundAction) (decision : TxDecision) : TxDecision :=
  match decision with
  | .commit writes => .commit (action :: writes)
  | .rollback code => .rollback code

def sequenceDecision (first second : TxDecision) : TxDecision :=
  match first with
  | .rollback code => .rollback code
  | .commit firstWrites =>
    match second with
    | .rollback code => .rollback code
    | .commit secondWrites => .commit (firstWrites ++ secondWrites)

def runAtomic (env : Env context) : List (AtomicStep context) → TxDecision
  | [] => .commit []
  | .check g :: rest =>
    match g.run env with
    | .accept => runAtomic env rest
    | .refuse code => .rollback code
  | .mutate w :: rest => prependAction (w.eval env) (runAtomic env rest)

def evalProcedureCall (env : Env context) (arg : Value parameter)
    (callee : List (AtomicStep (parameter :: context)))
    (continuation : List (AtomicStep context)) : TxDecision :=
  sequenceDecision (runAtomic (extend arg env) callee) (runAtomic env continuation)

/-- Flattening a hygienically specialized procedure into the enclosing atomic
    block preserves isolated lexical evaluation and single-decision rollback,
    discarding earlier procedure writes if a later guard refuses. -/
theorem procedure_inline_atomic (env : Env context) (arg : Value parameter)
    (callee : List (AtomicStep (parameter :: context)))
    (continuation : List (AtomicStep context)) :
    runAtomic env (callee.map (AtomicStep.substitute arg) ++ continuation) =
      evalProcedureCall env arg callee continuation := by
  induction callee with
  | nil =>
    unfold evalProcedureCall sequenceDecision
    simp only [List.map_nil, List.nil_append, runAtomic]
    cases runAtomic env continuation <;> rfl
  | cons step rest ih =>
    cases step with
    | check g =>
      cases g with
      | mk cond code =>
        have hrun : (GuardCheck.mk (cond.substitute arg) code).run env =
            (GuardCheck.mk cond code).run (extend arg env) := by
          change (match ((cond.substitute arg).eval env).scalar with
            | .boolean true => GuardOutcome.accept
            | _ => GuardOutcome.refuse code) = _
          rw [nominal_substitution]
          rfl
        unfold evalProcedureCall at ih ⊢
        change (match (GuardCheck.mk (cond.substitute arg) code).run env with
          | GuardOutcome.accept => runAtomic env (rest.map (AtomicStep.substitute arg) ++ continuation)
          | GuardOutcome.refuse c => TxDecision.rollback c) =
          sequenceDecision (match (GuardCheck.mk cond code).run (extend arg env) with
            | GuardOutcome.accept => runAtomic (extend arg env) rest
            | GuardOutcome.refuse c => TxDecision.rollback c) (runAtomic env continuation)
        rw [hrun]
        cases (GuardCheck.mk cond code).run (extend arg env) with
        | accept => exact ih
        | refuse c => rfl
    | mutate w =>
      cases w with
      | insert table expr =>
        have hw : (Write.insert table (expr.substitute arg)).eval env =
            (Write.insert table expr).eval (extend arg env) := by
          change BoundAction.mk table.binding _ ((expr.substitute arg).eval env).scalar = _
          rw [nominal_substitution]
          rfl
        unfold evalProcedureCall at ih ⊢
        change prependAction ((Write.insert table (expr.substitute arg)).eval env)
            (runAtomic env (rest.map (AtomicStep.substitute arg) ++ continuation)) =
          sequenceDecision (prependAction ((Write.insert table expr).eval (extend arg env))
            (runAtomic (extend arg env) rest)) (runAtomic env continuation)
        rw [hw, ih]
        cases runAtomic (extend arg env) rest with
        | rollback code => rfl
        | commit calleeWrites =>
          cases runAtomic env continuation with
          | rollback code => rfl
          | commit contWrites => rfl

#print axioms function_substitution
#print axioms guard_sequence_refusal
#print axioms guard_reorder_non_equivalent
#print axioms procedure_inline_atomic

/-- The return value is exposed only after a successful atomic decision.
    This fragment has total scalar expressions; runtime expression errors and
    database authority remain obligations of the ordinary SQL owner. -/
def returned (decision : TxDecision) (value : Value type) : Option (Value type) :=
  match decision with
  | .commit _ => some value
  | .rollback _ => none

theorem procedure_return_substitution (env : Env context) (arg : Value parameter)
    (callee : List (AtomicStep (parameter :: context)))
    (continuation : List (AtomicStep context))
    (result : Expr (parameter :: context) type) :
    returned (runAtomic env (callee.map (AtomicStep.substitute arg) ++ continuation))
      ((result.substitute arg).eval env) =
    returned (evalProcedureCall env arg callee continuation)
      (result.eval (extend arg env)) := by
  rw [procedure_inline_atomic, nominal_substitution]

#print axioms procedure_return_substitution

/- A fourth fragment models first-class module-instance DAG sharing: evaluating
   a shared module constructor once (`LET m = USE MODULE ...`) emits its DDL
   actions once and exposes its typed export interface to multiple downstream
   consumers without re-instantiating the constructor. -/
structure ModuleInstance (Interface : Type) where
  ddl : List BoundAction
  exports : Interface

abbrev ModuleCtor (context : List SourceType) (Interface : Type) :=
  Env context → ModuleInstance Interface

abbrev ModuleConsumer (context : List SourceType) (parameter : SourceType) (Interface : Type) :=
  Interface → List (Write (parameter :: context))

def evalSharedDiamond (env : Env context)
    (ctor : ModuleCtor context Interface)
    (argLeft : Value paramLeft) (left : ModuleConsumer context paramLeft Interface)
    (argRight : Value paramRight) (right : ModuleConsumer context paramRight Interface) :
    List BoundAction :=
  let inst := ctor env
  inst.ddl ++
    boundActions env ((left inst.exports).map (Write.substitute argLeft)) ++
    boundActions env ((right inst.exports).map (Write.substitute argRight))

def evalUnsharedPair (env : Env context)
    (ctor : ModuleCtor context Interface)
    (argLeft : Value paramLeft) (left : ModuleConsumer context paramLeft Interface)
    (argRight : Value paramRight) (right : ModuleConsumer context paramRight Interface) :
    List BoundAction :=
  let inst1 := ctor env
  let inst2 := ctor env
  inst1.ddl ++
    boundActions env ((left inst1.exports).map (Write.substitute argLeft)) ++
    inst2.ddl ++
    boundActions env ((right inst2.exports).map (Write.substitute argRight))

/-- Shared module-instance DAG evaluation preserves nominal domain substitution
    across exported handles while emitting the shared instance's DDL once ahead
    of downstream consumers; whenever the shared DDL is non-empty, shared DAG
    evaluation is strictly non-equivalent to per-consumer re-instantiation. -/
theorem module_instance_dag_sharing (env : Env context)
    (ctor : ModuleCtor context Interface)
    (argLeft : Value paramLeft) (left : ModuleConsumer context paramLeft Interface)
    (argRight : Value paramRight) (right : ModuleConsumer context paramRight Interface) :
    evalSharedDiamond env ctor argLeft left argRight right =
      (ctor env).ddl ++
        (left (ctor env).exports).map (Write.eval (extend argLeft env)) ++
        (right (ctor env).exports).map (Write.eval (extend argRight env)) ∧
    ((ctor env).ddl ≠ [] →
      evalSharedDiamond env ctor argLeft left argRight right ≠
        evalUnsharedPair env ctor argLeft left argRight right) := by
  have subst_writes : ∀ {p : SourceType} (v : Value p) (ws : List (Write (p :: context))),
      boundActions env (ws.map (Write.substitute v)) = ws.map (Write.eval (extend v env)) := by
    intro p v ws
    induction ws with
    | nil => rfl
    | cons step rest ih =>
      cases step with
      | insert table expr =>
        simp only [List.map_cons, boundActions, Write.substitute, Write.eval, nominal_substitution] at ih ⊢
        exact congrArg _ ih
  constructor
  · simp only [evalSharedDiamond, subst_writes]
  · intro h_nonempty h_eq
    have h_len := congrArg List.length h_eq
    simp only [evalSharedDiamond, evalUnsharedPair, List.length_append] at h_len
    have h_mid := Nat.add_right_cancel h_len
    have h_zero : 0 = (ctor env).ddl.length :=
      Nat.add_left_cancel (Eq.trans (Nat.add_zero _).symm h_mid)
    cases h_ddl : (ctor env).ddl with
    | nil => exact h_nonempty h_ddl
    | cons head tail =>
      rw [h_ddl, List.length_cons] at h_zero
      exact Nat.noConfusion h_zero

#print axioms module_instance_dag_sharing

/- A fifth fragment models schema-bound module specialization (`BIND SCHEMA`) and
   reference-only table exports (`EXPORT REFERENCE TABLE`). -/
structure QualifiedObject where
  schema : String
  name : String
  deriving DecidableEq, Repr

def bindSchemaObjects (schema : String) (localNames : List String) : List QualifiedObject :=
  localNames.map (fun name => ⟨schema, name⟩)

def bindSchemaWrite (schema : String) (localName : String) (expr : Expr (parameter :: context) type) :
    Write (parameter :: context) :=
  .insert ⟨schema ++ "." ++ localName⟩ expr

/-- Specializing a schema-bound module under distinct concrete schema bindings
    produces strictly disjoint qualified object identities while preserving
    nominal domain substitution on every specialized write. -/
theorem schema_binding_isolation (env : Env context) (arg : Value parameter)
    (s1 s2 : String) (h_distinct : s1 ≠ s2)
    (localNames : List String) (localTable : String)
    (expr : Expr (parameter :: context) type) :
    ((Write.substitute arg (bindSchemaWrite s1 localTable expr)).eval env =
      (bindSchemaWrite s1 localTable expr).eval (extend arg env)) ∧
    (∀ obj, obj ∈ bindSchemaObjects s1 localNames → obj ∉ bindSchemaObjects s2 localNames) := by
  have mem_schema : ∀ {s : String} {names : List String} {obj : QualifiedObject},
      obj ∈ bindSchemaObjects s names → obj.schema = s := by
    intro s names obj hmem
    induction names with
    | nil => cases hmem
    | cons _ _ ih =>
      cases hmem with
      | head => rfl
      | tail _ htl => exact ih htl
  constructor
  · simp only [bindSchemaWrite, Write.substitute, Write.eval, nominal_substitution]
  · intro obj h1 h2
    exact h_distinct ((mem_schema h1).symm.trans (mem_schema h2))

inductive TableExport (keyType : SourceType) where
  | full (table : Table keyType) (columns : List String)
  | referenceOnly (binding : String) (columns : List String)

def allExported (cols : List String) : List String → Bool
  | [] => true
  | col :: rest => decide (col ∈ cols) && allExported cols rest

private theorem allExported_iff (cols requested : List String) :
    allExported cols requested = true ↔ (∀ col, col ∈ requested → col ∈ cols) := by
  induction requested with
  | nil =>
    constructor
    · intro _ _ h; cases h
    · intro _; rfl
  | cons hd tl ih =>
    constructor
    · intro h col hmem
      cases hAnd : decide (hd ∈ cols) with
      | false =>
        change (decide (hd ∈ cols) && allExported cols tl) = true at h
        rw [hAnd] at h
        cases h
      | true =>
        change (decide (hd ∈ cols) && allExported cols tl) = true at h
        rw [hAnd] at h
        cases hmem with
        | head => exact of_decide_eq_true hAnd
        | tail _ htl => exact ih.mp h col htl
    · intro hall
      change (decide (hd ∈ cols) && allExported cols tl) = true
      rw [decide_eq_true (hall hd (.head tl)), ih.mpr (fun c hc => hall c (.tail hd hc))]
      rfl

def TableExport.admitForeignKey (cap : TableExport keyType)
    (requestedCols : List String) (childType : SourceType) : Bool :=
  let cols := match cap with
    | .full _ c => c
    | .referenceOnly _ c => c
  decide (childType = keyType) && allExported cols requestedCols

def TableExport.admitWrite (cap : TableExport keyType)
    (expr : Expr context keyType) : Option (Write context) :=
  match cap with
  | .full table _ => some (.insert table expr)
  | .referenceOnly _ _ => none

/-- A reference-only table export (`EXPORT REFERENCE TABLE`) admits foreign-key
    references iff the child column matches the exact nominal source type and all
    referenced columns were exported, while never escalating into a write capability. -/
theorem reference_export_non_escalation (binding : String) (columns requestedCols : List String)
    (keyType childType : SourceType) (expr : Expr context keyType) :
    TableExport.admitWrite (.referenceOnly (keyType := keyType) binding columns) expr = none ∧
    (TableExport.admitForeignKey (.referenceOnly (keyType := keyType) binding columns) requestedCols childType = true ↔
      (childType = keyType ∧ ∀ col, col ∈ requestedCols → col ∈ columns)) := by
  constructor
  · rfl
  · constructor
    · intro h
      change (decide (childType = keyType) && allExported columns requestedCols) = true at h
      cases hType : decide (childType = keyType) with
      | false => rw [hType] at h; cases h
      | true =>
        rw [hType] at h
        exact ⟨of_decide_eq_true hType, (allExported_iff columns requestedCols).mp h⟩
    · intro ⟨hType, hCols⟩
      change (decide (childType = keyType) && allExported columns requestedCols) = true
      rw [decide_eq_true hType, (allExported_iff columns requestedCols).mpr hCols]
      rfl

#print axioms schema_binding_isolation
#print axioms reference_export_non_escalation

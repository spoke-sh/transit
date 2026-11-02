------------------------- MODULE BoardStatement -------------------------
EXTENDS Naturals, TLC
CONSTANT CheckRun
VARIABLES s, effects, last, unique
vars == <<s,effects,last,unique>>
Initial == [reader |-> "none", generation |-> 0, phase |-> "idle", visible |-> TRUE,
    available |-> TRUE, disclosed |-> FALSE, disposed |-> FALSE, failure |-> "none"]
None == [cancel |-> FALSE, close |-> "none", action |-> "none"]
Result(x,e) == [state |-> x, effects |-> e]
Busy(x) == x.phase \in {"submitting","observing","advancing"}
Request(x,e) == IF ~x.visible \/ ~x.available \/ (CheckRun /\ Busy(x)) THEN Result(x,None)
    ELSE LET reader == CASE e = "RunA" -> "a" [] e = "RunB" -> "b" [] OTHER -> x.reader
        IN IF reader = "none" THEN Result(x,None)
        ELSE Result([x EXCEPT !.reader = reader, !.generation = @ + 1,
            !.phase = CASE e \in {"RunA","RunB"} -> "submitting" [] e = "Next" -> "advancing" [] OTHER -> "observing",
            !.disclosed = IF e \in {"RunA","RunB"} THEN FALSE ELSE @, !.failure = "none"],
            [cancel |-> TRUE, close |-> IF e \in {"RunA","RunB"} THEN x.reader ELSE "none",
                action |-> CASE e \in {"RunA","RunB"} -> "run" [] e = "Next" -> "next" [] OTHER -> "observe"])
Events == {"RunA","RunB","Observe","Next","Hide","Show","Disable","Enable","Close","Dispose","Receive","Old","Foreign","Deny","Lost"}
Transition(x,e) == IF x.disposed THEN Result(x,None)
    ELSE IF e \in {"Close","Dispose"} THEN Result([x EXCEPT !.reader = "none", !.generation = @ + 1,
        !.phase = "idle", !.disclosed = FALSE, !.failure = "none", !.disposed = e = "Dispose"],
        [None EXCEPT !.cancel = TRUE, !.close = x.reader])
    ELSE IF e \in {"Hide","Disable"} THEN Result([x EXCEPT !.visible = IF e = "Hide" THEN FALSE ELSE @,
        !.available = IF e = "Disable" THEN FALSE ELSE @, !.generation = @ + 1, !.phase = "idle", !.disclosed = FALSE], [None EXCEPT !.cancel = TRUE])
    ELSE IF e \in {"Show","Enable"} THEN
        LET next == [x EXCEPT !.visible = IF e = "Show" THEN TRUE ELSE @,
            !.available = IF e = "Enable" THEN TRUE ELSE @]
        IN IF next.visible /\ next.available /\ next.reader # "none" THEN Request(next,"Observe") ELSE Result(next,None)
    ELSE IF e \in {"RunA","RunB","Observe","Next"} THEN Request(x,e)
    ELSE IF ~Busy(x) \/ ~x.visible \/ ~x.available \/ e \in {"Old","Foreign"} THEN Result(x,None)
    ELSE IF e = "Receive" THEN Result([x EXCEPT !.phase = "ready", !.disclosed = TRUE, !.failure = "none"], None)
    ELSE Result([x EXCEPT !.phase = "failed", !.disclosed = FALSE,
        !.failure = IF e = "Deny" THEN "denied" ELSE "unavailable",
        !.reader = IF e = "Deny" THEN "none" ELSE @], [None EXCEPT !.close = IF e = "Deny" THEN x.reader ELSE "none"])
Init == /\ s = Initial /\ effects = None /\ last = "Init" /\ unique = TRUE
Step == \E e \in Events: LET r == Transition(s,e) IN
    /\ r.state.generation <= 3 /\ s' = r.state /\ effects' = r.effects /\ last' = e
    /\ unique' = (Busy(s) => r.effects.action # "run")
NoDuplicateRun == unique
NoHiddenDisclosure == (~s.visible \/ ~s.available \/ s.disposed \/ s.failure = "denied") => ~s.disclosed
Spec == Init /\ [][Step]_vars
=============================================================================

------------------------ MODULE BoardObservation ------------------------
EXTENDS Integers, Sequences, TLC
CONSTANTS CheckGeneration, CheckDenial
VARIABLES a, b, effects, last, fresh
vars == <<a, b, effects, last, fresh>>
Initial == [tag |-> "idle", generation |-> 0, failures |-> 0, value |-> FALSE, failure |-> "none"]
None == [cancel |-> FALSE, read |-> FALSE, delay |-> 0]
Result(x, e) == [state |-> x, effects |-> e]
Busy(x) == x.tag \in {"loading", "refreshing"}
Events == {"Read", "Show", "Hide", "Dispose", "Receive", "Old", "Future", "Deny", "Lost", "Limited", "Disabled", "Expired", "Incompatible"}
Failure(e) == CASE e = "Deny" -> "denied" [] e = "Lost" -> "unavailable" [] e = "Limited" -> "limited"
    [] e = "Disabled" -> "unconfigured" [] e = "Expired" -> "expired" [] OTHER -> "incompatible"
ReplyGeneration(x,e) == CASE e = "Old" -> x.generation - 1 [] e = "Future" -> x.generation + 1 [] OTHER -> x.generation
StepOwner(x,e) == IF x.tag = "disposed" THEN Result(x,None)
    ELSE IF e \in {"Hide", "Dispose"} THEN Result(
        [x EXCEPT !.tag = IF e = "Hide" THEN "hidden" ELSE "disposed", !.generation = @ + 1,
            !.failures = 0, !.value = FALSE, !.failure = "none"], [None EXCEPT !.cancel = TRUE])
    ELSE IF e \in {"Read", "Show"} THEN
        IF Busy(x) \/ (x.tag = "hidden" /\ e = "Read") THEN Result(x,None)
        ELSE Result([x EXCEPT !.tag = IF @ = "ready" THEN "refreshing" ELSE "loading",
            !.generation = @ + 1, !.failure = "none"], [None EXCEPT !.cancel = TRUE, !.read = TRUE])
    ELSE IF ~Busy(x) \/ (CheckGeneration /\ ReplyGeneration(x,e) # x.generation) THEN Result(x,None)
    ELSE IF e \in {"Receive", "Old", "Future"} THEN Result(
        [x EXCEPT !.tag = "ready", !.failures = 0, !.value = TRUE, !.failure = "none"], [None EXCEPT !.delay = 5000])
    ELSE LET count == IF x.failures < 3 THEN x.failures + 1 ELSE 3
             delay == IF e = "Limited" THEN 250 * (2 ^ count)
                ELSE IF count < 3 THEN 5000 * (2 ^ count) ELSE 30000
         IN Result([x EXCEPT !.tag = "failed", !.failures = count, !.failure = Failure(e),
             !.value = IF e = "Deny" /\ ~CheckDenial THEN @ ELSE FALSE],
             [None EXCEPT !.delay = IF e \in {"Lost", "Limited"} THEN delay ELSE 0])
Init == /\ a = Initial /\ b = Initial /\ effects = None /\ last = "Init" /\ fresh = TRUE
Step == \E owner \in {"A", "B"}, event \in Events:
    LET before == IF owner = "A" THEN a ELSE b
        outcome == StepOwner(before,event)
    IN /\ (event \in {"Read", "Show", "Hide", "Dispose"} => before.generation < 3)
       /\ a' = IF owner = "A" THEN outcome.state ELSE a
       /\ b' = IF owner = "B" THEN outcome.state ELSE b
       /\ effects' = outcome.effects
       /\ last' = owner \o event
       /\ fresh' = (event \in {"Old", "Future"} => outcome.state = before)
NoStaleReply == fresh
ClearDenied == \A x \in {a,b}: x.failure = "denied" => ~x.value
NoHiddenDisclosure == \A x \in {a,b}: x.tag \in {"hidden", "disposed", "idle", "loading"} => ~x.value
Spec == Init /\ [][Step]_vars
=============================================================================

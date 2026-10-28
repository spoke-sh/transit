------------------------- MODULE StatementResult -------------------------
EXTENDS Naturals, Integers

\* SQL_RESULTS_V1 logical progress, independently specified from Progress.zig.
\* MaxRows bounds exploration, not an implementation quota. Identity 0 is the
\* original triple; 1/2/3 change only result/schema/observation respectively.
CONSTANTS MaxRows, CheckIdentity, CheckCount, CheckRelease,
          CheckTerminal, CheckPreserveCompletion
VARIABLES s, last, error, safety
vars == <<s, last, error, safety>>
Event(kind, rows, identity) == [kind |-> kind, rows |-> rows, identity |-> identity]
Initial == [received |-> 0, delivered |-> 0, outcome |-> "open",
            consumption |-> "reading", released |-> FALSE,
            terminal |-> -1, evidence |-> FALSE]
Result(state, err) == [state |-> state, error |-> err]
OK(state) == Result(state, "none")
Reading(x) == ~x.released /\ x.consumption = "reading"
Live(x) == ~CheckRelease \/ Reading(x)

Receive(x, n, identity) ==
    IF CheckIdentity /\ identity # 0 THEN Result(x, "ResultIdentityChanged")
    ELSE IF ~Live(x) \/ x.outcome # "open" \/ n = 0
        THEN Result(x, "InvalidResultTransition")
    ELSE OK([x EXCEPT !.received = @ + n])
Deliver(x, n) ==
    IF ~Live(x) \/ x.outcome \notin {"open", "complete"} \/ n = 0
       \/ n > x.received - x.delivered THEN Result(x, "InvalidResultTransition")
    ELSE OK([x EXCEPT !.delivered = @ + n,
        !.consumption = IF x.outcome = "complete" /\ x.delivered + n = x.received
                       THEN "exhausted" ELSE x.consumption])
Finish(x, n, identity) ==
    IF CheckIdentity /\ identity # 0 THEN Result(x, "ResultIdentityChanged")
    ELSE IF ~Live(x) \/ x.outcome # "open" THEN Result(x, "InvalidResultTransition")
    ELSE IF CheckCount /\ n # x.received THEN Result(x, "InvalidResultCount")
    ELSE OK([x EXCEPT !.outcome = "complete", !.terminal = n, !.evidence = TRUE,
        !.consumption = IF x.delivered = x.received THEN "exhausted" ELSE x.consumption])
Fail(x, cancelled) == OK([x EXCEPT
    !.outcome = IF x.outcome = "open" THEN IF cancelled THEN "cancelled" ELSE "failed" ELSE x.outcome,
    !.consumption = IF x.consumption = "reading" THEN "stopped" ELSE x.consumption])
Release(x) ==
    LET closed == [x EXCEPT !.released = TRUE,
        !.consumption = IF x.consumption = "reading" THEN "stopped" ELSE x.consumption]
    IN IF ~CheckTerminal /\ x.outcome = "open"
       THEN OK([closed EXCEPT !.outcome = "complete", !.terminal = x.received])
       ELSE IF ~CheckPreserveCompletion /\ x.outcome = "complete"
       THEN OK([closed EXCEPT !.outcome = "open", !.terminal = -1, !.evidence = FALSE])
       ELSE OK(closed)
Transition(x, e) == CASE
    e.kind = "receive" -> Receive(x, e.rows, e.identity)
    [] e.kind = "deliver" -> Deliver(x, e.rows)
    [] e.kind = "finish" -> Finish(x, e.rows, e.identity)
    [] e.kind = "fail" -> Fail(x, FALSE)
    [] e.kind = "cancel" -> Fail(x, TRUE)
    [] e.kind = "release" -> Release(x)
Audit(x, y, e, err) == [
    attribution |-> (e.kind \in {"receive", "finish"} /\ err = "none") => e.identity = 0,
    release |-> (~Reading(x) /\ e.kind \in {"receive", "deliver", "finish"}) => err # "none",
    completion |-> x.outcome = "complete" => (y.outcome = "complete" /\ y.terminal = x.terminal),
    monotone |-> (y.received >= x.received /\ y.delivered >= x.delivered),
    terminal |-> x.outcome = "complete" => y.received = x.received]
Events ==
    {Event(k, n, i) : k \in {"receive", "finish"}, n \in 0..(MaxRows+1), i \in 0..3}
    \cup {Event("deliver", n, 0) : n \in 0..(MaxRows+1)}
    \cup {Event(k, 0, 0) : k \in {"fail", "cancel", "release"}}
Init == /\ s = Initial /\ error = "none" /\ last = Event("Init", 0, 0)
        /\ safety = Audit(Initial, Initial, last, error)
Step(e) ==
    /\ e \in Events
    /\ LET result == Transition(s, e) IN
       /\ result.state.received <= MaxRows
       /\ s' = result.state /\ error' = result.error
       /\ safety' = Audit(s, s', e, error')
    /\ last' = e
Next == \E e \in Events : Step(e)
Spec == Init /\ [][Next]_vars

TypeOK == /\ s.received \in Nat /\ s.delivered \in Nat /\ s.terminal \in {-1} \cup Nat
          /\ s.outcome \in {"open", "complete", "failed", "cancelled"}
          /\ s.consumption \in {"reading", "exhausted", "stopped"}
          /\ s.released \in BOOLEAN /\ s.evidence \in BOOLEAN
          /\ error \in {"none", "ResultIdentityChanged", "InvalidResultTransition", "InvalidResultCount"}
ProgressBounds == s.delivered <= s.received
TerminalAgreement == s.outcome = "complete" => s.terminal = s.received
VerifiedTerminal == s.outcome = "complete" => s.evidence
StableAttribution == safety.attribution
ReleasedIsFinal == safety.release
CompletionPreserved == safety.completion
MonotoneProgress == safety.monotone
NoRowsAfterTerminal == safety.terminal
Exhaustion == s.consumption = "exhausted" =>
             (s.outcome = "complete" /\ s.delivered = s.received)
=============================================================================

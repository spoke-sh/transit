-------------------------- MODULE BoardScheduler --------------------------
EXTENDS Naturals, TLC
VARIABLES s, last
vars == <<s,last>>
Init == /\ s = [read |-> 0, control |-> 0] /\ last = "Init"
Step == \E e \in {"ReadStart","ReadFinish","ControlStart","ControlFinish"}:
    /\ s' = CASE e = "ReadStart" -> [s EXCEPT !.read = IF @ < 2 THEN @ + 1 ELSE @]
        [] e = "ReadFinish" -> [s EXCEPT !.read = IF @ > 0 THEN @ - 1 ELSE @]
        [] e = "ControlStart" -> [s EXCEPT !.control = IF @ < 1 THEN @ + 1 ELSE @]
        [] OTHER -> [s EXCEPT !.control = IF @ > 0 THEN @ - 1 ELSE @]
    /\ last' = e
Bounded == s.read \in 0..2 /\ s.control \in 0..1
Spec == Init /\ [][Step]_vars
=============================================================================

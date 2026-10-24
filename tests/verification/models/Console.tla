---------------------------- MODULE Console ----------------------------
EXTENDS Naturals, TLC
CONSTANTS CheckFresh, CheckUnique, CheckBasis, CheckRestore, CheckOwnership, CheckProtected
VARIABLES s, effects, last, safety
vars == <<s, effects, last, safety>>

None == [cancel |-> FALSE, clear |-> FALSE, install |-> FALSE, action |-> "none"]
Emit(a) == [None EXCEPT !.action = a]
Result(x, f) == [state |-> x, effect |-> f]
Borrowing == {"fetching", "validating", "obsolete", "cancelling"}
Busy(x) == x.request \in Borrowing
Dismiss(x) == [x EXCEPT !.mode = IF @ = "completion" THEN "editing" ELSE @,
    !.request = IF Busy(x) THEN "cancelling" ELSE @,
    !.intent = "choose", !.freshness = "pending"]
DismissEffects(x) == [None EXCEPT !.cancel = Busy(x), !.clear = TRUE]
Restore(x) == [x EXCEPT !.text = IF CheckRestore THEN x.saved ELSE 0,
    !.cursor = IF CheckRestore THEN x.savedCursor ELSE 0,
    !.mode = "editing", !.filter = 0, !.matched = FALSE, !.failed = FALSE]
Changed(x) == [x EXCEPT
    !.request = IF @ \in {"fetching", "validating"} THEN "obsolete" ELSE @,
    !.intent = "choose", !.freshness = "pending"]
Open(x, intent) == IF x.request # "idle" \/ x.mode = "history" THEN Result(x, None)
    ELSE Result([x EXCEPT !.mode = "completion", !.request = "fetching",
        !.intent = intent, !.freshness = "pending", !.source = "remote"],
        [None EXCEPT !.clear = TRUE, !.action = "acquire"])
Refresh(x) == IF x.mode = "completion" /\ x.request = "idle" /\ x.freshness = "pending"
    THEN Result([x EXCEPT !.request = "fetching"], Emit("acquire")) ELSE Result(x, None)
HistoryAccept(x) == IF x.mode = "history" /\ x.matched /\ ~x.failed
    THEN Result([x EXCEPT !.mode = "editing", !.filter = 0, !.matched = FALSE, !.failed = FALSE], None)
    ELSE Result(x, None)
Accept(x, candidate) == CASE x.mode = "history" -> HistoryAccept(x)
    [] x.mode = "editing" -> Open(x, "unique")
    [] x.request # "idle" -> Result(x, None)
    [] x.freshness = "unavailable" -> Open(x, "choose")
    [] x.freshness = "pending" -> Refresh(x)
    [] ~candidate -> Result(Dismiss(x), DismissEffects(x))
    [] x.source = "local" -> Result(x, Emit("apply"))
    [] OTHER -> Result([x EXCEPT !.request = "validating"], Emit("validate"))
Reply(x, unique, matches, interrupted) ==
    IF x.request \notin {"fetching", "validating", "obsolete"} THEN Result(x, None)
    ELSE IF CheckFresh /\ (x.request = "obsolete" \/ interrupted \/ x.mode # "completion")
        THEN Result([x EXCEPT !.request = "idle", !.intent = "choose", !.freshness = "pending"], None)
    ELSE LET ready == [x EXCEPT !.request = "idle", !.source = "remote", !.freshness = "current"]
        IN IF x.request = "validating" \/ (~CheckFresh /\ x.request = "obsolete")
            THEN Result([ready EXCEPT !.intent = "choose"],
                IF (~CheckBasis \/ matches) /\ (~CheckUnique \/ x.intent # "unique" \/ unique)
                THEN Emit("apply") ELSE [None EXCEPT !.install = TRUE])
        ELSE IF x.intent = "unique" /\ unique
            THEN Result([ready EXCEPT !.request = "validating"], [None EXCEPT !.install = TRUE, !.action = "validate"])
        ELSE Result([ready EXCEPT !.intent = "choose"], [None EXCEPT !.install = TRUE])

Events == {"Type", "Move", "Filter", "Match", "Miss", "OpenUnique", "OpenMenu",
    "Refresh", "Remote", "LocalUnique", "LocalMany", "ReplyUniqueSame", "ReplyUniqueChanged",
    "ReplyManySame", "ReplyManyChanged", "ReplyInterrupted", "Failed", "Protected",
    "Joined", "Accept", "AcceptEmpty", "Enter", "EnterEmpty", "Dismiss", "Cancel",
    "Search", "HistoryAccept", "Clear", "Executed"}

\* Payload classes stand for arbitrary text, candidate sets and validated bases.
\* Decoder/grammar, buffers, transport and wall-clock time are outside this model.
Enabled(e) == CASE e \in {"Type", "Move"} -> s.mode # "history" /\ s.request \notin {"executing", "cancelling"}
    [] e \in {"Filter", "Match", "Miss"} -> s.mode = "history" /\ s.request = "idle"
    [] e = "Remote" -> s.request = "fetching"
    [] e \in {"LocalUnique", "LocalMany"} -> s.request = "fetching"
    [] e \in {"ReplyUniqueSame", "ReplyUniqueChanged", "ReplyManySame", "ReplyManyChanged", "ReplyInterrupted", "Failed"}
        -> s.request \in {"fetching", "validating", "obsolete"}
    [] e = "Joined" -> s.request = "cancelling"
    [] e = "Executed" -> s.request = "executing"
    [] OTHER -> TRUE

Transition(e) ==
    IF s.request = "executing" /\ e \notin {"Executed", "Protected", "Clear", "Dismiss"} THEN Result(s, None)
    ELSE IF CheckOwnership /\ s.request = "cancelling" /\ e \notin {"Joined", "Protected"} THEN Result(s, None)
    ELSE CASE e = "Type" -> Result(Changed([s EXCEPT !.text = 1, !.cursor = 1]), None)
    [] e = "Move" -> Result(Changed([s EXCEPT !.cursor = 0]), None)
    [] e = "Filter" -> Result([s EXCEPT !.filter = 3], None)
    [] e = "Match" -> Result(Changed([s EXCEPT !.text = 2, !.cursor = 1, !.matched = TRUE, !.failed = FALSE]), None)
    [] e = "Miss" -> Result([s EXCEPT !.failed = TRUE], None)
    [] e = "OpenUnique" -> Open(s, "unique")
    [] e = "OpenMenu" -> Open(s, "choose")
    [] e = "Refresh" -> Refresh(s)
    [] e = "Remote" -> Result([s EXCEPT !.source = "remote"], None)
    [] e \in {"LocalUnique", "LocalMany"} -> Result([s EXCEPT !.request = "idle", !.source = "local", !.freshness = "current", !.intent = "choose"],
        [None EXCEPT !.install = TRUE, !.action = IF s.intent = "unique" /\ e = "LocalUnique" THEN "apply" ELSE "none"])
    [] e = "ReplyUniqueSame" -> Reply(s, TRUE, TRUE, FALSE)
    [] e = "ReplyUniqueChanged" -> Reply(s, TRUE, FALSE, FALSE)
    [] e = "ReplyManySame" -> Reply(s, FALSE, TRUE, FALSE)
    [] e = "ReplyManyChanged" -> Reply(s, FALSE, FALSE, FALSE)
    [] e = "ReplyInterrupted" -> Reply(s, TRUE, TRUE, TRUE)
    [] e = "Failed" -> IF s.request = "obsolete" THEN Result([s EXCEPT !.request = "idle"], None)
        ELSE Result([s EXCEPT !.request = "idle", !.intent = "choose", !.freshness = "unavailable"], [None EXCEPT !.clear = TRUE])
    [] e = "Protected" -> IF ~CheckProtected /\ s.request = "obsolete" THEN Result([s EXCEPT !.request = "idle"], None)
        ELSE Result([Dismiss(s) EXCEPT !.mode = "editing", !.text = 0, !.cursor = 0,
            !.saved = 0, !.savedCursor = 0, !.filter = 0, !.matched = FALSE, !.failed = FALSE],
            [DismissEffects(s) EXCEPT !.action = "erase"])
    [] e = "Joined" -> Result([s EXCEPT !.request = "idle"], None)
    [] e = "Accept" -> Accept(s, TRUE)
    [] e = "AcceptEmpty" -> Accept(s, FALSE)
    [] e \in {"Enter", "EnterEmpty"} -> CASE s.mode = "history" -> HistoryAccept(s)
        [] s.mode = "completion" -> IF e = "Enter" THEN Accept(s, TRUE) ELSE Result(Dismiss(s), DismissEffects(s))
        [] s.request = "idle" \/ (~CheckOwnership /\ s.request = "cancelling") -> Result([s EXCEPT !.request = "executing"], Emit("submit"))
        [] OTHER -> Result(s, None)
    [] e = "Dismiss" -> Result(Dismiss(s), DismissEffects(s))
    [] e = "Cancel" -> LET restored == IF s.mode = "history" THEN Restore(s) ELSE s
        IN Result(Dismiss(restored), DismissEffects(restored))
    [] e = "Search" -> IF s.mode = "history" THEN Result(s, Emit("search_older"))
        ELSE Result([Dismiss(s) EXCEPT !.mode = "history", !.saved = s.text, !.savedCursor = s.cursor,
            !.filter = s.text, !.matched = FALSE, !.failed = FALSE],
            [DismissEffects(s) EXCEPT !.action = IF s.text # 0 THEN "search_newest" ELSE "none"])
    [] e = "HistoryAccept" -> HistoryAccept(s)
    [] e = "Clear" -> Result([Dismiss(s) EXCEPT !.mode = "editing", !.text = 0, !.cursor = 0,
        !.filter = 0, !.matched = FALSE, !.failed = FALSE], DismissEffects(s))
    [] e = "Executed" -> Result([s EXCEPT !.request = "idle"], None)

Init ==
    /\ s = [mode |-> "editing", request |-> "idle", freshness |-> "pending",
        intent |-> "choose", source |-> "remote", text |-> 0, cursor |-> 0,
        saved |-> 0, savedCursor |-> 0, filter |-> 0, matched |-> FALSE, failed |-> FALSE]
    /\ effects = None /\ last = "Init"
    /\ safety = [restore |-> TRUE, stale |-> TRUE, unique |-> TRUE, basis |-> TRUE, owner |-> TRUE, submit |-> TRUE, private |-> TRUE]
Step(e) ==
    /\ Enabled(e)
    /\ LET result == Transition(e) IN (s' = result.state /\ effects' = result.effect)
    /\ last' = e
    /\ safety' = [
        restore |-> (e = "Cancel" /\ s.mode = "history" /\ s.request # "cancelling") => (s'.text = s.saved /\ s'.cursor = s.savedCursor),
        stale |-> (e = "ReplyInterrupted" \/ (s.request = "obsolete" /\ e \in {"ReplyUniqueSame", "ReplyUniqueChanged", "ReplyManySame", "ReplyManyChanged"})) => (~effects'.install /\ effects'.action \notin {"apply", "validate"}),
        unique |-> (s.request = "validating" /\ s.intent = "unique" /\ e \in {"ReplyManySame", "ReplyManyChanged"}) => effects'.action # "apply",
        basis |-> e \in {"ReplyUniqueChanged", "ReplyManyChanged"} => effects'.action # "apply",
        owner |-> effects'.action \in {"acquire", "submit"} => s.request = "idle",
        submit |-> effects'.action = "submit" => (e \in {"Enter", "EnterEmpty"} /\ s.mode = "editing"),
        private |-> e = "Protected" => (s'.text = 0 /\ s'.saved = 0 /\ s'.filter = 0 /\ ~s'.matched /\ effects'.clear /\ effects'.action = "erase")]
Next == \E e \in Events : Step(e)
FinishRequest == \E e \in {"Joined", "Failed", "Executed"} : Step(e)
Spec == Init /\ [][Next]_vars
FairSpec == Spec /\ WF_vars(FinishRequest)
BorrowerReleased == [](s.request # "idle" => <> (s.request = "idle"))
TypeOK ==
    /\ s.mode \in {"editing", "history", "completion"}
    /\ s.request \in {"idle", "fetching", "validating", "obsolete", "cancelling", "executing"}
    /\ s.freshness \in {"pending", "current", "unavailable"}
    /\ s.intent \in {"choose", "unique"} /\ s.source \in {"local", "remote"}
    /\ s.text \in 0..2 /\ s.saved \in 0..2 /\ s.filter \in 0..3
    /\ s.cursor \in 0..1 /\ s.savedCursor \in 0..1
    /\ s.matched \in BOOLEAN /\ s.failed \in BOOLEAN
RestoresDraft == safety.restore
NoStaleInsertion == safety.stale
ProvenUnique == safety.unique
ValidatedBasis == safety.basis
InteractionShape == /\ (s.request \in {"fetching", "validating", "obsolete"} => s.mode = "completion")
                    /\ (s.request = "executing" => s.mode = "editing")
                    /\ (s.intent = "unique" => s.mode = "completion" /\ s.request \in {"fetching", "validating"})
ExclusiveOwner == safety.owner
ExplicitSubmission == safety.submit
ClearsPrivate == safety.private
=============================================================================

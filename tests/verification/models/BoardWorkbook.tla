-------------------------- MODULE BoardWorkbook --------------------------
EXTENDS Naturals, TLC
CONSTANTS CheckLineage, CheckComposition, CheckDenial
VARIABLES s, effects, last
vars == <<s, effects, last>>

IdleEffects == [action |-> "none", cancel |-> FALSE]

Init ==
    /\ s = [
        active |-> TRUE,
        live |-> FALSE,
        composing |-> FALSE,
        phase |-> "idle",
        queued |-> FALSE,
        generation |-> 0,
        watermark |-> 1,
        depUsesSource |-> TRUE,
        issue |-> "none",
        sourceState |-> "Draft",
        depState |-> "Waiting",
        sourceOut |-> "none",
        depOut |-> "none",
        failure |-> "none"
       ]
    /\ effects = IdleEffects
    /\ last = "Init"

NextGen(g) == g + 1
NextWatermark(w) == w + 1
Demote(out) == IF out = "current" THEN "earlier" ELSE out

NeedsEval(st) ==
    st.sourceOut /= "current" \/ st.depOut /= "current" \/ st.issue /= "none"

IdleCellState(live, out, waitingOnInput, issue) ==
    IF issue = "invalid" THEN "Invalid"
    ELSE IF out = "current" THEN "Complete"
    ELSE IF live \/ waitingOnInput THEN "Waiting"
    ELSE "Draft"

StartValidation(st) ==
    [st EXCEPT
        !.phase = "validating",
        !.queued = FALSE,
        !.generation = NextGen(@),
        !.failure = "none",
        !.sourceState = IF st.sourceOut = "current" THEN "Complete" ELSE "Queued",
        !.depState = IF st.depOut = "current" THEN "Complete" ELSE "Queued"]

Transition(e) ==
    CASE e = "EditSource" ->
        LET sOut == Demote(s.sourceOut)
            dOut == IF s.depUsesSource /\ CheckLineage THEN Demote(s.depOut) ELSE s.depOut
            wasBusy == s.phase /= "idle"
            canSchedule == s.active /\ s.live /\ (~s.composing \/ ~CheckComposition)
            nextPhase == IF canSchedule THEN "debouncing" ELSE "idle"
        IN [state |-> [s EXCEPT
                !.issue = "none",
                !.failure = "none",
                !.queued = FALSE,
                !.generation = IF s.phase \in {"validating", "evaluating"} THEN NextGen(@) ELSE @,
                !.phase = nextPhase,
                !.sourceOut = sOut,
                !.depOut = dOut,
                !.sourceState = IdleCellState(s.live, sOut, FALSE, "none"),
                !.depState = IdleCellState(s.live, dOut, s.depUsesSource /\ sOut /= "current", "none")],
            effects |-> [
                action |-> IF canSchedule THEN "schedule" ELSE "none",
                cancel |-> wasBusy]]

    [] e = "EditDep" ->
        LET dOut == Demote(s.depOut)
            wasBusy == s.phase /= "idle"
            canSchedule == s.active /\ s.live /\ (~s.composing \/ ~CheckComposition)
            nextPhase == IF canSchedule THEN "debouncing" ELSE "idle"
        IN [state |-> [s EXCEPT
                !.issue = "none",
                !.failure = "none",
                !.queued = FALSE,
                !.generation = IF s.phase \in {"validating", "evaluating"} THEN NextGen(@) ELSE @,
                !.phase = nextPhase,
                !.depOut = dOut,
                !.sourceState = IdleCellState(s.live, s.sourceOut, FALSE, "none"),
                !.depState = IdleCellState(s.live, dOut, s.depUsesSource /\ s.sourceOut /= "current", "none")],
            effects |-> [
                action |-> IF canSchedule THEN "schedule" ELSE "none",
                cancel |-> wasBusy]]

    [] e = "ToggleDep" ->
        LET nextDep == ~s.depUsesSource
            dOut == Demote(s.depOut)
            wasBusy == s.phase /= "idle"
            canSchedule == s.active /\ s.live /\ (~s.composing \/ ~CheckComposition)
            nextPhase == IF canSchedule THEN "debouncing" ELSE "idle"
        IN [state |-> [s EXCEPT
                !.depUsesSource = nextDep,
                !.issue = "none",
                !.failure = "none",
                !.queued = FALSE,
                !.generation = IF s.phase \in {"validating", "evaluating"} THEN NextGen(@) ELSE @,
                !.phase = nextPhase,
                !.depOut = dOut,
                !.sourceState = IdleCellState(s.live, s.sourceOut, FALSE, "none"),
                !.depState = IdleCellState(s.live, dOut, nextDep /\ s.sourceOut /= "current", "none")],
            effects |-> [
                action |-> IF canSchedule THEN "schedule" ELSE "none",
                cancel |-> wasBusy]]

    [] e = "ComposeStart" ->
        [state |-> [s EXCEPT
            !.composing = TRUE,
            !.phase = IF @ = "debouncing" /\ CheckComposition THEN "idle" ELSE @],
         effects |-> [action |-> "none", cancel |-> s.phase = "debouncing" /\ CheckComposition]]

    [] e = "ComposeEnd" ->
        LET canSchedule == s.active /\ s.live /\ NeedsEval(s) /\ s.phase = "idle"
        IN [state |-> [s EXCEPT
                !.composing = FALSE,
                !.phase = IF canSchedule THEN "debouncing" ELSE @],
            effects |-> [action |-> IF canSchedule THEN "schedule" ELSE "none", cancel |-> FALSE]]

    [] e = "EnableLive" ->
        IF ~s.active THEN [state |-> s, effects |-> IdleEffects]
        ELSE IF (s.composing /\ CheckComposition) \/ ~NeedsEval(s) THEN
            [state |-> [s EXCEPT !.live = TRUE], effects |-> IdleEffects]
        ELSE IF s.phase \in {"validating", "evaluating"} THEN
            [state |-> [s EXCEPT !.live = TRUE, !.queued = TRUE], effects |-> IdleEffects]
        ELSE
            [state |-> [s EXCEPT
                !.live = TRUE,
                !.phase = "debouncing",
                !.sourceState = IF s.sourceOut = "current" THEN "Complete" ELSE "Waiting",
                !.depState = IF s.depOut = "current" THEN "Complete" ELSE "Waiting"],
             effects |-> [action |-> "schedule", cancel |-> s.phase = "debouncing"]]

    [] e = "PauseLive" ->
        [state |-> [s EXCEPT
            !.live = FALSE,
            !.phase = IF @ = "debouncing" THEN "idle" ELSE @,
            !.sourceState = IF @ = "Waiting" THEN "Draft" ELSE @,
            !.depState = IF @ = "Waiting" /\ ~(s.depUsesSource /\ s.sourceOut /= "current")
                         THEN "Draft" ELSE @],
         effects |-> [action |-> "none", cancel |-> s.phase = "debouncing"]]

    [] e = "QuietTick" ->
        IF ~s.active \/ ~s.live \/ (s.composing /\ CheckComposition) \/ s.phase /= "debouncing" \/ ~NeedsEval(s)
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> StartValidation(s),
              effects |-> [action |-> "validate", cancel |-> FALSE]]

    [] e = "Blur" ->
        IF ~s.active \/ (s.composing /\ CheckComposition) \/ ~NeedsEval(s)
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE IF s.phase \in {"validating", "evaluating"}
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> StartValidation(s),
              effects |-> [action |-> "validate", cancel |-> s.phase = "debouncing"]]

    [] e = "Run" ->
        IF ~s.active \/ (s.composing /\ CheckComposition)
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE IF s.phase \in {"validating", "evaluating"}
        THEN [state |-> [s EXCEPT !.queued = TRUE], effects |-> IdleEffects]
        ELSE LET forced == [s EXCEPT
                    !.sourceOut = Demote(@),
                    !.depOut = Demote(@)]
             IN [state |-> [StartValidation(forced) EXCEPT !.queued = TRUE],
                 effects |-> [action |-> "validate", cancel |-> s.phase = "debouncing"]]

    [] e = "ValidateOk" ->
        IF s.phase /= "validating"
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE IF s.live \/ s.queued
        THEN [state |-> [s EXCEPT
                !.phase = "evaluating",
                !.queued = FALSE,
                !.issue = "none",
                !.sourceState = IF s.sourceOut = "current" THEN "Complete" ELSE "Running",
                !.depState = IF s.depOut = "current" THEN "Complete" ELSE "Running"],
              effects |-> [action |-> "evaluate", cancel |-> FALSE]]
        ELSE [state |-> [s EXCEPT
                !.phase = "idle",
                !.issue = "none",
                !.sourceState = IdleCellState(s.live, s.sourceOut, FALSE, "none"),
                !.depState = IdleCellState(s.live, s.depOut, s.depUsesSource /\ s.sourceOut /= "current", "none")],
              effects |-> IdleEffects]

    [] e = "ValidateInvalid" ->
        IF s.phase /= "validating"
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> [s EXCEPT
                !.phase = "idle",
                !.queued = FALSE,
                !.issue = "invalid",
                !.sourceOut = Demote(@),
                !.depOut = Demote(@),
                !.sourceState = "Invalid",
                !.depState = IF s.depUsesSource THEN "Incomplete" ELSE "Invalid"],
              effects |-> IdleEffects]

    [] e = "ValidateOld" ->
        [state |-> s, effects |-> IdleEffects]

    [] e = "EvalComplete" ->
        IF s.phase /= "evaluating"
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> [s EXCEPT
                !.phase = "idle",
                !.queued = FALSE,
                !.issue = "none",
                !.failure = "none",
                !.sourceState = "Complete",
                !.depState = "Complete",
                !.sourceOut = "current",
                !.depOut = "current"],
              effects |-> IdleEffects]

    [] e = "EvalBlocked" ->
        IF s.phase /= "evaluating"
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> [s EXCEPT
                !.phase = "idle",
                !.queued = FALSE,
                !.issue = "none",
                !.sourceOut = Demote(@),
                !.depOut = IF s.depUsesSource THEN Demote(@) ELSE "current",
                !.sourceState = "Incomplete",
                !.depState = IF s.depUsesSource THEN "Incomplete" ELSE "Complete"],
              effects |-> IdleEffects]

    [] e = "EvalOld" ->
        [state |-> s, effects |-> IdleEffects]

    [] e = "WatermarkAdvance" ->
        LET sOut == IF CheckLineage THEN Demote(s.sourceOut) ELSE s.sourceOut
            dOut == IF CheckLineage THEN Demote(s.depOut) ELSE s.depOut
            wasBusy == s.phase /= "idle"
            canValidate == s.active /\ s.live /\ (~s.composing \/ ~CheckComposition)
            base == [s EXCEPT
                !.watermark = NextWatermark(@),
                !.generation = IF s.phase \in {"validating", "evaluating"} THEN NextGen(@) ELSE @,
                !.phase = "idle",
                !.queued = FALSE,
                !.sourceOut = sOut,
                !.depOut = dOut,
                !.sourceState = IdleCellState(s.live, sOut, FALSE, s.issue),
                !.depState = IdleCellState(s.live, dOut, s.depUsesSource /\ sOut /= "current", s.issue)]
        IN IF canValidate /\ s.issue = "none"
           THEN [state |-> StartValidation(base),
                 effects |-> [action |-> "validate", cancel |-> wasBusy]]
           ELSE [state |-> base,
                 effects |-> [action |-> "none", cancel |-> wasBusy]]

    [] e = "Deny" ->
        [state |-> [s EXCEPT
            !.live = FALSE,
            !.composing = FALSE,
            !.phase = "idle",
            !.queued = FALSE,
            !.generation = NextGen(@),
            !.failure = "denied",
            !.issue = "none",
            !.sourceOut = IF CheckDenial THEN "none" ELSE Demote(@),
            !.depOut = IF CheckDenial THEN "none" ELSE Demote(@),
            !.sourceState = "Draft",
            !.depState = IF s.depUsesSource THEN "Waiting" ELSE "Draft"],
         effects |-> [action |-> "close", cancel |-> TRUE]]

    [] e = "Lost" ->
        IF s.phase \notin {"validating", "evaluating"}
        THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> [s EXCEPT
                !.phase = "idle",
                !.queued = FALSE,
                !.failure = "unavailable",
                !.sourceOut = Demote(@),
                !.depOut = Demote(@),
                !.sourceState = "Incomplete",
                !.depState = "Incomplete"],
              effects |-> IdleEffects]

    [] e = "Hide" ->
        [state |-> [s EXCEPT
            !.active = FALSE,
            !.live = FALSE,
            !.composing = FALSE,
            !.phase = "idle",
            !.queued = FALSE,
            !.generation = NextGen(@),
            !.sourceOut = "none",
            !.depOut = "none",
            !.sourceState = "Draft",
            !.depState = IF s.depUsesSource THEN "Waiting" ELSE "Draft"],
         effects |-> [action |-> "close", cancel |-> TRUE]]

    [] OTHER ->
        IF s.active THEN [state |-> s, effects |-> IdleEffects]
        ELSE [state |-> [s EXCEPT !.active = TRUE], effects |-> IdleEffects]

Events == {
    "EditSource", "EditDep", "ToggleDep",
    "ComposeStart", "ComposeEnd",
    "EnableLive", "PauseLive",
    "QuietTick", "Blur", "Run",
    "ValidateOk", "ValidateInvalid", "ValidateOld",
    "EvalComplete", "EvalBlocked", "EvalOld",
    "WatermarkAdvance", "Deny", "Lost",
    "Hide", "Show"
}

Step == \E e \in Events :
    LET next == Transition(e) IN
    /\ next.state.generation <= 2
    /\ next.state.watermark <= 2
    /\ s' = next.state
    /\ effects' = next.effects
    /\ last' = e

CurrentImpliesComplete ==
    /\ (s.sourceOut = "current" => (s.sourceState = "Complete" /\ s.issue = "none" /\ s.active))
    /\ (s.depOut = "current" =>
        (s.depState = "Complete" /\ s.issue = "none" /\ s.active /\
         (~s.depUsesSource \/ s.sourceOut = "current")))
    /\ (last = "WatermarkAdvance" => (s.sourceOut /= "current" /\ s.depOut /= "current"))

CompositionBlocksEval ==
    ~(s.composing /\ s.phase = "debouncing")

ClearDeniedAndHidden ==
    ((s.failure = "denied" \/ ~s.active) => (s.sourceOut = "none" /\ s.depOut = "none"))

Spec == Init /\ [][Step]_vars
=============================================================================

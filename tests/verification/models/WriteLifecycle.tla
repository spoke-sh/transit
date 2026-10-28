------------------------- MODULE WriteLifecycle -------------------------
EXTENDS Naturals, Sequences, FiniteSets, TLC

\* One frozen statement, three row slots, one independent later INSERT.
\* "combined" is a candidate atomic acceptance+decision, not installed SQL.
\* Durable publication is an assumption discharged separately by Wal.tla and
\* disk/object tests. TRUNCATE is a proposed contract, never executable evidence.
CONSTANTS Kind, Variant, Path, CheckOriginal, CheckBasis, CheckAtomic,
          CheckCounts, CheckFence, CheckPolicy, CheckDisclosure, CheckStable,
          CheckRetention, CheckDurability
VARIABLES s, last
vars == <<s, last>>
Empty == <<0, 0, 0>>
InitialRows == IF Kind = "insert" \/ Variant = "empty" THEN Empty
               ELSE IF Variant = "noop" THEN <<2, 2, 0>> ELSE <<1, 1, 0>>
Count(r) == Cardinality({i \in 1..3 : r[i] # 0})
Successor(r) == CASE Kind = "insert" -> [r EXCEPT ![1] = 2]
                 [] Kind = "update" -> [i \in 1..3 |-> IF r[i] = 0 THEN 0 ELSE 2]
                 [] OTHER -> Empty
Matched(r) == IF Kind = "insert" THEN 1 ELSE Count(r)
Changed(r) == Cardinality({i \in 1..3 : r[i] # Successor(r)[i]})
Good == [fence |-> TRUE, policy |-> TRUE, disclosure |-> TRUE]
Init == /\ s = [frozen |-> FALSE, accepted |-> FALSE, decision |-> "none",
                 first |-> "none", rows |-> InitialRows, durable |-> InitialRows,
                 basis |-> InitialRows, version |-> 0, frozenVersion |-> 0,
                 later |-> FALSE, applications |-> 0, matched |-> 0, changed |-> 0,
                 expectedMatched |-> 0, expectedChanged |-> 0, appliedVersion |-> 0,
                 owner |-> 1, epoch |-> 1, execute |-> TRUE, inspect |-> TRUE,
                 online |-> TRUE, retained |-> TRUE, knowledge |-> "unknown",
                 audit |-> Good]
        /\ last = "Init"
Freeze == /\ s.online /\ ~s.frozen /\ s.execute /\ s.owner = s.epoch
          /\ s' = [s EXCEPT !.frozen = TRUE, !.basis = s.rows,
                            !.frozenVersion = s.version, !.audit = Good]
          /\ last' = "Freeze"
Accept == /\ Path = "split" /\ s.online /\ s.frozen /\ ~s.accepted
          /\ s.execute /\ s.owner = s.epoch
          /\ s' = [s EXCEPT !.accepted = TRUE, !.audit = Good]
          /\ last' = "Accept"
Commit ==
    /\ s.online /\ s.frozen /\ (s.accepted \/ Path = "combined")
    /\ (s.decision = "none" \/ (~CheckOriginal /\ s.applications < 2))
    /\ (s.execute \/ ~CheckPolicy) /\ (s.owner = s.epoch \/ ~CheckFence)
    /\ LET basis == IF CheckBasis THEN s.basis ELSE s.rows
           refused == Variant = "invalid" \/ (CheckBasis /\ s.version # s.frozenVersion /\ (CheckOriginal \/ s.decision = "none"))
           outcome == IF refused THEN "rejected" ELSE "committed"
           successor == IF refused THEN s.rows ELSE Successor(basis)
           visible == IF CheckAtomic THEN successor ELSE [s.rows EXCEPT ![1] = successor[1]]
       IN s' = [s EXCEPT !.accepted = TRUE, !.decision = outcome,
                !.first = IF @ = "none" THEN outcome ELSE @,
                !.rows = visible, !.durable = IF CheckDurability THEN visible ELSE @,
                !.applications = @ + IF refused THEN 0 ELSE 1,
                !.version = @ + IF refused \/ (Changed(basis) = 0 /\ Kind # "truncate") THEN 0 ELSE 1,
                !.matched = IF refused THEN 0 ELSE IF CheckCounts THEN Matched(basis) ELSE 0,
                !.changed = IF refused THEN 0 ELSE Changed(basis),
                !.appliedVersion = IF CheckBasis THEN s.frozenVersion ELSE s.version,
                !.expectedMatched = IF refused THEN 0 ELSE Matched(s.basis),
                !.expectedChanged = IF refused THEN 0 ELSE Changed(s.basis),
                !.audit = [Good EXCEPT !.fence = s.owner = s.epoch, !.policy = s.execute]]
    /\ last' = "Commit"
Retry == /\ s.online /\ s.decision # "none"
         /\ s' = [s EXCEPT !.knowledge = IF s.inspect THEN s.decision ELSE "denied", !.audit = Good]
         /\ last' = "Retry"
Cancel == /\ s.online /\ s.accepted /\ (s.decision = "none" \/ ~CheckStable)
          /\ s.execute /\ s.owner = s.epoch
          /\ s' = [s EXCEPT !.decision = "cancelled",
                   !.first = IF @ = "none" THEN "cancelled" ELSE @, !.audit = Good]
          /\ last' = "Cancel"
Observe == /\ s.online
           /\ s' = [s EXCEPT !.knowledge = IF ~s.inspect /\ CheckDisclosure THEN "denied"
                    ELSE IF s.decision # "none" THEN s.decision
                    ELSE IF s.accepted THEN "pending" ELSE "unknown",
                    !.audit = [Good EXCEPT !.disclosure = s.inspect \/ CheckDisclosure]]
           /\ last' = "Observe"
LaterInsert == /\ s.online /\ ~s.later
               /\ s' = [s EXCEPT !.later = TRUE, !.rows[3] = 1, !.durable[3] = 1,
                                 !.version = @ + 1, !.audit = Good]
               /\ last' = "LaterInsert"
Crash == /\ s.online /\ s' = [s EXCEPT !.online = FALSE, !.knowledge = "unknown",
                                      !.rows = s.durable, !.audit = Good]
         /\ last' = "Crash"
Recover == /\ ~s.online /\ s' = [s EXCEPT !.online = TRUE, !.owner = s.epoch, !.audit = Good]
           /\ last' = "Recover"
Fence == /\ s.epoch = 1 /\ s' = [s EXCEPT !.epoch = 2, !.audit = Good] /\ last' = "Fence"
Execution == /\ s' = [s EXCEPT !.execute = ~@, !.audit = Good] /\ last' = "Execution"
Inspection == /\ s' = [s EXCEPT !.inspect = ~@, !.audit = Good] /\ last' = "Inspection"
LoseReply == /\ s' = [s EXCEPT !.knowledge = "unknown", !.audit = Good] /\ last' = "LoseReply"
Cleanup == /\ s.decision # "none"
           /\ s' = [s EXCEPT !.retained = CheckRetention, !.audit = Good] /\ last' = "Cleanup"
Next == Freeze \/ Accept \/ Commit \/ Retry \/ Cancel \/ Observe \/ LaterInsert
        \/ Crash \/ Recover \/ Fence \/ Execution \/ Inspection \/ LoseReply \/ Cleanup
Spec == Init /\ [][Next]_vars
FairSpec == Spec /\ WF_vars(Commit) /\ WF_vars(Observe)
EligibleProgress == (<>[](s.online /\ s.execute /\ s.owner = s.epoch)) =>
                    (s.accepted ~> (s.decision # "none"))
LearnableOutcome == (<>[](s.online /\ s.inspect)) =>
                    ((s.decision # "none") ~> (s.knowledge = s.decision))

TypeOK == /\ s.rows \in [1..3 -> 0..2] /\ s.durable \in [1..3 -> 0..2]
          /\ s.basis \in [1..3 -> 0..2] /\ s.owner \in {1,2} /\ s.epoch \in {1,2}
          /\ s.decision \in {"none", "committed", "rejected", "cancelled"}
          /\ s.knowledge \in {"unknown", "denied", "pending", "committed", "rejected", "cancelled"}
AcceptedDecision == s.decision # "none" => s.accepted /\ s.frozen
OriginalApplication == s.applications <= 1
FrozenSelection == s.decision = "committed" =>
    s.appliedVersion = s.frozenVersion
AtomicVisibility == s.decision = "committed" =>
    s.rows = Successor(s.basis) \/ (s.later /\ s.rows = [Successor(s.basis) EXCEPT ![3] = 1])
TruthfulCounts == s.decision = "committed" => s.matched = Matched(s.basis) /\ s.changed = Changed(s.basis)
DurablePublication == s.rows = s.durable
StableDecision == s.decision = s.first
FencedPublication == s.audit.fence
AuthorizedPublication == s.audit.policy
AuthorizedDisclosure == s.audit.disclosure
RetainedHistory == s.retained
=============================================================================

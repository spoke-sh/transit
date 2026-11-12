---------------------- MODULE TransactionDecision ----------------------
EXTENDS Naturals, FiniteSets

\* One original attempt, two written participants, two coordinator epochs.
\* Atomic log append and truthful participant verification are assumptions.
\* Payloads, cut acquisition, Table visibility and SQL are outside this model.
CONSTANTS CheckFrozen, CheckComplete, CheckFence, CheckPolicy,
          CheckStable, CheckDisclosure, CheckExecution, CheckRetirement
VARIABLES frozen, prepared, decision, first, epoch, owner, allowed,
          available, conflict, knowledge, audit, last, generation, retired
vars == <<frozen, prepared, decision, first, epoch, owner, allowed,
          available, conflict, knowledge, audit, last, generation, retired>>
Participants == {1, 2}
Outcomes == {"none", "committed", "aborted"}
Good == [policy |-> TRUE, fence |-> TRUE, disclosure |-> TRUE,
         execution |-> TRUE, retirement |-> TRUE]

Init == /\ frozen = FALSE /\ prepared = {}
        /\ decision = "none" /\ first = "none"
        /\ epoch = 1 /\ owner = 1 /\ allowed = TRUE
        /\ available = TRUE /\ conflict = FALSE
        /\ generation = 1 /\ retired = FALSE
        /\ knowledge = "unknown" /\ audit = Good /\ last = "Init"

Freeze == /\ ~frozen /\ allowed /\ owner = epoch
          /\ frozen' = TRUE /\ last' = "Freeze" /\ audit' = Good
          /\ UNCHANGED <<prepared, decision, first, epoch, owner, allowed,
                          available, conflict, knowledge, generation, retired>>
Prepare(p) == /\ frozen /\ decision = "none" /\ p \notin prepared
              /\ prepared' = prepared \cup {p}
              /\ last' = "Prepare" /\ audit' = Good
              /\ UNCHANGED <<frozen, decision, first, epoch, owner, allowed,
                              available, conflict, knowledge, generation, retired>>
Decide(outcome) ==
    /\ (frozen \/ ~CheckFrozen)
    /\ (decision = "none" \/ ~CheckStable)
    /\ (allowed \/ ~CheckPolicy)
    /\ (owner = epoch \/ ~CheckFence)
    /\ (outcome = "aborted" \/
        ((prepared = Participants \/ ~CheckComplete) /\ available /\ ~conflict /\
         (generation = 1 \/ ~CheckExecution) /\ (~retired \/ ~CheckRetirement)))
    /\ decision' = outcome
    /\ first' = IF first = "none" THEN outcome ELSE first
    \* A durable append does not imply receipt of its reply.
    /\ knowledge' = "unknown"
    /\ audit' = [policy |-> allowed, fence |-> owner = epoch, disclosure |-> TRUE,
                 execution |-> outcome = "aborted" \/ generation = 1,
                 retirement |-> outcome = "aborted" \/ ~retired]
    /\ last' = IF outcome = "committed" THEN "Commit" ELSE "Abort"
    /\ UNCHANGED <<frozen, prepared, epoch, owner, allowed, available, conflict, generation, retired>>
Observe ==
    /\ knowledge' = IF ~allowed /\ CheckDisclosure THEN "denied"
                     ELSE IF decision # "none" THEN decision
                     ELSE IF frozen THEN "preparing" ELSE "unknown"
    /\ audit' = [Good EXCEPT !.disclosure = allowed \/ knowledge' = "denied"]
    /\ last' = "Observe"
    /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner, allowed,
                    available, conflict, generation, retired>>
LoseReply == /\ knowledge' = "unknown" /\ last' = "LoseReply" /\ audit' = Good
             /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                             allowed, available, conflict, generation, retired>>
Recover == /\ owner' = epoch /\ knowledge' = "unknown"
           /\ last' = "Recover" /\ audit' = Good
           /\ UNCHANGED <<frozen, prepared, decision, first, epoch, allowed,
                           available, conflict, generation, retired>>
Fence == /\ epoch = 1 /\ epoch' = 2 /\ last' = "Fence" /\ audit' = Good
         /\ UNCHANGED <<frozen, prepared, decision, first, owner, allowed,
                         available, conflict, knowledge, generation, retired>>
Policy == /\ allowed' = ~allowed /\ last' = "Policy" /\ audit' = Good
          /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                          available, conflict, knowledge, generation, retired>>
Availability == /\ available' = ~available /\ last' = "Availability" /\ audit' = Good
                /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                                allowed, conflict, knowledge, generation, retired>>
Conflict == /\ conflict' = ~conflict /\ last' = "Conflict" /\ audit' = Good
            /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                            allowed, available, knowledge, generation, retired>>
Replace == /\ generation = 1 /\ generation' = 2
           /\ last' = "Replace" /\ audit' = Good
           /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                           allowed, available, conflict, knowledge, retired>>
Retire == /\ ~retired /\ retired' = TRUE
          /\ last' = "Retire" /\ audit' = Good
          /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                          allowed, available, conflict, knowledge, generation>>
Next == Freeze \/ (\E p \in Participants : Prepare(p))
        \/ Decide("committed") \/ Decide("aborted") \/ Observe \/ LoseReply
        \/ Recover \/ Fence \/ Policy \/ Availability \/ Conflict \/ Replace \/ Retire
Spec == Init /\ [][Next]_vars

TypeOK == /\ frozen \in BOOLEAN /\ prepared \subseteq Participants
          /\ decision \in Outcomes /\ first \in Outcomes
          /\ epoch \in {1, 2} /\ owner \in {1, 2}
          /\ generation \in {1, 2} /\ retired \in BOOLEAN
          /\ allowed \in BOOLEAN /\ available \in BOOLEAN /\ conflict \in BOOLEAN
          /\ knowledge \in {"unknown", "denied", "preparing", "committed", "aborted"}
FrozenDecision == decision # "none" => frozen
CompletePreparation == decision = "committed" => prepared = Participants
OriginalDecision == decision = first
CurrentPublication == audit.policy
FencedPublication == audit.fence
CurrentDisclosure == audit.disclosure
CurrentExecution == audit.execution
ExecutableLifetime == audit.retirement
HonestObservation == knowledge \in {"committed", "aborted"} => knowledge = decision
=============================================================================

---------------------- MODULE TransactionDecision ----------------------
EXTENDS Naturals, FiniteSets

\* One original attempt, two written participants, two coordinator epochs.
\* Atomic log append and truthful participant verification are assumptions.
\* Payloads, cut acquisition, Table visibility and SQL are outside this model.
CONSTANTS CheckFrozen, CheckComplete, CheckFence, CheckPolicy,
          CheckStable, CheckDisclosure
VARIABLES frozen, prepared, decision, first, epoch, owner, allowed,
          available, conflict, knowledge, audit, last
vars == <<frozen, prepared, decision, first, epoch, owner, allowed,
          available, conflict, knowledge, audit, last>>
Participants == {1, 2}
Outcomes == {"none", "committed", "aborted"}
Good == [policy |-> TRUE, fence |-> TRUE, disclosure |-> TRUE]

Init == /\ frozen = FALSE /\ prepared = {}
        /\ decision = "none" /\ first = "none"
        /\ epoch = 1 /\ owner = 1 /\ allowed = TRUE
        /\ available = TRUE /\ conflict = FALSE
        /\ knowledge = "unknown" /\ audit = Good /\ last = "Init"

Freeze == /\ ~frozen /\ allowed /\ owner = epoch
          /\ frozen' = TRUE /\ last' = "Freeze" /\ audit' = Good
          /\ UNCHANGED <<prepared, decision, first, epoch, owner, allowed,
                          available, conflict, knowledge>>
Prepare(p) == /\ frozen /\ decision = "none" /\ p \notin prepared
              /\ prepared' = prepared \cup {p}
              /\ last' = "Prepare" /\ audit' = Good
              /\ UNCHANGED <<frozen, decision, first, epoch, owner, allowed,
                              available, conflict, knowledge>>
Decide(outcome) ==
    /\ (frozen \/ ~CheckFrozen)
    /\ (decision = "none" \/ ~CheckStable)
    /\ (allowed \/ ~CheckPolicy)
    /\ (owner = epoch \/ ~CheckFence)
    /\ (outcome = "aborted" \/
        ((prepared = Participants \/ ~CheckComplete) /\ available /\ ~conflict))
    /\ decision' = outcome
    /\ first' = IF first = "none" THEN outcome ELSE first
    \* A durable append does not imply receipt of its reply.
    /\ knowledge' = "unknown"
    /\ audit' = [policy |-> allowed, fence |-> owner = epoch, disclosure |-> TRUE]
    /\ last' = IF outcome = "committed" THEN "Commit" ELSE "Abort"
    /\ UNCHANGED <<frozen, prepared, epoch, owner, allowed, available, conflict>>
Observe ==
    /\ knowledge' = IF ~allowed /\ CheckDisclosure THEN "denied"
                     ELSE IF decision # "none" THEN decision
                     ELSE IF frozen THEN "preparing" ELSE "unknown"
    /\ audit' = [Good EXCEPT !.disclosure = allowed \/ knowledge' = "denied"]
    /\ last' = "Observe"
    /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner, allowed,
                    available, conflict>>
LoseReply == /\ knowledge' = "unknown" /\ last' = "LoseReply" /\ audit' = Good
             /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                             allowed, available, conflict>>
Recover == /\ owner' = epoch /\ knowledge' = "unknown"
           /\ last' = "Recover" /\ audit' = Good
           /\ UNCHANGED <<frozen, prepared, decision, first, epoch, allowed,
                           available, conflict>>
Fence == /\ epoch = 1 /\ epoch' = 2 /\ last' = "Fence" /\ audit' = Good
         /\ UNCHANGED <<frozen, prepared, decision, first, owner, allowed,
                         available, conflict, knowledge>>
Policy == /\ allowed' = ~allowed /\ last' = "Policy" /\ audit' = Good
          /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                          available, conflict, knowledge>>
Availability == /\ available' = ~available /\ last' = "Availability" /\ audit' = Good
                /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                                allowed, conflict, knowledge>>
Conflict == /\ conflict' = ~conflict /\ last' = "Conflict" /\ audit' = Good
            /\ UNCHANGED <<frozen, prepared, decision, first, epoch, owner,
                            allowed, available, knowledge>>
Next == Freeze \/ (\E p \in Participants : Prepare(p))
        \/ Decide("committed") \/ Decide("aborted") \/ Observe \/ LoseReply
        \/ Recover \/ Fence \/ Policy \/ Availability \/ Conflict
Spec == Init /\ [][Next]_vars

TypeOK == /\ frozen \in BOOLEAN /\ prepared \subseteq Participants
          /\ decision \in Outcomes /\ first \in Outcomes
          /\ epoch \in {1, 2} /\ owner \in {1, 2}
          /\ allowed \in BOOLEAN /\ available \in BOOLEAN /\ conflict \in BOOLEAN
          /\ knowledge \in {"unknown", "denied", "preparing", "committed", "aborted"}
FrozenDecision == decision # "none" => frozen
CompletePreparation == decision = "committed" => prepared = Participants
OriginalDecision == decision = first
CurrentPublication == audit.policy
FencedPublication == audit.fence
CurrentDisclosure == audit.disclosure
HonestObservation == knowledge \in {"committed", "aborted"} => knowledge = decision
=============================================================================

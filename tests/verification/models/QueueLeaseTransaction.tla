----------------------- MODULE QueueLeaseTransaction -----------------------
EXTENDS Naturals, Sequences, FiniteSets

\* Finite design model: two FIFO offsets for k1, one independent offset for k2,
\* two claim generations, time in 0..2, one prepared turn and one durable decision.
\* All fields except resident represent accepted state. Restart drops only the
\* derived cache. This abstracts atomic persistence; it does not model disk I/O.
CONSTANTS CheckTackPartition, CheckKeyFifo, CheckLeaseEpochFence,
          CheckAtomicTurn, CheckSegmentReclaim, CheckLeaseTimeFence,
          CheckPolicyFence, CheckRetainedPayload, CheckDlqDurability
VARIABLE s
vars == <<s>>
Offsets == {1, 2, 3}
Segment == {1, 2}
KeyOf(m) == IF m = 3 THEN "k2" ELSE "k1"

Init == s = [available |-> Offsets, acquired |-> {}, acked |-> {}, dlq |-> {},
             holder |-> "none", epoch |-> 0, originalEpoch |-> 0, retries |-> 0,
             now |-> 0, deadline |-> 0, preparedEpoch |-> 0,
             decision |-> "none", tableUpdated |-> FALSE, outboxPublished |-> FALSE,
             staleAccepted |-> FALSE, expiredCommit |-> FALSE,
             unauthorizedCommit |-> FALSE, allowed |-> TRUE,
             dlqPublished |-> FALSE, historyHeld |-> TRUE,
             segmentReclaimed |-> FALSE, resident |-> TRUE, last |-> "Init"]

ClaimOffset1 == /\ s.resident /\ 1 \in s.available /\ s.epoch = 0 /\ s.now = 0
                /\ s' = [s EXCEPT !.available = @ \ {1}, !.acquired = @ \cup {1},
                           !.holder = "workerA", !.epoch = 1, !.originalEpoch = 1,
                           !.deadline = 1, !.last = "ClaimOffset1"]

ClaimOffset2 == /\ s.resident /\ 2 \in s.available
                /\ ((1 \notin s.available /\ 1 \notin s.acquired) \/ ~CheckKeyFifo)
                /\ s' = [s EXCEPT !.available = @ \ {2}, !.acquired = @ \cup {2},
                           !.last = "ClaimOffset2"]

\* Another key can advance regardless of k1's delay, preparation or lease.
ClaimOffset3 == /\ s.resident /\ 3 \in s.available
                /\ s' = [s EXCEPT !.available = @ \ {3}, !.acquired = @ \cup {3},
                           !.last = "ClaimOffset3"]
AckOther(m) == /\ s.resident /\ m \in {2, 3} /\ m \in s.acquired
               /\ s' = [s EXCEPT !.acquired = @ \ {m}, !.acked = @ \cup {m},
                          !.last = IF m = 2 THEN "AckOffset2" ELSE "AckOffset3"]

Tick == /\ s.now < 2
        /\ s' = [s EXCEPT !.now = @ + 1, !.last = "Tick"]

\* Expiry is independent of cleanup and reassignment. Time must be checked at
\* commit even while an expired record remains acquired with the old epoch.
ExpireLease1 == /\ s.resident /\ 1 \in s.acquired /\ s.now >= s.deadline
                /\ s.retries = 0
                /\ s' = [s EXCEPT !.acquired = @ \ {1}, !.available = @ \cup {1},
                           !.holder = "none", !.retries = 1, !.last = "ExpireLease1"]
ReclaimOffset1 == /\ s.resident /\ 1 \in s.available /\ s.epoch = 1 /\ s.now < 2
                  /\ s' = [s EXCEPT !.available = @ \ {1}, !.acquired = @ \cup {1},
                             !.holder = "workerB", !.epoch = 2, !.deadline = 2,
                             !.last = "ReclaimOffset1"]

PublishDlq == /\ s.resident /\ 1 \in s.acquired /\ s.retries = 1
              /\ s.now >= s.deadline /\ ~s.dlqPublished
              /\ s' = [s EXCEPT !.dlqPublished = TRUE, !.last = "PublishDlq"]
ArchiveDlq == /\ s.resident /\ 1 \in s.acquired /\ s.retries = 1
              /\ s.now >= s.deadline /\ (s.dlqPublished \/ ~CheckDlqDurability)
              /\ s' = [s EXCEPT !.acquired = @ \ {1}, !.dlq = @ \cup {1},
                         !.holder = "none", !.last = "ArchiveDlq"]

PrepareTurn == /\ s.resident /\ 1 \in s.acquired /\ s.preparedEpoch = 0
               /\ s.now < s.deadline /\ s.allowed
               /\ s' = [s EXCEPT !.preparedEpoch = s.epoch, !.last = "PrepareTurn"]
Revoke == /\ s.allowed
          /\ s' = [s EXCEPT !.allowed = FALSE, !.last = "Revoke"]
CommitThreePrimitiveTurn ==
    /\ s.resident /\ 1 \in s.acquired /\ s.preparedEpoch > 0 /\ s.decision = "none"
    /\ (s.preparedEpoch = s.epoch \/ ~CheckLeaseEpochFence)
    /\ (s.now < s.deadline \/ ~CheckLeaseTimeFence)
    /\ (s.allowed \/ ~CheckPolicyFence)
    /\ s' = [s EXCEPT !.acquired = @ \ {1}, !.acked = @ \cup {1},
               !.tableUpdated = TRUE, !.outboxPublished = CheckAtomicTurn,
               !.decision = "committed", !.holder = "none",
               !.expiredCommit = (s.now >= s.deadline),
               !.unauthorizedCommit = ~s.allowed,
               !.staleAccepted = (s.preparedEpoch # s.epoch),
               !.last = "CommitThreePrimitiveTurn"]
AbortTurn == /\ s.resident /\ s.preparedEpoch > 0 /\ s.decision = "none"
             /\ s' = [s EXCEPT !.decision = "aborted", !.last = "AbortTurn"]

\* Original accepted result recovery is allowed after time/policy changes;
\* disclosure authorization is outside this abstract decision-state model.
RecoverDecision == /\ s.resident /\ s.decision # "none"
                   /\ s' = [s EXCEPT !.last = "RecoverDecision"]
Restart == /\ s.resident
           /\ s' = [s EXCEPT !.resident = FALSE, !.last = "Restart"]
LoadAccepted == /\ ~s.resident
                /\ s' = [s EXCEPT !.resident = TRUE, !.last = "LoadAccepted"]

StaleWorkerAck == /\ s.epoch > s.originalEpoch /\ s.originalEpoch > 0
                  /\ ~s.staleAccepted /\ ~CheckLeaseEpochFence
                  /\ s' = [s EXCEPT !.staleAccepted = TRUE, !.last = "StaleWorkerAck"]
CorruptTackBitmap == /\ 1 \in s.acquired /\ ~CheckTackPartition
                     /\ s' = [s EXCEPT !.acked = @ \cup {1}, !.last = "CorruptTackBitmap"]

ReleaseHistory == /\ Segment \subseteq (s.acked \cup s.dlq) /\ s.historyHeld
                  /\ s' = [s EXCEPT !.historyHeld = FALSE, !.last = "ReleaseHistory"]
ReclaimSegment == /\ ~s.segmentReclaimed
                  /\ ((Segment \subseteq (s.acked \cup s.dlq)) \/ ~CheckSegmentReclaim)
                  /\ (~s.historyHeld \/ ~CheckRetainedPayload \/ ~CheckSegmentReclaim)
                  /\ s' = [s EXCEPT !.segmentReclaimed = TRUE, !.last = "ReclaimSegment"]

Next == ClaimOffset1 \/ ClaimOffset2 \/ ClaimOffset3 \/ (\E m \in {2, 3}: AckOther(m))
        \/ Tick \/ ExpireLease1 \/ ReclaimOffset1 \/ PublishDlq \/ ArchiveDlq
        \/ PrepareTurn \/ Revoke \/ CommitThreePrimitiveTurn \/ AbortTurn
        \/ RecoverDecision \/ Restart \/ LoadAccepted \/ StaleWorkerAck
        \/ CorruptTackBitmap \/ ReleaseHistory \/ ReclaimSegment
Spec == Init /\ [][Next]_vars

TypeOK == /\ s.available \subseteq Offsets /\ s.acquired \subseteq Offsets
          /\ s.acked \subseteq Offsets /\ s.dlq \subseteq Offsets
          /\ s.holder \in {"none", "workerA", "workerB"}
          /\ s.epoch \in 0..2 /\ s.originalEpoch \in 0..1 /\ s.preparedEpoch \in 0..2
          /\ s.now \in 0..2 /\ s.deadline \in 0..2 /\ s.retries \in 0..1
          /\ s.decision \in {"none", "committed", "aborted"}
          /\ \A b \in {s.tableUpdated, s.outboxPublished, s.staleAccepted,
                        s.expiredCommit, s.unauthorizedCommit, s.allowed,
                        s.dlqPublished, s.historyHeld, s.segmentReclaimed,
                        s.resident}: b \in BOOLEAN
TackStatesMutuallyExclusive ==
    /\ s.available \cap s.acquired = {} /\ s.available \cap s.acked = {}
    /\ s.available \cap s.dlq = {} /\ s.acquired \cap s.acked = {}
    /\ s.acquired \cap s.dlq = {} /\ s.acked \cap s.dlq = {}
    /\ s.available \cup s.acquired \cup s.acked \cup s.dlq = Offsets
KeyFifoMutualExclusion ==
    /\ \A k \in {"k1", "k2"}: Cardinality({m \in s.acquired: KeyOf(m) = k}) <= 1
    /\ (2 \in s.acquired => 1 \notin s.available)
StaleEpochRejected == ~s.staleAccepted
ExpiredLeaseRejected == ~s.expiredCommit
RevokedCommitRejected == ~s.unauthorizedCommit
AtomicThreePrimitiveTurn ==
    /\ (s.tableUpdated <=> s.outboxPublished)
    /\ (s.tableUpdated <=> s.decision = "committed")
    /\ (s.tableUpdated => 1 \in s.acked)
SegmentReclaimedOnlyWhenTerminal ==
    s.segmentReclaimed => Segment \subseteq (s.acked \cup s.dlq)
SegmentReclaimedOnlyWhenUnpinned == s.segmentReclaimed => ~s.historyHeld
DlqRetainsPayload == (1 \in s.dlq) => s.dlqPublished
=============================================================================

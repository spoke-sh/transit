----------------------- MODULE QueueLeaseTransaction -----------------------
EXTENDS Naturals, Sequences, FiniteSets

\* Forward-design formal specification of Milestone 6 QueuePartition (.tack
\* Roaring-bitmap state sets, key_fifo entity-key affinity, timing-wheel lease
\* expiry with _lease_epoch fencing) composed with Milestone 5 multi-primitive
\* atomic turn commit (CLAIM -> TABLE UPDATE -> STREAM/QUEUE PRODUCE -> ACK).
CONSTANTS CheckTackPartition, CheckKeyFifo, CheckLeaseEpochFence,
          CheckAtomicTurn, CheckSegmentReclaim

VARIABLES available, acquired, acked, dlq,
          holder1, epoch1, currentEpoch1, retries1,
          tableUpdated, outboxPublished, staleAccepted,
          segmentReclaimed, last

vars == <<available, acquired, acked, dlq,
          holder1, epoch1, currentEpoch1, retries1,
          tableUpdated, outboxPublished, staleAccepted,
          segmentReclaimed, last>>

\* Two offsets {1, 2} sharing entity key k1 in segment 1.
Offsets == {1, 2}
KeyOf(m) == "k1"

Init == /\ available = {1, 2}
        /\ acquired = {}
        /\ acked = {}
        /\ dlq = {}
        /\ holder1 = "none"
        /\ epoch1 = 0
        /\ currentEpoch1 = 0
        /\ retries1 = 0
        /\ tableUpdated = FALSE
        /\ outboxPublished = FALSE
        /\ staleAccepted = FALSE
        /\ segmentReclaimed = FALSE
        /\ last = "Init"

\* Claim offset 1 with a fenced lease.
ClaimOffset1 ==
    /\ 1 \in available /\ holder1 = "none"
    /\ available' = available \ {1}
    /\ acquired' = acquired \cup {1}
    /\ holder1' = "workerA"
    /\ currentEpoch1' = currentEpoch1 + 1
    /\ epoch1' = currentEpoch1 + 1
    /\ last' = "ClaimOffset1"
    /\ UNCHANGED <<acked, dlq, retries1, tableUpdated, outboxPublished,
                    staleAccepted, segmentReclaimed>>

\* Claim offset 2 (which shares entity key "k1" with offset 1).
\* Under key_fifo, offset 2 cannot be acquired while offset 1 is acquired,
\* nor while offset 1 is still available ahead of offset 2.
ClaimOffset2 ==
    /\ 2 \in available
    /\ ((1 \notin available /\ 1 \notin acquired) \/ ~CheckKeyFifo)
    /\ available' = available \ {2}
    /\ acquired' = acquired \cup {2}
    /\ last' = "ClaimOffset2"
    /\ UNCHANGED <<acked, dlq, holder1, epoch1, currentEpoch1, retries1,
                    tableUpdated, outboxPublished, staleAccepted,
                    segmentReclaimed>>

\* Timing wheel expires offset 1's lease and returns it to available (or DLQ).
ExpireLease1 ==
    /\ 1 \in acquired /\ holder1 = "workerA"
    /\ acquired' = acquired \ {1}
    /\ IF retries1 < 1
       THEN /\ available' = available \cup {1}
            /\ dlq' = dlq
            /\ retries1' = retries1 + 1
       ELSE /\ available' = available
            /\ dlq' = dlq \cup {1}
            /\ retries1' = retries1
    /\ holder1' = "none"
    /\ last' = "ExpireLease1"
    /\ UNCHANGED <<acked, epoch1, currentEpoch1, tableUpdated, outboxPublished,
                    staleAccepted, segmentReclaimed>>

\* Worker B claims offset 1 after lease expiry, advancing currentEpoch1.
ReclaimOffset1 ==
    /\ 1 \in available /\ holder1 = "none" /\ currentEpoch1 = 1
    /\ available' = available \ {1}
    /\ acquired' = acquired \cup {1}
    /\ holder1' = "workerB"
    /\ currentEpoch1' = currentEpoch1 + 1
    /\ last' = "ReclaimOffset1"
    /\ UNCHANGED <<acked, dlq, epoch1, retries1, tableUpdated, outboxPublished,
                    staleAccepted, segmentReclaimed>>

\* Stale worker A attempts to ACK offset 1 using its expired epoch1 < currentEpoch1.
StaleWorkerAck ==
    /\ currentEpoch1 > epoch1 /\ epoch1 > 0 /\ ~staleAccepted
    /\ ~CheckLeaseEpochFence
    /\ staleAccepted' = TRUE
    /\ last' = "StaleWorkerAck"
    /\ UNCHANGED <<available, acquired, acked, dlq, holder1, epoch1,
                    currentEpoch1, retries1, tableUpdated, outboxPublished,
                    segmentReclaimed>>

\* Illegal .tack state transition placing offset 1 into both acquired and acked.
CorruptTackBitmap ==
    /\ 1 \in acquired /\ ~CheckTackPartition
    /\ acked' = acked \cup {1}
    /\ last' = "CorruptTackBitmap"
    /\ UNCHANGED <<available, acquired, dlq, holder1, epoch1, currentEpoch1,
                    retries1, tableUpdated, outboxPublished, staleAccepted,
                    segmentReclaimed>>

\* Atomic 3-primitive turn commit (CLAIM offset 1 -> TABLE update -> outbox publish -> ACK offset 1).
CommitThreePrimitiveTurn ==
    /\ 1 \in acquired /\ ~tableUpdated /\ ~outboxPublished
    /\ (holder1 = "workerB" \/ (holder1 = "workerA" /\ currentEpoch1 = epoch1))
    /\ acquired' = acquired \ {1}
    /\ acked' = acked \cup {1}
    /\ tableUpdated' = TRUE
    /\ outboxPublished' = IF CheckAtomicTurn THEN TRUE ELSE FALSE
    /\ holder1' = "none"
    /\ last' = "CommitThreePrimitiveTurn"
    /\ UNCHANGED <<available, dlq, epoch1, currentEpoch1, retries1,
                    staleAccepted, segmentReclaimed>>

\* ACK offset 2 once acquired.
AckOffset2 ==
    /\ 2 \in acquired
    /\ acquired' = acquired \ {2}
    /\ acked' = acked \cup {2}
    /\ last' = "AckOffset2"
    /\ UNCHANGED <<available, dlq, holder1, epoch1, currentEpoch1, retries1,
                    tableUpdated, outboxPublished, staleAccepted,
                    segmentReclaimed>>

\* Reclaim segment 1 once all offsets {1, 2} are in terminal states (acked \cup dlq).
ReclaimSegment ==
    /\ ~segmentReclaimed
    /\ ((Offsets \subseteq (acked \cup dlq)) \/ ~CheckSegmentReclaim)
    /\ segmentReclaimed' = TRUE
    /\ last' = "ReclaimSegment"
    /\ UNCHANGED <<available, acquired, acked, dlq, holder1, epoch1,
                    currentEpoch1, retries1, tableUpdated, outboxPublished,
                    staleAccepted>>

Next == ClaimOffset1 \/ ClaimOffset2 \/ ExpireLease1 \/ ReclaimOffset1
        \/ StaleWorkerAck \/ CorruptTackBitmap \/ CommitThreePrimitiveTurn
        \/ AckOffset2 \/ ReclaimSegment

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ available \subseteq Offsets
    /\ acquired \subseteq Offsets
    /\ acked \subseteq Offsets
    /\ dlq \subseteq Offsets
    /\ holder1 \in {"none", "workerA", "workerB"}
    /\ epoch1 \in 0..2 /\ currentEpoch1 \in 0..2 /\ retries1 \in 0..1
    /\ tableUpdated \in BOOLEAN /\ outboxPublished \in BOOLEAN
    /\ staleAccepted \in BOOLEAN /\ segmentReclaimed \in BOOLEAN

\* Every offset belongs to at most one .tack Roaring bitmap state.
TackStatesMutuallyExclusive ==
    /\ available \cap acquired = {}
    /\ available \cap acked = {}
    /\ available \cap dlq = {}
    /\ acquired \cap acked = {}
    /\ acquired \cap dlq = {}
    /\ acked \cap dlq = {}

\* Under key_fifo, at most one offset for entity key "k1" is acquired at a time,
\* and offset 2 is never acquired while offset 1 is still available.
KeyFifoMutualExclusion ==
    /\ Cardinality(acquired) <= 1
    /\ (2 \in acquired => 1 \notin available)

\* A worker with a stale _lease_epoch can never ACK, NACK, or commit its turn.
StaleEpochRejected == ~staleAccepted

\* A 3-primitive turn commits input ACK, table mutation, and outbox publication atomically.
AtomicThreePrimitiveTurn ==
    (tableUpdated <=> outboxPublished) /\ (tableUpdated => 1 \in acked)

\* Physical .tseg segment reclamation requires every offset in the segment to be terminal.
SegmentReclaimedOnlyWhenTerminal ==
    segmentReclaimed => Offsets \subseteq (acked \cup dlq)
=============================================================================

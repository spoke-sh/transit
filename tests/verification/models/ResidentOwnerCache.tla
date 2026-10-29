------------------------- MODULE ResidentOwnerCache -------------------------
EXTENDS Naturals, Sequences, FiniteSets

\* Formal model of LocalTableService resident owner caching, incremental
\* recoverSince replay, transaction owner isolation (commit 02159344e), and
\* ReadCache snapshot pin eviction/reconciliation (SQL-READ-01, SQL-READ-02).
CONSTANTS CheckRecoverSincePrefix, CheckUncertainAppendEviction,
          CheckTxOwnerIsolation, CheckEvictBeforeRelease,
          CheckConflictAbsenceProof

VARIABLES walLsn, residentLsn, residentChainValid, residentPoisoned,
          residentSlotOwner, txExecuted,
          cacheAdvertised, cacheUsers, cacheState, pinReleasedOnOwner,
          pinAcceptedOnOwner, orphanedPinLeaked, last

vars == <<walLsn, residentLsn, residentChainValid, residentPoisoned,
          residentSlotOwner, txExecuted,
          cacheAdvertised, cacheUsers, cacheState, pinReleasedOnOwner,
          pinAcceptedOnOwner, orphanedPinLeaked, last>>

Init == /\ walLsn = 2
        /\ residentLsn = 2
        /\ residentChainValid = TRUE
        /\ residentPoisoned = FALSE
        /\ residentSlotOwner = "public_warm"
        /\ txExecuted = FALSE
        /\ cacheAdvertised = TRUE
        /\ cacheUsers = 0
        /\ cacheState = "active"
        /\ pinReleasedOnOwner = FALSE
        /\ pinAcceptedOnOwner = FALSE
        /\ orphanedPinLeaked = FALSE
        /\ last = "Init"

\* Public write advances WAL; incremental recoverSince brings residentLsn up to walLsn.
AdvanceWalAndRecoverSince ==
    /\ walLsn = 2 /\ residentLsn = 2 /\ ~residentPoisoned
    /\ walLsn' = 3
    /\ residentLsn' = 3
    /\ last' = "AdvanceWalAndRecoverSince"
    /\ UNCHANGED <<residentChainValid, residentPoisoned, residentSlotOwner,
                    txExecuted, cacheAdvertised, cacheUsers, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* Incremental WAL replay from a corrupted prior chain hint must fail closed.
RecoverSinceStaleHint ==
    /\ walLsn = 2 /\ residentChainValid /\ last # "RecoverSinceStaleHint"
    /\ IF CheckRecoverSincePrefix
       THEN /\ residentLsn' = walLsn
            /\ residentChainValid' = TRUE
       ELSE /\ residentLsn' = 1
            /\ residentChainValid' = FALSE
    /\ last' = "RecoverSinceStaleHint"
    /\ UNCHANGED <<walLsn, residentPoisoned, residentSlotOwner, txExecuted,
                    cacheAdvertised, cacheUsers, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* An uncertain WAL append (lost reply) poisons the in-memory owner until full
\* recovery runs; the resident hint must be evicted immediately.
UncertainAppend ==
    /\ ~residentPoisoned /\ walLsn = 2
    /\ walLsn' = 3
    /\ IF CheckUncertainAppendEviction
       THEN /\ residentLsn' = 3
            /\ residentPoisoned' = FALSE
       ELSE /\ residentLsn' = 2
            /\ residentPoisoned' = TRUE
    /\ last' = "UncertainAppend"
    /\ UNCHANGED <<residentChainValid, residentSlotOwner, txExecuted,
                    cacheAdvertised, cacheUsers, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* Executing a transaction statement opens a temporary table owner on the
\* transaction's memory budget and must never overwrite the resident slot.
ExecuteTxStatement ==
    /\ ~txExecuted
    /\ txExecuted' = TRUE
    /\ residentSlotOwner' = IF CheckTxOwnerIsolation THEN "public_warm" ELSE "tx_private"
    /\ last' = "ExecuteTxStatement"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    cacheAdvertised, cacheUsers, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* A warm SELECT borrows the active ReadCache entry while users <= 1.
BorrowWarmCache ==
    /\ cacheAdvertised /\ cacheState = "active" /\ cacheUsers < 2
    /\ cacheUsers' = cacheUsers + 1
    /\ last' = "BorrowWarmCache"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    residentSlotOwner, txExecuted, cacheAdvertised, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* Closing a SELECT releases only the in-memory borrow; the durable pin stays warm.
CloseWarmBorrow ==
    /\ cacheUsers > 0
    /\ cacheUsers' = cacheUsers - 1
    /\ last' = "CloseWarmBorrow"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    residentSlotOwner, txExecuted, cacheAdvertised, cacheState,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* Evicting an unborrowed ReadCache entry must stop advertising the warm entry
\* before releasing the durable pin on the table owner.
EvictLoseReleaseReply ==
    /\ cacheState = "active" /\ cacheUsers = 0 /\ ~pinReleasedOnOwner
    /\ cacheState' = "closing"
    /\ pinReleasedOnOwner' = TRUE
    /\ cacheAdvertised' = IF CheckEvictBeforeRelease THEN FALSE ELSE TRUE
    /\ last' = "EvictLoseReleaseReply"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    residentSlotOwner, txExecuted, cacheUsers,
                    pinAcceptedOnOwner, orphanedPinLeaked>>

\* Background tick reconciles a closing slot after an interrupted release.
ReconcileCacheTick ==
    /\ cacheState = "closing" /\ pinReleasedOnOwner
    /\ cacheState' = "idle"
    /\ cacheAdvertised' = FALSE
    /\ last' = "ReconcileCacheTick"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    residentSlotOwner, txExecuted, cacheUsers,
                    pinReleasedOnOwner, pinAcceptedOnOwner, orphanedPinLeaked>>

\* A Conflict during ReadCache pin acquisition may only retry at a newer cut if
\* pin_status proves the original pin is absent at a strictly later frontier.
PinConflictAmbiguous ==
    /\ ~pinAcceptedOnOwner /\ ~orphanedPinLeaked
    /\ pinAcceptedOnOwner' = TRUE
    /\ orphanedPinLeaked' = IF CheckConflictAbsenceProof THEN FALSE ELSE TRUE
    /\ last' = "PinConflictAmbiguous"
    /\ UNCHANGED <<walLsn, residentLsn, residentChainValid, residentPoisoned,
                    residentSlotOwner, txExecuted, cacheAdvertised, cacheUsers,
                    cacheState, pinReleasedOnOwner>>

Next == AdvanceWalAndRecoverSince \/ RecoverSinceStaleHint \/ UncertainAppend
        \/ ExecuteTxStatement \/ BorrowWarmCache \/ CloseWarmBorrow
        \/ EvictLoseReleaseReply \/ ReconcileCacheTick \/ PinConflictAmbiguous

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ walLsn \in {2, 3}
    /\ residentLsn \in {1, 2, 3}
    /\ residentChainValid \in BOOLEAN
    /\ residentPoisoned \in BOOLEAN
    /\ residentSlotOwner \in {"public_warm", "tx_private"}
    /\ txExecuted \in BOOLEAN
    /\ cacheAdvertised \in BOOLEAN
    /\ cacheUsers \in 0..2
    /\ cacheState \in {"active", "closing", "idle"}
    /\ pinReleasedOnOwner \in BOOLEAN
    /\ pinAcceptedOnOwner \in BOOLEAN
    /\ orphanedPinLeaked \in BOOLEAN

\* Incremental recoverSince never trusts an invalid chain prefix.
ResidentOwnerMatchesColdReplay ==
    residentChainValid /\ ( ~residentPoisoned => residentLsn = walLsn )

\* An uncertain append never leaves a poisoned resident owner active.
NoPoisonedResidentAfterUncertainAppend == ~residentPoisoned

\* Transaction statement execution never contaminates the resident CachedTable slot.
TransactionDoesNotMutateResidentSlot == residentSlotOwner = "public_warm"

\* A warm cache entry is never advertised after its pin release has begun.
NoDanglingWarmCachePin == pinReleasedOnOwner => ~cacheAdvertised

\* Ambiguous pin Conflict never leaks an accepted original snapshot pin.
RetryPinOnlyOnVerifiedAbsence == ~orphanedPinLeaked
=============================================================================

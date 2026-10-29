---------------------- MODULE TransactionWorkspace ----------------------
EXTENDS Naturals, Sequences, FiniteSets

\* Finite catalog-owned transaction admission, common-cut epoch fence,
\* two-phase private statement workspace, operation-claim namespace exclusion,
\* and per-account/per-workspace quota model (TRANSACTION-02, 03, 05, 06).
CONSTANTS CheckCoordinator, CheckAccountQuota, CheckCutEpoch,
          CheckCutRequired, CheckSequence, CheckOpClaim,
          CheckWorkspaceQuota, CheckDisclosure

VARIABLES begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
          cutAcquired, cutEpochOk, pendingSeq, pendingOp, lastSeq,
          executedSeq, privateRows, publicRows, chargedBytes,
          txOps, autoOps, disclosed, auditDisclosure, last

vars == <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
          cutAcquired, cutEpochOk, pendingSeq, pendingOp, lastSeq,
          executedSeq, privateRows, publicRows, chargedBytes,
          txOps, autoOps, disclosed, auditDisclosure, last>>

MaxWorkspaceBytes == 3

Init == /\ begun = <<FALSE, FALSE>>
        /\ coord = <<0, 0>>
        /\ nextPart = 2
        /\ pinEpoch = 0
        /\ policyEpoch = 1
        /\ allowed = TRUE
        /\ cutAcquired = FALSE
        /\ cutEpochOk = TRUE
        /\ pendingSeq = 0
        /\ pendingOp = 0
        /\ lastSeq = 0
        /\ executedSeq = {}
        /\ privateRows = 0
        /\ publicRows = 0
        /\ chargedBytes = 0
        /\ txOps = {}
        /\ autoOps = {}
        /\ disclosed = "none"
        /\ auditDisclosure = TRUE
        /\ last = "Init"

Begin1 ==
    /\ ~begun[1] /\ allowed
    /\ begun' = [begun EXCEPT ![1] = TRUE]
    /\ coord' = [coord EXCEPT ![1] = IF CheckCoordinator THEN nextPart ELSE 1]
    /\ nextPart' = IF nextPart < 4 THEN nextPart + 1 ELSE nextPart
    /\ auditDisclosure' = TRUE /\ last' = "Begin1"
    /\ UNCHANGED <<pinEpoch, policyEpoch, allowed, cutAcquired, cutEpochOk,
                    pendingSeq, pendingOp, lastSeq, executedSeq, privateRows,
                    publicRows, chargedBytes, txOps, autoOps, disclosed>>

Begin2 ==
    /\ begun[1] /\ ~begun[2] /\ allowed
    /\ ~CheckAccountQuota
    /\ begun' = [begun EXCEPT ![2] = TRUE]
    /\ coord' = [coord EXCEPT ![2] = nextPart]
    /\ nextPart' = IF nextPart < 4 THEN nextPart + 1 ELSE nextPart
    /\ auditDisclosure' = TRUE /\ last' = "Begin2"
    /\ UNCHANGED <<pinEpoch, policyEpoch, allowed, cutAcquired, cutEpochOk,
                    pendingSeq, pendingOp, lastSeq, executedSeq, privateRows,
                    publicRows, chargedBytes, txOps, autoOps, disclosed>>

PinSelected ==
    /\ begun[1] /\ ~cutAcquired /\ pinEpoch = 0 /\ allowed
    /\ pinEpoch' = policyEpoch
    /\ auditDisclosure' = TRUE /\ last' = "PinSelected"
    /\ UNCHANGED <<begun, coord, nextPart, policyEpoch, allowed, cutAcquired,
                    cutEpochOk, pendingSeq, pendingOp, lastSeq, executedSeq,
                    privateRows, publicRows, chargedBytes, txOps, autoOps, disclosed>>

AdvanceEpoch ==
    /\ policyEpoch = 1
    /\ policyEpoch' = 2
    /\ auditDisclosure' = TRUE /\ last' = "AdvanceEpoch"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, allowed, cutAcquired,
                    cutEpochOk, pendingSeq, pendingOp, lastSeq, executedSeq,
                    privateRows, publicRows, chargedBytes, txOps, autoOps, disclosed>>

AcquireCut ==
    /\ begun[1] /\ ~cutAcquired /\ pinEpoch # 0 /\ allowed
    /\ (pinEpoch = policyEpoch \/ ~CheckCutEpoch)
    /\ cutAcquired' = TRUE
    /\ cutEpochOk' = (pinEpoch = policyEpoch)
    /\ auditDisclosure' = TRUE /\ last' = "AcquireCut"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    pendingSeq, pendingOp, lastSeq, executedSeq, privateRows,
                    publicRows, chargedBytes, txOps, autoOps, disclosed>>

AdmitStmt1 ==
    /\ begun[1] /\ allowed /\ pendingSeq = 0 /\ lastSeq = 0
    /\ (cutAcquired \/ ~CheckCutRequired)
    /\ (1 \notin autoOps \/ ~CheckOpClaim)
    /\ chargedBytes < MaxWorkspaceBytes
    /\ pendingSeq' = 1 /\ pendingOp' = 1 /\ lastSeq' = 1
    /\ txOps' = txOps \cup {1}
    /\ chargedBytes' = chargedBytes + 1
    /\ auditDisclosure' = TRUE /\ last' = "AdmitStmt1"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, executedSeq, privateRows,
                    publicRows, autoOps, disclosed>>

AdmitStmt2 ==
    /\ begun[1] /\ allowed /\ cutAcquired
    /\ 2 \notin txOps /\ 2 \notin autoOps
    /\ ((pendingSeq = 0 /\ lastSeq = 1 /\ 1 \in executedSeq) \/ ~CheckSequence)
    /\ chargedBytes < MaxWorkspaceBytes
    /\ pendingSeq' = 2 /\ pendingOp' = 2 /\ lastSeq' = 2
    /\ txOps' = txOps \cup {2}
    /\ chargedBytes' = chargedBytes + 1
    /\ auditDisclosure' = TRUE /\ last' = "AdmitStmt2"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, executedSeq, privateRows,
                    publicRows, autoOps, disclosed>>

ExecuteStmt ==
    /\ begun[1] /\ allowed /\ pendingSeq # 0
    /\ (chargedBytes + 1 <= MaxWorkspaceBytes \/ ~CheckWorkspaceQuota)
    /\ executedSeq' = executedSeq \cup {pendingSeq}
    /\ privateRows' = IF privateRows < 2 THEN privateRows + 1 ELSE 2
    /\ chargedBytes' = IF chargedBytes < 4 THEN chargedBytes + 1 ELSE 4
    /\ pendingSeq' = 0 /\ pendingOp' = 0
    /\ auditDisclosure' = TRUE /\ last' = "ExecuteStmt"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, lastSeq, publicRows, txOps,
                    autoOps, disclosed>>

Autocommit1 ==
    /\ allowed /\ 1 \notin autoOps
    /\ (1 \notin txOps \/ ~CheckOpClaim)
    /\ autoOps' = autoOps \cup {1}
    /\ publicRows' = 1
    /\ auditDisclosure' = TRUE /\ last' = "Autocommit1"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, pendingSeq, pendingOp, lastSeq,
                    executedSeq, privateRows, chargedBytes, txOps, disclosed>>

InspectWorkspace ==
    /\ begun[1] /\ cutAcquired
    /\ disclosed' = IF ~allowed /\ CheckDisclosure THEN "denied" ELSE "ok"
    /\ auditDisclosure' = (allowed \/ disclosed' = "denied")
    /\ last' = "InspectWorkspace"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, pendingSeq, pendingOp, lastSeq,
                    executedSeq, privateRows, publicRows, chargedBytes,
                    txOps, autoOps>>

TogglePolicy ==
    /\ allowed' = ~allowed
    /\ auditDisclosure' = TRUE /\ last' = "TogglePolicy"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, cutAcquired,
                    cutEpochOk, pendingSeq, pendingOp, lastSeq, executedSeq,
                    privateRows, publicRows, chargedBytes, txOps, autoOps, disclosed>>

CrashRecover ==
    /\ disclosed' = "none" /\ auditDisclosure' = TRUE /\ last' = "CrashRecover"
    /\ UNCHANGED <<begun, coord, nextPart, pinEpoch, policyEpoch, allowed,
                    cutAcquired, cutEpochOk, pendingSeq, pendingOp, lastSeq,
                    executedSeq, privateRows, publicRows, chargedBytes,
                    txOps, autoOps>>

Next == Begin1 \/ Begin2 \/ PinSelected \/ AdvanceEpoch \/ AcquireCut
        \/ AdmitStmt1 \/ AdmitStmt2 \/ ExecuteStmt \/ Autocommit1
        \/ InspectWorkspace \/ TogglePolicy \/ CrashRecover

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ begun \in [1..2 -> BOOLEAN]
    /\ coord \in [1..2 -> 0..3]
    /\ nextPart \in 2..4
    /\ pinEpoch \in 0..2 /\ policyEpoch \in 1..2
    /\ allowed \in BOOLEAN /\ cutAcquired \in BOOLEAN /\ cutEpochOk \in BOOLEAN
    /\ pendingSeq \in 0..2 /\ pendingOp \in 0..2 /\ lastSeq \in 0..2
    /\ executedSeq \subseteq {1, 2}
    /\ privateRows \in 0..2 /\ publicRows \in 0..1 /\ chargedBytes \in 0..4
    /\ txOps \subseteq {1, 2} /\ autoOps \subseteq {1}
    /\ disclosed \in {"none", "ok", "denied"} /\ auditDisclosure \in BOOLEAN

ExclusiveCoordinator == \A i \in 1..2 : begun[i] => coord[i] > 1
AccountQuotaBounded == ~(begun[1] /\ begun[2])
SingleEpochCut == cutAcquired => cutEpochOk
CutPrecedesStatement == (lastSeq > 0 \/ pendingSeq > 0) => cutAcquired
OrderedTwoPhaseStatements == (2 \in executedSeq \/ pendingSeq = 2) => 1 \in executedSeq
DisjointOperationClaims == txOps \cap autoOps = {}
WorkspaceBytesBounded == chargedBytes <= MaxWorkspaceBytes
AuthorizedWorkspaceDisclosure == auditDisclosure
PublicIsolation == (publicRows = 0 <=> autoOps = {})
=============================================================================

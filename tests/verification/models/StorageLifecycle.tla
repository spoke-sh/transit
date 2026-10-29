-------------------------- MODULE StorageLifecycle --------------------------
EXTENDS Naturals, Sequences, FiniteSets

\* Unified Table storage maintenance and two-pass physical GC model covering:
\* - Fixed-cut WAL-to-.tseg flush and unchanged logical changed_lsn (STORAGE-04)
\* - Archive coverage before physical WAL trim (STORAGE-04)
\* - Fixed-boundary selective segment compaction (STORAGE-05)
\* - Recovery checkpoint ordering before history_floor expiry (STORAGE-06)
\* - Two-pass epoch-fenced GC with clock-uncertainty grace window and root
\*   reachability across live, snapshot, pending, and transaction-workspace
\*   objects (STORAGE-06, TRANSACTION-04).
CONSTANTS CheckTrimArchive, CheckCompactionBoundary, CheckCheckpointOrder,
          CheckPinProtection, CheckWorkspaceRoots, CheckGraceWindow

VARIABLES nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
          archiveThrough, walTrimmed, checkpointLsn, historyFloor,
          compactionBefore, compactedSegs,
          pinnedWalLsn, pinnedSeg, workspaceSeg,
          gcPhase, graceElapsed, storedSegs, storedArchives, last

vars == <<nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
          archiveThrough, walTrimmed, checkpointLsn, historyFloor,
          compactionBefore, compactedSegs,
          pinnedWalLsn, pinnedSeg, workspaceSeg,
          gcPhase, graceElapsed, storedSegs, storedArchives, last>>

Init == /\ nextLsn = 2
        /\ changedLsn = 2
        /\ nextSeg = 1
        /\ liveSegs = {}
        /\ walRowFlushed = FALSE
        /\ archiveThrough = 0
        /\ walTrimmed = 0
        /\ checkpointLsn = 0
        /\ historyFloor = 0
        /\ compactionBefore = 0
        /\ compactedSegs = {}
        /\ pinnedWalLsn = 1
        /\ pinnedSeg = 0
        /\ workspaceSeg = 0
        /\ gcPhase = "idle"
        /\ graceElapsed = FALSE
        /\ storedSegs = {}
        /\ storedArchives = {}
        /\ last = "Init"

FlushWal ==
    /\ ~walRowFlushed /\ nextSeg = 1
    /\ walRowFlushed' = TRUE
    /\ nextSeg' = 2
    /\ liveSegs' = {1}
    /\ storedSegs' = storedSegs \cup {1}
    /\ nextLsn' = nextLsn + 1
    /\ last' = "FlushWal"
    /\ UNCHANGED <<changedLsn, archiveThrough, walTrimmed, checkpointLsn,
                    historyFloor, compactionBefore, compactedSegs,
                    pinnedWalLsn, pinnedSeg, workspaceSeg, gcPhase,
                    graceElapsed, storedArchives>>

PinSegment ==
    /\ 1 \in liveSegs /\ pinnedSeg = 0 /\ pinnedWalLsn = 1
    /\ pinnedSeg' = 1
    /\ nextLsn' = nextLsn + 1
    /\ last' = "PinSegment"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, pinnedWalLsn,
                    workspaceSeg, gcPhase, graceElapsed, storedSegs,
                    storedArchives>>

StageWorkspaceSegment ==
    /\ workspaceSeg = 0 /\ nextSeg = 2
    /\ workspaceSeg' = 2
    /\ nextSeg' = 3
    /\ storedSegs' = storedSegs \cup {2}
    /\ last' = "StageWorkspaceSegment"
    /\ UNCHANGED <<nextLsn, changedLsn, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, pinnedWalLsn, pinnedSeg,
                    gcPhase, graceElapsed, storedArchives>>

BeginCompaction ==
    /\ 1 \in liveSegs /\ compactionBefore = 0
    /\ compactionBefore' = nextSeg
    /\ nextLsn' = nextLsn + 1
    /\ last' = "BeginCompaction"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactedSegs, pinnedWalLsn, pinnedSeg, workspaceSeg,
                    gcPhase, graceElapsed, storedSegs, storedArchives>>

CompactSegments ==
    /\ compactionBefore > 0 /\ compactedSegs = {} /\ nextSeg <= 3
    /\ LET newSeg == nextSeg
           illegalTarget == IF CheckCompactionBoundary THEN {} ELSE {newSeg}
       IN /\ nextSeg' = nextSeg + 1
          /\ liveSegs' = (liveSegs \ {1}) \cup {newSeg}
          /\ storedSegs' = storedSegs \cup {newSeg}
          /\ compactedSegs' = {1} \cup illegalTarget
          /\ nextLsn' = nextLsn + 1
          /\ last' = "CompactSegments"
          /\ UNCHANGED <<changedLsn, walRowFlushed, archiveThrough, walTrimmed,
                          checkpointLsn, historyFloor, compactionBefore,
                          pinnedWalLsn, pinnedSeg, workspaceSeg, gcPhase,
                          graceElapsed, storedArchives>>

PublishArchive ==
    /\ archiveThrough = 0
    /\ archiveThrough' = 2
    /\ storedArchives' = {1}
    /\ nextLsn' = nextLsn + 1
    /\ last' = "PublishArchive"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed, walTrimmed,
                    checkpointLsn, historyFloor, compactionBefore,
                    compactedSegs, pinnedWalLsn, pinnedSeg, workspaceSeg,
                    gcPhase, graceElapsed, storedSegs>>

PublishCheckpoint ==
    /\ checkpointLsn = 0 /\ archiveThrough >= 2
    /\ checkpointLsn' = 2
    /\ nextLsn' = nextLsn + 1
    /\ last' = "PublishCheckpoint"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, historyFloor, compactionBefore,
                    compactedSegs, pinnedWalLsn, pinnedSeg, workspaceSeg,
                    gcPhase, graceElapsed, storedSegs, storedArchives>>

TrimWal ==
    /\ walTrimmed = 0
    /\ ((archiveThrough >= 2 /\ checkpointLsn >= 2) \/ ~CheckTrimArchive)
    /\ walTrimmed' = 2
    /\ last' = "TrimWal"
    /\ UNCHANGED <<nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, pinnedWalLsn, pinnedSeg,
                    workspaceSeg, gcPhase, graceElapsed, storedSegs,
                    storedArchives>>

ExpireHistory ==
    /\ historyFloor = 0
    /\ ((checkpointLsn >= 2 /\ archiveThrough >= 2) \/ ~CheckCheckpointOrder)
    /\ historyFloor' = 2
    /\ nextLsn' = nextLsn + 1
    /\ last' = "ExpireHistory"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn,
                    compactionBefore, compactedSegs, pinnedWalLsn, pinnedSeg,
                    workspaceSeg, gcPhase, graceElapsed, storedSegs,
                    storedArchives>>

ReleasePins ==
    /\ (pinnedWalLsn # 0 \/ pinnedSeg # 0)
    /\ pinnedWalLsn' = 0
    /\ pinnedSeg' = 0
    /\ nextLsn' = nextLsn + 1
    /\ last' = "ReleasePins"
    /\ UNCHANGED <<changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, workspaceSeg, gcPhase,
                    graceElapsed, storedSegs, storedArchives>>

StartGC ==
    /\ gcPhase = "idle" /\ historyFloor = 2
    /\ gcPhase' = "wait"
    /\ last' = "StartGC"
    /\ UNCHANGED <<nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, pinnedWalLsn, pinnedSeg,
                    workspaceSeg, graceElapsed, storedSegs, storedArchives>>

AdvanceClockGrace ==
    /\ gcPhase = "wait" /\ ~graceElapsed
    /\ graceElapsed' = TRUE
    /\ last' = "AdvanceClockGrace"
    /\ UNCHANGED <<nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
                    archiveThrough, walTrimmed, checkpointLsn, historyFloor,
                    compactionBefore, compactedSegs, pinnedWalLsn, pinnedSeg,
                    workspaceSeg, gcPhase, storedSegs, storedArchives>>

SweepGC ==
    /\ gcPhase = "wait"
    /\ (graceElapsed \/ ~CheckGraceWindow)
    /\ LET pinSegSet == IF CheckPinProtection /\ pinnedSeg # 0 THEN {pinnedSeg} ELSE {}
           wsSegSet == IF CheckWorkspaceRoots /\ workspaceSeg # 0 THEN {workspaceSeg} ELSE {}
           keptSegs == liveSegs \cup pinSegSet \cup wsSegSet
           keptArchives == IF CheckPinProtection /\ pinnedWalLsn # 0 THEN {pinnedWalLsn} ELSE {}
       IN /\ storedSegs' = storedSegs \cap keptSegs
          /\ storedArchives' = storedArchives \cap keptArchives
          /\ gcPhase' = "complete"
          /\ last' = "SweepGC"
          /\ UNCHANGED <<nextLsn, changedLsn, nextSeg, liveSegs, walRowFlushed,
                          archiveThrough, walTrimmed, checkpointLsn,
                          historyFloor, compactionBefore, compactedSegs,
                          pinnedWalLsn, pinnedSeg, workspaceSeg, graceElapsed>>

Next == FlushWal \/ PinSegment \/ StageWorkspaceSegment \/ BeginCompaction
        \/ CompactSegments \/ PublishArchive \/ PublishCheckpoint \/ TrimWal
        \/ ExpireHistory \/ ReleasePins \/ StartGC \/ AdvanceClockGrace \/ SweepGC

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ nextLsn \in 2..12 /\ changedLsn = 2
    /\ nextSeg \in 1..4 /\ liveSegs \subseteq 1..3
    /\ walRowFlushed \in BOOLEAN
    /\ archiveThrough \in {0, 2} /\ walTrimmed \in {0, 2}
    /\ checkpointLsn \in {0, 2} /\ historyFloor \in {0, 2}
    /\ compactionBefore \in 0..3 /\ compactedSegs \subseteq 1..3
    /\ pinnedWalLsn \in {0, 1} /\ pinnedSeg \in {0, 1} /\ workspaceSeg \in {0, 2}
    /\ gcPhase \in {"idle", "wait", "complete"} /\ graceElapsed \in BOOLEAN
    /\ storedSegs \subseteq 1..3 /\ storedArchives \subseteq {1}

\* Physical maintenance never alters logical changed_lsn.
PhysicalMaintenancePreservesChangedLsn == changedLsn = 2

\* WAL trim never advances past archived and checkpointed coverage.
TrimCoverage == walTrimmed > 0 => (archiveThrough >= walTrimmed /\ checkpointLsn >= walTrimmed)

\* Compaction only consumes segments strictly below the fixed before_segment cut.
CompactionBoundary == \A s \in compactedSegs : s < compactionBefore

\* History floor expiry requires a published recovery checkpoint and archive.
CheckpointPrecedesExpiry == historyFloor > 0 => (checkpointLsn >= historyFloor /\ archiveThrough >= historyFloor)

\* Live segments and active snapshot pins remain in the object store.
PinnedRootsPreserved ==
    /\ liveSegs \subseteq storedSegs
    /\ (pinnedSeg # 0 => pinnedSeg \in storedSegs)
    /\ (pinnedWalLsn # 0 => (pinnedWalLsn >= walTrimmed \/ pinnedWalLsn \in storedArchives))

\* Private transaction workspace segments remain reachable across GC.
WorkspaceRootsPreserved == workspaceSeg # 0 => workspaceSeg \in storedSegs

\* Two-pass GC sweep never completes before the clock-uncertainty grace window elapses.
GraceWindowRespected == gcPhase = "complete" => graceElapsed
=============================================================================

------------------------------ MODULE Wal ------------------------------
EXTENDS Naturals, FiniteSets, TLC

\* Exclusive local owner, one partition, one frame per segment. File contents,
\* directory entries and atomic metadata replacement have independent durability.
CONSTANTS MaxLsn, MaxEpoch, CheckSync, CheckFence, CheckTrimOrder,
          ResumeTrim, SyncRecovered, SyncRecoveredNames
VARIABLES s, last
vars == <<s, last>>
Lsns == 0..(MaxLsn - 1)
Epochs == 1..MaxEpoch
Frames == 2..(MaxEpoch * MaxEpoch + 1)
Bytes == 0..(MaxEpoch * MaxEpoch + 1)
Frame(w,p) == 2 + (w - 1) * MaxEpoch + p - 1
Writer(f) == 1 + ((f - 2) \div MaxEpoch)
Policy(f) == 1 + ((f - 2) % MaxEpoch)
Meta == [next : 0..MaxLsn, floor : 0..MaxLsn,
         writer : Epochs, policy : Epochs]
InitialMeta == [next |-> 0, floor |-> 0, writer |-> 1, policy |-> 1]
EmptyData == [i \in Lsns |-> 0]
Min(a) == CHOOSE i \in a : \A j \in a : i <= j
Max(a) == CHOOSE i \in a : \A j \in a : i >= j
Max2(a,b) == IF a >= b THEN a ELSE b
Complete == {i \in s.names : s.data[i] \in Frames}
Incomplete == s.names \ Complete
End == IF Complete = {} THEN s.meta.floor ELSE Max(Complete) + 1
Valid == /\ End >= s.meta.next
         /\ (s.names = {} => s.meta.floor = s.meta.next)
         /\ (s.names # {} => Min(s.names) <= s.meta.floor)
         /\ \A i \in s.names :
              IF i < End THEN i \in Complete
              ELSE /\ i = End /\ i >= s.meta.next /\ i = Max(s.names)
         /\ \A i \in s.meta.floor..(End - 1) : i \in Complete
         /\ (s.names # {} => \A i \in Min(s.names)..(End - 1) : i \in Complete)
Recovered == [next |-> End, floor |-> s.meta.floor,
              writer |-> Max({s.meta.writer} \cup {Writer(s.data[i]) : i \in Complete}),
              policy |-> Max({s.meta.policy} \cup {Policy(s.data[i]) : i \in Complete})]

Init == /\ s = [data |-> EmptyData, disk |-> EmptyData,
                 names |-> {}, durableNames |-> {},
                 meta |-> InitialMeta, durableMeta |-> InitialMeta,
                 cache |-> InitialMeta, pending |-> InitialMeta,
                 phase |-> "idle", op |-> "none",
                 acked |-> EmptyData, ackWriter |-> 1, ackPolicy |-> 1,
                 trimDone |-> 0, admitted |-> TRUE, removedSafe |-> TRUE]
        /\ last = "Init"

BeginAppend(w,p) ==
    /\ s.phase = "idle" /\ s.cache.next < MaxLsn
    /\ (~CheckFence \/ (w >= s.cache.writer /\ p >= s.cache.policy))
    /\ s' = [s EXCEPT !.phase = "create", !.op = "append",
                 !.pending = [s.cache EXCEPT !.next = @ + 1, !.writer = w, !.policy = p],
                 !.admitted = w >= s.cache.writer /\ p >= s.cache.policy]
    /\ last' = "BeginAppend"
Create == /\ s.phase = "create"
          /\ s' = [s EXCEPT !.names = @ \cup {s.cache.next},
                       !.data[s.cache.next] = 0, !.phase = "partial"]
          /\ last' = "Create"
Partial == /\ s.phase = "partial"
           /\ s' = [s EXCEPT !.data[s.cache.next] = 1, !.phase = "write"]
           /\ last' = "Partial"
Write == /\ s.phase = "write"
         /\ s' = [s EXCEPT !.data[s.cache.next] =
                    Frame(s.pending.writer, s.pending.policy),
                      !.phase = "fileSync"]
         /\ last' = "Write"
FileSync == /\ s.phase = "fileSync"
            /\ s' = [s EXCEPT !.disk[s.cache.next] =
                       IF CheckSync THEN s.data[s.cache.next] ELSE @,
                         !.phase = "nameSync"]
            /\ last' = "FileSync"
NameSync == /\ s.phase = "nameSync"
            /\ s' = [s EXCEPT !.durableNames = s.names,
                         !.durableMeta = s.meta, !.phase = "metaWrite"]
            /\ last' = "NameSync"
BeginFence(w,p) ==
    /\ s.phase = "idle" /\ w >= s.cache.writer /\ p >= s.cache.policy
    /\ (w > s.cache.writer \/ p > s.cache.policy)
    /\ s' = [s EXCEPT !.phase = "metaWrite", !.op = "fence",
                 !.pending = [s.cache EXCEPT !.writer = w, !.policy = p]]
    /\ last' = "BeginFence"
BeginTrim(f) ==
    /\ s.phase = "idle" /\ f >= s.cache.floor /\ f <= s.cache.next /\ f > 0
    /\ s' = [s EXCEPT !.op = "trim", !.pending = [s.cache EXCEPT !.floor = f],
                 !.phase = IF f = s.cache.floor
                           THEN IF ResumeTrim THEN "delete" ELSE "ack"
                           ELSE IF CheckTrimOrder THEN "metaWrite" ELSE "delete"]
    /\ last' = "BeginTrim"
\* The temporary metadata file is not authoritative. Crashes before Rename
\* retain the old descriptor; successful MetaSync precedes atomic Rename.
MetaWrite == /\ s.phase = "metaWrite"
             /\ s' = [s EXCEPT !.phase = "metaSync"] /\ last' = "MetaWrite"
MetaSync == /\ s.phase = "metaSync"
            /\ s' = [s EXCEPT !.phase = "rename"] /\ last' = "MetaSync"
Rename == /\ s.phase = "rename"
          /\ s' = [s EXCEPT !.meta = s.pending, !.phase = "metaDirSync"]
          /\ last' = "Rename"
MetaDirSync == /\ s.phase = "metaDirSync"
               /\ s' = [s EXCEPT !.durableMeta = s.meta, !.durableNames = s.names,
                            !.phase = IF s.op = "trim" THEN "delete" ELSE "ack"]
               /\ last' = "MetaDirSync"
Delete == /\ s.phase = "delete"
          /\ {i \in s.names : i < s.pending.floor} # {}
          /\ LET i == Min({j \in s.names : j < s.pending.floor}) IN
                s' = [s EXCEPT !.names = @ \ {i}, !.removedSafe = i < s.durableMeta.floor]
          /\ last' = "Delete"
DeleteSync == /\ s.phase = "delete"
              /\ {i \in s.names : i < s.pending.floor} = {}
              /\ s' = [s EXCEPT !.durableNames = s.names,
                           !.durableMeta = s.meta, !.phase = "ack"]
              /\ last' = "DeleteSync"
Ack == /\ s.phase = "ack"
       /\ s' = [s EXCEPT !.cache = s.pending, !.phase = "idle", !.op = "none",
                    !.acked = IF s.op = "append" THEN
                         [@ EXCEPT ![s.cache.next] = s.data[s.cache.next]] ELSE @,
                    !.ackWriter = IF s.op = "trim" THEN @ ELSE Max2(@, s.pending.writer),
                    !.ackPolicy = IF s.op = "trim" THEN @ ELSE Max2(@, s.pending.policy),
                    !.trimDone = IF s.op = "trim" THEN s.pending.floor ELSE @]
       /\ last' = IF s.op = "trim" THEN "TrimAck" ELSE "Ack"

\* Unrequested persistence may occur in any order. Explicit successful syncs
\* impose the required lower bound; process death retains the visible image.
PersistData(i) == /\ i \in s.names /\ s.disk[i] # s.data[i]
                  /\ s' = [s EXCEPT !.disk[i] = s.data[i]] /\ last' = "PersistData"
PersistName(i) == /\ (i \in s.names) # (i \in s.durableNames)
                  /\ s' = [s EXCEPT !.durableNames = IF i \in s.names
                                    THEN @ \cup {i} ELSE @ \ {i}]
                  /\ last' = "PersistName"
PersistMeta == /\ s.meta # s.durableMeta
               /\ s' = [s EXCEPT !.durableMeta = s.meta] /\ last' = "PersistMeta"
Kill == /\ s.phase \notin {"down", "rejected"}
        /\ s' = [s EXCEPT !.phase = "down", !.op = "none", !.pending = InitialMeta]
        /\ last' = "Kill"
PowerLoss == /\ s.phase # "rejected"
             /\ s' = [s EXCEPT !.data = s.disk, !.names = s.durableNames,
                          !.meta = s.durableMeta, !.phase = "down",
                          !.op = "none", !.pending = InitialMeta]
             /\ last' = "PowerLoss"
Fail == /\ s.phase \notin {"idle", "down", "poisoned", "rejected"}
        /\ s' = [s EXCEPT !.phase = "poisoned"] /\ last' = "IoError"
Recover == /\ s.phase = "down"
           /\ s' = IF Valid THEN [s EXCEPT !.pending = Recovered, !.phase = "repair"]
                   ELSE [s EXCEPT !.phase = "rejected"]
           /\ last' = "Recover"
Repair == /\ s.phase = "repair"
          /\ s' = [s EXCEPT !.data = [i \in Lsns |-> IF i \in Incomplete
                                     THEN 0 ELSE s.data[i]],
                       !.phase = "recoverSync"]
          /\ last' = "Repair"
RecoverSync ==
    /\ s.phase = "recoverSync"
    /\ s' = [s EXCEPT !.disk = [i \in Lsns |->
                     IF i \in Incomplete \/ (SyncRecovered /\ i \in s.names /\ i >= s.meta.next)
                     THEN s.data[i] ELSE s.disk[i]],
                 !.durableNames = IF SyncRecoveredNames THEN s.names ELSE @,
                 !.durableMeta = IF SyncRecoveredNames THEN s.meta ELSE @,
                 !.cache = s.pending, !.phase = "idle"]
    /\ last' = "RecoverSync"

Next == (\E w,p \in Epochs : BeginAppend(w,p) \/ BeginFence(w,p))
        \/ (\E f \in 1..MaxLsn : BeginTrim(f))
        \/ Create \/ Partial \/ Write \/ FileSync \/ NameSync
        \/ MetaWrite \/ MetaSync \/ Rename \/ MetaDirSync \/ Delete \/ DeleteSync \/ Ack
        \/ (\E i \in Lsns : PersistData(i) \/ PersistName(i)) \/ PersistMeta
        \/ Kill \/ PowerLoss \/ Fail \/ Recover \/ Repair \/ RecoverSync
Spec == Init /\ [][Next]_vars

TypeOK == /\ s.data \in [Lsns -> Bytes] /\ s.disk \in [Lsns -> Bytes]
          /\ s.acked \in [Lsns -> Bytes]
          /\ s.names \subseteq Lsns /\ s.durableNames \subseteq Lsns
          /\ s.meta \in Meta /\ s.durableMeta \in Meta /\ s.cache \in Meta /\ s.pending \in Meta
          /\ \A m \in {s.meta, s.durableMeta, s.cache, s.pending} : m.floor <= m.next
          /\ s.ackWriter \in Epochs /\ s.ackPolicy \in Epochs
          /\ s.trimDone \in 0..MaxLsn /\ s.admitted \in BOOLEAN /\ s.removedSafe \in BOOLEAN
          /\ s.phase \in {"idle", "create", "partial", "write", "fileSync", "nameSync",
                           "metaWrite", "metaSync", "rename", "metaDirSync", "delete", "ack",
                           "down", "poisoned", "rejected", "repair", "recoverSync"}
          /\ s.op \in {"none", "append", "fence", "trim"}
DeletionAuthorized == s.removedSafe
AppendFenced == s.admitted
AcknowledgedHistory == \A i \in Lsns :
    (s.acked[i] \in Frames /\ i >= s.durableMeta.floor) =>
        (i \in s.durableNames /\ s.disk[i] = s.acked[i])
PublishedHistory == \A i \in s.durableMeta.floor..(s.durableMeta.next - 1) :
    i \in s.durableNames /\ s.disk[i] \in Frames
FencePreserved == /\ s.durableMeta.writer >= s.ackWriter
                  /\ s.durableMeta.policy >= s.ackPolicy
AcknowledgedProgress == /\ s.durableMeta.floor >= s.trimDone
                        /\ \A i \in Lsns : s.acked[i] \in Frames => i < s.durableMeta.next
TrimComplete == \A i \in s.names \cup s.durableNames : i >= s.trimDone
RecoveredFrontier == s.phase = "idle" =>
    /\ s.cache.next >= s.meta.next /\ s.cache.floor = s.meta.floor
    /\ s.cache.writer >= s.meta.writer /\ s.cache.policy >= s.meta.policy
    /\ \A i \in s.cache.floor..(s.cache.next - 1) : i \in s.names /\ s.data[i] \in Frames
=============================================================================

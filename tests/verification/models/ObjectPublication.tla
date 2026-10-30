------------------------- MODULE ObjectPublication -------------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

\* A bounded group, one candidate and its exact retry under ordered per-key locks.
\* Content pairs precede descriptors; 0/1/2 = absent/partial/complete.
\* Names and bytes can persist independently before successful sync. Successful
\* sync is truthful. An old conditional descriptor is abstracted as no NEW
\* descriptor; this model does not establish CAS, inventory or GC authority.
CONSTANTS ObjectCount, SyncPayload, SyncChecks, SyncContentNames, SyncDescriptor,
          SyncDescriptorName
VARIABLES s, last
vars == <<s, last>>
Files == 1..(3 * ObjectCount)
Content == 1..(2 * ObjectCount)
Descriptors == (2 * ObjectCount + 1)..(3 * ObjectCount)
ContentBarrier == 6 * ObjectCount
FinalBarrier == 9 * ObjectCount + 1
Done == FinalBarrier + 2

Init == /\ s = [phase |-> 0, live |-> TRUE, ack |-> FALSE,
                bytes |-> [i \in Files |-> 0], durable |-> [i \in Files |-> 0],
                names |-> {}, savedNames |-> {}]
        /\ last = "Init"

Partial(i, phase) ==
    /\ s.live /\ s.phase = phase /\ s.bytes[i] = 0 /\ i \notin s.names
    /\ s' = [s EXCEPT !.bytes[i] = 1]
    /\ last' = "Partial"
Write(i, phase, event) ==
    /\ s.live /\ s.phase = phase
    /\ s' = [s EXCEPT !.bytes[i] = 2, !.phase = phase + 1]
    /\ last' = event
Sync(i, phase, guard, event) ==
    /\ s.live /\ s.phase = phase
    /\ s' = [s EXCEPT !.durable[i] = IF guard THEN s.bytes[i] ELSE @,
                       !.phase = phase + 1]
    /\ last' = event
Link(i, phase, event) ==
    /\ s.live /\ s.phase = phase
    /\ s' = [s EXCEPT !.names = @ \cup {i}, !.phase = phase + 1]
    /\ last' = event

PayloadWrite == \E k \in 1..ObjectCount: Write(2*k-1, 6*(k-1), "PayloadWrite")
PayloadSync == \E k \in 1..ObjectCount: Sync(2*k-1, 6*(k-1)+1, SyncPayload, "PayloadSync")
PayloadLink == \E k \in 1..ObjectCount: Link(2*k-1, 6*(k-1)+2, "PayloadLink")
ChecksWrite == \E k \in 1..ObjectCount: Write(2*k, 6*(k-1)+3, "ChecksWrite")
ChecksSync == \E k \in 1..ObjectCount: Sync(2*k, 6*(k-1)+4, SyncChecks, "ChecksSync")
ChecksLink == \E k \in 1..ObjectCount: Link(2*k, 6*(k-1)+5, "ChecksLink")
ContentNamesSync ==
    /\ s.live /\ s.phase = ContentBarrier
    /\ s' = [s EXCEPT !.savedNames = IF SyncContentNames THEN @ \cup Content ELSE @,
                       !.phase = ContentBarrier + 1]
    /\ last' = "ContentNamesSync"
DescriptorWrite == \E k \in 1..ObjectCount:
    Write(2*ObjectCount+k, ContentBarrier+1+3*(k-1), "DescriptorWrite")
DescriptorSync == \E k \in 1..ObjectCount:
    Sync(2*ObjectCount+k, ContentBarrier+2+3*(k-1), SyncDescriptor, "DescriptorSync")
DescriptorReplace == \E k \in 1..ObjectCount:
    Link(2*ObjectCount+k, ContentBarrier+3+3*(k-1), "DescriptorReplace")
DescriptorNameSync ==
    /\ s.live /\ s.phase = FinalBarrier
    /\ s' = [s EXCEPT !.savedNames = IF SyncDescriptorName THEN @ \cup Descriptors ELSE @,
                       !.phase = FinalBarrier + 1]
    /\ last' = "DescriptorNameSync"
Ack == /\ s.live /\ s.phase = FinalBarrier + 1
       /\ s' = [s EXCEPT !.phase = Done, !.ack = TRUE]
       /\ last' = "Ack"

\* Environment writeback may persist any prefix and any linked name. This
\* models ordering obligations, not device sectors or a physical filesystem.
PersistBytes ==
    \E i \in Files, n \in 0..2:
       /\ n > s.durable[i] /\ n <= s.bytes[i]
       /\ s' = [s EXCEPT !.durable[i] = n]
       /\ last' = "PersistBytes"
PersistName ==
    \E i \in s.names \ s.savedNames:
       /\ s' = [s EXCEPT !.savedNames = @ \cup {i}]
       /\ last' = "PersistName"
Kill == /\ s.live
        /\ s' = [s EXCEPT !.live = FALSE, !.phase = 0]
        /\ last' = "Kill"
IoError == /\ s.live /\ s.phase < Done
           /\ s' = [s EXCEPT !.live = FALSE, !.phase = 0]
           /\ last' = "IoError"
PowerLoss == /\ s.live
             /\ s' = [s EXCEPT !.live = FALSE, !.phase = 0,
                                !.bytes = s.durable, !.names = s.savedNames]
             /\ last' = "PowerLoss"
Recover == /\ ~s.live /\ ~s.ack
           /\ s' = [s EXCEPT !.live = TRUE]
           /\ last' = "Recover"

Next == PayloadWrite \/ PayloadSync \/ PayloadLink \/ ChecksWrite \/ ChecksSync
        \/ ChecksLink \/ ContentNamesSync \/ DescriptorWrite \/ DescriptorSync
        \/ DescriptorReplace \/ DescriptorNameSync \/ Ack
        \/ (\E k \in 1..ObjectCount: Partial(2*k-1, 6*(k-1)) \/ Partial(2*k, 6*(k-1)+3)
            \/ Partial(2*ObjectCount+k, ContentBarrier+1+3*(k-1)))
        \/ PersistBytes \/ PersistName \/ Kill \/ IoError \/ PowerLoss \/ Recover
Spec == Init /\ [][Next]_vars

TypeOK == /\ s.phase \in 0..Done /\ s.live \in BOOLEAN /\ s.ack \in BOOLEAN
          /\ s.bytes \in [Files -> 0..2] /\ s.durable \in [Files -> 0..2]
          /\ s.names \subseteq Files /\ s.savedNames \subseteq Files
ContentBeforeVisibility ==
    s.names \cap Descriptors # {} => /\ Content \subseteq s.savedNames
                        /\ \A i \in Content: s.durable[i] = 2
DescriptorBeforeVisibility == \A i \in Descriptors \cap s.names: s.durable[i] = 2
AcknowledgedDurable == s.ack => /\ s.savedNames = Files
                                /\ \A i \in Files: s.durable[i] = 2
=============================================================================

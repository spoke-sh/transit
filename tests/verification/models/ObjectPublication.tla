------------------------- MODULE ObjectPublication -------------------------
EXTENDS Integers, Sequences, FiniteSets, TLC

\* One key, one candidate and its exact retry under the per-key process lock.
\* 1 = payload, 2 = checks, 3 = descriptor; 0/1/2 = absent/partial/complete.
\* Names and bytes can persist independently before successful sync. Successful
\* sync is truthful. An old conditional descriptor is abstracted as no NEW
\* descriptor; this model does not establish CAS, inventory or GC authority.
CONSTANTS SyncPayload, SyncChecks, SyncContentNames, SyncDescriptor,
          SyncDescriptorName
VARIABLES s, last
vars == <<s, last>>
Files == 1..3
Content == {1, 2}

Init == /\ s = [phase |-> 0, live |-> TRUE, ack |-> FALSE,
                bytes |-> <<0, 0, 0>>, durable |-> <<0, 0, 0>>,
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

PayloadWrite == Write(1, 0, "PayloadWrite")
PayloadSync == Sync(1, 1, SyncPayload, "PayloadSync")
PayloadLink == Link(1, 2, "PayloadLink")
ChecksWrite == Write(2, 3, "ChecksWrite")
ChecksSync == Sync(2, 4, SyncChecks, "ChecksSync")
ChecksLink == Link(2, 5, "ChecksLink")
ContentNamesSync ==
    /\ s.live /\ s.phase = 6
    /\ s' = [s EXCEPT !.savedNames = IF SyncContentNames THEN @ \cup Content ELSE @,
                       !.phase = 7]
    /\ last' = "ContentNamesSync"
DescriptorWrite == Write(3, 7, "DescriptorWrite")
DescriptorSync == Sync(3, 8, SyncDescriptor, "DescriptorSync")
DescriptorReplace == Link(3, 9, "DescriptorReplace")
DescriptorNameSync ==
    /\ s.live /\ s.phase = 10
    /\ s' = [s EXCEPT !.savedNames = IF SyncDescriptorName THEN @ \cup {3} ELSE @,
                       !.phase = 11]
    /\ last' = "DescriptorNameSync"
Ack == /\ s.live /\ s.phase = 11
       /\ s' = [s EXCEPT !.phase = 12, !.ack = TRUE]
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
IoError == /\ s.live /\ s.phase < 12
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
        \/ Partial(1, 0) \/ Partial(2, 3) \/ Partial(3, 7)
        \/ PersistBytes \/ PersistName \/ Kill \/ IoError \/ PowerLoss \/ Recover
Spec == Init /\ [][Next]_vars

TypeOK == /\ s.phase \in 0..12 /\ s.live \in BOOLEAN /\ s.ack \in BOOLEAN
          /\ s.bytes \in [Files -> 0..2] /\ s.durable \in [Files -> 0..2]
          /\ s.names \subseteq Files /\ s.savedNames \subseteq Files
ContentBeforeVisibility ==
    3 \in s.names => /\ Content \subseteq s.savedNames
                        /\ \A i \in Content: s.durable[i] = 2
DescriptorBeforeVisibility == 3 \in s.names => s.durable[3] = 2
AcknowledgedDurable == s.ack => /\ s.savedNames = Files
                                /\ \A i \in Files: s.durable[i] = 2
=============================================================================

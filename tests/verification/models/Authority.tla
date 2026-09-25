--------------------------- MODULE Authority ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS MaxTail, CheckTail, CheckGeneration, CheckPermission, CheckClosure
VARIABLES tail, generation, granted, closed, now, prepared, committed, acknowledged,
          effect, badEffect, last
vars == <<tail, generation, granted, closed, now, prepared, committed,
          acknowledged, effect, badEffect, last>>
Slots == {0, 1}
Empty == [at |-> 0, generation |-> 0, input |-> 0]

Init == /\ tail = 0 /\ generation = 1 /\ granted = TRUE
        /\ closed = FALSE /\ now = 0
        /\ prepared = [s \in Slots |-> Empty]
        /\ committed = <<>> /\ acknowledged = {}
        /\ effect = "pending" /\ badEffect = FALSE /\ last = "Init"

Prepare(s, stale) ==
    /\ Len(committed) < 2 /\ now < 2
    /\ (granted \/ ~CheckPermission) /\ (~closed \/ ~CheckClosure)
    /\ (~stale \/ ~CheckGeneration)
    /\ prepared' = [prepared EXCEPT ![s] =
        [at |-> tail, generation |-> IF stale THEN 0 ELSE generation,
         input |-> Len(committed) + 1]]
    /\ last' = IF stale THEN IF s = 0 THEN "PrepareStale0" ELSE "PrepareStale1"
               ELSE IF s = 0 THEN "Prepare0" ELSE "Prepare1"
    /\ UNCHANGED <<tail, generation, granted, closed, now, committed,
                    acknowledged, effect, badEffect>>

Commit(s, lost) ==
    /\ tail < MaxTail /\ prepared[s].input # 0
    /\ (prepared[s].at = tail \/ ~CheckTail)
    /\ committed' = Append(committed,
        [input |-> prepared[s].input,
         safe |-> granted /\ ~closed /\ prepared[s].generation = generation])
    /\ acknowledged' = IF lost THEN acknowledged
                         ELSE acknowledged \cup {prepared[s].input}
    /\ tail' = tail + 1
    /\ last' = IF lost THEN IF s = 0 THEN "Lost0" ELSE "Lost1"
               ELSE IF s = 0 THEN "Commit0" ELSE "Commit1"
    /\ UNCHANGED <<generation, granted, closed, now, prepared, effect, badEffect>>

Retry(s) ==
    /\ granted /\ prepared[s].input \in {committed[i].input : i \in 1..Len(committed)}
    /\ acknowledged' = acknowledged \cup {prepared[s].input}
    /\ last' = IF s = 0 THEN "Retry0" ELSE "Retry1"
    /\ UNCHANGED <<tail, generation, granted, closed, now, prepared, committed,
                    effect, badEffect>>

Own == /\ tail < MaxTail /\ granted /\ ~closed /\ now < 1
       /\ tail' = tail + 1 /\ generation' = generation + 1 /\ last' = "Own"
       /\ UNCHANGED <<granted, closed, now, prepared, committed,
                       acknowledged, effect, badEffect>>
Revoke == /\ tail < MaxTail /\ granted
          /\ tail' = tail + 1 /\ granted' = FALSE /\ last' = "Revoke"
          /\ UNCHANGED <<generation, closed, now, prepared, committed,
                          acknowledged, effect, badEffect>>
Grant == /\ tail < MaxTail /\ ~granted
         /\ tail' = tail + 1 /\ granted' = TRUE /\ last' = "Grant"
         /\ UNCHANGED <<generation, closed, now, prepared, committed,
                         acknowledged, effect, badEffect>>
Tick == /\ now < 2 /\ now' = now + 1 /\ last' = "Tick"
        /\ UNCHANGED <<tail, generation, granted, closed, prepared, committed,
                        acknowledged, effect, badEffect>>
Close == /\ tail < MaxTail /\ ~closed
         /\ tail' = tail + 1 /\ closed' = TRUE /\ last' = "Close"
         /\ UNCHANGED <<generation, granted, now, prepared, committed,
                         acknowledged, effect, badEffect>>

\* Connector settlement is distinct from process closure. Dispatch authorization
\* before cutoff may result in a later external send; this model never promises
\* remote cancellation. Accepted observations stop at the settlement boundary.
Dispatch == /\ tail < MaxTail /\ granted /\ ~closed /\ now < 1
            /\ effect = "pending" /\ effect' = "authorized"
            /\ tail' = tail + 1 /\ last' = "Dispatch"
            /\ UNCHANGED <<generation, granted, closed, now, prepared, committed,
                            acknowledged, badEffect>>
Observe == /\ tail < MaxTail /\ granted /\ now < 2
           /\ (effect = "authorized" \/ (~CheckClosure /\ effect = "closed"))
           /\ badEffect' = badEffect \/ effect = "closed"
           /\ effect' = "observed" /\ tail' = tail + 1 /\ last' = "Observe"
           /\ UNCHANGED <<generation, granted, closed, now, prepared, committed,
                           acknowledged>>
CloseEffect == /\ tail < MaxTail /\ effect = "authorized"
               /\ effect' = "closed" /\ tail' = tail + 1 /\ last' = "CloseEffect"
               /\ UNCHANGED <<generation, granted, closed, now, prepared, committed,
                               acknowledged, badEffect>>

Next == (\E s \in Slots : (\E stale \in BOOLEAN : Prepare(s, stale))
                          \/ (\E lost \in BOOLEAN : Commit(s, lost)) \/ Retry(s))
        \/ Own \/ Revoke \/ Grant \/ Tick \/ Close \/ Dispatch \/ Observe \/ CloseEffect
Spec == Init /\ [][Next]_vars
TypeOK == /\ tail \in 0..MaxTail /\ now \in 0..2 /\ generation \in 1..(MaxTail + 1)
          /\ granted \in BOOLEAN /\ closed \in BOOLEAN /\ badEffect \in BOOLEAN
PublicationSafe == \A i \in 1..Len(committed) : committed[i].safe
UniqueInput == Cardinality({committed[i].input : i \in 1..Len(committed)}) = Len(committed)
AcknowledgementSound == acknowledged \subseteq {committed[i].input : i \in 1..Len(committed)}
SettlementClosed == ~badEffect
=============================================================================

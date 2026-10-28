----------------------- MODULE TableTransaction -----------------------
EXTENDS Naturals, FiniteSets, Sequences

\* Two original transactions and two Tables. Each program is finite, but every
\* interleaving of begin, statements, prepare, decision and finalization runs.
\* The decision journal supplies atomic/fenced append and original identity.
\* A host acquisition fence excludes data/definition publication while pinning.
\* Crash drops that fence; resume must revalidate every already-pinned source.
CONSTANTS Programs, ReadOnly, AllowDefinition, CheckReads, CheckDependencies, CheckVisibility,
          CheckBarrier, CheckDefinition, CheckPrivate, CheckAcquisition
VARIABLES tx, base, barrier, published, definitions, cutOwner, cuts, audit, last
vars == <<tx, base, barrier, published, definitions, cutOwner, cuts, audit, last>>
Transactions == {1, 2}
Tables == {1, 2}
Zero == [p \in Tables |-> 0]
Read(p) == [action |-> "read", table |-> p]
Write(p) == [action |-> "write", table |-> p]
Save == [action |-> "save", table |-> 1]
Rollback == [action |-> "rollback", table |-> 1]
SkewPrograms == [t \in Transactions |-> <<Read(3 - t), Write(t)>>]
PublicationPrograms == [t \in Transactions |->
    IF t = 1 THEN <<Write(1), Write(2)>> ELSE <<Read(1), Read(2)>>]
SavepointPrograms == [t \in Transactions |->
    IF t = 1 THEN <<Save, Read(2), Write(1), Rollback, Write(1)>>
    ELSE <<Read(1), Write(2)>>]
PrivatePrograms == [t \in Transactions |-> <<Write(t), Read(t)>>]
BarrierPrograms == [t \in Transactions |-> <<Write(1), Write(2)>>]
Empty == [phase |-> "new", pc |-> 1, cut |-> Zero, schema |-> Zero, pinned |-> {},
          reads |-> {}, dependencies |-> {}, writes |-> {}, saved |-> {},
          prepared |-> {}, finalized |-> {}, decision |-> "none"]
Init == /\ tx = [t \in Transactions |-> Empty]
        /\ base = Zero /\ barrier = Zero /\ published = Zero
        /\ definitions = Zero /\ cutOwner = 0 /\ cuts = {<<Zero, Zero>>}
        /\ audit = TRUE /\ last = "Init"

\* The physical predecessor remains until maintenance finalizes this Table.
Visible == [p \in Tables |->
    IF CheckVisibility /\ barrier[p] # 0
    THEN IF tx[barrier[p]].decision = "committed" THEN barrier[p] ELSE base[p]
    ELSE base[p]]

Begin(t) ==
    /\ tx[t].phase = "new" /\ cutOwner = 0
    /\ tx' = [tx EXCEPT ![t].phase = "acquiring"]
    /\ cutOwner' = t
    /\ last' = "Begin" /\ audit' = TRUE
    /\ UNCHANGED <<base, barrier, published, definitions, cuts>>

Pin(t, p) ==
    /\ tx[t].phase = "acquiring" /\ cutOwner = t /\ p \notin tx[t].pinned
    /\ tx' = [tx EXCEPT ![t].cut[p] = Visible[p], ![t].schema[p] = definitions[p],
                       ![t].pinned = @ \cup {p}]
    /\ last' = "Pin" /\ audit' = TRUE
    /\ UNCHANGED <<base, barrier, published, definitions, cutOwner, cuts>>

Acquire(t) ==
    /\ tx[t].phase = "acquiring" /\ cutOwner = t /\ tx[t].pinned = Tables
    /\ tx' = [tx EXCEPT ![t].phase = "active"] /\ cutOwner' = 0
    /\ audit' = (<<tx[t].cut, tx[t].schema>> \in cuts) /\ last' = "Acquire"
    /\ UNCHANGED <<base, barrier, published, definitions, cuts>>

Crash(t) ==
    /\ tx[t].phase = "acquiring" /\ cutOwner = t /\ cutOwner' = 0
    /\ last' = "Crash" /\ audit' = TRUE
    /\ UNCHANGED <<tx, base, barrier, published, definitions, cuts>>

Resume(t) ==
    /\ tx[t].phase = "acquiring" /\ cutOwner = 0
    /\ (\A p \in tx[t].pinned :
          (tx[t].cut[p] = Visible[p] /\ tx[t].schema[p] = definitions[p])
          \/ ~CheckAcquisition)
    /\ cutOwner' = t /\ last' = "Resume" /\ audit' = TRUE
    /\ UNCHANGED <<tx, base, barrier, published, definitions, cuts>>

Statement(t) ==
    /\ tx[t].phase = "active" /\ tx[t].pc <= Len(Programs[t])
    /\ LET op == Programs[t][tx[t].pc]
           p == op.table
           own == p \in tx[t].writes
           value == IF CheckPrivate /\ own THEN t ELSE tx[t].cut[p]
           advanced == [tx EXCEPT ![t].pc = @ + 1]
       IN CASE op.action = "read" ->
            /\ tx' = [advanced EXCEPT
                 ![t].reads = IF own THEN @ ELSE @ \cup {<<p, value>>},
                 ![t].dependencies = @ \cup {p}]
            /\ audit' = (~own \/ value = t)
          [] op.action = "write" ->
            /\ t \notin ReadOnly
            /\ tx' = [advanced EXCEPT ![t].writes = @ \cup {p}]
            /\ audit' = TRUE
          [] op.action = "save" ->
            /\ tx' = [advanced EXCEPT ![t].saved = tx[t].writes]
            /\ audit' = TRUE
          [] op.action = "rollback" ->
            /\ tx' = [advanced EXCEPT ![t].writes = tx[t].saved,
                 ![t].dependencies = IF CheckDependencies THEN @ ELSE {}]
            /\ audit' = TRUE
    /\ last' = Programs[t][tx[t].pc].action
    /\ UNCHANGED <<base, barrier, published, definitions, cutOwner, cuts>>

Freeze(t) ==
    /\ tx[t].phase = "active" /\ tx[t].pc > Len(Programs[t])
    /\ tx' = [tx EXCEPT ![t].phase = "frozen"]
    /\ last' = "Freeze" /\ audit' = TRUE
    /\ UNCHANGED <<base, barrier, published, definitions, cutOwner, cuts>>

Prepare(t, p) ==
    /\ tx[t].phase = "frozen" /\ tx[t].decision = "none"
    /\ p \in tx[t].writes \ tx[t].prepared
    /\ (barrier[p] = 0 \/ ~CheckBarrier)
    /\ tx' = [tx EXCEPT ![t].prepared = @ \cup {p}]
    /\ barrier' = [barrier EXCEPT ![p] = t]
    /\ last' = "Prepare" /\ audit' = TRUE
    /\ UNCHANGED <<base, published, definitions, cutOwner, cuts>>

Commit(t) ==
    /\ tx[t].phase = "frozen" /\ tx[t].decision = "none" /\ cutOwner = 0
    /\ tx[t].prepared = tx[t].writes
    /\ LET guarded == tx[t].writes \cup
                        (IF CheckReads THEN tx[t].dependencies ELSE {})
       IN /\ (t \in ReadOnly \/
              \A p \in guarded : published[p] = tx[t].cut[p])
          /\ (\A p \in guarded :
                definitions[p] = tx[t].schema[p] \/ ~CheckDefinition)
    /\ tx' = [tx EXCEPT ![t].decision = "committed", ![t].phase = "decided"]
    /\ published' = [p \in Tables |-> IF p \in tx[t].writes THEN t ELSE published[p]]
    /\ cuts' = cuts \cup {<<published', definitions>>}
    /\ audit' = \A p \in tx[t].writes \cup tx[t].dependencies :
                   definitions[p] = tx[t].schema[p]
    /\ last' = "Commit"
    /\ UNCHANGED <<base, barrier, definitions, cutOwner>>

Abort(t) ==
    /\ tx[t].phase \in {"acquiring", "active", "frozen"} /\ tx[t].decision = "none"
    /\ tx' = [tx EXCEPT ![t].decision = "aborted", ![t].phase = "decided"]
    /\ cutOwner' = IF cutOwner = t THEN 0 ELSE cutOwner
    /\ last' = "Abort" /\ audit' = TRUE
    /\ UNCHANGED <<base, barrier, published, definitions, cuts>>

Finalize(t, p) ==
    /\ tx[t].phase = "decided" /\ p \in tx[t].prepared \ tx[t].finalized
    /\ barrier[p] = t
    /\ base' = [base EXCEPT ![p] = IF tx[t].decision = "committed" THEN t ELSE @]
    /\ barrier' = [barrier EXCEPT ![p] = 0]
    /\ tx' = [tx EXCEPT ![t].finalized = @ \cup {p}]
    /\ last' = "Finalize" /\ audit' = TRUE
    /\ UNCHANGED <<published, definitions, cutOwner, cuts>>

ChangeDefinition(p) ==
    /\ AllowDefinition /\ definitions[p] = 0 /\ barrier[p] = 0 /\ cutOwner = 0
    /\ definitions' = [definitions EXCEPT ![p] = 1]
    /\ cuts' = cuts \cup {<<published, definitions'>>}
    /\ last' = "ChangeDefinition" /\ audit' = TRUE
    /\ UNCHANGED <<tx, base, barrier, published, cutOwner>>

Next == (\E t \in Transactions : Begin(t) \/ Acquire(t) \/ Crash(t) \/ Resume(t)
                                 \/ Statement(t) \/ Freeze(t)
                                 \/ Commit(t) \/ Abort(t)
                                 \/ (\E p \in Tables : Pin(t, p) \/ Prepare(t, p) \/ Finalize(t, p)))
        \/ (\E p \in Tables : ChangeDefinition(p))
Spec == Init /\ [][Next]_vars

Committed == {t \in Transactions : tx[t].decision = "committed"}
\* Independent serial-history oracle. Reads of one's own writes are excluded;
\* all other returned values, including reads before rollback, constrain order.
Fits(first, second) ==
    /\ (first \notin Committed \/ \A r \in tx[first].reads : r[2] = 0)
    /\ (second \notin Committed \/ \A r \in tx[second].reads :
          r[2] = IF first \in Committed /\ r[1] \in tx[first].writes THEN first ELSE 0)
Serializable == Fits(1, 2) \/ Fits(2, 1)
AtomicVisibility == Visible = published
BarrierIntegrity == \A t \in Transactions :
    \A p \in tx[t].prepared \ tx[t].finalized : barrier[p] = t
RetainedDependencies == \A t \in Transactions :
    \A r \in tx[t].reads : r[1] \in tx[t].dependencies
CurrentDefinition == (last = "Commit" => audit)
ReadYourWrites == (last = "read" => audit)
CommonCut == (last = "Acquire" => audit)
TypeOK == /\ base \in [Tables -> 0..2] /\ published \in [Tables -> 0..2]
          /\ barrier \in [Tables -> 0..2] /\ definitions \in [Tables -> 0..1]
          /\ audit \in BOOLEAN /\ cutOwner \in 0..2
          /\ cuts \subseteq ([Tables -> 0..2] \X [Tables -> 0..1])
          /\ \A t \in Transactions :
              /\ tx[t].phase \in {"new", "acquiring", "active", "frozen", "decided"}
              /\ tx[t].decision \in {"none", "committed", "aborted"}
              /\ tx[t].cut \in [Tables -> 0..2] /\ tx[t].schema \in [Tables -> 0..1]
              /\ tx[t].pinned \subseteq Tables
              /\ tx[t].pc \in 1..(Len(Programs[t]) + 1)
              /\ tx[t].reads \subseteq (Tables \X (0..2))
              /\ tx[t].dependencies \subseteq Tables /\ tx[t].writes \subseteq Tables
              /\ tx[t].saved \subseteq Tables /\ tx[t].prepared \subseteq Tables
              /\ tx[t].finalized \subseteq Tables
=============================================================================

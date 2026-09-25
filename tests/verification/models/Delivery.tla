-------------------------- MODULE Delivery ---------------------------
EXTENDS Naturals

\* Growing result delivery: bounded ordered segment transfer from a captured
\* Station job to its destination, with receiver-driven credit-based flow
\* control. This models the wire contract in
\* packages/zig/transit-station/src/QueryDelivery.zig and
\* contracts/STATION_QUERY_V2.md, not Zig execution; see the file header in
\* both for what remains an integration premise.

CONSTANTS NumSegments, Window
VARIABLES sent, received, granted, seen, complete
vars == <<sent, received, granted, seen, complete>>

Init == /\ sent = 0 /\ received = 0 /\ granted = 0 /\ seen = 0 /\ complete = FALSE

\* The sender may not run more than Window segments ahead of credit it has
\* actually observed. This is the flow-control bound itself: exceeding it is
\* the one guard a mutant of this model would remove.
SendSegment == /\ sent < NumSegments /\ sent - seen < Window
               /\ sent' = sent + 1
               /\ UNCHANGED <<received, granted, seen, complete>>

\* The network/receiver accepts the next segment strictly in order, matching
\* QueryDelivery.receiving's ordinal check (manifest.ordinal # transfer.segments
\* is rejected). Reordering or skipping is not a modeled transition.
Deliver == /\ received < sent
           /\ received' = received + 1
           /\ UNCHANGED <<sent, granted, seen, complete>>

\* A lost credit grant or lost acknowledgement causes the sender to retry an
\* already-accepted segment. The receiver's duplicate check is a no-op, exactly
\* QueryRecords.Fragment/Segment's idempotent-duplicate branch: identical
\* evidence is inert, not a state change or a second acceptance.
DuplicateDeliver == /\ received > 0 /\ sent >= received
                     /\ UNCHANGED vars

\* The receiver only grants credit for segments it has durably verified and
\* stored (`granted <= received` is enforced by construction here, and
\* asserted separately as the CreditSound invariant). This is the deliberate
\* design choice from the flow-control discussion: credit is receiver-issued,
\* not sender-self-paced.
GrantCredit == /\ granted < received
               /\ granted' = received
               /\ UNCHANGED <<sent, received, seen, complete>>

\* The sender observes a credit grant. Modeled as a separate step (rather than
\* folded into GrantCredit) so grant delivery can lag or never happen, the same
\* way an ordinary cast can be lost; SendSegment's guard only ever sees `seen`.
ObserveCredit == /\ seen < granted
                  /\ seen' = granted
                  /\ UNCHANGED <<sent, received, granted, complete>>

\* The final manifest acknowledgement, closing the caller's wait. Only
\* reachable once every segment is durably received in order, matching
\* Manifest.check/Transfer.seal's all-segments-sealed requirement.
Acknowledge == /\ received = NumSegments /\ ~complete
               /\ complete' = TRUE
               /\ UNCHANGED <<sent, received, granted, seen>>

Next == SendSegment \/ Deliver \/ DuplicateDeliver \/ GrantCredit \/ ObserveCredit \/ Acknowledge
Spec == Init /\ [][Next]_vars

TypeOK == /\ sent \in 0..NumSegments /\ received \in 0..NumSegments
          /\ granted \in 0..NumSegments /\ seen \in 0..NumSegments
          /\ complete \in BOOLEAN
          /\ received <= sent /\ granted <= received /\ seen <= granted

\* The sender never runs more than Window segments ahead of credit it has
\* actually observed, independent of TypeOK's static ranges.
WindowBound == sent - seen <= Window

\* The receiver never issues credit ahead of what it has durably stored.
CreditSound == granted <= received

\* Acknowledgement is never sent before every segment is durably verified.
NoPrematureAck == complete => received = NumSegments
=============================================================================

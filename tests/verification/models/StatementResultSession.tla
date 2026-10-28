--------------------- MODULE StatementResultSession ---------------------
EXTENDS StatementResult, Sequences

\* One established reader, one retained server batch and one response in flight.
\* The initial execute response has already arrived. Losing it is deliberately
\* outside this model: it cannot be repaired by the fetch protocol below.
CONSTANTS CheckRepeat, CheckDisclosure
VARIABLES total, w, receivedRows, deliveredRows, disclosure
sessionVars == <<s, last, error, safety, total, w, receivedRows, deliveredRows, disclosure>>
Rows(start, count) == [i \in 1..count |-> start + i]
Accept(x, n, terminal, count) ==
    LET rows == IF n = 0 THEN OK(x) ELSE Receive(x, n, 0)
        done == IF rows.error = "none" /\ terminal
                THEN Finish(rows.state, count, 0) ELSE rows
    IN done
Stop(x, cancelled) == Release(Fail(x, cancelled).state).state
SessionInit ==
    /\ total \in 0..MaxRows
    /\ \E n \in 0..total, terminal \in BOOLEAN :
       /\ (n > 0 \/ (total = 0 /\ terminal))
       /\ (terminal => n = total)
       /\ s = Accept(Initial, n, terminal, total).state
       /\ w = [produced |-> n, start |-> 0, rows |-> n, terminal |-> terminal,
                ordinal |-> 0, accepted |-> TRUE, reply |-> "none",
                allowed |-> TRUE, alive |-> TRUE, closed |-> FALSE]
       /\ receivedRows = Rows(0, n) /\ deliveredRows = <<>>
    /\ last = Event("Init", 0, 0) /\ error = "none"
    /\ safety = Audit(Initial, Initial, last, error) /\ disclosure = TRUE

\* Fetching the successor acknowledges the drained batch and materializes a
\* bounded new one. Materialization is separated from the disclosure check.
Buffer(n, terminal) ==
    /\ Reading(s) /\ s.outcome = "open" /\ s.received = s.delivered
    /\ w.accepted /\ w.reply = "none" /\ w.alive /\ ~w.closed
    /\ n \in 0..(total-w.produced)
    /\ (n > 0 \/ terminal) /\ (terminal => w.produced+n = total)
    /\ w' = [w EXCEPT !.start = w.produced, !.rows = n, !.terminal = terminal,
              !.produced = @ + n, !.ordinal = @ + 1, !.accepted = FALSE]
    /\ last' = Event(IF terminal THEN "BufferFinal" ELSE "Buffer", n, 0)
    /\ UNCHANGED <<s, error, safety, total, receivedRows, deliveredRows, disclosure>>
Send ==
    /\ w.reply = "none" /\ ~s.released
    /\ w' = [w EXCEPT !.reply = IF ~w.alive \/ w.closed THEN "expired"
                    ELSE IF CheckDisclosure /\ ~w.allowed THEN "denied" ELSE "data"]
    /\ disclosure' = (w'.reply = "data" => (w.allowed /\ w.alive /\ ~w.closed))
    /\ last' = Event("Send", 0, 0)
    /\ UNCHANGED <<s, error, safety, total, receivedRows, deliveredRows>>
Drop == /\ w.reply # "none" /\ w' = [w EXCEPT !.reply = "none"]
        /\ last' = Event("Drop", 0, 0)
        /\ UNCHANGED <<s, error, safety, total, receivedRows, deliveredRows, disclosure>>
ReceiveReply ==
    /\ w.reply # "none"
    /\ LET fresh == ~s.released /\ w.reply = "data" /\ (~w.accepted \/ ~CheckRepeat)
           attempt == IF fresh THEN Accept(s, w.rows, w.terminal, w.produced) ELSE OK(s)
           failed == ~s.released /\ (w.reply # "data" \/ attempt.error # "none")
       IN /\ s' = IF failed THEN Stop(s, FALSE) ELSE attempt.state
          /\ receivedRows' = IF fresh /\ ~failed THEN receivedRows \o Rows(w.start, w.rows) ELSE receivedRows
          /\ w' = [w EXCEPT !.reply = "none", !.accepted = IF fresh /\ ~failed THEN TRUE ELSE @]
    /\ last' = Event("ReceiveReply", 0, 0)
    /\ UNCHANGED <<error, safety, total, deliveredRows, disclosure>>
Consume(n) ==
    /\ Reading(s) /\ n \in 1..(s.received-s.delivered)
    /\ s' = Deliver(s, n).state
    /\ deliveredRows' = deliveredRows \o SubSeq(receivedRows, s.delivered+1, s.delivered+n)
    /\ last' = Event("Consume", n, 0)
    /\ UNCHANGED <<w, error, safety, total, receivedRows, disclosure>>
Environment(kind) ==
    /\ kind \in {"Revoke", "Grant", "Expire", "Renew", "Cleanup"}
    /\ (kind = "Renew" => w.alive /\ ~w.closed)
    /\ (kind = "Cleanup" => s.released \/ ~w.alive)
    /\ w' = CASE kind = "Revoke" -> [w EXCEPT !.allowed = FALSE]
               [] kind = "Grant" -> [w EXCEPT !.allowed = TRUE]
               [] kind = "Expire" -> [w EXCEPT !.alive = FALSE]
               [] kind = "Renew" -> w
               [] kind = "Cleanup" -> [w EXCEPT !.closed = TRUE]
    /\ last' = Event(kind, 0, 0)
    /\ UNCHANGED <<s, error, safety, total, receivedRows, deliveredRows, disclosure>>
End(kind) ==
    /\ kind \in {"Close", "EOF", "Cancel"}
    /\ s' = IF kind = "Close" THEN Release(s).state ELSE Stop(s, kind = "Cancel")
    /\ last' = Event(kind, 0, 0)
    /\ UNCHANGED <<w, error, safety, total, receivedRows, deliveredRows, disclosure>>
SessionNext ==
    \/ \E n \in 0..MaxRows, terminal \in BOOLEAN : Buffer(n, terminal)
    \/ Send \/ Drop \/ ReceiveReply
    \/ \E n \in 1..MaxRows : Consume(n)
    \/ \E kind \in {"Revoke", "Grant", "Expire", "Renew", "Cleanup"} : Environment(kind)
    \/ \E kind \in {"Close", "EOF", "Cancel"} : End(kind)
SessionSpec == SessionInit /\ [][SessionNext]_sessionVars
SessionTypeOK == /\ TypeOK /\ total \in 0..MaxRows
                 /\ w.produced \in 0..total /\ w.start \in 0..w.produced
                 /\ w.rows = w.produced-w.start /\ w.ordinal \in 0..(MaxRows+1)
                 /\ w.reply \in {"none", "data", "denied", "expired"}
                 /\ \A b \in {w.accepted, w.terminal, w.allowed, w.alive, w.closed, disclosure} : b \in BOOLEAN
                 /\ receivedRows \in Seq(1..MaxRows) /\ deliveredRows \in Seq(1..MaxRows)
ExactOccurrences == /\ Len(receivedRows) <= total
                    /\ receivedRows = Rows(0, Len(receivedRows))
                    /\ deliveredRows = Rows(0, Len(deliveredRows))
                    /\ Len(receivedRows) = s.received /\ Len(deliveredRows) = s.delivered
CompleteCoverage == s.outcome = "complete" =>
                    (receivedRows = Rows(0, total) /\ s.terminal = total)
AuthorizedDisclosure == disclosure
=============================================================================

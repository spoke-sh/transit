-------------------------- MODULE WriteTokens --------------------------
EXTENDS Naturals, Sequences, FiniteSets
\* Two concurrent submissions, two accounts/Tables/tokens/fingerprints.
\* Profiles fix their relationship; schedules explore either winning first.
CONSTANTS Account2, Token2, Table2, Fingerprint2, CheckScope,
          CheckFingerprint, CheckBinding, CheckRecovery, CheckAccount
VARIABLES directory, replies, names, retained, last
vars == <<directory, replies, names, retained, last>>
Requests == <<[account |-> 1, token |-> 1, table |-> 1, fingerprint |-> 1],
              [account |-> Account2, token |-> Token2, table |-> Table2, fingerprint |-> Fingerprint2]>>
Key(i) == <<Requests[i].account, Requests[i].token>>
Same(i,j) == Key(i) = Key(j)
Matches(i,j) == Requests[i].fingerprint = Requests[j].fingerprint /\ Requests[i].table = Requests[j].table
Init == /\ directory = <<>> /\ replies = <<0,0>> /\ names = <<1, Table2>>
        /\ retained = TRUE /\ last = "Init"
Submit(i) ==
    LET matches == {j \in 1..Len(directory) :
                      IF ~CheckAccount THEN Requests[i].token = Requests[directory[j].caller].token
                      ELSE IF CheckScope THEN Same(i,directory[j].caller)
                      ELSE Same(i,directory[j].caller) /\ Requests[i].table = Requests[directory[j].caller].table}
        known == IF matches = {} THEN 0 ELSE CHOOSE j \in matches : TRUE
        original == IF known = 0 THEN i ELSE directory[known].caller
        conflict == known # 0 /\ ~Matches(i,original)
    IN /\ replies[i] = 0
       /\ directory' = IF known # 0 THEN directory ELSE Append(directory,
               [caller |-> i, table |-> IF CheckBinding THEN Requests[i].table ELSE names[i]])
       /\ replies' = [replies EXCEPT ![i] = IF conflict /\ CheckFingerprint THEN 3 ELSE original]
       /\ UNCHANGED <<names, retained>>
       /\ last' = IF i = 1 THEN "Submit1" ELSE "Submit2"
LoseReply(i) == /\ replies' = [replies EXCEPT ![i] = 0]
                /\ UNCHANGED <<directory, names, retained>>
                /\ last' = IF i = 1 THEN "LoseReply1" ELSE "LoseReply2"
Rebind == /\ names # <<2,1>> /\ names' = <<2,1>>
          /\ UNCHANGED <<directory, replies, retained>> /\ last' = "Rebind"
Recover == /\ directory' = IF CheckRecovery THEN directory ELSE <<>>
           /\ retained' = (retained /\ (CheckRecovery \/ Len(directory) = 0))
           /\ UNCHANGED <<replies, names>> /\ last' = "Recover"
Next == (\E i \in 1..2 : Submit(i) \/ LoseReply(i)) \/ Rebind \/ Recover
Spec == Init /\ [][Next]_vars
TypeOK == /\ Len(directory) <= 2 /\ replies \in [1..2 -> 0..3]
          /\ \A j \in 1..Len(directory) : directory[j].caller \in 1..2 /\ directory[j].table \in 1..2
AccountTokenUnique == \A j,k \in 1..Len(directory) :
    Same(directory[j].caller,directory[k].caller) => j = k
FingerprintConflict == \A i \in 1..2 : replies[i] \in {1,2} => Matches(i,replies[i])
AccountIsolation == \A i \in 1..2 : replies[i] \in {1,2} => Same(i,replies[i])
FrozenObject == \A j \in 1..Len(directory) : directory[j].table = Requests[directory[j].caller].table
RetainedIdentity == retained
=============================================================================

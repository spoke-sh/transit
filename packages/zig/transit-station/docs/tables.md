# Tables and finite Arrow replies

The [Table profile](../../../../contracts/FUZE_V1.md) defines the two-column
schema and operator matrix. `Table.create/open`, typed insert/update/upsert/delete,
get and scan operate on a private `Turn`. `Table.atomic` restores the entire
proposal on failure, including a cross-resource or distinct-key budget error.
It never splits a transaction. Queries select a committed snapshot; querying
after private mutations is rejected. Commit changes and query on a later input.

Descriptors use key `00 t <table:u32le>` and `TBL1`, value-type byte, then two
length-prefixed column names. Rows use `00 r <table:u32le> <key:u64be>`, where
the signed key's high bit is flipped to preserve numeric order. Values start
with version 1 and a non-null byte; the body is i64le, a boolean byte or variable
UTF-8/binary bytes. Null has no body. Every decode validates type and length.

`Query.setPolicy` is a trusted handler operation. The example only accepts policy
changes from authority-derived root-principal origin. The durable per-peer policy
allows one Table, has a conditional revision and explicitly permits copying
results to that peer. No send grant or resource association implies this right.

`Query.capture` requires a process-origin call. It evaluates Fuze in a 1 MiB
bounded workspace and copies at most **672 IPC bytes** into up to three 224-byte
state values plus a manifest. The query input, capture and self-continuation
commit together. Four mutations and one output fit the existing kernel profile.
The result identity is the writer's consumed input position; it fixes source
resource/revision, schema fingerprint, destination, correlation, policy revision,
row/byte counts and SHA-256. Oversize, allocation or query errors publish no
capture; the application can return a recorded failure reply.

On continuation, Station reads those retained bytes, rechecks policy and digest,
and commits up to three fragments plus completion with the manifest's progress.
It never holds the old view or reevaluates against new rows. A revoked or revised
policy closes publication with a denied reply. Already published copies cannot
be recalled by changing the source grant. `published` means outbox intents exist;
`acknowledged` requires the receiver's authenticated completion acknowledgement.
Neither phase deletes history or result keys.

Receivers store bounded fragments under their existing wait's correlation. They
validate the source PID, result identity, ordinals, exact sizes, SHA-256 and finite
Arrow schema/batch/end marker. Decoding has a fixed arena. Completion closes the
wait, retains its manifest and sends acknowledgement in one turn. Application
code runs only after this verification; it can use `Query.completed` to read
the finite bytes. Duplicate identical fragments are inert; conflicting or
incomplete results fail without partial success. A closed wait never reopens.

Framework keys are `00 q <result:u64le> <slot:u8>` at the producer (manifest slot
0, fragments 1–3), `00 i <correlation:u64le> <slot:u8>` at the consumer (fragments
0–2, manifest 3), and `00 a <peer:u64le> 00` for query policy. All consume the same
32-key resource budget as rows, schemas and waits. Result retention defaults to
unlimited; callers eventually receive capacity errors unless they explicitly
choose and implement a reclamation policy. [Wait closure](services.md#waiting-and-time)
handles cancellation and timeout; process/resource expiry retains its kernel meaning.

`just test::station` exercises actual writer/requester hosts, capture/publication
and receiver restarts, independent PyArrow consumption, denied requests and
revocation before publication. `just test::arrow` checks Fuze's full admitted
type matrix with an independent Arrow reader. Unit tests cover private rollback,
forged/duplicate/truncated/conflicting fragments, nulls, overflow and bounds.

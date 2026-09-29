# Station Document v1

The Document format defines structured changes, merge rules and accepted-state
reads above Station. [Documents](../docs/reference/documents.md) explains the model;
[the package](../packages/zig/transit-station-document/README.md) describes usage.
External CRDT wire formats are unsupported.

## Identity and changes

A Document has a nonzero u64 identity scoped by its resource, nonzero u64 merge
epoch, nonzero u32 type revision and u64 accepted revision. Its root is a map.
Replica IDs are nonzero u64s independent of Transit PID, activation and ownership.
An operation dot is `(counter:u64, replica:u64)`; `(0,0)` denotes the root/sequence
start only. Ordering compares counter, then replica. Counters are logical, never
wall-clock timestamps. Object and element IDs are their creation operation dots.
Objects cannot move, reparent or form cycles.

`SDC1` starts a canonical change: document:u64, epoch:u64, type_revision:u32,
replica:u64, previous_accepted_counter:u64, first_counter:u64, operation_count:u8,
then operations. All integers are little endian. There are 1–8 operations with
consecutive counters starting at `first_counter`. The first counter must exceed
the previous counter; every referenced dot must have a strictly lower counter
than its referencing operation. A previous counter of zero starts a replica.
Accepted changes advance that replica's frontier to their final counter.
Canonical encoded changes are bounded by 4096 bytes; trailing bytes reject.

Every operation begins with a u8 tag and object dot (counter, replica). The
remaining fields are ordered as below:

| Tag | Operation | Fields after object |
| --- | --- | --- |
| 0 | Assign map field | field, observed assignments, scalar |
| 1 | Remove map field | field, observed assignments |
| 2 | Insert list/text element | predecessor dot, scalar |
| 3 | Assign list element | element dot, observed assignments, scalar |
| 4 | Delete list/text element | element dot |

A field is length:u8 plus 1–64 valid UTF-8 bytes. Names are not normalized.
Observed assignments are count:u8 and at most eight dots, strictly ascending and
unique. They must be accepted assignments to that exact field/element; names,
IDs and causal knowledge never grant authority. Missing predecessors, objects,
assignments or replica predecessors reject as dependency missing, without
advancing a frontier. There is no implicit pending queue. Resubmission is explicit.
A dot reused with different canonical change content is an identity conflict.
An exact duplicate returns its original accepted revision without another change.

Scalars use a u8 tag: 0 null; 1 boolean (u8, exactly zero or one); 2 i64; 3 u64;
4 finite IEEE754 f64 bits; 5 UTF-8 string; 6 binary; 7 new map; 8 new list;
9 new editable text; 10 Unicode scalar value (u32). Strings/binary contain a u8
length and at most 96 bytes. Empty strings/binary differ from null. Strings do
not acquire editable sequence semantics. Non-finite numbers, invalid UTF-8,
surrogates and codepoints above U+10FFFF reject. No normalization or grapheme
indexing occurs. Tag 10 is used only by text insert; text cannot use list set.

## Merge and visibility

A map field/list value is an observed-remove multi-value register. An assignment
removes only its explicitly observed assignments and introduces its own dot.
Concurrent unseen assignments remain visible conflicts. Removal does not imply
knowledge of all concurrent edits. Up to eight unresolved values per register
are supported; exceeding that explicit work quota rejects the candidate without
expiring accepted evidence. Resolution is another assignment naming the conflicts.
Capacity may affect which changes can be accepted, so convergence is claimed only
for the same accepted set, not arbitrary rejected submissions.

Removing an object assignment detaches that object. Concurrent child edits remain
in accepted history but cannot restore the removed parent. A concurrent unseen
parent assignment remains visible. Objects are created with immutable identities;
replacing a map/list/text value creates a distinct object.

Lists/text use predecessor edges and descending sibling-dot order. Deleting an
element permanently hides its value but preserves the anchor and descendants.
Inserting after a deleted anchor is supported. List set/delete races retain their
causal evidence while deletion wins element visibility. Sequence traversal uses
bounded transitions and an explicit continuation, including backtracking and
skipped deleted elements; a progress-only response is not EOF.

## Storage and bounded reads

The accepted Document snapshot contains its exact document/epoch/type/revision
and [immutable index root](STATION_INDEX_V1.md). Candidate construction may stage
many nodes; only a fenced final head decision accepts the whole change together
with input progress and outputs. Intermediate nodes and failed candidates never
replace the accepted root. The owner must durably reserve candidate IDs, preserve
exact signed uncertainty, and disposition unreachable candidates separately.

The index stores immutable assignment records, per-field live assignment sets,
object kinds, sequence edges/elements, replica frontiers and change digests with
original accepted revision. It is not a whole-document buffer. Per-change work,
per-field conflicts, scalar bytes, node fanout and traversal depth are bounded;
total accepted history and sequence size are not fixed-cardinality arrays.
Retention is unlimited by default. This format alone does not authorize trimming
causal records or forgetting tombstones. Epoch advancement, checkpoints and
physical cleanup require the owning service's explicit policy and evidence.

`field` and bounded map `path` reads distinguish missing, explicit null, scalar,
object and unresolved conflict. Traversing through a scalar/null raises a type
error. Conflict alternatives include stable assignment dots. Sequence reads
return stable element IDs with those same value distinctions. Every read uses
one exact snapshot and currently authorized source; source loss, corruption and
revocation are errors, never empty data. Immutable references grant neither
access nor continued availability. Direct object-ID reads can inspect detached
accepted history; visible path traversal cannot resurrect it.

## Durable publication profile

The `Service` component fixes one resource and a Publication namespace equal to
Document ID. It owns a permanent head, revision snapshots, job ledgers and
exclusive monotonically allocated record intervals. One active job is supported;
its explicit node quota is independent of total accepted history. `prepare`
freezes the exact canonical request commitment before upload. Changed job content
rejects, and no admitted prefix counts as Document acceptance.

Request format `0x53444301` covers the canonical SDC1 bytes. Candidate index nodes
use SIX1. The final head and per-revision snapshot bind the complete index root;
acceptance also records the job outcome, using three ordinary mutations. Input
progress and any success output belong to this same fenced decision. A maximum
head uses 252 bytes, without widening the 256-byte value. A discarded proposal
cannot publish the head; an uncertain commit uses Station's exact signed retry
or fresh ownership and recorded recovery.

Snapshots retain causal records and the replica clock/frontier. Service reads
reopen a revision using a current source and return at most eight sequence items
per 32 traversal transitions. Progress-only pages are explicit. A fresh
resynchronization basis names the epoch, revision, replica predecessor and logical
clock; it does not authorize blind replay of tentative edits. Permanent retirement
blocks old snapshot reads and new work even while bytes remain.

Rejected jobs have permanently closed intervals. Their independent cleanup may
reclaim that interval's unreachable nodes/request, with at most one bounded
Publication operation per turn. Accepted job intervals and snapshots stay retained
until an explicit checkpoint/lifetime policy permits their disposition. Capacity
failure never chooses that policy. Disk and checkpoint recovery evidence is in
the [test guide](../tests/README.md), alongside separate local two-client,
Compose and reference placement proofs. Private-turn tests alone do not establish those properties.

## Checkpoints and finite merge windows

Checkpoint construction copies one bounded index entry/path at a time to a new
root. Its durable cursor and candidate root are separate from the visible head.
The per-entry 65-node reservation derives from the index's 32-level bound; the
number of entries/history records is not a resident array or a total checkpoint
quota. Final publication advances the accepted revision atomically with its root,
job outcome, epoch and read floor. Candidate rejection has independent bounded
reclamation and cannot affect accepted roots.

An explicit finite window N retains the N newest revisions including a completed
checkpoint; zero means unlimited future retention. Its proposed floor is the
maximum of the existing floor and `checkpoint_revision - N + 1`, when nonnegative.
Only a completed checkpoint may advance the floor. Advancing it also advances
the merge epoch. Stale-epoch edits require authorized resynchronization; copied
replica frontiers reject recycled counters. Setting unlimited policy later never
recreates unavailable history. Checkpoint revisions count in this finite window.

Unlimited checkpoints preserve all causal/deduplication records. On epoch
advancement, obsolete register assignments and duplicate-change records below
the floor may be omitted from the new index. Object IDs, replica frontiers,
logical clocks, sequence edges and deletion anchors remain. This deliberately
conservative profile does not erase detached object trees or sequence tombstones.

SDS2 snapshots add a u64 request ID to their exact Document root; zero denotes a
checkpoint/initial boundary. Existing SDS1 roots remain readable with no tail
request. Accepted tail requests remain immutable Publication records. Public
reads reject revisions below the current floor and recheck current grants.
Physical bytes shared by retained roots stay intact: live reachability collection
is not implemented. Accepted job/checkpoint intervals can be reclaimed after
permanent logical Document retirement, using bounded Publication cleanup while
keeping permanent ledgers. Logical history closure, checkpoint compaction and
physical removal remain distinct.

## Public reader reference

SDR1 is a 40-byte reference: magic, resource:u64, document:u64, epoch:u64,
type_revision:u32, accepted_revision:u64, with little-endian integers. Resource
uses the kernel ID range; Document and revisions preserve full u64 width. Unknown
magic, extra/truncated bytes, zero identities or a mismatched epoch/type/revision
reject. References do not require or confer writer ownership.

The public Client opens a current resource cut for each bounded operation and
checks the referenced accepted snapshot plus live floor/retirement. It returns
that source cut with owned path/sequence values. Resource change/loss, revocation,
type mismatch and missing history stay explicit; it never substitutes another
Document revision. Its ResourceReader poisons a source after failed authority
reads. Language bindings must preserve the same identities, state distinctions
and continuation ownership through the shared Zig implementation.

Value-free register metadata scans at most eight accepted register records per
page. It returns counts of registers, live assignment IDs and conflicting
registers, plus an ordered continuation. These are page counts over an exact
accepted snapshot; detached objects and deleted-element history are included.
They are not visible application field counts or whole-Document statistics.
An empty final page is valid. Consumers keep the same SDR1 reference throughout
a scan, rechecking current grants, history floor and retirement on each page.
Malformed register keys, unordered IDs and invalid continuations reject. The
metadata reader never decodes or returns scalar/text values. Its internal
continuation may contain an opaque register key and must not be treated as a
user-facing field name or authority token.

The shared host codec preserves u64/i64 values as canonical decimal strings and
binary as hex. A finite float64 uses `float_bits`, exactly eight little-endian IEEE
bytes encoded as 16 hex characters, preserving negative zero across JSON hosts.
Host `character` is a UTF-8 string containing exactly one Unicode scalar. These
are binding values: SDC1 remains the canonical binary change, and language-native
public APIs own their idiomatic numeric, string and byte types. Host codecs share
Zig validation and implement no independent merge algorithm.

## Authenticated submission profile

Remote submission uses an authenticated Station call. A caller publishes one
canonical SDC1 change as Publication record 1 in a dedicated caller namespace.
It sends an STN1 `call` carrying SDQ1, a 96-byte reference with these ordered,
little-endian fields: magic, resource:u64, namespace:u64, document:u64, epoch:u64,
type_revision:u32, replica:u64, policy_revision:u64, format:u32, length:u32,
digest:32 bytes. Format must be `0x53444301`; length is 1–4096 bytes. Identity and
policy fields are nonzero; resource uses the kernel ID range. The complete STN1
request is 109 bytes. No mailbox or KV limit changes.

The writer uses the authenticated process origin, never a payload PID. Explicit
current service policy binds that caller PID to its request resource, replica
and policy revision for the selected Document. Both the reference and decoded
change must match. Resource grants remain separate: the writer needs current
read access to the caller's publication and current mutation rights to its own
Document resource. Replica identity alone cannot impersonate another caller.
Every publication chunk rechecks current access and immutable spec; later
building steps recheck publication availability and service policy. Read outages
or policy loss leave work recoverable, without inventing an accepted outcome.

Admission freezes the original writer PID, caller PID, input position,
correlation and SDQ1 bytes in a 132-byte SDT1 route. Its job ID is the input
position with bit 63 set; that range is reserved for remote jobs. Admission uses
three mutations (job, head, route), leaving one framework mutation. There is one
active candidate per Document. Busy or invalid submissions receive an explicit
correlated rejection; they are not held in an implicit pending queue. Publishing
caller bytes or admitting a job does not accept a Document change.

Progress reconstructs the recorded job and route under fresh ownership of the
same writer PID. Final accepted state, job outcome and success reply share one
fenced turn, with at most three Document mutations plus framework state. No
later tick sends another success for a completed job. A distinct call containing
the same canonical change may receive its original accepted revision through
the CRDT's duplicate contract. Uncertain commits retain exact signed bytes.
Replacement PIDs or renamed services cannot retarget the recorded route.

SDO1 is a 54-byte reply: magic, status:u8, reason:u8, job:u64, basis:40-byte SDR1
or forty zero bytes for no basis. Denied and malformed requests receive no basis,
so they cannot inspect accepted state through a rejected call.
Status is 1 accepted, 2 duplicate, or 3 rejected. Reasons are 0 none, 1 invalid
request, 2 denied, 3 busy, 4 invalid change, 5 dependency missing/wrong dependency,
6 identity conflict, 7 resynchronization required, 8 capacity, 9 retired, and
10 type mismatch. Accepted/duplicate require reason zero, a nonzero job and a
nonzero accepted revision. Rejection requires a nonzero reason; job zero means
no job was admitted. Its basis names the current accepted Document, not a
partially applied candidate. Unknown enum values and malformed frames reject.
The caller verifies reply origin and durable correlation before recording it.
Neither a success reference nor a rejection basis promises continued availability.

The caller's private SDW1 record is 124 bytes: magic, writer_pid:u64,
writer_resource:u64, correlation:u64 and the original 96-byte SDQ1. Its call,
Station wait record and original destination commit together. The received SDO1
is stored unchanged only after validating process origin, correlation and any
returned resource/Document basis. A new call after semantic rejection requires
an explicit new publication namespace; changing a configured name cannot reroute
an already recorded call.

Terminal candidate rejection closes the recorded interval and sends its reply
in one turn. Cleanup remains a separate bounded operation. Infrastructure,
corruption and authorization errors are not silently converted to domain
rejections. An administrator may explicitly reject blocked work under current
authority; capacity never authorizes retirement, expiry or arbitrary cleanup.

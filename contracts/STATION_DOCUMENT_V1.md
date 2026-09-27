# Station Document v1

Status: M17 component implementation and merge tests; durable service, SDK and
placement qualification are in progress. This is a Station format, not a kernel
command. [Documents](../docs/DOCUMENTS.md) owns the model and
[the package](../packages/zig/transit-station-document/README.md) owns usage.
No external CRDT wire compatibility is implied.

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

# Documents and collaborative text

`DocumentChange` and its operations describe tentative edits. `prepare_document`
uses the shared Zig codec to validate/canonicalize them; it does not grant access
or accept them. Replica IDs are stable application identities, independent of a
Transit PID or ownership generation. Dot counters and IDs are Python integers
with explicit uint64 bounds. `DocumentUnsigned` distinguishes unsigned scalars
from signed `int`; finite `float` preserves negative zero. `None` is explicit null,
`bytes` is binary, and replacement `str` is distinct from `DocumentKind.TEXT`.

```python
from transit_station import (
    DocumentChange, DocumentAssign, DocumentInsert, DocumentKind,
    DocumentDot, DocumentCharacter, prepare_document,
)

prepared = prepare_document(DocumentChange(
    document=42, epoch=1, replica=7, first=1,
    operations=(
        DocumentAssign("body", DocumentKind.TEXT),
        DocumentInsert(DocumentDot(1, 7), DocumentCharacter("🙂")),
    ),
))
```

An insert contributes exactly one Unicode scalar, not a byte, UTF-16 code unit or
grapheme. Names/strings use UTF-8 byte limits. Use stable element IDs for insert,
set and delete; observed assignment IDs explicitly resolve concurrent fields.
See the [shared contract](../../../../contracts/STATION_DOCUMENT_V1.md) for the
supported causal ordering and merge profile. Python implements no CRDT algorithm.

Inside a fenced writer handler, `turn.document(42)` returns a scoped owner.
`create()` fixes explicit publication quotas, defaulting to 4096-byte records,
8192 staged bytes and two staged records. `stage(job, prepared, node_limit=256)`
performs **one** bounded preparation/upload/materialization step per turn. The
caller chooses a node budget appropriate to its change and durably schedules
further turns with the same job ID and canonical bytes. A prepared change can
exceed one mailbox frame; this owner API does not implicitly send it to a remote
writer. Authenticate application routing before invoking it.

The returned `DocumentProgress` is private until the enclosing runner reports
`Committed`. `PROGRESS` publishes no accepted Document revision. `ACCEPTED` or
`DUPLICATE` names the exact accepted revision proposed by this turn; duplicate
changes preserve their original revision. Save/retry uncertain signed envelopes
or replace the owner under fresh fencing using the normal runner recovery model.
Never report durable acceptance from a handler field alone.

`checkpoint(job)` incrementally copies accepted state. `merge_window(0)` preserves
unlimited future history; positive values opt into a finite history window at
checkpoint publication. `reject`, `collect` and `retire` expose explicit durable
lifecycle operations. Collection is one bounded step. Retirement is permanent;
physical cleanup does not undo it. These owner objects expire with their turn,
including on a failed handler or attempted use from another thread.

`runner.documents` reads independently of execution ownership under the configured
principal's current inspect/read grants. A read-only consumer can use this surface
without polling a writer turn. `describe(resource, id)` returns an exact
`DocumentReference`, live floor/window and the current resource cut. `path(ref,
("body",))` preserves missing/null/object/scalar/conflict states; invalid
intermediate types fail. Field assignments include their IDs for explicit
resolution. `sequence(ref, object_id, cursor)` returns at most eight items and
bounded traversal work; an empty page with a continuation is not EOF. Every page
keeps the exact accepted revision, rechecks current availability, and may name a
newer resource cut without changing its values.

`resynchronize` supplies the accepted replica predecessor and logical clock.
Reconcile pending edits explicitly; it never replays stale changes for you.
`accepted_change` reads a verified retained tail change and reports checkpoint
boundaries explicitly. `DocumentReference.encode/decode` uses the shared SDR1
codec; possession of its bytes never authorizes a read.

`AsyncRunner.documents` exposes the same owned values with awaited reads. Cancelling
a wait does not cancel a durable change, retire a Document or free native work
still executing. `aclose()` joins that work. Both runners reject reads while an
uncertain mutation needs resolution. No hidden whole-document buffer or native
cursor survives a call.

`just bindings::document-python` builds wheels, installs a clean external consumer
and qualifies codecs, independent Unicode/full-width fixtures, scoped turns,
checkpoint creation, mid-upload host loss, duplicate acceptance, retained reads,
conflicts, read revocation, retirement and joined asynchronous destruction.

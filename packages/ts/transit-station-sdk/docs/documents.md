# Documents and collaborative text

`prepareDocument` validates tentative typed changes through shared Zig. Use
`bigint` for Document/replica/counter/revision identities and signed/unsigned
scalars; resources retain Transit's safe-integer bound. `DocumentValue` distinguishes
null, object kinds, replacement strings, binary arrays, finite float64 and single
Unicode scalar characters. Negative zero survives canonical encoding.

```typescript
import { prepareDocument } from "@transit/station";

const change = await prepareDocument({
  document: 42n, epoch: 1n, replica: 7n, first: 1n,
  operations: [
    { kind: "assign", field: "body", value: { kind: "text" } },
    { kind: "insert", object: { counter: 1n, replica: 7n },
      value: { kind: "character", value: "🙂" } },
  ],
});
```

Preparation copies inputs before awaiting native work. Prepared byte getters return
copies. `decodeDocument` and `DocumentReference.decode` use the shared versioned
codec; no CRDT or reference encoding is reimplemented in TypeScript. Stable object
and element IDs, observed assignments and supported causal delivery follow the
[shared Document contract](../../../../contracts/STATION_DOCUMENT_V1.md).

Inside a handler, `turn.document(42n)` returns a scoped owner. Await `create()` to
fix publication quotas, then `stage(job, change, nodeLimit)` to perform one bounded
step per turn. Preserve the same job ID and bytes through application scheduling
and recovery. The returned phase/revision is a private proposal until the runner
reports `committed`; preparation, progress and a dropped promise are not durable
acceptance. An unawaited Document operation prevents successful turn completion,
even if its native work finishes before the handler returns.

`checkpoint`, `mergeWindow`, `reject`, `collect` and `retire` compose the same
scoped writer. Default retention is unlimited. Finite windows advance only when a
checkpoint publishes; retirement is permanent and physical collection is separate.
All helpers retain the existing mutation/output and native lifetime bounds.
The owner API does not route large change bodies through an ordinary mailbox
frame. A remote writer requires authenticated application routing and durable
publication references.

`runner.documents.describe(resource, id)` supplies an exact accepted reference,
current resource cut and retained floor/window. Its principal needs current
resource inspect/read permission; execution ownership is unnecessary for reads.
`path(reference, names)` returns missing/null/scalar/object/conflict states with
owned assignment IDs. Wrong intermediate types fail explicitly. `sequence` returns
at most eight items plus an optional cursor; empty continuation pages are not EOF.
Keep the exact reference across pages. Fresh authorization may name a newer
resource cut while retained values remain the same.

`acceptedChange` exposes a verified retained tail entry or checkpoint-boundary
failure. `resynchronize` supplies accepted replica/clock facts; the application
reconciles pending edits explicitly. References and cursors never grant authority.
Reads are serialized through the runner and refuse pending uncertain mutations.
Closing the runner joins work and invalidates saved reader objects; it does not
cancel a durable change or retire its Document.

`just bindings::document-node` installs clean tarball consumers and qualifies
shared codec/Unicode/reference fixtures, scoped checkpoints/changes, host loss
mid-upload, duplicates, conflict/text reads, current revocation and retirement.
Runtime native boundary schemas are validated before public values are returned.

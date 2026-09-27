# Documents

The growing-profile SDK exposes Station Documents through the shared Zig
implementation. It provides owned values and bounded reads; it does not merge
changes in Rust. Document, replica and operation identities use full-width u64
values and remain independent of a process or activation.

Construct a `DocumentChange` with one to eight `DocumentOperation` values and
call `prepare_document`. Its immutable `PreparedDocumentChange` owns the canonical
SDC1 bytes. `decode_document` returns native Rust values through the same codec.
`DocumentValue` distinguishes null, signed/unsigned integers, finite floats,
strings, binary, map/list/text creation and a Unicode scalar `char`. Text sequence
positions are stable `DocumentDot` identities, not UTF-8 or UTF-16 offsets.

In a handler, `turn.document(id)?` borrows the turn exclusively. `create` sets
explicit publication quotas. `stage(job, &prepared, node_limit)` advances one
bounded durable publication step; repeat with the same job and bytes in later
turns until acceptance. Progress is private until the runner reports a committed
turn. Preserve a job's identity across recovery; changed content under that
identity rejects. Checkpoint, merge-window, rejection, collection and retirement
methods retain the same scoped boundary. Unlimited retention is the default;
finite windows are explicit and retirement is permanent.

Between handler turns, `runner.documents()?` borrows the runner exclusively.
`describe` returns an exact `DocumentReference` and current source revision.
`path` preserves missing/null/type-error/conflict states; field assignments and
sequence pages own their values. Each sequence page contains at most eight items
and an optional continuation. `accepted_change` retrieves a verified retained
change; `resynchronize` returns the accepted reference, replica predecessor and
logical clock. Resynchronization does not replay stale edits automatically.

References identify accepted values, never grant access. Every read checks current
resource policy, lifetime and the Document's retained floor. Older references can
continue returning their original values while their resource source cut advances.
A reader cannot overlap runner mutation or close because it holds `&mut Runner`.
Dropping it releases that borrow; owned returned values survive runner destruction.
For asynchronous hosts, keep the runner on its owning worker and join that worker
before disposal. The SDK does not claim arbitrary thread cancellation is safe.

`just bindings::document-rust` installs packaged crates in a clean external
consumer, checks rejected owner/reader lifetimes, and runs shared codec/Unicode
fixtures plus the disk-backed recovery/read-authority schedule. See the
[qualification evidence](../../../../tests/README.md#m17-work-in-progress).

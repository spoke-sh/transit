# Documents

The growing-profile C11 interface exposes typed changes, scoped publication jobs
and current-policy reads over the shared Zig Document implementation. Replica,
Document and operation identities are full-width `uint64_t` values, independent
of PID and activation. The header declares every resident bound: eight operations
per change, eight conflict assignments, eight sequence items, 64-byte field names,
96-byte scalar values and 1,024-byte continuations. No collection's total durable
size determines a host allocation.

Fill a `transit_station_document_change` and call
`transit_station_document_prepare`. The returned opaque prepared handle owns its
canonical SDC1 bytes; `transit_station_document_prepared_bytes` borrows them until
`transit_station_document_prepared_destroy`. `transit_station_document_decode`
returns a copied change. Scalars distinguish signed and unsigned integers, finite
IEEE doubles (including negative zero), null, UTF-8 strings, binary, map/list/text
creation and one UTF-8 Unicode scalar. Sequence edits use stable element dots,
not character offsets or UTF-16 units. The shared codec validates all encodings.

`transit_station_turn_document_create` configures explicit publication quotas.
`transit_station_turn_document_stage` advances one bounded step of a job; repeat
with the same job and prepared bytes in later handler turns. Checkpoint, merge
window, rejection, collection and retirement helpers share this scope. Progress
is private until the runner commits. A lost host must recover with the exact
retained mutation or fresh ownership. Reusing a job identity with changed bytes
rejects; a duplicate accepted change preserves its original revision.

`transit_station_documents_open` returns a reader that retains a local runner
handle. Destroy it with `transit_station_document_reader_destroy`. The reader
holds no remote cursor slot: continuations are copied, bounded values bound to an
accepted reference. Each call uses the runner's serialized worker and refuses a
pending mutation. Results are copied structs and survive reader/runner destruction.
A caller owns those structs and must not destroy a reader while another thread
is using that same pointer. Runner close joins admitted work; later reader calls
return `CLOSED`, including after the original runner handle is destroyed.

Describe returns the exact accepted reference, source resource revision, retained
floor, configured window, active job and retirement status. Path reads distinguish
missing, null, scalar, object and explicit multi-assignment conflict; traversing an
incompatible type fails. Sequence reads return at most eight owned items and an
optional continuation. Accepted-change and resynchronization reads expose verified
retained bytes and replica predecessor/clock evidence. References do not grant
access: every request checks current policy, resource lifetime, retained floor
and permanent Document retirement. Unlimited retention remains the default.

Run `just bindings::document-c` for separately compiled installed C11 and C++17
consumers over the shared disk-backed schedule. See the
[proof evidence](../../../../tests/README.md#m17-work-in-progress).

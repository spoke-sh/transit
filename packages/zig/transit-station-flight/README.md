# transit-station-flight

M22's finite outbound adapter constructs standard
Flight RPC requests for the existing `transit-station-grpc` recorded effect
boundary; it has no sockets, credentials, retries or separate persistence.
`Call.prepare` returns the ordinary `RequestRecord` for resumable publication and
authorized dispatch. Credential metadata remains immutable secret references.

`Replay` reads captured `DoGet` messages through M16's current-availability and
complete-transcript checks. Schema and batch events are provisional until the
explicit complete event. It reconstructs bounded standard IPC with one schema,
one message and one batch buffer, plus caller-owned Arrow workspace. The initial
remote schema profile is one or two int64 columns; other schemas fail explicitly.
Captured bytes and RPC success do not prove honest remote computation.

`just test::flight-outbound` passes a pinned independent PyArrow Flight service
over verified TLS through the actual recorded RPC worker. Six batches preserve
all 41 full-width int64/null rows. The proof stops the peer, removes the credential,
restarts node/disk store and checks typed replay without another remote call.
No inbound query permission authorizes an outbound call, and replay never dispatches.

The constructed request borrows the caller's message buffer and metadata entries;
keep them alive through `Call.prepare` and upload the resulting ordinary GRQ1
reference through M16's publication/admission path. No automatic retry policy is
introduced: an unknown remote outcome stays unknown until an explicit authorized
M16 reconciliation. A returned schema or batch is not complete-result evidence.

Use at least 8 MiB plus 64 KiB of caller-owned workspace for the qualified decoder.
Its fixed schema/message/IPC buffers total 40 KiB, in addition to M16's fixed replay
validator. Every bounded transcript read rechecks current resource availability.
Call `next` until `.complete`; discard provisional output on any error. Slices
borrow the replay object until its next call. Non-OK remote status, malformed IPC,
unsupported types and incomplete/omitted transcripts fail explicitly.

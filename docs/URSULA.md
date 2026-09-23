# Ursula integration

Status: Ursula 0.5.1 and its matching `ursulactl` CLI are pinned in the dev shell
through [ursula-overlay](https://github.com/rupurt/ursula-overlay). `flake.lock`
records the overlay revision. [ursula-zig](https://github.com/rupurt/ursula-zig)
is the selected Zig client, pinned by revision and package hash in
`packages/zig/transit-ursula/build.zig.zon`.

Container deployments use the [official Ursula image](https://github.com/tonbo-io/ursula/pkgs/container/ursula),
not a separately built Nix image. The matching `0.5.1` release and immutable
multi-platform manifest digest are pinned in
[`deploy/reference/versions.json`](../deploy/reference/versions.json). Update this
pin deliberately alongside the development overlay and rerun disk recovery
checks. Supply an explicit disk-backed configuration and persistent volume;
the upstream image's bundled configuration uses an in-memory WAL.

## Implemented authority experiment

`just test-storage` uses the pinned client against an isolated Ursula 0.5.1
single-node disk WAL. JSON `Stream-Record-Match` compares the current record tail
and appends one object atomically; a conflicting proposal returns `412`. The
adapter rejects arrays, malformed objects, and oversized records. It reads at
most 16 records per page and does not silently recreate missing history.

The test discards an append receipt, rejects its retry at the original position,
and verifies history after SIGKILL/restart. The kernel proof additionally
publishes a validated checkpoint, interrupts maintenance, retries trim, and
recovers the same PID/grants/state plus pending tail after another SIGKILL.
This proves the storage primitive on
this topology, not Transit authorization, multi-node availability, or host/disk
loss tolerance. Protocol operation identities must still resolve uncertain writes
by reading the accepted record; a transport success alone is not that resolution.

Use `ursula server --config FILE` without `--preset default`. The explicit default
preset selects the in-memory runtime for a peerless node even when the config
sets a disk WAL. The initial crash experiment reproduced data loss with that
combination; removing the preset selects the Raft/disk path. See
[the pinned startup implementation](https://github.com/tonbo-io/ursula/blob/v0.5.1/crates/ursula/src/server.rs).

The initial Transit authority will use one realm journal for policy and process
operations. Conditional append orders both without cross-stream transactions.
Catch-up reads are bounded historical reads; a fresh `HEAD` supplies a required
tail, and mutation acceptance always uses record-tail comparison. Current-policy
read authorization will need its own conditional barrier before disclosure.
Redirects currently fail closed; multi-node routing remains unproved.

The transport notes below were researched against upstream v0.5.0 docs on
2026-09-21; retention and security mappings also reference v0.5.1 source
documentation.
M1 must validate both against the pinned server and client. Current tooling
checks cover CLI execution, not stream or recovery behavior. See
[development](DEVELOPMENT.md) for commands and updates.

## Boundary

Use [Ursula](https://ursula.tonbo.io/) for stream storage and transport. This is
an established project choice; the first milestone integrates Ursula and
validates its behavior against Rey's requirements. Performance and recovery
guarantees still need evidence from that integration.

Use `ursula-zig` in Rey's trusted transport integration, following the authority
and language boundaries in [ARCHITECTURE.md](ARCHITECTURE.md). Process handlers use
the Transit/Station API; they do not receive raw authoritative stream-write
access. The library supplies typed HTTP operations, response metadata, streaming
exchanges, and an incremental SSE decoder. Reusing it keeps protocol handling
in one upstream implementation.
Rey's integration layer implements the kernel's transport requirements around
that library. Ursula provides persistence and transport; legal execution is
defined by [Transit, the kernel](TRANSIT.md). The proposed `transit-ursula`
library owns this transport integration; see the
[decomposition plan](ARCHITECTURE.md#planned-monorepo-decomposition).
Transit defines logical stream identity, lifetime, and retained-boundary
semantics independently of this adapter. Native Ursula retention mechanisms
must implement the accepted [application contract](RETENTION.md), not silently
weaken it or bypass process expiry and checkpoint validation.
See the client [architecture](https://github.com/rupurt/ursula-zig/blob/8cfd68b275022c2de8572bce3608157b95ba13d7/docs/architecture.md)
and [dependency setup](DEVELOPMENT.md#zig-client-dependency).

Keep Ursula nodes private behind Rey's trusted protocol boundary. Authenticate
and authorize process admissions, commits, and connector records there; do not
expose raw stream APIs to workloads or browsers. In v0.5.1, node listeners lack
authentication/ACLs; the optional gateway can validate access tokens and enforce
bucket access. A bucket alone is not a security boundary, and gateway ownership
does not authorize a Transit turn or deletion. See the
[pinned upstream security contract](https://github.com/tonbo-io/ursula/blob/v0.5.1/docs/web/src/content/docs/pages/security.mdx)
and [Rey's authority model](SECURITY.md).

## Client integration surface

Exercise the following operations through `ursula-zig` in M1. They are already
part of the library's API; Rey's work is integration and verification against
the pinned server. Keep Ursula-specific behavior explicit in contract fixtures.

| Rey operation | Ursula API |
| --- | --- |
| Provision namespace and stream | `PUT /{bucket}`, then `PUT /{bucket}/{stream}` |
| Append command/event bytes | `POST /{bucket}/{stream}` |
| Read retained history | `GET /{bucket}/{stream}?offset=...` |
| Tail new data | GET with `live=long-poll` or `live=sse` |
| Inspect stream metadata | `HEAD /{bucket}/{stream}` |

The API overview currently lists bucket stream enumeration as unimplemented, so
Rey should own its stream catalog/naming scheme. This storage catalog is separate
from Station's registered-name-to-PID registry. See
[API overview](https://ursula.tonbo.io/docs/api/overview/).

Treat `Stream-Next-Offset` as an opaque continuation value. Prefer `Stream-Cursor`
for reconnecting live readers so stream recreation can be detected. `offset=-1`
starts at the earliest retained data, not necessarily the original beginning.
Handle trimmed positions (`410 Gone`) through explicit restore/bootstrap policy.
See [offsets](https://ursula.tonbo.io/docs/concepts/offsets/).

The client leaves retries, live-read reconnects, deadlines, and redirects to its
caller. Rey must inspect HTTP status and response metadata before advancing
producer or consumer state. Follow redirects only to configured trusted
endpoints, preserving the method, body, and append identity. See the upstream
[usage and lifetime rules](https://github.com/rupurt/ursula-zig/blob/8cfd68b275022c2de8572bce3608157b95ba13d7/docs/usage.md).

Rey integration tests must cover partial responses, cancellation, bounded
buffering, reconnects, and leader redirects. Use the library's SSE decoder and
copy borrowed continuation metadata before releasing its response. Checkpoint
only after applying the preceding data; a closed connection alone does not mean
the stream is complete. Choose the payload encoding and its record framing
before connecting producers to consumers; an HTTP chunk is not a domain event
boundary.

## Producer and consumer state

Ursula's append deduplication uses `Producer-Id`, `Producer-Epoch`, and
`Producer-Seq`, scoped per producer and stream. Sequences advance contiguously
within an epoch. Receipt history covers the current epoch; a newer epoch replaces
the previous epoch's receipts. See
[exactly-once writes](https://ursula.tonbo.io/docs/concepts/exactly-once-writes/).

Rey's producer recovery design must durably associate pending payloads with their
append identities and stable domain event IDs. Retrying an uncertain append in
a new epoch can defeat transport deduplication. Prove recovery/fencing behavior
before advancing epochs or taking over producer ownership.

Rey owns process sequence validation, ownership, consumer positions, recoverable
state, and output delivery. Kernel ownership generations and Ursula producer
epochs are distinct; the mapping must not let a stale worker regain authority
by choosing a new producer identity or epoch. Do not infer consumer scheduling
or multi-stream transactions from append deduplication.

M1 must prove that the selected append and framing mechanisms can support a
serialized per-process authority and atomic visibility of complete turn commits.
If they need an additional coordination mechanism, document and validate it
without creating a second authority for execution history. The guarantee remains
an implementation obligation, not a capability established by today's CLI checks.

Prove the exact conditional-append semantics, authoritative reads, payload
framing, and recovery of uncertain writes used by that mechanism. Security and
retention decisions spanning control and process journals need an explicit
coordination protocol too. Do not infer an atomic grant/revoke/commit operation
from independently successful appends or a trusted writer convention.

Mailboxes and exchange stream groups are Rey abstractions over Ursula. Group
membership, complete-record visibility, and safe retention need explicit
manifests and policies; do not assume a native group/transaction API. Follow
[STREAMS.md](STREAMS.md) and [CONNECTORS.md](CONNECTORS.md).

## Retention adapter

Ursula supplies mechanisms for whole-stream expiry/deletion and checkpoint-based
prefix trimming. These are implementation options for Transit policy, not a
complete process-lifetime or keyed-compaction model.

The implemented deletion proof uses a separate closed immutable payload stream.
Transit records declaration, verified publication, opt-in, owner retirement,
deletion intent and outcome in the authority journal/checkpoint. The adapter
uses the client's `create_stream` with initial bytes and `closed=true`, bounded
read verification, and `delete_stream`. Recovery after a lost deletion receipt
confirms 404 for the recorded intent; ordinary missing reads never mean expiry.
See the [payload profile](RETENTION.md#m1-immutable-payload-deletion). Control
journal deletion and native TTL on required history remain unavailable.

| Required operation | Documented Ursula mechanism |
| --- | --- |
| Whole-stream expiration | Creation with `Stream-TTL` or `Stream-Expires-At` |
| Publish recovery state | `PUT /{bucket}/{stream}/snapshot/{offset}` |
| Advance earliest retained position | `PUT /{bucket}/{stream}/retention/{offset}` |
| Delete a retired physical stream | `DELETE /{bucket}/{stream}` |

TTL applies to the whole stream rather than a rolling per-record window. See
[stream creation](https://ursula.tonbo.io/docs/api/create-stream/).
Snapshot publication leaves history readable; retention advances separately
at an aligned, monotonic boundary no newer than the visible checkpoint. The
snapshot body limit is 128 MiB. See the
[v0.5.1 snapshot/retention contract](https://github.com/tonbo-io/ursula/blob/v0.5.1/docs/web/src/content/docs/pages/api/publish-snapshot.mdx).
Stream deletion commits logical removal before asynchronous physical GC. See
[stream deletion](https://ursula.tonbo.io/docs/api/delete-stream/).

Use prefix trimming only after Transit's validated recovery basis and policy
permit it. Whole-stream deletion suits retired workloads or physical segments;
rotation requires a durable logical-to-physical mapping and unreused incarnation
identities. Do not use native TTL on required process/control data if it could
erase the only expiry, retirement, or recovery evidence. Logical expiry must
remain enforceable even when native cleanup is delayed.

An application-selected hard lifetime cannot be silently extended to accommodate
an adapter limitation. Validate compatible process, mailbox, checkpoint, and
payload lifetimes first. Keyed state compaction needs application/framework
semantics and validated replacement data; raw Ursula prefix trimming cannot
infer which keys or effects are safe to discard.

M1 must verify these operations through the selected `ursula-zig` revision and
identify any client surface gaps before implementation. Test crash recovery
between checkpoint publication, logical trim, adapter calls, and outcome
recording; expired cursors and recreated streams; and the distinction between
delete acknowledgement and observed physical reclamation. No current CLI check
establishes those guarantees. The portable contract lives in [RETENTION.md](RETENTION.md).

## Persistence plan

For M1, configure `raft.wal.backend = "disk"` and a persistent `raft.wal.path`.
Local state belongs under ignored `data/ursula/`; the Kubernetes reference
deployment needs persistent storage that survives service/pod replacement.
The upstream default and `dev` preset use memory storage and lose data on
restart. Pin and test the complete configuration when M1 implements the service.
See
[configuration](https://ursula.tonbo.io/docs/configuration/).

Quorum acknowledgement and background S3 offload are separate boundaries. Do not
interpret an append acknowledgement as confirmation that an S3 upload completed.
The selected WAL mode, replica layout, snapshots, and cold storage determine
recovery behavior. See
[durability and consistency](https://ursula.tonbo.io/docs/concepts/durability-and-consistency/).

Test execution-worker loss separately from Ursula restart and persistent-volume loss
in the [reference deployment](DEPLOYMENT.md). Multi-node failure tolerance,
S3-compatible cold storage, backup/restore, and retention need explicit design
and tests before broader use. Unread mailbox data must survive authorized
suspension within its accepted lifetime; expiry must make recovery terminal.
Benchmark realistic process backlogs and exchange groups rather than inheriting
upstream throughput claims. M1's exit criteria live in [ROADMAP.md](ROADMAP.md).

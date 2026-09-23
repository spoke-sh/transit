# transit-backend-ursula

Ursula storage and transport adapter, exported as `transit_backend_ursula`.
[The module root](src/root.zig) exposes the backend integration used by
[transit-node](../../../apps/transit-node/README.md). It depends on
[transit-core](../transit-core/README.md) and pinned upstream `ursula-zig`, importing
its `ursula` module. Callers never receive this raw storage capability.

The [Ursula design](../../../docs/URSULA.md) owns the provider boundary;
this README owns API mappings, pinned behavior, integration findings, and operations.

## Pinned dependencies

Ursula 0.5.1 and its matching `ursulactl` CLI are pinned in the dev shell
through [ursula-overlay](https://github.com/rupurt/ursula-overlay). `flake.lock`
records the overlay revision. [ursula-zig](https://github.com/rupurt/ursula-zig)
is the selected Zig client, pinned by revision and package hash in
[build.zig.zon](build.zig.zon).

Container deployments use the [official Ursula image](https://github.com/tonbo-io/ursula/pkgs/container/ursula),
not a separately built Nix image. The matching `0.5.1` release and immutable
multi-platform manifest digest are pinned in
[`deploy/reference/versions.json`](../../../deploy/reference/versions.json). Update this
pin deliberately alongside the development overlay and rerun disk recovery
checks. Supply an explicit disk-backed configuration and persistent volume;
the upstream image's bundled configuration uses an in-memory WAL.

## Conditional authority and startup

`just test::storage` uses the pinned client against an isolated Ursula 0.5.1
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

Transit uses one realm journal for policy and process operations. Conditional append orders both without cross-stream transactions.
Catch-up reads are bounded historical reads; a fresh `HEAD` supplies a required
tail, and mutation acceptance always uses record-tail comparison. The node checks the tail again before disclosing a signed view, forming the
current-policy read authorization barrier.
Redirects currently fail closed; multi-node routing remains unproved.

The transport notes below were researched against upstream v0.5.0 docs on
2026-09-21; retention and security mappings also reference v0.5.1 source
documentation.
The disk-backed integration and recovery suites exercise the implemented subset;
API availability alone is not evidence that Transit supports a capability. See
the [test guide](../../../tests/README.md) for commands and limits.

## Security boundary

[The integration design](../../../docs/URSULA.md) defines logical ownership and
provider independence. The backend adds retry/recovery and retention policy around
upstream HTTP operations; handlers use the public Transit client.

Keep Ursula nodes private behind Rey's trusted protocol boundary. Authenticate
and authorize process admissions, commits, and connector records there; do not
expose raw stream APIs to workloads or browsers. In v0.5.1, node listeners lack
authentication/ACLs; the optional gateway can validate access tokens and enforce
bucket access. A bucket alone is not a security boundary, and gateway ownership
does not authorize a Transit turn or deletion. See the
[pinned upstream security contract](https://github.com/tonbo-io/ursula/blob/v0.5.1/docs/web/src/content/docs/pages/security.mdx)
and [Rey's authority model](../../../docs/SECURITY.md).

## Client integration surface

These operations are available through `ursula-zig`; API availability is
distinct from a verified Transit integration against the pinned server. Keep Ursula-specific behavior explicit in contract fixtures.

| Rey operation | Ursula API |
| --- | --- |
| Provision namespace and stream | `PUT /{bucket}`, then `PUT /{bucket}/{stream}` |
| Append command/event bytes | `POST /{bucket}/{stream}` |
| Read retained history | `GET /{bucket}/{stream}?offset=...` |
| Tail new data | GET with `live=long-poll` or `live=sse` |
| Inspect stream metadata | `HEAD /{bucket}/{stream}` |

The reviewed upstream API overview listed bucket stream enumeration as
unimplemented; Rey owns its stream catalog/naming scheme. This storage catalog is separate
from Station's registered-name-to-PID registry. See
[API overview](https://ursula.tonbo.io/docs/api/overview/).

Treat `Stream-Next-Offset` as an opaque continuation position and `Stream-Cursor`
as a separate cache token. Echo the cursor unchanged alongside the next offset
or record position; it is not a checkpoint or stream-incarnation identifier.
The pinned client exposes these as `ReadOptions.position` and `ReadOptions.cursor`.
Its former `Position.cursor` API treated the cursor as a position and could not
send both together; [ursula-zig PR #1](https://github.com/rupurt/ursula-zig/pull/1)
fixes that model. Rey's disk-backed proof wakes on an append, then checks that
offset-plus-cursor and record-plus-cursor long polls return only the next record.

Direct HTTP checks independent of the client, including the official 0.5.1 image,
also confirmed a server documentation mismatch: cursor-only catch-up requests
reread from the earliest retained data, while cursor-only live requests return `400` because
they lack a start position. Recreating the same stream path does not make an
old cursor detect a new incarnation. The guide's cursor-as-position and
cursor/epoch claims are tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317).
Transit uses explicit record positions and unreused physical identities. The
selected client restricts `max_records` to record-coordinate requests;
byte-offset reads use `max_bytes`.

`offset=-1` starts at the earliest retained data, not necessarily the original
beginning. Handle trimmed positions (`410 Gone`) through explicit restore policy.
See [offsets](https://ursula.tonbo.io/docs/concepts/offsets/) for the upstream
description, qualified by this executable finding.

The client leaves retries, live-read reconnects, deadlines, and redirects to its
caller. Rey must inspect HTTP status and response metadata before advancing
producer or consumer state. Follow redirects only to configured trusted
endpoints, preserving the method, body, and append identity. See the upstream
[usage and lifetime rules](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/docs/usage.md).

Extending live streaming/routing requires tests for partial responses,
cancellation, bounded buffering, reconnects, and leader redirects. SSE support
in the upstream client is not a claim of a Transit subscription API. Use the library's SSE decoder and
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

The current authority uses conditional record-tail append, not Ursula producer
deduplication. Policy and process operations share the realm journal, so grant,
revocation, and commit ordering require no cross-stream transaction. A future
split must prove its coordination protocol; independently successful appends
or a trusted-writer convention do not establish atomic authority.

Mailboxes and exchange stream groups are Rey abstractions over Ursula. Group
membership, complete-record visibility, and safe retention need explicit
manifests and policies; do not assume a native group/transaction API. Follow
[STREAMS.md](../../../docs/STREAMS.md) and [CONNECTORS.md](../../../docs/CONNECTORS.md).

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
See the [payload profile](#immutable-payload-deletion). Control
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

`just test::storage` verifies checkpoint publication, trim, and deletion through
the pinned client with crashes between physical operations and durable outcomes.
The [proof guide](../../../tests/README.md) records tested schedules and limits.
Native TTL, keyed compaction, and physical erasure of all historical copies are
not claimed. The portable contract lives in [RETENTION.md](../../../docs/RETENTION.md).

## Persistence configuration

Configure `raft.wal.backend = "disk"` and a persistent `raft.wal.path`.
Local state belongs under ignored `data/ursula/`; the Kubernetes reference
deployment needs persistent storage that survives service/pod replacement.
The upstream default and `dev` preset use memory storage and lose data on
restart. Keep the complete configuration pinned and covered by recovery tests.
See
[configuration](https://ursula.tonbo.io/docs/configuration/).

Quorum acknowledgement and background S3 offload are separate boundaries. Do not
interpret an append acknowledgement as confirmation that an S3 upload completed.
The selected WAL mode, replica layout, snapshots, and cold storage determine
recovery behavior. See
[durability and consistency](https://ursula.tonbo.io/docs/concepts/durability-and-consistency/).

Test execution-worker loss separately from Ursula restart and persistent-volume loss
in the [reference deployment](../../../docs/DEPLOYMENT.md). Multi-node failure tolerance,
S3-compatible cold storage, backup/restore, and retention need explicit design
and tests before broader use. Unread mailbox data must survive authorized
suspension within its accepted lifetime; expiry must make recovery terminal.
Benchmark realistic process backlogs and exchange groups rather than inheriting
upstream throughput claims. M1's exit criteria live in [ROADMAP.md](../../../docs/ROADMAP.md).

## Updating the client dependency

[ursula-zig](https://github.com/rupurt/ursula-zig) is the selected application
library. The `transit-backend-ursula` package owns the `ursula_zig` dependency in
its `build.zig.zon`, pinned to an immutable revision URL and Zig package hash.
The upstream client exports the `ursula` module;
see its
[build integration](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/docs/usage.md).
The adapter now pins that revision and its Zig package hash; `just build` and
`just test::storage` compile and exercise the consuming backend. The Git URL avoids
a tarball-root handling failure observed in this pinned compiler's build fetch.

The reviewed client revision `2d507829429d4199f411df02df9cc937bf624144` declares
Zig `0.17.0-dev.2251+1175a3e99` as its minimum version, matching Rey's pinned
compiler. Its Zig and Ursula overlay revisions also match Rey's current pins.
`just ci` builds the consuming packages and runs disk-backed integration and
recovery checks against that server. See the client
[package metadata](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/build.zig.zon)
and [toolchain pins](https://github.com/rupurt/ursula-zig/blob/2d507829429d4199f411df02df9cc937bf624144/flake.lock).

This revision includes [the cursor API fix](https://github.com/rupurt/ursula-zig/pull/1):
set the continuation offset or record position in `ReadOptions.position` and
echo the independent cache token in `ReadOptions.cursor`. `Position.cursor` was
removed. The storage proof exercises both position types with the cursor; the
journal adapter's existing record-position reads need no API migration.

Updating `ursula-overlay` changes the server tools; update the Zig source
dependency separately. Check client/compiler/server compatibility and rerun the
backend integration and recovery checks with `just ci`.

During this dependency update, the pinned Zig reused a stale build configuration
that still selected the old client despite the new manifest and fetched package.
Clearing the affected build root's ignored `.zig-cache/` forced resolution of
the new pin. If compilation still references an old package hash after an update,
clear that local cache and rerun `just ci`.

## Immutable payload deletion

The initial resource catalog supports sixteen lifetime payload identities, each
at most 64 KiB, owned by an unlimited-lifetime PID. They are immutable standalone
bytes; the inline profile defines no protocol-recognized references from mailbox, state
or effect fields to them.
Finite owner/body lifetimes are rejected as unsupported rather than inferred.
General reference admission, large body streams and connector replay dependencies
need their own later contract.

A declaration records owner PID, publisher principal, length, SHA-256, and
`allow_delete` (false by default). Its journal position is its logical identity;
neither logical nor derived physical names are reused. A trusted publisher makes
one atomic Ursula create with the complete body and `closed=true`, verifies the
closed stream and hash, then records readiness. Creation and publication are
trusted control operations, not application handler capabilities. The publisher
must be serialized and issue no duplicate PUT: a lost receipt or restarted
publisher may only verify the original attempt. A missing stream stays uncertain;
it is not recreated. An unresolved creation remains pinned, with bounded catalog
and payload capacity; maintenance does not poll or discard it indefinitely.

Once the owner is permanently retired, an opted-in, positively published payload
can enter `retiring`. That durable record removes logical availability before
physical deletion. Background maintenance checks current grants, verifies the
stream is closed, issues DELETE, confirms 404, and records `deleted`. A crash
after DELETE leaves `retiring` in the control journal/checkpoint; a subsequent
404 completes that same intent. Storage errors are not deletion evidence.
Creating/default-retention payloads are not eligible, and late publication or a
new dependency cannot reopen a retired identity. Physical erasure of old WAL,
snapshots, backups or external copies is not claimed by a DELETE acknowledgement.

`just test::storage` kills/restarts disk Ursula after publication and after DELETE
but before recording its outcome, including checkpoint/trim of the control
history. `just test::service` proves automatic background retirement/deletion and
that default-retention bytes remain readable by the trusted storage verifier.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-backend-ursula && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

Run `just test::storage` and `just test::service` after changing backend or client
behavior; package tests alone cannot prove persistence or server semantics.

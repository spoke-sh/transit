# Storage, recovery, and reclamation

[transit-backend-ursula](../README.md)

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

The [transport notes](upstream.md) were researched against upstream v0.5.0 docs on
2026-09-21; retention and security mappings also reference v0.5.1 source
documentation.
The disk-backed integration and recovery suites exercise the implemented subset;
API availability alone is not evidence that Transit supports a capability. See
the [test guide](../../../../tests/README.md) for commands and limits.

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
The [proof guide](../../../../tests/README.md) records tested schedules and limits.
Native TTL and physical erasure of all historical copies are not claimed.
M7 performs keyed compaction through core's validated whole-realm checkpoint;
the adapter does not choose application keys or independent resource policies. The portable contract lives in [RETENTION.md](../../../../docs/reference/retention.md).

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
in the [reference deployment](../../../../docs/reference/deployment.md). Multi-node failure tolerance,
S3-compatible cold storage, backup/restore, and retention need explicit design
and tests before broader use. Unread mailbox data must survive authorized
suspension within its accepted lifetime; expiry must make recovery terminal.
Benchmark realistic process backlogs and exchange groups rather than inheriting
upstream throughput claims. M1's completed outcomes and limits live in [M1](../../../../docs/roadmap/M1.md).

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

## Checkpoint ownership

`Store.loadCheckpoint` returns an optional owned parsed checkpoint. Its `value`
is a pointer; callers must call `deinit()` after copying the needed state.
Publication/verification, maintenance and core recovery release it on every
success/error path. The bounded JSON parser writes large catalog fields into
allocated storage, avoiding repeated large Debug stack copies. Wire bytes and
checkpoint hashes are unchanged for inline-only histories.

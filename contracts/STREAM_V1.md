# Stream operation bindings v1

## Implemented boundary

[`transit-protocol.StreamQueue`](../packages/zig/transit-protocol/src/StreamQueue.zig)
defines neutral partition, append, receipt, read-coverage and consumer-offset
bindings. Its validators check shape, exact attribution and supplied guards.
They perform no I/O and establish no permission, catalog publication, payload
availability or durable acceptance. There is no installed `CREATE STREAM`,
`PRODUCE`, `CONSUME`, `COMMIT OFFSET` or `STREAM_SLICE` execution API.

The reflected [data lifecycle schema](data-lifecycle-v1.schema.json) owns field
shapes; the [shared fixture](../packages/zig/transit-protocol/src/fixtures/stream-queue-v1.json)
uses full-width identities and deliberately different logical offsets and WAL
positions. The [typed catalog lifecycle](DIRECT_TABLE_V1.md#stream-and-queue-lifecycle)
now publishes Stream/Queue declarations with native authority and verified
partition initialization. SQL verbs and the Table-only transaction profile
remain unchanged. Storage
provides immutable `LogDeclaration` records, fenced `LogInitialization`, a
bounded pinned `LogTail` cache and shared paged bitmap/sidecar codecs. These
foundations do not enable payload operations or SQL verbs. Their stored
formats use the current shared definition under the coordinated cutover policy.

The storage-only `StreamPartition` additionally accepts schema-bound batches,
publishes paged producer and original-result indexes atomically with each
payload, and persists explicit group assignment generations. Its bounded recovery
and borrowed current-batch reads are exercised on disk. Service payload APIs,
pinned finite reads, offset settlement and segment maintenance are not enabled
by that component. See the [stored acceptance contract](TRANSIT_STORAGE_V1.md#stream-partition-acceptance).

## Identity and append

`StreamQueueDeclaration.Declaration` binds the current definition, immutable
object interpretation, exact schema content, configuration and operation limits.
The schema owner resolves stable column IDs and validates their logical types,
physical codecs and collations. A content digest alone does not perform that
binding. Declarations use branch one.

Partition count is nonzero and remains fixed across definition successors.
Automatic routing requires a declared stable key column. It hashes the schema
owner's canonical collation-aware key bytes with SHA-256, interprets the first
eight digest bytes as a big-endian unsigned integer and takes modulo partition
count. Callers without a partition key select an ordinal explicitly. Neither
hash equality nor partition equality establishes complete key equality.

Retention has a nullable positive `max_age_ms`; null retains unlimited history.
Key compaction separately names a stable key column. Definition successors retain
object identity, advance exactly one revision and preserve kind, routing and key
selection. Schema evolution requires its owner's additional compatibility checks.
Changing those fixed properties requires a separately defined migration; the
validator refuses it rather than reinterpreting accepted operations.

Required nonzero limits bound append rows/bytes, claim rows, read rows/bytes,
active leases, waiters and timer work. Claim size cannot exceed active lease
capacity. These budgets do not cap durable collection cardinality. Deployment
admission separately meters aggregate memory and physical capacity and reserves
control capacity for settlement, revocation and recovery.

`Partition` binds the mandatory current definition, immutable data interpretation
and a zero-based logical partition ordinal. Its object has one catalog scope and
branch one. The owning declaration must additionally verify the ordinal against
its partition count and establish the interpretation's schema, codecs, collations,
hash algorithm, retention and policy references. A definition descriptor is not
proof of catalog membership. Renaming never changes an accepted binding.

`Append` freezes that target, original operation, `stream` or `queue` kind,
optional producer identity, nonzero row count and immutable payload commitment.
The operation and target share a catalog scope. The count describes durable
cardinality; it is not a resident array size. Runtime admission must enforce
independent byte/row/work quotas and verify the actual payload and schema.
One append targets one logical partition. Atomic cross-partition append requires
an executable common transaction owner.

Producer ID is a nonzero 16-byte value. Epoch and sequence are nonzero unsigned
64-bit values; sequence identifies a batch. The eventual owner must serialize
producer fencing, accept each sequence only once, reject conflicting payloads,
and preserve old-sequence rejection after receipt cleanup. Shape validation alone
cannot prove monotonic progression or deduplication.

`ProducerState` specifies the concrete progression rule. The first accepted
batch for an ID starts at sequence one. A producer ID is scoped to the stable
object/partition and its original principal; another principal cannot take it
over. In the same epoch, the next fresh batch is exactly the last accepted
sequence plus one. An older accepted sequence requires its exact retained
receipt, including original operation and payload. A higher epoch starts at
sequence one and fences lower epochs. Current authorization is required to
advance an epoch. Definition revisions preserve this stable producer scope;
the current schema/definition check remains an independent admission guard.

The persisted `discarded_through` floor only advances and never exceeds the
last accepted sequence. A sequence at or below it returns
`LogProducerReceiptExpired`; cleanup cannot readmit it as fresh work. Maximum
unsigned sequence is representable; further work in that epoch cannot advance
without an explicit greater epoch. The owner checks original-operation receipts
before current producer fencing so a previously accepted retry remains an
observation of its original result. State and receipt changes must share the
append decision. These pure progression checks do not publish that decision.

`AppendReceipt` attributes an accepted half-open logical range `[first, next)`
to the complete original append. The range length equals its row count without
wrapping, and the separately recorded WAL acceptance position is nonempty.
Neither a WAL LSN nor its partition ID is the logical offset or ordinal.
`requireAppend` compares every frozen field; retry cannot substitute a new
producer, payload, interpretation, operation or partition.

## Finite read coverage

`Cut` records the partition interpretation, physical accepted frontier and
logical `[retained_from, next)` range. Its owner must separately establish a live
retention pin and complete reconstructible history. An offset below the retained
boundary produces `LogHistoryUnavailable`; an offset above the upper boundary
produces `LogOffsetBeyondCut`. Neither condition silently rebases a read.

`Coverage` describes a requested finite `[from, until)` interval within the cut,
its verified exclusive `through` frontier and returned row count. Completion
holds exactly when `through == until`. Returned rows cannot exceed traversed
logical offsets, but filters and compaction may make the row count smaller or
zero. An empty complete range is valid. Partial coverage is not completion,
and finite completion never claims that a live Stream has ended.

These types do not certify the truth of caller-supplied coverage. The reader
must verify storage continuity and compaction evidence, retain source identity
across batches and recheck current authorization before every disclosure,
including empty results, repeated batches and terminal metadata. The owning
[SQL result lifecycle](SQL_RESULTS_V1.md) remains responsible for result delivery.

## Consumer settlement

The initial local assignment protocol is explicit administrative work. An object
owner assigns one principal to one group/partition; no connection establishes
membership and no background rebalance infers it. `GroupAssignment` freezes its
original operation, verified observed cut, nullable expected `GroupProgress`,
new group identity/generation/principal and exclusive next offset. Initial
assignment uses generation one and an explicitly chosen checkpoint within that
cut, including either boundary. Reassignment requires the exact earlier progress,
increments generation by one and preserves the checkpoint. Generation overflow,
concurrent progress and checkpoints outside retained history refuse publication.
Reassignment cannot silently skip expired data. Retiring or resetting a group
requires a separate closure contract and is not an implied assignment action.

`GroupProgress` retains target, group and committed next offset. Definition
changes preserve the stable object/partition/group identity; a subsequent operation
explicitly binds the new definition while retaining its expected progress.
`GroupAssignmentReceipt` retains the complete original assignment and its later
acceptance frontier in the same partition. Original receipt lookup precedes
fresh validation. The assigned principal separately needs current read/acquire
rights to consume and settlement rights to commit; assignment grants none.

`Group` binds a nonzero object-scoped group identity, assignment generation and
claimant principal. `OffsetCommit` freezes an original operation, that group,
complete consumed coverage, the expected checkpoint and its successor. The
checkpoint is always the exclusive next offset. Coverage starts at the expected
checkpoint and ends at the proposed successor; no skipped interval is implied
by a filtered result. Equal checkpoints permit an empty completed observation.

`requireCurrent` checks the exact supplied group assignment and expected next
offset. A changed generation/principal yields `LogGroupFenced`; an independently
advanced checkpoint yields `LogOffsetConflict`. An owner must obtain both from
the selected target under the same current-policy/publication guard and verify
its own issued coverage. Reading never implicitly commits this checkpoint.
Lost-response recovery first looks up the original accepted operation; it must
not run fresh-publication validation against a later checkpoint and relabel
the accepted result as rejected.

`GroupProgress.advance` verifies stable target identity, group fencing and the
expected checkpoint. `OffsetReceipt` binds the full original commit and a later
acceptance frontier in that physical partition. Receipt recovery compares the
original request independently of later group progress or reassignment, under
current disclosure rights. These pure types still require the runtime owner to
verify issued coverage and durably publish progress and its receipt together.

## Storage and transaction obligations

Executable owners must durably retain accepted payloads and original outcomes,
publish dependencies before referencing them, and preserve retained read and
consumer bases across flush, archive, compaction and restart. Retention is
unlimited by default. Capacity pressure can refuse admission, never expire
accepted records or forget producer floors. Required missing history blocks
recovery.

Stream append and offset settlement remain reserved, unsupported transaction
participants. Enabling them requires retained preparation, conflict/policy
guards, one original decision, common-decision visibility and bounded cleanup
under [the transaction contract](DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence).
A structure that validates is not an executable participant.

The [current-v1 policy](../docs/handbook/reference/versioning.md) applies to every
future persistent or executable binding. Decoding a missing or foreign definition
never substitutes the current value. Definition changes require a coordinated
consumer/fixture cutover before incompatible work executes.

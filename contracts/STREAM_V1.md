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
positions. This additive vocabulary does not change existing native commands,
stored records or the Table-only transaction profile.

## Identity and append

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

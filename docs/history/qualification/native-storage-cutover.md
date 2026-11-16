# Native storage cutover assertion map

Source being replaced: `424cc32e88a1b7d85a160195887fd7a7b0199756`.
This map records ownership of assertions during Ursula removal. It is not a
passing qualification report: final committed-source commands and outcomes must
be recorded before this change is submitted.

The replacement has one exclusive native disk owner, with optional immutable
MinIO storage. It does not support Ursula's remote shared-WAL topology. The WAL,
installation identity, allocation inventories, upload coverage and collection
progress remain local authority. MinIO is the selected real provider; AWS S3 is
unqualified. Historical Ursula results do not qualify the replacement.

## Retired provider implementations

Original source files remain available in the
[pre-cutover storage proofs](https://github.com/spoke-sh/transit/tree/424cc32e88a1b7d85a160195887fd7a7b0199756/tests/storage/providers)
and [Ursula backend](https://github.com/spoke-sh/transit/tree/424cc32e88a1b7d85a160195887fd7a7b0199756/packages/zig/transit-backend-ursula).

| Retired owner / assertions | Replacement assertion owners | Scope distinction |
| --- | --- | --- |
| `pages.{zig,py}`: old and current tree roots, deleted-key absence, ordered iteration, foreign/corrupt references, roots after checkpoint/trim, fixed read cache | [Native page tests](../../../packages/zig/transit-backend-local/src/native_test.zig), [growth crash driver](../../../tests/storage/providers/growing.zig), [disk process proof](../../../tests/storage/providers/native_disk.zig) | Native immutable object locators replace packed/closed Ursula stream layouts; root-only authority and original values remain required |
| `pages.zig` and `local/page_batch_faults.py`: private page staging, distinct locators, unpublished partial batches, lost staging responses, corrupt readback | [Native page batch tests](../../../packages/zig/transit-backend-local/src/native_test.zig), [local storage fault driver](../../../tests/storage/local/local_storage_faults.zig), [S3 provider proof](../../../tests/storage/providers/s3.py) | Ursula's missing stream coordinates and snapshot endpoints have no native equivalent. Native per-object barriers, original descriptors and failed-candidate invisibility replace those inputs |
| `block_storage.{zig,py}`: full batch larger than one read page, retained roots, replacement/deletion, absent and corrupt bytes, conditional publication conflict | [Native page/block tests](../../../packages/zig/transit-backend-local/src/native_test.zig), [public bulk proof](../../../tests/storage/providers/block_native.py), [owner recovery proof](../../../tests/storage/local/local_owner_recovery.py) | Public proof retains 16 records / 128 KiB, exact original receipt, old-version bytes, corrupt/missing remote rejection and revocation during I/O |
| `storage_collection.{zig,py}`: independent retained roots, allocation/candidate quotas, control reserve, stale candidate refusal, incomplete mark refusal, grace/epoch fencing, deletion after lost reply, exact accounting on reopen | [Native collection tests](../../../packages/zig/transit-backend-local/src/collection_test.zig), [direct collection tests](../../../packages/zig/transit-backend-local/src/data_collection_test.zig), [collection process faults](../../../tests/storage/local/local_native_collection_faults.py), [MinIO tier proof](../../../tests/storage/providers/s3_tier.zig) | Native retained-root cuts and captured read lifetimes replace Ursula stream closure/retirement. Recorded generation-specific DELETE cannot remove a recreated object |
| `growing_maintenance.py`: unacknowledged snapshot/page publication cannot permit trim; trim deadline; current revocation; restart | [Native maintenance proof](../../../tests/storage/local/local_native_maintenance.py), [owner sync-fault recovery](../../../tests/storage/local/local_owner_recovery.py), [local filesystem faults](../../../tests/storage/local/local_storage_faults.py), [S3 deadlines](../../../tests/storage/providers/s3.py) | No second maintenance process shares the disk owner. Native checkpoint/WAL barriers replace remote snapshot publication; remote deadlines belong to the tier adapter |
| Former `node_recovery.py` proxy: transient GET/HEAD failures, bounded retry exhaustion, denied/missing state, invalid definition/genesis, no bootstrap mutation | [Native startup proof](../../../tests/storage/providers/node_recovery.py), [native owner recovery](../../../tests/storage/local/local_owner_recovery.py), [growth definition rejection](../../../tests/storage/providers/growing.zig), [MinIO provider/tier proofs](../../../tests/storage/providers/s3.py) | Native startup never uses an HTTP WAL. The S3 adapter reports bounded failures without hidden retries; the background tier retries retained work |
| Former `node_concurrency.py` provider barriers: slow read does not hold authority mutex; current revocation; identical concurrent publication | [Native I/O barrier tests](../../../packages/zig/transit-backend-local/src/native_test.zig), [public concurrency proof](../../../tests/storage/providers/node_concurrency.py), [remote block revocation](../../../tests/storage/providers/block_native.py) | Independent local progress and concurrent public exact retry remain separate from remote-dependent reads. No distributed-writer claim |
| `harness/test_ursula.py`: separate public/admin provider listeners, provider restart and owned cleanup | [Shared listener controls](../../../tests/harness/test_services.py), [catalog fixture controls](../../../tests/catalog/tables/catalog_fixture.py) | The native fixture owns a directory, not a provider listener/process. Scenario owners join their actual children before retaining or deleting evidence |

## Migrated application and physical profiles

Service ingress, signed reads, wait cancellation, grants/revocation, ownership
fencing, effects and payload retirement use the native owner through their
existing callers. Their original semantic scenarios remain in
[service](../../../tests/interfaces/native/service.py),
[retention maintenance](../../../tests/storage/retention/maintenance.py),
[effects](../../../tests/runtime/effects) and
[deletion](../../../tests/storage/retention/deletion_service.py).
A second shared-storage authority is replaced by explicit exclusive-owner
refusal; different clients still use the same public authority.

The [growth proof](../../../tests/storage/providers/growing.py) retains its
value/count, mailbox, captured-version, exact-receipt and checkpoint assertions
across SIGKILL, with one decoded read page. The
[physical capacity proof](../../../tests/storage/retention/capacity.py) fills
an owned ext4 filesystem to actual ENOSPC, preserves the accepted head, releases
only its preallocated control reserve, completes reconciliation/checkpoint/trim,
and kills/reopens the native owner. Read-cache size and fixed mutation staging
workspace are reported separately; neither is a total durable cardinality cap.

SDKs, direct Table/Document/KV queries, connector examples and installed services
retain their existing accepted-value/restart assertions while using native disk
or a configured MinIO immutable tier. Native `.tseg` descriptors, not evictable
local payload files, establish whether a Table was flushed. Timing samples from
these functional proofs are exploratory and do not qualify a performance SLO.

## Final evidence

Pending: final-source baseline, contract/SDK, Board/browser, runtime, deployment,
physical capacity, MinIO and clean-lane gates. Commands that only compile,
install dependencies or list tasks are not executed durability evidence.

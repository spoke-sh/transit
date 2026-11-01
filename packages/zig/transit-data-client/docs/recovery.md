# Local recovery storage

`LocalRecoveryStore` is an explicitly opened Linux local-filesystem store for
frozen operations and later owner evidence. It grants no dispatch, observation or
execution permission. `SqlRecovery` connects that store to the existing SQL
executor; no background worker, SQL replay or credential discovery is started.
`KVRecovery` connects the same store to named direct KV mutations. All are available through `transit_data_client` in the public Zig SDK.

## Ownership and bounds

Open one child directory beneath a trusted, caller-supplied parent. The store
creates it with mode `0700`, creates files with `0600`, and rejects existing
directories/files accessible by group or other users. It rejects symlinks at the
store and record boundaries. The parent and store names must not be replaced
while open. The store does not protect against another program deliberately
modifying files as the same OS user; checksums detect damage, not malicious
forgery. Network filesystems and non-Linux platforms are unqualified.

An exclusive OS file lock fences cooperating store owners until close or process
exit. There are no expiring leases or per-record ownership claims. A mutex
serializes operations within the owner. Keep the store at a stable address, join
all users before `deinit`, and keep its I/O and allocator alive. The lock does not
coordinate Transit principal sequences or give permission to share a principal.

`Config.record_bytes` bounds the entire encoded record, including its 116-byte
header. It defaults to 1 MiB and must be greater than 116 bytes and at most 64 MiB.
The store reserves one buffer at open. Records do not occupy a resident directory
or acquire an in-memory queue entry. `get` copies into caller-owned storage; its
returned slices survive later store operations while that storage survives.

`listPage(after, keys)` fills a caller-supplied, nonempty array in lexicographic
key order. It scans directory names with bounded memory. A non-null `next` means
more keys existed during that call. This is not a snapshot across calls: additions
before the cursor require another walk from null. Corrupt record contents remain
enumerable and fail validation when loaded. Temporary unpublished files left by
interruption are ignored and never interpreted as accepted records.

## Publication and failure ordering

The mandatory `TCR1` marker and every record contain the current shared definition.
A missing marker alongside saved records, a foreign definition, bad checksum,
truncated record, mismatched key or excessive size refuses recovery. There is no
default definition, migration decoder or silent reset.

The 36-byte `.format` marker is ASCII `TCR1` followed by the 32 raw bytes of the
shared definition. Record names are the lowercase 64-digit key plus `.rec`.
Each record has this fixed header, followed immediately by original and evidence
bytes; integers are unsigned little-endian and trailing bytes are refused.

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | ASCII `TCR1` |
| 4 | 32 | Required shared definition |
| 36 | 32 | Exact filename key |
| 68 | 8 | Positive revision; initial insertion is 1 |
| 76 | 4 | Nonzero original length |
| 80 | 4 | Evidence length, initially zero |
| 84 | 32 | SHA-256 of header bytes 0–83 followed by both payloads |

An incompatible layout or interpretation replaces the current shared definition;
the format label alone never establishes compatibility across builds.

`insert(key, original)` preserves exact nonempty bytes. Repeating the same key
and bytes preserves subsequent evidence; different bytes refuse. `update` uses
an expected revision and replaces evidence without changing the original. The
store is neutral: domain adapters must validate both original bytes and evidence.
Revisions do not wrap. `remove` requires the expected revision and an explicit
`forget_original` application retention decision. No timeout, capacity pressure,
close or observed completion removes a record automatically.

Publication writes a private temporary file, synchronizes it, atomically installs
the name, then synchronizes the directory. Open also synchronizes the parent.
Cancellation or failure after name publication can leave a complete new record
even though the call failed. Reopen/load resolves that local uncertainty;
duplicate insertion/update re-establishes the directory durability barrier.
Failures never authorize sending replacement work. Pre-dispatch failure sends
nothing; later storage failure does not change a known remote outcome.

The component tests exercise actual files and injected create/write/sync/rename
failures. They do not qualify power loss, disk hardware or caller-process death
against a running Transit service.

## SQL adapter

Create `SqlRecovery` with the store and an explicit allocator. It reserves a
record-sized encoding buffer and `Config.parse_bytes` scratch (4 MiB by default,
positive and at most 64 MiB). Internal receipt parsing reuses that reserve.
Public `load` uses the caller's output allocator; supply a bounded allocator when
loading untrusted saved artifacts. Keep one borrower per adapter and executor.
Independent adapters may share the store. The store outlives its adapters.

`execute(executor, sql, parameters, options)` installs the executor's
`before_submit` hook. The executor freezes and validates the original token,
exact SQL/parameters, instance/account and observed database/source/transaction
scope before the hook persists them. The record contains no session credential
or login/signing secret. It can contain private application data. The key hashes
the SQL domain, original instance/account and client token; scope/content reuse
under that key must match exactly. A second persistence callback is refused.

The returned `Execution` separates three observations:

- `outcome` is the existing shared command, result, failure or unresolved outcome.
- `attempt` identifies the saved original and its last known store revision; a
  preparation refusal may have no attempt.
- `persistence_failure` reports failure to save an observed command completion.
  A verified commitment remains visible in `outcome` even when this is non-null.

The caller releases `Execution` with `deinit`; its SQL executor and clients must
outlive the result. Row/schema/observation and incomplete-result semantics remain
with the shared SQL reader. Saved interactive SELECT text does not permit a
replacement SELECT or restoration of a lost session's cursor.

`save` and `saveCompletion` expose the same original/evidence storage separately.
They validate scope and command evidence, reject conflicting known completions,
and preserve provisional transaction outcomes. `load` owns the parsed submission
and optional completion until `Loaded.deinit`. `Loaded.pending(client)` validates
the definition and original instance/account against a separately authenticated
client, then creates the existing original-token observer. It does not attach a
transaction or dispatch SQL. Current service authorization still governs recovery.

Missing status is uncertainty, including a record saved before a send that never
occurred. An error after submission leaves the original record enumerable even
when `execute` cannot return an `Execution`. These APIs provide no automatic
receipt-retention policy, browser storage, Catalog staging/settlement adapter or
installed foreign-language host.


## Direct KV adapter

`KVRecovery` composes `Context.callKV` with the existing
[`DirectKVClient.Saved`](../../transit-catalog/docs/direct-kv.md) codec. It uses the
same record-sized buffer, configurable parsing reserve and single-borrower rules
as the SQL adapter. `load` returns an owned original and optional validated receipt;
call `Loaded.deinit` when finished. Give untrusted loads a bounded output allocator.

Prepare a mutation with `DirectKVClient.prepareMutation`, then call
`execute(context, handle, output, mutation, admission)`. The adapter validates the
handle's frozen connection and saves/synchronizes the exact prepared work before
dispatch. Keep inputs immutable until it returns. The `admission` argument uses
the context's immediate-refusal or finite-wait policy; its deadline applies to
admission after persistence. A saved record can exist even if admission or a later
local step refuses. Enumerate the store or compute `key(original_identity)` to
recover it. A persisted original alone never establishes acceptance.

The key hashes the KV mutation domain, current definition and little-endian
realm/resource/catalog/principal/operation identity. The original includes the
full connection, target branch/object, expectations, content commitment and exact
mutation. Reusing an identity with different content or connection refuses.
The adapter adds no signing seed, session credential or endpoint. The original
can contain private application data and signed prerequisite guards.
Endpoint replacement preserves the original signed connection scope.

`Execution.outcome` is the ordinary arena-owned KV result/failure and its dispatch
evidence. `attempt` retains the store key/revision. `persistence_failure` separately
reports receipt validation/storage failure; it never hides a known service result.
Leave enough record capacity for the original **and** its later receipt. A legal
service batch can exceed the default local store or parsing reserve; preparation
refuses before send when those bounds are insufficient. No record is automatically
forgotten after a successful mutation or receipt save.

`observe(context, handle, output, key, admission)` loads the exact original,
checks the full connection, and inspects its original operation through the
control lane. It never resubmits a mutation. The service rechecks current
permission; a saved receipt cannot bypass that check. A missing observation is
uncertainty, including when no send occurred. An observed receipt is validated
against the exact binding and the storage owner's accepted-evidence rules before
revision-checked persistence. Conflicting receipts refuse replacement. `save`
and `saveReceipt` expose the same persistence steps for explicit callers.

This adapter covers standalone mutations. Declaration settlement, retained pin
recovery, transactions and other data kinds continue to use their explicit owner
APIs and saved-operation contracts. It does not create a recovery loop or a
principal-sequence allocator.

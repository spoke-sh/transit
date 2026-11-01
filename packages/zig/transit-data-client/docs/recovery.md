# Local recovery storage

`LocalRecoveryStore` is an explicitly opened Linux local-filesystem store for
frozen operations and later owner evidence. It grants no dispatch, observation or
execution permission. `SqlRecovery` connects that store to the existing SQL
executor; no background worker, SQL replay or credential discovery is started.
Both are available through `transit_data_client` in the public Zig SDK.

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
installed foreign-language host. Their remaining integration belongs to M9.

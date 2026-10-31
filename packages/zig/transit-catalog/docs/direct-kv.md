# Named direct KV

`DirectKVClient` declares and accesses named, typed KV objects through the shared
signed database connection. `transit-data-client.Catalog.callKV` owns transport
and attempt diagnostics. Storage belongs to `KVPartition` over `TransitLog` and
`TransitObjectStore`; declaration and access require no writer PID or Station turn.

## Declare and resolve

Prepare a `DirectKV.Declaration` with `DirectKVClient.prepareDeclaration`. It
freezes the current definition, scoped object, original operation, namespace/name,
owner role and `KVDeclaration.Spec`. The value types are `int64`, `boolean`, `utf8`
and `binary`, with explicit nullability. Save that complete declaration before
sending it. `declaration` commands are `preview`, `admit`, `inspect`, `execute`
and `cancel`; execution accepts a bounded step count of 1–256.

Preview accepts no work. Admission reserves the shared name and permanently
claims the object ID. Execution registers the KV authorization object and
initializes its partition before exposing the name. `lookup`, `list` and
`observe` return current metadata; list pages contain at most eight entries.
A position describes that observation, not a retained read pin.

Rename and DROP require the exact expected definition and current ownership.
DROP removes the live name while preserving accepted operations and retained
reads. Explicit incoming dependency registrations block DROP. Cancelling an
uncompleted declaration preserves its recorded progress; it does not undo a
committed partition change. A dropped name can be reused with a fresh object ID.
ALTER and executable SQL `CREATE KV` are not supported by this caller.

## Mutate and recover

`prepareMutation(output, binding, spec, changes)` encodes one atomic batch of
`put` and `remove` operations. Puts select `any`, `absent` or `present` key
expectations. The binding requires the exact definition and may also require an
observed partition position. A missing-key read includes its observation basis;
use that position when subsequent changes must invalidate the write. A failed
key expectation or position guard rejects the whole batch.

Keys contain 1–1024 byte-exact bytes, including zero bytes. Batches contain
1–1024 changes. A value's logical byte budget is 1 MiB minus 1024 bytes, and the
entire canonical encoded change list must fit 4 MiB. The client checks retained
encoding size before allocating another payload. Deployment request and builder
memory quotas can refuse work within those protocol bounds. These limits bound
one operation, not the durable collection's total cardinality.

Use `save` before submission and `load` for recovery. Saved mutations require the
current shared definition and preserve the full signed-connection binding,
original operation, guards and content digest. The `mutate` call publishes its
state and receipt in one partition acceptance. A lost response is unresolved;
inspect `operation` or repeat the identical saved mutation. Never assign a new
operation ID to resolve the old one. Exact retry returns the original outcome,
including after rename or DROP, subject to current authorization.

## Read, retain and authorize

`get` distinguishes a missing key from explicit NULL. Returned logical values
belong to the output arena and survive response cleanup and later calls until
the caller resets that arena. Use bounded output windows when reading many keys.

`pin` binds an original owner operation to an exact observed partition position.
After uncertainty, `pin_status` recovers the same handle. Pass the handle to
`get` to read that retained cut after later writes or DROP. `release` closes the
pin explicitly; repeating closure is safe. An unpinned read observes current
state. A descriptor alone does not retain data.

All operations recheck current catalog CONNECT and namespace USAGE. CREATE also
requires namespace CREATE and owner-role eligibility. KV has separate INSPECT,
READ and WRITE privileges. Metadata and mutation receipts use INSPECT; values,
pins and release use READ; mutations use WRITE. Rename and DROP require ownership.
A dependency source uses these KV privileges, while registration/removal requires
the dependent's metadata authority. Neither a receipt, pin nor dependency grants
access. Native resource grants do not authorize direct KV.

Each batch commits in one KV partition. The Table transaction service still
rejects KV participants before admission; independent Table/KV calls are not one
atomic transaction. The [direct contract](../../../../contracts/DIRECT_TABLE_V1.md#direct-kv)
defines exact request attribution and compatibility checks.

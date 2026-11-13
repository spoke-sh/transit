# Reading a private transaction

Use `Context.readTransaction(handle, transaction, output, action)` to read selected
Table and KV objects in an active transaction. The result is a
`Catalog.TransactionReadOutcome`: either a typed result or the original error,
native rejection and per-call diagnostic. Reads use data admission and preserve
the database's existing current-authorization and private-workspace checks.
`readTransactionWithAdmission` accepts the context's finite admission wait.

| Action | Result |
| --- | --- |
| `kv` with object, key and optional expected definition | `kv`: owned decoded value and private read evidence; absence differs from logical NULL |
| `open_table` with retained allocator, namespace, name and optional expected definition | `opened`: owned `Transaction.Read.TableReader` |
| `table` with reader and `describe` | `description`: copied schema and exact read basis |
| `table` with reader and `key` | `row`: owned row or absence; key cells follow primary-key order and the schema's collation |
| `table` with reader and `next` | `batch`: bounded owned rows and explicit completion; subsequent successful terminal calls return null |

An open resolves the name against the transaction's frozen catalog and binds the
original account/token, full connection, selected definition and exact workspace
revision. `describe` carries that basis, including the common cut and private
revision. Scan completion covers this private observation; it does not establish
commit. Point reads do not change scan progress. Scans reuse native Table page
limits (at most eight rows per batch); this API adds no relational execution,
projection or filter language.

## Lifetimes and revision changes

The reader owns its schema and cursor using the allocator passed to `open_table`.
Returned schema copies, rows, batches and KV values use the separate output arena.
They survive later calls, reader disposal and context destruction. Destroy owned
rows/batches/descriptions before resetting their output arena. Reset reusable
batch output with `.retain_capacity` after consuming each page; retaining every
page is an application memory choice, not streaming.

The transaction's exclusive call guard covers dispatch, validation and copying.
Overlapping reads or writes on the same transaction refuse with `Busy`. Readers
also reject overlapping calls. Keep owners at stable addresses while in use;
copying a reader does not create a second owner. Join calls before `deinit`.
Idle readers hold no transport borrow or admission permit. The host bounds the
number of idle readers and retained output through its allocator; context
capacity bounds active calls, not total process memory.

Every reader call validates its original context slot/generation and full
connection. Closing and reopening a facet cannot retarget it. Metadata, missing
keys, empty batches and repeated terminal calls all recheck current permission.
Already returned copies describe an earlier observation; they confer no ongoing
permission. The server retains its policy-epoch checks before disclosure.

Writes and savepoint controls change the workspace revision and invalidate older
readers, including when another host advances the original transaction. Fetches
never inspect and silently rebind to a newer revision. Pending local statements
or controls refuse reads with `TransactionSessionPending`; settlement refuses
them with `TransactionSessionSettling`. Resolve saved work and explicitly open a
new reader if needed. Do not splice its rows onto an earlier result.

Failed exchanges, invalid pages and failed output allocation do not advance the
cursor or claim completion. A read failure neither decides the transaction nor
erases saved work. Native error distinctions and per-call diagnostics remain
available; the client never retries automatically.

## Cleanup, recovery and embedding

`reader.deinit()` frees local memory only. Its private snapshot is a descriptor
over transaction-owned pins, not an independent durable pin. Only original
transaction settlement/cleanup releases those pins; inspect `cleanup_complete`
separately from the decision. Disposal works after revocation or revision change
without I/O. Context close joins active calls, and reserved control admission
continues to allow original settlement while the context is closing.

There is no durable reader cursor format. `TransactionRecovery` restores original
write/control identities; an application can explicitly open a new read of the
recovered active workspace. It cannot implicitly continue an earlier prefix or
claim it complete after replacement.

Native hosts use `Transaction.read(client, output, action)` with their existing
signed client. Context and native hosts share `DirectTransactionReader`, above
the existing Table/KV owners and below Station. A reader opened by one entry point
cannot switch context ownership. `Transaction.privateClient` remains for native
preparation helpers; its returned borrow does not extend the exclusive read guard.
The shared read API adds no wire, ABI or persisted-format definition and starts no
worker, retry loop or hidden journal.

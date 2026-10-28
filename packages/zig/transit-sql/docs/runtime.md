# Database-owned SQL execution

An account fixes its identity, database principal, one Catalog and up to eight
namespace/role bindings within that Catalog. Catalog positions identify its SQL
operations; independent catalogs cannot share this operation-number domain.
SQL operation IDs and underlying data-operation IDs are distinct. The original
accepted reference binds them; neither is reconstructed from SQL during recovery.

`DatabaseRuntime.admit` validates and stages the complete frozen intent before
`DirectClientToken.bind` accepts its account, token and request fingerprint.
The first accepted reference wins. An identical token retry observes that
reference before preparation; a conflicting fingerprint rejects. A missing
reply leaves acceptance uncertain and requires inspection of that same token.
Staging alone neither accepts work nor authorizes dispatch.

Temporary transport/capacity failures retry observations and the same immutable
staging or token-binding request within the native request timeout and statement
deadline. A retry preserves the frozen intent, data-operation identity and token;
it never submits SQL as new work. Retained quota refusals, changed definitions
and authorization denial do not enter this availability retry. Exhaustion keeps
the original uncertainty and recovery identity.

Catalog owns the paged token, operation and pending indexes. Pending enumeration
reads eight entries per route and keeps at most 64 candidates for the account's
eight routes. Terminal history does not determine resident memory. A CAS update
records cancellation or removes settled work from the pending index. Cancellation
is sticky and settled entries cannot become pending. Settlement of a database
operation requires its owner's actual terminal observation; cached counts do not
authorize disclosure or manufacture success.

The account's operation, byte and pending budgets are fixed by its first
accepted binding. New acceptance checks and charges them in the same Catalog
WAL transition. A Table operation reserves 4608 bytes of account recovery content;
complete data intent bytes have their separate `intent_bytes` bound and storage
owner. External operations reserve their declared recovery budget. Settlement
releases pending capacity; retained identities and byte charges remain. A quota
refusal never expires accepted work. The node's catalog-wide token quota is an
independent upper bound, including internal recovery accounts.

Activation uses a domain-separated Catalog record containing the generation and
random runtime instance. A replacement requires a strictly higher generation
and CAS publication. Runtime requests carry the exact activation revision as a
signed request fence. The local host holds Catalog access through validation,
execution and disclosure; changing activation requires exclusive access.
Current authorization remains independent of this execution fence. A saved
record, local file or generation number never grants database access.

Single-partition DML uses `commit_saved`: the partition evaluates the complete
frozen intent and publishes its rows, indexes and outcome in one `TWAL1` append.
There is no intermediate Table admission record on this path. Catalog token
acceptance and pending-index settlement are separate durable decisions; this
is not a claim that an entire SQL request performs only one network request or
one WAL append across all owners. DDL and cancelled work retain their explicit
owner transitions. Lost replies recover the original owner outcome before any
further execution. Interactive transactions are not implemented here.

`ReadCache` retains up to 64 Table cuts in memory across the account and 64
Catalog recovery slots per connection route. A read checks the current definition and logical change
frontier, then borrows an unchanged cut without another pin or durable slot
write. Every page and buffered disclosure still checks current authorization.
A cold acquisition records its exact owner and expected cut before acquiring the
pin; a missing reply never permits substituting a new cut. Reuse is bounded by
cache capacity; active borrows cannot be evicted. Idle entries can be replaced,
and a new generation closes original pins using their recorded identities.
Closing a result releases its borrow; it need not release the cached durable pin.
There are no per-query SQL pin files or local fsyncs. The installer retains
recovery for disabled accounts with outstanding pins as well as pending writes.
Denied cleanup remains visible and does not authorize expiry.

Socket loss, timeout and stopping a wait are not rollback. The service continues
accepted work under current rights. A new statement without the original token
creates new work. Status, inventory, metadata preparation and source inspection
never dispatch work. Caller rights, accepted identity, owner completion and
transport delivery remain separate observations.

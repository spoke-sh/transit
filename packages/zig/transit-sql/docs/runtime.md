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
`commit_saved` resolves an original receipt before execution, so ordinary DML
recovery calls it directly without an additional pre-commit inspection request.
`DatabaseRuntime.submit` and the synchronous wire execution path attempt that
same operation in the submitting request, within the existing statement and
native request budgets. A successful foreground response projects the freshly
authorized owner outcome directly, without waiting for background enumeration
or another status RPC. The pending record supplies the original frozen reference
and current cancellation state. Foreground completion also attempts the Catalog
pending-index settlement. A failed or lost settlement reply preserves the known
terminal outcome and schedules recovery of the original token. Per-token
scheduling claims prevent background execution from racing its foreground owner;
these bounded in-memory stripes carry no durable authority. Concurrent identical
tokens still converge through Catalog, and replacement needs no old claim.
Terminal completion does not promise that failed pending-accounting cleanup has
finished. Status and lookup remain observation-only, and disclosure retains
current authorization.

Recovery discovers pending work in complete bounded pages on startup, then parks
when its obligations are settled. Notifications record a generation before a
sweep; a notification arriving during discovery remains outstanding for another
pass. Uncertain binding, cancellation, explicit resume, incomplete transaction
publication/cleanup and failed pin acquisition/release schedule work. Only
unresolved obligations use bounded retry delays. Denial or a failed scan cannot
certify an empty backlog. A crash loses the volatile signals, so replacement
always rediscovers the durable pending index and original read-pin slots.
Successful foreground DML does not require another recovery execution.
Foreground activation failures withdraw readiness and notify the same recovery
owner. A settled account's health observation is not a cached permission grant;
foreground execution and buffered disclosure still require current authority.

There is no intermediate Table admission record on this path. Catalog token
acceptance and pending-index settlement are separate durable decisions; this
is not a claim that an entire SQL request performs only one network request or
one WAL append across all owners. DDL and cancelled work retain their explicit
owner transitions. Lost replies recover the original owner outcome before any
further execution.

Interactive Table transactions use `TransactionWork` and the same Catalog token
and pending directories. A caller command reserves 37,376 bytes for its frozen
transaction request and outcome. BEGIN, private DML, savepoint controls and
settlement retain separate owner identities before dispatch. Recovery resumes
that recorded command without compiling SQL again. Fixed statement/control and
savepoint ceilings refuse before admitting another SQL command; storage or memory
unavailability preserves accepted work for original recovery.

The Catalog owns the common cut, private roots and commit decision. Session
attachment is temporary and can be explicitly restored through the shared client.
Private reads bypass `ReadCache` and use the original transaction pins and exact
workspace revision. Provisional counts do not establish commit; a decision may
be observable while background publication and pin cleanup are still pending.
See [Table transactions](../../../../docs/handbook/reference/sql/transactions.md)
for the executable domain, lifecycle and limits.

`ReadCache` retains up to 64 Table cuts in memory across the account and 64
Catalog recovery slots per connection route. A read checks the current definition and logical change
frontier, then borrows an unchanged cut without another pin or durable slot
write. Every page and buffered disclosure still checks current authorization.
A cold acquisition records its exact owner and expected cut before acquiring the
pin; a missing reply never permits substituting a new cut. Before an iterator or
result exists, a pin conflict permits another acquisition attempt only after
`pin_status` proves the original owner absent at a strictly later frontier. The
old exact request cannot then succeed, even if delayed. The service records its
closure, rechecks the same Table definition and tries a fresh acquisition, with
at most four attempts. An existing pin, uncertain observation, definition change
or exhausted bound ends preparation without switching an accepted cut. Reuse is bounded by
cache capacity; active borrows cannot be evicted. Idle entries can be replaced,
and a new generation closes original pins using their recorded identities.
Closing a result releases its borrow; it need not release the cached durable pin.
There are no per-query SQL pin files or local fsyncs. The installer retains
recovery for disabled accounts with outstanding pins as well as pending writes.
Denied cleanup remains visible and does not authorize expiry.

Only the acquisition identity and expected cut require a durable cache record;
the returned handle stays in the resident entry. Recovery resolves that same
identity with `pin_status`, including when the acquisition reply was lost. An
unborrowed stale cut for the same Table is replaced before consuming another
empty slot. Eviction still records closure before releasing a pin. Startup
reconciliation scans each route's bounded slots; successful sweeps stop until
an acquisition or cleanup failure requires another pass. Each recovery turn bounds both operation work and pin reconciliation.

Socket loss, timeout and stopping a wait are not rollback. The service continues
accepted work under current rights. A new statement without the original token
creates new work. Status, inventory, metadata preparation and source inspection
never dispatch work. Caller rights, accepted identity, owner completion and
transport delivery remain separate observations.

Managed Table reconciliation scans paged declaration tokens, advances one work
unit per computation and rotates through configured database routes. The finite
query unit has explicit work/memory/spill/output budgets; output statements and
common decision cleanup advance separately. Coalesced local publication hints
wake reconciliation after Table/KV/catalog or policy mutations. Hints carry no
authority or cursor and may be duplicated; restart discovery uses durable heads.
Settled computations park without polling, and shutdown joins the hint waiter.
The [managed Table profile](../../../../docs/handbook/reference/queries.md#managed-table-computations)
distinguishes control acceptance, first result, blocked work and retirement.

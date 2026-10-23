# SQL session v1

This contract defines the native SQL session interface above Fuze and public
native clients. The [types](../packages/zig/transit-sql-protocol/src/root.zig)
own message shapes; the [generated route and message description](sql-session-v1.schema.json)
is derived from those types.
The shared [definition](../packages/zig/transit-protocol/src/Growth.zig) is
mandatory on every request and response. Its exact spelling is checked before
execution. A version number alone does not establish compatibility.

The native, PostgreSQL and MySQL adapters use the shared SQL execution package.
The database wire contracts remain
in [SQL gateways](SQL_GATEWAY_V1.md).

## Transport and authentication

Requests use HTTP/1.1 POST with `application/json`, bounded Content-Length and
no content encoding. `/v1/sql/session` admits data and authentication work;
`/v1/sql/control` independently admits cancellation, observation, resume and
closure. The body action must match the selected lane. Duplicate security or
framing headers, ambiguous framing, redirects, browser Origin and forwarded
identity headers are rejected. Responses carry `Cache-Control: no-store`.
There is no cookie authentication, automatic redirect or automatic SQL replay.
Connection reuse is an optimization, never a session identity. Idle HTTP headers
have a one-second deadline; clients replace a quiescent transport before sending
new work. This does not replay a request. Fixed byte identities and SQLSTATE use
JSON integer arrays even when their bytes form printable text. Text fields use
JSON strings. The canonical authentication binding uses a compact JSON array of
its five fields with these same rules.

Remote exposure is explicitly configured. HTTPS uses verified certificates and
system roots or a configured CA. Password accounts authenticate with
SCRAM-SHA-256, using the existing printable-ASCII password/verifier profile.
`hello` reports the exact definition, persistent server instance and bounds.
`open` selects account, database and optional service-owned source binding.
The SCRAM challenge includes `b=<lowercase SHA-256 hex>` in its server-first
message. This commits the authenticated transcript to the canonical encoding
of definition, instance, account name, database and source. The client verifies
this binding and the server-final proof. Authentication challenges expire,
consume bounded slots, and can be completed once. Credentials are revalidated
before opening and on subsequent protected operations.

Explicit trust authentication is restricted to configured loopback listeners.
Local native carriage uses HTTP on a private Unix socket. Peer authentication
uses the operating system's socket peer credential and the configured owner UID;
request fields and forwarding headers cannot assert that UID. Peer accounts do
not permit TCP trust or password login implicitly.

`opened` returns a random 256-bit secret session handle, account identity and
selected database. Handles are credentials and must not appear in logs, URLs or
error text. Subsequent requests name the persistent instance and session.
A mismatched instance rejects before account work. Restart invalidates temporary
handles, even when it preserves the persistent instance and operation history.

## Lifetimes and concurrency

A logical session belongs to the SQL service, independently of any HTTP socket.
Its settings, prepared metadata and read cursor survive transport replacement.
The finite idle lease uses the gateway's `limits.session_lease_ms` (30 seconds
by default), configured locally as `sql.native.session_lease_ms`. It is independent
of `sql.idle_ms`, which controls PostgreSQL/MySQL wire connections.
`touch` renews the idle lease after checking current credentials and database
authority; it does not reset settings or replace an active result.
Closing an HTTP socket does not close the session. Closing/resetting a session,
its idle lease expiring or the service restarting releases temporary state.
PostgreSQL and MySQL adapters tie logical session closure to their wire connection.

Each enrolled account has one active fenced runtime, coordinated principal
sequences and a durable ledger. Sessions share this owner, never its private keys.
One session has one borrower of each native transport and at most one active
interactive result. Concurrent commands on that session return busy; commands on
other sessions retain their own bounded execution slots. A cancellation request
can set the current query's cancellation flag without borrowing its transport.
A query target of 32 zero bytes means the current request of this authenticated
session, including execution before its first response. Other query targets
identify that session's result cursor.
Tasks are joined before releasing their sockets, allocator, snapshot or spill.

Preparation discloses authorized metadata without opening a snapshot. `prepare`
returns a temporary statement handle, result schema and parameter descriptors;
`describe` rechecks authority. `release` closes a prepared handle. `execute`
accepts SQL directly or a prepared handle, and typed bound parameters. Native
mutations require an admission token and SQL text so retries remain meaningful
after a session disappears. The client can retain preparation for reads without
making it durable. Adapter-specific admission restrictions remain in the wire
adapters; the native codec preserves Fuze logical types.

## Logical results and fetch acknowledgement

The selected encoding is `transit.logical.v1.hex`. Schema fields contain
lowercase hexadecimal of the existing FTY1 logical descriptor. Each row contains
one lowercase hexadecimal canonical schema-bound cell per field. Parameters
contain standalone FVL1 values with descriptors. Integer and decimal values do
not pass through JSON floating-point conversion. Nested containers, binary,
NULL, missing, type errors and conflicts retain their logical distinction.
The schema descriptor and cell codecs validate their existing recursion, child
and byte bounds. Unknown tags or noncanonical hexadecimal reject.

An interactive execute returns its schema, cursor and initial batch numbered
zero. Fetch requests name the next desired batch. Requesting the last returned
batch repeats its exact retained data after a fresh authorization check.
Requesting its successor acknowledges that batch and advances the same iterator;
all other ordinals reject. At most one unacknowledged batch is retained per
cursor. A duplicate concurrent fetch cannot advance the iterator twice.
The final batch remains repeatable until closed or expired.
Each data result carries its source basis: an explicit source cut, a retained
Table cut, or an ordered independent-Table snapshot vector. A Table basis binds
its catalog/branch/object, exact definition, physical and logical frontiers,
retained pin content, source commitment and schema. Independent Table cuts do
not establish a common catalog-wide snapshot; repeated aliases share one pin. Settings and inspection results
have no retained data basis. A basis identifies observed data; it grants no access.

Lost/expired session or cursor state reports an incomplete result. The server
never reopens a snapshot or silently skips to a new cut. A new session cannot
resume an ordinary interactive SELECT. Explicit captured execution uses its
separate durable query owner and operation reference.

## Durable admission and recovery

The account-scoped token is a caller-generated 128-bit value. Its durable index
commits the request fingerprint and original operation identity. The fingerprint
covers instance, account, database/source binding, SQL text, canonical logical
parameter encodings and execution mode. The account ledger fixes the signing
principal and role; changing the binding does not inherit an existing operation.
Concurrent identical tokens bind to one operation. Different content conflicts.
SQL text equivalence is never inferred.

Admission has distinct observations:

- `reserved`: an identity and quota are durable; there is no complete intent.
- `uploading`: immutable intent publication is incomplete or awaiting validation.
- `ready`/`active`: complete validated intent is accepted for execution.
- `terminal`: the original domain outcome is recorded and currently authorized.
- `abandoned`: unpublished work was closed without executing it.

Only a complete frozen intent can become accepted execution. Retries return the
original identity and state; they never compile fresh SQL for an existing token.
A reservation interrupted before publication can remain incomplete. Status does
not turn incompleteness into absence or dispatch new work. Explicit resume and
the recovery worker act only on the original published intent reference. Complete
content staging, reference publication, committed dispatch eligibility, direct
admission and terminal evidence are separate boundaries. A private native control
receipt alone does not establish Table acceptance.

Operation identity includes the persistent server instance in the envelope,
account identity, owner kind and durable ID. `status` accepts a known operation
or token. `operations` pages account-scoped history by its append-only ID.
A caller that lost all correlation can inspect this history and select an
operation explicitly. The server never matches operations by similar SQL.
The index stores Table, configuration and captured-query references together.
Configuration references retain the original 128-bit reload identity, selected
binding and expected configuration generation. `owner_operation` exposes that
identity; `configuration_phase` distinguishes applying, applied, pending restart,
rejected and partial. Observation does not reload. Resume submits the original
owner request; configuration cancellation is unsupported. This does not create a
cross-domain transaction.

Captured execution requires a service-owned source binding and a token. The
ledger reserves its original query namespace and publishes the exact compiled
bundle before native Query admission. Each signed upload/control request is
published in paged ledger storage before dispatch. The service records receipt
and processed-input evidence before releasing that source's sequence lane.
Generation fencing rejects stale publication; a replacement resumes the same
published bytes. An incomplete, unpublished step can be abandoned and prepared
again; a published request cannot. An incomplete initial bundle is reported as
blocked and can be cancelled, never recompiled from token reuse.

`result` opens a new temporary result cursor for a complete captured operation in
the selected source binding. Current Query-owner authorization and its complete
manifest determine disclosure and coverage. Fetch acknowledgements are identical
to interactive results. After disconnect/restart, a caller can authenticate again,
inspect the original token and open the retained result from its beginning.
Cancellation first settles any published request, then uses the Query owner's
cancel operation; it does not continue an unfinished upload.
An operation can carry its currently authorized owner diagnostic, including the
captured query's failure stage, source witness and budget dimension. This is
recorded domain evidence, distinct from a transport error or a pending status.

`context` lists currently authorized service-owned source names for the selected
database. Source bindings contain the server's connection, key reference, decoder
or Table/Document definition, SQL alias and budgets. Clients supply only the name.
The source caller has a dedicated principal sequence and the SQL account's login
role and selected database role. A declaration alone grants no native access.

Accepted work survives session closure, transport loss, idle expiry and service
replacement. Cancellation follows the owning domain's publication rules and
does not promise rollback or external cancellation. Sending the same SQL again
through PostgreSQL or MySQL creates new work; their wire protocols do not carry
this native admission token.

## Authority, bounds and failure

Errors before durable admission, including invalid session settings and SQL
validation, do not request operation observation. Errors while locating an
existing token, admitting work or observing accepted work can require checking
the original token. A conflicting token is rejected and never substitutes the
original statement's result for different SQL.

Current account enablement, credential epoch, selected role and object rights
are checked before protected metadata, each result batch (including repeats and
empty results), and terminal counts. The service clears protected buffered state
when validation fails. Knowledge of a handle does not transfer account authority.
Session expiry does not retire the account or expire durable history.

Messages are at most 4 MiB, SQL at most 64 KiB, batches at most 1 MiB of encoded
logical payload and 32 rows, and parameters at most 65. Prepared handles, active
sessions, per-account sessions, handshakes, in-flight data/control requests,
resident memory, spill, execution time and idle leases have explicit bounds.
Durable quotas reserve space before admission and do not bound collection size
with resident arrays. Pressure cannot delete accepted operations.
Each captured operation reserves 1 MiB of retained ledger content, with at most
1024 finite publication attempts; incomplete proposals consume that reservation.
This is an operation bound, not a bound on account history. Source declarations
are limited to 32 per account. An account's capture lane serializes submission
steps; query execution and result reads remain with their independent owners.

Errors contain a bounded code, SQLSTATE, safe message, retry classification and
optional original operation observation and structured owner diagnostic. They do not contain SQL text, stored value payloads,
passwords, session secrets or private paths. A transport failure cannot establish
whether a mutation was accepted. Clients recover by the original token on the
same instance; arbitrary request retries are not a transport policy.

## Assistance coverage

`assist` is read-only grammar and currently authorized metadata acquisition.
Its required `coverage` is `complete` or `limited`; `status` is `ready`,
`inside_text` or `unsupported`. Empty limited results do not establish absence.
Only a complete, ready one-item result establishes a unique matching candidate.
At most eight ranked candidates and 128 catalog pages are retained/acquired per
request. The range uses UTF-8 byte offsets in the original input; context is the
active statement at the cursor, including its suffix. Completion never executes
statements, samples row values or grants permission to execute a suggestion.
Settings contexts use the authorized configuration owner. Transport failure is
unavailable acquisition, never an empty complete result.

The assistance coverage cutover replaces the shared native definition. Missing
coverage/status and foreign definitions reject; there is no fallback decoder.

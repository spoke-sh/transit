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
The [logical result contract](SQL_RESULTS_V1.md) defines statement outcomes and
consumption independently of this carriage.

## Transport and authentication

Requests use HTTP/1.1 POST with `application/json`, bounded Content-Length and
no content encoding. `/v1/sql/session` admits data and authentication work;
`/v1/sql/control` independently admits cancellation, observation, resume and
closure. The body action must match the selected lane. Duplicate security or
framing headers, ambiguous framing, redirects, browser Origin and forwarded
identity headers are rejected. Responses carry `Cache-Control: no-store`.
Control responses use `application/json`. Result batches use
`application/vnd.transit.sql-result` with the binary framing below. Both require
an exact bounded Content-Length and identity content encoding. Content type
selects the decoder; a JSON batch is invalid. Compression is not supported by
this profile.
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

Each enrolled account has one active fenced runtime, a Catalog activation revision
and paged database recovery. Sessions share this owner, never its private keys.
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

Prepared descriptions always include `schema`. It is null when the statement
returns no rows, including DML and schema commands; parameters and the mutation
flag remain explicit. Row-returning statements have a logical schema even when
execution returns zero rows. No empty logical structure stands in for command
completion.

The native profile accepts CREATE SCHEMA, ALTER SCHEMA ... RENAME and DROP SCHEMA
RESTRICT through the direct catalog. Preparation freezes the expected schema and
requested owner without allocating IDs or publishing work. Catalog accepts a SQL operation ID bound to the complete frozen intent.
CREATE retains its independently prepared schema ID in that original intent. Its `GIR1` reference carries the session's selected
namespace separately from the changed namespace binding. Current database/schema
ownership and requested-owner SET eligibility are checked by the existing native
authority. Registration, direct acceptance and SQL recovery settlement remain
separate recoverable decisions. Namespace completion has zero matched/changed
rows and a catalog position; the shared completion kinds are `create_schema`,
`alter_schema` and `drop_schema`. Current rights govern all outcome disclosure,
including retired schemas. A prepared schema cannot follow name replacement or
definition drift. Rejected and cancelled schema outcomes include an owner-projected
diagnostic; dependency rejection does not disclose the blocking object's identity.
These forms do not execute through the PostgreSQL/MySQL profile
and do not change a session's configured namespace.

## Logical results and fetch acknowledgement

The selected result encoding is `transit.sql.result.v1.binary-columns`. Result
schemas carry raw FTY1 descriptors and values use binary columns. Integer and
decimal values do not pass through JSON floating-point conversion. Nested
containers, binary, NULL, missing, type errors and conflicts retain their logical
distinction. Prepared metadata descriptors and standalone FVL1 parameters still
use canonical lowercase hexadecimal in their JSON control messages. Their
existing recursion, child and byte bounds apply.

Every result body starts with this 192-byte header. Integers are unsigned,
little-endian; byte identities retain their exact bytes.

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | `TSR1` |
| 4 | 32 | Shared current definition, decoded from its hex identifier |
| 36 | 16 | Persistent server instance |
| 52 | 32 | Result cursor |
| 84 | 8 | Batch ordinal |
| 92 | 4 | Logical rows in this batch |
| 96 | 4 | Flags: 0 for data, 1 for verified terminal |
| 100 | 8 | Cumulative terminal row count, zero unless terminal |
| 108 | 32 | SHA-256 of the canonical FTY1 schema |
| 140 | 32 | SHA-256 of the canonical observation JSON |
| 172 | 4 | Schema byte length |
| 176 | 4 | Observation byte length |
| 180 | 4 | Column count |
| 184 | 8 | Zero reserved bytes |

Ordinal zero includes the schema immediately after the header, followed by
canonical observation JSON. Subsequent ordinals set both lengths to zero and
retain the two commitments. The reader validates the initial descriptors against
those commitments before exposing rows. Schema is at most 16 KiB, observation at
most 64 KiB. Observation JSON uses the shared type's declared field order and
compact serialization. A descriptor commits meaning; it does not grant access
or retain a source.

The descriptors are followed by one eight-byte directory entry per column:
absolute `u32` offset and `u32` byte length. Zero padding aligns the first column
and each following column to 64 bytes relative to the body. Columns appear in
schema order, without gaps other than canonical zero alignment padding. The last
column's padding ends the body exactly. Each column is a current-definition
plain TCP1 page, using the [physical column layout](TRANSIT_STORAGE_V1.md#qualified-plain-value-buffers)
without acquiring storage identity. Its row count must match the frame. Common
scalar types use aligned Arrow-compatible validity, offset and value buffers;
other types use canonical schema-bound cells. State tags and error/conflict
details are always retained. The decoder validates every lane and the logical
field's optionality, nullability and type before disclosure.

A nonempty batch has one column per schema field. An empty terminal batch has
zero columns and retains the schema/observation commitments. At most 32 rows and
1 MiB of canonical schema-bound cell bytes are admitted per batch, independent of
physical framing. The full HTTP body remains bounded at 4 MiB. HTTP receivers
allocate the body at 64-byte alignment; borrowed columns remain valid only while
that response owner lives. There is no hex decoding or row matrix required for
common scalar result columns. Receiving bytes from the socket and constructing
server columns still involve copying; this is not an end-to-end zero-copy claim.

An interactive row-returning execute returns its schema, cursor and initial batch numbered
zero. Fetch requests name the next desired batch. Requesting the last returned
batch repeats its exact retained data after a fresh authorization check.
Requesting its successor acknowledges that batch and advances the same iterator;
all other ordinals reject. At most one unacknowledged batch is retained per
cursor. A duplicate concurrent fetch cannot advance the iterator twice.
The final batch remains repeatable until closed or expired. Every batch carries
the same observation commitment and an explicit terminal flag. The shared API
projects that flag into nullable `completion`. Completion contains the cumulative unsigned 64-bit
logical row count; checked arithmetic rejects overflow. Repetition does not add
to this count. The client compares it with uniquely received rows before exposing
successful completion. Empty terminal batches are valid after earlier data and
do not begin another result. Missing completion, EOF and closure never establish
exhaustion. A known final data batch carries completion directly.

Each data result carries an `observation.data` basis: an explicit source cut, a retained
Table cut, or an ordered independent-Table snapshot vector. A Table basis binds
its catalog/branch/object, exact definition, physical and logical frontiers,
retained pin content, source commitment and schema. Independent Table cuts do
not establish a common catalog-wide snapshot; repeated aliases share one pin.
`observation.metadata` distinguishes catalog, settings, prepared plan and probe
observations. DESCRIBE and EXPLAIN identify their exact prepared definitions;
source inspection identifies its declared source contract and schema. Paged
catalog relations declare independent observations, with no invented global cut.
Settings identify the observed configuration revision, when a page was read, and
the session-settings commitment. A metadata descriptor is not a retained data
snapshot. Observation and schema remain identical throughout a cursor, including
repeats and terminal responses. A basis identifies observed data; it grants no access.

Command replies carry `CommandCompletion`: typed command kind, domain outcome,
applicable matched/changed counts, original operation identity where applicable,
pending-restart state and an authorized diagnostic. Session SET, RESET and empty
statements have no durable operation or row counts. Empty statements complete
unchanged without fabricating a zero-column relation. Durable Table/schema
commands expose their original owner's counts, including authoritative zero
counts for declarations. Configuration and captured commands have no row counts.

Lost/expired session or cursor state reports an incomplete result. The server
never reopens a snapshot or silently skips to a new cut. A new session cannot
resume an ordinary interactive SELECT. Explicit captured execution uses its
separate durable query owner and operation reference.

## Durable admission and recovery

The account-scoped token is a caller-generated 128-bit value. Its durable index
commits the request fingerprint and original operation identity. The fingerprint
covers instance, account, database/source binding, SQL text, canonical logical
parameter encodings and execution mode. The Catalog binding fixes the signing
principal and role; changing the binding does not inherit an existing operation.
Concurrent identical tokens bind to one operation. Different content conflicts.
SQL text equivalence is never inferred.

Admission has distinct observations:

- `ready`: complete validated intent and its token are durably accepted.
- `uploading`/`active`: an explicit captured Query owner is progressing its work.
- `terminal`: the original domain outcome is recorded and currently authorized.

Database admission never exposes a reserved or partial-upload SQL operation.
Complete intent staging precedes token acceptance. Unreferenced staged content
is not accepted work.

Only a complete frozen intent can become accepted execution. Retries return the
original identity and state; they never compile fresh SQL for an existing token.
A reservation interrupted before publication can remain incomplete. Status does
not turn incompleteness into absence or dispatch new work. Explicit resume and
the recovery worker act only on the original published intent reference. Complete
content staging, reference publication, committed dispatch eligibility, direct
admission and terminal evidence are separate boundaries. A private native control
receipt alone does not establish Table acceptance.

Operation status requires a nullable `command` field. Table commands derive it
from the retained typed intent once published; it is absent while that intent is
unavailable. A terminal operation supplies it. Configuration and captured owners
report `reload` and `capture`. Neither a client nor a renderer reparses SQL to
guess the command kind. Terminal status projects to the same command completion
whether observed immediately, through the original token, or after replacement.

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

Captured execution requires a service-owned source binding and a token. Catalog
accepts the exact compiled bundle and original Query namespace before native
Query admission. Each complete signed upload/control request is published in a
Catalog recovery record before dispatch. A CAS source lane retains that request
through uncertain sends and records receipt and processed-input evidence before
allowing its successor. Status does not create a lane. A replacement resumes the
same published bytes; it never recompiles the token's SQL.

A captured Table bundle freezes its direct data interpretation, expected cut,
executor and pin operation before Catalog publication. The native source resource
holds computation progress independently of the catalog's data resource. Recovery
uses the published delegation; observing or resuming an operation does not capture
current data again. Interactive Table sources use Catalog-owned cached direct pins whose
original connection and current configured credential govern cleanup.

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
Metadata batches retain bounded authority subjects for their catalog rows and
configuration-origin fields. Their checks run again after materialization and
before repetition; the enclosing session grant alone is insufficient.

Messages are at most 4 MiB, SQL at most 64 KiB, batches at most 1 MiB of encoded
logical payload and 32 rows, and parameters at most 65. Prepared handles, active
sessions, per-account sessions, handshakes, in-flight data/control requests,
resident memory, spill, execution time and idle leases have explicit bounds.
Durable quotas reserve space before admission and do not bound collection size
with resident arrays. Pressure cannot delete accepted operations.

The server batch builder has independent row/byte limits and copies borrowed
source rows before another pull can reset scratch memory. It can span storage
pages or execution vectors. A row that does not fit the remaining byte budget
stays with its bounded source state for the next batch. A row too large for an
empty batch fails explicitly. Builder rows, retained source state, replay data
and serialization all remain charged to the session's resident allocator.
Each captured operation reserves 1 MiB of retained recovery content, with at most
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

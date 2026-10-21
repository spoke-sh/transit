# Database wire adaptation v1

This contract defines the shared gateway library, PostgreSQL/MySQL sessions,
typed message/scalar codecs and signed account recovery. The
[gateway application](../apps/transit-sql-gateway/README.md) composes those owners
with explicitly configured transport and login policies. Codec acceptance alone cannot admit a durable
write. Executed evidence belongs to the
[proof ledger](../tests/README.md).

## Common values and resource budgets

`transit-sql-gateway.Type` admits exactly int64, uint64, finite float64, Boolean,
UTF-8 and binary logical descriptors. Nullability is independent of the type.
Values retain exact integer sign/range and finite floating-point checks. Missing,
type-error and conflict cells never encode as SQL NULL. Other stored descriptors
return `UnsupportedWireType` at this boundary.

The shared prepared-scalar binder limits each UTF-8 or binary parameter to 4096
bytes. This is a per-value bound, independent of the frame/session ceilings and
the account's admitted intent size. Over-limit bindings reject before dispatch.
Stored results remain subject to their logical codec, query and output-frame
bounds; a larger frame budget does not enlarge the prepared-scalar profile.

`Limits.validate` checks the following default configuration and ceilings.
These are operation/resident bounds, independent of retained Table cardinality.
The application owner must enforce admission and use these limits at each I/O
and allocation boundary; constructing a Limits value does not reserve capacity.

| Bound | Default | Ceiling |
| --- | ---: | ---: |
| Connections | 64 | 256 |
| Connections per account | 8 | Total connection bound |
| Concurrent authentication attempts | 4 | 16, within the connection bound |
| Prepared statements per session | 16 | 64 |
| Portals per session | 4 | 8 |
| Frame length | 4 MiB + 8192 bytes | Same |
| Extended-cycle bytes | 4 MiB + 8192 bytes | Twice the frame ceiling |
| Extended-cycle messages | 64 | 256 |
| Session allocator budget | 16 MiB | 64 MiB |
| Handshake / command / idle / write deadline | 5 / 30 / 30 / 5 seconds | 270 seconds each |

Every configured bound is positive. A cycle accommodates at least one frame and
fits the session budget. SQL text remains at most 4096 bytes. The common maximum
parameter count is 256; the owning SELECT/DML compiler can impose a tighter
syntax/plan bound. The constants reserve at most 63 bytes for account/database/statement/portal
names and 32 configured accounts. Their owning session/configuration APIs must
enforce these ceilings; Table identifiers retain the SQL owner's limits. These
constants do not bound durable operation history.

The application enforces one account runtime independently of sockets, a bounded
session allocator, at most one borrowed output row and direct write backpressure.
Two extra transport slots are reserved for PostgreSQL cancellation; they cannot
authenticate ordinary sessions. Absolute command deadlines join native and socket
work before freeing borrowed state. Metadata-only preparation/validation retries
at most 64 exact-current revision races within the same deadline; query iteration
and SQL mutations are never transparently replayed.

Interactive reads admit at most 10000 output rows, 16 MiB result bytes and 10000
native requests. Relational reads additionally bound resident/spill bytes to
16 MiB each, work to one million steps, source pins to two and spill operations to
10000. Limits fail explicitly; a suspended portal retains its original snapshot
and lease rather than opening a new cut. These per-query budgets are subordinate
to the session allocator and the native snapshot owner's lease/resource quotas.

## Transport and login policy

`tls_mode` selects `disabled`, `optional` or `required` (default). Disabled TLS
has no PEM dependency. Optional TLS requires valid TLS material before binding
and accepts encrypted or plaintext startup on the same listener. Required TLS
rejects plaintext before login; it never downgrades after TLS negotiation fails.

Accounts select `password` (default) or explicit `trust`. Trust requires an IPv4
loopback bind address and maps only a configured enabled SQL name to its native
principal. It accepts the claimed name without checking an OS identity. Its
credential record has a null verifier but still binds account fingerprint,
native principal, login role, credential epoch and revision. Password accounts
require a non-null verifier. Both methods perform the same current native login,
database and disclosure checks. No network input selects another native identity.

PostgreSQL rejects GSS encryption with `N`; SSLRequest receives `N` for disabled
TLS or `S` followed by TLS negotiation otherwise. Plain StartupMessage is accepted
only for disabled/optional TLS. Trust proceeds directly to AuthenticationOk after
native admission; passwords use SCRAM-SHA-256 over either permitted transport.
MySQL advertises CLIENT_SSL only when TLS is enabled. A plaintext response and a
TLS SSLRequest have separate bounded parsers. Trust receives OK after native
admission without a full-password request. MySQL password authentication requires
TLS; with optional TLS an unencrypted password login fails before requesting the
password. Configuring MySQL password accounts with disabled TLS rejects.

## Credential verification

A verifier contains mandatory version 1, the current native definition,
iterations, a 16-byte salt, 32-byte StoredKey and 32-byte ServerKey. Derivation is
PBKDF2-HMAC-SHA-256 followed by the SCRAM Client Key/Server Key derivations.
Iterations are 4096–262144, default 65536. The password profile is 1–128 printable
ASCII bytes (U+0020–U+007E). SASLprep is the identity on this profile; unsupported
codepoints reject rather than changing password bytes.

The SCRAM owner accepts `n,,` and `y,,` GS2 headers, a bounded client-first bare
message and a 16–256-byte printable nonce excluding commas. It appends 24 Base64
characters from 18 secure random bytes supplied by the I/O owner. The exact
client/server-first and client-final-without-proof bytes form AuthMessage.
The final message must match the original GS2 header and combined nonce, with a
canonical Base64 32-byte proof. Constant-time StoredKey comparison precedes the
server proof. A finish attempt consumes the state on both success and failure;
`deinit` erases retained key/proof material. SCRAM-SHA-256-PLUS is unsupported.
PostgreSQL's startup account selects the verifier; the SCRAM name does not select
another identity.

The same verifier can check a full plaintext password received inside an already
established TLS session, for MySQL's full caching_sha2_password exchange. The
caller owns TLS admission, secure randomness, credential revision/rotation,
authentication concurrency and erasure of the received password buffer. No fast
authentication cache or unencrypted RSA-password exchange is implemented here.

SQL account verifier files additionally bind their account fingerprint, native
principal, login role and credential epoch. A valid password alone supplies no
privileges. Session establishment and protected disclosure validate that binding
against native authority and require current database CONNECT. Database mappings
fix a schema namespace and eligible selected role; the operation ledger retains
both, independently of the connection lifetime.

The private reader identity supplies catalog storage bytes and exact admission
inspection. The Table caller supplies the signed subject used by the common
catalog/query evaluator; the reader's raw-resource grants cannot satisfy that
subject's missing Table privileges. SQL users need no raw-resource grants.
Immutable signed steps retain their own signing key. Credential rotation does
not change the ledger's identity or replace those signatures; exact receipt
recovery precedes any retry under the original request bytes.

## PostgreSQL frame and cycle ownership

Startup frames carry a four-byte big-endian total length of at least eight bytes,
then a code/version. SSLRequest and GSSENCRequest have length eight; the selected
v3.0 CancelRequest has length sixteen. Typed frames carry a one-byte type and a
four-byte big-endian length including that length field. Values below four,
above signed int32 or above the configured budget reject before allocation.
A complete decoded frame borrows its exact payload and reports consumed bytes;
a partial frame returns no message. The transport wrapper reads only its exact
header/payload and returns an independently owned bounded buffer.

Startup acquisition is separately limited to 8192 bytes and 16 name/value pairs.
Keys are at most 63 bytes and values at most 256 bytes, with valid UTF-8, no
duplicate keys and one exact terminating zero byte. `user` is mandatory and
nonempty; `database` defaults to that user only when absent. Account/database
names remain at most 63 bytes. Major versions other than 3 reject; the requested
minor is retained for deliberate session negotiation. Parsing supplies no
account permission and does not accept or apply arbitrary settings.

The deterministic cycle gate accepts metadata-only Parse/Bind/Describe/Close
work and one execution. Execute of a write only records deferred admission;
only a subsequently validated Sync returns `sync_write`. Any intervening message
including Flush or another Execute fails that cycle before write dispatch.
A write Execute with a row limit rejects. Reads may execute/resume one portal;
resumption requires its suspended state and exact identity. A read cycle cannot
later admit a write. Sync clears the gate. Failed cycles ignore all messages
except Terminate and Sync; Sync returns an empty completion action.

The adapter must validate message bodies before acting on gate results, discard
candidate writes after any validation failure and destroy portals at Sync. Named
statement lifetime belongs to the session owner. Invalid framing closes the
connection, because a body boundary cannot be trusted. A gate action is neither
authorization nor a native receipt. The backend protocol's full transaction and
pipeline semantics are outside this explicitly selected autocommit cycle.

`Frontend.decode` validates complete Query, Parse, Bind, Describe, Close,
Execute, Sync, Flush and Terminate bodies, including trailing bytes, names,
UTF-8, parameter counts and format codes. Input slices borrow the bounded frame;
the session must own any bytes retained beyond it. Bind distinguishes NULL from
empty bytes. Formats have zero, one or exactly the affected number of entries;
the caller validates result formats against the prepared output schema. Parse
OID count/inference and Bind parameter count are checked against that statement
by the session owner. `saslInitial` admits only bounded SCRAM-SHA-256 payloads.

| Logical type | Result OID | Text | Binary |
| --- | ---: | --- | --- |
| int64 | 20 | Signed decimal | Signed eight-byte big-endian |
| uint64 / counts | 1700 | Unsigned decimal | Positive numeric, scale zero, base-10000 digits; `numeric(20,0)` modifier |
| finite float64 | 701 | Decimal floating point | Eight-byte IEEE big-endian |
| Boolean | 16 | `t` / `f` | Exactly zero or one |
| UTF-8 | 25 | UTF-8 without NUL | Same |
| Binary | 17 | `\\x` followed by hex | Exact bytes |

Parameter OID zero infers the canonical type. Signed integer OIDs 21/23/20
admit lossless int16/int32/int64 representations for int64 or nonnegative uint64;
numeric OID 1700 is also available for uint64. Numeric parameters have integer
scale and a maximum of five base-10000 digits; negative, fractional, special and
overflow values reject. Float OIDs 700/701 preserve their declared width before
widening to float64. UTF-8 accepts OIDs 25/1043. Other cross-kind conversions
reject, including an incompatible declared OID on a NULL parameter. Text integer
parameters obey their declared width. SQL constraints remain the compiler's
responsibility. Bytea text decoding allocates in the supplied allocator; other
variable-sized inputs borrow their frame. Encoders append a non-NULL payload;
the row owner supplies length or NULL framing and bounds the aggregate message.

`Backend` emits complete bounded frames with the same scalar codecs. Row
descriptions use zero table/attribute OIDs because native Table identities are
not PostgreSQL OIDs. uint64 metadata retains `numeric(20,0)` even for empty
results. Data rows use -1 for NULL and validate every cell's logical descriptor;
missing, type-error and conflict remain errors. Completion counts stay u64, and
INSERT uses the protocol's zero OID. The caller selects matched counts for UPDATE
only after observing original terminal evidence under current rights.
ReadyForQuery emits idle status for the selected autocommit profile. The protocol
negotiation response selects minor 0 and four-byte backend cancellation secrets.
Error fields carry validated five-character SQLSTATE, severity, a bounded safe
message and optional safe detail. This encoder does not decide authority,
transaction outcomes or which errors may be disclosed.

## Shared statement ownership

`Statement` owns immutable prepared SQL, catalog identity and output/parameter
metadata. Bind validation submits no native input and opens no data snapshot.
Every metadata disclosure rechecks current rights and the complete Table binding.
Execution uses the shared query owners with a fresh authorized cut, or binds a
new Table intent to its reserved gateway operation identity. Literal relational
SELECT resolves every target through the explicitly selected catalog; captured
descriptors must match preparation before executor work. Parameters are confined
to the shared single-Table SELECT/DML profile. MySQL quoting is handled by the
shared lexer for SELECT, DML, CREATE and literal relational SQL.

`Read.nextBatch(maximum)` borrows at most one to eight rows until its next call
or close. The single-Table path owns at most 16 MiB of canonical cells per batch;
other read owners may return a smaller batch. The host validates current account,
statement and scoped query authority after materialization, before any row in
that batch is transmitted. Empty and final output require the same validation.
A batch is one bounded disclosure; later batches observe current rights again.
PostgreSQL also limits the request to the remaining rows in this Execute. No
authorized output batch survives portal suspension. MySQL repeats bounded pulls
within the command deadline. Transport failure closes the exchange without
replaying any partially transmitted batch.

## MySQL frame ownership

`Handshake.upgrade` accepts exactly 32 Protocol 4.1 SSLRequest bytes. The full
response must retain flags, packet limit and encoding across TLS. The selected
flags include found-rows, optional database, plugin authentication, bounded
attributes and optional deprecated-EOF framing. Protocol 4.1, SSL, secure response
layout and plugin authentication are mandatory. The intersection of the server
advertisement and known client offers selects behavior; reserved extension bits
reject. Offers for unadvertised features do not enable SQL syntax, compression,
LOCAL INFILE, multiple results or query-attribute layouts. Multi-statement SQL
and unsupported command layouts reject before execution. This includes the
pinned Connector/Python's default multi-statement offer. UTF8MB4 negotiation accepts
charset bytes 45, 46 and 255; logical comparisons and UTF-8 column metadata retain
collation 309. Attributes are ignored only after validating at most 4096 bytes,
32 pairs and 1024 bytes per name/value. Authentication proof is empty, a single NUL for an absent password, or
32 bytes; the full password follows only after TLS and an explicit auth request.

`Backend` emits bounded HandshakeV10, prepare, metadata, text/binary rows,
classified errors and negotiated EOF/OK frames. A binary result bitmap reserves
the first two bits. Non-SQL NULL states fail encoding. Sequence numbers wrap
modulo 256 only after a complete packet is built; failure clears the packet.
Replies report autocommit status without a transaction or subsequent results.
Affected rows use lossless length-encoded uint64; last-insert ID and warnings are
zero because no such observations are supplied by the native Table result.

Classic packets carry payload length:u24 little-endian and sequence:u8. The
caller supplies the expected sequence for the current authentication/command
exchange. A mismatch rejects before allocation. Complete messages borrow payloads
and report consumed bytes; partial network fragments return no message. The
transport wrapper allocates only after checking the header.

The selected logical-message bound is below 0xffffff bytes. A full-size MySQL
continuation header therefore rejects as oversized before reading its body.
Sequence 255 is valid when expected; the exchange owner controls wrap/reset.
Framing alone neither advertises command capabilities nor executes SQL.

`Command.decode` admits Query, Prepare, Execute, Close, Reset, InitDB, Ping, Quit
and ResetConnection bodies. Query/Prepare SQL is bounded UTF-8 without NUL;
unknown commands reject. `Parameters.execute` checks the statement ID, zero
cursor flags, iteration count one, NULL bitmap, new-type flag and exact payload
end. It remembers types only after a complete valid execution body. A caller
must retain that state with the prepared statement and validate the expected
logical parameter types. No query-attribute layout is accepted.

| Logical type | Result field type | Flags / representation |
| --- | --- | --- |
| int64 | LONGLONG (8) | Signed eight-byte little-endian |
| uint64 / counts | LONGLONG (8) | UNSIGNED, eight-byte little-endian |
| finite float64 | DOUBLE (5) | Eight-byte IEEE little-endian |
| Boolean | TINY (1) | UNSIGNED; integer zero or one |
| UTF-8 | VAR_STRING (253) | Session's explicitly selected UTF-8 collation |
| Binary | BLOB (252) | BINARY flag, charset 63 |

Non-nullable fields add NOT_NULL. Numeric fields use charset 63. Parameters
admit signed/unsigned TINY, SHORT, LONG, INT24 and LONGLONG when they fit the
logical integer or zero/one Boolean destination; FLOAT widens to finite DOUBLE.
String/blob wire types carry length-encoded UTF-8/binary bytes. Embedded NUL is
valid in MySQL length-framed values. NULL remains separate from an empty value;
type code NULL carries no value bytes. Unsupported codes/flags, negative unsigned
values and narrowing overflow reject. Result encoders append one non-NULL field;
the owner supplies text NULL markers or the binary-row NULL bitmap (offset two),
row framing and aggregate byte limits. Execute parameter bitmaps have offset zero.

`Codec.length` handles every defined non-NULL length width and rejects reserved
markers. `Codec.string` checks its byte bound before slicing input. These helpers
do not allocate based on untrusted lengths. Decoded parameter strings borrow the
input until the session clones/binds them.

## Saved native steps and record upload

`SavedStep` stores one exact `TableClient.Prepared` in at most 455 bytes. The
layout is `GSS1`, mandatory current native definition:32, realm/resource/catalog/
owner/principal/sequence as six little-endian u64 values, schema namespace:u64,
selected-role presence:u8 (0 or 1), selected role:u64 (zero when absent), original
signing public key:32, Station frame length:u16,
exact frame bytes (at most 256) and signature:64. The redundant native envelope
identities are reconstructed only after validating this explicit definition and
the Table command's connection. No signature is generated or replaced. Encoding
requires a current Table send; decoding rejects missing/foreign definitions,
invalid framing, unsupported command identities and trailing bytes. `verify`
checks the saved public key against the configured original signer, the signature
and its match to the original complete Table intent. The reconstructed native
send retains the selected role; schema namespace and null-role presence are not
inferred from a current session.
The coordinator remains responsible for current grants and principal sequence
ownership. A decoded record is not evidence that its send was accepted.

`Upload` composes SQL gateway publication domain 11 with 128-byte ingress parts.
It temporarily retains a first half under publication key tag `h`, id=record ID,
index=0. The second half atomically writes the complete 256-byte chunk and clears
that half. Duplicate exact parts succeed without new mutations; changed parts,
gaps, oversize and writes after sealing reject. Every failed multi-write helper
restores the previous private decision; native read failures remain sticky.
Sealing requires the whole committed byte chain and no retained half. Reads use
only published records from a supplied committed view, check the explicit finite
allocation bound and verify the complete publication digest.

Publication acknowledgement alone does not establish SQL admission or a terminal
outcome. The [account ledger API](../packages/zig/transit-sql/docs/ledger.md)
composes these records under native owner/generation checks. The running host and
coordinator transport are separate from these deterministic library methods.

## Account ledger records and transitions

Every metadata value starts with its four-byte record magic and the mandatory
32-byte current native definition. Fields follow the declaration order in
[`LedgerRecords`](../packages/zig/transit-sql/src/LedgerRecords.zig) and
[`Terminal`](../packages/zig/transit-sql/src/Terminal.zig), using exact
little-endian integer widths, one-byte enum tags and fixed byte arrays. Unknown
tags, missing/foreign definitions, trailing bytes and inconsistent counters reject.
The [independent fixture](../packages/zig/transit-sql/src/fixtures/records.json)
fixes head, operation and terminal layouts including full-width u64 counts.

| Magic | Contents |
| --- | --- |
| GSH1 | Account/configuration commitment, retained/unsettled counters, used/reserved content, current quotas, active operation and known accepted principal sequence |
| GSN1 | Immutable nonce-to-operation identity |
| GSO1 | Frozen target, preparation phase, intent commitment, record/pending identities, sequence/input observations, conservative content reservation, requested controls and terminal summary/counts |
| GSB1 | Original Table command header fields with nested TCQ1 magic/definition omitted, body offset/length, command/domain digests and DML route; exactly 222 bytes including the checked GSB1 definition prefix |
| GSE1 | Signed-step record/sequence, native input, processed flag and optional exact disposition commitment |
| GST1 | Attributed native kind/identity, resource/principal/operation/object, input positions, state/reason, full matched/changed counts, actual DDL object and Table route |
| GSD1 | Rejected ledger input position/principal, exact frame fingerprint and bounded error name |

Ledger keys are `00 47 57`, tag:u8, operation:u64be, item:u64be (20 bytes).
Tags are `h` head (both IDs zero), `o` operation, `u` unfinished-upload index,
`q` ready index, `b` intent binding, `e` step observation, `d` exact native
disposition, `i` ledger input rejection and `t` terminal facts. Index values are
the exact ASCII bytes `upload` and `ready`. `i` uses the native input as its first
ID, zero as its second, and a GSD1 value.
Nonce keys use tag `n` followed by the 16 nonce bytes instead of the two integers.
`d` values use the catalog's original TCA1/E encoding. `t` holds GST1 or the exact
marker `gateway.cancelled.before-dispatch.v1` under a current-definition operation.
The marker claims local cancellation only. Publication namespace is the operation
ID: record 1 is the complete typed intent; later IDs are monotonic step attempts.
Only never-published abandoned step parts may be collected by the bounded helper.

Operation phases are reserved=1, uploading=2, ready=3, active=4, terminal=5 and
abandoned=6. A begin input allocates the ID and reservation before any intent is
uploaded. Complete canonical validation precedes ready admission. One active
operation owns the account's dedicated Table sequence. A committed published step
precedes dispatch; a native receipt precedes sequence advancement; processed
input and SQL terminal facts remain distinct records. Current rights are required
again before disclosing cached outcome facts. Operator controls and private
coordinator observations have distinct native principals.

DDL bindings cover CREATE, ALTER, rename and DROP. A missing-object
`DROP IF EXISTS` retains object zero and the catalog's unchanged outcome.
GST1 DDL route zero carries catalog reasons; route three carries a delegated
ALTER's Table rejection reason and completion input. The latter retains the
original catalog digest, checks the Table reference against its recorded
delegation, and has zero row counts. Neither admission nor catalog delegation
alone is terminal evidence.

Configuration supports 1–8 frozen catalogs per account, a dedicated private
ledger resource and five distinct nonzero worker/ingress/operator/coordinator/
Table principals. Native grants remain explicit. Initial retained-count/content
quotas are mandatory; pending quota defaults to 16, at most 1024. Increasing
capacity and reserving extra recovery space are explicit operator transitions.
New admission cannot consume an existing operation reservation. No transition
expires accepted work, drops history under pressure, dispatches during inspection
or treats a disconnected session as cancellation.

## Signed native ledger controls

A Station cast payload contains `GSQ1`, current definition:32, command tag:u8,
then the fields of [`Control.Command`](../packages/zig/transit-sql/src/Control.zig)
in declaration order. Integers are little-endian, arrays have exact declared
length, enums use their declared integer tag, and optional values start with
zero (absent) or one (present). There are no omitted/defaulted wire fields.
Qualified targets contain operation:u64 and native generation:u64; record
targets add record:u64. Parts contain offset:u32, length:u8 and bytes:128; offsets
are multiples of 128 and unused bytes are zero. Embedded terminal facts omit
the GST1/definition prefix because the command already supplies its definition.

| Tag | Command | Required actor |
| ---: | --- | --- |
| 1 | initialize(sequence) | Operator |
| 2 | begin(nonce, binding) | Ingress |
| 3 | begin_intent(operation, spec) | Ingress |
| 4 | intent_part(operation, part) | Ingress |
| 5 | seal_intent(operation) | Ingress |
| 6 | admit_intent(qualified target) | Coordinator |
| 7 | activate(generation) | Coordinator |
| 8 | begin_step(qualified target, spec) | Coordinator |
| 9 | step_part(record target, part) | Coordinator |
| 10 | publish_step(record target) | Coordinator |
| 11 | receipt(record target, input) | Coordinator |
| 12 | processed(record target, optional Table disposition) | Coordinator |
| 13 | reconcile(operation) | Operator |
| 14 | cancel(operation) | Operator |
| 15 | abandon_step(record target) | Coordinator |
| 16 | collect_step(record target) | Coordinator |
| 17 | cancel_unsent(qualified target) | Coordinator |
| 18 | capacity(operations:u64, bytes:u64, pending:u32) | Operator |
| 19 | reserve(operation:u64, bytes:u64) | Operator |
| 20 | complete(qualified target, terminal facts) | Coordinator |

Successful native input processing is observed through the owner and its current
resource; it does not create a SQL success reply. A rejected ledger input stores
GSD1 with input:u64, principal:u64, frame fingerprint:32, cause length:u8 and
cause:64, zero padded. Causes contain ASCII alphanumeric error names, never SQL,
credentials or values. Source read, allocation and host cancellation failures
are not application rejections and do not advance through this path.

`Client.Prepared` canonical JSON contains mandatory version/current definition,
realm/resource/owner, configuration fingerprint and exact native signed request.
Its saved size is at most 4096 bytes. Restoration rejects trailing/noncanonical
JSON and foreign definitions. Submission verifies the configured role, identity
and signature, then attempts the original request once. Unknown outcomes retain
that request; no helper silently allocates a successor or substitutes a new
signature. Read-only list/discover/status acquisition does not call the scheduler.

Operation inventory uses ordered keyset pagination over retained, increasing
operation IDs. A cursor binds realm/resource, account configuration, last ID and
minimum resource revision. Each page checks current read authority at its own
cut and returns at most eight operations. Forward revisions are permitted;
foreign bindings and backward revisions reject. Page phases are observations,
not one atomic inventory snapshot. Appends after the last page require another
listing; terminal status separately checks current Table disclosure rights.

## Runtime handoff and configuration

`ControlLane` owns at most one exact signed request and its optional native
receipt. Preparation transfers into the lane before submit. Polling neither
allocates a successor nor replaces the request after transport/status failure.
The lane clears only after an attributed processed observation. It belongs to
the account runtime, independent of a connection's wait or allocation lifetime.

`AccountRuntime` serializes ingress through its lane and ticks the ledger worker
and private coordinator independently. Each native HTTP client has one borrower;
sessions use their own transport for metadata, reads and observations. An
exact-current ledger reader invalidated by concurrent publication is reacquired,
while signed pending work is retained. Only a definite native `ConflictingRetry`
on an unreceipted private coordinator proposal permits clearing that proposal,
after checking the actual current native fence. This exception never applies to
a published Table step or ingress/operator control.

Immutable `intent_part` controls advance after a valid native admission receipt.
The ordered durable mailbox holds accepted bytes while the ledger processes
them; the runtime retains at most one uncertain ingress request, independently
of the durable backlog. A missing or invalid receipt keeps that exact signed
request pending and prevents allocating its successor. Begin and seal controls
still wait for their domain processing result. The seal validates the complete
publication before admission; accepted parts alone establish neither a complete
intent nor a successful SQL write. Existing per-intent size, native admission
quotas and turn mutation/value bounds apply unchanged.

Execution reserves a nonce/operation, binds an immutable Table intent, uploads it
and waits for original terminal evidence. Cancellation/deadline releases the
wait; it does not roll back, discard or authorize expiry of accepted work. A
partial upload remains discoverable with its received parts, but missing intent
bytes are not reconstructed after the originating task ends. Already admitted
parts and a queued seal continue processing after the wait ends. An uploading
phase observation alone does not establish that no later admission can occur.
It cannot dispatch until the complete intent is sealed and admitted; qualified unsent cancellation
can close it. The returned terminal record must equal a
fresh authorized observation from the Table owner; a cached ledger count alone
cannot establish disclosure authority. The host joins workers and connections
before destruction and requires fresh eligible ownership for a restarted process.

`Configuration` requires version 1 and the current native definition explicitly.
SQL account names and database names map to configured native bindings only.
Within a realm, configured accounts cannot share a ledger owner/resource or any
sequenced principal. TLS material, native keys, activation and spill paths are
explicit references. A `Credential` binds account identity, nonzero revision,
enabled state and current verifier definition. The host owns file loading,
atomic replacement and existing-session revision checks; validating these values
does not provision grants, certify an activation or open a listener.

## Primary definitions

The adapters follow the selected portions of PostgreSQL's
[message formats](https://www.postgresql.org/docs/18/protocol-message-formats.html)
and [message flow](https://www.postgresql.org/docs/18/protocol-flow.html), and
MySQL's [classic packets](https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html).
The credential primitives use the SCRAM-SHA-256 construction described by
[RFC 7677](https://www.rfc-editor.org/rfc/rfc7677).

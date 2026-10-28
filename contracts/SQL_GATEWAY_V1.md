# Database wire adaptation v1

This contract defines the shared gateway library, PostgreSQL/MySQL sessions,
typed message/scalar codecs and signed account recovery. The
[gateway application](../apps/transit-sql-gateway/README.md) composes those owners
with explicitly configured transport and login policies. Codec acceptance alone cannot admit a durable
write. Executed evidence belongs to the
[proof ledger](../docs/history/qualification/README.md).

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
| Handshake / command / write deadline | 5 / 30 / 5 seconds | 270 seconds each |
| PostgreSQL/MySQL idle timeout (`idle_ms`) | 0 (disabled) | 4294967295 milliseconds |
| Native HTTP session lease (`session_lease_ms`) | 30 seconds | 270 seconds |

Every configured bound except the wire idle timeout is positive. A cycle
accommodates at least one frame and fits the session budget. SQL text remains at most 4096 bytes. The common maximum
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

Idle wire connections remain open by default. A positive `idle_ms` starts an
idle timeout between complete command cycles. Expiry sends PostgreSQL FATAL
SQLSTATE `57P05`, or MySQL error `4031` with SQLSTATE `HY000`, then closes the
connection. This ends the session, not previously admitted account work.
The first incoming network bytes start a finite frame deadline using the command
budget, including an incomplete TLS record. Buffered TLS application bytes also
start this bound; later fragments do not renew it. Handshake, frame, command and
output deadlines remain finite when idle expiry is disabled. Native HTTP session
leases are independent of this wire timeout.

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
fix a schema namespace and eligible selected role; the Catalog binding retains
both, independently of the connection lifetime.

Direct Table metadata, scans and operation evidence use the Table caller's current
signed subject and selected role. They require no private raw-storage reader.
Catalog retains an exact direct intent reference; current credentials may
sign its transport attempts without changing accepted work. Catalog recovery
controls retain their own exact signatures and sequence-recovery rules.

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

`Read.nextBatch(maximum)` borrows up to 32 owned logical rows until its next call
or close, with at most 1 MiB of canonical cells. SQL batches fill across source
pages without changing storage page size. A row that exceeds the remaining byte
budget stays with the source for the next pull; a row larger than an empty batch
fails explicitly. Nested values are copied before iterator scratch is reused. The host validates current account,
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

## Frozen database references and admission

The shared `DirectIntent.Reference` contract is a tagged `table`,
`name_assertion`, `namespace_change` or `external` reference. Its canonical
`GIR1` encoding contains the current definition and at most 4096 bytes. Complete
Table `TDI1` work and opaque external recovery bodies are staged directly with
the database before accepting their references. SQL text is not split into
Station mailbox frames or KV values.

The [direct contract](DIRECT_TABLE_V1.md#durable-client-token-bindings) owns
account/token first-bind selection, recovery CAS transitions, request fences and
paged inventory. An accepted SQL ID is the token's Catalog acceptance position;
the underlying operation retains its independent, original data identity.
Repeated tokens return the original binding under current rights. Different
fingerprints conflict. Staging is not admission; token acceptance is not data
completion. A missing reply requires inspecting the original token or operation.

CREATE IF NOT EXISTS on an existing Table and DROP IF EXISTS on an absent name
produce name assertions. Their commitment includes the exact SQL, dialect and
proposed schema. Namespace changes retain the selected SQL namespace separately
from the changed schema. Preparation does not allocate or publish either kind.

## Database runtime and recovery

`transit-sql` depends only on public client, Catalog, direct query and logical
result/session contracts. Its build graph rejects Station dependencies.
`DatabaseRuntime` observes the bounded pending index and advances original saved
intents. `commit_saved` commits complete single-partition DML with one Table WAL
append, including its outcome; it does not publish an intermediate Table
admission. Token acceptance and pending-index settlement use separate Catalog
transitions. DDL and cancellation use their owning public operation contracts.

`DatabaseAccount.Configuration` fixes realm, account, database principal and one
to eight namespace/role routes within one Catalog. Independent catalogs cannot
share an account's numeric operation IDs. Operation, recovery-byte and pending
budgets are charged atomically by Catalog admission. Pending capacity is released
on settlement; retained identities and byte charges remain. The default pending
limit is 16 and its maximum is 1024. Budget changes require a separately designed
account reconfiguration operation; changing a runtime configuration cannot
silently reset an existing account's limits.

A Catalog activation record fixes a strictly increasing generation and runtime
instance. Each database request carries that exact revision as its signed lease
fence. The local host checks it under Catalog access held through execution and
disclosure. Replacement acquires exclusive access. This fence does not grant
rights; current database/schema/Table authorization is checked separately.

`ReadCache` retains 64 active or reusable Table cuts. Exact connection routes
have distinct recovery slots. Current definition and logical change frontier
qualify reuse, and disclosure still checks current policy. A cold read persists
its original acquisition in Catalog before pinning. Recovery resolves that exact
request after an uncertain reply; it never captures a replacement cut into a
partly returned result. There are no per-query local pin files. Closing a result
releases its cache borrow; eviction or replacement releases the original durable
pin. Denied cleanup remains pending and observable.

## Service composition and controls

`transit-sql-service` composes the database runtime with sessions, credentials,
settings and explicit source/capture adapters. Catalog records retain complete
external requests before dispatch. Their separate domain owners establish
completion. Explicit captured queries can use Station Query owners; database
admission, DDL/DML, cancellation and snapshot recovery never require their turns.

The operator interface provides `list [AFTER_ID]`, `status OPERATION`,
`cancel OPERATION` and credential-file generation. Inventory has at most eight
entries and a numeric keyset cursor. Pages are current observations, not one
atomic inventory snapshot. Status checks the original owner under current rights.
Cancellation is a sticky request, not a promise of rollback or external closure.
The old GSQ1 controls, private KV records, multipart upload, initialization mode
and actor provisioning are removed by the current-v1 cutover.

`Configuration` requires version 1 and the exact current definition. An account
provides `execution`, a generation, a `table` key reference, databases and optional
sources. Accounts cannot share their database principal. Source credentials have
separate sequence ownership. TLS, activation/spill paths and verifier files are
explicit references. Loading configuration does not create grants. Existing
sessions recheck credential revisions and current database permissions.

A deadline, disconnect or cancellation ends a wait; it does not discard accepted
work. Completion is projected only from a matching, currently authorized owner
outcome. Workers and connections join before destruction. A restarted service
requires a fresh Catalog generation.

## Primary definitions

The adapters follow the selected portions of PostgreSQL's
[message formats](https://www.postgresql.org/docs/18/protocol-message-formats.html)
and [message flow](https://www.postgresql.org/docs/18/protocol-flow.html), and
MySQL's [classic packets](https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html).
The credential primitives use the SCRAM-SHA-256 construction described by
[RFC 7677](https://www.rfc-editor.org/rfc/rfc7677).

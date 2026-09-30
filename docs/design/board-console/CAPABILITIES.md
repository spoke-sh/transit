# D1 capability inventory

[D1 review](D1.md) · [Review index](README.md)

Supporting material for **board-console D1**, not another review or an
implementation plan. All configuration and operational UI below is proposed.
The [D2 refinement](D2.md) carries this inventory forward while organizing
workload declarations in Workspace and supporting capabilities in Operations.
No row here supplies a new SQL production or executable declaration contract.
Only the finite HTTP/1.1 connector has current implementation progress; gRPC,
Document, unified-query and Flight milestones retain their own planned scope.
Other families are design candidates without a selected implementation order.

The classification applies Transit's [existing terminology](../../history/GLOSSARY.md#transports-effects-and-connectors).
Protocol names alone do not determine a screen, runtime process or durability
boundary. Each row names the decision the UI would need to represent and the
contract required before enabling it. Provider examples are illustrative, not
selected vendors, dependencies or promised integrations.

## Carriage and HTTP families

HTTP versions need two linked views: HTTP operation semantics in the connector,
and the selected framing/session profile under Transports. Do not advertise a
working HTTP connector as supporting every HTTP version. HTTP/2 multiplexing and
HTTP/3's mapping over QUIC motivate separate connection/stream observations.
These facts come from [RFC 9113](https://www.rfc-editor.org/rfc/rfc9113.html) and
[RFC 9114](https://www.rfc-editor.org/rfc/rfc9114.html); the Board organization is
this review's proposal.

| Family | Proposed home | Configuration and evidence to represent | Contract still needed |
| --- | --- | --- | --- |
| TCP | Transport | Peer scope, dial/listen direction, connection limits, timeouts and pressure | Distinguish bytes accepted by a socket from a connector's accepted operation; no generic raw-socket effect API |
| UDP | Transport | Datagram/peer scope, size/rate budgets and observed drops | Explicit loss, duplicate and ordering treatment in the consuming connector; socket send cannot prove receipt |
| QUIC | Transport | Peer/trust policy, connection and stream bounds, negotiated features and reconnect/migration observations | Define permitted stream/datagram features and handling of replayable early data; transport recovery grants no new effect attempt |
| TLS and SSH security layers | Transport/trust dependencies | Server identity, CA/host-key references, client credential references, policy revision and handshake evidence | Rotation/revalidation, identity mismatch and scope checks; no private-key or decrypted-secret display |
| HTTP/1.1 and HTTPS | HTTP connector plus transport details | Endpoint, allowed methods/headers, framing/capture bounds, credential bindings and finite timeout | Extend current finite M15 evidence into Board; current provisioned IPv4/TLS hostname profile is not ambient DNS/proxy discovery |
| HTTP/2 | HTTP framing/session profile under Transports; HTTP and gRPC consumers | Negotiated protocol, concurrent streams, flow control, reset/drain and compression budgets | M16 qualifies its transport dependency for gRPC; that does not automatically qualify outbound HTTP/2 operations |
| HTTP/3 | HTTP framing/session profile over QUIC | HTTP stream evidence linked to its QUIC incarnation, trust and negotiated profile | New transport and HTTP connector qualification, including fallback/early-data policy; no silent retry on protocol change |
| SSE | Candidate HTTP streaming profile with an explicit subscription contract | Endpoint, event framing, last accepted event ID, capture cursor, reconnect policy, gaps and lag basis | Durable acceptance/checkpoint mapping and upstream replay limits; Last-Event-ID alone promises no retained history |
| WebSocket | Candidate connector family or reviewed streaming adapter | Endpoint/subprotocol, messages in each direction, send/capture progress, close/ping observations and buffers | Per-message intent/send authority, bounded bidirectional capture, reconnect identity and unknown outcome; handshake success is not message delivery |
| gRPC | Connector over qualified HTTP/2 | Method/type descriptors, unary/streaming mode, directional progress, half-close, trailers and budgets | M16's exact send units, capture, cancellation and reconciliation proofs; no automatic restart of a partial stream |
| Flight / Flight SQL / ADBC | Query gateway/client capability using the qualified RPC path | Source catalog, identity mapping, tickets/result references, query features and retrieval state | M22's initial bounded Table matrix; neither ticket possession nor a gRPC implementation grants data access |

[SSE's specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)
defines event framing and reconnection behavior;
[WebSocket's specification](https://www.rfc-editor.org/rfc/rfc6455.html) defines
its bidirectional message protocol. Our durable subscription/message mapping
is additional design work. A live stream cannot stand in for a Transit mailbox.

Ingress is a separate role from egress. An HTTP fetcher does not imply a webhook
listener; a connector client does not imply a server. Future inbound profiles
need authenticated origin, durable admission before the declared acknowledgement,
duplicate/gap handling, destination grants, limits and deployment exposure rules.

## Files, objects and databases

| Family | Proposed home | Configuration and operational workspace | Contract still needed |
| --- | --- | --- | --- |
| FTP | Connector | Endpoint, control/data channel policy, remote path scope, transfer direction and progress | Transfer identity, partial visibility, resume/restart and completion rules; remote reply versus captured content |
| FTPS | Connector/profile with explicit TLS semantics | FTP operation details plus control/data protection and certificate policy | Qualify the selected secure profile rather than assuming FTP configuration supplies it |
| SFTP | Connector over SSH | Host-key trust, path scope, file handles, transfer offsets and explicit operations | Its own protocol/version, restart and reconciliation behavior; not an FTP TLS toggle |
| Filesystem | Connector with a local OS boundary | Approved roots, path operations, read/write/rename/watch modes and bounded capture | Symlink/path escape, file mutation during reads, atomicity/visibility and watch gaps; no arbitrary Board host file browser |
| S3 / compatible object APIs | Connector; provider variants may add integrations | Endpoint, bucket/prefix, credential/region policy, object/version references, multipart work and capture | Per-operation outcome and consistency, multipart cleanup, listing coverage and vendor compatibility; separate from Ursula's internal cold storage |
| GCS / other object stores | Connector where effect semantics differ; provider integration where they truly reuse a connector | Store-specific scope, object identity and upload/list/delete behavior | Demonstrate semantic reuse; a similar UI does not prove interchangeable attempts |
| PostgreSQL | Candidate connector with distinct query/write/CDC profiles | Database/schema scope, allowed operations, remote transaction state, snapshot/LSN/slot evidence, mapping to local resources | Remote commit uncertainty, capture/ack ordering, snapshot-to-tail handoff, duplicate processing and retained-log pressure |
| MongoDB | Candidate connector with operation and change-stream profiles | Database/collection scope, selected operation types, resume token, captured change progress and mapping revision | Resume/gap handling, document/type mapping and remote write uncertainty; remote documents are not Station Documents |
| Redis | Candidate connector with command, Pub/Sub and Streams profiles | Key/channel/stream scopes, command allowlist, subscription/consumer progress and capture | Distinct delivery/ack/replay semantics per profile; remote keys are not Transit KV and remote TTL is not Transit expiry |
| SSH command execution | Separate high-authority connector capability | Exact command policy, executor identity, output bounds and terminal/unknown outcome | Explicit isolation and reconciliation; SFTP support does not authorize an arbitrary shell |

Database ingestion must distinguish **observed remotely**, **captured durably**,
**materialized into a local revision**, and **acknowledged upstream**. Their
contract defines which events may safely advance each stage. A remote transaction
and a Transit resource turn are separate commits; distributed atomicity cannot
be inferred from a pipeline diagram. Querying a retained local result never
performs an implicit database read.

Three primary references illustrate why a generic Reconnect button is insufficient:

- PostgreSQL logical decoding can redeliver changes after a crash; its slot and
  snapshot contracts require a deduplication and progress design.
  [PostgreSQL logical decoding concepts](https://www.postgresql.org/docs/14/logicaldecoding-explanation.html).
- MongoDB change-stream resumption depends on a compatible token/options and
  sufficient retained oplog history. An expired history basis needs a visible
  recovery decision. [MongoDB change streams](https://www.mongodb.com/docs/manual/changestreams/).
- Redis Pub/Sub has at-most-once delivery and loses missed messages; Redis Streams
  is a separate persistence/delivery model. Board must identify the selected
  profile. [Redis Pub/Sub delivery semantics](https://redis.io/docs/latest/develop/pubsub/).

These are upstream constraints, not claims that Transit implements their adapters.

## Identity and mail

| Family | Proposed home | Configuration and evidence to represent | Contract still needed |
| --- | --- | --- | --- |
| OIDC | Access: federation/trust profile; provider-specific identity integration | Issuer, audience/client, redirect scope, key-validation policy, principal mapping and authentication freshness | Attributable Board admission and current Transit grants; sessions, logout/revocation, outage behavior and bootstrap |
| SAML | Access: federation/trust profile; provider-specific identity integration | Entity/issuer identity, metadata/signing references, audience/recipient, assertion validity and principal mapping | Qualified assertion/replay validation, session/trust rotation and current Transit authorization |
| OAuth/API keys/mTLS for external services | Credential bindings referenced by connectors/integrations | Scope, issuer/audience where applicable, expiry and immutable credential version; no raw values | Authorized resolution/renewal, current destination binding and redacted capture; an outbound token is not Board sign-in |
| SMTP | Connector; provider account/policy may be an integration | Envelope/recipient scope, send attempt, submission response, capture and later delivery evidence where supplied | Ambiguous submission, duplicate-send risk, per-recipient outcomes and bounded reconciliation; accepted submission is not human receipt |
| IMAP | Connector; mailbox provider may be an integration | Account/mailbox scope, stable message identity, selected operations, fetch/capture progress and change observations | Reconnect/resync, identity invalidation, flags/deletion effects and acknowledgement rules; preview operations need declared side effects |
| Provider mail API | Integration over HTTP when HTTP owns the operation shape | Provider schemas, pagination, message IDs and rate/auth conventions | Preserve HTTP attempts and provider-specific idempotency/delivery interpretation; same mailbox does not imply SMTP/IMAP parity |

OIDC adds authentication on OAuth 2.0; SAML communicates security assertions.
That informs their placement under Access, with trusted provider integrations,
rather than treating them as ordinary data-transfer connectors. See
[OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html) and
[OASIS SAML overview](https://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html).
Some adapter operations may use HTTP and recorded effects, but an identity
assertion still cannot create a Transit grant. No login protocol is selected by D1.

## Further families the model should accommodate

The list is intentionally open. Future candidates include Kafka, MQTT, AMQP,
NATS, DNS, LDAP/SCIM, additional databases, cloud APIs, observability exporters,
LLM/tool APIs, and webhook ingress. Their names do not all denote the same tier.
For example, a provider-specific model API may be an HTTP integration, while a
new messaging protocol needs its own connector admission/acknowledgement contract.
Identity provisioning has different authority from an ordinary data import.

For each selected family, establish these facts before adding a supported badge:

| Dimension | Required answer |
| --- | --- |
| Owner | Which library/executor, public contract and milestone owns it? Which existing transport/connector does it actually reuse? |
| Shape | Finite operation, transfer, subscription, bidirectional exchange, transaction or identity relationship? Which directions are supported? |
| Scope | Exact realm, endpoint/path/topic/database, credential and permitted operations; which details may each reader discover? |
| Identity | Configuration revision, remote object/session identity, operation/attempt identity and fixed result destination |
| Progress | Where do send, remote acknowledgement, durable capture and local publication occur? Which may be unknown? |
| Recovery | Exact retry versus new attempt; duplicate/gap/resnapshot behavior; original budgets and irreversible closure |
| Data | Declared schema/decoder/mapping versions, local versus external resource identity and provable lineage |
| Capacity | Independent operation, resident, scan, live-work, retention and deployment budgets; explicit backpressure |
| Controls | Precisely supported validation, probe, pause, drain, resume, rotate, reconnect and retire actions |
| Evidence | Independent peer, current policy/revocation, lost response, partial capture, restart and cleanup proofs; UI/API agreement |

This permits shared inventory, revision review and evidence components without
pretending all protocols share one form, one connection state machine or one
remote exactly-once guarantee. Persistent library/module boundaries should follow
real implementations, not this inventory.

[D1 review](D1.md) · [Review index](README.md)

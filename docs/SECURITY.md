# Identity, authorization, and trust boundaries

Status: required security boundaries with a bounded M1 implementation. The
[v2 protocol](../contracts/TRANSIT_V2.md) and [service contract](../contracts/SERVICE_V2.md)
specify signed requests, grants, revocation, and scoped reads; [state v1](../contracts/STATE_V1.md) adds
resource grants and read-view authority.
[The proof guide](../tests/README.md#service-and-reference-evidence) records
loopback and reference-runtime evidence. Public ingress TLS, federation,
arbitrary native handlers, and broader topologies remain outside that proof.

## Responsibility in the stack

M19's [serving caller profile](../contracts/SERVING_V1.md) preserves caller-signed
native ingress commands and authority-derived external origins. Scoped status
reads combine a signature over the exact service/operation read with a matching
native identity proof and current service policy. Its trusted gateway reader has
an independent resource grant; callers receive no raw grant to other callers'
records. Provisioned public keys are bounded gateway configuration, not a grant
database. Inbound TLS/deployment qualification is separate and remains in progress.

Authentication establishes who is calling. Authorization decides which action
that principal may perform on which resource. Execution ownership separately
decides which activation may commit. None substitutes for the other two.

| Boundary | Responsibility |
| --- | --- |
| Identity provider and credential adapters | Issue/validate human and service credentials; establish issuer-qualified principals and credential validity |
| Trusted protocol ingress | Authenticate every caller, bind verified identity to the request, limit input size/rate, and prevent forged identity headers |
| Transit authority | Enforce realm, action/resource grants, delegation bounds, policy revisions, ownership, and lifecycle at authoritative operations |
| Station and applications | Express policies and apply workload/domain rules; framework helpers cannot grant privileges or replace kernel checks |
| Board inspection boundary | Admit viewers through the private deployment boundary, bind the configured read identity, enforce current upstream permission, and protect derived views and caches; no viewer identity or M2 mutation authority |
| Trusted effect executor | Authorize each attempt, enforce destination/secret scope, perform external I/O, and authenticate outcome submissions |
| Storage/runtime adapters | Use separate service credentials for authorized infrastructure operations; translate identities without inheriting provider-wide privileges |

Authentication belongs at protocol entry points, including internal worker and
controller APIs. Board’s private inspection endpoint is the explicit viewer
admission exception described below; its upstream Transit calls authenticate.
An edge proxy can authenticate clients, but the receiving
service must trust the authenticated channel and its identity binding; a public
`sender` field or forwarded header is not proof. Transit core consumes verified
identity and policy facts through interfaces. It does not implement an identity
provider or depend on OIDC, Kubernetes, or Substrate types.

## Principals, realms, and grants

A **principal** identifies a human, service, or logical workload. A **security
realm** is an explicit administrative authority for principals, grants, and
resource access. It is distinct from a registry namespace, PID allocation
scope, Ursula bucket, Kubernetes namespace, or Substrate atespace. Resources
carry a realm binding; mappings between these scopes are explicit.

M1 may run one realm, but must test rejection of foreign or forged realm
references. Cross-realm use is denied until explicitly supported; a portable
PID does not imply federated trust or network reachability.

A process has a durable workload-principal binding. Each activation obtains
fresh, limited execution authority bound to its PID, generation, workload
version, realm, and intended API. A worker's service identity alone cannot act
as any PID it names. Credential renewal cannot renew revoked ownership, extend
process lifetime, or revive a retired PID. Sender provenance comes from the
trusted boundary, not workload-supplied envelope claims.

The target grant model covers subject, actions, scope, validity and policy
revision. The current contracts use Ed25519 principals, permission bits, optional
PID scope, ordered policy revisions, and separate resource grants; federation
and general delegation are not implemented. Default deny applies to spawn,
send, inspect/read/tail, name lookup/mutation, supervision, effect request and
dispatch, secret use, runtime control, retention/GC, and policy administration.
Permission to send is not permission to inspect a mailbox, fetch a referenced
body, change its lifetime, or delegate the receiver's rights.

Durable admissions and public handler inputs carry an authority-derived,
versioned origin: external principal/policy revision, source PID/turn/output, or
effect/attempt/executor. Payloads cannot select this evidence. General delegation
is not implemented. The [input contract](../contracts/TRANSIT_V2.md) and shared
fixtures define the envelope; origin survives eligible catalog collection.

Automatic delivery uses a dedicated principal with the delivery capability,
optionally scoped to a destination PID. Its separate current send grant determines
whether admission is accepted or terminally denied. The courier can read pending
counts and its sequence through [the signed delivery endpoint](../contracts/SERVICE_V2.md);
it needs no mailbox values, execution rights, root seed or storage access.
Receiving a message does not automatically grant the sender's permissions to
the receiver or let the sender use all of the receiver's privileges. Delegation
must be explicit, bounded, and no broader than the delegator's current grant.
Authority delegation is distinct from application-level agent/task delegation.
Applications still validate domain rules, such as which account a command may
affect, even when Transit permits delivery to their process.

The implemented [M7 state-resource profile](STATE.md) uses current administrator
rights for creation, association changes and lifecycle operations, with separate
resource inspect/read/write grants for disclosure and turn access. Association
changes also require target inspection; root authority issues resource grants.
Association, writer PID, and lifetime ownership do not substitute for permission.
PID inspection alone reveals neither associated resources nor their values.
Resource revocation fences reads, commits and receipt reconciliation even after
a read view has been released; see the [state contract](../contracts/STATE_V1.md).

## Authorization over time

| Operation | Required decision |
| --- | --- |
| Message admission | Authenticate and authorize the sender, target PID/realm, message class, and lifetime; record the accepted provenance |
| Turn commit | Validate the process principal, current execution grant, ownership, prior state, and proposed outputs under the applicable policy |
| Associated-state read or mutation (M7) | Check current resource grant, identity/revision and lifetime; mutation additionally requires the fenced writer and accepted turn decision |
| Outbox delivery | Preserve source provenance and fixed target PID; validate current destination admission policy before first acceptance |
| Effect dispatch authorization | Validate committed intent, current grant/revocation state, attempt identity, destination, secret scope, and deadline |
| History/receipt read or live tail | Enforce current read authority, including referenced payloads; revalidate long-lived access at a defined bounded interval |
| Policy, retention, or lifecycle mutation | Require the corresponding administrative grant and serialize its durable result |

Policy changes and revocations are versioned durable control operations. M1
must define how their effective boundary is ordered against admissions, commits,
dispatch authorizations, and read authorizations. A cached allow decision must
not outlive that boundary; policy propagation without enforced fencing is
insufficient. If current policy cannot be established, refuse the operation.
The first slice can use one policy authority rather than solve arbitrary
distributed policy engines.

Revoking a human credential does not undo a message already admitted or make
its historical acceptance invalid. Subsequent execution uses the process's
own current authority; suspending that authority requires an explicit operation.
Revoking future delivery permission can stop an undelivered committed output:
record a denied delivery outcome or a declared blocked state without rolling
back the source turn. An already accepted destination message is deduplicated,
not accepted a second time. Current read permission still governs disclosure of
its receipt. Cancellation and disposition of accepted work are lifecycle rules,
not silent deletion through an ACL update.

Record principal, operation/resource identity, grant/policy revision, relevant
validity bounds, and the accepted authorization decision. Never record bearer
tokens, private keys, cookies, or resolved secrets as replay inputs. Historical
replay uses recorded decisions; access to replay itself needs current read
permission, and resumed live work needs fresh authority. Retain/compact policy
evidence consistently with the execution history it explains.

## Effects and the limits of revocation

A committed effect intent is eligible work, not a reusable network credential.
The trusted executor crosses a durable **dispatch authorization boundary** for
one attempt before I/O. Revocation and expiry forbid new authorizations after
their effective boundary. Once authorized, an attempt is potentially in flight,
including a worker paused immediately before its network send. The protocol
cannot retroactively prove it did no work.

Do not retry an uncertain authorized attempt merely because its worker lost a
lease. Reconcile under the connector's external idempotency contract. A promise
that no network byte or remote action occurs after a wall-clock cutoff requires
additional enforceable egress/remote support; the default contract only fences
new dispatch authorizations. This limitation also applies to runtime-provider
operations. See [CONNECTORS.md](CONNECTORS.md).

Connectors own bounded reconciliation policy. Transit enforces the accepted
scope and budget, authenticates observations, and orders result acceptance
against irreversible closure. Authority to reconcile does not grant new caller
turns, extra attempts, or an extension of the window. After closure, reject new
result submissions even from the original executor; current read rights can
still disclose historical receipts. Administrative investigation requires
separate authority and cannot reopen or overwrite the closed attempt.

For the first slice, reviewed connector executors and their dispatch path are
trusted infrastructure. Untrusted handlers have neither connector credentials
nor unrestricted egress. A plugin with direct sockets and secrets cannot be
constrained by an optional SDK check; untrusted connector code would need a
separate trusted I/O broker. Report this trust boundary explicitly.

## Credentials, secrets, and observations

Use established credential mechanisms with explicit issuer, audience, subject,
validity, and rotation rules. M1 selects a minimal provider/service identity
setup and proves spoofing, expiry, renewal, and revoked-owner rejection. Provider
credentials and Transit workload grants remain distinct. Keep operator, kernel,
connector, storage, and runtime controller privileges separately scoped.

Provider logout or token invalidation is separate from Transit grant revocation.
Each credential adapter declares validation freshness, revocation delay, and
outage behavior; offline token validation cannot promise immediate invalidation.
To establish a protocol cutoff, record a Transit revocation and enforce its
ordered boundary. Do not silently turn an unavailable required validation step
into permission to proceed.

Secrets are resolved only by authorized executors from references. Check the
rendered destination, DNS resolution, proxy route, and every redirect before
using credentials; an allowed URL string must not enable access to cluster
control APIs, cloud metadata, or another realm's service. Bind observations to
the authenticated executor and authorized attempt. Correlation IDs alone do
not authorize a forged reply or effect result.

[Board console D6](design/board-console/D6.md) applies these boundaries to a
proposed operator interface. Its [SECRET lifecycle](design/board-console/OPERATIONS_SQL.md)
manages versioned reference metadata, with separate disclosure, management and
executor-use permissions. It does not implement a credential store, identity
provider or new grant family. Attributable operator ingress and recovery need
their own contracts before controls can extend Board's current private viewer
and read-only inspection profile.

Protect history, checkpoints, transcripts, lookup/list results, logs, metrics,
and backups as data surfaces. A projection is not automatically public because
it is derived. End or reauthorize live subscriptions on credential/policy expiry
within the declared bound. Denial responses should not disclose private resource
existence or old receipts. Audit privileged accepted operations durably; bound
and rate-limit rejection telemetry so unauthenticated traffic cannot fill the
authoritative journal. Audit records omit credentials and unnecessary payloads.

The [observability design](OBSERVABILITY.md) applies these boundaries to implemented
service instrumentation. Use allowlisted fields and protected sinks; omit
payloads, credentials and raw URLs. Trace context and diagnostic request IDs are
untrusted correlation hints, never principals, grants or proof of an outcome.
Future telemetry endpoints/exporters need their own scoped access and retention
policy; Board read access does not grant access to every service's diagnostics.

A live read authorizes a bounded batch or interval, not unlimited future access.
Specify that bound and the point at which revocation prevents the next read
authorization; bytes already released cannot be recalled. This distinguishes
bounded subscription shutdown from an unsupported claim of instantaneous
revocation across every open connection.

## Connector TLS verification

HTTP uses the pinned [Transit TLS adapter](../packages/zig/transit-tls/README.md)
with explicit hostname and trust-bundle verification. It adds whole-path CA,
key-usage, path-length, name-constraint and server-purpose checks missing from
the pinned compiler's client, and validates bounded DER before parsing. Upstream
revisions and source hashes are recorded beside the implementation; compiler
changes require an explicit rebase and independent chain qualification.
Numeric routing remains separately frozen by endpoint policy. This profile has
no online OCSP/CRL fetching or automatic trust-store update. TLS peer verification
does not grant Transit dispatch or transcript-read authority.

## RPC and query boundaries

[M19 serving](SERVING.md) implements a common inbound contract for HTTP application
APIs and Board. Application callers need explicit credential/principal and
service mappings; Board preserves its private shared viewer profile. Route
publication, proxy headers and a running listener grant no authority. Forwarding
must preserve the actual Transit origin and bind any original-caller attribution
to verifiable admitted evidence. Server TLS needs its own qualification.

[M20 reactive APIs](REACTIVE_API.md) require current checks for commands,
notifications, idle watches and resumption, bounded disclosure intervals and
scope-bound cursors. Qualify browser Origin/admission and any scoped bootstrap
credential for WebSocket; an upgrade cannot grant every subsequent operation.
Keep reusable bearer credentials out of URLs, subprotocol names and descriptions.
[M21 reactive interfaces](REACTIVE.md) clears protected views on denial. Neither
a resume token nor an accepted query grants unlimited future disclosure. Individual
Board sign-in, federation and general delegation remain separate scope. The
qualified Table API checks idle authority every 500 ms and bounds each write to
one second; these disclosure bounds are not instantaneous revocation. Expired
leases stop reads even without an observer. Physical recovery and cursor signing
key reuse cannot extend a lease or restore a revoked grant.

M13's [public Table query profile](../contracts/PUBLIC_QUERY_V1.md) uses a
separate configured query identity, durable requester binding and source peer
policy. Inspection credentials remain read-only. Board's optional POST route
requires exact Origin/JSON checks and accepts only bounded query operations;
these browser checks do not authenticate individual viewers. Every reachable
viewer shares the configured query scope. Typed result reads recheck current
authority after verification; result IDs and frozen submissions are not bearer
grants. Browser denial clears protected state, and neither frontend creates an
offline result cache. Captured execution can continue after local disconnect.

The planned [Flight gateway](ARROW.md#identity-lifetime-and-failure) is a separate
ingress with an explicitly qualified credential-to-principal and Table-service
mapping. Its catalog, tickets and result caches require current scoped read
checks; a query handle cannot act as an implicit bearer grant. The
[gRPC connector](GRPC.md#security-inspection-and-qualification) separately
authorizes external destination/method/credential use. Neither inherits Board's
shared-viewer access model or supplies general delegation.

## Board inspection profile

[M2](roadmap/M2.md) adds protected discovery/history and an inspection-only UI/API.
Board exposes one explicitly configured read-only Transit principal per
instance to everyone who can reach its private UI/API. Viewer admission belongs
to the network/deployment boundary; Board has no access keys or sessions.
It exposes that shared scope, not individual user delegation. Transit rechecks
current permission for each bounded read; network access and cached projections
cannot extend it. The
[Board design](BOARD.md#access-and-trust) and [application guide](../apps/transit-board/README.md) specify the implemented
private access profile and qualification boundary. Per-user policy, federation, and operational controls
require later explicit scope. Lists, relationship edges, counts, and previews
must not disclose resources outside the read grant.

The [development launchers](../launchers/README.md#local-development-configuration)
can explicitly enable unencrypted HTTP for a trusted LAN origin. This is a
development transport exception, not relaxed authentication or authorization:
the public origin remains exact, the upstream Transit signing credential is
still required, and Transit and Ursula listeners remain private. Inspection
data is available to every caller admitted by the private network boundary.
Normal remote Board deployments require TLS.

## Trusted computing base and provider boundaries

The trusted computing base includes protocol authorities, credential validation,
policy control, storage integrity, selected handler-execution enforcement,
privileged adapters, and effect executors. Cluster/storage administrators can
alter these components and are outside the workload-adversary boundary. Do not
claim protection against a compromised administrator or trusted executor.

Transit validates protocol legality. That alone cannot prove a native handler
computed an honest state transition, is deterministic, or reported an external
response faithfully. The reference qualifies a reviewed native caller and its
I/O boundary; it does not supply an arbitrary deterministic-code executor.
Recovery from recorded committed state and deterministic
re-execution are distinct claims; business correctness remains application
validation. Unrestricted nondeterministic code belongs behind a recorded effect
boundary. Package boundaries and network isolation alone do not establish this.

Ursula v0.5.1 documents unauthenticated node APIs and optional gateway token and
bucket access controls. Those controls do not implement Transit PID/turn/effect
permissions; keep nodes private behind the trusted adapter. See the
[pinned security documentation](https://github.com/tonbo-io/ursula/blob/v0.5.1/docs/web/src/content/docs/pages/security.mdx).

Substrate's current documentation supports client authentication but states
that authorization/RBAC is not implemented. Treat its control API credentials
as broadly privileged, accessible only to trusted runtime controllers and
operators. Do not expose that API to workloads or infer isolation from atespace
names. Validate the selected revision before claiming support. See
[upstream authentication](https://github.com/agent-substrate/substrate/blob/main/docs/authentication.md).

Kubernetes identities and RBAC protect Kubernetes resources; mapping a service
identity into Transit still requires the grants above. The reference deployment
must prove its credential, network, and sandbox boundaries, including bypass
attempts after snapshot restoration. See [DEPLOYMENT.md](DEPLOYMENT.md).

## Bootstrap and minimum scope

Bootstrap must establish a realm, trusted identity roots, initial administrator,
and durable policy/control catalog before application processes exist. Pin
provider trust configuration outside workload control; record the realm genesis
and initial grants without storing root secrets. System recovery cannot depend
on an application registry or process whose own authority is not yet recovered.

M1 implements minimal explicit grants and revocation, authenticated services,
and a fixed trusted workload image. Identity federation, arbitrary user-supplied
native plugins, an identity-provider product, and broad policy languages are
outside the first slice. The adversarial evidence belongs in
[CONFORMANCE.md](CONFORMANCE.md), with implementation gates in [M1](roadmap/M1.md#design-gates-before-expanding-the-slice).

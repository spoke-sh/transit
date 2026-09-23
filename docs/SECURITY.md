# Identity, authorization, and trust boundaries

Status: required boundaries and semantics. Credential providers, policy schema,
execution isolation, and deployment configuration must be selected and proved
in M1. The [experimental v1 profile](../contracts/TRANSIT_V1.md) now implements
Ed25519 request verification, scoped grants, key replacement, and durable
revocation. Network ingress and deployment isolation remain unproved.

## Responsibility in the stack

Authentication establishes who is calling. Authorization decides which action
that principal may perform on which resource. Execution ownership separately
decides which activation may commit. None substitutes for the other two.

| Boundary | Responsibility |
| --- | --- |
| Identity provider and credential adapters | Issue/validate human and service credentials; establish issuer-qualified principals and credential validity |
| Trusted protocol ingress | Authenticate every caller, bind verified identity to the request, limit input size/rate, and prevent forged identity headers |
| Transit authority | Enforce realm, action/resource grants, delegation bounds, policy revisions, ownership, and lifecycle at authoritative operations |
| Station and applications | Express policies and apply workload/domain rules; framework helpers cannot grant privileges or replace kernel checks |
| Trusted effect executor | Authorize each attempt, enforce destination/secret scope, perform external I/O, and authenticate outcome submissions |
| Storage/runtime adapters | Use separate service credentials for authorized infrastructure operations; translate identities without inheriting provider-wide privileges |

Authentication belongs at all entry points, including internal worker and
controller APIs. An edge proxy can authenticate clients, but the receiving
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

Grants describe subject, allowed actions, resource scope, validity, and policy
revision; exact representation remains open. Default deny applies to spawn,
send, inspect/read/tail, name lookup/mutation, supervision, effect request and
dispatch, secret use, runtime control, retention/GC, and policy administration.
Permission to send is not permission to inspect a mailbox, fetch a referenced
body, change its lifetime, or delegate the receiver's rights.

Messages retain authenticated origin and any explicit delegation reference.
Receiving a message does not automatically grant the sender's permissions to
the receiver or let the sender use all of the receiver's privileges. Delegation
must be explicit, bounded, and no broader than the delegator's current grant.
Authority delegation is distinct from application-level agent/task delegation.
Applications still validate domain rules, such as which account a command may
affect, even when Transit permits delivery to their process.

## Authorization over time

| Operation | Required decision |
| --- | --- |
| Message admission | Authenticate and authorize the sender, target PID/realm, message class, and lifetime; record the accepted provenance |
| Turn commit | Validate the process principal, current execution grant, ownership, prior state, and proposed outputs under the applicable policy |
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
connector, storage, and runtime-controller privileges separately scoped.

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

Protect history, checkpoints, transcripts, lookup/list results, logs, metrics,
and backups as data surfaces. A projection is not automatically public because
it is derived. End or reauthorize live subscriptions on credential/policy expiry
within the declared bound. Denial responses should not disclose private resource
existence or old receipts. Audit privileged accepted operations durably; bound
and rate-limit rejection telemetry so unauthenticated traffic cannot fill the
authoritative journal. Audit records omit credentials and unnecessary payloads.

A live read authorizes a bounded batch or interval, not unlimited future access.
Specify that bound and the point at which revocation prevents the next read
authorization; bytes already released cannot be recalled. This distinguishes
bounded subscription shutdown from an unsupported claim of instantaneous
revocation across every open connection.

## Trusted computing base and provider boundaries

The trusted computing base includes protocol authorities, credential validation,
policy control, storage integrity, selected handler-execution enforcement,
privileged adapters, and effect executors. Cluster/storage administrators can
alter these components and are outside the workload-adversary boundary. Do not
claim protection against a compromised administrator or trusted executor.

Transit validates protocol legality. That alone cannot prove a native handler
computed an honest state transition, is deterministic, or reported an external
response faithfully. M1 must choose and demonstrate the execution mechanism for
deterministic handlers. Recovery from recorded committed state and deterministic
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
[CONFORMANCE.md](CONFORMANCE.md), with implementation gates in [ROADMAP.md](ROADMAP.md).

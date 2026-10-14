# Identity, permissions and trust

Transit checks three independent questions: who called, whether that principal
may perform this operation now, and whether this worker owns the process
generation needed to commit. A PID, resource reference, session, cursor or ticket
answers none of them by itself.

## Principals, realms and grants

Native authentication uses Ed25519 credentials bound to stable login roles.
Roles, membership options, generic object ownership and grants share one paged
authorization catalog. Effective privileges follow current inherited grant
paths; credential rotation preserves role grants. Native permission masks name
actions in that same model, with independent process/resource scopes.
Realm, registry namespace, Kubernetes namespace and storage bucket are different
scopes. Role memberships support ADMIN, INHERIT and SET independently; object
grants support delegation options and RESTRICT/CASCADE. PUBLIC has no bootstrap
access. Cross-realm federation is not implemented.

Repeated grants preserve existing options and independent grantors. Ownership
transfer checks SET eligibility from the login role separately from inherited
owner authority. Exact logical role-name lookup is visible to authenticated
callers in the realm; private native roles and full role enumeration remain
restricted. Role metadata contains no credential material.

Supply credentials explicitly. Native callers sign canonical operations through
the [shared client](native.md); reserializing a signed request with an arbitrary
JSON client may change its meaning or signature. Imported credentials, native
support and a valid signature do not establish a running authority capability.
Perform the authorized capability read for the selected profile.

The native `declarative_authorization` capability exposes signed administration
and bounded inspection. Changes stage privately and publish against an expected
policy revision. A competing change rejects publication; abandoned staged work
confers no authority. Names resolve to stable IDs and retired IDs are not reused.
The [authorization contract](../../contracts/AUTHORIZATION_V1.md) defines the
workflow, credential lifecycle, evaluator budgets and current integration scope.

| Operation | Additional authority or condition |
| --- | --- |
| Send | Current admission rights to the target; not permission to inspect it |
| Turn commit | Current execution grant, fenced ownership, matching state/input basis and valid lifetime |
| Resource read | Current inspect/read grants, required association scope and live dependencies |
| Resource mutation | Current write rights plus the resource's fenced writer and turn boundary |
| History or receipt read | Current read authorization, even when the original write was accepted |
| Effect dispatch | Recorded intent plus a permitted attempt, destination, credential scope and budget |
| Policy/lifecycle/retention change | Its explicit administrative right |

An association, writer PID or lifetime owner does not grant access. Metadata
inspection is not entry-read permission. Applications still validate domain rules
after Transit admits a message. Authenticated origin is supplied by authority,
not decoded from application payload claims.

## Authorization changes over time

Revocation prevents later unauthorized operations; it does not undo an admitted
message. That message's subsequent processing uses the receiver's current
execution rights. Revoking delivery may prevent a pending output's first
admission without rolling back the source turn. Long-lived readers and adapters
must recheck current policy before each bounded protected disclosure.

Policy revision is distinct from a captured data revision. Authorization cursors
bind their caller, selected role, selector and policy revision. A revoked grant
does not override another independently valid grant path. Cascaded dependents
cannot revive when a former grantor later receives a new independent grant.

Growing `read_access` probes check the caller's current resource/association and
lifetime scope without returning entries. A retained signature or previous allow
response is not a bearer grant. A stronger gateway credential cannot replace the
caller's missing source permission. If current policy cannot be established,
access fails closed; the result is not proof that prior work never committed.

Table authorization binds stable database, schema and Table identities to native
objects. CONNECT and USAGE precede each Table privilege check; role ownership
governs ALTER and DROP. Metadata visibility follows the current object's grants
or ownership. Names and backing-resource associations do not inherit privileges.

The [Table service](../../apps/transit-table-service/README.md) lets a restricted
caller use one Table without raw access to the shared catalog resource. Its
private storage identity reads bytes while a separate, action-bound caller proof
supplies the credential epoch and selected role for authorization. It checks all
observed requirements before returning a complete response. Metadata is filtered
by current visibility. Historical definitions use the original Table's authority,
including after DROP or name reuse. Direct raw-resource grants deliberately allow
broader inspection and are not a Table isolation mechanism.

## Effects and secrets

Once an external attempt is authorized, treat it as potentially in flight, even
if its worker paused before sending. Expiry, revocation or fencing can prevent
new authorizations but cannot prove a remote action did not occur. Recovery uses
the connector's explicit idempotency/reconciliation policy or preserves unknown.
Closure rejects late results; it cannot promise remote cancellation.

Keep credentials as references in durable intents. Resolve them only inside the
authorized executor, scoped to destination, TLS identity and operation. Captures
mark omitted secret fields and cannot claim byte completeness where redacted.
Do not put keys, tokens, raw payloads or private data in logs, URLs or Git.

## Ingress and isolation profiles

The [database gateway](../../apps/transit-sql-gateway/README.md) requires TLS,
separate SQL password verifiers and explicit account/catalog bindings. SQL
credentials select a configured native principal; they do not grant resource or
catalog rights. Sessions recheck credential revision and current authority before
metadata, rows and terminal counts. Revocation can suppress a reply while an
admitted write remains in the account's private recovery ledger. Operator
reconciliation uses a separate signed control identity. Verifier rotation and
fenced replacement are described in its
[configuration guide](../../apps/transit-sql-gateway/docs/configuration.md).

Board admits viewers through its private deployment boundary. Everyone who can
reach it sees the configured shared scope; there is no per-viewer login or
credential session. Its upstream identity remains read-only. Optional query and
application operators use separate capabilities. See [Board access](board-api.md).

Serving uses scoped native proofs and current service policy. Its provisioned
public-key configuration is not a grant database. Reactive channels additionally
bind session, subscription, attachment, lease and source generation. TLS, exact
Host/Origin policy and native authorization are independent checks.

The local CLI gateway binds IPv4 loopback, accepts its configured exact Host
authorities and rejects browser Origin and forwarded-identity headers. Additional
local aliases do not expose a browser API or bind another interface. See
[server configuration](../../apps/transit-cli/docs/server.md).

SDKs and same-user local processes are trusted code, not a native-code sandbox.
Kubernetes/Substrate supplies the reference isolation boundary; storage and
provider credentials stay in their adapters. Configure each ingress using its
documented TLS, Host/Origin and authorization requirements.

[Service v1](../../contracts/SERVICE_V1.md), [state v1](../../contracts/STATE_V1.md)
and [native v1](../../contracts/TRANSIT_V1.md) specify exact permissions and
signatures. [Deployment](deployment.md) explains bootstrap and recovery trust.

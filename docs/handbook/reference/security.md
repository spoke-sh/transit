# Identity, permissions and trust

Transit checks three independent questions: who called, whether that principal
may perform this operation now, and whether this worker owns the process
generation needed to commit. A PID, resource reference, session, cursor or ticket
answers none of them by itself.

The [collaboration stories](collaborative-decisions.md#what-the-control--policy-plane-contributes)
describe the proposed extension from native grants to enterprise identity,
delegated agents and branch/publication policy. Those additions are not part of
the implemented authorization profile described here.

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

Repeated grants preserve omitted options and independent grantors. Turning off
an enabled membership option checks dependencies; a new SET-only membership or
an unchanged false option does not reconcile unrelated inactive grant paths. Ownership
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
The [authorization contract](../../../contracts/AUTHORIZATION_V1.md) defines the
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

The Stream/Queue foundation uses separate registered domains for metadata
inspection, payload reads, append/enqueue, consumption/claim and settlement.
Selection requires payload-read rights as well as consumption/claim rights;
settlement alone cannot disclose payloads. CONNECT and USAGE still apply, and
administration requires object ownership. A lease or consumer-group assignment
never grants access. This foundation does not yet enable Stream/Queue SQL or
catalog lifecycles; see the [authorization contract](../../../contracts/AUTHORIZATION_V1.md).

SQL authorization plans resolve database, schema and Table names through the
direct catalog and publish through native authorization against the observed
policy revision. Default Table grants apply when a new Table permission object
is registered. Adding or removing a default does not change existing Table
grants. Catalog listings filter inaccessible objects; an exact lookup of a live
Table without metadata privileges returns AccessDenied. SELECT permits retained
reads without granting mutation, definition changes or raw native resource access.

Direct namespace CREATE requires database ownership and eligibility for its
declared owner role; RENAME and DROP require ownership of the original native
schema. Admission and native registration are separate from catalog publication.
DROP removes live namespace visibility but preserves native permission references
for retained Table reads, receipts and result evidence. Those references remain
subject to current grants and resource lifetime. The
[namespace lifecycle](../../../contracts/DIRECT_TABLE_V1.md#namespace-lifecycle)
defines bounded RESTRICT checks, cancellation and exact recovery.

Typed direct Table mutations can retain an additional authorization condition
from an application's original accepted input. The worker needs its own Table
rights, and the original subject must still satisfy the retained condition at
admission and acceptance. Worker credential replacement preserves that condition;
it does not renew the original caller's authority. Current authorized workers
can still inspect or cancel the same operation after the original condition
fails. A previously accepted mutation remains accepted. See the
[direct Table authority contract](../../../contracts/DIRECT_TABLE_V1.md#requests-and-authority).

Root may explicitly bind an authorization domain to a native resource's
lifetime. The binding is immutable and grants no access to that resource.
Protected guard checks require both current rights and a usable bound resource;
a privilege decision alone does not establish usability. Direct Table database,
schema and Table domains bind their catalog resource, so later native query
publication checks the source lifetime even when the query runs in a different
state resource. Native transitions use their recorded time sample and existing
commit fence; see the [authorization contract](../../../contracts/AUTHORIZATION_V1.md).

The [direct Table owner](../../../contracts/DIRECT_TABLE_V1.md) lets a caller
use an authorized Table without raw access to the catalog lifetime resource.
Each signed action binds the original credential epoch, selected role and
connection. The node checks all accumulated requirements before disclosing a
response. Metadata is filtered by current visibility. Retained metadata and rows
use the original Table's authority after DROP or name reuse. Native raw-resource
grants are separate permissions; they do not authorize a direct Table operation.

Saved authorization changesets bind their reviewed scope and unsent intents to
an original signature. Before recovery signs a continuation, it verifies that
signer and the exact begin request against retained native admission evidence.
Replacing a saved public key and re-signing the document cannot borrow an earlier
published step. Credential rotation preserves this verification: the current key
permits recovery while the retained key identifies the original signed intent.

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

The [database gateway](../../../apps/transit-sql-gateway/README.md) separates TLS policy,
login authentication and native account/catalog bindings. Password logins use
SCRAM for PostgreSQL and TLS-protected full caching_sha2_password for MySQL.
Explicit trust logins are restricted to loopback and accept a claimed configured
name without verifying the OS user. Local owner bootstrap records a one-time
binding through ordinary authorization; restarting never restores revoked access. SQL
credentials select a configured native principal; they do not grant resource or
catalog rights. Sessions recheck credential revision and current authority before
metadata, rows and terminal counts. Revocation can suppress a reply while an
admitted write remains in the account's private recovery ledger. Operator
reconciliation uses a separate signed control identity. Verifier rotation and
fenced replacement are described in its
[configuration guide](../../../apps/transit-sql-gateway/docs/configuration.md).

The native [SQL session API](../../../contracts/SQL_SESSION_V1.md) uses the same
account authorization and recovery owner. Remote SCRAM binds the definition,
server instance, account, database and source over verified TLS. Local Linux
sessions map socket peer credentials to the configured account; a forwarded UID
header grants nothing. The default local account is provisioned once through
ordinary authorization. A nonsecret rendezvous locates its private socket;
consoles need neither the installation record nor native signing keys. Session
secrets expire, while operation tokens identify retained work and confer no
access independently of the current account and object grants.

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
[server configuration](../../../apps/transit-cli/docs/server.md).

SDKs and same-user local processes are trusted code, not a native-code sandbox.
Kubernetes/Substrate supplies the reference isolation boundary; storage and
provider credentials stay in their adapters. Configure each ingress using its
documented TLS, Host/Origin and authorization requirements.

[Service v1](../../../contracts/SERVICE_V1.md), [state v1](../../../contracts/STATE_V1.md)
and [native v1](../../../contracts/TRANSIT_V1.md) specify exact permissions and
signatures. [Deployment](deployment.md) explains bootstrap and recovery trust.

## Configuration administration

The [configuration service](configuration.md) uses a registered native domain
object scoped to its installation. Inspection, source provenance and reload have
independent privilege bits. The original caller signs the exact target, operation
and action; the gateway forwards that caller's own signed guard to current native
authority. Checking one's own subject does not require raw process inspection and
does not grant any of the guarded actions. Initial installation grants are
recorded once; restarting or reloading never restores a revoked grant.

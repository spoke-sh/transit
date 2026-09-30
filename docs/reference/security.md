# Identity, permissions and trust

Transit checks three independent questions: who called, whether that principal
may perform this operation now, and whether this worker owns the process
generation needed to commit. A PID, resource reference, session, cursor or ticket
answers none of them by itself.

## Principals, realms and grants

The implemented native profiles use Ed25519 identities, explicit realm binding,
ordered policy revisions, permission bits and separately scoped resource grants.
Realm, registry namespace, Kubernetes namespace and storage bucket are different
scopes. Cross-realm federation and general delegation are not implemented.

Supply credentials explicitly. Native callers sign canonical operations through
the [shared client](native.md); reserializing a signed request with an arbitrary
JSON client may change its meaning or signature. Imported credentials, native
support and a valid signature do not establish a running authority capability.
Perform the authorized capability read for the selected profile.

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

Growing `read_access` probes check the caller's current resource/association and
lifetime scope without returning entries. A retained signature or previous allow
response is not a bearer grant. A stronger gateway credential cannot replace the
caller's missing source permission. If current policy cannot be established,
access fails closed; the result is not proof that prior work never committed.

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

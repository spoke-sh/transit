# 10. Enterprise identity and the Control & Policy Plane

[Roadmap](README.md) · **Status:** Planned

Let an enterprise admit humans and agents through its identity infrastructure,
then explain which data, branches and operations each participant may use now.
Formalize authentication, identity bindings, delegation and policy evaluation
around the existing authorization graph. SQL `GRANT`/`REVOKE`, SDK operations,
MCP and application interfaces use the same owners; ingress adds no grant store.

## Prerequisites and scope

Build on the [data lifecycle](01-declarative-data-lifecycle.md),
[historical identities](05-standards-and-catalogs.md),
[branch scope](08-branches-merges-and-restore.md) and current
[authorization contract](../../contracts/AUTHORIZATION_V1.md).
Contract design can begin against current native principals and roles. Qualify
branch-dependent enforcement after the corresponding branch operations exist.
Current native authorization does not establish OIDC federation or enterprise IAM
integration; this milestone owns those additions.

The Control & Policy Plane owns catalog identities, trusted identity bindings,
policy and publication conditions. Data owners enforce access and conditional
acceptance; process/effect owners enforce execution and dispatch authority.
Application reasoning and task delegation remain application responsibilities;
the shared plane validates the resulting authorization delegation.

## Delivery sequence

1. **Define a shared access context.** Preserve authenticated actor, represented
   subject where applicable, enterprise/realm binding, client application,
   delegation identity and scope, authentication assurance and audience. Bind
   operations to their target object/branch and original identity. A claimed
   user name, forwarded header, PID or model instruction supplies no authority.
2. **Integrate enterprise authentication and membership.** Select trusted OIDC
   issuers and workload identity mechanisms; map validated issuer/subject pairs
   to stable Transit principals. Specify audience, key rotation, expiry and
   account lifecycle. Distinguish login ID tokens from API access tokens. Define
   ownership of IAM-managed memberships versus local grants, permitted claim
   mappings and provisioning/deprovisioning, including whether SCIM is supported.
   Synchronization must not silently override local restrictions or recreate
   access an operator believes revoked. Preserve independent valid grant paths.
3. **Specify freshness and failure behavior.** State which identity/membership
   decisions are live or cached, their maximum age, offboarding propagation and
   behavior during provider failure. Recheck current native rights at acceptance
   and each protected disclosure. Token validity alone cannot establish fresh
   external membership. Audit decisions without recording credentials or private
   payloads; an unavailable decision is not a grant.
4. **Implement bounded delegation.** Represent actor and subject distinctly,
   restrict audience, actions, objects/branches, lifetime and further delegation.
   An agent acting for a reviewer does not inherit human-only approval authority.
   Define separate authenticated, intent-bound approval and any required step-up
   authentication or separation of duties. Evaluate OAuth token exchange and
   enterprise-managed MCP authorization as adapters to this contract.
5. **Enforce branch and publication policy through all owners.** Separate inspect,
   branch creation, edit, share, propose, approve, merge and external activation.
   Support installations prohibiting every merge and protected destinations that
   reject direct-write bypasses. Source/data versions do not freeze permissions.
   Policy inheritance, explicit restrictions and their composition with grants
   must be defined before exposing them; introduce no assumed deny semantics.
6. **Expose bounded administration and explanation.** Show identity-binding and
   policy provenance, effective permitted actions and attributable denials under
   current inspection rights. Reuse existing policy publication/recovery and
   migrate all adapters together when a current-v1 contract changes.

## Completion evidence

Use an independent identity-provider fixture and real SQL/SDK/HTTP callers.
Exercise issuer/subject collisions, wrong audience, rotation, expired credentials,
stale groups, offboarding, provider outage, conflicting management sources,
delegation attenuation and revocation between pages. An agent must fail to claim
another subject or borrow its represented user's approval power. Prove that
branch-only and protected-destination policies cannot be bypassed through a
different adapter, including native operations. Inspect an original accepted
operation after a lost reply without granting access to revoked data.

Record actual propagation bounds and failure profiles. These checks do not
establish cross-realm federation or a universal IAM-provider compatibility claim.

## Primary references

- [OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html): authentication and identity claims.
- [OAuth token exchange](https://www.rfc-editor.org/rfc/rfc8693.html): actor/subject delegation mechanisms.
- [MCP authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization) and [enterprise-managed authorization](https://modelcontextprotocol.io/extensions/auth/enterprise-managed-authorization): protocol integration candidates, subject to selected provider/host evidence.

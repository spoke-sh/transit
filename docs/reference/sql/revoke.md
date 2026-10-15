# REVOKE

The dedicated [authorization interface](authorization.md) compiles REVOKE into
the shared native action. Review and explicitly apply its revision-bound plan;
query-only interfaces do not mutate policy.

```text
REVOKE [GRANT OPTION FOR] privileges ON [TABLE] [schema.]name FROM role [RESTRICT | CASCADE];
REVOKE [membership_option OPTION FOR] granted_role FROM member [RESTRICT | CASCADE];
```

The membership option prefix is optional; when present it is one of ADMIN OPTION
FOR, INHERIT OPTION FOR or SET OPTION FOR. DATABASE and SCHEMA object forms use
their [supported privilege sets](authorization.md). Each statement targets one
object/role and one recipient; RESTRICT is the default.

```sql
REVOKE UPDATE ON TABLE public.items FROM writer;
REVOKE GRANT OPTION FOR SELECT ON TABLE public.items FROM analyst CASCADE;
REVOKE SET OPTION FOR reader FROM analyst RESTRICT;
```

Revocation removes the selected grantor's authority and its dependent delegation.
Independent grants remain effective. RESTRICT rejects dependent changes; CASCADE
stages their bounded cleanup and publishes one completed policy root. Revoking
only an option preserves privileges still supported by that grant. Unfinished
candidates do not change access.

Current checks order later protected reads, continuations and publication after
revocation. Already disclosed bytes cannot be recalled, and a committed write
remains committed. Interrupted accepted work retains its identity and status for
authorized recovery. A saved request never restores access by itself.

See [GRANT](grant.md), [security](../security.md) and the
[authorization contract](../../../contracts/AUTHORIZATION_V1.md).
Source: [`revokeStatement`](../../../contracts/sql/TransitExtensions.g4).

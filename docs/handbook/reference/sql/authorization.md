# Role and schema administration

The dedicated authorization compiler resolves SQL to a reviewable typed plan.
The Table bridge/service `compile_authorization` operation uses this compiler. Native policy changes use
the explicit [administration lifecycle](../../../../packages/zig/transit-client/docs/authorization.md);
schema changes use the catalog owner. The query console, Board query worksheet
and Flight SQL retain their separate query interfaces.

Names resolve within one configured database/catalog binding. Schema and Table
names bind stable IDs before preparation. Plans include the original principal,
active role and policy revision. Preparation rejects a stale policy basis;
publication and disclosure still require current rights.

The local installation's direct catalog uses `DirectAuthorizationSql` for
role, membership, grant/revoke, default-privilege and ownership plans. It resolves
schema and Table names through signed metadata reads rather than raw catalog
resource access. CONNECT, USAGE and current metadata visibility are required even
for an administrator. The result uses the same native administration lifecycle;
compiling it starts no Table work or policy publication. SET/RESET ROLE returns
an explicitly checked selection without applying it to a session. Its default
read budget is 128 operations, with one namespace page resident at a time.
CREATE, RENAME and DROP SCHEMA are unavailable on this direct path. The schema
lifecycle forms below belong to the existing typed catalog owner.

| Object | Privileges |
| --- | --- |
| Database | CONNECT |
| Schema | USAGE, CREATE |
| Table | SELECT, INSERT, UPDATE, DELETE |

`ALL [PRIVILEGES]` expands to this set for the selected object kind. Ownership
controls schema/Table lifecycle and grant delegation separately from native PID
ownership. See [security](../security.md) and the
[authorization contract](../../../../contracts/AUTHORIZATION_V1.md) for the selected
SQL/PostgreSQL reference semantics and explicit exclusions.

## Supported forms

The compiler accepts one statement of at most 4096 bytes. Names contain at most
63 UTF-8 bytes. Quoted identifiers preserve case; unquoted identifiers follow
the shared SQL name rules. Each grant/revoke targets one object and one grantee.

```sql
CREATE ROLE analyst LOGIN;
ALTER ROLE analyst NOLOGIN;
ALTER ROLE analyst RENAME TO reporting_user;
DROP ROLE reporting_user;
GRANT reader TO analyst WITH ADMIN OPTION, INHERIT TRUE, SET TRUE;
REVOKE ADMIN OPTION FOR reader FROM analyst RESTRICT;
CREATE SCHEMA reporting AUTHORIZATION CURRENT_USER;
ALTER SCHEMA reporting RENAME TO reports;
ALTER SCHEMA reports OWNER TO analyst;
DROP SCHEMA reports RESTRICT;
ALTER TABLE public.items OWNER TO analyst;
ALTER DATABASE transit OWNER TO analyst;
SET ROLE reader;
RESET ROLE;
```

Role options are LOGIN/NOLOGIN and CREATEROLE/NOCREATEROLE. New roles default to
NOLOGIN. Credential provisioning is a separate typed action; passwords and keys
are not SQL role options. Membership records carry ADMIN, INHERIT and SET
independently. Repeating a membership grant preserves omitted options; a new
membership defaults to ADMIN false, INHERIT true and SET true.

`CURRENT_ROLE` and `CURRENT_USER` select the active role; `SESSION_USER` selects
the credential's login role. SET ROLE requires current SET eligibility from that
login role. Its compiled result is an explicit session selection, not a durable
policy mutation or a change automatically applied by compiling a file. RESET
ROLE and SET ROLE NONE select the login role. Owner assignment requires SET
eligibility; inherited data access alone is insufficient.

CREATE SCHEMA uses an explicit new schema ID and operation ID supplied alongside
SQL. Initial catalog configuration explicitly creates `public`; there are no
automatic PUBLIC access grants. Schema rename retains IDs. DROP SCHEMA RESTRICT
rejects a schema with a live or initializing Table. Its bounded scan detects
concurrent Table creation using the schema revision. Name reuse allocates a new
schema identity and does not restore earlier grants.

## Default privileges

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA reporting GRANT SELECT ON TABLES TO reader;
ALTER DEFAULT PRIVILEGES FOR ROLE analyst IN SCHEMA reporting REVOKE SELECT ON TABLES FROM reader;
```

Defaults are scoped to the creator role and one schema, and apply when a future
Table's native authorization object is published. They do not alter existing
Tables. IN SCHEMA is required; there is no realm-wide implicit default template.
PUBLIC can receive object privileges but cannot receive membership or delegation
options. See [GRANT](grant.md) and [REVOKE](revoke.md).

The profile excludes column grants, row policies, ABAC, security-definer routines,
password SQL, SUPERUSER, TRUNCATE, multi-object/grantee statements and DROP SCHEMA
CASCADE. Unsupported forms fail before preparation. Compilation alone is neither
authorization nor evidence of execution. Mixed policy/catalog work has ordered
outcomes, not a cross-owner transaction.

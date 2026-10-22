# GRANT

The dedicated [authorization interface](authorization.md) compiles GRANT into
the shared native action. Review and explicitly apply its revision-bound plan;
the query console, Board query worksheet and Flight SQL do not apply grants.

```text
GRANT privilege [, privilege ...] ON [TABLE] [schema.]name TO role [WITH GRANT OPTION];
GRANT CONNECT ON DATABASE name TO role;
GRANT USAGE, CREATE ON SCHEMA name TO role;
GRANT granted_role TO member [WITH ADMIN OPTION, INHERIT TRUE, SET TRUE];
```

Table privileges are SELECT, INSERT, UPDATE and DELETE. ALL [PRIVILEGES] expands
to the supported privileges for that object kind. One statement names one object
and one recipient. PUBLIC can receive object privileges but no grant option or
role membership. CURRENT_USER/CURRENT_ROLE select the active role; SESSION_USER
selects the login role.

```sql
GRANT SELECT ON TABLE public.items TO reader;
GRANT INSERT, UPDATE ON TABLE public.items TO writer WITH GRANT OPTION;
GRANT reader TO analyst WITH INHERIT TRUE, SET TRUE;
```

Repeated grants by the same effective grantor add to that grant's privilege and
option masks; they do not create duplicate effective edges. Other grantors retain
independent provenance. Membership ADMIN, INHERIT and SET options are independent;
omitted options on an existing edge remain unchanged. A new membership defaults
to ADMIN false, INHERIT true and SET true.

CREATE/ownership and grant options determine delegation. Native process and raw
resource rights remain separate typed capabilities; SQL SELECT cannot expose
raw backing pages. Names, associations and PID ownership confer no SQL grant.
See [REVOKE](revoke.md), [security](../security.md) and the
[authorization contract](../../../../contracts/AUTHORIZATION_V1.md).

Source: [`grantStatement`](../../../../contracts/sql/TransitExtensions.g4).

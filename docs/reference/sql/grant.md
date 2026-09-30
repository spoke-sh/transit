# GRANT

**Grammar only.** This statement describes granting privileges on a named object
to a named subject. It does not execute Transit's typed grant commands or change
query/source policy. The query console, Board query workspace and Flight SQL
reject it.

## Syntax

```text
GRANT privilege [, privilege ...] ON object_name TO subject_name;
```

Privileges, object and subject names are identifiers; at least one privilege is
required. The grammar does not enumerate valid privileges or resolve names to
realm-qualified resources and principals. It defines no validity interval,
policy revision, delegation clause or `WITH GRANT OPTION`.

## Example

This example illustrates syntax only; `read` and `inspect` are illustrative
identifiers, not an executable SQL privilege vocabulary:

```sql
GRANT read, inspect ON items TO analyst;
```

## Meaning and current interface

The form is intended to spell typed grant operations. Actual authority depends
on an authenticated principal, exact actions/resources and current policy.
PID ownership and resource permissions are separate; a grant does not establish
writer ownership. A name, association or connection cannot supply a grant.

Use the public [native protocol](../native.md) and
[security contract](../../../contracts/SERVICE_V1.md) for implemented operations.
Query-source policy has its own owner and must be configured explicitly.
[Security](../security.md) explains scope, current checks and delegation limits.

Source: [`grantStatement`, `privilege`](../../../contracts/sql/TransitExtensions.g4).
See also [REVOKE](revoke.md).

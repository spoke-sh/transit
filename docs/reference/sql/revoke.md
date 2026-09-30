# REVOKE

**Grammar only.** This statement describes removing privileges from a named
subject on a named object. It does not execute typed revocation or modify query
policy. SQL query interfaces reject it.

## Syntax

```text
REVOKE privilege [, privilege ...] ON object_name FROM subject_name;
```

All names and privileges are identifiers; the list is nonempty. The grammar
does not resolve principals/resources, validate a privilege vocabulary or define
`CASCADE`, `RESTRICT`, grant-option removal or a policy revision precondition.

## Example

This example illustrates syntax only; `read` and `inspect` are placeholders for
privilege names, not an implemented SQL authorization interface:

```sql
REVOKE read, inspect ON items FROM analyst;
```

## Meaning and current interface

Actual revocation uses the owning public authority or query-policy operation.
Current authorization continues to gate reads, replay and receipt reconciliation;
an old snapshot, query result reference or association does not preserve access.
Revocation does not undo accepted history or prove that a previously authorized
remote effect was canceled.

Use the [native protocol](../native.md) and its
[service contract](../../../contracts/SERVICE_V1.md) for supported commands.
See [security](../security.md) for current-policy rules and
[connectors](../connectors.md#unknown-outcomes-and-closure) for remote uncertainty.

Source: [`revokeStatement`, `privilege`](../../../contracts/sql/TransitExtensions.g4).
See also [GRANT](grant.md).

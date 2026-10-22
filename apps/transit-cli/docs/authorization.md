# Authorization administration

`transit auth` uses the shared native authorization client. It previews a typed
change, saves its signed identity, submits exact steps and inspects the retained
outcome. Only `submit` and `apply` send commands. The native authority owns the
roles, grants, credential bindings and policy revision. Files and SQL plans grant
no access. See the [authorization contract](../../../contracts/AUTHORIZATION_V1.md)
for the privilege model, delegation and current-check rules.

## Connection

The explicit JSON or YAML configuration has these fields:

| Field | Meaning |
| --- | --- |
| `version` | `1` |
| `connection.definition` | Current definition from `transit auth capabilities` |
| `connection.realm` | Native realm identity |
| `connection.principal` | Authenticated native principal; zero is the bootstrap root |
| `connection.role` | Optional selected role; null selects the bound login role |
| `url` | HTTP or HTTPS native authority URL, without embedded credentials |
| `seed_file` | Private signing seed file, resolved relative to the configuration |
| `request_timeout_ms` | Per-request timeout from 1 to 60000, default 5000 |

The seed remains a private file reference. It never enters SQL, saved operations
or result JSON. The configuration selects an existing identity; loading it
neither creates that identity nor restores revoked permission.

## Prepare and review

Put a native authorization query in a file. For example, `{"identity":{}}`
reads the selected role and current policy revision:

```sh
transit auth read --config admin.json --file identity.json
```

The result is `observation.body.authorization`. Its `revision` is the explicit
basis for preparation. A typed input contains `expected_revision` and `action`;
the action follows the generated native authorization contract. Native `Value`
fields, including role names, use hexadecimal UTF-8 bytes. SQL compilation
accepts ordinary SQL names and produces the same typed actions.

```sh
transit auth prepare --config admin.json --file change.json --output change.saved.json
```

This performs a read-only preview and signs a begin request without sending it.
The new file contains the mandatory definition, a `kind`, an opaque `record` and preview
evidence. It is created with mode 0600, synced before publication, and refuses an
existing path. Review `preview.complete`, changed-record count and work counts.
An incomplete preview has exhausted its bounded scratch allowance; it does not
prove that remaining dependency checks will pass during durable staging.

SQL uses an explicit catalog binding for the database name, schema and Table
identities:

```sh
transit catalog compile-authorization --config catalog.json --file grant.sql --output grant.plan.json
transit auth prepare-plan --config admin.json --file grant.plan.json --output grant.saved.json
```

`compile-authorization` supports the selected role, membership, privilege,
default-privilege, ownership and schema forms in the [SQL authorization
reference](../../../docs/handbook/reference/sql/authorization.md). The plan fixes its
scope, original principal, selected role, policy revision and resolved IDs.
`prepare-plan` requires the same principal and selected role at that revision.
Changing the source SQL or recompiling is a new proposal, not recovery of a
previously accepted change.

The direct catalog CLI requires native inspection and raw-resource privileges
in addition to SQL object rights. Restricted Table users use the mediated Table
service; granting SQL SELECT never supplies raw-resource permission.

## Explicit apply and recovery

```sh
transit auth apply --config admin.json --file grant.saved.json
```

`apply` locks this recovery file, resolves pending receipts, prepares a bounded
next step, atomically checkpoints it and only then sends it. A successful reply
is checkpointed before progressing. An interrupted invocation can use the same
command and file. Independent mutations by the same principal can still conflict
on native sequence numbers; the file lock does not serialize other clients.

The default budget is 16 submitted steps per invocation; `--steps 1..64` selects
a different budget. A `pending` result means further explicit apply calls are
needed. A terminal result distinguishes `published` from `abandoned`.
Publication changes one native policy root. A ready candidate grants nothing.

After a timeout, retain the file. An exact receipt lookup can recover a lost
reply even after credential rotation, using the principal's current key. An
absent receipt leaves the original pending signature unchanged. A rejected retry
does not prove that an earlier attempt failed. Stale policy bases require a
separate reviewed change; apply never re-resolves names or silently rebases it.

For hosts that schedule individual steps:

```sh
transit auth submit --config admin.json --file grant.saved.json
transit auth recover --config admin.json --file grant.saved.json --output recovered.json
transit auth next --config admin.json --file recovered.json --output next.json
transit auth observe --config admin.json --file recovered.json
```

`submit` sends once and prints its receipt without modifying the file. `recover`
writes a new record only when the authority proves acceptance. `next` preserves
an existing pending request, prepares one new step, or reports a terminal result.
An admitted change with no uncertain step can be closed with `abandon`, which
prepares a closure step for explicit submit/apply. It cannot undo publication.

## Scoped grant changesets

`prepare-set` accepts a document containing `definition`, `realm`,
`base_revision`, `managed_scope` and `intents`. The [shared client
reference](../../../packages/zig/transit-client/docs/authorization.md#scoped-changesets)
defines the six grant/membership/default intent tags and their explicit scopes.

```sh
transit auth prepare-set --config admin.json --file grants.json --output grants.saved.json
transit auth apply --config admin.json --file grants.saved.json --steps 4
transit auth observe --config admin.json --file grants.saved.json
```

The same recovery commands recognize the saved `changeset` kind. The complete
document and selected role are signed during preparation; each native change
publishes separately. The first preview does not certify later intents. Apply
checkpoints completed outcomes before moving on, and reports completed/total
counts when its submit budget is exhausted. An interrupted apply can therefore
have already published a prefix. A stale remaining basis requires a separately
reviewed document, and omitted grants remain unchanged. Documents contain at
most 32 intents and 32 managed targets; saved records are limited to 128 KiB.

## Schema operations

Schema SQL belongs to the catalog owner. Supply a positive native operation ID;
CREATE additionally requires a new, never-reused schema ID:

```sh
transit catalog compile-authorization --config catalog.json --operation 50 --schema 2 --file schema.sql --output schema.plan.json
transit catalog prepare-schema --config catalog.json --file schema.plan.json --output schema.step.json
transit catalog submit --config catalog.json --file schema.step.json
```

The native receipt is input admission. Inspect the schema request's retained
`schema_status` through the Table bridge/service to distinguish applied,
rejected and scanning outcomes. Rename preserves the stable schema and native
authorization identities. DROP SCHEMA supports RESTRICT and scans bounded pages;
concurrent Table admission changes the schema revision and rejects a stale drop.
Retired IDs remain reserved when names are reused.

Records are bounded to 32 KiB; neutral action input is bounded to 256 KiB. The
C ABI `transit_authorization_apply` and client host `authorization` operation use
the same implementation. See [the client lifecycle](../../../packages/zig/transit-client/docs/authorization.md).
Neither this workflow nor a sequence of SQL files is an implicit transaction
across policy and catalog owners.

# Explicit catalog operations

`transit catalog` compiles `CREATE TABLE`, saves exact signed commands and
observes their outcomes through the shared catalog caller. Provision an
explicit [catalog host](../../transit-query-host/README.md), native resource,
caller grants and worker ownership first. Creating a Table publishes its empty
Table descriptor and named definition. Query sources and mutation writers need
their own explicit configuration and policies.

## Connection and offline compilation

Use a version-1 YAML file, or an explicit `.json` file. Replace the example
identities with your provisioned catalog connection:

```yaml
version: 1
url: http://127.0.0.1:19105
seed_file: caller.seed
connection:
  scope:
    realm: 46
    resource: 3
    catalog: '42'
  owner: 2
  principal: 1234
request_timeout_ms: 5000
```

The catalog ID is a canonical positive uint64 decimal string. Native identities
are numeric and retain their native bounds. `seed_file` resolves relative to the
connection file; command input/output paths resolve against the working directory.
The configuration is at most 64 KiB. Request timeout is 1–60000 milliseconds,
default 5000. The HTTP/HTTPS URL has no embedded credentials, query or fragment.
Credentials are referenced by files, never command arguments. There is no
configuration discovery or environment overlay for these commands.

```sh
transit catalog capabilities
transit catalog compile --config catalog.yaml --operation 71 --object 81 --table 1 --file create.sql --output compiled.json
```

`capabilities` is local and needs no configuration. `compile` is offline: a file
containing only `version` and `connection` suffices, with no URL or signing key.
Neither operation establishes current authority or reserves an identity. The
SQL file is at most 4096 bytes. For example:

```sql
CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL);
```

The executable profile has exactly two columns: an explicitly `INT64 NOT NULL`
key and an explicitly nullable value of type `INT64`, `BOOL`, `UTF8` or `BINARY`.
Names and other bounds follow the [catalog contract](../../../contracts/DECLARATIVE_CATALOG_V1.md).
Operation and object flags accept canonical positive uint64 decimal values;
the Table ID is a positive uint32. Use fresh identities for new definitions.

The compiled JSON envelope contains a typed `request` and its current-definition
canonical hexadecimal bytes. Later commands validate both representations and
reject disagreement. Review and retain the artifact before preparing creation.
Compilation creates no native resource and sends no command.

## Initialization and policy

The host's immutable configuration must match an explicit initialization file:

```json
{"scope":{"realm":46,"resource":3,"catalog":"42"},"owner":2,"administrator":1234}
```

Save it as `initialize.json`, then prepare and submit:

```sh
transit catalog prepare-initialize --config catalog.yaml --file initialize.json --output initialize-prepared.json
transit catalog submit --config catalog.yaml --file initialize-prepared.json
```

The host checks the configured administrator before accepting initialization.
Its four-write turn publishes framework/configuration/policy/readiness together.
Use the returned receipt position to observe processing and inspect its separate
input disposition. `initialized` confirms the applied initialization. A repeated
matching initialization preserves existing policy; it does not reset grants.

```sh
transit catalog observe --config catalog.yaml --file initialize-prepared.json --input 17
transit catalog disposition --config catalog.yaml --file initialize-prepared.json --input 17
transit catalog describe --config catalog.yaml
```

Here and below, `17` is an example: use the actual receipt position for that saved
command. `describe` reads currently authorized catalog configuration and policy.

Conditional policy input is a plain JSON value, for example a new principal's
first catalog policy:

```json
{"expected_revision":"0","policy":{"scope":{"realm":46,"resource":3,"catalog":"42"},"principal":1235,"revision":"1","inspect":true,"create":false}}
```

```sh
transit catalog prepare-policy --config catalog.yaml --file policy.json --output policy-prepared.json
transit catalog submit --config catalog.yaml --file policy-prepared.json
```

Observe processing and read `disposition` for this exact saved command and its
receipt. Preparation checks current metadata; the host checks the condition again
at application. The expected revision is a canonical uint64 string, including
`"0"` for an absent policy; the replacement is its successor. The configured
administrator can restore policy after revoking its own inspection, but disclosure
remains denied until restoration applies. Native grants remain independently
required. These controls do not implement SQL `GRANT` or `REVOKE`.

## Creation and exact recovery

```sh
transit catalog prepare-create --config catalog.yaml --file compiled.json --output create-prepared.json
transit catalog submit --config catalog.yaml --file create-prepared.json
transit catalog observe --config catalog.yaml --file create-prepared.json --input 17
transit catalog disposition --config catalog.yaml --file create-prepared.json --input 17
transit catalog status --config catalog.yaml --file compiled.json
```

Only `submit` sends a native command. A receipt establishes admission;
`observe` distinguishes pending and processed input. `status` reads the original
creation receipt under current inspection policy: its `applied` outcome establishes
publication. Creation conflicts are frozen outcomes. `disposition` carries controls
and rejected-input outcomes separately; a null disposition alone proves neither
success nor rejection. Current authorization applies to all disclosure and retries.

Compilation and preparation require new output paths. The CLI atomically creates
a private 0600 JSON artifact, synchronizes its file and directory, and refuses
to overwrite an existing path. It then prints the same envelope on stdout.
Keep the artifacts private: they contain definitions or signed commands, although
they do not contain the signing key. A prepared envelope contains one non-null
opaque saved string. Retain it exactly.

After an unknown outcome, retry the original prepared file with the same
configuration and signing identity. Do not prepare a replacement or infer
rejection from a lost reply, process exit or failed stdout write. Each invocation
restores and validates the saved signed command. Callers sharing a principal must
coordinate native sequences; there is no automatic retry or session coordinator.
Deleting local files does not remove accepted work or catalog objects.

## Definition lookup and saved pages

```sh
transit catalog lookup --config catalog.yaml --name items
transit catalog definition --config catalog.yaml --object 81 --revision 1
transit catalog list --config catalog.yaml --output page-1.json
transit catalog list --config catalog.yaml --file page-1.json --output page-2.json
```

`lookup` resolves an exact, case-sensitive catalog name and checks the live Table
schema. `definition` reads an immutable object/revision pair without requiring
that the current Table still matches it. Both return a `definition` envelope;
an absent value is `null`. Names contain 1–16 ASCII letters, digits or underscores
and start with a letter or underscore. Object and definition revision flags are
canonical positive uint64 decimal values.

`list` returns one `page` envelope: a native resource revision, exactly eight
optional definition slots and an optional `next` cursor. Present entries are
dense and strictly ordered by name. `--output` optionally saves the same envelope
as a new private, non-replacing artifact; `--file` continues an original saved
page. Page inputs are at most 8192 bytes and validate all entries, scope, ordering,
revision and mandatory current cursor definition before credential loading.
A saved final page has no continuation and is rejected by `--file`; it never
implicitly restarts the listing. An empty final page is possible.

Each remote read checks current catalog inspection policy and native grants.
Cursors confer no authority. Continuation requires the exact resource revision;
`CatalogCursorChanged` means start a fresh listing without `--file` and discard
the old partial result. These are current reads, not retained snapshots. Listing
does not create a view or submit a command. Python, TypeScript and Rust have equivalent
metadata methods; other SDK metadata mappings remain separate from their
existing creation/control methods.

Typed initialization/policy inputs and compiled artifacts are at most 4096 bytes;
prepared envelopes are at most 65536 bytes, with an inner saved command bounded
to 8192 bytes. Malformed local artifacts reject before key loading or network I/O.
All commands have offline `--help` and validate supplied arguments even during
help. Results are one neutral JSON envelope on stdout; diagnostics use stderr.
Invocation/configuration failures exit 2, runtime failures exit 1 and successful
commands exit 0. See the [CLI reference](../../../docs/reference/cli.md) for human
output conventions and [proof ledger](../../../tests/README.md) for executed evidence.

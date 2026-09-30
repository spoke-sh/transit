# Explicit Table mutations

`transit mutate` compiles bounded `INSERT`, `UPDATE` and `DELETE` statements and
prepares, submits and observes commands through the shared Table mutation client.
Provision an explicitly authorized [Table writer](../../transit-query-host/README.md)
and its caller policy first. A query connection or read grant does not enable
writes. The console and `transit query` remain read-query interfaces.

## Connection and compilation

Use a version-1 YAML connection file, or an explicit `.json` file. Replace the
example identities with those of your provisioned writer:

```yaml
version: 1
url: http://127.0.0.1:19105
seed_file: caller.seed
connection:
  realm: 46
  principal: 1234
  writer: 2
  resource: 3
  table: 1
request_timeout_ms: 5000
```

`seed_file` resolves relative to the connection file. Command input/output paths
resolve relative to the working directory. Configuration is bounded to 64 KiB;
the request timeout is 1–60000 milliseconds. The URL must use HTTP or HTTPS and
have no embedded credentials, query or fragment. Credentials are never supplied
as command arguments. Use the same connection and signing identity for recovery.

```sh
transit mutate capabilities
transit mutate describe --config writer.yaml
transit mutate compile --config writer.yaml --name items --namespace 42 --file update.sql --output request.json
```

`capabilities` reports local compiler limits without configuration or network.
It does not establish authority. `describe` reads current authorized Table and
policy metadata. `compile` validates SQL against that metadata and saves the
canonical request and complete immutable reference. For example, `update.sql`
can contain:

```sql
UPDATE items SET value = 12 WHERE id = 7;
```

The namespace is a positive uint64; choose a fresh one for new work. Changed
bytes under an existing identity reject. SQL input is at most 4096 bytes. The
[mutation contract](../../../contracts/TABLE_MUTATION_V1.md) defines the exact
scalar types and the three-row insert / primary-key update and delete profile.
There is no SQL transaction spanning an earlier read and this write.

## Save, submit and observe

```sh
transit mutate next --config writer.yaml --file request.json --output step-1.json
transit mutate submit --config writer.yaml --file step-1.json
```

`next` reads current upload state and prepares one command. It does not submit
it. Every preparation requires a new output path. The CLI creates a private
0600 file atomically, synchronizes the file and directory, and refuses to replace
an existing path. Compilation and preparation print the same JSON envelope on
stdout after saving it. Keep these files private: they contain SQL values or
signed commands, although they do not contain the signing key.

Only `submit` sends a command. Its receipt proves admission. Use the receipt's
input position to observe processing of that exact saved command:

```sh
transit mutate observe --config writer.yaml --file step-1.json --input 17
transit mutate rejection --config writer.yaml --file step-1.json --input 17
transit mutate status --config writer.yaml --file request.json
```

Here `17` is an example; use the actual receipt position. Wait for processing
and inspect its separate rejection before preparing the next upload step into
another new file. Repeat preparation, submission and observation until durable
status is terminal. A null `prepared` result means there is no next command;
inspect status. It is not itself proof of application. The applied status carries
the affected-row count; a send receipt does not prove rows changed.

An unknown outcome retains the original prepared file. Retry that same file
with the same connection; do not create a replacement command or advance the
upload across uncertainty. Each invocation restores the exact saved signed bytes
through the shared native validator before dispatch. A process exit, missing
stdout receipt or output failure cannot establish rejection or cancellation.
Current authorization still applies to retries and disclosure.

## Explicit controls and bounds

```sh
transit mutate prepare --config writer.yaml --file request.json --control cancel --output cancel.json
transit mutate submit --config writer.yaml --file cancel.json
```

`prepare --control apply|cancel` saves the selected control without dispatch.
Submission still requires separate observation and status inspection. Applying
an unsealed upload rejects; cancelling cannot undo a terminal applied result.
Deleting local files does not cancel accepted work. Callers sharing credentials
must coordinate their native sequence; this command has no session coordinator
or automatic retry loop. One writer admits one active upload at a time.

The compiled artifact is a JSON `compiled` envelope containing hexadecimal
request and reference bytes. The prepared artifact is a JSON `prepared` envelope
containing an opaque canonical saved string, or null. Preserve that string
exactly. The native request is at most 799 bytes, its reference is 68 bytes and
the saved command is at most 8192 bytes. Compiled input envelopes are bounded
to 4096 bytes and prepared envelopes to 65536 bytes. Malformed local artifacts
reject before loading the key or contacting authority.

Every subcommand has offline `--help` and validates supplied arguments even
during help. Successful results are one neutral JSON envelope on stdout;
diagnostics use stderr. Invocation/configuration failures exit 2, runtime
failures exit 1, and successful commands exit 0. See the
[CLI reference](../../../docs/reference/cli.md) for diagnostic conventions and
the [proof ledger](../../../tests/README.md) for executed recovery evidence.

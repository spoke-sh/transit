# Transit CLI reference

`transit` starts a local server, manages installed applications and opens signed
query sessions. It is separate from the retained `rey-cli` administration utility
and `kubectl-transit` runtime tooling. Build it with `zig build transit` in the
pinned development shell, or use the [Nix local bundle](../guides/quickstart.md).

## Commands

```text
transit --help
transit --version
transit serve --config FILE [--initialize] [--no-ui]
transit server --config FILE [--initialize] [--no-ui]
transit console [--config FILE] [--format table|json]
transit query FILE
transit query-v2 FILE
transit app install --config FILE --file DECLARATION --operation ID
transit app replace --config FILE --file REPLACEMENT --operation ID
transit app retry --config FILE --operation ID
transit app status --config FILE --application NAME [--after INDEX]
transit app connect --config FILE --application NAME --caller NAME [--output FILE]
```

| Command | Input and outcome |
| --- | --- |
| `serve`, `server` | Aliases. Run the local supervisor in the foreground; `--initialize` creates a new installation. Version 3 starts Board by default; `--no-ui` runs headlessly |
| `console` | Versioned configuration; multiline, explicit-submit unified v2 SQL with terminal assistance and optional durable recovery file |
| `query` | Original single-line Table v1 shell and positional configuration |
| `query-v2` | Single-line KV/Table/Document shell with positional configuration and explicit recovery exports |
| `app install` | Freeze/sign a declaration under an operation ID; accepted management intent is separate from installed/ready/domain state |
| `app replace` | Conditional role replacement using `expected_revision`; stable durable IDs and current permissions remain |
| `app retry` | Retry the original frozen management request after uncertainty |
| `app status` | Read sampled deployment state and bounded receipt pages; pass the prior `next` as `--after` |
| `app connect` | Export a named caller connection, with a seed-file reference rather than an installer/root key |

There is no implicit current-directory credential discovery. `console` accepts
an explicit `TRANSIT_CONSOLE_CONFIG` environment default; `--config` overrides
it. Server and management configuration stay explicit. Configurations reject
unknown/duplicate fields and unsupported versions.

## Console commands

The console requires a semicolon outside SQL literals/comments before submission.
Slash commands start an empty draft and end at newline. Completion never submits.

| Command | Meaning |
| --- | --- |
| `/help` | Show available commands |
| `/sources`, `/tables`, `/schema` | Inspect the authorized source and schema |
| `/new ID` | Select an unused positive u64 query namespace |
| `/resume ID` | Observe an existing query without submitting SQL again |
| `/status`, `/info` | Durable query status or local session information |
| `/advance` | Continue the same admitted finite upload |
| `/next` | Read one result segment after complete-coverage verification |
| `/bundle`, `/restore-bundle HEX` | Export/import the canonical query bundle |
| `/pending`, `/restore TOKEN`, `/retry` | Export/import/retry an exact pending signed operation |
| `/cancel` | Explicit durable cancellation, separately admitted |
| `/retire`, `/collect` | Withdraw a terminal request and reclaim it in bounded steps |
| `/format table`, `/format json` | Select escaped display; no semantic change |
| `/quit` / EOF | Disconnect; accepted work persists |

`query-v2` shares these operations except the console's `/tables` alias and TTY
editing. The [v1 shell](../../apps/transit-cli/README.md) uses its own smaller
command set and correlation model; it has no `/new`, upload or collection commands.

## Configuration, output and recovery

Use [server configuration](../../apps/transit-cli/docs/server.md),
[application installation](../../apps/transit-cli/docs/applications.md),
[console configuration](../../apps/transit-cli/docs/console.md) and
[v2 source configuration](../../apps/transit-cli/docs/unified-query.md) for exact
fields, paths and bounds. Configuration alone never creates a grant.

Console JSON output keeps prompts and diagnostics off stdout. Full-width
integers remain decimal strings; binary stays hex and cell-state distinctions
are explicit. Each command reads a bounded page; the console does not accumulate
all rows. Previously displayed output cannot be recalled after revocation.

For `console`, normal disconnect/help exits 0, invalid invocation/configuration
exits 2, runtime or any piped-command failure exits 1, and an interrupted native
wait exits 130 after bounded settlement. Disconnect and SIGINT do not submit
cancellation. Recovery files explicitly opt into persisting private query intent;
use `/retry` and `/advance` to reconcile it, never fresh SQL as a timeout retry.

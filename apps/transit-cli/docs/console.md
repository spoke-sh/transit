# Transit console

`transit console --config console.json [--format table|json]` is the M24
explicit-submit interface over the shared v2 KV/Table/Document query session.
It needs a provisioned native authority, scoped caller and query workers. The
separate `query` and `query-v2` entry points retain their single-line contracts.
`transit server` remains under implementation; this command does not initialize
or adopt a launcher installation.

## Configuration and trust

Configuration is strict JSON, limited to 64 KiB. Unknown/duplicate fields,
unsupported versions and invalid endpoints reject before native operations.
Paths resolve relative to the configuration file. No environment, current
directory or home-directory credential discovery is performed. Explicit
`--format` overrides the file; other duplicate/unknown options reject.
`--help`, `--version` and `console --help` work offline.

```json
{
  "version": 1,
  "profile": "unified_v2",
  "url": "http://127.0.0.1:8301",
  "transport": "loopback",
  "seed_file": "caller.key",
  "connection": {
    "realm": 42, "principal": 1234, "source": 1, "resource": 7,
    "requester": 2, "requests": 8
  },
  "workspace": {
    "name": "items",
    "source": {
      "version": 2, "resource": 7,
      "source": {"table": {"id": 1, "names": ["id", "value"], "value_type": "int64"}}
    },
    "limits": {"pages": "1000", "segments": "100", "result_bytes": "1048576"}
  },
  "request_timeout_ms": 5000,
  "format": "table",
  "recovery_file": "console-recovery.json"
}
```

The example is a configuration shape, not allocated identities or a grant.
Use the actual provisioned IDs and source contract. Table names, KV decoders
and Document projections follow the [unified source guide](unified-query.md).
The timeout defaults to 5000 ms and must be 1–60000 ms.

`loopback` accepts literal `127.0.0.1` or `::1` HTTP endpoints. Remote connections
must select `tls_system` (HTTPS with system roots) or `tls_ca` (HTTPS with an
explicit `ca_file`). The latter uses only that trust bundle. Endpoint credentials,
query strings, fragments and path prefixes are rejected. The existing native
client verifies the peer and never follows redirects with signed requests.
Neither transport selection nor configuration grants native access.

## Input, commands and results

```text
/tables
/new 42
SELECT id, value
FROM items LIMIT 8;
/status
/next
```

SQL submits on a semicolon outside strings, quoted identifiers and nested
comments. In a TTY, Enter submits the completed statement; bracketed paste stays
in the draft until Enter. A slash command starts an otherwise empty statement
and ends at newline/Enter. Slashes and semicolons inside SQL literals/comments
remain content. EOF rejects an unfinished SQL statement without submitting it.
Typing or accepting completion never submits.

The slash commands are the [shared v2 operations](unified-query.md): `/sources`
(also `/tables`), `/schema`, `/info`, `/new ID`, `/resume ID`, `/status`, `/advance`,
`/next`, `/cancel`, `/retire`, `/collect`, `/bundle`, `/restore-bundle HEX`,
`/pending`, `/restore TOKEN`, `/retry`, `/help`, `/format table|json` and `/quit`.
Fresh SQL needs an explicit unused namespace. Unsupported SQL and unknown slash
commands fail before mutations; there are no administrative SQL aliases or Live
execution in this profile. Recovery commands do not require the current source
binding to load, while each native operation retains its own authorization.

JSON output has no prompt/banner on stdout. TTY controls and diagnostics use
stderr. Table output is one bounded page with manifest/coverage evidence,
column headings and escaped typed cells. JSON escaping preserves exact decimal
integers, float bits, hex binary and missing/null/type-error/conflict distinctions;
Unicode and terminal control characters are escaped in result presentation.
A receipt is input admission; `/status` distinguishes upload, admission and
verified completion. `/next` performs the shared complete-coverage verification
and current page read. It does not accumulate result rows in the session.

The Linux terminal supports Left/Right, Home/End (also Ctrl-A/Ctrl-E), Backspace,
Delete, Ctrl-U, eight-entry SQL history with Up/Down, and Ctrl-C draft clearing.
Slash commands and recovery arguments never enter history. No history is written
to disk. The horizontally scrolling, highlighted draft renders newline, Unicode
and control bytes as visible escapes; the underlying SQL remains unchanged.
The display responds to terminal resize and restores the original terminal
attributes on normal and handled-signal exit.

Ctrl-Space opens shared [cursor assistance](../../../contracts/QUERY_ASSISTANCE_V1.md).
Up/Down chooses a candidate, Tab/Enter accepts it, Escape dismisses it and Ctrl-Z
undoes the acceptance. Acceptance rechecks current metadata. Input queued while
a metadata read waits discards the older response. An idle result expires after
five seconds. Observed denial clears draft, undo, history, completion and result
cursor; frozen recovery intent remains separate. Previous terminal output was
already disclosed and cannot be recalled.

Normal disconnect/help returns 0; invalid invocation/configuration returns 2;
runtime failure returns 1. A piped session with any failed command returns 1.
An interrupted native wait disconnects with 130 after its bounded request
settles; it does not submit cancellation. Broken stdout similarly disconnects.
Cancellation is the explicit, separately admitted `/cancel` operation.

## Exact recovery and bounds

`recovery_file` is optional and explicitly opts into retaining private query
literals and signed intent, never private keys or result rows. A companion lock
refuses simultaneous managers of that file. The 128 KiB versioned record binds
realm, principal, requester, request resource and caller public key. Changes to
the source binding do not silently replace an already accepted operation.

The console writes a 0600 temporary file, synchronizes it, atomically replaces
the record and synchronizes the parent directory before sending a frozen
request. It records a received receipt before preparing a successor. Recovery
loads the exact bundle, pending request or admitted input; it never reconstructs
SQL or submits automatically. `/retry` and `/advance` reconcile that original
work. A failed persistence step stops further submission. Without the file,
explicit `/bundle` and `/pending` exports remain the recovery mechanism.

One session retains one 16 KiB bundle, one signed request and one result cursor.
SQL and TTY drafts are at most 4096 UTF-8 bytes. Piped slash recovery commands
are limited to 64 KiB. TTY history holds at most eight 4096-byte statements and
one undo draft. Completion retains at most eight candidates, one current read
and one result. One command has a fixed 1 MiB presentation buffer, released after
writing; no background poll or unbounded output queue exists.
Display/stdout writes have a two-second deadline and join on failure, preserving
accepted work even when a local pipe stops reading. Each upload
advance has a 30-second progress deadline and at most 132 steps in addition to
per-attempt transport deadlines. These are resident/operation bounds, not
retention limits or an external cancellation promise.

`just test::console table` exercises the real command over disk Ursula and query
workers, with pipe, controlling-PTY and explicit TLS trust fixtures. `kv` and
`document` select other source profiles. The [proof ledger](../../../tests/README.md)
distinguishes completed runs and remaining M24 server/lifecycle work.

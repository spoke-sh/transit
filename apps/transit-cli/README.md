# transit-cli

The additive `transit` executable starts a signed Table query shell. Existing
`rey-cli` administration commands remain separate.

```sh
nix develop
zig build transit
zig-out/bin/transit query query.json
```

Configuration contains `url`, `seed_file`, `connection`, and optional
`request_timeout_ms` (default 5000, range 1–60000). `connection` contains `realm`,
`principal`, `source` PID, source `resource`, numeric `table`, SQL `name`,
`requester` PID and requester resource `requests`. Provision the separate
[query host](../transit-query-host/README.md) and [query permissions](../../contracts/PUBLIC_QUERY_V1.md)
first. A configuration file never grants access by itself.

Enter one qualified read-only Table SQL statement per line to run explicitly.
M12's [SQL subset](../../packages/zig/transit-fuze/docs/sql.md) applies; the public
frame additionally caps encoded plans at 207 bytes, including an exact schema
fence. Unsupported operations fail before submission. No shell command creates,
changes or exports a Table. No query or result history is saved to disk.

| Command | Behavior |
| --- | --- |
| `/help` | Show commands and completion distinctions |
| `/tables`, `/schema` | Current authorized registered Table and schema |
| `/info` | Current connection, selected correlation and uncertain-operation state |
| SQL statement | Compile, freeze and submit one query; receipt means submitted |
| `/status` | Read admission, capture/delivery or verified complete status |
| `/next` | Read and render one segment of the verified complete result |
| `/resume ID` | Select an existing authorized correlation without rerunning it |
| `/cancel` | Freeze and submit explicit durable cancellation |
| `/retry` | Retry the exact uncertain submission or cancellation |
| `/format table`, `/format json` | Change rendering without changing query semantics |
| `/quit` / EOF | Disconnect; does not cancel durable work |

Integers remain full-width decimal strings and binary remains hex. Displayed
strings use JSON escaping so result bytes cannot issue terminal control commands.
Rows live only in the current command's arena. On observed denial, the shell
also clears its remembered query/prepared request. Earlier terminal output is
already disclosed and cannot be recalled; an idle shell holds no result cache.

One active query per configured principal is admitted. Other submitted requests
receive busy outcomes; independent shells sharing a principal may conflict on
its signed mutation sequence. An uncertain result must be reconciled with
`/retry`, not replaced by rerunning SQL. Resource observation conflicts can be
retried with the same read command. The shell does not claim automatic polling,
saved sessions, multiline editing or indefinite in-memory result accumulation.

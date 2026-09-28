# transit-cli

The `transit` executable provides the local `server`, explicit-submit `console`
and existing signed query shells. Existing `rey-cli` administration commands remain separate.

[M24](../../docs/roadmap/M24.md) implements the selected
[server/console contract](../../contracts/TRANSIT_CLI_V1.md). Shared parser and
cursor assistance lives in Fuze/query packages. The [console guide](docs/console.md)
covers versioned configuration, terminal editing, trust and exact recovery.
The [local server guide](docs/server.md) describes the implemented supervisor,
private native gateway and selected dependency/credential profile. Focused recovery,
gateway pressure, physical capacity and clean-checkout qualification pass within
the selected M24 profiles. Existing query entry points retain their qualified contracts.

`transit query-v2` adds the explicit KV/Table/Document SQL profile. Its
[unified shell guide](docs/unified-query.md) covers source declarations, finite
upload, namespaces, exact retries and owned nested results. `transit query`
continues to serve the original Table v1 profile below.

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
| `/resume ID` | Select an authorized correlation without rerunning it; an absent status is `unobserved`, not proof of submission |
| `/cancel` | Freeze and submit explicit durable cancellation |
| `/retry` | Retry the exact uncertain submission or cancellation |
| `/format table`, `/format json` | Change rendering without changing query semantics |
| `/quit` / EOF | Disconnect; does not cancel durable work |

Integers remain full-width decimal strings and binary remains hex. Displayed
strings use JSON escaping so result bytes cannot issue terminal control commands.
Rows live only in the current command's arena. On observed denial or unavailable/retired source, the shell
also clears its remembered query/prepared request. Earlier terminal output is
already disclosed and cannot be recalled; an idle shell holds no result cache.

One active query per configured principal is admitted. Other submitted requests
receive busy outcomes; independent shells sharing a principal may conflict on
its signed mutation sequence. An uncertain result must be reconciled with
`/retry`, not replaced by rerunning SQL. Resource observation conflicts can be
retried with the same read command. The shell does not claim automatic polling,
saved sessions, multiline editing or indefinite in-memory result accumulation.

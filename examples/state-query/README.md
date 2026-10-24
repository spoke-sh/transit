# Recoverable state query

`example-state-query` is a finite, non-trading SQL caller using the public
`transit-query` workspace. It queries synthetic Unicode records through KV,
Table or accepted Document state and prints one verified nested result page at
a time. It uses the same Zig compiler, finite upload and current result checks
as the shell, Board and language SDKs.

From the pinned Nix environment:

```sh
just examples::query table
just examples::query-compose table
just examples::query-reference table
```

Each task accepts `kv`, `table` or `document`. They create isolated disposable
fixtures with disk Ursula and an 8 MiB hot-store budget. Their provisioning keys
are public test fixtures; use these tasks only for the fresh synthetic realm they
create. The reference task uses existing owned infrastructure while creating its
own namespace and Substrate actors. It does not adopt a launcher installation.
See [placement and recovery](docs/placement.md) and the
[proof ledger](../../tests/README.md#m18-qualification) for executed profiles;
a runnable task alone does not establish qualification.

For a separately provisioned query service, build with `zig build
example-state-query` and run `zig-out/bin/example-state-query CONFIG.json`.
Configuration uses `url`, `seed_file`, `connection` and `workspace` from the
[unified caller guide](../../packages/zig/transit-query/docs/unified-client.md),
plus a positive `namespace`, `sql`, private `recovery_file` path, and `mode`
(`upload`, the default, or `read`). The parent directory must already exist.
`upload` prints durable status after all upload inputs commit; admission is not
result completion. `read` requires a completed query, verifies every page and
prints a final `complete_coverage: true` only after full manifest coverage.

A direct Table workspace supplies its exact published source and `executor`,
the native principal running the capture worker. The Table service and native
authority share the configured URL. Before a fresh upload, the caller observes
the current definition and signs a single-use capture for the selected namespace.
The recovery file saves that bundle before dispatch; reopening it does not select
a new cut or issue another capture grant. The direct local execution and separate
caller restart are exercised by:

```sh
zig build test-direct-captured-query -Doptimize=ReleaseSafe -Ddirect-query-example=true -- --follow-only
```

This uses the native local persistence owner and separate Table, query-worker and
requester resources. It does not qualify the older Compose or reference Table
fixtures, which still require migration to the direct service.

The recovery file atomically preserves one original bundle and exact pending
signed operation before dispatch. A network error exits with that operation
intact. Rerunning the same configuration retries identical bytes and observes
the committed input before preparing its successor. Changed SQL, source, budgets,
connection or namespace rejects recovery. Never delete an unresolved file to
start over. The URL may change with placement; the logical identity may not.
Use one caller process per principal and one recovery file per query. This
example qualifies OS-process restart, not host power-loss durability or concurrent
writers. The 0600 file contains source definitions and signed requests;
keep its directory private. It is recovery material, never an authority or grant.

Result memory is bounded by one page and its shared Arrow workspaces, independent
of total rows. JSON preserves all five cell states, full-width values, binary,
Unicode and provenance. A page arena is released after output. Output failures
may leave an emitted prefix; rerunning `read` starts a new verified traversal
from ordinal zero. No cancellation, expiry or retirement is implied by exit.

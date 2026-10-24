# Work items

This non-trading application stores work items in direct typed catalog Tables
and uses the shared application migration ledger. `WorkItems.zig` owns the state
encoding, command admission and data activation above Station. Table writes and
migration steps can stage across native turns; their domain outcomes establish
completion separately from input consumption.

From the pinned Nix environment, run `just test::work-items`. Its fixture runs the
actual worker, replaces it twice with fresh keys/generations, restarts authority
and disk storage, and resumes a 19-row migration from retained receipts. Lost
operator/worker replies retry identical native bytes. Unit tests exercise 33 rows,
empty tables, full-width keys, corrupt targets, exact receipts, abandoned
identities and explicit write release. Executed results and limits belong in the
[proof ledger](../../tests/README.md), including the source revision of each run.

`zig build example-work-items` installs `transit-work-items`. Pass a JSON file
with `url`, `principal`, `pid`, `generation`, `seed_file`, `activation_directory`
and `application` (`application`, `realm`, `administrator`, `writer`, `resource`, `owner`
IDs). Credentials and grants must already exist. A restarted worker requires a
fresh native ownership generation; local activation markers never supply rights.
`owner` must match the worker PID. `--bootstrap-json` uses the public fresh-key
runtime handshake.
An explicit administrator command binds the application to an existing direct
data service and namespace. Native application state retains that binding,
dispatch references and migration progress; Table rows belong to the data owner.
The [local workflow](docs/local.md) grants access through recoverable public
authorization changes. Startup never recreates grants or a private catalog.
Worker diagnostics exclude data and keys. Current read failures leave the input
unresolved; malformed/denied commands have retained dispositions.
The initial ownership read retries temporary unavailability within
`request_timeout_ms` before writing its activation marker. Authority denial and
stale ownership still stop startup.

Run `just test::work-items-browser` for the generated standalone frontend,
conditional interface publication, migration, exact saved query recovery after
gateway replacement, cancellation, new schema queries and current denial. The
browser checks all three result pages, business labels, keyboard navigation,
two densities, 320 px layout and axe accessibility. See the [browser composition
guide](docs/browser.md) for roles, finite limits and recovery.

See [the selected migration](docs/migration.md) for application revision changes.
Authority movement and disaster recovery follow the separate
[deployment boundary](../../docs/handbook/reference/deployment.md).

The [physical placement guide](docs/placement.md) describes the owned Compose
and reference tasks, role-specific files, TLS edge and fresh-key recovery. The
proof ledger records which source revisions completed those schedules.

The package also has its own build manifest and domain CLI. Follow [separate build and local iteration](docs/local.md) to install it through the public application installation contract.

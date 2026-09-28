# Work items

M23's non-trading application uses a two-column Table and the shared application
migration ledger. `WorkItems.zig` is application code, outside Board and the
kernel. The data owner and independently scheduled native worker now pass disk recovery.
The generated browser and Compose/reference placement qualifications remain open.

From the pinned Nix environment, run `just test::work-items`. It provisions an
isolated synthetic realm, runs the actual worker, replaces it twice with fresh
keys/generations, restarts the authority and disk store, and resumes a 19-row
migration from retained receipts. Lost operator/worker replies retry identical
native bytes. Old keys cannot replay accepted proposals after replacement;
current migration denial leaves progress unchanged. The run measured 15.75 seconds,
53 observed turns, 20 bounded page reads, four mutations and 142 value bytes at
maximum. Unit tests separately exercise 33 rows, empty tables, full-width keys,
corrupt targets, exact receipts, abandoned identities and explicit write release.

`zig build example-work-items` installs `transit-work-items`. Pass a JSON file
with `url`, `principal`, `pid`, `generation`, `seed_file`, `activation_directory`
and `application` (`application`, `realm`, `administrator`, `writer`, `resource`
IDs). Credentials and grants must already exist. A restarted worker requires a
fresh native ownership generation; local activation markers never supply rights.
`--bootstrap-json` uses the existing public fresh-key runtime handshake; this
entry point is not yet a qualified reference placement or automatic controller.
Worker diagnostics exclude data and keys. Current read failures leave the input
unresolved; malformed/denied commands have retained dispositions.

See [the selected migration](docs/migration.md). Work is tied to
[M23](../../docs/roadmap/M23.md), with authority movement reserved for M24.

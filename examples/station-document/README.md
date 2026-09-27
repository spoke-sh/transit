# Collaborative Document example

Two independent Zig editor processes submit structured and Unicode text changes
to the [Document worker](../../apps/transit-station-document-worker/README.md).
The synthetic shared note is a non-trading application. Changes use the public
`Request`/`Caller` API; the example runs no alternate CRDT implementation.

Run `just examples::document` from `nix develop`. It creates isolated disk Ursula,
a growing Transit node, two caller resources and one Document resource, using
ephemeral keys and explicit grants. The runner removes only its own temporary
state after completion. The local schedule passes in 571.4 seconds with an 8 MiB
hot-store limit; see [evidence](../../tests/README.md#m17-work-in-progress).
Compose/reference tasks and their physical trust boundaries are described in the
[placement guide](docs/placement.md). Compose passes in 208.78 seconds with bounded
hot storage and cold spill; reference qualification is tracked separately.

The schedule prepares two edits against the same accepted note, keeps one caller
disconnected, then submits in reverse order. It checks conflicts, Unicode scalar
ordering, explicit resolution and duplicate acceptance. It kills the actual
writer during candidate publication, restarts the node and disk store, denies
then restores request access, and recovers under fresh ownership. The proxy
withholds one successful acceptance acknowledgement and verifies exact signed
retry. An opted-in checkpoint window then forces stale-replica resynchronization;
permanent retirement rejects delayed changes.

`example-station-document CONFIG.json` also supports `publish`, `receive`,
`inspect` and `resynchronize` modes. The generated configurations demonstrate
required identities, seed paths, activation directories and canonical SDC1 input.
Each executing invocation needs fresh ownership. Inspection uses current read
grants without executing as the writer. The application view reads the `title`
and `body` fields, with an explicit 512-byte/128-page display budget; exceeding it
fails rather than silently truncating text.

The Python runner provisions and observes through public signed CLI operations.
Zig binaries own all caller/service semantics. A completed publication or a sent
call is not an accepted change; only the recorded correlated outcome establishes
acceptance. Hosted cost and physical placement require their own measured runs.

`just transit-board::document-test` adds real accepted-metadata, source-cut,
retained-floor and current-grant checks. `just transit-board::document-browser`
also exercises the embedded view and clearing after live read revocation. Both
run the complete local two-editor schedule, with their own temporary Board process.

# Counter

A runnable Transit application that adds each input to its committed state.
[main.zig](main.zig) owns configuration, activation, polling and commit retries;
[handler.zig](handler.zig) owns checked integer addition and application encoding.

Run the complete local demo from the repository root:

```sh
nix develop --command just examples::run counter
```

It starts disposable disk-backed infrastructure, sends `7` and `5`, invokes
`example-counter`, and verifies committed state `12`. See the
[example setup](../README.md) for provisioning and cleanup details.

## Running against your development authority

Build with `just examples::build`. A trusted operator must first create a process,
grant its caller principal PID-scoped `execute` and `inspect` (permission bits
`24`), and record ownership. The application receives only that caller's key.
For a fresh manual setup, root's commands are `spawn`, `grant`, then `own` with
`expected_generation: 0`. Take the PID from the spawn receipt and use generation
`1` after ownership is accepted. Keys and request sequences follow the
[service profile](../../contracts/SERVICE_V2.md).

Create `counter.json` with your actual authority, principal, PID, generation and
private seed-file path:

```json
{
  "url": "http://127.0.0.1:8080",
  "realm": 42,
  "principal": 1,
  "pid": 1,
  "generation": 1,
  "seed_file": "/absolute/path/to/counter.key"
}
```

The seed file contains 32 private bytes as hex and should have owner-only
permissions. These example IDs do not create or authorize a process. Then run:

```sh
zig-out/bin/example-counter counter.json
```

The program waits for input and processes it in mailbox order. For one input:

```sh
zig-out/bin/example-counter --once counter.json
```

Unavailable or malformed responses are retried with a 200 ms delay. An uncertain
commit retries the exact signed operation; it never advances from an unusable
receipt. Valid permission rejections and stale activations stop the caller.

State and inputs are signed 64-bit integers encoded as decimal UTF-8 text inside
Transit's opaque values. For example, a `send` body for `7` is
`{"send":{"pid":1,"value":"37"}}`. Empty state or input is treated as zero;
`"30"` explicitly encodes `0`. Overflow or malformed decimal input commits a
failure with unchanged state, leaves the input pending, fences ownership and
exits with an error. Transit validates that failure's protocol structure; it
does not check the arithmetic itself.

Optional `publish_to: PID` emits the new state to that fixed destination on each
successful turn. Add the source PID's `publish` grant (combined permission bits
`88`) and arrange separate delivery. Omitting it produces state-only turns.

## Kubernetes and Substrate

This is the reference deployment's sample workload, not a platform worker daemon.
`just launchers::reference::images` packages it as `example-counter`; the runtime controller
reconciles its PID and current sandbox activation.

The reference template uses:

```sh
example-counter --bootstrap-json '{"url":"http://transit.example:8080","realm":42,"principal":1,"pid":1}'
```

Those are illustrative public settings; the harness supplies the real authority
and process. Bootstrap generates a fresh private key in memory, prints public
registration evidence, and waits for the controller's verified activation. No
signing seed is embedded in the image or template. The counter pins the accepted
generation and cannot acquire a newer one itself. See
[reference setup and tests](../../deploy/reference/README.md#prerequisites-and-lifecycle).

## Diagnostics

`LOG_LEVEL` / `LOG_FORMAT` configure stderr through the
[telemetry runtime](../../packages/zig/telemetry/README.md). Configured activation
identity and short proposal-preparation spans explain local work; they do not
claim ownership or committed progress. Each public client attempt has its own
span linked to the prepared proposal. Receipts and bootstrap JSON remain on stdout;
input/state bytes and keys are excluded from diagnostics. Idle polling is debug.

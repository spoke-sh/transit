# Byte log

A runnable Transit application that appends each input's bytes to committed state.
[main.zig](main.zig) owns configuration, polling and commit retries;
[handler.zig](handler.zig) owns byte concatenation and the state-size limit.

Run the complete local demo from the repository root:

```sh
nix develop --command just example byte-log
```

It starts disposable disk-backed infrastructure, sends `hello` and ` world`, runs
`example-byte-log`, and verifies state `hello world`. See the
[example setup](../README.md) for provisioning and cleanup details.

## Running against your development authority

Build with `just build-examples`. A trusted operator must create a process with
empty or application-defined initial bytes, grant the caller PID-scoped
`execute` and `inspect` (permission bits `24`), and record ownership. The
[counter provisioning instructions](../counter/README.md#running-against-your-development-authority)
use the same protocol operations. Create `byte-log.json` with your actual values:

```json
{
  "url": "http://127.0.0.1:8080",
  "realm": 42,
  "principal": 2,
  "pid": 5,
  "generation": 1,
  "seed_file": "/absolute/path/to/byte-log.key"
}
```

The private seed file contains 32 bytes as hex with owner-only permissions. Run
continuously, or commit one pending input and print its receipt:

```sh
zig-out/bin/example-byte-log byte-log.json
zig-out/bin/example-byte-log --once byte-log.json
```

The continuous and one-input commands are alternatives; serialize callers sharing
a principal. This example uses a pre-provisioned key and activation. It does not
implement the counter example's Substrate bootstrap mode.

Unavailable or malformed responses are retried with a 200 ms delay. An uncertain
commit retries the exact signed operation; it never advances from an unusable
receipt. Valid permission rejections and stale activations stop the caller.

Input can contain arbitrary bytes, including NUL. There is no implicit separator
or text decoding. The wire encoding is lowercase hex: `hello` is
`"68656c6c6f"`, and empty state is `""`. State is limited to Transit's current
256-byte inline value. Exceeding that size records a blocked failure, preserving
state and pending input; it never truncates or silently discards bytes. This
small example is not a replacement for durable mailbox or stream storage.

Optional `publish_to: PID` emits the new state atomically with each successful
turn. This needs source PID `publish` permission (combined bits `88`); an
authorized courier/controller delivers the committed output separately.

`just test-callers` runs this binary and the counter against the same generic
node, including binary data, lost responses, ownership replacement and restart.

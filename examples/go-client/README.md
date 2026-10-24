# Go input submission and recovery

This program sends application bytes to an existing process and reports its
admission receipt. It prepares and persists the signed operation separately from
dispatch so an interrupted caller can recover the original outcome without its
signing seed. A receipt does not establish handler completion.

Install the [Go SDK and matching native library](../../sdks/go/README.md), then
build this example with Go 1.26.7 and cgo on Linux amd64. In the checkout, the
module's `replace` entry selects the public SDK. For a separately copied example,
point that entry at the extracted SDK module before building:

```sh
go build -o transit-go-client .
```

Create a private configuration file for a provisioned realm, process and caller.
The principal needs the current grant for the requested operation. The sequence
belongs to that principal and must be coordinated with its other callers.

```json
{
  "url": "http://127.0.0.1:9010",
  "native_directory": "/opt/transit-go/lib",
  "realm": 72,
  "principal": 65536,
  "pid": 1,
  "sequence": 1,
  "seed": "/private/caller.seed",
  "pending": "/private/input.pending.json",
  "value": "hello"
}
```

The native directory must contain the library from the SDK's matching build and
retain its Nix runtime closure. The seed file is a private hexadecimal encoding
of 32 bytes. No command provisions resources or grants access.

```sh
./transit-go-client capabilities caller.json
./transit-go-client prepare caller.json
./transit-go-client dispatch caller.json
```

`prepare` creates the recovery file with private permissions, refuses to replace
an existing file, and syncs both the file and its directory. It prints operation
metadata without the payload. `dispatch` imports that exact file and makes one
attempt, printing the admission receipt on success. It does not read the seed.
After a lost response, run `dispatch` again with the same file; keep the original
sequence and bytes. A failure leaves the recovery file intact.

`just bindings::go-sdk-test` builds this actual example outside the checkout and
checks its saved bytes and seedless dispatch against the shared recovery scenario.

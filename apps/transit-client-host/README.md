# transit-client-host

The standalone native port for raw Transit SDKs. It depends on `transit-client`
and its public protocol and telemetry dependencies; it does not import Station,
Fuze, handlers or a provider. See the [client ABI guide](../../packages/zig/transit-client/docs/bindings.md).

```sh
zig build transit-client-host
zig-out/bin/transit-client-host /private/client.json
```

Configuration contains an explicit `url` and optional `timeout_ms` (default
5000, range 1–60000). Construction reads no credentials. `prepare` requires an
explicit seed file containing 64 hexadecimal characters; seedless `metadata`
and `call` accept exact exported retry strings. Import validates canonical shape;
authority dispatch validates signatures and current authorization.

Send one JSON line and await its response before sending another. `hello` returns
`host_version: 1` and `transit_version: 1`; `capabilities` advertises local operation
metadata, opaque recovery and growing-profile support. These do not establish
running authority capabilities. The other requests are `prepare`, `metadata` and
`call`; schemas are generated from the client package's owning Zig types in
[abi-v1.json](../../packages/zig/transit-client/abi-v1.json).

Responses contain `status` and `value`, using the client ABI's exact status codes.
Preparation returns a canonical string to persist unchanged before dispatch.
Metadata includes its SHA-256 identity, profile, kind, principal, sequence and
send destination, without its payload or signature. Identity is descriptive, not
an authorization token or proof of admission. A recovered send must be checked
for its operation kind and profile before a public SDK presents it as one.

The input budget is twice the protocol body limit plus 16 KiB. The parent must
bound its own frames, one outstanding request, diagnostics and lifecycle. Stdout
is reserved for protocol responses; stderr must be drained or inherited. EOF joins
the current native operation before releasing handles. A killed port can leave a
mutation uncertain; retry saved bytes or reconcile under fresh ownership.
`just test::client-abi` exercises this executable against disk-backed Ursula,
including fresh-process recovery without the original seed file.

`shutdown` is an explicit local lifecycle request. After the preceding operation
finishes, the owner destroys its client, responds with `{"closed":true}` and
exits successfully without waiting for stdin EOF. An adapter can await the
acknowledgement and child exit to join cleanup. This does not cancel accepted
work or replace its receipt/recovery evidence. A missing acknowledgement is a
cleanup failure, never proof that a mutation was rejected.

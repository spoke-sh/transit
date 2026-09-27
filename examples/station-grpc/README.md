# Finite RPC caller

This non-trading Zig application binds a local generated descriptor, publishes a
finite protobuf batch, records its correlated call and reads the captured reply.
It has no external RPC transport or credential resolver. Publication progress,
peer/correlation and authenticated outcomes live in its associated resource.

```sh
nix develop --command just examples::grpc
nix develop --command just examples::grpc-bootstrap
nix develop --command just examples::grpc-compose
nix develop --command just examples::grpc-reference
```

The shared [operator schedule](../exchange/README.md) runs an independent grpcio
TLS peer from the pinned environment. The checked-in [schema](exchange.proto)
defines a finite bidirectional exchange. The caller sends original protobuf with
binary/Unicode/full-width values and an empty message. Descriptor lookup fixes
the method path, shape and complete descriptor digest without network reflection.
The ordinary SDK/worker proofs separately cover all four method shapes.

`example-station-grpc CONFIG.json` accepts `publish`, `receive` and `replay` modes.
Configure the authority URL, realm/principal/seed, PID/fresh generation, worker
PID, immutable publication namespace, endpoint revision and fixed reconciliation
deadline. `descriptor` contains a hex FileDescriptorSet, `method` its exact path,
`messages` a finite array of original protobuf hex values, and `metadata` ordered
literal or versioned-secret entries. The example's literal metadata JSON uses
text strings; the shared public SDKs also expose arbitrary binary metadata.
Namespaces cannot be reused with different content. Preserve identical source
configuration until publication completes and after ownership replacement.

`publish` resumes bounded upload and returns the saved call on repeat. `receive`
authenticates the original peer and correlation before storing the outcome; a
separate delivery identity delivers outputs. `replay` reports only the response
byte count and SHA-256, without printing protobuf or interpreting business values.
Unknown outcomes cannot open a complete replay. All reads require current grants.

`--bootstrap-json JSON` creates a fresh in-memory key, emits one public
`growing_bootstrap` registration and waits for the configured exact generation.
The operator authenticates the physical source before issuing grants and
ownership. Seed files are forbidden in this mode. Optional `park_after_result_ms`
(at most 300,000; bootstrap only) keeps a finite caller inspectable after its
result; it does not extend ownership or deadlines.

Configuration is at most 256 KiB; descriptors at most 64 KiB; messages at most 64,
16 KiB each and 64 KiB total framed data. Metadata is at most 8 KiB. Publication
uses ordinary 256-byte chunks and four-mutation turns; no kernel limits change.
Host files are input, not authoritative state. Uncertain Transit writes retry
identical signed bytes; exhausted retries require explicit fresh ownership.

The local task proves scoped identities and durable recovery. Compose and
reference tasks additionally test caller/effect isolation, using the shared
[placement guide](../station-http/docs/placement.md). Reference requires the owned
cluster and pinned runtime image to be prepared; it creates a separate namespace
and leaves the default installation alone. The caller runs in Substrate/gVisor
and the effect worker in an egress-confined pod. Automatic growing bindings and
supervision are not implemented by this example. Local timings and the exact
completed placement proofs are recorded in [tests](../../tests/README.md).

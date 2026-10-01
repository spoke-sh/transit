# Finite exchange example support

The [HTTP caller](../station-http/README.md) and
[RPC caller](../station-grpc/README.md) share this operator-owned recovery schedule,
Compose topology and isolated Kubernetes/Substrate placement code. Their Zig
callers and effect workers remain separate binaries with protocol-specific
request/replay validation. The operator issues scoped grants and explicit fresh
ownership through the public growing protocol; provider placement grants no
execution rights.

`run.py` provisions disposable disk Ursula, an authority, caller and connector
resources, and an independent TLS peer. It verifies the same saved call after
caller replacement, then restarts node/store and replays after deleting the
credential and stopping the peer. Protocol selection is fixed by each example's
runnable entry point. HTTP uses a synthetic POST; RPC uses a protoc descriptor
and original binary/Unicode/full-width protobuf plus an empty message.
Saved-call recovery checks the shared publication marker against the complete
frozen request. The schedule rejects a changed reconciliation deadline before
resuming the original peer and correlation under fresh ownership.

`compose.py` builds static Zig images and packages only the pinned Python closure
needed by the independent fixture. RPC adds pinned grpcio; it is never a worker
runtime dependency. `reference.py` composes the existing Transit chart and
Substrate runtime in a generated namespace, authenticates physical caller
registration and checks namespace identity before cleanup. It does not update
the default launcher installation. See the
[placement and isolation guide](../station-http/docs/placement.md) for the shared
network/file boundaries and explicitly unsupported automatic growing bindings.

Run `just examples::http[-compose|-reference]` or
`just examples::grpc[-compose|-reference]`; these are separate literal task names,
not shell bracket expansion. The `*-bootstrap` tasks qualify fresh in-memory
caller keys locally. Evidence belongs in [the test guide](../../tests/README.md).

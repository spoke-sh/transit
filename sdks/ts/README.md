# TypeScript and Node.js SDK

`@transit/client` and `@transit/station` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use Node.js 24 on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Install the local tarballs for `@transit/client`, `@transit/station`,
`@transit/native-client` and `@transit/native-station`, all at version 0.2.0.
Set both dependencies and `pnpm.overrides` to the local tarball paths, then run
`vp install`. The [raw client guide](transit-client/README.md) describes package
resolution and explicit native-host overrides.

Import raw callers from `@transit/client` and runners from `@transit/station`.
Each client owns a native port. Use `try/finally` and await `close()`; aborting an
await does not cancel accepted durable work. Public identities use `bigint`
where the contract permits full-width integers.

These packages target Node.js. The runtime's browser query, reactive and Board
libraries remain separate; they do not load the Node native port.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.

# Ruby SDK

`transit-client` and `transit-station` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use Ruby 3.4.9 on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Install the locally built 0.0.1 gems with their `transit-native-client` and
`transit-native-station` dependencies:

```sh
gem install --local --user-install /path/to/gems/*.gem
```

Require `transit/client` for raw callers and `transit/station` for the framework.
Block-scoped clients own native ports and join their work when closing. Importing
definitions starts no port and discovers no credentials. Preserve exact recovery
material when a caller is interrupted. Registry publication is not available.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station/README.md)
- [Caller semantics](../../docs/handbook/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.

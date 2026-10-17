# Python SDK

`transit-client` and `transit-station` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use CPython 3.13 on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Install the locally built wheels and their matching `transit-native-client` and
`transit-native-station` wheels into your virtual environment. Use the wheel
output directory as an explicit local package source; no public registry release
is available. The native wheels supply the shared libraries and ports.

```sh
python -m pip install --no-index --find-links /path/to/wheels transit-client==0.2.0 transit-station==0.2.0
```

Import raw callers from `transit_client` and framework APIs from `transit_station`.
Both synchronous context managers and asynchronous context managers own their
handles. Closing joins admitted work; cancellation of an await preserves any
unknown durable outcome.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station/README.md)
- [Caller semantics](../../docs/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.

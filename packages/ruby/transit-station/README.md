# transit-station for Ruby

Ruby handlers use block-scoped runners, versioned application codecs and scoped
KV/Table/query helpers. The independent [client](../transit-client/README.md) owns
bounded port work; shared Zig owns protocol and framework decisions.

Read the [usage and recovery guide](docs/USAGE.md) and installed
[counter/query examples](../../../examples/station-sdk/ruby/README.md). The public
API uses value objects, `Integer`, binary `String` and named exceptions. Turn
helpers belong to one callback thread/fiber and expire when that callback ends.
The [HTTP guide](docs/HTTP.md) covers experimental request values, bounded upload
turns, correlated outcomes and owned capture replay through the same worker.

```sh
nix develop .#bindings
just bindings::ruby-build
gem install --local --user-install .cache/bindings/ruby/*.gem
just bindings::ruby-sdk-test
```

The [native gem](../transit-native-station/README.md) supplies its version-matched
executable without loader-path setup. Linux x86_64, Ruby 3.4.9 and the pinned Nix
runtime closure are the qualified baseline. Clean consumers run the shared
failure/recovery/Table/query schedule; see the [proof guide](../../../tests/README.md).
Original IPC is independently decoded with PyArrow. No optional Ruby Arrow
adapter has been selected or qualified.

The [finite RPC guide](docs/GRPC.md) describes pinned descriptor binding, original
message batches, scoped durable calls and owned transcript replay.

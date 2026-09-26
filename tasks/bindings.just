set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list bindings

# Install shared libraries, the native port and the C/C++ example executables.
build:
    zig build client-abi station-abi transit-client-host transit-station-host bindings-examples

# Regenerate declarations and shared schemas from the reviewed Zig ABI exports.
generate:
    just contract::client-generate contract::station-generate
    python3 -B bindings/generate.py --write

check:
    just contract::client-check contract::station-check
    python3 -B bindings/generate.py

# Qualify the native boundary and C/C++/Python callers in the normal dev shell.
native:
    zig build test-bindings

# Qualify every implemented language; enter nix develop .#bindings first.
test:
    cargo fmt --manifest-path packages/rust/transit-station/Cargo.toml --check
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted packages/beam/transit-station/lib/transit_station.ex examples/station-bindings/elixir/main.exs
    zig build test-bindings -Dbindings-foreign=true

# Validate the Node adapter and its bounded asynchronous port transport.
node-check:
    cd packages/ts/transit-station && vp check
    vp exec --filter @rey/transit-station tsc --noEmit
    vp exec --filter @rey/transit-station node --test src/host.test.ts

# Build version-matched Python wheels, including separate native dependencies.
python-build: build
    python3 -B bindings/build_python.py .cache/bindings/wheels

# Type-check public APIs and run a clean wheel consumer outside the checkout.
python-test: python-build
    mypy --strict packages/python/transit-native-client/transit_native_client packages/python/transit-native-station/transit_native_station packages/python/transit-client/transit_client
    mypy --config-file packages/python/transit-station/pyproject.toml packages/python/transit-client/transit_client packages/python/transit-station/transit_station examples/station-sdk/python/transit_sdk_examples
    zig build transit-node rey-cli
    python3 -B tests/python_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/wheels
    python3 -B tests/python_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/wheels

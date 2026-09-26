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

# Build installed Node SDK tarballs with independent native artifacts.
node-build: build
    python3 -B bindings/build_node.py .cache/bindings/node

# Qualify public Node clients/runners through the shared real-authority schedules.
node-sdk-test: node-build
    cd packages/ts/transit-client && vp check
    vp exec --filter @transit/client tsc --noEmit
    cd packages/ts/transit-station-sdk && vp check
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/scope.test.ts src/runner.test.ts
    cd examples/station-sdk/typescript && vp check
    vp exec --filter @transit/sdk-examples tsc --noEmit
    zig build transit-node rey-cli
    python3 -B tests/node_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/node
    python3 -B tests/node_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/node

# Build independent Rust source crates with their embedded native artifact.
rust-build: build
    cargo fetch --locked --manifest-path packages/rust/transit-client/Cargo.toml
    cargo fetch --locked --manifest-path packages/rust/transit-station-sdk/Cargo.toml
    cargo fetch --locked --manifest-path examples/station-sdk/rust/Cargo.toml
    python3 -B bindings/build_rust.py .cache/bindings/rust

# Build clean Rust consumers; run from the bindings shell.
rust-sdk-test: rust-build
    cargo fmt --manifest-path packages/rust/transit-client/Cargo.toml --check
    cargo fmt --manifest-path packages/rust/transit-native-client/Cargo.toml --check
    cargo fmt --manifest-path packages/rust/transit-native-station/Cargo.toml --check
    cargo fmt --manifest-path packages/rust/transit-station-sdk/Cargo.toml --check
    cargo fmt --manifest-path examples/station-sdk/rust/Cargo.toml --check
    zig build transit-node rey-cli
    python3 -B tests/rust_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/rust
    python3 -B tests/rust_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/rust

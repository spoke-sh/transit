set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list bindings

# Install shared libraries, the native port and the C/C++ example executables.
build:
    zig build client-abi station-abi transit-station-host bindings-examples

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

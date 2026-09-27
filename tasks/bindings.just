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
    zig build transit-node rey-cli transit-station-http-worker
    python3 -B tests/python_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/wheels
    zig build transit-station-grpc-worker
    python3 -B tests/python_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/wheels zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python

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
    zig build transit-node rey-cli transit-station-http-worker
    python3 -B tests/node_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/node
    zig build transit-station-grpc-worker
    python3 -B tests/node_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/node zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language node

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
    zig build transit-node rey-cli transit-station-http-worker
    python3 -B tests/rust_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/rust
    zig build transit-station-grpc-worker
    python3 -B tests/rust_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/rust zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language rust

# Build independent Ruby gems; native executables remain separate dependencies.
ruby-build: build
    python3 -B bindings/build_ruby.py .cache/bindings/ruby

# Syntax checks and installed public Ruby client/authority schedules.
ruby-sdk-test: ruby-build
    ruby -c packages/ruby/transit-client/lib/transit/client.rb
    ruby -c packages/ruby/transit-client/lib/transit/client/values.rb
    ruby -c packages/ruby/transit-client/lib/transit/client/worker.rb
    ruby -c packages/ruby/transit-client/lib/transit/client/port.rb
    ruby -c packages/ruby/transit-client/lib/transit/client/operations.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/values.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/bridge.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/http.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/turn.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/table.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/query.rb
    ruby -c packages/ruby/transit-station/lib/transit/station/runner.rb
    ruby -c examples/station-sdk/ruby/lib/transit/sdk_examples.rb
    ruby -c examples/station-sdk/ruby/lib/transit/sdk_examples/codecs.rb
    ruby -c examples/station-sdk/ruby/bin/transit-ruby-counter
    zig build transit-node rey-cli
    python3 -B tests/ruby_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/ruby
    zig build transit-station-http-worker
    zig build transit-station-grpc-worker
    python3 -B tests/ruby_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/ruby zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language ruby

# Build independent C/C++ prefixes with standard pkg-config metadata.
c-build: build
    cd packages/c/transit-client && zig build
    cd packages/cpp/transit-client && zig build check
    cd packages/c/transit-station && zig build
    cd packages/cpp/transit-station-sdk && zig build check
    cd examples/station-sdk/c && zig build
    cd examples/station-sdk/cpp && zig build
    python3 -B bindings/build_c.py .cache/bindings/c

# Compile installed public C and C++ consumers and run the shared raw schedule.
c-sdk-test: c-build
    zig fmt --check packages/c packages/cpp/transit-client packages/cpp/transit-station-sdk examples/station-sdk/c examples/station-sdk/cpp
    zig build transit-node rey-cli transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/c_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/c
    python3 -B tests/c_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/c zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language c

# Build independent Java JARs and POM manifests with the pinned JDK/Gson.
java-build: build
    python3 -B bindings/build_java.py .cache/bindings/java

# Compile installed public Java consumers outside the checkout.
java-sdk-test: java-build
    zig build transit-node rey-cli transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/java_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/java
    python3 -B tests/java_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/java zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language java

# Build isolated .NET NuGet packages with exact native dependencies.
dotnet-build: build
    python3 -B bindings/build_dotnet.py .cache/bindings/dotnet

# Restore public raw/Station/example NuGet artifacts into clean consumers.
dotnet-sdk-test: dotnet-build
    zig build transit-node rey-cli transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/dotnet_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/dotnet
    python3 -B tests/dotnet_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/dotnet zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language dotnet

# Build separate standard OTP client/Station applications, examples and native artifacts.
beam-build: build
    python3 -B bindings/build_beam.py .cache/bindings/beam

# Compile clean Erlang consumers and execute both public BEAM language schedules.
beam-sdk-test: beam-build
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted packages/beam/transit-client-elixir/lib/client.ex packages/beam/transit-client-elixir/mix.exs packages/beam/transit-station-elixir/lib/*.ex packages/beam/transit-station-elixir/mix.exs examples/station-sdk/elixir/lib/*.ex examples/station-sdk/elixir/mix.exs tests/elixir_client_sdk.exs tests/elixir_station_adapter.ex tests/elixir_http_adapter.ex tests/elixir_grpc_adapter.ex
    zig build transit-node rey-cli transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/beam_client_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/beam
    python3 -B tests/beam_station_sdk.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings/beam zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language beam

# Every public language serves and requests a foreign peer through installed APIs.
sdk-interop: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    zig build transit-node rey-cli
    python3 -B tests/sdk_public_interop.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings .cache/verification/m11-public-interop.json

# Crash after public RPC output commit and preserve a retired caller destination.
grpc-faults: python-build
    zig build transit-node rey-cli transit-station-grpc-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python --fault published
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python --fault retirement

# Qualify Document scoped jobs and read-only native/port consumers.
document-native: build
    zig build transit-node rey-cli
    PYTHONPATH=packages/python/transit-station:packages/python/transit-client python3 -B tests/station_document_abi.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_station.so zig-out/lib/libtransit_client.so zig-out/bin/transit-station-host

# Installed Python Document types, scoped changes, retained reads and host loss.
document-python: python-build
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language python

# Installed Node Document values, scoped ownership, retained reads and host loss.
document-node: node-build
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/document.test.ts
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language node

# Installed Ruby Document values, scoped changes and joined reader destruction.
document-ruby: ruby-build
    ruby -c packages/ruby/transit-station/lib/transit/station/document.rb
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language ruby

# Installed Rust Document values and compiler-enforced owner/reader lifetimes.
document-rust: rust-build
    cargo fmt --manifest-path packages/rust/transit-station-sdk/Cargo.toml --check
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language rust

# Installed C11/C++17 Document handlers, owned values and reader lifetimes.
document-c: c-build
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language c

# Installed Java Document values, scoped jobs and asynchronous joined reads.
document-java: java-build
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language java

# Installed .NET Document values, scoped jobs, cancellation and joined disposal.
document-dotnet: dotnet-build
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language dotnet

# Installed Erlang and Elixir Document APIs share the native merge implementation.
document-beam: beam-build
    mix format --check-formatted packages/beam/transit-station-elixir/lib/document.ex tests/elixir_document_adapter.ex
    zig build transit-node rey-cli
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/rey-cli zig-out/lib/libtransit_client.so .cache/bindings --language beam

# Installed Python sync/async unified query APIs, shared fixtures and exact retry.
unified-python source="kv": python-build
    mypy --config-file packages/python/transit-station/pyproject.toml packages/python/transit-client/transit_client packages/python/transit-station/transit_station examples/station-sdk/python/transit_sdk_examples
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=python -Dunified-source={{source}}

# Installed TypeScript unified API, runtime schemas, Arrow and signed recovery.
unified-node source="table": node-build
    cd packages/ts/transit-station-sdk && vp check
    vp exec --filter @transit/station tsc --noEmit
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=node -Dunified-source={{source}}

# Installed Ruby unified API with immutable values and joined query ownership.
unified-ruby source="kv": ruby-build
    ruby -c packages/ruby/transit-station/lib/transit/station/unified.rb
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=ruby -Dunified-source={{source}}

# Installed Rust unified API, exclusive borrows, Arrow and signed recovery.
unified-rust source="table": rust-build
    cargo fmt --manifest-path packages/rust/transit-station-sdk/Cargo.toml --check
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=rust -Dunified-source={{source}}

# Installed C11 and C++17 unified-query callers; each runs the signed schedule.
unified-c source="kv": c-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=c -Dunified-source={{source}}
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=cpp -Dunified-source={{source}}

# Java 21 typed unified-query futures and joined native port.
unified-java source="table": java-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=java -Dunified-source={{source}}

# Owned .NET unified-query tasks through the native client.
unified-dotnet source="kv": dotnet-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=dotnet -Dunified-source={{source}}

# Installed Erlang and Elixir unified state queries with owned port workers.
unified-beam source="table": beam-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=erlang -Dunified-source={{source}}
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=elixir -Dunified-source={{source}}

# All ten installed SDKs against each of the three v2 source services.
unified-all: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir

set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list bindings

# Install the shared libraries and native ports.
build:
    zig build client-abi station-abi transit-client-host transit-station-host

# Regenerate declarations and shared schemas from the reviewed Zig ABI exports.
generate:
    just contract::client-generate contract::station-generate
    python3 -B bindings/generate.py --write

check:
    just contract::client-check contract::station-check
    python3 -B bindings/generate.py

# Qualify native and port ownership, codecs and durable capture.
native:
    zig build test-bindings

# Qualify every implemented language; enter nix develop .#bindings first.
test: native python-test node-sdk-test rust-sdk-test go-sdk-test ruby-sdk-test c-sdk-test java-sdk-test dotnet-sdk-test beam-sdk-test sdk-interop

# Build the Go module and its matching explicit native installation.
go-build: build
    python3 -B bindings/build_go.py .cache/bindings/go

# Run Go ownership, recovery and race checks against the actual native library.
go-check: build
    go version
    test -z "$(gofmt -l sdks/go tests/go_client_sdk examples/go-client)"
    cd sdks/go && GOTOOLCHAIN=local GOWORK=off go vet ./...
    cd sdks/go && TRANSIT_GO_TEST_NATIVE_DIRECTORY="$PWD/../../zig-out/lib" GOTOOLCHAIN=local GOWORK=off GOEXPERIMENT=cgocheck2 go test -race ./...

# Compile an installed external Go consumer and run the shared disk-backed proof.
go-sdk-test: go-build go-check
    zig build transit-node transit-admin
    python3 -B tests/go_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/go

# Requires the installed language artifacts from the corresponding *-build tasks.
# C exercises C/C++; BEAM exercises Erlang/Elixir. Select with --family.
query-failures *args: build
    zig build transit-node transit-admin
    python3 -B tests/sdk_query_failures.py {{args}}

# Validate the current Node adapters and their asynchronous port transport.
node-check:
    cd sdks/ts/transit-client && vp check
    vp exec --filter @transit/client node --test src/errors.test.ts src/port.test.ts
    # Station imports the package's emitted declarations and runtime exports.
    vp exec --filter @transit/client tsc
    cd sdks/ts/transit-station-sdk && vp check
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/scope.test.ts src/runner.test.ts src/catalog.test.ts src/unified.test.ts src/relational.test.ts src/table.test.ts

# Build version-matched Python wheels, including separate native dependencies.
python-build: build
    python3 -B bindings/build_python.py .cache/bindings/wheels

# Type-check public APIs and run a clean wheel consumer outside the checkout.
python-test: python-build
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/python_relational_values.py
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/python_handler_tables.py
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station:examples/station-sdk/python python3 -B tests/sdk_table_work.py
    PYTHONPATH=sdks/python/transit-client python3 -B tests/python_diagnostic_errors.py zig-out/lib/libtransit_client.so
    mypy --strict sdks/python/transit-native-client/transit_native_client sdks/python/transit-native-station/transit_native_station sdks/python/transit-client/transit_client
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station examples/station-sdk/python/transit_sdk_examples
    zig build transit-node transit-admin transit-station-http-worker
    python3 -B tests/python_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/wheels
    zig build transit-station-grpc-worker
    python3 -B tests/python_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/wheels zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python
    just test::typed-tables --cold --sdk python
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=python

# Build installed Node SDK tarballs with independent native artifacts.
node-build: build
    python3 -B bindings/build_node.py .cache/bindings/node

# Qualify installed relational SQL callers through the shared Zig owner.
relational-node: node-build node-check
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=node

relational-python: python-build
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/python_relational_values.py
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=python

# Qualify public Node clients/runners through the shared real-authority schedules.
node-sdk-test: node-build
    cd sdks/ts/transit-client && vp check
    vp exec --filter @transit/client tsc --noEmit
    cd sdks/ts/transit-station-sdk && vp check
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/scope.test.ts src/runner.test.ts src/catalog.test.ts src/unified.test.ts src/relational.test.ts src/table.test.ts
    cd examples/station-sdk/typescript && vp check
    vp exec --filter @transit/sdk-examples tsc --noEmit
    zig build transit-node transit-admin transit-station-http-worker
    python3 -B tests/node_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/node
    zig build transit-station-grpc-worker
    python3 -B tests/node_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/node zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language node
    just test::typed-tables --cold --sdk node
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=node

# Qualify installed logical values and Arrow ownership outside the checkout.
logical-test: python-build node-build
    python3 -B tests/sdk_logical.py python node

# Build independent Rust source crates with their embedded native artifact.
rust-build: build
    cargo fetch --locked --manifest-path sdks/rust/transit-client/Cargo.toml
    cargo fetch --locked --manifest-path sdks/rust/transit-station-sdk/Cargo.toml
    cargo fetch --locked --manifest-path examples/station-sdk/rust/Cargo.toml
    python3 -B bindings/build_rust.py .cache/bindings/rust

# Stress installed Rust runner destruction on fresh malformed inputs.
rust-lifetime cases="128": rust-build
    zig build transit-node transit-admin
    python3 -B tests/rust_station_lifetime.py --cases {{quote(cases)}}

# Build clean Rust consumers; run from the bindings shell.
rust-sdk-test: rust-build
    cargo fmt --manifest-path sdks/rust/transit-client/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-native-client/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-native-station/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check
    cargo fmt --manifest-path examples/station-sdk/rust/Cargo.toml --check
    zig build transit-node transit-admin transit-station-http-worker
    python3 -B tests/rust_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/rust
    zig build transit-station-grpc-worker
    python3 -B tests/rust_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/rust zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language rust
    just test::typed-tables --cold --sdk rust

# Build independent Ruby gems; native executables remain separate dependencies.
ruby-build: build
    python3 -B bindings/build_ruby.py .cache/bindings/ruby

# Syntax checks and installed public Ruby client/authority schedules.
ruby-sdk-test: ruby-build
    ruby -Isdks/ruby/transit-client/lib -Isdks/ruby/transit-station/lib tests/ruby_handler_tables.rb
    ruby -c sdks/ruby/transit-client/lib/transit/client.rb
    ruby -c sdks/ruby/transit-client/lib/transit/client/values.rb
    ruby -c sdks/ruby/transit-client/lib/transit/client/worker.rb
    ruby -c sdks/ruby/transit-client/lib/transit/client/port.rb
    ruby -c sdks/ruby/transit-client/lib/transit/client/operations.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/values.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/bridge.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/http.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/turn.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/table.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/query.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog_values.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/logical.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/runner.rb
    ruby -c examples/station-sdk/ruby/lib/transit/sdk_examples.rb
    ruby -c examples/station-sdk/ruby/lib/transit/sdk_examples/codecs.rb
    ruby -c examples/station-sdk/ruby/bin/transit-ruby-counter
    zig build transit-node transit-admin
    python3 -B tests/ruby_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/ruby
    zig build transit-station-http-worker
    zig build transit-station-grpc-worker
    python3 -B tests/ruby_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/ruby zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language ruby
    just test::typed-tables --cold --sdk ruby

# Build independent C/C++ prefixes with standard pkg-config metadata.
c-build: build
    cd sdks/c/transit-client && zig build
    cd sdks/cpp/transit-client && zig build check
    cd sdks/c/transit-station && zig build
    cd sdks/cpp/transit-station-sdk && zig build check
    cd examples/station-sdk/c && zig build
    cd examples/station-sdk/cpp && zig build
    python3 -B bindings/build_c.py .cache/bindings/c

# Compile installed public C and C++ consumers and run the shared raw schedule.
c-sdk-test: c-build
    zig fmt --check sdks/c sdks/cpp/transit-client sdks/cpp/transit-station-sdk examples/station-sdk/c examples/station-sdk/cpp
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/c_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/c
    python3 -B tests/c_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/c zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language c
    just test::typed-tables --cold --sdk c --sdk cpp
    python3 -B tests/c_logical_values.py .cache/bindings/c

# Qualify owned recursive models through installed C11 and C++17 consumers.
logical-c: c-build
    python3 -B tests/c_logical_values.py .cache/bindings/c

# Build independent Java JARs and POM manifests with the pinned JDK/Gson.
java-build: build
    python3 -B bindings/build_java.py .cache/bindings/java

# Compile installed public Java consumers outside the checkout.
java-sdk-test: java-build
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/java_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/java
    python3 -B tests/java_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/java zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language java
    just test::typed-tables --cold --sdk java

# Build isolated .NET NuGet packages with exact native dependencies.
dotnet-build: build
    python3 -B bindings/build_dotnet.py .cache/bindings/dotnet

# Qualify owned recursive .NET logical models in an isolated package consumer.
logical-dotnet: dotnet-build
    python3 -B tests/dotnet_logical_values.py .cache/bindings/dotnet

# Restore public raw/Station/example NuGet artifacts into clean consumers.
dotnet-sdk-test: dotnet-build
    python3 -B tests/dotnet_logical_values.py .cache/bindings/dotnet
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/dotnet_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/dotnet
    python3 -B tests/dotnet_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/dotnet zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language dotnet
    just test::typed-tables --cold --sdk dotnet

# Build separate standard OTP client/Station applications, examples and native artifacts.
beam-build: build
    python3 -B bindings/build_beam.py .cache/bindings/beam

# Qualify recursive logical models from installed Erlang and Elixir artifacts.
logical-beam: beam-build
    python3 -B tests/beam_logical_values.py .cache/bindings/beam

# Compile clean Erlang consumers and execute both public BEAM language schedules.
beam-sdk-test: beam-build
    python3 -B tests/beam_logical_values.py .cache/bindings/beam
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted sdks/beam/transit-client-elixir/lib/client.ex sdks/beam/transit-client-elixir/mix.exs sdks/beam/transit-station-elixir/lib/*.ex sdks/beam/transit-station-elixir/mix.exs examples/station-sdk/elixir/lib/*.ex examples/station-sdk/elixir/mix.exs tests/elixir_client_sdk.exs tests/elixir_station_adapter.ex tests/elixir_http_adapter.ex tests/elixir_grpc_adapter.ex tests/elixir_logical_values.exs
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/beam_client_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/beam
    python3 -B tests/beam_station_sdk.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings/beam zig-out/bin/transit-station-http-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language beam
    just test::typed-tables --cold --sdk erlang --sdk elixir

# Every public language serves and requests a foreign peer through installed APIs.
sdk-interop: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    zig build transit-node transit-admin
    python3 -B tests/sdk_public_interop.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings .cache/verification/m11-public-interop.json

# Every installed SDK uses only native send and its selected Table data role.
authorization: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    just test::authorization-tables --sdk python --sdk node --sdk ruby --sdk rust --sdk c --sdk cpp --sdk java --sdk dotnet --sdk erlang --sdk elixir

# Qualify installed HTTP/gRPC outcome diagnostics and recovery in every SDK.
connector-outcomes: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-http-worker .cache/bindings --protocol http
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings

# Retain original accepted-call preparation failures across lost receipts and restart.
connector-preparation: python-build
    zig build transit-node transit-admin transit-station-http-worker transit-station-grpc-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-http-worker .cache/bindings --protocol http --language python --preparation-failure
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python --preparation-failure

# Crash after public RPC output commit and preserve a retired caller destination.
grpc-faults: python-build
    zig build transit-node transit-admin transit-station-grpc-worker
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python --fault published
    python3 -B tests/sdk_grpc_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so zig-out/bin/transit-station-grpc-worker .cache/bindings --language python --fault retirement

# Qualify Document scoped jobs and read-only native/port consumers.
document-native: build
    zig build transit-node transit-admin
    PYTHONPATH=sdks/python/transit-station:sdks/python/transit-client python3 -B tests/station_document_abi.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_station.so zig-out/lib/libtransit_client.so zig-out/bin/transit-station-host

# Installed Python Document types, scoped changes, retained reads and host loss.
document-python: python-build
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language python

# Installed Node Document values, scoped ownership, retained reads and host loss.
document-node: node-build
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/document.test.ts
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language node

# Installed Ruby Document values, scoped changes and joined reader destruction.
document-ruby: ruby-build
    ruby -c sdks/ruby/transit-station/lib/transit/station/document.rb
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language ruby

# Installed Rust Document values and compiler-enforced owner/reader lifetimes.
document-rust: rust-build
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language rust

# Installed C11/C++17 Document handlers, owned values and reader lifetimes.
document-c: c-build
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language c

# Installed Java Document values, scoped jobs and asynchronous joined reads.
document-java: java-build
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language java

# Installed .NET Document values, scoped jobs, cancellation and joined disposal.
document-dotnet: dotnet-build
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language dotnet

# Installed Erlang and Elixir Document APIs share the native merge implementation.
document-beam: beam-build
    mix format --check-formatted sdks/beam/transit-station-elixir/lib/document.ex tests/elixir_document_adapter.ex
    zig build transit-node transit-admin
    python3 -B tests/sdk_document_runner.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/lib/libtransit_client.so .cache/bindings --language beam

# Python sync/async direct capture, independent native progress and rotated-credential results.
direct-captured-python:
    zig build client-abi station-abi -Doptimize=ReleaseSafe
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --python-native zig-out/lib

# Ruby public port caller over direct Table lookup, capture and recovered results.
direct-captured-ruby:
    zig build transit-station-host -Doptimize=ReleaseSafe
    RUBYLIB=sdks/ruby/transit-client/lib:sdks/ruby/transit-station/lib zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --ruby-host zig-out/bin/transit-station-host

# Installed JAR/NuGet callers share the direct capture and cleanup fault schedule.
direct-captured-managed: java-build dotnet-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --java-packages .cache/bindings/java --dotnet-packages .cache/bindings/dotnet

# Installed C11/C++17 callers own direct definitions independently of the client.
direct-captured-c: c-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --c-packages .cache/bindings/c

# Installed Erlang/Elixir callers retain independent direct cuts through recovery.
direct-captured-beam: beam-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --beam-packages .cache/bindings/beam

# Every installed language resolves, seals and reads the same retained Table query.
direct-captured-all: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --python-packages .cache/bindings/wheels --ruby-packages .cache/bindings/ruby --node-packages .cache/bindings/node --rust-packages .cache/bindings/rust --c-packages .cache/bindings/c --java-packages .cache/bindings/java --dotnet-packages .cache/bindings/dotnet --beam-packages .cache/bindings/beam

# Installed Python sync/async unified query APIs, shared fixtures and exact retry.
unified-python source="kv": python-build
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station examples/station-sdk/python/transit_sdk_examples
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=python -Dunified-source={{source}}

# Installed TypeScript unified API, runtime schemas, Arrow and signed recovery.
unified-node source="table": node-build
    cd sdks/ts/transit-station-sdk && vp check
    vp exec --filter @transit/station tsc --noEmit
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=node -Dunified-source={{source}}

# Installed Ruby unified API with immutable values and joined query ownership.
unified-ruby source="kv": ruby-build
    ruby -c sdks/ruby/transit-station/lib/transit/station/unified.rb
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=ruby -Dunified-source={{source}}

# Installed Rust unified API, exclusive borrows, Arrow and signed recovery.
unified-rust source="table": rust-build
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check
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

# All ten installed SDKs against each of the three current source services.
unified-all: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir

# Filtering Boolean programs through all ten SDKs and the SQL shell, across all sources.
unified-compound: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir -Dunified-compound=true -Dunified-shell=true

# Pure installed query codecs: exact bundle bytes and independently produced Arrow.
unified-codecs: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    python3 -B tests/sdk_unified.py

# Build matching ReleaseSafe wheels and qualify direct lifecycle and retained SQL.
direct-catalog-python:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_python.py .cache/bindings/wheels transit-native-client transit-native-station transit-client transit-station
    zig build test-direct-catalog-python -Doptimize=ReleaseSafe

# Build matching ReleaseSafe packages and qualify the TypeScript direct caller.
direct-catalog-node:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_node.py .cache/bindings/node transit-native-client transit-client transit-native-station transit-station-sdk
    zig build test-direct-catalog-node -Doptimize=ReleaseSafe

# Installed Python sync/async direct catalog and exact saved-operation recovery.
catalog-python: direct-catalog-python
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station

# Installed TypeScript catalog caller with generated runtime checks and saved recovery.
catalog-node: node-check direct-catalog-node

# Build matching ReleaseSafe crates and qualify installed Rust direct recovery.
direct-catalog-rust:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_rust.py .cache/bindings/rust transit-native-client transit-client transit-native-station transit-station-sdk
    zig build test-direct-catalog-rust -Doptimize=ReleaseSafe

# Installed Rust catalog caller with exclusive borrows and saved recovery.
catalog-rust: direct-catalog-rust
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check

# Build matching ReleaseSafe gems and qualify the Ruby direct caller.
direct-catalog-ruby:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_ruby.py .cache/bindings/ruby transit-native-client transit-client transit-native-station transit-station
    zig build test-direct-catalog-ruby -Doptimize=ReleaseSafe

# Installed Ruby catalog caller with immutable values and joined worker ownership.
catalog-ruby: direct-catalog-ruby
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog_values.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/logical.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog.rb

# Build matching ReleaseSafe prefixes and qualify both direct C/C++ callers.
direct-catalog-c:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    cd sdks/c/transit-client && zig build -Doptimize=ReleaseSafe
    cd sdks/c/transit-station && zig build -Doptimize=ReleaseSafe
    cd sdks/cpp/transit-station-sdk && zig build check -Doptimize=ReleaseSafe
    cd examples/station-sdk/c && zig build -Doptimize=ReleaseSafe
    cd examples/station-sdk/cpp && zig build -Doptimize=ReleaseSafe
    python3 -B bindings/build_c.py .cache/bindings/c
    zig build test-direct-catalog-c -Doptimize=ReleaseSafe

# Installed C11/C++17 catalog callers with owned values and saved recovery.
catalog-c: direct-catalog-c

# Build matching ReleaseSafe JARs and qualify Java direct lifecycle recovery.
direct-catalog-java:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_java.py .cache/bindings/java transit-native-client transit-client transit-native-station transit-station-sdk
    zig build test-direct-catalog-java -Doptimize=ReleaseSafe

# Installed Java catalog futures, generated port validation and owned recovery.
catalog-java: direct-catalog-java

# Build matching ReleaseSafe NuGet packages and qualify direct lifecycle recovery.
direct-catalog-dotnet:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_dotnet.py .cache/bindings/dotnet transit-native-client transit-client transit-native-station transit-station-sdk
    zig build test-direct-catalog-dotnet -Doptimize=ReleaseSafe

# Installed .NET catalog tasks, generated ABI validation and joined ownership.
catalog-dotnet: direct-catalog-dotnet

# Build matching ReleaseSafe OTP artifacts and qualify both direct callers.
direct-catalog-beam:
    zig build client-abi station-abi transit-client-host transit-station-host -Doptimize=ReleaseSafe
    python3 -B bindings/build_beam.py .cache/bindings/beam transit-native-client transit-client transit-client-elixir transit-native-station transit-station-sdk transit-station-elixir
    zig build test-direct-catalog-beam -Doptimize=ReleaseSafe

# Installed Erlang/Elixir catalog values and joined native-port ownership.
catalog-beam: direct-catalog-beam
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted sdks/beam/transit-station-elixir/lib/catalog.ex tests/elixir_catalog_adapter.ex

# Compile and run the public Zig SDK and a separately built application.
zig-test:
    cd sdks/zig && zig build test
    python3 -B tests/sdk_zig.py

# Build the runtime in an isolated source tree that contains no SDKs.
runtime-boundary:
    python3 -B tests/sdk_runtime.py

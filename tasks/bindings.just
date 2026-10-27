set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list bindings

# Resolve the immutable Debug client fixture set and record its identity.
build:
    python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug

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
# Station SDK schedules retain Debug bindings/hosts and use a ReleaseSafe node
# for the bounded disk-backed query workload. Deadlines and assertions are fixed.
test: native python-test node-sdk-test rust-sdk-test go-sdk-test ruby-sdk-test c-sdk-test java-sdk-test dotnet-sdk-test beam-sdk-test sdk-interop

# Build the Go module and its matching explicit native installation.
go-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging go -- python3 -B bindings/build_go.py .cache/bindings/Debug/go --native-prefix "$native_prefix"

# Run Go ownership, recovery and race checks against the actual native library.
go-check:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    go version
    test -z "$(gofmt -l sdks/go tests/sdk/consumers/go/go_client_sdk examples/go-client)"
    (cd sdks/go && GOTOOLCHAIN=local GOWORK=off go vet ./...)
    (cd sdks/go && TRANSIT_GO_TEST_NATIVE_DIRECTORY="$native_prefix/lib" GOTOOLCHAIN=local GOWORK=off GOEXPERIMENT=cgocheck2 go test -race ./...)

# Compile an installed external Go consumer and run the shared disk-backed proof.
go-sdk-test: go-build go-check
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/consumers/go/go_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/go

# Requires the installed language artifacts from the corresponding *-build tasks.
# C exercises C/C++; BEAM exercises Erlang/Elixir. Select with --family.
[positional-arguments]
query-failures *args:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_query_failures.py --native-prefix "$native_prefix" --node "$authority_prefix/bin/transit-node" "$@"

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
python-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging python -- python3 -B bindings/build_python.py .cache/bindings/Debug/wheels --native-prefix "$native_prefix"

# Type-check public APIs and run a clean wheel consumer outside the checkout.
python-test: python-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_relational_values.py
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_handler_tables.py
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station:examples/station-sdk/python python3 -B tests/runner/launch.py tests/sdk/sdk_table_work.py
    PYTHONPATH=sdks/python/transit-client python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_diagnostic_errors.py "${native_prefix}/lib/libtransit_client.so"
    mypy --strict sdks/python/transit-native-client/transit_native_client sdks/python/transit-native-station/transit_native_station sdks/python/transit-client/transit_client
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station examples/station-sdk/python/transit_sdk_examples
    python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/wheels
    python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/wheels "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language python
    just bindings::direct-catalog-python
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=python

# Build installed Node SDK tarballs with independent native artifacts.
node-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging node -- python3 -B bindings/build_node.py .cache/bindings/Debug/node --native-prefix "$native_prefix"

# Qualify installed relational SQL callers through the shared Zig owner.
relational-node: node-build node-check
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=node

relational-python: python-build
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station python3 -B tests/runner/launch.py tests/sdk/consumers/python/python_relational_values.py
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=python

# Qualify public Node clients/runners through the shared real-authority schedules.
node-sdk-test: node-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    (cd sdks/ts/transit-client && vp check)
    vp exec --filter @transit/client tsc --noEmit
    (cd sdks/ts/transit-station-sdk && vp check)
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/scope.test.ts src/runner.test.ts src/catalog.test.ts src/unified.test.ts src/relational.test.ts src/table.test.ts
    (cd examples/station-sdk/typescript && vp check)
    vp exec --filter @transit/sdk-examples tsc --noEmit
    python3 -B tests/runner/launch.py tests/sdk/consumers/node/node_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/node
    python3 -B tests/runner/launch.py tests/sdk/consumers/node/node_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/node "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language node
    just bindings::direct-catalog-node
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-sdk=node

# Qualify installed logical values and Arrow ownership outside the checkout.
logical-test: python-build node-build
    python3 -B tests/runner/launch.py tests/sdk/sdk_logical.py python node

# Build independent Rust source crates with their embedded native artifact.
rust-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    cargo fetch --locked --manifest-path sdks/rust/transit-client/Cargo.toml
    cargo fetch --locked --manifest-path sdks/rust/transit-station-sdk/Cargo.toml
    cargo fetch --locked --manifest-path examples/station-sdk/rust/Cargo.toml
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging rust -- python3 -B bindings/build_rust.py .cache/bindings/Debug/rust --native-prefix "$native_prefix"

# Stress installed Rust runner destruction on fresh malformed inputs.
rust-lifetime cases="128": rust-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/consumers/rust/rust_station_lifetime.py --cases {{quote(cases)}} --node "$authority_prefix/bin/transit-node" --cli "$native_prefix/bin/transit-admin" --library "$native_prefix/lib/libtransit_client.so" --artifacts .cache/bindings/Debug/rust

# Build clean Rust consumers; run from the bindings shell.
rust-sdk-test: rust-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    cargo fmt --manifest-path sdks/rust/transit-client/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-native-client/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-native-station/Cargo.toml --check
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check
    cargo fmt --manifest-path examples/station-sdk/rust/Cargo.toml --check
    python3 -B tests/runner/launch.py tests/sdk/consumers/rust/rust_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/rust
    python3 -B tests/runner/launch.py tests/sdk/consumers/rust/rust_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/rust "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language rust
    just bindings::direct-catalog-rust

# Build independent Ruby gems; native executables remain separate dependencies.
ruby-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging ruby -- python3 -B bindings/build_ruby.py .cache/bindings/Debug/ruby --native-prefix "$native_prefix"

# Syntax checks and installed public Ruby client/authority schedules.
ruby-sdk-test: ruby-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    ruby -Isdks/ruby/transit-client/lib -Isdks/ruby/transit-station/lib tests/sdk/consumers/ruby/ruby_handler_tables.rb
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
    python3 -B tests/runner/launch.py tests/sdk/consumers/ruby/ruby_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/ruby
    python3 -B tests/runner/launch.py tests/sdk/consumers/ruby/ruby_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/ruby "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language ruby
    just bindings::direct-catalog-ruby

# Build independent C/C++ prefixes with standard pkg-config metadata.
c-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    (cd sdks/c/transit-client && zig build)
    (cd sdks/cpp/transit-client && zig build check)
    (cd sdks/c/transit-station && zig build)
    (cd sdks/cpp/transit-station-sdk && zig build check)
    (cd examples/station-sdk/c && zig build)
    (cd examples/station-sdk/cpp && zig build)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging c -- python3 -B bindings/build_c.py .cache/bindings/Debug/c --native-prefix "$native_prefix"

# Compile installed public C and C++ consumers and run the shared raw schedule.
c-sdk-test: c-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    zig fmt --check sdks/c sdks/cpp/transit-client sdks/cpp/transit-station-sdk examples/station-sdk/c examples/station-sdk/cpp
    python3 -B tests/runner/launch.py tests/sdk/consumers/c/c_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/c
    python3 -B tests/runner/launch.py tests/sdk/consumers/c/c_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/c "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language c
    just bindings::direct-catalog-c
    python3 -B tests/runner/launch.py tests/sdk/consumers/c/c_logical_values.py .cache/bindings/Debug/c

# Qualify owned recursive models through installed C11 and C++17 consumers.
logical-c: c-build
    python3 -B tests/runner/launch.py tests/sdk/consumers/c/c_logical_values.py .cache/bindings/Debug/c

# Build independent Java JARs and POM manifests with the pinned JDK/Gson.
java-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging java -- python3 -B bindings/build_java.py .cache/bindings/Debug/java --native-prefix "$native_prefix"

# Compile installed public Java consumers outside the checkout.
java-sdk-test: java-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/sdk/consumers/java/java_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/java
    python3 -B tests/runner/launch.py tests/sdk/consumers/java/java_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/java "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language java
    just bindings::direct-catalog-java

# Build isolated .NET NuGet packages with exact native dependencies.
dotnet-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging dotnet -- python3 -B bindings/build_dotnet.py .cache/bindings/Debug/dotnet --native-prefix "$native_prefix"

# Qualify owned recursive .NET logical models in an isolated package consumer.
logical-dotnet: dotnet-build
    python3 -B tests/runner/launch.py tests/sdk/consumers/dotnet/dotnet_logical_values.py .cache/bindings/Debug/dotnet

# Restore public raw/Station/example NuGet artifacts into clean consumers.
dotnet-sdk-test: dotnet-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/sdk/consumers/dotnet/dotnet_logical_values.py .cache/bindings/Debug/dotnet
    python3 -B tests/runner/launch.py tests/sdk/consumers/dotnet/dotnet_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/dotnet
    python3 -B tests/runner/launch.py tests/sdk/consumers/dotnet/dotnet_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/dotnet "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language dotnet
    just bindings::direct-catalog-dotnet

# Build separate standard OTP client/Station applications, examples and native artifacts.
beam-build:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging beam -- python3 -B bindings/build_beam.py .cache/bindings/Debug/beam --native-prefix "$native_prefix"

# Qualify recursive logical models from installed Erlang and Elixir artifacts.
logical-beam: beam-build
    python3 -B tests/runner/launch.py tests/sdk/consumers/beam/beam_logical_values.py .cache/bindings/Debug/beam

# Compile clean Erlang consumers and execute both public BEAM language schedules.
beam-sdk-test: beam-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/sdk/consumers/beam/beam_logical_values.py .cache/bindings/Debug/beam
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted sdks/beam/transit-client-elixir/lib/client.ex sdks/beam/transit-client-elixir/mix.exs sdks/beam/transit-station-elixir/lib/*.ex sdks/beam/transit-station-elixir/mix.exs examples/station-sdk/elixir/lib/*.ex examples/station-sdk/elixir/mix.exs tests/sdk/consumers/elixir/elixir_client_sdk.exs tests/sdk/consumers/elixir/elixir_station_adapter.ex tests/sdk/consumers/elixir/elixir_http_adapter.ex tests/sdk/consumers/elixir/elixir_grpc_adapter.ex tests/sdk/consumers/elixir/elixir_logical_values.exs
    python3 -B tests/runner/launch.py tests/sdk/consumers/beam/beam_client_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/beam
    python3 -B tests/runner/launch.py tests/sdk/consumers/beam/beam_station_sdk.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug/beam "${native_prefix}/bin/transit-station-http-worker"
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language beam
    just bindings::direct-catalog-beam

# Every public language serves and requests a foreign peer through installed APIs.
sdk-interop: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_public_interop.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug .cache/verification/m11-public-interop.json

# Every installed catalog caller explicitly selects a non-inherited data role.
authorization: direct-catalog-python direct-catalog-node direct-catalog-rust direct-catalog-ruby direct-catalog-c direct-catalog-java direct-catalog-dotnet direct-catalog-beam

# Qualify installed HTTP/gRPC outcome diagnostics and recovery in every SDK.
connector-outcomes: python-build node-build rust-build ruby-build c-build java-build dotnet-build beam-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-http-worker" .cache/bindings/Debug --protocol http
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug

# Retain original accepted-call preparation failures across lost receipts and restart.
connector-preparation: python-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-http-worker" .cache/bindings/Debug --protocol http --language python --preparation-failure
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language python --preparation-failure

# Crash after public RPC output commit and preserve a retired caller destination.
grpc-faults: python-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language python --fault published
    python3 -B tests/runner/launch.py tests/sdk/sdk_grpc_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-grpc-worker" .cache/bindings/Debug --language python --fault retirement

# Qualify Document scoped jobs and read-only native/port consumers.
document-native:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    PYTHONPATH=sdks/python/transit-station:sdks/python/transit-client python3 -B tests/runner/launch.py tests/sdk/station_document_abi.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_station.so" "${native_prefix}/lib/libtransit_client.so" "${native_prefix}/bin/transit-station-host"

# Installed Python Document types, scoped changes, retained reads and host loss.
document-python: python-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language python

# Installed Node Document values, scoped ownership, retained reads and host loss.
document-node: node-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    vp exec --filter @transit/station tsc --noEmit
    vp exec --filter @transit/station node --test src/document.test.ts
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language node

# Installed Ruby Document values, scoped changes and joined reader destruction.
document-ruby: ruby-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    ruby -c sdks/ruby/transit-station/lib/transit/station/document.rb
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language ruby

# Installed Rust Document values and compiler-enforced owner/reader lifetimes.
document-rust: rust-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language rust

# Installed C11/C++17 Document handlers, owned values and reader lifetimes.
document-c: c-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language c

# Installed Java Document values, scoped jobs and asynchronous joined reads.
document-java: java-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language java

# Installed .NET Document values, scoped jobs, cancellation and joined disposal.
document-dotnet: dotnet-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language dotnet

# Installed Erlang and Elixir Document APIs share the native merge implementation.
document-beam: beam-build
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug)
    authority_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize Debug)
    mix format --check-formatted sdks/beam/transit-station-elixir/lib/document.ex tests/sdk/consumers/elixir/elixir_document_adapter.ex
    python3 -B tests/runner/launch.py tests/sdk/sdk_document_runner.py "${authority_prefix}/bin/transit-node" "${native_prefix}/bin/transit-admin" "${native_prefix}/lib/libtransit_client.so" .cache/bindings/Debug --language beam

# Python sync/async direct capture, independent native progress and rotated-credential results.
direct-captured-python:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    PYTHONPATH=sdks/python/transit-client:sdks/python/transit-station zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --python-native "${native_prefix}/lib"

# Ruby public port caller over direct Table lookup, capture and recovered results.
direct-captured-ruby:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    RUBYLIB=sdks/ruby/transit-client/lib:sdks/ruby/transit-station/lib zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --ruby-host "${native_prefix}/bin/transit-station-host"

# Installed JAR/NuGet callers share the direct capture and cleanup fault schedule.
direct-captured-managed: java-build dotnet-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --java-packages .cache/bindings/Debug/java --dotnet-packages .cache/bindings/Debug/dotnet

# Installed C11/C++17 callers own direct definitions independently of the client.
direct-captured-c: c-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --c-packages .cache/bindings/Debug/c

# Installed Erlang/Elixir callers retain independent direct cuts through recovery.
direct-captured-beam: beam-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --beam-packages .cache/bindings/Debug/beam

# Every installed language resolves, seals and reads the same retained Table query.
direct-captured-all: python-build node-build ruby-build rust-build c-build java-build dotnet-build beam-build
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --python-packages .cache/bindings/Debug/wheels --ruby-packages .cache/bindings/Debug/ruby --node-packages .cache/bindings/Debug/node --rust-packages .cache/bindings/Debug/rust --c-packages .cache/bindings/Debug/c --java-packages .cache/bindings/Debug/java --dotnet-packages .cache/bindings/Debug/dotnet --beam-packages .cache/bindings/Debug/beam

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
    python3 -B tests/runner/launch.py tests/sdk/sdk_unified.py

# Build matching ReleaseSafe wheels and qualify direct lifecycle and retained SQL.
direct-catalog-python:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging python -- python3 -B bindings/build_python.py .cache/bindings/ReleaseSafe/wheels transit-native-client transit-native-station transit-client transit-station --native-prefix "$native_prefix"
    zig build test-direct-catalog-python -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Build matching ReleaseSafe packages and qualify the TypeScript direct caller.
direct-catalog-node:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging node -- python3 -B bindings/build_node.py .cache/bindings/ReleaseSafe/node transit-native-client transit-client transit-native-station transit-station-sdk --native-prefix "$native_prefix"
    zig build test-direct-catalog-node -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed Python sync/async direct catalog and exact saved-operation recovery.
catalog-python: direct-catalog-python
    mypy --config-file sdks/python/transit-station/pyproject.toml sdks/python/transit-client/transit_client sdks/python/transit-station/transit_station

# Installed TypeScript catalog caller with generated runtime checks and saved recovery.
catalog-node: node-check direct-catalog-node

# Build matching ReleaseSafe crates and qualify installed Rust direct recovery.
direct-catalog-rust:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging rust -- python3 -B bindings/build_rust.py .cache/bindings/ReleaseSafe/rust transit-native-client transit-client transit-native-station transit-station-sdk --native-prefix "$native_prefix"
    zig build test-direct-catalog-rust -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed Rust catalog caller with exclusive borrows and saved recovery.
catalog-rust: direct-catalog-rust
    cargo fmt --manifest-path sdks/rust/transit-station-sdk/Cargo.toml --check

# Build matching ReleaseSafe gems and qualify the Ruby direct caller.
direct-catalog-ruby:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging ruby -- python3 -B bindings/build_ruby.py .cache/bindings/ReleaseSafe/ruby transit-native-client transit-client transit-native-station transit-station --native-prefix "$native_prefix"
    zig build test-direct-catalog-ruby -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed Ruby catalog caller with immutable values and joined worker ownership.
catalog-ruby: direct-catalog-ruby
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog_values.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/logical.rb
    ruby -c sdks/ruby/transit-station/lib/transit/station/catalog.rb

# Build matching ReleaseSafe prefixes and qualify both direct C/C++ callers.
direct-catalog-c:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    (cd sdks/c/transit-client && zig build -Doptimize=ReleaseSafe)
    (cd sdks/c/transit-station && zig build -Doptimize=ReleaseSafe)
    (cd sdks/cpp/transit-station-sdk && zig build check -Doptimize=ReleaseSafe)
    (cd examples/station-sdk/c && zig build -Doptimize=ReleaseSafe)
    (cd examples/station-sdk/cpp && zig build -Doptimize=ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging c -- python3 -B bindings/build_c.py .cache/bindings/ReleaseSafe/c --native-prefix "$native_prefix"
    zig build test-direct-catalog-c -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed C11/C++17 catalog callers with owned values and saved recovery.
catalog-c: direct-catalog-c

# Build matching ReleaseSafe JARs and qualify Java direct lifecycle recovery.
direct-catalog-java:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging java -- python3 -B bindings/build_java.py .cache/bindings/ReleaseSafe/java transit-native-client transit-client transit-native-station transit-station-sdk --native-prefix "$native_prefix"
    zig build test-direct-catalog-java -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed Java catalog futures, generated port validation and owned recovery.
catalog-java: direct-catalog-java

# Build matching ReleaseSafe NuGet packages and qualify direct lifecycle recovery.
direct-catalog-dotnet:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging dotnet -- python3 -B bindings/build_dotnet.py .cache/bindings/ReleaseSafe/dotnet transit-native-client transit-client transit-native-station transit-station-sdk --native-prefix "$native_prefix"
    zig build test-direct-catalog-dotnet -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed .NET catalog tasks, generated ABI validation and joined ownership.
catalog-dotnet: direct-catalog-dotnet

# Build matching ReleaseSafe OTP artifacts and qualify both direct callers.
direct-catalog-beam:
    #!/usr/bin/env bash
    set -euo pipefail
    native_prefix=$(python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize ReleaseSafe)
    python3 -B tests/runner/launch.py tests/harness/phases.py packaging beam -- python3 -B bindings/build_beam.py .cache/bindings/ReleaseSafe/beam transit-native-client transit-client transit-client-elixir transit-native-station transit-station-sdk transit-station-elixir --native-prefix "$native_prefix"
    zig build test-direct-catalog-beam -Doptimize=ReleaseSafe -Dsdk-packages=.cache/bindings/ReleaseSafe

# Installed Erlang/Elixir catalog values and joined native-port ownership.
catalog-beam: direct-catalog-beam
    ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1' mix format --check-formatted sdks/beam/transit-station-elixir/lib/catalog.ex tests/sdk/consumers/elixir/elixir_catalog_adapter.ex

# Compile and run the public Zig SDK and a separately built application.
zig-test:
    cd sdks/zig && zig build test
    python3 -B tests/runner/launch.py tests/sdk/sdk_zig.py

# Build the runtime without tests/SDKs and reject disabled or missing checks.
runtime-boundary:
    python3 -B tests/runner/test_nix_inputs.py
    python3 -B tests/runner/test_nix_evaluation.py
    python3 -B tests/runner/launch.py tests/sdk/sdk_runtime.py

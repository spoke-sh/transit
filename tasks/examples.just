set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list examples

# Compile complete example applications separately from platform executables.
build:
    zig build examples

# Run an example against a fresh, owned local disk Ursula and authority.
run name:
    zig build apps examples
    python3 -B examples/local.py {{quote(name)}}

# Finite HTTP call, separate connector, captured replay and worker/store recovery.
http:
    zig build transit-node rey-cli example-station-http transit-station-http-worker
    python3 -B examples/station-http/run.py

# The finite HTTP example with separate client, storage and effect networks.
http-compose:
    zig build rey-cli
    python3 -B examples/station-http/run.py --profile compose

# Fresh public caller registration and generation-pinned operator activation.
http-bootstrap:
    zig build transit-node rey-cli example-station-http transit-station-http-worker
    python3 -B examples/station-http/run.py --bootstrap

# Isolated Substrate caller and egress-confined effect pod in owned reference infra.
http-reference:
    zig build rey-cli
    python3 -B examples/station-http/run.py --profile reference

# Finite binary RPC caller, independent TLS peer and durable recovery/replay.
grpc:
    zig build transit-node rey-cli example-station-grpc transit-station-grpc-worker
    python3 -B examples/station-grpc/run.py

grpc-bootstrap:
    zig build transit-node rey-cli example-station-grpc transit-station-grpc-worker
    python3 -B examples/station-grpc/run.py --bootstrap

# RPC effect isolation in separate Compose networks.
grpc-compose:
    zig build rey-cli
    python3 -B examples/station-grpc/run.py --profile compose

# Substrate caller and egress-confined RPC effect pod in owned reference infra.
grpc-reference:
    zig build rey-cli
    python3 -B examples/station-grpc/run.py --profile reference

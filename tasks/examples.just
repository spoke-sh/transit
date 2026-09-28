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

# Two independent Document editors, atomic replies and worker/store recovery.
document:
    zig build transit-node rey-cli transit-station-document-worker example-station-document
    python3 -B examples/station-document/run.py

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

# Two editors and a writer on a client network isolated from disk Ursula.
document-compose:
    zig build rey-cli
    python3 -B examples/station-document/run.py --profile compose

# Two Substrate editor identities and a trusted writer in an owned namespace.
document-reference:
    zig build rey-cli
    python3 -B examples/station-document/run.py --profile reference

# Finite SQL over synthetic Unicode data; exact caller and worker/disk recovery.
query source="table":
    python3 -B examples/state-query/run.py --source {{quote(source)}}

# Separate query hosts, caller and private storage network.
query-compose source="table":
    zig build unified-query-proof example-state-query transit-query-host -Doptimize=ReleaseSafe
    python3 -B examples/state-query/run.py --profile compose --source {{quote(source)}}

# Two Substrate query hosts; explicit operator grants and fresh ownership.
query-reference source="table":
    zig build unified-query-proof example-state-query transit-query-host -Doptimize=ReleaseSafe
    python3 -B examples/state-query/run.py --profile reference --source {{quote(source)}}

# Two private HTTP/TLS gateways and fenced workers recover owned Compose storage.
serving-compose:
    nix develop .#serving --command python3 -B examples/serving/run.py --profile compose

# Fresh Substrate worker keys and exact generations; an owned namespace only.
serving-reference:
    zig build transit-query-host -Doptimize=ReleaseSafe
    nix develop .#serving --command python3 -B examples/serving/run.py --profile reference

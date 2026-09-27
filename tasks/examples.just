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

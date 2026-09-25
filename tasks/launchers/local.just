set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := "../.."

[default]
_default:
    @just --list launchers local

# Build candidates without changing the running installation.
[positional-arguments]
build *args:
    python3 -B launchers/main.py local build "$@"

# Build and apply compatible changes; pass --no-build to select existing candidates.
[positional-arguments]
update *args:
    python3 -B launchers/main.py local update "$@"

# Stream a persistent local stack's logs; pass --detach (or -d) for background use.
[positional-arguments]
up *args:
    python3 -B launchers/main.py local up "$@"

# Stop owned services while preserving history, configuration and credentials.
down:
    python3 -B launchers/main.py local down

# Show machine-readable service status, identity and endpoints.
status:
    python3 -B launchers/main.py local status

# Print endpoint URLs and listener settings.
endpoints:
    python3 -B launchers/main.py local endpoints

# Inspect the realm through Board's read-only API.
inspect:
    python3 -B launchers/main.py local inspect

# Show recent service logs (or manager for native lifecycle/probe evidence).
logs service="node":
    python3 -B launchers/main.py local logs {{quote(service)}}

# Restart one service; counter replacement receives a fresh fenced activation.
restart service:
    python3 -B launchers/main.py local restart {{quote(service)}}

# Admit a counter input; reuse the request ID to retry without duplicate admission.
send value request_id="":
    python3 -B launchers/main.py local send {{quote(value)}} --request-id {{quote(request_id)}}

# Permanently delete this installation's data and keys; requires down first.
reset:
    python3 -B launchers/main.py local reset

# Prove persistence, duplicate-safe provisioning, fencing and missing-store refusal.
test:
    python3 -B tests/launchers.py local

# Qualify the three-process Station example, Board lenses and fresh ownership.
test-station:
    python3 -B tests/station_launchers.py local

# Attach the terminal service/log viewer; detach leaves the stack running.
attach:
    python3 -B launchers/main.py local attach

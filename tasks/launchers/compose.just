set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := "../.."

[default]
_default:
    @just --list launchers compose

# Compile the binaries used by this launcher; install frontend dependencies first.
build:
    zig build apps

# Start an owned persistent development stack and print endpoints/access-key path.
up: build
    python3 -B launchers/main.py compose up

# Stop owned services while preserving history, configuration and credentials.
down:
    python3 -B launchers/main.py compose down

# Show machine-readable service status, identity and endpoints.
status:
    python3 -B launchers/main.py compose status

# Print endpoint and credential-file locations; never print the credential.
endpoints:
    python3 -B launchers/main.py compose endpoints

# Inspect the realm through Board's authenticated public API.
inspect:
    python3 -B launchers/main.py compose inspect

# Show recent logs for one service.
logs service="node":
    python3 -B launchers/main.py compose logs {{quote(service)}}

# Restart one service; counter replacement receives a fresh fenced activation.
restart service:
    python3 -B launchers/main.py compose restart {{quote(service)}}

# Admit a counter input; reuse the request ID to retry without duplicate admission.
send value request_id="":
    python3 -B launchers/main.py compose send {{quote(value)}} --request-id {{quote(request_id)}}

# Permanently delete this installation's data and keys; requires down first.
reset:
    python3 -B launchers/main.py compose reset

# Prove persistence, duplicate-safe provisioning, fencing and missing-store refusal.
test: build
    python3 -B tests/launchers.py compose

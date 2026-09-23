set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list reference

# Create an isolated Linux/Docker Kubernetes + Substrate reference cluster.
up:
    python3 -B tests/reference.py up

# Build Rey's images and the pinned upstream runtime; use Ursula's official image.
images:
    python3 -B tests/reference.py images

# Kill real workers/controllers and restart persistent storage on the owned cluster.
test:
    python3 -B tests/reference_workload.py

# Delete only the cluster and registry recorded by reference::up.
down:
    python3 -B tests/reference.py down

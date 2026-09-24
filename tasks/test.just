set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list test

# Run unit and protocol checks without a service.
unit:
    zig build test

# Qualify finite IPC schemas/values against an independent Arrow reader.
arrow:
    zig build test-arrow

# Prove the generated C ABI and exact retry after a foreign host exits.
client-abi:
    zig build test-client-abi

# Check each library using its own declared dependencies.
packages:
    cd packages/zig/transit-fuze && zig build test
    cd packages/zig/transit-observability && zig build test
    cd packages/zig/telemetry && zig build test
    cd packages/zig/transit-board-api && zig build test
    cd packages/zig/transit-protocol && zig build test
    cd packages/zig/transit-core && zig build test
    cd packages/zig/transit-backend-ursula && zig build test
    cd packages/zig/transit-client && zig build test
    cd packages/zig/transit-runtime-substrate && zig build test

# Run isolated persistent Ursula tests, including SIGKILL and restart.
storage:
    zig build test-storage

# Exercise signed HTTP ingress and worker recovery against isolated disk Ursula.
service:
    zig build test-service

# Exercise independent Zig callers against the same generic authority.
callers:
    zig build test-callers

# Linux/Docker: fill an owned ext4 image while keeping a physical control reserve.
capacity:
    zig build capacity-proof
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/capacity.py zig-out/bin/transit-capacity-proof

# Exercise bounded discovery and retained inspection through the public client.
inspection:
    zig build test-inspection

# Prove authorized state reads and atomic KV commits through the public service.
state:
    zig build test-state

# Prove bounded diagnostics, independent metrics and cancelable log sinks.
telemetry:
    zig build test-telemetry

# Prove Board/client/node correlation and protocol-aware diagnostic outcomes.
observability:
    zig build test-observability

# Render and validate the Transit Helm chart without a cluster.
deployments:
    python3 -B tests/deployments.py

# Verify checkout-local Kubernetes selection without contacting a cluster.
dev-environment:
    python3 -B tests/dev_environment.py

# Prove the inspection plugin's CLI, subprocess and credential boundaries offline.
kubectl-transit:
    zig build test-kubectl-transit

# Prove fenced workload changes and recovery after a lost provider response.
runtime-upgrade:
    zig build test-runtime-upgrade

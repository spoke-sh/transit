set shell := ["bash", "-euo", "pipefail", "-c"]

# List the available project commands.
default:
    @just --list

# Show tool versions and verify the CLIs without contacting a cluster.
doctor:
    nix --version
    just --version
    python3 --version
    zig version
    node --version
    pnpm --version
    vp toolchain --global
    ursula --help > /dev/null
    ursulactl --version
    kubectl version --client
    k9s version --short
    if [[ "$(uname -s)" == "Linux" ]]; then k3s --version; fi

# Validate tooling and the implemented Zig packages.
check:
    nixfmt --check flake.nix nix/*.nix
    nix flake check
    zig fmt --check build.zig packages/zig apps examples tests/*.zig
    zig build test
    python3 -B tests/docs.py
    git diff --check

# Compile services, clients, and executable proofs.
build:
    zig build

# Run unit and protocol checks without a service.
test:
    zig build test

# Run isolated persistent Ursula tests, including SIGKILL and restart.
test-storage:
    zig build test-storage

# Exercise signed HTTP ingress and worker recovery against isolated disk Ursula.
test-service:
    zig build test-service

# Check each library using its own declared dependencies.
test-packages:
    cd packages/zig/transit && zig build test
    cd packages/zig/transit-ursula && zig build test
    cd packages/zig/transit-client && zig build test

# Format the Nix configuration.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig apps examples tests/*.zig

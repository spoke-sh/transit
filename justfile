set shell := ["bash", "-euo", "pipefail", "-c"]

# List the available project commands.
default:
    @just --list

# Show tool versions and verify the CLIs without contacting a cluster.
doctor:
    nix --version
    just --version
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
    zig fmt --check build.zig packages/zig tests/*.zig
    zig build test
    git diff --check

# Compile the executable storage proof.
build:
    zig build

# Run unit and protocol checks without a service.
test:
    zig build test

# Run isolated persistent Ursula tests, including SIGKILL and restart.
test-storage:
    zig build test-storage

# Format the Nix configuration.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig tests/*.zig

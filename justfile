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
    just check-contract
    python3 -B tests/docs.py
    git diff --check

# Run the hosted CI checks within one already-entered development environment.
ci: check test-packages test-storage test-service test-callers

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

# Exercise independent Zig callers against the same generic authority.
test-callers:
    zig build test-callers

# Linux/Docker: fill an owned ext4 image while keeping a physical control reserve.
test-capacity:
    zig build capacity-proof
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/capacity.py zig-out/bin/transit-capacity-proof

# Create an isolated Linux/Docker Kubernetes + Substrate reference cluster.
reference-up:
    python3 -B tests/reference.py up

# Build Rey's images and the pinned upstream runtime; use Ursula's official image.
reference-images:
    python3 -B tests/reference.py images

# Kill real workers/controllers and restart persistent storage on the owned cluster.
reference-test:
    python3 -B tests/reference_workload.py

# Delete only the cluster and registry recorded by reference-up.
reference-down:
    python3 -B tests/reference.py down

# Check each library using its own declared dependencies.
test-packages:
    cd packages/zig/transit-protocol && zig build test
    cd packages/zig/transit-core && zig build test
    cd packages/zig/transit-ursula && zig build test
    cd packages/zig/transit-client && zig build test
    cd packages/zig/runtime-substrate && zig build test

# Format the Nix configuration.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig apps examples tests/*.zig

# Regenerate the public binding resource from the authoritative Zig wire types.
generate-contract:
    zig build contract > contracts/transit-v2.schema.json

# Detect public schema/default/signing changes that were not reviewed together.
check-contract:
    zig build contract | python3 -B tests/contract.py

set shell := ["bash", "-euo", "pipefail", "-c"]

# Compile executables with an explicit Zig optimization profile.
mod build 'tasks/build.just'

# Embedded inspection API, UI and generated browser client.
mod transit-board 'tasks/transit-board.just'

# Persistent development environments and the deployment reference.
mod launchers 'tasks/launchers.just'

# Unit, package and integration proofs.
mod test 'tasks/test.just'

# Build and run complete example applications.
mod examples 'tasks/examples.just'

# Generate and validate the public protocol contract.
mod contract 'tasks/contract.just'

# List common commands and task namespaces.
[default]
_default:
    @just --list

# Show tool versions and verify the CLIs without contacting a cluster.
doctor:
    nix --version
    just --version
    python3 --version
    process-compose version
    zig version
    node --version
    pnpm --version
    vp toolchain --global
    ursula --help > /dev/null
    ursulactl --version
    kubectl version --client
    helm version --short
    k9s version --short
    kind version
    kubectl ate --version
    kubectl transit --version
    kubectl plugin list

# Validate tooling, generated contracts, Zig and frontend code (install dependencies first).
check:
    nixfmt --check flake.nix nix/*.nix
    nix flake check
    zig fmt --check build.zig packages/zig apps examples tests/*.zig
    just contract::check
    just transit-board::check
    just test::unit
    python3 -B tests/docs.py
    git diff --check

# Run the hosted CI checks within one already-entered development environment.
ci: check test::dev-environment test::kubectl-transit test::deployments test::telemetry test::observability test::packages test::arrow test::client-abi test::station test::storage test::service test::runtime-upgrade test::callers test::inspection test::state transit-board::test launchers::local::test

# Run the committed HEAD's CI suite in a fresh clone, without local build outputs.
ci-clean:
    python3 -B tests/ci_clean.py

# Format Nix, Zig and frontend source/documentation without regenerating contracts.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig apps examples tests/*.zig
    just transit-board::fmt

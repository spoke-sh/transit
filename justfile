set shell := ["bash", "-euo", "pipefail", "-c"]

# Compile executables with an explicit Zig optimization profile.
mod build 'tasks/build.just'

# Embedded inspection API, UI and generated browser client.
mod board 'tasks/board.just'

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
    if [[ "$(uname -s)" == "Linux" ]]; then k3s --version; fi

# Validate tooling and the implemented Zig packages.
check:
    nixfmt --check flake.nix nix/*.nix
    nix flake check
    zig fmt --check build.zig packages/zig apps examples tests/*.zig
    just test::unit
    just contract::check
    python3 -B tests/docs.py
    git diff --check

# Run the hosted CI checks within one already-entered development environment.
ci: check test::deployments test::telemetry test::observability test::packages test::storage test::service test::callers test::inspection board::check board::test launchers::local::test

# Format Nix and Zig source.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig apps examples tests/*.zig

set shell := ["bash", "-euo", "pipefail", "-c"]

# Compile executables with an explicit Zig optimization profile.
mod build 'tasks/build.just'

# Embedded inspection API, UI and generated browser client.
mod transit-board 'tasks/transit-board.just'

# Public guides, Internals and generated interface reference.
mod transit-docs 'tasks/transit-docs.just'

# Persistent development environments and the deployment reference.
mod launchers 'tasks/launchers.just'

# Unit, package and integration proofs.
mod test 'tasks/test.just'

# Build and run complete example applications.
mod examples 'tasks/examples.just'

# Generate and validate the public protocol contract.
mod contract 'tasks/contract.just'

# Shared client/framework declarations and foreign-language qualification.
mod bindings 'tasks/bindings.just'

# Scoped local checks and the complete repository check.
mod check 'tasks/check.just'

# Hosted CI lanes and the complete local suite.
mod ci 'tasks/ci.just'

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
    openssl version
    psql --version
    mysql --version
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

# Format Nix, Zig and frontend source/documentation without regenerating contracts.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig sdks/zig packages/zig apps examples tests/*.zig tests/fuze_benchmarks
    just transit-board::fmt

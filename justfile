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
check: check-core transit-board::check transit-docs::check

# Foundation checks shared by local check and the core CI lane.
check-core:
    nixfmt --check flake.nix nix/*.nix
    actionlint .github/workflows/*.yml
    python3 -B tests/benchmarks/test_runner.py
    python3 -B tests/fuze_benchmarks/test_runner.py
    python3 -B tests/mutation_latency_test.py
    python3 -B tests/fuze_sources.py
    python3 -B tests/fuze_types.py
    python3 -B tests/ci_runner.py
    python3 -B tests/reference_launcher_state.py
    python3 -B tests/verification/check.py
    just test::diagnostic-inventory
    just test::diagnostic-mappings
    just test::diagnostic-errors
    just test::diagnostic-outcomes
    just test::diagnostic-grammar
    nix flake check
    zig fmt --check build.zig packages/zig apps examples tests/*.zig tests/fuze_benchmarks
    just contract::check
    just test::unit
    just test::cli-diagnostics
    just test::console-history
    python3 -B tests/docs.py
    git diff --check

# Run the committed HEAD's CI suite in a fresh clone, without local build outputs.
ci-clean *args:
    python3 -B tests/ci_clean.py {{args}}

# Format Nix, Zig and frontend source/documentation without regenerating contracts.
fmt:
    nixfmt flake.nix nix/*.nix
    zig fmt build.zig packages/zig apps examples tests/*.zig tests/fuze_benchmarks
    just transit-board::fmt

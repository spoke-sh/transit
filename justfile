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

# Validate the foundation; application checks will be added with application code.
check:
    nixfmt --check flake.nix nix/*.nix
    nix flake check
    git diff --check

# Format the Nix configuration.
fmt:
    nixfmt flake.nix nix/*.nix

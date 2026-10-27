set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

# List validation scopes; running this default does not qualify any checks.
[default]
_default:
    @just --list check

# Formatting, tooling, independent Python oracles and docs; no runtime build.
fast:
    python3 -B tests/runner/checks.py fast

# Reflected schemas, signing fixtures and generated language resource drift.
contracts:
    zig build check-contracts

# Native scopes: all, components (includes filesystem), fixtures, or process faults.
[positional-arguments]
native scope="all":
    python3 -B tests/runner/checks.py "native-$1"

# Foundation checks shared by local qualification and the core CI lane.
core: fast
    just test::diagnostic-errors
    just test::diagnostic-outcomes
    just test::diagnostic-grammar
    nix flake check
    just check contracts
    just check::native
    just test::cli-diagnostics
    just test::console-history
    git diff --check

# Complete repository checks, including Board and docs; install dependencies first.
all: core
    just transit-board::check
    just transit-docs::check

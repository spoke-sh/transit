set positional-arguments

# Show available recipes.
default:
    @just --list

# Run the default human-facing verification flow.
mission:
    #!/usr/bin/env bash
    set -euo pipefail

    repo_root="{{justfile_directory()}}"
    mission_root="$repo_root/target/transit-mission"

    (
        cd "$repo_root"

        rm -rf "$mission_root"
        mkdir -p "$mission_root/object-store" "$mission_root/local-engine"

        just build
        just test
        just doctest
        just run mission local-engine-proof --root "$mission_root/local-engine"
        just run object-store probe --root "$mission_root/object-store"
        just mission-status
    )

# Show the current mission-status summary.
mission-status:
    cargo run -p transit-cli --bin transit -- mission status --repo-root {{justfile_directory()}}

# Build the workspace.
build:
    cargo build --workspace

# Run cargo check across the workspace.
check:
    cargo check --workspace

# Run the workspace test suite with cargo-nextest.
test:
    cargo nextest run --workspace

# Run workspace documentation tests.
doctest:
    cargo test --workspace --doc

# Format the workspace.
fmt:
    cargo fmt --all

# Verify formatting without writing changes.
fmt-check:
    cargo fmt --all -- --check

# Lint the workspace.
clippy:
    cargo clippy --workspace --all-targets -- -D warnings

# Run the transit CLI help output.
help:
    cargo run -p transit-cli --bin transit -- --help

# Run the transit CLI with arbitrary arguments.
run *args:
    cargo run -p transit-cli --bin transit -- {{args}}

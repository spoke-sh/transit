set positional-arguments

# Show available recipes.
default:
    @just --list

# Run the default human-facing verification flow and board screen.
screen:
    #!/usr/bin/env bash
    set -euo pipefail

    repo_root="{{justfile_directory()}}"
    screen_root="$repo_root/target/transit-screen"

    announce() {
        printf '\n==> %s\n' "$1"
    }

    render_keel_screen() {
        if keel screen --help >/dev/null 2>&1; then
            keel screen
        else
            keel flow
        fi
    }

    (
        cd "$repo_root"

        rm -rf "$screen_root"
        mkdir -p "$screen_root/object-store" "$screen_root/local-engine" "$screen_root/integrity" "$screen_root/materialization" "$screen_root/tiered-engine" "$screen_root/controlled-failover" "$screen_root/chaos-failover" "$screen_root/networked-server"

        announce "Build workspace"
        just build
        announce "Prove local engine"
        just run mission local-engine-proof --root "$screen_root/local-engine"
        announce "Prove tiered engine"
        just run mission tiered-engine-proof --root "$screen_root/tiered-engine"
        announce "Prove controlled failover"
        just run mission controlled-failover-proof --root "$screen_root/controlled-failover"
        announce "Prove chaos failover"
        just run mission chaos-failover-proof --root "$screen_root/chaos-failover"
        announce "Prove networked server"
        just run mission networked-server-proof --root "$screen_root/networked-server"
        announce "Prove integrity proof"
        just run mission integrity-proof --root "$screen_root/integrity"
        announce "Prove materialization"
        just run mission materialization-proof --root "$screen_root/materialization"
        announce "Probe object store"
        just run object-store probe --root "$screen_root/object-store"
        announce "Show transit status"
        just screen-status
    )

# Backward-compatible alias for the old verification recipe name.
mission:
    @just screen

# Show the current transit status summary.
screen-status:
    cargo run -p transit-cli --bin transit -- mission status --repo-root {{justfile_directory()}}

# Backward-compatible alias for the old status recipe name.
mission-status:
    @just screen-status

# Run the Rust client proof example against a locally started transit server.
rust-client-proof:
    cargo run -p transit-client --example proof

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

# Run the standard local guardrails enforced by the keel pre-commit hook.
quality:
    just fmt-check
    just clippy

# Run the transit CLI help output.
help:
    cargo run -p transit-cli --bin transit -- --help

# Run the transit CLI with arbitrary arguments.
run *args:
    cargo run -p transit-cli --bin transit -- {{args}}

# Install website dependencies through the repo-supported Node toolchain.
docs-install:
    nix shell nixpkgs#nodejs_20 --command npm --prefix website ci

# Sync foundational root docs into the public website reference section.
docs-sync:
    nix shell nixpkgs#nodejs_20 --command npm --prefix website run sync:foundations

# Build the public docs site.
docs-build:
    nix shell nixpkgs#nodejs_20 --command npm --prefix website run build

# Run the public docs dev server.
docs-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    port="${PORT:-3000}"
    nix shell nixpkgs#nodejs_20 --command bash -lc "npm --prefix website run start -- --host 0.0.0.0 --port ${port}"

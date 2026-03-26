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
        mkdir -p "$screen_root/object-store" "$screen_root/local-engine" "$screen_root/integrity" "$screen_root/tiered-engine" "$screen_root/networked-server"

        announce "Build workspace"
        just build
        announce "Prove local engine"
        just run mission local-engine-proof --root "$screen_root/local-engine"
        announce "Prove integrity surfaces"
        just run mission integrity-proof --root "$screen_root/integrity"
        announce "Prove tiered engine"
        just run mission tiered-engine-proof --root "$screen_root/tiered-engine"
        announce "Prove networked server"
        just run mission networked-server-proof --root "$screen_root/networked-server"
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

# Prove the Python client library works end to end.
python-client-proof:
    #!/usr/bin/env bash
    set -euo pipefail
    
    proof_root="$(mktemp -d)"
    trap 'rm -rf "$proof_root"' EXIT
    
    # Start server in background
    cargo run -p transit-cli --bin transit -- server run --root "$proof_root" --listen-addr 127.0.0.1:7171 --serve-for-ms 5000 &
    server_pid=$!
    
    # Wait for server to be ready
    sleep 2
    
    # Run Python proof
    export PYTHONPATH="clients/python"
    python3 clients/python/proof.py
    
    # Wait for server to finish
    wait $server_pid

# Prove the Dojo sparring tapes work end to end.
dojo-proof:
    #!/usr/bin/env bash
    set -euo pipefail
    
    proof_root="$(mktemp -d)"
    trap 'rm -rf "$proof_root"' EXIT
    
    # Start server in background
    cargo run -p transit-cli --bin transit -- server run --root "$proof_root" --listen-addr 127.0.0.1:7171 --serve-for-ms 5000 &
    server_pid=$!
    
    # Wait for server to be ready
    sleep 2
    
    # Run Dojo proof
    export PYTHONPATH="dojo:clients/python"
    python3 dojo/proof.py
    
    # Wait for server to finish
    wait $server_pid

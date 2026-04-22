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

    (
        cd "$repo_root"

        storage_probe_config="$screen_root/storage-probe.toml"

        rm -rf "$screen_root"
        mkdir -p "$screen_root/object-store" "$screen_root/local-engine" "$screen_root/compression" "$screen_root/retention" "$screen_root/object-store-authority" "$screen_root/integrity" "$screen_root/materialization" "$screen_root/hosted-materialization" "$screen_root/reference-projection" "$screen_root/tiered-engine" "$screen_root/warm-cache-recovery" "$screen_root/controlled-failover" "$screen_root/chaos-failover" "$screen_root/networked-server"

        printf '%s\n' \
            '[node]' \
            'id = "screen"' \
            'mode = "embedded"' \
            "data_dir = \"$screen_root/storage-data\"" \
            "cache_dir = \"$screen_root/storage-cache\"" \
            '' \
            '[storage]' \
            'provider = "filesystem"' \
            "bucket = \"$screen_root/object-store\"" \
            'prefix = "screen"' \
            'durability = "local"' \
            > "$storage_probe_config"

        announce "Build workspace"
        just build
        announce "Prove local engine"
        just transit proof local-engine --root "$screen_root/local-engine"
        announce "Prove compression"
        just transit proof compression --root "$screen_root/compression"
        announce "Prove retention"
        just transit proof retention --root "$screen_root/retention"
        announce "Prove object-store authority"
        just transit proof object-store-authority --root "$screen_root/object-store-authority"
        announce "Prove tiered engine"
        just transit proof tiered-engine --root "$screen_root/tiered-engine"
        announce "Prove warm-cache recovery"
        just transit proof warm-cache-recovery --root "$screen_root/warm-cache-recovery"
        announce "Prove controlled failover"
        just transit proof controlled-failover --root "$screen_root/controlled-failover"
        announce "Prove chaos failover"
        just transit proof chaos-failover --root "$screen_root/chaos-failover"
        announce "Prove networked server"
        just transit proof networked-server --root "$screen_root/networked-server" --server-connection-io-timeout-ms 5000 --client-io-timeout-ms 5000
        announce "Prove integrity proof"
        just transit proof integrity --root "$screen_root/integrity"
        announce "Prove materialization"
        just transit proof materialization --root "$screen_root/materialization"
        announce "Prove hosted materialization"
        just transit proof hosted-materialization --root "$screen_root/hosted-materialization" --server-connection-io-timeout-ms 5000 --client-io-timeout-ms 5000
        announce "Prove reference projection"
        just transit proof reference-projection --root "$screen_root/reference-projection"
        announce "Probe storage"
        just transit --config "$storage_probe_config" storage probe
        announce "Show transit status"
        just screen-status
        announce "Show board screen"
        just keel screen --static
    )

# Backward-compatible alias for the old verification recipe name.
mission:
    @just screen

# Show the current transit log summary for the default screen proof root.
screen-status:
    cargo run -p transit-cli --bin transit -- status --root {{justfile_directory()}}/target/transit-screen/local-engine

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
transit *args:
    cargo run -p transit-cli --bin transit -- {{args}}

# Run the keel CLI with arbitrary arguments.
keel *args:
    command keel {{args}}

# Install website dependencies through the repo-supported Node toolchain.
docs-install:
    nix shell nixpkgs#nodejs_24 --command npm --prefix website ci

# Build the public docs site.
docs-build:
    nix shell nixpkgs#nodejs_24 --command npm --prefix website run build

# Run the public docs dev server.
docs-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    port="${PORT:-3000}"
    nix shell nixpkgs#nodejs_24 --command bash -lc "npm --prefix website run start -- --host 0.0.0.0 --port ${port}"

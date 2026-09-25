set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list contract

# Regenerate the public binding resource from the authoritative Zig wire types.
generate:
    #!/usr/bin/env bash
    set -euo pipefail
    generated=$(mktemp -d)
    trap 'rm -rf "$generated"' EXIT
    zig build contract > "$generated/transit-v2.schema.json"
    zig build growth-contract > "$generated/transit-v3.schema.json"
    mv "$generated/transit-v2.schema.json" contracts/transit-v2.schema.json
    mv "$generated/transit-v3.schema.json" contracts/transit-v3.schema.json

# Detect public schema/default/signing changes that were not reviewed together.
check:
    zig build contract | python3 -B tests/contract.py
    zig build growth-contract | python3 -B tests/contract.py --growth
    just contract::client-check
    just contract::station-check
    python3 -B bindings/generate.py

# Regenerate the C ABI resource and header from exported Zig function types.
client-generate:
    zig build client-contract | python3 -B packages/zig/transit-client/generate.py --write

client-check:
    zig build client-contract | python3 -B packages/zig/transit-client/generate.py

# Regenerate shared Station exports and language-neutral handler operations.
station-generate:
    zig build station-contract | python3 -B packages/zig/transit-station/generate.py --write

station-check:
    zig build station-contract | python3 -B packages/zig/transit-station/generate.py

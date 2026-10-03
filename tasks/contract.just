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
    zig build contract > "$generated/transit-v1.schema.json"
    zig build application-installation-contract > "$generated/application-installation-v1.schema.json"
    zig build diagnostic-contract > "$generated/diagnostic-v1.schema.json"
    mv "$generated/transit-v1.schema.json" contracts/transit-v1.schema.json
    mv "$generated/application-installation-v1.schema.json" contracts/application-installation-v1.schema.json
    mv "$generated/diagnostic-v1.schema.json" contracts/diagnostic-v1.schema.json
    zig build application-installation-fixture > contracts/application-installation-v1.fixture.json

# Detect public schema/default/signing changes that were not reviewed together.
check:
    zig build contract | python3 -B tests/contract.py
    zig build application-installation-contract | python3 -B tests/contract.py --installation
    zig build application-installation-fixture | python3 -B tests/installation_contract.py
    zig build diagnostic-contract | python3 -B tests/diagnostic_contract.py
    just contract::client-check
    just contract::station-check
    just contract::logical-check
    python3 -B bindings/generate.py

# Regenerate the C ABI resource and header from exported Zig function types.
client-generate:
    zig build client-contract | python3 -B packages/zig/transit-client/generate.py --write

client-check:
    zig build client-contract | python3 -B packages/zig/transit-client/generate.py

# Regenerate shared Station exports and language-neutral handler operations.
station-generate:
    zig build station-contract | python3 -B packages/zig/transit-station-bindings/generate.py --write

station-check:
    zig build station-contract | python3 -B packages/zig/transit-station-bindings/generate.py

# Reflect recursive logical documents independently of transport envelopes.
logical-generate:
    zig build logical-contract | python3 -B packages/zig/transit-fuze/generate.py --write

logical-check:
    zig build logical-contract | python3 -B packages/zig/transit-fuze/generate.py

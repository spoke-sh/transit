set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list contract

# Regenerate the public binding resource from the authoritative Zig wire types.
generate:
    zig build contract > contracts/transit-v2.schema.json

# Detect public schema/default/signing changes that were not reviewed together.
check:
    zig build contract | python3 -B tests/contract.py
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

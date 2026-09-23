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

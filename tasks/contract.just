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
    zig build data-lifecycle-contract > "$generated/data-lifecycle-v1.schema.json"
    zig build index-lifecycle-contract > "$generated/index-lifecycle-v1.schema.json"
    mv "$generated/transit-v1.schema.json" contracts/transit-v1.schema.json
    mv "$generated/application-installation-v1.schema.json" contracts/application-installation-v1.schema.json
    mv "$generated/diagnostic-v1.schema.json" contracts/diagnostic-v1.schema.json
    mv "$generated/data-lifecycle-v1.schema.json" contracts/data-lifecycle-v1.schema.json
    mv "$generated/index-lifecycle-v1.schema.json" contracts/index-lifecycle-v1.schema.json
    python3 -B tests/index_lifecycle_contract.py --write < contracts/index-lifecycle-v1.schema.json
    python3 -B tests/work_items_contract.py --write
    zig build application-installation-fixture > contracts/application-installation-v1.fixture.json

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

direct-table-generate:
    zig build direct-table-contract | python3 -B tests/direct_table_contract.py --write

direct-table-check:
    zig build direct-table-contract | python3 -B tests/direct_table_contract.py

configuration-generate:
    zig build configuration-contract | python3 -B tests/runner/launch.py tests/interfaces/installation/configuration_contract.py --write
    zig build settings-reference | python3 -B tests/runner/launch.py tests/interfaces/installation/configuration_reference.py --write

configuration-check:
    zig build configuration-contract | python3 -B tests/runner/launch.py tests/interfaces/installation/configuration_contract.py
    zig build settings-reference | python3 -B tests/runner/launch.py tests/interfaces/installation/configuration_reference.py

sql-session-generate:
    cd packages/zig/transit-sql-protocol && zig build schema | python3 -B ../../../tests/interfaces/sql_sessions/contracts.py --schema --write
    python3 -B tests/runner/launch.py tests/interfaces/sql_sessions/contracts.py --write

sql-session-check:
    cd packages/zig/transit-sql-protocol && zig build schema | python3 -B ../../../tests/interfaces/sql_sessions/contracts.py --schema
    python3 -B tests/runner/launch.py tests/interfaces/sql_sessions/contracts.py

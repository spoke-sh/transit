set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list board

# Install the locked frontend build and test dependencies with Vite+.
install:
    vp install --frozen-lockfile

# Regenerate Board's OpenAPI, TypeScript types, and CSP-compatible validators.
generate:
    zig build board-contract > contracts/board-v1.openapi.json
    python3 -B packages/ts/board-client/generate.py
    vp exec node packages/ts/board-client/validators.mjs

# Check typed contract and generated browser-resource drift.
contract:
    zig build board-contract | python3 -B tests/board_contract.py
    python3 -B packages/ts/board-client/generate.py --check
    vp exec node packages/ts/board-client/validators.mjs --check

# Check frontend formatting, lint, strict types and unit tests.
check: contract
    cd apps/board-web && vp check
    vp exec --filter @rey/board-web tsc --noEmit
    cd apps/board-web && vp test run

# Build the Zig API with every static frontend asset embedded.
build:
    zig build board

# Serve an explicitly provisioned installation.
run config: build
    zig-out/bin/board {{quote(config)}}

# Prove bounded auth, scopes, embedded delivery, retention and failure handling.
test:
    zig build test-board-unit test-board

# Install the pinned Playwright Chromium used by browser qualification.
browser-install:
    vp exec --filter @rey/board-web playwright install chromium

# Exercise the real embedded UI against an isolated disk-backed Transit node.
browser:
    zig build test-board -Dboard-browser=true

# Open a disposable counter realm for interactive inspection; Ctrl-C cleans it up.
demo: build
    zig build apps examples
    python3 -B examples/local.py counter --board

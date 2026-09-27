set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --list transit-board

# Install the locked frontend build and test dependencies with Vite+.
install:
    vp install --frozen-lockfile

# Regenerate Board's OpenAPI, TypeScript types, and CSP-compatible validators.
generate:
    zig build transit-board-contract > contracts/transit-board-v1.openapi.json
    python3 -B packages/ts/transit-board-client/generate.py
    vp exec node packages/ts/transit-board-client/validators.mjs

# Check typed contract and generated browser-resource drift.
contract:
    zig build transit-board-contract | python3 -B tests/board_contract.py
    python3 -B packages/ts/transit-board-client/generate.py --check
    vp exec node packages/ts/transit-board-client/validators.mjs --check

# Check frontend formatting, lint, strict types and unit tests.
check: contract
    cd packages/ts/transit-board-client && vp check
    cd apps/transit-board-web && vp check
    vp exec --filter @rey/transit-board-web tsc --noEmit
    cd apps/transit-board-web && vp test run

# Format frontend source and Markdown; generated contracts have their own recipe.
fmt:
    cd packages/ts/transit-board-client && vp fmt
    cd apps/transit-board-web && vp fmt

# Build the Zig API with every static frontend asset embedded.
build:
    zig build transit-board

# Serve an explicitly provisioned installation.
run config: build
    zig-out/bin/transit-board {{quote(config)}}

# Prove private access, upstream scopes, embedded delivery, retention and failures.
test:
    zig build test-transit-board-unit test-transit-board

# Install the pinned Playwright Chromium used by browser qualification.
browser-install:
    vp exec --filter @rey/transit-board-web playwright install chromium

# Exercise the real embedded UI against an isolated disk-backed Transit node.
browser:
    zig build test-transit-board -Dtransit-board-browser=true

# Open a disposable counter realm for interactive inspection; Ctrl-C cleans it up.
demo: build
    zig build apps examples
    python3 -B examples/local.py counter --board

# Qualify the optional growing query API against real hosts and disk Ursula.
query-test:
    zig build test-board-query

# Qualify the real growing atlas/workspace, typed results and live revocation.
query-browser:
    zig build test-board-query -Dquery-browser=true

# Inspect real HTTP captures, scoped metadata pages and revoked continuations.
http-test:
    zig build test-http-worker -Dhttp-board=true

# Exercise the embedded exchange inspector and clearing after read revocation.
http-browser:
    zig build test-http-worker -Dhttp-board-browser=true

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
    zig build serving-api
    zig-out/bin/transit-serving-api client > packages/zig/transit-serving/api/client.json
    python3 -B packages/ts/transit-reactive-client/generate.py
    vp exec node packages/ts/transit-reactive-client/validators.mjs
    zig build transit-app
    zig-out/bin/transit-app schema > packages/zig/transit-station-app/api/application.schema.json
    python3 -B packages/ts/transit-application/generate.py
    vp exec node packages/ts/transit-application/validators.mjs

# Check typed contract and generated browser-resource drift.
contract:
    zig build transit-board-contract | python3 -B tests/board_contract.py
    python3 -B packages/ts/transit-board-client/generate.py --check
    vp exec node packages/ts/transit-board-client/validators.mjs --check
    zig build serving-api
    python3 -B tests/reactive_client_contract.py zig-out/bin/transit-serving-api
    python3 -B packages/ts/transit-reactive-client/generate.py --check
    vp exec node packages/ts/transit-reactive-client/validators.mjs --check
    zig build transit-app
    python3 -B tests/application_schema.py zig-out/bin/transit-app
    python3 -B packages/ts/transit-application/generate.py --check
    vp exec node packages/ts/transit-application/validators.mjs --check

# Check frontend formatting, lint, strict types and unit tests.
check: contract
    cd packages/ts/transit-board-client && vp check
    cd packages/ts/transit-reactive-client && vp check
    cd packages/ts/transit-application && vp check
    cd packages/ts/transit-application && vp exec tsc --noEmit
    cd packages/ts/transit-application && vp test run
    cd apps/transit-board-web && vp check
    vp exec --filter @rey/transit-board-web tsc --noEmit
    cd apps/transit-board-web && vp test run
    cd examples/serving/web && vp check
    cd examples/serving/web && vp exec tsc --noEmit

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

# Inspect all four RPC shapes and current authorization over real captured data.
grpc-test:
    zig build test-grpc-worker -Dgrpc-board=true

grpc-browser:
    zig build test-grpc-worker -Dgrpc-board-browser=true

# Accepted Document metadata with source cuts, current grants and retained gaps.
document-test:
    zig build transit-node rey-cli transit-station-document-worker example-station-document transit-board
    python3 -B examples/station-document/run.py --board

# Real embedded metadata view and clearing after current read revocation.
document-browser:
    zig build transit-node rey-cli transit-station-document-worker example-station-document transit-board
    python3 -B examples/station-document/run.py --browser

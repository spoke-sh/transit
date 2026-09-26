set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list test

# Run unit and protocol checks without a service.
unit:
    zig build test

# Independent HTTP/TLS peers; exact single sends, bounded capture and failure.
http-transport:
    zig build test-http-transport

# Actual finite worker with disk capture, lost receipts and killed executor.
http-worker:
    zig build test-http-worker

# Compile application/probe entry points independently of fast library tests.
build:
    zig build test-build

# Replay saved regressions and deterministic generated authority schedules.
properties *args:
    zig build test-properties -- {{args}}

# Run finite codec regressions; optional Zig fuzz iteration budget.
codecs *args:
    zig build test-codecs {{args}}

# Finite offered-load, control latency and state-drain measurements (owned storage).
growing-load *args:
    zig build test-growing-load -- {{args}}

# Repeated single-authority growth/load matrix with an owned S3-compatible tier.
scale *args:
    zig build test-scale -- {{args}}

# Bounded formal exploration and negative controls; tools use the locked nixpkgs.
model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command zig build test-model -- {{args}}

# Bounded TLC safety check of the growing result delivery/credit model. Type
# and safety invariants only; no guard mutants or Zig trace replay yet, unlike
# `model` above.
model-delivery:
    nix shell --inputs-from . nixpkgs#tlaplus --command tlc -workers 1 -seed 1 -fp 0 \
        -config tests/verification/models/Delivery.cfg tests/verification/models/Delivery.tla

# Committed HEAD only: omit selected real guards in isolated clones.
mutations:
    python3 -B tests/verification/mutations.py

# Qualify finite IPC schemas/values against an independent Arrow reader.
arrow:
    zig build test-arrow

# Prove the generated C ABI and exact retry after a foreign host exits.
client-abi:
    zig build test-client-abi

# Exercise the real Station example with a disk-backed authority and courier.
station:
    zig build test-station

# Check each library using its own declared dependencies.
packages:
    cd packages/zig/transit-exchange && zig build test
    cd packages/zig/transit-station-http && zig build test
    cd packages/zig/transit-query && zig build test
    cd packages/zig/transit-station && zig build test
    cd packages/zig/transit-fuze && zig build test
    cd packages/zig/transit-observability && zig build test
    cd packages/zig/telemetry && zig build test
    cd packages/zig/transit-board-api && zig build test
    cd packages/zig/transit-protocol && zig build test
    cd packages/zig/transit-core && zig build test
    cd packages/zig/transit-backend-ursula && zig build test
    cd packages/zig/transit-client && zig build test
    cd packages/zig/transit-runtime-substrate && zig build test

# Compile each library independently; root unit checks own shared test execution.
packages-build:
    cd packages/zig/transit-exchange && zig build check
    cd packages/zig/transit-station-http && zig build check
    cd packages/zig/transit-query && zig build check
    cd packages/zig/transit-station && zig build check
    cd packages/zig/transit-fuze && zig build check
    cd packages/zig/transit-observability && zig build check
    cd packages/zig/telemetry && zig build check
    cd packages/zig/transit-board-api && zig build check
    cd packages/zig/transit-protocol && zig build check
    cd packages/zig/transit-core && zig build check
    cd packages/zig/transit-backend-ursula && zig build check
    cd packages/zig/transit-client && zig build check
    cd packages/zig/transit-runtime-substrate && zig build check

# Run the upstream compute tests absent from the root library suite.
compute:
    cd packages/zig/transit-fuze && zig build test-compute

# Run isolated persistent Ursula tests, including SIGKILL and restart.
storage:
    zig build test-storage

# Exercise signed HTTP ingress and worker recovery against isolated disk Ursula.
service:
    zig build test-service

# Exercise independent Zig callers against the same generic authority.
callers:
    zig build test-callers

# Linux/Docker: fill an owned ext4 image while keeping a physical control reserve.
capacity:
    zig build capacity-proof
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/capacity.py zig-out/bin/transit-capacity-proof

# Linux/Docker: retain growing pages/backlog through real ENOSPC and reserve use.
growing-capacity:
    zig build growing-capacity-proof
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/capacity.py zig-out/bin/transit-growing-capacity-proof --growing

# Exercise bounded discovery and retained inspection through the public client.
inspection:
    zig build test-inspection

# Prove authorized state reads and atomic KV commits through the public service.
state:
    zig build test-state

# Qualify the M10 immutable page primitive; not a new public state profile.
pages *args:
    zig build test-pages -- {{args}}

# Linux/Docker: qualify packed pages with persistent S3-compatible cold storage.
pages-cold *args:
    zig build test-pages -- --cold-s3 {{args}}

# Prove v3 authority publication with retained views/receipts and disk restart.
growing *args:
    zig build test-growing -- {{args}}

# Exercise the explicit v3 node/client profile and lost replies on one CPU.
growing-service:
    zig build test-growing-service

# Focus service/Station quota refusal and reserved control progress after restart.
growing-quota:
    zig build test-growing-quota

# Focus incremental Arrow capture, lost receipts and two disk recovery boundaries.
[positional-arguments]
growing-query *args:
    zig build test-growing-query -- "$@"

# Run the same growing service/fault corpus with optimized safety checks.
growing-service-release:
    zig build test-growing-service -Doptimize=ReleaseSafe

# Focus Station growth/recovery without rerunning unrelated service scenarios.
[positional-arguments]
growing-station *args:
    zig build test-growing-station -- "$@"

# Qualify larger immutable records, current access and bounded cleanup over disk Ursula.
publication:
    zig build test-publication

# Prove bounded diagnostics, independent metrics and cancelable log sinks.
telemetry:
    zig build test-telemetry

# Prove Board/client/node correlation and protocol-aware diagnostic outcomes.
observability:
    zig build test-observability

# Render and validate the Transit Helm chart without a cluster.
deployments:
    python3 -B tests/deployments.py

# Verify checkout-local Kubernetes selection without contacting a cluster.
dev-environment:
    python3 -B tests/dev_environment.py

# Prove the inspection plugin's CLI, subprocess and credential boundaries offline.
kubectl-transit:
    zig build test-kubectl-transit

# Prove fenced workload changes and recovery after a lost provider response.
runtime-upgrade:
    zig build test-runtime-upgrade

# Generate/check the reference grammar and compare its covered AST with Postgres.
sql-grammar:
    nix shell .#sql-tools --command python3 -B tests/sql/grammar.py

# Type-check the named rewrite theorems and reject incomplete proofs.
sql-rewrites:
    nix shell .#sql-tools --command python3 -B tests/sql/rewrites.py

# Full reference/production AST, real plan and paged Arrow execution proof.
sql:
    nix shell .#sql-tools --command zig build test-sql

# Real signed query shell, growing workers, exact retry and current read rights.
public-query:
    zig build test-public-query

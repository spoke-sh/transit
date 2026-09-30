set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list test

# Run unit and protocol checks without a service.
unit:
    zig build test

# Independent HTTP/TLS peers; exact single sends, bounded capture and failure.
tls-alpn:
    zig build test-tls-alpn

grpc-libraries:
    cd third_party/zig-libs && zig build test-rpc

grpc-transport:
    zig build test-grpc-transport

grpc-server:
    nix develop .#flight --command zig build test-grpc-server

grpc-worker:
    zig build test-grpc-worker

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
    cd packages/zig/transit-flight && zig build test
    cd packages/zig/transit-station-flight && zig build test
    cd packages/zig/transit-serving-http && zig build test
    cd packages/zig/transit-http-server && zig build test
    cd packages/zig/transit-station-app && zig build test
    cd packages/zig/transit-serving && zig build test
    cd packages/zig/transit-station-document && zig build test
    cd packages/zig/transit-station-grpc && zig build test
    cd packages/zig/transit-grpc && zig build test
    cd packages/zig/transit-tls && zig build test
    cd packages/zig/transit-station-bindings && zig build test
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
    cd packages/zig/transit-flight && zig build check
    cd packages/zig/transit-station-flight && zig build check
    cd packages/zig/transit-serving-http && zig build check
    cd packages/zig/transit-http-server && zig build check
    cd packages/zig/transit-station-app && zig build check
    cd packages/zig/transit-serving && zig build check
    cd packages/zig/transit-station-document && zig build check
    cd packages/zig/transit-station-grpc && zig build check
    cd packages/zig/transit-grpc && zig build check
    cd packages/zig/transit-tls && zig build check
    cd packages/zig/transit-station-bindings && zig build check
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
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/capacity.py zig-out/bin/transit-capacity-proof --growing

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
query *args:
    zig build test-query -- "$@"

# Run the same growing service/fault corpus with optimized safety checks.
growing-service-release:
    zig build test-growing-service -Doptimize=ReleaseSafe

# Focus Station growth/recovery without rerunning unrelated service scenarios.
[positional-arguments]
growing-station *args:
    zig build test-growing-station -- "$@"

# Qualify Document jobs, checkpoint recovery and current-policy reads over disk Ursula.
document:
    zig build test-document

# Run the real Document writer and two Zig editors through failure and resynchronization.
document-remote:
    just examples::document

# Conditional application publication with signed operators, lost replies and disk recovery.
application:
    zig build test-application -Doptimize=ReleaseSafe

# Actual non-trading Table migration worker and disk recovery.
work-items:
    zig build test-work-items -Doptimize=ReleaseSafe

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

# Independent application grammar/model and actual compiler round-trip.
application-grammar:
    zig build transit-app
    nix shell .#sql-tools --command python3 -B tests/application_grammar.py

# Type-check the named rewrite theorems and reject incomplete proofs.
sql-rewrites:
    nix shell .#sql-tools --command python3 -B tests/sql/rewrites.py

# Full reference/production AST, real plan and paged Arrow execution proof.
sql:
    nix shell .#sql-tools --command zig build test-sql

# Real signed query shell, growing workers, exact retry and current read rights.
public-query:
    zig build test-public-query

# Signed v2 upload, all source adapters, nested results and disk recovery.
unified-query *args="-Doptimize=ReleaseSafe":
    zig build test-unified-query {{args}}

# Shared inbound HTTP framing, bounded concurrency and joined cancellation.
serving-http:
    zig build test-serving-http -Doptimize=ReleaseSafe

# Signed HTTP gateway/Station admission, isolated disk restart and current reads.
serving:
    zig build test-serving -Doptimize=ReleaseSafe

# Same service admission/recovery through pinned nginx HTTPS termination.
serving-tls:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-tls=true

# Linux: aggregate resident memory and health progress through the real TLS proxy.
serving-capacity:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-tls=true -Dserving-capacity=true

# Finite waits, durable cancellation, duplicate/late timeouts and hard expiry.
serving-lifetimes:
    zig build test-serving -Doptimize=ReleaseSafe -Dserving-lifetimes=true

# Bounded point reads and retained operations beyond the resident-page budget.
serving-growth:
    zig build test-serving -Doptimize=ReleaseSafe -Dserving-growth=true

# Explicit SQL shell and separately authorized Board query API/browser.
unified-ingress source="table":
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-shell=true -Dunified-board=true -Dunified-browser=true

# Actual versioned console on disk-backed native query workers.
console source="table":
    nix develop .#serving --command zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-console=true -Dunified-console-tls=true

# Real command diagnostics, configuration locations and stderr/privacy boundaries.
cli-diagnostics:
    zig build test-cli-diagnostics

# Measure the default local empty Table with consistently optimized executables.
console-latency *args:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe --prefix .cache/transit-latency/release
    python3 -B tests/console_latency.py .cache/transit-latency/release/bin/transit .cache/transit-latency/release/bin/transit-node .cache/transit-latency/release/bin/transit-query-host {{args}}

# Leased native snapshots and real finite Fuze/Arrow execution for all sources.
interactive-query *args:
    zig build transit transit-node unified-query-proof -Doptimize=ReleaseSafe --prefix .cache/transit-interactive
    python3 -B tests/interactive_query.py .cache/transit-interactive/bin/transit-node .cache/transit-interactive/bin/transit-unified-query-proof .cache/transit-interactive/bin/transit {{args}}

# Actual native server with independent console and owned process failures.
server:
    zig build test-server -Doptimize=ReleaseSafe

server-faults:
    zig build test-server -Doptimize=ReleaseSafe -Dserver-faults=true

# Linux/Docker: real ENOSPC inside one newly allocated ext4 image.
server-capacity:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/server_capacity.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host

# Current grant changes/cancellation after a durable segment staging decision.
unified-lifecycle source="kv":
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-lifecycle=true

# Real opted-in request lifetime, complete/prefix reads and disk restart.
unified-expiry source="kv":
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-expiry=true

# Independent v2 bundle and Arrow fixtures through native and port APIs.
unified-codec:
    zig build test-unified-codec

# Qualify RPC preparation, dispatch, final publication and blocked-peer control.
grpc-faults:
    zig build test-grpc-worker -Dgrpc-faults=true

# Generate and compile durable request helpers without sockets or reflection.
grpc-codegen:
    zig build test-grpc-codegen

# M20: independent TLS SSE/WebSocket, lifecycle and full native recovery peers.
reactive:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true

# Actual Chromium/WebCrypto plus independent peer recovery; loopback fixture permission only.
reactive-browser:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-browser=true

# Full data pool, reserved controls, malformed frames, resume rejection and hard expiry.
reactive-limits:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-limits=true

# Owned private placement, TLS peers and physical stack recovery.
reactive-placement profile="compose":
    nix develop .#serving --command python3 -B examples/serving/run.py --profile {{profile}} --reactive

# Rebuild descriptions and check the pinned offline specifications and drift.
reactive-descriptions:
    zig build serving-api -Doptimize=ReleaseSafe
    python3 -B tests/reactive_descriptions.py zig-out/bin/transit-serving-api

# Qualify the shared Zig caller and private host adapter over real TLS and disk.
reactive-client:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-client=true

# Real shared requester, fair finite refresh and current grant recovery.
reactive-refresh:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-refresh=true

# Real Board/counter browser consumers against the durable refresh owner.
reactive-views:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-views=true

# Actual browser consumers and durable result recovery in owned placements.
reactive-views-placement profile:
    zig build serving-example transit-query-host -Doptimize=ReleaseSafe
    nix develop .#serving --command python3 -B examples/serving/run.py --profile {{quote(profile)}} --views

reactive-views-lifecycle:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-views-lifecycle=true

# Pinned standard protobuf declarations and independent Arrow metadata consumer.
flight-metadata:
    nix develop .#flight --command python3 -B packages/zig/transit-flight/generate.py --check
    nix develop .#flight --command zig build test-flight-metadata -Doptimize=ReleaseSafe

# Real finite native queries over verified TLS with pinned Python and C consumers.
flight:
    nix develop .#flight --command zig build test-flight -Doptimize=ReleaseSafe

flight-faults:
    nix develop .#flight --command zig build test-flight -Doptimize=ReleaseSafe -Dflight-faults=true

flight-placement profile:
    nix develop .#flight --command zig build test-flight -Doptimize=ReleaseSafe -Dflight-placement={{quote(profile)}}

flight-outbound:
    nix develop .#flight --command zig build test-flight-outbound -Doptimize=ReleaseSafe

# Embedded application editor, real operator signatures and recovery.
application-browser:
    zig build test-application-browser -Doptimize=ReleaseSafe

# Generated standalone application, migration and native query recovery.
work-items-browser:
    zig build test-work-items-browser -Doptimize=ReleaseSafe

# Generated work-item application with real physical owners and browser recovery.
work-items-placement profile="compose":
    zig build work-items-browser-proof transit-query-host -Doptimize=ReleaseSafe
    nix develop .#serving --command python3 -B examples/work-items/placed.py {{quote(profile)}}

# Separately compiled consumer, scoped installation and disk-backed replacement.
server-applications:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/server_applications.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Lost native and migration replies, current revocation and management admission.
server-application-faults:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/server_application_faults.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Accepted application input across real ENOSPC in an owned ext4 image.
server-application-capacity:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/server_capacity.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Default embedded Board, retained inspection grants and local UI recovery.
server-board:
    zig build transit transit-node transit-query-host transit-board -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/server_board.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host zig-out/bin/transit-board examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Downstream-consumable closure and manifest, with no source-runtime dependencies.
server-board-package:
    nix build .#transit-local --out-link .cache/transit-board-package
    python3 -B tests/server_board_package.py .cache/transit-board-package

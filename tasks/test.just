set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := ".."

[default]
_default:
    @just --list test

# Verified segment metadata/page ranges and the disk-backed direct Table reader.
storage-segments:
    cd packages/zig/transit-fuze && zig build test -Dtest-filter=TSeg -Dtest-filter="column" -Dtest-filter="bound borrowing" --summary all
    cd packages/zig/transit-storage && zig build test -Dtest-filter="Table segment ranges" --summary all

# Real process death at WAL append/fence/trim and object publication boundaries.
local-storage-faults:
    zig build test-local-storage-faults -Doptimize=ReleaseSafe

# Paired disk owner measurements; explicit output, raw samples and value oracles.
[positional-arguments]
[script]
storage-benchmark *args:
    #!/usr/bin/env bash
    set -euo pipefail
    zig build storage-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/storage/storage_benchmark.py zig-out/bin/transit-storage-benchmark "$@"

# Matched WAL/bulk ingestion, native turn commit and independent reopen readback.
[positional-arguments]
[script]
storage-ingest-benchmark *args:
    #!/usr/bin/env bash
    set -euo pipefail
    zig build storage-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/storage/storage_ingest_benchmark.py zig-out/bin/transit-storage-benchmark "$@"

# Table/native growth with 16 KiB values and a hard process memory ceiling.
[positional-arguments]
[script]
storage-growth *args:
    #!/usr/bin/env bash
    set -euo pipefail
    zig build storage-benchmark -Doptimize=ReleaseSafe -Dstorage-benchmark-body-bytes=16384 --prefix .cache/storage-growth
    python3 -B tests/runner/launch.py tests/storage/local/storage_growth.py .cache/storage-growth/bin/transit-storage-benchmark "$@"

# Accepted Table archives, retained reads, current authority and interrupted trim.
table-archives:
    cd packages/zig/transit-storage && zig build test -Dtest-filter="Table archive" -Dtest-filter="Table recovery rejects archive" -Dtest-filter="Table admitted work survives" --summary all
    cd packages/zig/transit-backend-local && zig build test -Dtest-filter="direct Table archive" -Dtest-filter="direct data acceptance" --summary all
    just test::local-storage-faults

# Accepted bounded restart baselines, original evidence and publication crashes.
table-checkpoints:
    cd packages/zig/transit-storage && zig build test -Dtest-filter="Table recovery checkpoint" -Dtest-filter="Table admitted work survives" -Dtest-filter="Table history floor" -Dtest-filter="Table compact evidence" -Dtest-filter="Table storage walk" -Dtest-filter="Table retained root enumeration" --summary all
    cd packages/zig/transit-backend-local && zig build test -Dtest-filter="direct Table archive" --summary all
    just test::local-storage-faults

# Explicit private allocation ceilings across Table mutation/maintenance builders.
table-build-memory:
    cd packages/zig/transit-fuze && zig build test -Dtest-filter="memory budget" --summary all
    cd packages/zig/transit-storage && zig build test -Dtest-filter="Table build memory" -Dtest-filter="frozen SQL" -Dtest-filter="Table ALTER" -Dtest-filter="Table definition acceptance makes" -Dtest-filter="Table admitted work survives" --summary all
    just test::local-storage-faults

# Bounded live-row segment consolidation and exact retained roots after restart.
table-compaction:
    cd packages/zig/transit-storage && zig build test -Dtest-filter="Table compaction" -Dtest-filter="Table segment ranges" -Dtest-filter="Table index batches" --summary all
    cd packages/zig/transit-backend-local && zig build test -Dtest-filter="direct Table archive" --summary all
    just test::local-storage-faults

# Real process death during native object deletion and allocation FIFO progress.
local-native-collection:
    zig build test-local-native
    zig build test-local-native-collection-faults -Doptimize=ReleaseSafe

# Disk owner error propagation with real partial writes and injected syscall failures.
storage-io-faults:
    cd packages/zig/transit-storage && zig build test -Dtest-filter="disk space errors" -Dtest-filter="disk sync errors" -Dtest-filter="disk recovery syncs complete" -Dtest-filter="disk opening syncs observed metadata" -Dtest-filter="object write errors" -Dtest-filter="object publication sync failures" --summary all

# Full-key pages, retained intervals, collation order, signing and owned decoding.
storage-key-ranges:
    cd packages/zig/transit-storage && zig build test -Dtest-filter="ordered full key" -Dtest-filter="Table index batches" -Dtest-filter="retained Table key ranges" -Dtest-filter="Table recovery" -Dtest-filter="Table segment ranges" --summary all
    cd packages/zig/transit-catalog && zig build test -Dtest-filter="retained key range" -Dtest-filter="retained reader binds" --summary all

# Finite count intervals, same-pin scan controls and post-compute disclosure.
table-count-ranges:
    cd packages/zig/transit-query-direct && zig build test -Dtest-filter="count range" --summary all
    just test::direct-table-service count-ranges

# Projected segment pages, retained wire cursors and finite signed SQL reads.
table-projection:
    cd packages/zig/transit-fuze && zig build test -Dtest-filter="Table projection" --summary all
    cd packages/zig/transit-storage && zig build test -Dtest-filter="projected Table snapshots" --summary all
    cd packages/zig/transit-catalog && zig build test -Dtest-filter="retained column scan" -Dtest-filter="retained reader binds" --summary all
    just test::direct-table-service projection

# Encoded decisions, retained visibility, empty coverage and owned output.
table-filtering:
    cd packages/zig/transit-fuze && zig build test -Dtest-filter="TSeg" --summary all
    cd packages/zig/transit-storage && zig build test -Dtest-filter="filtered Table" -Dtest-filter="projected Table snapshots" --summary all
    cd packages/zig/transit-catalog && zig build test -Dtest-filter="retained filter" -Dtest-filter="retained reader" --summary all
    just test::direct-table-service projection

# Independent provider stalls, exact publication races and current revocation.
node-concurrency:
    zig build test-node-concurrency -Doptimize=ReleaseSafe

# Real local native node and signed caller faults, with no external store.
local-native-service:
    zig build test-local-native-service

# Real local owner reopen after physical disk sync outcomes are lost.
local-owner-recovery:
    zig build test-local-owner-recovery -Doptimize=ReleaseSafe

# Authenticated standalone payload bytes, recovery and native maintenance.
local-payload-service:
    zig build test-local-payload-service -Doptimize=ReleaseSafe

# Verify direct catalog lifecycle against signed native registration and policy.
local-catalog:
    zig build test-local-catalog

# Explicit Table expiry, retained snapshots and original receipts after collection.
local-data-collection:
    zig build test-local-data-collection
    zig build test-local-data-collection-faults -Doptimize=ReleaseSafe

# Real direct Table HTTP owner, typed caller, disk restart and uncertain replies.
direct-table-service *args:
    zig build test-direct-table-service -Doptimize=ReleaseSafe -- {{args}}

# Automatic Table flushing on physical disk, with original and new retained cuts.
direct-table-maintenance:
    zig build test-direct-table-maintenance -Doptimize=ReleaseSafe

# Focused shared host preparation, saved work and explicit direct operations.
direct-table-callers:
    zig build test-direct-table-callers -Doptimize=ReleaseSafe

direct-catalog-abi:
    zig build test-direct-catalog-abi -Doptimize=ReleaseSafe

direct-dependencies:
    zig build test-direct-dependencies -Doptimize=ReleaseSafe
    just test::direct-table-service dependency-growth

direct-named-resources:
    zig build test-direct-named-resources -Doptimize=ReleaseSafe
    just test::direct-table-service resource-growth

# Public retained direct Table capture with independent native progress and restart.
direct-captured-query *args:
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- {{args}}

# Prepared direct Table refresh, native selection, node restart and fresh output.
direct-follow-query:
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --follow-only

# Separate named publication, caller grants and explicit direct Table activation.
direct-named-query:
    zig build test-direct-captured-query -Doptimize=ReleaseSafe -- --named-only

# Primitive bytes/index proof; native authority and SQL integration are separate.
block-storage:
    zig build test-block-storage -Doptimize=ReleaseSafe

# Epoch fencing, retained roots, relocation and physical deletion across restart.
storage-collection:
    zig build test-storage-collection -Doptimize=ReleaseSafe

# Atomic native block roots, retained bytes and current authority through faults.
native-blocks:
    zig build test-native-blocks -Doptimize=ReleaseSafe

# Independent pinned database clients, TLS/authentication and prepared cycles.
sql-wire-reference:
    nix develop .#sql-wire --command python3 -B tests/runner/launch.py tests/interfaces/sql_wire/reference.py

sql-wire-tls:
    nix develop .#sql-wire --command bash -euc 'cd packages/zig/transit-tls-server; zig build test probe --prefix ../../../zig-out/sql-wire-tls'
    nix develop .#sql-wire --command python3 -B tests/runner/launch.py tests/interfaces/sql_wire/tls.py zig-out/sql-wire-tls/bin/transit-tls-server-probe

# Shared byte/credential primitives; independent Python oracle and Zig owners.
sql-wire-contracts:
    python3 -B tests/runner/launch.py tests/interfaces/sql_wire/contracts.py
    cd packages/zig/transit-sql-results && zig build test
    cd packages/zig/transit-sql-protocol && zig build test
    cd packages/zig/transit-sql-client && zig build test
    cd packages/zig/transit-sql && zig build test
    cd packages/zig/transit-sql-service && zig build test
    cd packages/zig/transit-postgres && zig build test
    cd packages/zig/transit-mysql && zig build test

# Catalog-owned SQL recovery, exact Table outcomes and fenced replacement.
sql-gateway:
    zig build test-sql-gateway -Doptimize=ReleaseSafe

# Independent HTTPS/SCRAM sessions, logical values and token recovery.
sql-sessions:
    nix develop .#sql-wire --command zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- sessions

sql-wire-gateway:
    nix develop .#sql-wire --command zig build test-sql-wire-gateway -Doptimize=ReleaseSafe

# Framed row costs without TLS/native/storage work; also runs before the gateway proof.
sql-wire-encoding:
    zig build test-sql-wire-encoding -Doptimize=ReleaseSafe

# Shared-client allocations across independent Unix, HTTP and TLS peers.
sql-result-allocations:
    zig build test-sql-result-allocations -Doptimize=ReleaseSafe

sql-wire-placement profile:
    nix develop .#sql-wire --command zig build test-sql-wire-placement -Doptimize=ReleaseSafe -Dsql-wire-placement={{quote(profile)}}

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

# Seeded multi-process delivery, live/cold correspondence and bounded progress.
simulation *args:
    zig build test-simulation -- {{args}}

# Committed HEAD only: qualify delivery oracles against compiling core mutants.
simulation-mutations:
    python3 -B tests/runner/launch.py tests/verification/mutations/mutations.py --simulation

# Small saved storage fault regression corpus.
resource-simulation-smoke:
    zig build test-resource-simulation -- --smoke

# Compiling core mutations for atomic resource/input publication.
resource-simulation-mutations:
    python3 -B tests/runner/launch.py tests/verification/mutations/mutations.py --resource

# Numbered page/journal faults, captured roots and checkpoint recovery.
resource-simulation *args:
    zig build test-resource-simulation -- {{args}}


# Run finite codec regressions; optional Zig fuzz iteration budget.
codecs *args:
    zig build test-codecs {{args}}

# Finite offered-load, control latency and state-drain measurements (owned storage).
growing-load *args:
    zig build test-growing-load -Doptimize=ReleaseSafe -- {{args}}

# Repeated single-authority growth/load matrix with an owned S3-compatible tier.
scale *args:
    zig build test-scale -- {{args}}

# Bounded formal exploration and negative controls; tools use the locked nixpkgs.
model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command zig build test-model -- {{args}}

# Local WAL durability ordering, bounded exhaustive safety and six negative controls.
wal-model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command python3 -B tests/runner/launch.py tests/verification/models/wal_model.py {{args}}

# One original transaction decision, bounded safety and six negative controls.
transaction-decision-model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command python3 -B tests/runner/launch.py tests/verification/models/transaction_decision_model.py {{args}}

# Durable write lifecycle/token models and selected production Table trace replay.
write-lifecycle-model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command zig build test-write-lifecycle-model -- {{args}}

# Finite editor model, every exported edge replayed against production Zig,
# removed-guard controls and borrower release under explicit fairness.
console-model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command zig build test-console-model -- {{args}}

# Finite SQL result progress/retry/disclosure models and production Progress replay.
statement-result-model *args:
    nix shell --inputs-from . nixpkgs#tlaplus --command zig build test-statement-result-model -- {{args}}

# Bounded TLC safety check of the growing result delivery/credit model. Type
# and safety invariants only; no guard mutants or Zig trace replay yet, unlike
# `model` above.
model-delivery:
    nix shell --inputs-from . nixpkgs#tlaplus --command tlc -workers 1 -seed 1 -fp 0 \
        -config tests/verification/models/Delivery.cfg tests/verification/models/Delivery.tla

# Committed HEAD only: omit selected real guards in isolated clones.
mutations:
    python3 -B tests/runner/launch.py tests/verification/mutations/mutations.py

# Qualify finite IPC schemas/values against an independent Arrow reader.
arrow:
    zig build test-arrow

# Prove the generated C ABI and exact retry after a foreign host exits.
client-abi:
    zig build test-client-abi

# Keep Debug Station callers and a ReleaseSafe disk-backed authority, matching
# the SDK query profile without changing the finite progress deadlines.
station:
    zig build transit-admin example-station-ledger transit-delivery transit-station-controller
    zig build transit-node -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/runtime/station/station.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/bin/example-station-ledger zig-out/bin/transit-delivery zig-out/bin/transit-station-controller

# Check each library using its own declared dependencies.
packages:
    cd packages/zig/transit-memory && zig build test
    cd packages/zig/transit-io && zig build test
    cd packages/zig/transit-config && zig build test
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
    cd packages/zig/transit-tls-server && zig build test
    cd packages/zig/transit-sql-results && zig build test
    cd packages/zig/transit-sql-protocol && zig build test
    cd packages/zig/transit-sql-client && zig build test
    cd packages/zig/transit-sql && zig build test
    cd packages/zig/transit-sql-service && zig build test
    cd packages/zig/transit-postgres && zig build test
    cd packages/zig/transit-mysql && zig build test
    cd packages/zig/transit-station-bindings && zig build test
    cd packages/zig/transit-exchange && zig build test
    cd packages/zig/transit-station-http && zig build test
    cd packages/zig/transit-query-direct && zig build test
    cd packages/zig/transit-query && zig build test
    cd packages/zig/transit-catalog && zig build test
    cd packages/zig/transit-station && zig build test
    cd packages/zig/transit-storage && zig build test
    cd packages/zig/transit-fuze && zig build test
    cd packages/zig/transit-observability && zig build test
    cd packages/zig/telemetry && zig build test
    cd packages/zig/transit-board-api && zig build test
    cd packages/zig/transit-protocol && zig build test
    cd packages/zig/transit-core && zig build test
    cd packages/zig/transit-backend-ursula && zig build test
    cd packages/zig/transit-backend-local && zig build test
    cd packages/zig/transit-client && zig build test
    cd packages/zig/transit-runtime-substrate && zig build test

# Compile each manifest independently; optional bounded parallelism (1..4).
[positional-arguments]
packages-build jobs="2":
    python3 -B tests/runner/packages.py --jobs "$1"

# Run the upstream compute tests absent from the root library suite.
compute:
    cd packages/zig/transit-fuze && zig build test-compute

# Run isolated persistent Ursula tests, including SIGKILL and restart.
storage:
    zig build test-storage

# Exercise signed HTTP ingress and worker recovery against isolated disk Ursula.
service:
    zig build test-service

# Signed policy staging, current checks and restart against disk-backed Ursula.
authorization:
    zig build transit-node transit-admin
    python3 -B tests/runner/launch.py tests/catalog/authorization/authorization_native.py zig-out/bin/transit-node zig-out/bin/transit-admin --report .cache/verification/authorization-native.json

# Public administration CLI and neutral C/host lifecycle, with disk restart.
authorization-cli:
    zig build test-operation-fixture transit-node transit-admin transit client-abi transit-client-host
    python3 -B tests/runner/launch.py tests/interfaces/cli/authorization_cli.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/bin/transit zig-out/lib/libtransit_client.so zig-out/bin/transit-client-host --report .cache/verification/authorization-cli.json

# Current Table roles, SQL defaults, filtered metadata and retained-cut denial.
authorization-tables:
    just test::direct-table-service authorization

# Restricted serving snapshots and exact control recovery under current roles.
authorization-serving:
    zig build transit-node transit-admin transit-station-host serving-example -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/interfaces/http/authorization_serving.py zig-out/bin/transit-node zig-out/bin/transit-admin zig-out/bin/transit-station-host zig-out/bin/transit-serving-example --report .cache/verification/authorization-serving.json

# Exercise independent Zig callers against the same generic authority.
callers:
    zig build test-callers

# Linux/Docker: fill an owned ext4 image while keeping a physical control reserve.
capacity:
    zig build capacity-proof
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/runner/launch.py tests/storage/retention/capacity.py zig-out/bin/transit-capacity-proof

# Linux/Docker: retain growing pages/backlog through real ENOSPC and reserve use.
growing-capacity:
    zig build growing-capacity-proof -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/runner/launch.py tests/storage/retention/capacity.py zig-out/bin/transit-growing-capacity-proof

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

# Prove v1 authority publication with retained views/receipts and disk restart.
growing *args:
    zig build test-growing -- {{args}}

# Exercise the explicit v1 node/client profile with optimized safety checks on one CPU.
growing-service:
    zig build test-growing-service -Doptimize=ReleaseSafe

# Read-only retained startup through owned provider connection/availability faults.
node-recovery:
    zig build test-node-recovery -Doptimize=ReleaseSafe

# Focus service/Station quota refusal and reserved control progress after restart.
growing-quota:
    zig build test-growing-quota

# Focus incremental Arrow capture and disk recovery with optimized safety checks.
[positional-arguments]
query *args:
    zig build test-query -Doptimize=ReleaseSafe -- "$@"

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

# Run the same worker/node crash schedule over the local WAL and immutable objects.
document-local:
    zig build test-document -Doptimize=ReleaseSafe -- --backend local

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
    python3 -B tests/runner/launch.py tests/interfaces/deployment/deployments.py

# Verify checkout-local Kubernetes selection without contacting a cluster.
dev-environment:
    python3 -B tests/runner/launch.py tests/interfaces/deployment/dev_environment.py

# Prove the inspection plugin's CLI, subprocess and credential boundaries offline.
kubectl-transit:
    zig build test-kubectl-transit

# Prove fenced workload changes and recovery after a lost provider response.
runtime-upgrade:
    zig build test-runtime-upgrade

# Generate/check the reference grammar and compare its covered AST with Postgres.
sql-grammar:
    nix shell .#sql-tools --command python3 -B tests/runner/launch.py tests/query/sql/grammar.py

# Independent application grammar/model and actual compiler round-trip.
application-grammar:
    zig build transit-app
    nix shell .#sql-tools --command python3 -B tests/runner/launch.py tests/interfaces/installation/application_grammar.py

# Type-check the named rewrite theorems and reject incomplete proofs.
sql-rewrites:
    nix shell --inputs-from . nixpkgs#lean4 --command python3 -B tests/runner/launch.py tests/query/sql/rewrites.py

# Full reference/production AST, real plan and paged Arrow execution proof.
sql:
    nix shell .#sql-tools --command zig build test-sql

# Shared relational parser against independent ANTLR/PostgreSQL trees.
relational-sql:
    nix shell .#sql-tools --command zig build test-relational-sql -Doptimize=ReleaseSafe

# General Table DDL grammar, exact schema bytes and pure evolution semantics.
table-ddl-sql:
    nix shell .#sql-tools --command zig build test-table-ddl-sql -Doptimize=ReleaseSafe

# General Table DML grammar and independently encoded typed intent plans.
table-dml-sql:
    nix shell .#sql-tools --command zig build test-table-dml-sql -Doptimize=ReleaseSafe

# Private fixture retention and direct dependency/resource lifecycle recovery.
catalog:
    python3 -B tests/runner/launch.py tests/catalog/tables/catalog_fixture.py
    just test::direct-dependencies
    just test::direct-named-resources

# Paged direct catalog/rows beyond resident pages, original pins and node restart.
catalog-growth:
    just test::direct-table-service growth

# Complete maintained revisions and independent direct Table deltas on disk.
relational-maintenance:
    just test::direct-captured-query --maintained-only

# Explicit retained relational callers and Board pages over the direct owner.
relational-callers:
    zig build test-relational-callers -Doptimize=ReleaseSafe -Drelational-board=true

# Bounded direct exchanges, process recovery and three independent producers.
relational-exchanges:
    zig build test-relational-exchanges -Doptimize=ReleaseSafe

# Real ext4 ENOSPC during captured checkpoints and accepted exchange work.
relational-capacity:
    zig build relational-capacity-proof -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash nixpkgs#patchelf --command python3 -B tests/runner/launch.py tests/query/execution/relational_capacity.py zig-out/bin/transit-node zig-out/bin/transit-direct-table-proof

# Immutable named definitions, explicit activation and revision recovery on disk.
named-relational:
    python3 -B tests/runner/launch.py tests/query/execution/named_relational_records.py
    zig build test-named-relational -Doptimize=ReleaseSafe

# Direct Table capture and separately authorized native query progress.
table-query-writer:
    zig build test-table-query-writer -Doptimize=ReleaseSafe

# Record pure compiler/engine costs separately from interactive source I/O.
sql-benchmark *args:
    zig build sql-benchmark -Doptimize=safe
    python3 -B tests/runner/launch.py tests/performance/declarative/sql.py zig-out/bin/transit-sql-benchmark {{args}}

# Correctness-checked component measurements and explicit full-suite blockers.
[positional-arguments]
declarative-benchmark *args:
    zig build declarative-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/declarative/run.py zig-out/bin/transit-declarative-benchmark "$@"

# Real signed query shell, growing workers, exact retry and current read rights.
public-query:
    zig build test-public-query -Doptimize=ReleaseSafe

# Signed v1 upload, all source adapters, nested results and disk recovery.
unified-query *args="-Doptimize=ReleaseSafe":
    zig build test-unified-query {{args}}

# Persist partial value counts through replacement, current denial and cancellation.
unified-counts *args="-Doptimize=ReleaseSafe":
    zig build test-unified-query -Dunified-counts=true {{args}}

# Shared inbound HTTP framing, bounded concurrency and joined cancellation.
serving-http:
    zig build test-serving-http -Doptimize=ReleaseSafe

# Typed counter queue, frozen deltas, overflow and private-turn rollback.
serving-counter:
    zig build test-serving-counter -Doptimize=ReleaseSafe

# Signed HTTP admission and application recovery over disk authority.
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

# Real terminal history search, persistence and file failure behavior, offline.
console-history:
    zig build test-console-history

# Real native-session console, independent HTTPS/SCRAM and captured recovery.
# Configured source owners are scheduled within the fixture's native wait budget.
console:
    just test::sql-sessions

# Real command diagnostics, configuration locations and stderr/privacy boundaries.
cli-diagnostics:
    zig build test-cli-diagnostics

# Review changes to public failure owners, outcomes, imports and checked grammar.
diagnostic-inventory:
    python3 -B tests/runner/launch.py tests/interfaces/cli/diagnostic_inventory.py

# Check closed compiler mappings and explicit boundary exceptions independently of inventory recording.
diagnostic-mappings:
    python3 -B tests/runner/launch.py tests/interfaces/cli/diagnostic_mappings.py

# Compiler-inferred finite/open sets and unknown-callback recovery evidence.
diagnostic-errors:
    zig build test-diagnostic-errors

# Execute every declared retained-outcome variant against reviewed semantic mappings.
diagnostic-outcomes:
    zig build test-diagnostic-outcomes

# Reference parser alternatives and reviewed public compiler diagnostics.
diagnostic-grammar:
    zig build diagnostic-grammar
    nix shell .#sql-tools --command python3 -B tests/runner/launch.py tests/interfaces/cli/diagnostic_grammar.py zig-out/bin/transit-diagnostic-grammar

# Measure local empty or seeded finite results with consistently optimized executables.
console-latency *args:
    zig build transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe --prefix .cache/transit-latency/release
    python3 -B tests/runner/launch.py tests/performance/console/console_latency.py .cache/transit-latency/release/bin/transit .cache/transit-latency/release/bin/transit-node .cache/transit-latency/release/bin/transit-query-host {{args}}

# Owned durable writes; requires --output, supports independent history/row controls.
mutation-latency *args:
    zig build transit transit-node transit-query-host transit-board transit-sql-gateway mutation-latency-client -Doptimize=ReleaseSafe --prefix .cache/transit-latency/release
    python3 -B tests/runner/launch.py tests/performance/mutations/mutation_latency.py .cache/transit-latency/release/bin/transit .cache/transit-latency/release/bin/transit-node .cache/transit-latency/release/bin/transit-query-host {{args}}

# Native-session snapshot execution, typed values and retained source basis.
interactive-query:
    just test::sql-sessions

# Actual native server with independent console and owned process failures.
server:
    zig build test-server -Doptimize=ReleaseSafe

server-direct-tables:
    zig build test-server-direct-tables -Doptimize=ReleaseSafe

server-direct-faults:
    zig build test-server-direct-faults -Doptimize=ReleaseSafe

# Terminal text, JSON collectors, settings propagation and standalone failures.
server-logging:
    zig build test-server-logging -Doptimize=ReleaseSafe

server-sql-lifetimes:
    zig build test-server-sql-lifetimes -Doptimize=ReleaseSafe

server-faults:
    zig build test-server -Doptimize=ReleaseSafe -Dserver-faults=true

# Actual psql/mysql over opt-in local listeners and public authorization.
server-sql:
    zig build test-server-sql -Doptimize=ReleaseSafe

# Local trust/password authentication, all TLS modes and recorded owner bootstrap.
# Exercise SQL protocols through the installed single Transit executable.
server-sql-local:
    zig build test-server-sql-local -Doptimize=ReleaseSafe --prefix .cache/transit-sql-local

# Exact SQL setup recovery after native commits with lost replies.
server-sql-faults:
    zig build test-server-sql-faults -Doptimize=ReleaseSafe

# Installed single-executable SQL lifecycle outside the checkout.
server-sql-package:
    nix build .#transit-local --out-link .cache/transit-sql-package
    zig build test-operation-fixture -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/interfaces/installation/server_sql.py --bundle .cache/transit-sql-package

# Linux/Docker: real ENOSPC inside one newly allocated ext4 image.
server-capacity:
    zig build transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/runner/launch.py tests/interfaces/installation/server_capacity.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host

# Current grant changes/cancellation after a durable segment staging decision.
unified-lifecycle source="kv":
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-lifecycle=true

# Real opted-in request lifetime, complete/prefix reads and disk restart.
unified-expiry source="kv":
    zig build test-unified-query -Doptimize=ReleaseSafe -Dunified-source={{source}} -Dunified-expiry=true

# Independent v1 bundle and Arrow fixtures through native and port APIs.
unified-codec:
    zig build test-unified-codec

# Qualify RPC preparation, dispatch, final publication and blocked-peer control.
grpc-faults:
    zig build test-grpc-worker -Dgrpc-faults=true

# Focus the finite work cutoff and bounded closure while the RPC remains active.
grpc-control:
    zig build test-grpc-worker -Dgrpc-control=true

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
    python3 -B tests/runner/launch.py tests/interfaces/reactive/reactive_descriptions.py zig-out/bin/transit-serving-api

# Qualify the shared Zig caller and private host adapter over real TLS and disk.
reactive-client:
    nix develop .#serving --command zig build test-serving -Doptimize=ReleaseSafe -Dserving-reactive=true -Dserving-tls=true -Dserving-reactive-client=true

# Real shared requester, fair finite refresh and current grant recovery.
reactive-refresh:
    python3 -B tests/runner/launch.py tests/interfaces/http/serving_submission.py
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
    zig build test-operation-fixture transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/interfaces/installation/server_applications.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Lost native and migration replies, current revocation and management admission.
server-application-faults:
    zig build test-operation-fixture transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/interfaces/installation/server_application_faults.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Accepted application input across real ENOSPC in an owned ext4 image.
server-application-capacity:
    zig build test-operation-fixture transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    nix shell --inputs-from . nixpkgs#e2fsprogs nixpkgs#util-linux nixpkgs#bash --command python3 -B tests/runner/launch.py tests/interfaces/installation/server_capacity.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Default embedded Board, retained inspection grants and local UI recovery.
server-board:
    zig build transit transit-node transit-query-host transit-board transit-sql-gateway -Doptimize=ReleaseSafe
    cd examples/work-items && zig build -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/interfaces/installation/server_board.py zig-out/bin/transit zig-out/bin/transit-node zig-out/bin/transit-query-host zig-out/bin/transit-board examples/work-items/zig-out/bin/transit-work-items examples/work-items/zig-out/bin/work-items

# Ordinary server/console and Board from one copied executable with unavailable PATH.
server-single-executable:
    zig build test-server-single-executable -Doptimize=ReleaseSafe

# Downstream single-executable package, with no source-runtime dependencies.
server-board-package:
    nix build .#transit-local --out-link .cache/transit-board-package
    python3 -B tests/runner/launch.py tests/interfaces/installation/server_board_package.py .cache/transit-board-package

# Deterministic shared-client and courier schedules.
scheduler-simulation *args:
    zig build test-scheduler-simulation -- {{args}}

# Defects in the actual shared Session and courier code must be observed.
scheduler-simulation-mutations:
    python3 -B tests/runner/launch.py tests/verification/mutations/mutations.py --scheduler

# Seeded checks over real Document, Exchange, query/reactive, runtime and catalog code.
domain-simulation *args:
    zig build test-domain-simulation -- {{args}}

# Qualify each component oracle using a compiling defect in its real owner.
domain-simulation-mutations:
    python3 -B tests/runner/launch.py tests/verification/mutations/mutations.py --domain

# External OS/network faults over owned binaries and actual disk Ursula.
vortex *args:
    python3 -B tests/runner/launch.py tests/runtime/delivery/vortex_proxy.py
    zig build test-vortex -- {{args}}

# Installed Python/Node, local application, query or browser/reactive faults.
vortex-profile profile:
    python3 -B tests/runner/external_profiles.py --profile {{quote(profile)}}

# Independent logical type fixtures, allocation failures and exact codecs.
fuze-types:
    python3 -B tests/runner/launch.py tests/query/logical/fuze_types.py
    zig test packages/zig/transit-fuze/src/Types.zig

# General Table schema identities, row constraints and independent byte oracle.
table-schema:
    python3 -B tests/runner/launch.py tests/storage/codecs/column_codecs.py
    python3 -B tests/runner/launch.py tests/catalog/tables/table_schema.py
    python3 -B tests/runner/launch.py tests/storage/local/table_storage.py
    python3 -B tests/runner/launch.py tests/catalog/tables/table_catalog.py
    zig test packages/zig/transit-fuze/src/TableRow.zig
    zig test packages/zig/transit-fuze/src/TableEvolution.zig
    zig test packages/zig/transit-fuze/src/SqlTypes.zig

# Relational contracts, bounded executor and independent finite semantics.
relational:
    python3 -B tests/runner/launch.py tests/query/execution/relational.py
    zig test packages/zig/transit-fuze/src/Relational.zig
    cd packages/zig/transit-fuze && zig build test-relational -Doptimize=ReleaseSafe

# Independent CSV/JSONL records, schema binding, denial and allocation schedules.
fuze-sources:
    python3 -B tests/runner/launch.py tests/query/logical/fuze_sources.py
    zig test packages/zig/transit-fuze/src/FileSource.zig

# Real file/stdin/gzip query host, independent codecs and constrained process memory.
file-query:
    zig build test-file-query

# Independent PyArrow interpretation of all logical families and five states.
logical-arrow:
    zig build test-logical-arrow

# Exact logical values across owned C buffers and bounded local host messages.
logical-codec:
    zig build station-abi transit-station-host
    python3 -B tests/runner/launch.py tests/query/logical/fuze_logical_codec.py zig-out/lib/libtransit_station.so zig-out/bin/transit-station-host

# Run in nix develop .#benchmarks; reports require an explicit output path.
[positional-arguments]
file-benchmark *args:
    #!/usr/bin/env bash
    set -euo pipefail
    zig build file-benchmark -Doptimize=ReleaseSafe
    "${TRANSIT_FUZE_BENCH_PYTHON:?Enter nix develop .#benchmarks}" -B tests/runner/launch.py tests/performance/query/run.py zig-out/bin/transit-file-benchmark "$@"

# Isolated immutable-tree prototypes; never opens native installation state.
page-layout *args:
    python3 -B tests/runner/launch.py tests/performance/storage/page_layout.py {{args}}

# Experimental fixed-width kernel/owned-row comparison with independent answers.
vector-benchmark output:
    zig build vector-benchmark file-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/query/vector.py zig-out/bin/transit-fuze-vector-benchmark --engines scalar batch --output {{quote(output)}}

# Real frozen-file pipeline sweep; preserves complete decoding and verification.
vector-files output:
    zig build file-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/query/vector_files.py zig-out/bin/transit-file-benchmark --output {{quote(output)}}

# Typed pipeline matrix; one warmup and nine measured paired repetitions.
vector-pipelines output:
    zig build vector-benchmark -Doptimize=ReleaseSafe
    python3 -B tests/runner/launch.py tests/performance/query/pipelines.py zig-out/bin/transit-fuze-vector-benchmark --engines scalar batch --output {{quote(output)}}

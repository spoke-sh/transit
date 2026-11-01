# Clients and language SDKs: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Installed language consumers, shared bindings, ABI ownership and cross-language conformance.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Bounded admission and direct KV recovery — 2026-11-01

[PR #307](https://github.com/spoke-sh/transit/pull/307) adds named KV to the
shared context, optional bounded admission waits and a local-store KV mutation
adapter. The public [context](../../../packages/zig/transit-data-client/docs/context.md)
and [recovery](../../../packages/zig/transit-data-client/docs/recovery.md) guides
own the semantics and limits. Tests use Linux x86_64 and pinned Zig
`0.17.0-dev.2267+48abf1a34`.

At integrated source `98ef070e3056ca783659bc471a5ca311996de116`, standalone
`zig build test` executes **31 passing tests**, and `zig build check` passes.
The context checks cover oldest-eligible admission, independent data/control
capacity, saturation, cancellation/expiry cleanup, queued close races and SQL
leases waiting behind Catalog work. Queue metadata performs 4,096 admission
cycles without further backing allocation. Recovery tests cover exact original
conflicts, stale revisions, invalid/conflicting receipts, retained output
lifetimes, allocation failure and a receipt-storage failure that preserves the
known service outcome. This does not establish aggregate host-memory bounds.

The installed `just test::direct-kv` schedule passes at
`a8387eae448202d1a3c40d03f3e557dc54f03f98` and again after integration at
`98ef070e3056ca783659bc471a5ca311996de116`, with clean runtime source records.
The latter has the same runtime/test source as merged `main` at
`0e697b438`; its only differences are roadmap/recovery prose.
It first proves that insufficient local record capacity sends no mutation, then
kills the caller after the service accepts an eight-key mutation with 1 KiB
values but before delivering its reply. The driver independently verifies the
stored original/key/checksum and deletes the standalone fixture save. A new
caller observes the original operation from the store after node replacement,
saves the receipt, and preserves both across a second node replacement. The
schedule also covers lost pin replies, retained reads after DROP, current denial
and control-lane observation/release while closing. The report records 41
requests and lost replies for operations 641001 and 641002. This is a standalone
KV mutation/pin profile, not transaction, power-loss or installed language-ABI
qualification.

The first clean core attempt at `bc1d5d0731eef8ebcce2e498aab753341305be71`
fails on diagnostic-inventory drift. After regeneration, the clean run at
`a8387eae448202d1a3c40d03f3e557dc54f03f98` passes the complete `check::core`
target: 58 fast checks, 19 contract checks, native execution, CLI diagnostics
and console checks. Transition properties and delivery simulation also pass.
The remaining broad lane is deliberately stopped during resource simulation
after integration introduces a newer definition; it is **incomplete**, not a
full core-lane pass. Clean `storage-query` at `bc1d5d0731eef8ebcce2e498aab753341305be71`
passes its first 11 tasks, then fails compilation because the existing branch
policy fixture omits `Intent.kind`. Commit `8e79f4316d4cb0d0e01834bd7f7d231a1ff104c5`
adds the explicit Table kind. A fresh full catalog attempt compiles and enters
runtime execution, then is stopped in favor of the two affected branch checks;
that full attempt is also incomplete. Neither failed lane is retroactively passed.

Raw command reports and bounded logs remain under
`.cache/ci/m9/client-foundation/` and `.cache/ci/m9/integrated/` in
`/var/tmp/transit-m9-implementation-plan`; the repeated captured package commands
were cached, and the earlier capture metadata retains its dirty starting revision
separately from the installed test's clean runtime record. Clean-run reports,
source checkouts and preparation logs remain at `/var/tmp/transit-ci-c71cmr3b`,
`/var/tmp/transit-ci-zhi6jskk` and `/var/tmp/transit-ci-20d6ncbt`.
The initial [hosted run](https://github.com/spoke-sh/transit/actions/runs/41291417832)
fails documentation links after concurrent roadmap renumbering; the correction
preserves the original assessment and updates its destinations. At the integrated
source, 9,992 local links, site lint/types, 10 site tests and the production build
pass. These scoped results do not close M9's remaining context, binding, ordinary
settlement, managed-handle or installed Python/Node requirements.

## Local SQL recovery and context leases — 2026-10-31

Source `53a02e10c5b07cf663771c4a3269cfe512e031f3` adds a Linux local-file
recovery store, its SQL adapter and SQL leases in the existing bounded context.
The pinned Zig toolchain is `0.17.0-dev.2267+48abf1a34`. Both changed packages
pass standalone `zig build test`/`check`; the data client executes **23 tests**.
The public Zig SDK consumer test passes, all **58 fast checks** pass, and the
documentation checker validates **9,735 local links across 703 files**.
The fast run precedes that commit and checks the same implementation; its raw
report retains the preceding HEAD and dirty-worktree provenance.

The complete `just check native` run, which executes the root `zig build test`,
also passes at that committed revision from a clean working tree. Its retained
report records completed validation and exit code 0. Component fixture stderr
does not change that aggregate result. Raw fast/native reports, their logs and
SHA-256 checksums are retained under `.cache/ci/m9/foundation/` and
`.cache/ci/m9/sha256.json` in the implementation worktree; [PR #298](https://github.com/spoke-sh/transit/pull/298)
records the reproduction commands and remaining broad-lane blockers.

Actual-file tests cover exclusive-owner refusal, reopen, exact-original conflict,
revision-checked evidence, private permissions, corrupt and missing-definition
records, and 31 records traversed in three-key pages without a resident directory.
Injected failures cover no space at creation, partial write followed by no space,
cancelled write, file sync, rename and directory sync. A failed publication leaves
complete original recovery material; a failure after rename can expose the new
record without reporting success. Store and SQL-adapter backing allocators refuse
new allocations after initialization while the bounded record workloads execute.
This does not measure all I/O/runtime allocations or qualify power loss.

The SQL loopback fixture negotiates a session through a context lease, checks the
persisted original before receiving its execute, and simulates success, lost
reply, pre-dispatch disk refusal and failed receipt persistence. Lost replies
cause one execute and observation of the same token. A verified applied command
remains visible alongside its receipt-storage error. The scripted peer is not a
Transit service and this is not a killed-caller/service-restart recovery proof.

Context tests cover constructor allocation failures, shared admission, stale
lease release/cancellation, control capacity under data saturation and close
timeout with an outstanding SQL lease. SQL primary/control transports retain
separate existing reserves, totaling 40 MiB per facet plus metadata; the context
does not create a worker pool. The lease must outlive all returned SQL outcomes
and views. Managed result handles and installed Python/Node APIs are unqualified.

The earlier clean core/SQL failures below remain recorded at their original
revisions; these focused results do not convert either lane into a complete pass.
Public ownership and limits are in the [context guide](../../../packages/zig/transit-data-client/docs/context.md)
and [recovery guide](../../../packages/zig/transit-data-client/docs/recovery.md).
M9 remains In Progress, including principal coordination, fair admission,
ordinary Catalog settlement, full result/transaction composition, data bindings,
installed languages, process-loss recovery and the M6/M7 facet handoffs.

## Catalog context and SQL submission persistence — 2026-10-31

This slice checks bounded local ownership and persistence ordering, without
changing Catalog acceptance or SQL settlement. The final code source is
`79c11936e23103c7e75b5b129c2ca99e8b578704`; the SQL implementation is identical
to the separately tested `7c70480aa92257465ff0f4c10df276a1ca6c9b87`.
Checks use the pinned Nix shells and Zig `0.17.0-dev.2267+48abf1a34`.
[PR #298](https://github.com/spoke-sh/transit/pull/298) records commands,
retained local report locations and validation blockers.

Both client packages pass their standalone `zig build test` and `zig build check`.
Context tests cover constructor allocation failures, wrong/stale handles, separate
data/control capacity, 4096 admission cycles without new directory allocations,
close timeout/cancellation, Table retention control admission and arena-owned
output surviving close. The SQL test uses real loopback HTTP with a scripted
peer: persistence precedes execute, storage failure/cancellation prevents execute,
scope replacement and context denial refuse submission, and a lost reply causes
observation of the same token with exactly one execute. Saved values exclude the
secret session handle; missing/foreign definitions and mismatched recovery
identities reject. The store in this test is memory owned by the fixture, not a
disk-durability or process-replacement proof.

The clean core run at `79c11936e` passes 58 fast checks, 19 contract checks and
the full native check, then fails the CLI diagnostic prefix assertion: startup
telemetry precedes `error:`. A separate checkout of base `b60f12154` reproduces
that same failure; the CLI and diagnostic test are unchanged by this slice.
The remaining core tasks were not reached. An earlier core run at `7c70480aa`
was intentionally stopped after the Table retention admission correction and
is incomplete, not passed.

The clean SQL lane at `7c70480aa` passes TLS, result allocations and the installed
gateway/CLI schedule. Unix, HTTP and HTTPS each report zero warm memory events
for the existing allocation workload. The session task then fails its 1800-second
`session-sources` provisioning deadline, before session assertions; the lane does
not reach its transaction task. These failures remain qualification blockers.
Documentation build, local links, version pins and whitespace checks pass.

A separate `zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- sessions-basic`
run in the retained SQL checkout passes the basic native-session profile: TLS and
independent SCRAM, concurrent sessions, wide logical values, storage/EXPLAIN
inspection, buffered disclosure and original-token recovery after restart. This
profile excludes the legacy source fixtures and does not convert the full-lane
timeout into a pass.

The independent `just test::sql-transactions` run also passes in that unchanged
SQL checkout: common cuts, private reads/joins, original savepoint retry,
write-skew prevention, retained read-only cuts, one lost commit reply, gateway
restart reattachment and PostgreSQL/MySQL status projection. Its lifetime profile
checks two private batches/40 rows, delayed-reader cuts, session-expiry attachment,
statement/savepoint limits and explicit cleanup. These are Table transaction
results, not mixed KV/Document/Stream/Queue participant qualification.

Current ownership and limits belong to the
[Catalog context](../../../packages/zig/transit-data-client/docs/context.md) and
[SQL persistence API](../../../packages/zig/transit-sql-client/README.md#persisting-an-original-attempt).
This evidence does not qualify a durable recovery store, fair queued admission,
principal coordination, shared SQL/context ownership, a foreign-language data
host or the installed SDK matrix, and does not complete M9.

## Installed C and C++ direct lifecycle — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-c -Doptimize=ReleaseSafe`
passes **152 public requests** across independently installed C11 and C++17
consumers. Six matching pkg-config artifacts supply the C API, C++ facade and
native libraries. Consumer compilation treats warnings as errors; compile-fail
checks reject copying clients and unique recovery owners. The C/C++ adapter
package checks preserve handler Table ownership and rejection coverage.

The forwarding native-library boundary suite passes **77 cases**: complete
binding and mandatory-definition checks, exact prepared action/object identity,
wide saved intents, bounded aggregate construction, physical descriptors, dense
ordered pages, substituted observations/snapshots, definite denial and unknown
mutation outcomes. A cancelled POSIX caller remains joined to its native work;
concurrent access returns busy and close waits through receipt publication.
The first boundary attempt stopped at the fixture's old capabilities envelope;
the corrected fixture and complete second installed run pass.

Both consumers stage nine 32 KiB rows, persist their original work and recover
committed writes after corrupted replies. Four corrupted pin/release replies and
six abrupt caller/node replacements preserve unchanged saved intents, references
and acquisitions. Exact DML counts, stale definition rejection, ALTER/RENAME/DROP,
name reuse, namespace/Table inspection, retained original metadata, current
credential rotation and idempotent release pass. The service produces `.tseg`
files; observed native commands are limited to authorization administration.

This proof checks retained metadata, without interactive SQL row reads. It does
not establish physical reclamation, automatic expiry, Board integration or final
repository checks.

## Installed Erlang and Elixir direct lifecycle — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-beam -Doptimize=ReleaseSafe`
passes **155 public requests** across independently installed Erlang and Elixir
APIs. Six matching OTP application artifacts provide the native ports, shared
worker and Elixir value projection; package and consumer compilation treats
warnings as errors. The generated recursive-schema and logical-value suites pass
for both consumers, as do complete binding/cursor checks, wide saved values,
substituted receipts, malformed replies and actual waiting-process loss whose
native operation remains owned until joined port cleanup.

Each adapter stages nine 32 KiB rows, saves original work before dispatch and
recovers after a corrupted committed-write response. Across both runs, four
corrupted acquisition/release replies and six abrupt caller/node replacements
preserve unchanged original values. Exact mutation counts, stale bases,
ALTER/RENAME/DROP/name reuse, namespace/Table inspection, retained metadata,
current credential rotation and idempotent original release pass. The service
produces `.tseg` files. Observed native commands are limited to authorization
administration. The first attempt stopped at a test fixture's Erlang syntax
error before the value suite; the corrected complete second run passes.

This proof checks retained metadata, without interactive SQL row reads. It does
not establish physical reclamation, automatic expiry, the remaining C/C++
adapter, Board integration or final repository checks.

## Installed Rust direct lifecycle and retained metadata — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-rust -Doptimize=ReleaseSafe`
passes **78 public requests** using four matching crate artifacts installed
outside the checkout. The proof verifies source/contract bytes, builds offline
with warnings treated as errors and checks resolved registry packages against
the committed lock. All **14 library tests** pass, including existing logical
and application-owned handler Table checks. Compile-fail checks reject overlapping
mutable calls and reuse after consuming close.

Nine 32 KiB bulk rows, corrupted committed-write and retention replies, and three
abrupt caller/node replacements preserve original recovery values. Exact counts,
stale bases, ALTER/RENAME/DROP/name reuse, current inspection, retained metadata,
credential rotation and idempotent release pass. The service produces `.tseg`
files and the observed native commands are limited to authorization administration.
The first two installed attempts stopped at typed bulk preparation: the decoder
incorrectly reused the raw client's 256 KiB string limit for catalog saved intent
bytes. The decoder now applies the catalog's explicit bound; a saved-value
regression check and the complete third run pass. The raw-client bound is unchanged.

`serde` is now a direct dependency at its existing locked version for strict
saved JSON decoding. Both affected locks add that dependency without changing
registry versions. The Rust example also compiles. This proof establishes retained
metadata, not an interactive SQL cursor, automatic expiry or physical reclamation.
C/C++, BEAM adapters, Board integration and final repository checks remain open.

## Installed .NET direct lifecycle and retained metadata — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-dotnet -Doptimize=ReleaseSafe`
passes **78 public requests** through four independently packaged NuGet artifacts
installed outside the checkout. The consumer compiles with warnings treated as
errors and uses the packaged native libraries. Nine 32 KiB bulk rows, corrupted
committed-write and retention replies, and three abrupt caller/node replacements
preserve original saved work, references and acquisition values. Exact mutation
counts, stale definitions, ALTER/RENAME/DROP/name reuse, original receipts,
namespace/Table inspection and retained metadata pass. Current credential
rotation denies retained metadata, repeated release is idempotent, and the
service produces `.tseg` files.

Boundary checks pass owned logical values, strict metadata, physical descriptors,
complete saved bindings, immutable pages and cancellation/disposal that joins the
native worker. The first attempt exposed a test fixture constructing JSON integer
nodes differently from native parsed JSON; the fixture now crosses the same JSON
serialization boundary and the full rerun passes. This proof checks retained
metadata, not interactive SQL row reads. Remaining adapters, Board integration,
physical reclamation and final repository validation are not established by it.

## Installed Java direct lifecycle and retained metadata — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-java -Doptimize=ReleaseSafe`
passes **78 public requests** through independently packaged JARs installed outside
the checkout. The consumer compiles with Java 21 and warnings treated as errors,
checks the matching contract resource and uses the packaged native port. Nine
32 KiB bulk rows, a corrupted committed-write reply, two uncertain retention
replies and three abrupt caller/node replacements preserve original recovery
values. Exact counts, stale definitions, ALTER/RENAME/DROP/name reuse, original
receipts, current namespace/Table inspection and retained metadata pass. Current
credential rotation denies retained metadata; repeated original release is
idempotent. The service produces `.tseg` files, and native commands observed by
the proxy are limited to authorization administration.

Installed decoder/ownership tests also pass complete saved identities, physical
schema requirements, bounded conversion, strict cursors, substituted receipts,
large port frames and cancelled futures whose worker/child cleanup is joined.
The generated recursive-schema suite passes independently. The first installed
attempt stopped during consumer compilation because a test's Gson parser class
required absent annotation metadata under `-Werror`; the consumer now uses the
same existing Gson entry point as the other installed tests, and the complete
rerun passes. This proof establishes retained metadata, not interactive SQL row
reads, physical reclamation, automatic expiry or the unfinished other adapters,
Board workflow and final repository checks.

## Installed Ruby direct lifecycle and retained metadata — 2026-10-24

`nix develop .#bindings -c zig build test-direct-catalog-ruby -Doptimize=ReleaseSafe`
passes **78 public requests** through four matching gems installed outside the
checkout. The proof checks packaged catalog/bridge/schema bytes against the
built revision and uses the packaged native port without source-path overrides.
Nine 32 KiB rows use direct bulk staging. A corrupted committed-write reply,
corrupted pin/release replies and three abrupt caller/node replacements preserve
the original saved work, operation reference and acquisition. Original receipts
and retained metadata survive ALTER, RENAME, DROP and same-name replacement;
current credential rotation denies retained metadata. Exact no-op/deletion
counts, stale-basis refusal, current namespace/Table pages and idempotent release
also pass. The service produces `.tseg` files and the proxy observes no native
actor commands beyond authorization administration.

The Ruby boundary suite passes owned nested values, full-width identities,
complete saved-binding rejection, malformed mutation replies retaining recovery,
fragmented large port responses and cancellation that joins active worker cleanup.
Existing handler Table checks pass **28 adversarial rejections**. These preserve
the application-owned handler path, distinct from the general catalog path being
replaced. The installed Ruby proof checks retained metadata; it does not execute
an interactive SQL cursor or independently decode retained rows. Python,
TypeScript and shared native callers provide their separately recorded SQL
coverage. Physical reclamation, automatic retention expiry, remaining adapters,
Board integration and final combined checks remain unqualified by this run.

The complete TypeScript SDK check also passes **39 Station tests**, client tests,
formatting, lint and type checks. A stale unified-query fixture exposed a missing
accepted Table position in the language projection; the decoder now preserves
it and rejects substituted resource/schema commitments. That projection check
uses a fake native boundary and does not establish result truth.

## Installed TypeScript direct lifecycle and retained SQL — 2026-10-24

`zig build test-direct-catalog-node -Doptimize=ReleaseSafe` passes **197 public
requests** using four independently packed, version-matched packages installed
outside the checkout. The consumer resolves the packaged native port without a
source-tree override. It runs the same direct lifecycle schedule as Python:
wide bulk rows, a corrupted committed write reply, exact saved recovery through
three abrupt caller/node replacements, and uncertain snapshot acquisition and
release. Cached and terminal output and repeated open reject after credential
rotation. Original rows remain readable through the explicit retained binding
after ALTER, RENAME, DROP and name reuse; no-op and deletion counts remain exact.

The package build includes TypeScript compilation. This run qualifies the
installed Table lifecycle and explicit retained interactive reads; namespace
administration, dependency/named-resource wrappers, the other language adapters,
Board integration and final repository gates remain separate work. It does not
establish physical reclamation, automatic pin expiry or a durable interactive
cursor after host loss.

## Installed Python direct lifecycle and retained SQL — 2026-10-24

`zig build test-direct-catalog-python -Doptimize=ReleaseSafe` passes **393 public
requests** against the disk-backed local service. Four version-matched wheels
are installed into an isolated consumer environment; the proof verifies their
catalog/relational source and contract resources against the built revision.
Both synchronous and asynchronous clients stage nine 32 KiB rows, preserve the
original operation after a corrupted accepted reply, and recover through actual
caller termination and node replacement. Four corrupted snapshot acquisition/
release replies and six abrupt caller/node replacements retain the original
saved work, operation reference and acquisition unchanged.

The same installed clients check matched/changed counts, ALTER, RENAME, DROP and
name reuse, then read nine rows from the original retained definition. Repeated
and terminal pages recheck current authority; credential rotation denies both
cached disclosure and repeated open. Local query closure leaves the explicit
source pin intact, and original-owner status resolves uncertain release. These
checks establish neither physical reclamation nor abandoned-pin expiry.

Earlier installed attempts failed in the harness: a synchronous call raised
before entering its expected-error handler, and overlapping fault rules flipped
the same response byte twice. The corrected complete schedule passes. Python's
strict type check passes **27 source/example files**; catalog decoder/ownership
checks, **6 relational boundary tests**, existing handler Table checks and the
application work model also pass. The handler checks preserve the application-owned Table helpers. They do not
qualify retirement of the separate general actor catalog path.
The other general language adapters, Board integration and final combined and
clean-checkout gates remain open.

## Direct catalog ABI and port recovery — 2026-10-24

The latest ReleaseSafe rerun passes **233 public requests** through both the C
ABI and native port. It includes the original bulk writes, four uncertain
pin/release replies and four abrupt node replacements, plus explicit relational
reads over the saved original binding and snapshot after DROP/name reuse. Both
callers preserve exact repeated pages, verify nine rows and terminal completion,
reject altered bindings and invalid ordinals, and deny cached and terminal
disclosure after credential rotation. Restored authority permits the original
read; destroying an interactive caller invalidates its local cursor without
releasing its durable source pin. Explicit release uses the original owner.

Earlier runs exposed a test that confused the live position with the retained
cut, local malformed-binding errors escaping the request boundary, and a test
that attempted to bind an existing credential instead of rotating it. These are
corrected in the passing run. Focused native relational suites pass **36** and
**10** tests; the TypeScript catalog/relational suites pass **14** tests with
their type check, and the browser decoder suite passes **4** tests. The native
Board build also passes. These checks do not qualify the unfinished Board UI,
Python or other installed language adapters, physical GC or abandoned-pin expiry.

`nix develop -c just test::direct-catalog-abi` passes **63 public requests** against
the local disk-backed service with separately built ReleaseSafe C ABI and native
port binaries. Both callers prepare and stage nine 32 KiB rows in a bulk request
larger than an actor frame. The proxy verifies each committed write before
corrupting its response; both callers report uncertainty and retain the original
operation. Caller replacement and **two abrupt node replacements** precede exact
receipt inspection. Repeated execution preserves the same counts, and original
receipts remain inspectable after DROP and name reuse. Immutable `.tseg` files
exist, full-width object IDs are preserved, and missing/foreign saved fields are
rejected without replacing valid local work.

The first run exposed missing structured diagnostics for the port parser's
pre-dispatch rejection. The port now uses the shared catalog input projection,
and the full schedule passes. The Station binding package separately passes
**22 tests**, including old actor configuration rejection, foreign definition
rejection, local saved loading, no-dispatch failure, overlap rejection and result
buffer ownership after handle destruction. These checks do not inject a real
post-acceptance output allocation failure. The TypeScript catalog boundary suite
passes **9 tests**, covering lossless references, physical descriptors, bounded
wide preparation, read failure versus uncertain mutation, and mismatched success
responses. These are source-level wrapper tests; installed language consumers
and the interactive relational cutover remain unfinished.

The extended rerun passes **77 public requests**, with four corrupted snapshot
acquisition/release replies and **four abrupt node replacements**. Both callers
persist exact acquisition bindings before dispatch, resolve original retention
owners after caller/node loss, and inspect original accepted positions and schemas
after DROP/name reuse. Uncertain release is confirmed through original-owner
status; repeated release preserves the same reference. The focused retention
reference package run passes **4 tests**, the expanded TypeScript suite passes
**10 tests**, and contract/mapping/documentation checks pass. The TypeScript
package type check remains incomplete because its interactive relational adapter
still imports the removed actor owner connection. No physical GC or abandoned-pin
expiry is established by these retention checks.

## Direct caller diagnostic projection — 2026-10-24

The focused catalog package run on committed source `ba51e4226` passes **4 tests**,
including root imports. Every direct registry entry retains its reviewed category,
failed reads report `not_applicable`, local failures report `not_submitted`, and
recorded mutation attempts preserve `unknown` and the original full-width operation
identity. The semantic mapping gate covers **106 direct/common causes across 66
owner/error pairs**, with no exceptions in this boundary. The inventory records
603 owners and 4,904 owner/error pairs; inventory coverage is separate from this
executable projection proof. This slice does not establish SDK/ABI migration or
inject allocation failures into a real accepted request.

## Direct caller mutation-attempt evidence — 2026-10-24

The focused `direct caller attempt` package run passes **4 tests**, including
root imports. It preserves original operation identity across later reads and
projects unknown outcomes for denial, conflict, malformed replies, timeout and
allocation errors after mutation dispatch. Failed credential lookup against an
unreachable authority leaves the attempt empty. These are attempt projections;
they do not establish a durable operation outcome or inject output-allocation
failure into a real accepted request.

The first filtered run omitted the new test import and establishes no test pass.
The first public-proof build caught an incorrect staged-intent member access;
it is corrected, the test import is present, and the explicit-count package rerun
passes. The corrected public rerun passes `just test::direct-dependencies`
(**32 calls**) and `just test::direct-named-resources` (**107 calls**). Corrupted
dependency replies preserve unknown outcomes and their original IDs. In each
resource allocation, a native receipt proves allocation was accepted before the
catalog response reports AccessDenied; the attempt remains unknown, preserving
the saved operation for recovery after explicit grants. All original fault and
restart assertions also pass. Contract, diagnostic inventory/mapping and
documentation checks pass. The hook does not yet replace the general catalog
ABI's dispatch/error boundary.

## Direct host named resource recovery — 2026-10-24

`just test::direct-named-resources` passes **107 typed catalog calls**, eight
withheld resource replies, four withheld dependency replies and eleven abrupt
node replacements with resource operations routed through serialized shared host
actions. The saved host CREATE bindings remain unchanged across each recovery.
The schedule covers original caller allocation, actual Station KV/Document
initialization, typed KV writes/deletes, Document publication, current native
data denial, metadata lookup, rename/DROP and original receipt recovery.
Dependency registration, both graph directions, RESTRICT and explicit cleanup
continue to use their existing native owner in this resource schedule.

The focused `direct resource host` package test passes full-width Document IDs,
staging budgets, object/operation identities and positions, owned restoration
after freeing the source arena, wrong-caller rejection and exact prepared native
allocation recovery. Independent schema fixtures require complete bindings and
reject numeric full-width Document IDs. Their first run caught a missing Python
brace; the corrected run passes. Generated contracts, diagnostic checks,
formatting and documentation links pass. General SDK/ABI integration and final
combined/clean-checkout qualification remain open.

## Direct host dependency recovery — 2026-10-24

`just test::direct-dependencies` passes **32 typed HTTP calls** through the shared
host adapter. The original host bindings remain byte-for-byte unchanged across
corrupted registration/removal replies and abrupt node replacement. Recovery
returns the exact terminal receipts; current membership becomes absent after
removal even when the original registration receipt is replayed. Both graph
directions, current metadata revocation, redacted DROP blockers, altered-binding
rejection and DROP/name replacement pass.

Independent generated-contract checks require complete saved host bindings and
decimal full-width operation identities. All 152 catalog package tests pass,
including owned saved-binding restoration after freeing its original JSON arena
and cursor rejection for a changed caller, selection or authority. Diagnostic
mappings/inventory, formatting and documentation links pass. This is shared caller qualification;
general SDK/ABI migration and final integrated/clean-checkout gates remain open.

## Direct host namespace and policy preparation — 2026-10-24

`just test::direct-table-callers` passes **150 typed HTTP calls**, including
saved namespace-binding restoration, read-only preview, explicit CREATE/RENAME/
DROP, stale-definition rejection and original CREATE receipt recovery after
retirement. Policy compilation binds the exact native Table reference; preparing
its signed native authorization record leaves the policy revision unchanged.
The complete `just test::direct-table-service` regression passes **1239 typed
HTTP calls**, including retained history, lost replies and three restarts.

All 151 catalog package tests pass. The new binding test restores the maximum
operation/catalog IDs after freeing its source arena and rejects a different
caller. Its first run incorrectly used the borrowing JSON parser and crashed
after freeing that input; the corrected fixture uses the owned parser and the
complete rerun passes. Independent generated-contract fixtures reject missing
namespace-binding definitions and numeric full-width operation IDs. Diagnostics,
formatting and documentation links pass.

These are shared host adapters over the existing namespace and native policy
owners. Preparation does not publish a policy change. General SDK/ABI integration,
dependency/resource host adapters and final integrated/clean-checkout checks
remain separate delivery gates.

## Direct host catalog inspection — 2026-10-24

`just test::direct-table-callers` passes **129 typed HTTP calls** with the host
inspection adapter. It reads capabilities, the current signed catalog
description, namespace metadata and the Table directory through the direct
owner. Directory entries preserve the exact interpretation returned by lookup;
continuation against a changed directory rejects after DROP. Existing saved-work,
preview, wide bulk mutation and receipt-recovery checks also pass.

The complete catalog package suite passes. The `direct catalog cursors` test
round-trips full-width IDs/frontiers, rejects a changed caller or selection and
rejects a changed directory before returning a continuation result. Independent
Python fixtures reject missing cursor definitions and numeric full-width IDs.
Generated contracts, diagnostics, formatting and documentation links pass.
These checks cover the shared host inspection boundary; general SDK/ABI dispatch,
catalog administration and the final integrated/clean-checkout gates remain open.

## Typed direct caller preparation — 2026-10-24

`just test::direct-table-service` passes **1184 typed HTTP calls** in the pinned
ReleaseSafe profile under current-v1 definition
`1f0a0d9a10df7cb89783f6106fb0881a56c29ad7135167b97325ba1d56750029`.
The added host sequence prepares typed CREATE, inserts nine 32 KiB UTF8 values
through a serialized host action larger than the 256 KiB actor frame, and reads
back a complete value from the direct owner. Typed ALTER adds a default; a DROP
prepared against the earlier definition rejects. RENAME, DROP and absent
conditional DROP use the same saved-work, staging, admission and explicit
execution path as SQL. The existing SQL, history, lost-reply, revocation and
three-restart regression also passes.

Host session package tests, independently validated generated contracts,
diagnostic mappings/inventory, Zig formatting and documentation links pass.
The independent Python contract check includes the wide typed batch and rejects
a missing definition. These are additive caller types; native and stored formats
are unchanged. Preview, SDK/ABI wiring, removal of remaining actor Table callers
and the final integrated/clean-checkout gates remain unfinished.

## Shared direct caller session — 2026-10-24

`just test::direct-table-service` passes **1150 typed HTTP calls** in the pinned
ReleaseSafe profile under current-v1 definition
`1f0a0d9a10df7cb89783f6106fb0881a56c29ad7135167b97325ba1d56750029`.
The new host session sequence compiles CREATE with independent operation/object
IDs, saves and restores it after destroying its original session, stages without
admission, admits and executes it, and decodes its metadata. Conditional CREATE
returns the owning unchanged name outcome; conditional execute rejects. INSERT
returns the exact committed matched/affected counts. After source DROP and local
forgetting, the original reference still recovers the identical CREATE receipt.
Existing SQL, DDL, retained history, current revocation, lost replies and three
node-restart schedules also pass.

The `direct host session` package test passes inert loading against an unreachable
endpoint, failed output allocation without replacing the prior intent, wrong
namespace/caller rejection and explicit local forgetting. Reflected host action,
result and saved-work contracts pass independent Python validation; diagnostics,
formatting and documentation links pass. This qualifies the shared caller's
lookup, SQL compilation and explicit recovery path. Typed declaration/batch
preparation, preview, SDK/ABI wiring and the final integrated/clean-checkout gates
remain separate work.

## Lossless direct caller references — 2026-10-24

The catalog package's `direct host references` tests pass full-width unsigned
catalog, object, operation, definition-revision and LSN conversion, owned JSON
restoration after the source arena is released, malformed decimal rejection,
missing compatibility rejection and mismatched interpretation-content rejection.
`just contract::direct-table-generate` generates the host reference/preparation
schemas from their Zig owners and checks an independent Python fixture against
the exact canonical saved intent and its SHA-256 content commitment. The fixture
contains operation/catalog identity `18446744073709551615`; host schemas reject
a numeric operation and missing required identity fields. Zig reconstructs the
original native reference from that independent fixture.

The complete catalog package tests, generated direct-contract drift check,
diagnostic mappings/inventory, Zig formatting and documentation links pass in
the pinned Nix shell. This does not replace the final integrated repository and
clean-checkout checks.

This adds value contracts under the existing current-v1 definition; native
requests and stored formats are unchanged. It is prerequisite evidence for
general Table SDK/ABI migration, not proof that those callers already dispatch
through the direct owner.

## Go raw client

`nix develop .#bindings --command just bindings::go-sdk-test` passes with Go
1.26.7, the pinned Zig 0.17 compiler and the current shared ABI definition on
Linux x86_64. The task runs `go vet`, `go test -race` and
`GOEXPERIMENT=cgocheck2`, then installs the Go module and matching native archive
outside the checkout. It deletes the consumer source and extracted SDK before
running the installed binary against the real node and disk-backed Ursula.

The shared raw-client schedule observes current capabilities, an accepted send
whose response is lost, identical signed recovery without the seed, typed native
operation classification, cancelled host waiting with continued native ownership,
busy/closed rejection, responsive joined close and revoked historical retry.
The last observed receipt and its frozen operation identity survive cancelled
waiting and close. A separately compiled consumer with a foreign generated ABI
definition rejects the actual native library; a build with cgo disabled rejects
native open. The actual
`examples/go-client` binary prepares the same canonical bytes and dispatches the
saved operation without a seed after its own source/build module is removed.

Focused units verify the native worker's actual stack against the generated
8 MiB requirement, owned recovery buffers, malformed/missing/foreign saved
definitions, native counter/payload bounds, realm validation and diagnostic
formatting. Repeated real-authority client opens reuse one retained native image;
replacing or removing an explicitly loaded library rejects subsequent opens.
This evidence covers the raw Go client, not Station handlers, catalog/query APIs,
the Station language ring, other operating systems or portable native artifacts.
The task writes its local outcome/history to
`.cache/bindings/go/raw-evidence.json`; fixture keys and data are synthetic.

`just doctor`, `just bindings::check` and `just check` also pass in the bindings
shell, including the SDK navigation, Go syntax support and production handbook
build. These are worktree checks; committed-HEAD `just ci-clean` has not run.

## Shared direct action dispatch — 2026-10-23

The typed Table/namespace dispatch now resides in `transit-catalog`, while the
local host retains signed-request validation, native policy, lock coordination,
registration execution and the final disclosure fence. After that ownership
move, `zig build test-local-catalog --summary all` passes **2/2** Debug tests,
including Table CRUD, delegated reads/history, original-input prerequisites and
namespace authority/recovery schedules. Wire and persisted definitions are
unchanged by this move; application consumer migration remains separate.

## SDK bridge computation removal — 2026-10-23

The mediated SDK bridge no longer projects the removed generic catalog
`computation` action or result. The Station bindings package passes **22/22**
Debug tests in the pinned Nix shell. The repository check exposed these stale
switch arms and the still-unmigrated Work items caller; this focused check does
not establish full repository qualification.

## Neutral physical schemas across language callers — 2026-10-23

The shared current-v1 definition is
`64510390ce1d02e9e93fc04bf00554ca4625ae8b895134fc8cb04e3f5143a96c`.
The neutral schema requires explicit encoding/collation fields; previous definitions
and missing fields reject. Generated contracts, binding resources and independent
signing fixtures have been regenerated. The standalone FTS1 definition is unchanged.

The Fuze ReleaseSafe suite passes, including independently generated neutral JSON,
FTS1/FTP1 bytes and SHA-256 fingerprints from `tests/table_schema.py`. Its physical
fixture combines bitpacking, EBCDIC/CP037, RLE and COMP-3; native conversion preserves
all descriptors and rejects reserved ICU support. The catalog package's focused
`-Dtest-filter=typed` suite passes, including physical ALTER lowering.
`just test::table-ddl-sql` passes 270 independent declaration cases and 238 exact
schema comparisons. `just test::direct-table-service` passes its 460-call public
HTTP lifecycle, retained-cut and three-restart recovery schedule under this definition.

All ten language SDK packages build in `nix develop .#bindings`. Installed boundary
qualification passes for Python (sync/async), TypeScript, Rust, Ruby, C/C++, Java,
.NET, Erlang and Elixir. The tests cover owned physical descriptors, metadata
readback, typed changes and missing/unknown-field rejection. The C/C++ native-ABI
fault fixture passes 63 cases. Rust's installed library passes 16 tests; the
TypeScript source catalog suite passes 43 tests. Python type checking also passes.
These runs invoke `tests/sdk_catalog.py`'s `install` function with a fresh temporary
consumer directory and the selected language names; they execute its installed
value/fault checks without starting the returned durable-owner clients. Reproduce
a selected run after its `just bindings::<language>-build` task (`c-build` for
C/C++, `beam-build` for Erlang/Elixir) with
`PYTHONPATH=tests python3 -c 'from pathlib import Path; import tempfile; from sdk_catalog import install; install(Path(tempfile.mkdtemp()) / "consumers", ["python"])'`
in the bindings shell. Select `node`, `rust`, `ruby`, `c`, `cpp`, `java`, `dotnet`,
`erlang` or `elixir` for the other installed callers.

Contract, formatting, diagnostic mapping/error/outcome and documentation checks
pass. Diagnostic inventory records 577 production owners and 4,728 owner/error
pairs; outcome checks execute 3,387 projections. This slice qualifies descriptor
preservation, not the language SDK migration to direct Table ownership. Nonbinary
SQL collation and captured-query lifecycle integration remain separate work.

## SDK source and runtime boundary

The [SDK directory](../../../sdks/README.md) owns consumer APIs; shared runtime
implementation remains under `apps/` and `packages/`. These gates cover the
source split without changing the protocol definition:

- `python3 -B tests/sdk_layout.py` rejects runtime manifest/import dependencies
  on SDKs, with negative controls for Zig paths, TypeScript imports, package
  dependencies and compiler aliases. It does not parse arbitrary build scripts.
- `just bindings::zig-test` checks exact shared module identity, then copies
  tracked SDK/shared/example source into an isolated directory, builds the real
  work-items worker/operator through its SDK dependency and runs its manifest
  command. It does not simulate a separately published Zig archive.
- `just bindings::runtime-boundary` asserts the actual Nix source has no SDK or
  language SDK example tree, builds the native runtime and SQL gateway offline
  from their pinned dependencies and runs the installed public CLI help paths.
- Existing binding lanes build and exercise installed language packages after
  relocation; native generation still compares against shared Zig contracts.
- Handbook browser proofs exercise SDK navigation and search alongside mobile,
  diagram and interface pages. Run with both root and prefixed hosting.

The source/consumer preflight, unchanged binding generation, `just doctor` and
`just check` passed during the October 16 layout work. These workspace runs are
not clean-checkout evidence. The committed-source gate includes all 88 ordinary
tasks across six lanes, including the two new SDK checks in core; lane timings
and completion are retained under `.cache/ci/clean/` and reported in the PR.
A failed or incomplete lane does not qualify the complete inventory.

## Installed interactive relational SDKs

[Exact implementation revision, artifact hashes, logs and retained attempts](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/relational-sdks-2026-10-12.json)
record TypeScript and Python sync/async consumers installed outside the checkout.
`just bindings::relational-node` and `just bindings::relational-python` build
their matching native artifacts and run the signed disk-backed caller fixture.
The ordinary Node and Python SDK tasks also run these schedules.

Both one-resource aliases and two-resource joins agree with the typed Zig
executor's prepared plan hash and the independent three-row fixture. Exact open,
current-page and close retries preserve identity. Current catalog denial blocks
an already returned prefix, fresh hosts reject the old reference, and ordered
overflow preserves its original output/contributor witness and incomplete status.
The reviewed Node schedule passes in **19.058 seconds** and the Python sync/async
schedule in **18.122 seconds**, including their neutral caller baseline. Each
baseline uses 72 port calls with a maximum 1,603-byte response. These small
fixtures do not measure sustained input, large-output memory or throughput.

Node checks pass **60** tests, including three relational boundary cases.
Python passes five relational boundary/ownership tests and strict typing across
22 source files. Full signed/unsigned integer bounds, nulls, owned row identities,
missing/foreign definitions, altered page identities and invalid coverage are
checked. Python cancellation leaves the native operation owned; overlapping work
is rejected, and close joins before releasing its handle.

The record preserves the initial missing build-task recipe, four Python typing
findings and a guide formatting failure, along with the successful reruns.
Board, foreign durable lifetimes and final committed-HEAD clean lanes remain
separate gates; this SDK evidence does not imply they have passed.

## Rust native lifetime investigation — 2026-09-30

Following PR #33, a fresh installed Rust suite passed on the merged source
`a53d6262`, while a separate repeated malformed-input schedule reproduced the
`decode-block` SIGSEGV on case 108 after 107 successful fresh cases. A retained
core shows the detached native thread returning from `futexWake` through
`Io.Threaded.WaitGroup.finish` and `Io.Threaded.worker` after the client library
was unmapped. The Rust owner was removing the extracted artifact, and the main
thread was joining that owner. Thus a passing ordinary rerun does not resolve
the failure.

The Rust loader now retains bounded shared code mappings until process exit,
while handle and buffer destruction remain explicit. Installed raw/Station
regressions check actual Linux mappings across close and repeated open. The
focused `nix develop .#bindings --command just bindings::rust-lifetime 256`
reuses the existing installed-consumer/real-authority fixture with fresh
malformed inputs. It checks the failure marker, unchanged input progress and
empty resource after each case. The case argument is bounded to 1–1024 and
defaults to 128; this is a selected host schedule, not deterministic OS replay.
The installed consumer is reused across independent fixtures of at most 32 cases,
with each history verified before joined cleanup. An initial 256-case attempt in
one history exhausted the fixture's 64 MiB hot-storage quota during provisioning.
It did not complete and is not lifetime evidence for all 256 cases. Quotas remain
unchanged; the batched profile keeps this host-lifetime proof within its scope.
The corrected batched run passed all 256 cases across eight independently verified
histories using one installed consumer build, followed by joined cleanup.

Qualification of the correction is in progress. An initial corrected run passed
the raw-client regression but could not compile the Station consumer because
the shared `/tmp` filesystem ran out of space. That incomplete run is not a pass;
subsequent work uses an owned disk-backed `TMPDIR`.
The full corrected installed Rust client, Station, HTTP and gRPC suite then passed.

The follow-up record (archived)
retains hashes and separates incomplete, passing and unexecuted profiles.
Installed raw-client checks passed, including sixteen I/O/open/close repetitions
and override reuse/replacement/missing-file rejection. A compiling mutation that
removes library retention fails the mapping assertion immediately. The authority
(14 traces / 749 events), resource (204 / 3,958), shared-client (eight / 542)
and component (eight schedules) simulations passed with identical replay.

The first concurrent clean attempts at `4ae88b99` remain incomplete. Core passed
21 tasks, then its final state test observed `Conflict` while maintenance changed
the authority tail during a resource metadata read. The corrected maintenance
poll retries that fresh read within the existing ten-second deadline; the focused
state proof passed. Snapshot cuts and mutation retries are unchanged. Growth
exceeded its existing 240-second Station write deadline, experience received
`503 Unavailable` observing a Board operation, and bindings reported an unexpected
Python Station event. Runner assertions now preserve the actual unexpected event.
These results do not establish the complete ordinary gate.

An isolated clean bindings run at `2b9faa53` passed generated contracts, native
conformance and the complete Python, Node and Rust SDK tasks. The Rust task took
574.66 s. The lane then stopped in Ruby when a query turn correctly returned
`NeedsRecovery` with `AuthorityTimeout`; the fixture had assumed immediate
commitment. Ten later tasks were unrun.

The shared fixture now repeats explicitly unavailable reads and reconciles
transient dispatch/confirmation failures through the installed host API. It
checks that `next()` remains paused, saved bytes stay unchanged and observed
same-identity command attempts remain byte-identical. Recovery shares the existing
180-second progress deadline and has at most eight recovery/read steps. Other
outcomes still fail. A deterministic unavailable read and unavailable reply after
acceptance challenge those paths; the accepted schema input must be consumed once.
The focused Ruby schedule passed with both faults: one unavailable read repeated
and one accepted outcome reconciled, followed by all Table, IPC, revocation and
lifetime checks. `just check` passed with the corrected fixtures.

Board's focused query proof passed after its fixture learned to repeat only
unavailable observations of the same receipt within the existing 60-second
deadline. It does not prepare or submit replacement work. The isolated complete
growing-service proof also passed without code or deadline changes: Station write
took 71.616 s against 240 s, and query delivery took 149.820 s against 180 s.
Earlier timing failures remain separate evidence.

The subsequent clean growth lane at `dae70a38` passed 14 tasks, including query
delivery in 145.224 s and the complete gRPC streaming/restart proof. Its gRPC fault
fixture then reached its declared 60-second process work cutoff while preparing
the second call for the blocked-peer scenario. `DeadlineUncertain` correctly
prevented further ordinary work; that scenario's intended control challenge had
not begun. The remaining three growth tasks and four later lanes were unrun.
The cutoff scenario now uses a separate disposable disk installation after the
crash/revocation installation is joined. It declares a 120-second work lifetime
before spawning and verifies that the recorded work and settlement cutoffs stay
unchanged through preparation and closure. It starts the RPC in the final
30 seconds of that work window. The 10-second control-progress limit remains
unchanged; cold-spill evidence belongs to the preceding crash/revocation profile.
Expiry waits through the configured
10-second clock-error bound and requires `DeadlineExpired`, rather than accepting
any failed dispatch. This scenario declares the peer's existing 120-second block
window as its RPC timeout before preparing the request, and checks that both the
worker and remote RPC remain active when closure completes.

An initial isolated attempt failed the combined closure-duration/worker-alive
assertion before its operands were logged; the original operand remains
unattributed. Four diagnostic reruns passed, with closure taking 0.186–0.711 s.
Those passes precede the definite-expiry and active-peer assertions and do not
erase the earlier failure.

A full rerun then took 59.078 s just to prepare both calls in the fresh
installation; the worker exited before reaching the peer. This demonstrated
that separating installations alone did not establish the intended pre-cutoff
dispatch premise. The 120-second work window is selected before admission to
accommodate setup; the test still requires definite expiry, an active remote
call, bounded closure and permanent retirement.

The lifetime diagnostic initially used the execution-read selector after work
expiry, which correctly rejected input access even though closure had passed in
0.294 s with an active peer. It now uses public inspection for retained process
metadata. `just test::grpc-control` runs this isolated portion directly;
`just test::grpc-faults` still includes both crash/revocation and cutoff profiles.
The corrected focused proof passed in 133.06 s excluding compilation, with
closure in 0.181 s while the worker and remote RPC remained active. It verified
unchanged recorded cutoffs, exact `DeadlineExpired`, duplicate-closure rejection,
permanent retirement and pending-effect cancellation. `just check` passed with
the corrected fixtures and focused task registration.

The next combined proof passed all crash boundaries and dispatch revocation,
then failed while starting the separate control installation: MinIO returned
HTTP 503 to bucket creation after its health probe returned ready. Bucket creation
now retries only HTTP 503 using the same signed request and the original
30-second startup deadline. An injected 503 followed by real MinIO creation
passed; negative checks retained immediate non-503 failure and deadline exhaustion
under persistent unavailability.

The expanded deterministic profiles passed on committed sources. Authority and
resource reports identify `028e2f7b`; shared-client and component reports identify
`2b9faa53`, whose intervening change corrects the separate state API polling fixture.
All four retain clean-source identity, binary/oracle hashes and identical replay.

| Expanded profile                                   | Executed result                                                           | Simulation time |
| -------------------------------------------------- | ------------------------------------------------------------------------- | --------------: |
| Authority: 32 seeds, 128 steps                     | 38 traces / 5,293 events                                                  |       119.304 s |
| Resources: four seeds, every observed I/O boundary | 3,202 traces / 60,704 events                                              |     1,744.224 s |
| Shared client: 32 seeds, 128 steps                 | 36 traces / 6,490 events                                                  |       158.158 s |
| Components: 32 seeds                               | 128 schedules across Document, Exchange, query/refresh and runtime owners |        38.139 s |

The resource checker rejects corrupted values, input progress, outputs and views,
plus stalled and incomplete histories. The retained reports include the full trace
hash lists and actual fault counts. These in-process results preserve the existing
atomic-journal premise; disk durability and host scheduling use their separate proofs.

At committed `ee4770c9`, the complete clean bindings lane passed all 16 tasks in
7,096.414 s including setup. This includes every installed SDK, the ten-language
interoperability ring, finite models, SQL checks and gRPC publication faults. The
same revision's first clean growth attempt passed Arrow, pages and authority growth,
then exceeded the unchanged 180-second query-delivery limit in `growing-service`.
Station writes had passed in 217.453 s against 240 s. Successful delivery/turn
receipts continued until the query timeout; no correctness assertion failed, but
the cause remains unattributed. Other test workloads were active on the shared
host. This attempt does not establish the complete ordinary gate. A new clean
attempt uses the same source, workload and limits with CPU affinity 6–11 instead
of 16–31. That clean growth repeat passed all 18 tasks in 3,548.751 s including
setup. Station writes took 71.311 s and query delivery took 150.013 s. The full
gRPC fault proof passed with closure in 0.316 s while its worker and remote RPC
remained active. The HTTP proof passed sixteen sends, eight applications and two
cancellation requests. Both real connector examples passed. These two complete
lanes account for 34 tasks at the same implementation revision; experience,
launchers and core remain outside this draft checkpoint. The earlier growth
timeout remains an incomplete attempt with an unattributed cause.

During the bindings run, an external process removed the qualification worktree
and branch. The independent clean checkout and running tests survived. The
worktree and source checkout were restored at the identical commit, and open log
descriptors preserved the complete bindings log through completion. No test was
restarted or skipped. Earlier ignored logs, build outputs and private crash files
were removed with the worktree; their committed result summaries, embedded reports
and hashes remain in the follow-up record. This event is recorded separately from
test outcomes.

The next clean experience attempt at `ee4770c9` passes five tasks, then fails
Board query qualification on HTTP 503 `Unavailable` while reading query status.
The final Station launcher task does not run. This remains an incomplete lane.
Integration with main at `dca324f3` preserves its definition/layout cutover and
catalog/mutation proof registrations; the integrated ordinary inventory has
68 tasks. Earlier results do not qualify this changed source by inheritance.

The integrated Board fixture repeats only the same unavailable status,
description, page or Atlas read. It retains the existing eight-query/twelve-Atlas
attempt limits, the 60-second receipt window and 120-second result window;
individual read timeouts cannot exceed the remaining window. It never prepares
or submits a replacement mutation. A first focused run passes query operations,
then fails on an unavailable final Atlas read. After including that read in its
existing retry loop, the complete real Board proof passes. Expected denial,
expired cuts and malformed-command checks remain in that proof. Full `just check`
and generated binding checks also pass on the integrated development source.

The merged cold-store fixture passes temporary-unavailability recovery,
accepted-but-unavailable then already-owned recovery, foreign/malformed conflict
rejection, immediate denial and exhaustion of the original startup deadline.
Repeated attempts retain identical signed requests. A real owned MinIO bucket
also accepts repeated creation. These focused checks and the Board failure logs
are retained in the follow-up record; clean integrated qualification remains
separate. A fresh hosted check still does not start because GitHub reports the
account payments/spending-limit restriction.

The clean experience lane at `95ed6c72` again passes five tasks, then fails
when a retained stale Atlas position returns temporary HTTP 503 instead of the
required 409. The Station launcher and subsequent lanes remain unrun. A 503
does not establish stale-cut rejection. The observation helper now gives each
read one bounded retry loop, including reads with expected rejection statuses:
eight attempts for query/inspection reads and twelve for Atlas. It retains the
same URL, saved position, operation and request bytes; expected statuses and
`no-store` assertions remain mandatory. The existing receipt/result deadlines
still bound their reads, and mutations are never retried by this helper.

Eleven controlled response schedules pass, including unavailable-then-expired,
unavailable-then-denied, refusal to accept a successful stale-cut read, both retry
bounds, unchanged query identity, deadline exhaustion, receipt observation and
no mutation retry. The final helper also passes the complete real Board proof
in a separate checkout based on `95ed6c72`. The simulation checkout remains at
that unchanged commit while this fixture correction is validated; reports retain
their actual source identities. The follow-up record embeds the failed clean
attempt and controlled-check driver. Complete clean qualification of the final
fixture is still required.

At clean simulation source `95ed6c72`, the expanded campaigns repeat successfully:
38 authority traces / 5,293 events (121.605 s), 3,202 exhaustive resource traces /
60,704 events (1,835.258 s), and 36 shared-client traces / 6,490 events (164.360 s).
The component campaign now includes catalog and passes 160 schedules across five
owners in 55.894 s. Each report retains identical replay, source and tool/binary
identity. These are 72,487 events across 3,276 traces plus the separate component
schedules; they preserve the existing atomic-journal and host-scheduling limits.

Clean experience at `5fe3df66` passes all six Board/frontend tasks, including the
corrected Board query proof, then fails the Station launcher's unchanged
60-second Arrow-reply wait. The retained manager log shows the courier exiting
after repeated failed readiness probes; its inherited `restart: no` policy leaves
it stopped. This matches the manager's documented
[probe lifecycle](https://f1bonacc1.github.io/process-compose/health/).
Current public reads show consumed requester input with no recorded Arrow result.
Restarting the same courier completes that retained reply (16.689 s of subsequent
polling). No query is reissued and no authority or deadline is changed. The
original clean attempt remains failed; subsequent lanes did not run.

The native counter and Station topologies now restart the stateless courier
after failure with a one-second backoff. An owned proxy in the Station proof
refuses only signed delivery reads, preserving command bytes and all authority
checks. The proof observes a new courier PID and increased manager restart count
before releasing the fault, then requires the Arrow result within the original
60-second window. It passes with 292 refused reads and one replacement after
30.261 s, followed by the existing same-PID worker recovery, upgrades, Board and
persistent stop/start assertions. The proxy restores the original configuration
and joins its threads. The full ordinary gate still requires all five lanes at
the final committed source.

The counter launcher proof also passes with the new policy, including an explicit
courier stop that preserves its queued outbox until explicit restart, authority
restart, same-PID replacement and foreground cleanup. Full `just check` passes.
A negative control disables only the Station courier restart policy: the real
injected-outage proof fails at `Courier did not recover after failed readiness
probes`. The driver restores the topology and stops its owned failed installation.
This is detection of the removed lifecycle guard, not an unrelated build or
timeout failure. Final catalog and documentation checks pass separately.

Clean experience at `8b1be77e` passes all seven tasks in 516.624 seconds including
setup. Its Station launcher observes 292 refused delivery reads, one automatic
courier replacement after 30.284 seconds and the Arrow reply within the original
60-second window. The remaining ordinary lanes are separate until their full
completion records are available.

Hosted [run 36796408660](https://github.com/spoke-sh/transit/actions/runs/36796408660)
executes jobs; the earlier account restriction no longer prevents this run.
Experience fails its first task because its reduced Nix Python environment lacks
`jsonschema`. Bindings fails while restoring the Nix store with `No space left
on device`, before any test executes. These are failed qualifications. The CI
shells now include the validator from the existing lock, and disposable hosted
runners reclaim unused SDK space before cache extraction, including exact hits.
Self-hosted runners retain their software. Both corrected Python environments,
the full Board check in the reduced experience shell, `just doctor` and full
`just check` pass locally; hosted correction evidence remains separate.

Cost accounting also distinguishes the intentionally skipped documentation-only
job from the full matrix that already owns the documentation proof. Its regression
requires all five lane names before excluding that alternative job and rejects a
missing or skipped required lane. This correction does not convert failed jobs
or unknown cache transfers into budget qualification.

Clean core at `8b1be77e` then passes all 22 tasks in 1,160.532 seconds including
setup. Together with experience, this is 29 tasks at one revision. Growth passes
Arrow, pages and authority growth, then the Station caller exits with
`AuthorityTimeout`. This is not its outer 240-second timeout: the node records a
6.72-second successful turn followed by a failed page stage and request timeout.
The underlying provider delay remains unattributed. That attempt has 32 passing
tasks, one failed task and 35 unrun tasks; bindings and launchers do not execute.

The separate clean experience attempt at CI-setup commit `151772ac` passes six
tasks, then misses the Station Arrow reply's original 60-second window after the
injected courier outage. The manager replaces the courier, but node logs record
storage read/write failures, request timeouts and capacity refusals after release.
The original reply is later present without resubmission or manual replacement.
This later observation does not pass the deadline. Logs, process status and the
stopped installation remain retained; the cause of storage unavailability is not
established by these observations.

Hosted run `36796408660` executes synthetic merge `7ee3c04b`, combining PR head
`8b1be77e` with main `5c98499e`. Its core lane passes all 22 tasks in 1,196.95
seconds excluding setup. Growth passes seven tasks, then Docker exits 125 before
the combined Table fixture starts. A separate registry lookup confirms that its
pinned historical MinIO digest has no manifest. The run takes 1,762 seconds from
creation to completion and 4,366 aggregate runner seconds. The bindings log is
unavailable after its runner disk failure, so total restored bytes are unknown;
this failed run does not qualify a cost budget. Cost collection now preserves
available job measurements when another job's log is missing and distinguishes
fallback cache restores from a complete warm sample.

Hosted launchers fails its initial consumed/admitted assertion without recording
the row. Independent controlled scheduling reproduces a race in the original
observer: it samples process progress before the counter value, then returns the
old row when the turn commits between reads. The corrected helper samples the
value first and progress afterward, retaining the 30-second polling limit. Four
controlled cases pass, including stalled and metadata-only observations, and the
full native counter launcher proof passes from a short checkout based on
`151772ac`. The hosted row's original operands remain unavailable. An earlier
focused attempt in the long worktree path fails the explicit Unix-socket path
bound before launching the manager; that attempt is not lifecycle evidence.

At committed `151772ac`, all nine component mutations are detected by executed
assertions: Document conflicts/checkpoint floors, Exchange holds, refresh
generation, provider readiness and four catalog policy/receipt/inspection/cursor
guards. Compilation failures and timeouts do not count as detections.

Cold-store fixtures now start the same native MinIO output already used by the
local bundle. The former bundle definition and extracted shared Nix definition
resolve to the identical store path and binary hash; source/vendor pins and
`flake.lock` are unchanged. Actual startup, repeated owned-bucket creation and
the six controlled readiness/rejection cases pass. The first combined Table
proof with native cold storage proceeds past startup, then fails on
`StaleStateResource` in its progress observation. Main's focused correction
`88d7ab7d` supplies a progress-only query and prepares the mutation before holding
the snapshot read; these fixture changes are brought over without changing the
runtime or broadening the declared snapshot deadline.

The corrected combined Table proof passes in 45.231 seconds with two recovered
initialization receipts, 70 turns and a 0.547-second held snapshot. The native
cold-page proof passes write, recovery, checkpoint and trim recovery with 1,024
keys, 1 MiB of retained values, two resident pages and 20 persisted cold chunks.
The physical capacity proof reaches real ENOSPC after query acceptance and passes
finite control/shutdown and exact recovery in 18.62 seconds. Native-provider
lifecycle checks join the real child and remove its owned data, including failed
startup. Full `just check` and `just doctor` pass on the corrected development
source based on `151772ac`; the experiment record binds the changed source hashes.
Initial stale image imports and ambient-tool assumptions in CLI diagnostics are
retained as failed attempts and corrected before these passes. These focused
results do not replace committed-source clean or hosted qualification.

Discovery retains the exact thirteen commands and exploration arguments formerly
appended to ordinary bindings. The fault workflow now selects that campaign weekly
or on demand, with separate 3,600-second stage and 180-minute job limits. A real
runner-entry regression completes stage one, fails stage two deliberately and
requires incomplete evidence with no later execution. The larger ordinary job
caps permit measuring expanded inventories; they do not change task-local
deadlines or qualify the historical feedback budgets.

Clean experience at `1f76bf3b` passes all seven tasks in 523.220 seconds including
setup, with 292 courier read refusals, replacement after 30.276 seconds and the
Arrow reply within the original deadline. Core passes twelve tasks before its
package build is deliberately interrupted to integrate main at `2704c153` after
new PR conflicts. Its completion record remains false; growth, bindings and
launchers are unrun at that checkpoint. The stopped checkout retains evidence
and has no remaining owned processes. Hosted discovery run
[36801433218](https://github.com/spoke-sh/transit/actions/runs/36801433218) uses the
unchanged `1f76bf3b` source. Its subsequent completion is recorded below.

Integration preserves main's SQL console write/recovery cases and the controlled
missing-MinIO diagnostic environment. Full `just check` passes on the merged
development source. Clean qualification of the merged commit remains separate
from the superseded run.

The first merged combined Table attempt fails its 45-second console wait while
MinIO rejects cold writes with HTTP 507 `XMinioStorageFull`. The pinned provider
reserves 1% of its filesystem's total capacity; the shared 1.97 TB filesystem has
fallen below that reserve. Removing rebuildable outputs and dependencies from
stopped, owned qualification checkouts restores space while retaining source,
logs, proof records and database state. The same proof then passes in 65.916
seconds: 105 turns, two recovered initialization receipts, a 0.504-second held
snapshot and all added SQL-write interruption/recovery/cancellation cases. No
assertion, request deadline or provider capacity guard changes between attempts.

## Typed SQL parameter SDKs — 2026-10-01

Commit `ea2e0fa3` adds typed one-shot SQL compilation to Python sync/async,
TypeScript, Rust, Ruby, C, C++, Java, .NET, Erlang and Elixir. These methods
delegate to the existing shared neutral compiler and exact scalar codecs,
returning an owned ordinary bundle without snapshot acquisition or admission.
The isolated `feat/sql-parameter-sdk` worktree contains `origin/main` at
`21e9569c`; its rebase preserves author dates and introduces no conflicts or
source changes. The parent shared-compilation PR remains a separate dependency.

All ten SDK package builds pass, as do all ten independently installed codec
consumers. Full `just check` passes on the implementation subsequently committed
unchanged as `ea2e0fa3`; the later SDK-index documentation addition passes the
local-link check separately (5003 links in 505 files). Logs are
`/var/tmp/transit-sql-parameter-sdk-{build,installed-codecs,check,docs}.log`.

The installed signed recovery proof runs in the pinned bindings shell:

```sh
just test::unified-query -Doptimize=ReleaseSafe \
  -Dunified-sdk=python,node,ruby,rust,c,cpp,java,dotnet,erlang,elixir \
  -Dunified-source=kv
```

The same command selects `table` and `document` for their separate source
profiles. Each uses thirteen callers: native ABI, local port, Python sync/async
and the other nine SDKs. Successful UTF-8 and maximum-u64 LIMIT bindings,
ordinary SQL and explicit empty bindings produce the same canonical bundles as
their literal equivalents. A separately constructed Zig typed-plan fixture
supplies the recovery bundle's expected bytes. Empty/missing bindings and the
five wrong scalar types reject; compilation allocates no command sequence.
Node, Java and .NET clear the original input collection before awaiting the
result; C releases borrowed inputs and C++ resets bindings before inspecting
the returned bundle. Existing codec cases supply independent scalar coverage.

KV passes in **151.89 s** and Table in **151.17 s**, each with 41 rows, six
segments and 13,584 Arrow bytes. All callers verify completed results and reject
compilation after prefix revocation and resource retirement. The returned bundle
survives a lost upload response, exact original retry and worker/node/disk-store
restart. Bounds remain eight resident authority pages and an 8 MiB hot store.
Durations include fixture installation/provisioning and are not comparative
SDK throughput or compiler-latency measurements. Logs are
`/var/tmp/transit-sql-parameter-sdk-kv.log` and
`/var/tmp/transit-sql-parameter-sdk-remaining-sources.log`.

The first Document command fails during provisioning, before compilation or
SDK recovery, with `AuthorityUnavailable`. Its retained log records MinIO
`507 XMinioStorageFull` at the minimum free-drive threshold and Ursula cold-store
backpressure. An audit finds no live process, mapping or file reference to the
two preceding parameter worktrees' generated `.zig-cache` directories. Removing
only those disposable caches raises available disk space from 18 GiB to 27 GiB;
source, probe archives and retained failure evidence are untouched. The unchanged
Document command is rerun with log
`/var/tmp/transit-sql-parameter-sdk-document-retry.log`. This rerun passes in
**680.72 s**, including **591.82 s** provisioning, with 12 rows, two segments
and 9880 Arrow bytes. All thirteen callers agree on parameter compilation,
results and current denial/retirement; the saved bundle survives exact upload
retry and worker/node/disk-store restart. The Document fixture retains its
existing 64 resident authority pages and 8 MiB hot store. The first failure
remains failed and separate from this successful rerun. No deadline, resident
bound, quota or storage threshold is increased.

Committed-HEAD `just ci-clean --lane core --work-root /var/tmp` passes all
**22 tasks in 810.40 s** at `ea2e0fa3`, including the seeded simulation layers,
ABI checks and real disk recovery. Completion, revision, exact inventory/order
and successful exits are audited in
`.cache/ci/clean/ea2e0fa3e49c-transit-ci-kdrwe6rc/core{,.meta}.json`; log
`/var/tmp/transit-sql-parameter-sdk-clean-core.log`. Later changes only record
this proof and milestone status. This is a core-lane result, not an all-five-lane
clean pass or a new performance improvement. Parent compiler-performance
failures and the earlier Document storage-pressure failure remain recorded
independently.
CLI binding inputs, named PREPARE/EXECUTE lifetime, file-source binding and
saved-template compatibility remain outside this SDK increment.

Hosted run `36894762494` at documentation checkpoint `074dc5d5` executes no jobs.
Both failed-job annotations identify account billing/spending-limit refusal;
the remaining jobs are skipped. This is not a hosted code/test failure or a
hosted pass. The submitted SDK PR can be reviewed independently of the
remaining complete clean-lane and milestone qualification.

### Semantic mutation conflict witnesses

The mutation status records the actual attempted key and one-based input row at
atomic rejection. Package tests cover each of three conflict positions, signed
int64 extrema, rollback of earlier proposed rows, exact replay after deleting
the conflicting stored row, recovered state and rejection of truncated or
inconsistent status records. The independent mutation byte fixture includes the
148-byte status. Native/port/CLI conformance checks the witness after lost replies.

On 2026-10-02, the diagnostic implementation working tree passed `just check`,
`just bindings::node-check`, the query package's `zig build test`,
`just test::query` and `just test::table-mutation`. The latter completed in
29.571 seconds with 3,340 reads, 99 turns, at most four mutations per turn,
256-byte native values and eight resident authority pages; all seven profiles
passed for native, port and CLI callers. All ten SDK packages built in the
bindings shell. These results do not establish the remaining diagnostic matrix
in [Diagnostics](../../../contracts/DIAGNOSTICS_V1.md); installed SDK witness qualification is separate.

The same working tree subsequently passed the installed mutation witness proof
for Python (sync and async), TypeScript/Node, Rust, Ruby, C, C++, Java, .NET,
Erlang and Elixir. Every caller preserved key `2`, input row `2` and atomic
rejection through lost-reply recovery; subsequent apply/cancel controls retained
that exact outcome. The first attempt exhausted the shared `/tmp` filesystem
while compiling Rust and is not counted as a pass; the completed run used a
private directory under `/var/tmp`.

The combined Table query/writer proof passed in 32.712 seconds with the console
presentation change. It checks one human conflict diagnostic, empty human
result stdout on rejection, exact key/row in JSON, `.status` parity, absence of
uncertainty advice on terminal rejection, rollback and existing interruption,
lost-reply and policy-race recovery schedules.

### Compiler and file diagnostic attribution

On 2026-10-02, `just check` and `just test::file-query` pass with owned compiler
binding context and file failure attribution. The focused rerun of
`just test::unit test::cli-diagnostics test::file-query` passes after adding
submitted-mutation context. The CLI suite executes 456 cases; the file suite
executes 184. New cases check unknown subjects, qualifiers and scopes, exact
expected/supplied types, bounded supplied literals, repeated INSERT keys and
both input positions. Multiple-file runtime failures identify the failing
file, logical record, record-start byte and field after LIMIT 0 or LIMIT 1;
partial output has no completion marker. Byte columns and logical records are
not presented as Unicode display columns or physical file lines.

These results establish local compiler and file presentation. They do not
establish retained runtime query causes or a shared structured diagnostic
contract across remote adapters; those remain in M44.

### Offline application diagnostic attribution

On 2026-10-02, `just test::application-grammar` and `just test::unit` pass with
owned application compiler diagnostics. The real binary proof checks unknown,
duplicate and wrongly typed options; missing theme/binding targets; invalid
query budgets; reserved paths; and embedded SELECT errors. SQL failures name
the member/option and actual outer source position, with nested coordinates
explicitly relative to the binding SQL. JSON semantic failures retain member
context without fabricated SQL spans. Rejections leave stdout empty and do not
print stack traces or arbitrary option values. Allocation-failure checks now
exercise diagnostic provenance allocation, and a unit renders failure context
after the input and parser arena have both been freed.

### Retained finite-query failure evidence

The current v1 records and replies retain a stable `QueryFailure` code and
admission/execution stage. Page, segment and result-byte failures carry the
actual limit and required work. Unit tests cover all three budget dimensions,
rollback before closure, first-failure preservation during repeated closure and
cleanup, authenticated requester replies, retirement, full-width counters,
malformed/truncated records and rejection of absent witnesses. Board lenses and
neutral SDK statuses preserve these fields. Extreme-float compiler diagnostics
also pass bounded rendering tests for maximum finite values, subnormals and
negative zero without replacing the original type mismatch.

On 2026-10-02, `just test::unified-lifecycle kv` passes in 72.51 seconds. The
installed all-ten-SDK run of `just test::unified-query -Doptimize=ReleaseSafe
-Dunified-source=kv -Dunified-lifecycle=true
-Dunified-sdk=python,node,rust,ruby,c,cpp,java,dotnet,erlang,elixir` passes in
230.08 seconds, including 91.86 seconds of provisioning. Python sync/async,
native, port and the ten SDKs provide 13 caller variants. All observe the exact
same result-byte failure after its committed receipt is hidden, an identical
retry, source/requester/node/disk-store restart and request retirement. The
schedule also preserves current-denial, cancellation, prefix-revocation and
cleanup checks. This run's successful query returns 41 rows in six segments and
13,584 Arrow bytes with eight resident authority pages and an 8 MiB hot store.
The new failure recovery schedule is executed for KV; it is not new installed
Table/Document failure-witness qualification.

All ten SDK packages build against the replacement contract definition. The
cutover regenerates native/ABI/browser schemas, SDK resources, signing and
record fixtures together. Earlier check attempts detected stale signing/size
fixtures and a browser status fixture missing the required field; corrected
checks do not count those attempts as passes. No fallback accepts the prior
query record or synthesizes a missing cause.

The final `just check` passes on 2026-10-02, including Zig and frontend checks,
generated-contract checks and the public documentation build. A final focused
run passes all 184 file-query cases, the application grammar/documentation
proof and the combined Table query/writer proof in 32.882 seconds. The combined
proof records 4,637 reads and 83 turns while retaining the four-mutation,
256-byte-value and eight-resident-page bounds. No installed SDK variants were
selected in that combined Table run. These checks run in the pinned Nix
environment; no push or clean committed-HEAD qualification is claimed.

### Prepared parameter diagnostic provenance

On 2026-10-02, `just test::unit test::cli-diagnostics` passes (456 real CLI
cases). Added unit evidence checks parameter indices, original repeated-use
offsets, incompatible type requirements, missing indices, expected/supplied
counts, bounded escaped values, canonical scalar encoding and changed schema
fingerprints. Context resets between failed operations and owns its bytes.

`just test::console table` passes in 323.08 seconds, including 289.01 seconds
for the console schedule. New negative cases execute through both interactive
and durable compilation: type, count and gap failures disclose the right
parameter context while making no submission and leaving the saved recovery
file unchanged. The same run preserves exact binding-file recovery after input
change/deletion, worker/node/store restart, current denial, PTY and signal
schedules, and explicit private-CA TLS checks. It returns 41 rows in six segments
with eight resident authority pages and an 8 MiB hot store. No installed SDK
variants are selected by this run.

### Flight and ADBC diagnostic projection

On 2026-10-02, `just test::flight` passes against the pinned PyArrow 23.0.0 and
ADBC Python/C clients. Schema and execution failures identify unknown columns
and exact expected/supplied types, and a supplied `50% discount` literal survives
standard gRPC percent encoding. Compile failures consume no native sequence.
The existing success workload still returns all 41 exact int64/null rows.

A separately provisioned source makes checked SUM overflow. PyArrow and ADBC
both observe the saved `query.arithmetic_overflow execution #2`; identical retry
and gateway replacement preserve that original failure. Revoking current source
access suppresses the retained detail. Unit tests exhaust all 58 saved failure
codes through explicit gRPC status mappings and fit maximum-width measured
budgets, including retirement, within the existing 128-byte message bound.
Escaped compiler detail truncates explicitly; it does not enlarge the transport
message bound or include SQL excerpts. This is exception-message projection,
not a general structured Flight diagnostic extension.

`just check` and `just test::packages` pass after the parameter/Flight changes.
No new installed SDK mutation/query proof is claimed for these local compiler
and Flight renderer increments; the retained-outcome SDK evidence above remains
the executed qualification for that contract.

### Declarative diagnostic source inventory

On 2026-10-02, `just test::diagnostic-inventory` passes over 476 production owner
files, 2,535 owner/error pairs, 286 named enum/union surfaces and 153 checked
SQL/application grammar productions. The lexical checker excludes comments,
strings and inline tests. Its negative checks detect a newly added error, another
occurrence of an existing error, a changed outcome tag/import and a changed
grammar alternative. `just check` includes the inventory drift gate.

This check establishes a reviewed source surface, not whole-program reachability
or semantic diagnostic completeness. Propagated external errors, mapping quality,
failure witnesses and executable negative-case coverage require their owning
contracts and proofs; recording an inventory does not pass those gates.

### Neutral diagnostic contract

On 2026-10-02, the standalone `transit-protocol` package tests and the generated
diagnostic-schema check pass. The independent JSON fixture retains signed and
unsigned 64-bit extrema after input ownership ends. Allocation-failure testing
exercises every decoder allocation; negatives reject missing mandatory fields,
noncanonical numeric strings, mismatched outcome evidence, forbidden recovery
actions and withheld details containing values. Digest arrays preserve their
declared JSON shape. UTF-8 truncation preserves whole code points. Documentation
validation passes 5,057 links across 508 files.

These tests establish the neutral value's construction/decoding rules. They do
not establish domain mapping completeness or delivery through every adapter.

### Structured owner projections and script attribution

On 2026-10-02, standalone Fuze and query package tests pass. The SQL registry
checks unique stable codes and typed binding projections; all 58 retained query
codes project valid evidence/actions through denied, rejected and retired phases.
Maximum-width measured counters retain precision. These are owner-value tests,
not yet ABI/SDK structured-envelope parity.

`just test::cli-diagnostics` passes 458 real CLI cases. New script and stdin cases
complete `.show`, then fail SQL binding, checking the second statement, completed
command count and absolute source line/column after comments, CRLF and Unicode.
Existing machine stdout, timing order, PTY/color and no-send negatives pass.

### Interactive runtime evidence

On 2026-10-02, standalone Fuze and query package tests pass. New cases verify
later-page scan ordinals, eager predicate instruction order, SUM intermediate
overflow despite a later compensating value, cancelled evaluation clearing old
detail, owned binary/signed keys and KV decoder length evidence. Diagnostic JSON
round trips exclude stored value payloads and preserve the frozen binding hash.

`just test::interactive-query --source all` passes for Table, KV and Document,
including measured page/segment/result-byte failures, incomplete output prefixes,
zero durable updates, cancellation, broken output and current access denial.
The Document run completes in 215.88 seconds. After extending current-access
checks to budget enrichment, `just test::interactive-query --source kv` passes
again in 3.24 seconds. Its new corrupt-input schedule uses the actual owner to
write invalid UTF-8, then verifies an eager second-atom failure, exact binary key,
column, scan row and decoding reason. Revocation at the enrichment read suppresses
key/basis details; restoring permission and repairing the source recovers ordinary
queries. Runtime enrichment does not reconstruct a row from a later read.

These are volatile interactive witnesses. Durable storage/restart qualification
for runtime row/expression context is not established by this increment.

### Durable runtime witnesses and neutral query status

On 2026-10-02, the query package's 84 tests pass with a compact owned runtime
witness. A failed source job is 255 bytes and requester failure status is 200
bytes. Tests retain the exact SUM overflow row after live values change,
recompute identical evidence after rollback, atomically close within the existing
turn bound, release the retained pin and preserve the witness through retirement.
Malformed flags/padding, old 24-byte failures and truncated records reject.
Maximum-width keys, row ordinals and measured counters survive owned JSON
projection; long column/KV-key prefixes carry explicit truncation markers.

`just check` passes, including generated contracts, package checks, frontend
validation and the documentation site build. `just test::cli-diagnostics` passes
458 real command cases. Installed C and C++ raw-client schedules also pass,
including a foreign-definition link rejection before exchanging SDK structs.

The all-ten-SDK lifecycle schedule is extended to compare complete diagnostic
status on KV, Table and Document. Its KV runtime case repairs the source after
failure and checks that the original witness survives exact lost-receipt recovery,
node/store restart and retirement. The initial run exhausted `/tmp` while
compiling an isolated Rust consumer; a disk-backed rerun found missing `const`
support in SDK schema validators. Ruby, Java, .NET and BEAM validators now check
that keyword. The corrected complete installed schedule remains in progress at
this source commit; these unit and build results do not certify that schedule.

### Installed runtime witness recovery

On 2026-10-02, the complete installed lifecycle schedule passes for KV, Table and
Document with all ten SDKs, Python asynchronous calls, native ABI and local port
(13 callers). The result-byte failure envelope remains identical across a lost
receipt, exact retry, source/requester/node/disk restart and retirement except
for the observed lifecycle outcome and its recovery actions. The KV predicate
case also preserves the first failing row/column/instruction, binary key, binding
and invalid-UTF-8 decoder reason after the live input is repaired. Table completes
in 200.35 seconds and Document in 618.53 seconds. The command uses the pinned
`ci-bindings` shell and disk-backed `TMPDIR=/var/tmp`; its exit status is zero.
Log: `/var/tmp/transit-witness-all-sdk3.log`. These results supersede the pending
installed schedule recorded above; they do not certify unfinished adapters.

### File scalar and runtime failure witnesses

On 2026-10-02, the Fuze package tests and `just test::file-query` pass. The real
CLI proof executes 190 cases, including nested decimal inexactness, explicit
NULL/missing rules, inferred-prefix failures after LIMIT, a failing second eager
predicate atom, COUNT over a type-error cell and checked SUM overflow. Runtime
binding/plan hashes equal the output header; failure emits no completion marker.
Owned unit evidence covers escaped/truncated JSON Pointer paths, scalar preview
ownership, map keys, tagged unions, array lengths, interval components and
clearing tolerated conversion evidence. The existing allocation-failure and
192 MiB source under a 96 MiB address-space-limit schedules also pass.

### Compiler categories and writer-scoped inspection

On 2026-10-02, `just test::unit test::cli-diagnostics` passes, including 459 real
CLI cases. Structured compiler categories distinguish unsupported constructs,
constraints, changed sources and bounds; scalar previews mark truncation in the
machine availability field. UPDATE/DELETE and INSERT tests identify the actual
failing column, expected type, supplied scalar and attempted key. Completion
fixtures cover writer schema and SQL help topics.

`just test::table-query-writer` passes in 40.016 seconds. The console's
`.schema writer` reads its authorized writer metadata without creating recovery
work. Unknown writer columns/sources direct users to that scope. Current writer
revocation denies the inspection without output or changes to the saved recovery
file. The existing lost-receipt, interruption, policy-race, cancellation and
four-mutation/256-byte-value bounds continue to pass. Logs are
`/var/tmp/transit-compiler-scope-check.log` and
`/var/tmp/transit-compiler-scope-writer.log`.

### Source policy/schema witnesses and byte-path coordinates

On 2026-10-02, `just check` passes after the source-witness definition cutover,
including reflected contracts, signing fixtures, SDK schema resources, frontend
validation and the documentation build. The query package's 87 tests pass.
Missing/disabled/changed source policies retain the original expected and
observed revisions without reopening a denied request publication. A changed
Table schema retains both hashes across rolled-back proposals, repair and
retirement. Source jobs remain 255 bytes; requester failure status remains 200
bytes. Owned witness codecs reject malformed shapes, flags and padding.

`just test::unit test::cli-diagnostics` passes with 460 real CLI cases. A script
with a non-UTF-8 filename executes its first command, reports the later SQL
failure at the correct absolute position, and labels its escaped byte path.
Partial/malformed byte escapes reject at diagnostic validation. The first
installed-SDK rerun encountered a stale Python wheel; the new authority rejected
its previous definition at the initial metadata read. All installed artifacts
were rebuilt. The corrected KV lifecycle run passes across native, port and
all ten installed SDKs (13 caller variants). A real policy change after signed
preparation rejects source admission with the original allowed/requested page
budgets, 999/1000. All callers retain the exact diagnostic through node/store/
worker restart, retirement and restoration of the live policy. The ordinary
lifecycle schedules pass afterwards. The first budget fixture was rejected by
local preflight before source admission and was replaced with this race.
Logs: `/var/tmp/transit-source-witness-full-check.log`,
`/var/tmp/transit-source-witness-check.log` and
`/var/tmp/transit-source-witness-installed-kv2.log` (failed fixture) and
`/var/tmp/transit-policy-race-proof2.log` (passing corrected run).

### Query caller attempt diagnostics

On 2026-10-02, `just test::unit` and the standalone query package tests pass
with native query attempt diagnostics. The native boundary test compares local
foreign-command rejection with an actual failed connection after explicit
submission: the former is `not_submitted`, while the latter retains `unknown`
and the exact sequence recovery target. Query tests retain EXPLAIN's original
unknown-column subject and byte offset and verify that denied metadata access
produces no binding witness. Unknown causes are internal; failed status reads
produce no terminal query outcome. These component checks do not establish
SDK exception retention. Logs: `/var/tmp/transit-api-diagnostic-root-unit.log`
and `/var/tmp/transit-api-inspection-unit.log`.

### SDK exception diagnostics and exact recovery

On 2026-10-02, the installed KV lifecycle proof passes across all ten SDKs and
native/port callers (13 variants). Invalid parameter counts, missing binding
interfaces and wrong scalar types produce identical complete diagnostic envelopes,
with local no-send evidence and no resume action. Each caller receives a lost
reply after a committed native send, retains the original diagnostic and exact
sequence, then retries identical saved bytes and obtains the original receipt.
Rejected cancellation input for an absent namespace creates no query outcome.
The retained runtime/policy failure, restart, retirement, denial and cancellation
schedules also pass. The log is `/var/tmp/transit-sdk-exception-installed3.log`.
The preceding run stopped because the test controllers did not expose generic
command preparation; the corrected schedule prepares centrally and imports the
same signed command through each public typed caller before testing submission.

`just check`, `just test::unit` and `just bindings::node-check` pass after the
SDK definition cutover. The native validator rejects foreign definitions,
oversized envelopes and unsafe outcome/action substitutions. TypeScript checks
owned detail, malformed shapes, foreign definitions and status-6 precedence.
Python boundary injection checks malformed JSON/UTF-8 and unsafe recovery actions
without losing primary uncertainty or saved bytes. Rust unit tests verify
optional validation failure and exclusion of detail from Display/Debug. These
are boundary/component checks, not an independent semantic validator in every
port SDK. Logs: `/var/tmp/transit-sdk-exception-check.log`,
`/var/tmp/transit-sdk-exception-units.log`,
`/var/tmp/transit-sdk-exception-validation.log` (TypeScript passed; the initial
Rust invocation lacked its native artifact directory), and
`/var/tmp/transit-sdk-exception-boundary.log` (corrected Rust invocation passed).
The subsequent full default-shell check also passes in
`/var/tmp/transit-sdk-exception-final-check3.log`. Native classification is
independent of optional detail construction; allocation failures keep their
original status and cannot become syntax failures.
The final root unit run also passes with worst-case escaped JSON size validation:
individually bounded fields cannot produce an envelope exceeding 32 KiB.
Log: `/var/tmp/transit-diagnostic-escaped-bound.log`.

### Board semantic diagnostic transport and presentation

On 2026-10-02, `just test::unified-ingress table` passes with original compiler
subjects and absolute EXPLAIN positions through the real HTTP host and embedded
browser. Unsupported catalog syntax and missing columns remain local no-send
failures. The browser displays their semantic codes, subjects, location and
outcome without issuing submissions. The existing lost-reply schedule retains
identical signed bytes; Live draft recovery after reload, current denial clearing,
competing instances, active quotas and worker/node/disk restart all pass. The
run uses native/port callers; no installed SDK variants were selected. It reports
41 rows, six segments, 13,584 result bytes, eight resident authority pages and
45,355,008 bytes combined Board RSS; total runtime 225.43 seconds.
Log: `/var/tmp/transit-board-diagnostic-ingress3.log`.

The preceding integration runs stopped at an obsolete coarse-error expectation
and then at a fixture namespace reused by the parameterized shell schedule.
The corrected Board fixture uses fresh identities and preserves shell history.
`just check` passes, including root units, generated-contract checks, 460 CLI
cases, browser component/type checks and documentation build. Browser boundary
checks reject foreign definitions, malformed Unicode, oversized/contradictory
optional detail, unsafe recovery actions and status/outcome disagreement without
changing the transport retry rules. Rendering treats text as text and creates no
action buttons. Logs: `/var/tmp/transit-board-diagnostic-full-check3.log` and
`/var/tmp/transit-board-diagnostic-status-check.log`. This does not establish
application-editor, reactive-adapter or every inspection error mapping.

### Mutation rejection evidence and owner projections — 2026-10-02

`just test::unit` passed the mutation/catalog owner changes. Mutation rejection
records preserve the rejecting policy revision, permission mask or declaration
fingerprint in a 192-byte status, within one native value and the existing four
mutation slots. Real admission tests assert the revoked-policy and excluded
operation witnesses, descriptor repair followed by store reconstruction and exact
replay, and signed-extreme conflict keys at each of three input positions. The
shared projections preserve outcome and recovery actions after those changes.
Catalog tests assert applied and all three conflict receipts, exact replay and
separate control/input dispositions. Rejected inputs never acquire invented
mutation/catalog operation identities or cancellation instructions.

Independent Python fixtures additionally encode all eight mismatch-witness kinds;
codec checks cover every truncation, canonical absent slots and inconsistent
status/witness combinations. Those fixture projections establish codec coverage,
not execution reachability for every kind. Installed SDK and disk-backed proof
coverage for the new mismatch witnesses remains separate from these owner tests.

`just check` then passed the current-definition cutover, generated contract and
binding drift, owner tests, 460 real CLI diagnostic cases, TypeScript/browser
component suites and documentation build (5,062 local links). All eight witness
fixtures and their malformed-record checks ran in this full check. The lexical
inventory gate was updated explicitly; it remains separate from semantic case
completeness. `ci-clean` has not yet qualified this increment.

### Mutation and catalog caller-attempt diagnostics — 2026-10-02

`just test::unit` and `just check` passed the native compiler/attempt projections.
Real catalog ABI calls, with an unavailable configured endpoint, retain the
original column and byte offset for invalid key/nullability and duplicate-name
failures, column-count evidence and the unsupported KV declaration category.
Both write ABIs distinguish malformed local saved commands from a failed
validated send, preserving unknown outcome, signed sequence and exact-resume
instructions. Classification does not depend on allocating optional detail.

Installed consumer controllers now retain optional error envelopes for all ten
language SDKs. Their mutation/catalog schedules assert compiler context and
lost-reply recovery detail; installed execution is tracked separately from the
unit/full-check result above. The catalog installer selects the pinned 0.2.0
wheels explicitly when unrelated older artifacts remain in the local cache.

The installed mutation and catalog schedules then passed with Python sync/async,
TypeScript, Ruby, Rust, C, C++, Java, .NET, Erlang and Elixir, plus direct native
and port callers. All 13 structured-error consumers retained exact compiler
codes/context and unknown-send sequence/actions, then recovered the identical
saved request after caller replacement. The existing CLI participated in the
ordinary recovery profiles; its structured error stream remains a separate gate.

The mutation run completed in 220.707 seconds with 330 turns, 99 lost caller
receipts and 100 total lost receipts, eight resident authority pages, at most
four mutations and 256 bytes per native value. It retained the original conflict
witness, atomic rollback, all seven caller profiles, upload cancellation,
writer/node/store recovery and current read denial. The catalog run completed in
117.447 seconds after 60.164 seconds of SDK installation, with 17 lost caller
receipts and three lost writer receipts; all owned children joined, with no
cleanup failures. It retained exact creation receipts and metadata after
owner/node/store replacement, and preserved native/catalog policy revocation.
These executions qualify the projections in `e75e092e`; the mutation run started
from the same code before that commit was made. Neither execution replaces the
final committed-HEAD `ci-clean` gate or the issue's full semantic inventory.

### Offline application JSON diagnostics — 2026-10-02

`just test::application-grammar` passed with both human and
`--diagnostics=json` output for every existing accepted/rejected grammar and
model fixture. Successful model/SQL output matched byte for byte. Failures
emitted one JSON stderr record, no model prefix, `not_submitted` evidence and no
resume/cancellation action or unrelated option value. Additional real compiler
cases verified encoded non-UTF-8 file paths, missing files, malformed JSON,
separate parent and nested-SELECT coordinates, and `/dev/full` output failure
with `completion: false` and no stale member attribution. The shared path helper
retains the existing bounded UTF-8/byte-path representation; no wire shape changed.
This focused execution does not replace the final full check and clean-HEAD gate.

### Main CLI structured diagnostics — 2026-10-02

`just test::unit test::cli-diagnostics` passes with 481 real command cases.
The JSON stderr cases check original argv ordinals, compiler subjects, absolute
UTF-8/CRLF script positions and completed-command counts, independent timing
records, offline catalog column positions, encoded byte paths, late conversion
failures with LIMIT 0/1, exact runtime/budget evidence, UTF-8 preview truncation,
`/dev/full` output failure and byte-identical successful result stdout. CLI owner
units check that optional rendering failure preserves the recorded rejected
outcome/cause and that selecting a query ID alone does not invent saved intent.
Log: `/var/tmp/transit-cli-json-final.log`.

`just test::file-query` passes its 190 actual file cases. The full `just check`
also passes, including 5,065 documentation links, schema/binding drift, browser
checks and the site build. These runs precede the final focused refinements to
artifact operation attribution, absent send evidence and rendering fallback;
the final root unit/CLI run above includes those refinements. Logs:
`/var/tmp/transit-cli-json-check1.log` and
`/var/tmp/transit-cli-json-full-check.log`.

The default mutation and catalog proofs now consume CLI JSON errors alongside
native and port errors. They pass shared compiler witnesses, identical signed
sequence after lost replies, caller replacement, current-denial gates and disk
recovery. Mutation reports 36.173 seconds, 99 turns and 22 lost caller receipts;
catalog reports six lost caller receipts and three lost writer receipts, with
no cleanup failures. No installed SDK variants were selected for these runs.
The combined query/writer proof passes in 40.272 seconds with 84 turns. It
checks an actual second-row conflict's key, column, name, zero affected rows and
terminal recovery actions in the console envelope, plus the existing atomicity,
interruption, policy-raced input rejection and cancellation schedules. These
runs precede the final focused refinements noted above. Log:
`/var/tmp/transit-cli-json-recovery3.log`.

The first two recovery invocations stopped at task invocation errors (a missing
recipe, then variadic arguments consuming subsequent task names); they did not
execute the intended integration proof. The successful invocation runs the
three `just` recipes separately. Clean committed-HEAD qualification remains a
separate gate.

The subsequent Table unified-shell proof passes both ordinary SQL and parameter
file recovery after revocation while a signed command is pending. It verifies
that `.bundle` and `.pending` remain byte-identical, `.new` cannot replace that
work, and restoration/retry after shell replacement uses the original identity.
Current denied result reads stay denied instead of becoming namespace loss.
The disk-backed proof reports 102.56 seconds, 41 rows, six segments and eight
resident authority pages; no installed SDK variants were selected. Command:
`just test::unified-query -Doptimize=ReleaseSafe -Dunified-source=table -Dunified-shell=true`.
Log: `/var/tmp/transit-cli-json-legacy-recovery.log`.

### Flight binary diagnostic details — 2026-10-02

`just test::flight` passes with the optional `transit-diagnostic-bin` trailer.
PyArrow middleware and installed Python/C ADBC consumers decode the shared JSON
envelope directly from binary metadata. Compiler cases retain column, scalar
type/value and byte location without consuming the native sequence. Saved SUM
overflow retains its original operator, column, source basis and incomplete
result through exact retry and gateway replacement. Python ADBC receives the
same envelope; current revocation suppresses the stored witness. Log:
`/var/tmp/transit-flight-detail-proof3.log`.

`just test::flight-faults` passes after the final gateway refinements. A dropped
native receipt retains the unknown outcome, first statement sequence, actual
upload sequence and exact-recovery actions in the envelope. The existing
authority/lifecycle schedule passes pooled authentication, sequence conflicts,
ticket scope/expiry, revocation after a real returned batch, interrupted fetch,
bounded concurrent streams, stalled HTTP/2 credit, malformed frames, and retained
results after gateway/worker/node/store restart. The reported finite-query time
is 35.45 seconds; observed gateway RSS is 76,500,992 bytes. Log:
`/var/tmp/transit-flight-detail-faults2.log`.

The first fault run stopped because its incomplete `DELETE FROM items` fixture
expected unsupported syntax rather than a parse failure. The corrected fixture
checks both incomplete DELETE and a valid DELETE rejected by the read-only
Flight interface. Two earlier ordinary runs stopped at test assumptions about
quoted scalar previews and ADBC's byte-valued detail keys; neither is counted
as a passed proof.

Final root unit tests pass exact maximum-width numeric evidence, bounded
metadata encoding with adversarial escaped paths, explicit unavailable context,
and all three source-policy budget dimensions. The main Flight run above
precedes the final policy-budget/native-rejection refinements; the final fault
and root unit runs include them. Log:
`/var/tmp/transit-flight-detail-unit-final.log`.

Full `just check` passes for this Flight increment, including 481 real CLI cases,
generated-contract and inventory drift checks, frontend tests and the public
documentation build. Log: `/var/tmp/transit-flight-detail-check.log`.

### Owned write status diagnostics across SDKs — 2026-10-03

Neutral mutation statuses and catalog receipts/dispositions expose their shared
owner diagnostic. Mutation input reads return the complete retained disposition,
including exact native input and payload commitment, instead of a reason alone.
The C/C++ structures, all ten SDK models, generated contracts and signing fixtures
use a coordinated current-definition cutover. Ruby copies and freezes nested
write diagnostics; C validates and owns bounded inline diagnostic JSON.

Executed `just test::table-mutation` with Python, Node, Ruby, Rust, C, C++, Java,
.NET, Erlang and Elixir selected: **passed**, 213.734 seconds. Every installed
caller compares complete terminal diagnostics with the native projection, checks
the actual duplicate key/row and zero affected rows, and reads an unsealed APPLY
input rejection without treating its still-active upload as terminal. Original
status/disposition evidence survives node/store restart; current revoked grants
deny later reads. The seven mutation profiles retain exact lost-reply recovery.
After the Ruby copy fix, `just test::table-mutation --sdk ruby` passed again in
53.715 seconds, including native, port and CLI profiles.

Executed `just test::catalog` with the same ten SDKs: **passed**, 132.280 seconds.
All callers exercise name/object/Table conflicts and compare the shared owner
projection, preserve successful receipts, and reject status reads after policy
or native-grant revocation. Native/port/SDK callers compare the complete retained
input-denial diagnostic and its payload commitment after restoration. CLI input
recovery uses its own original private artifacts. The metadata matrix also
checks separately copied stale/foreign CLI page artifacts; original pages and
signed commands stay byte-identical. Earlier attempts stopped at stale fixture
shapes, Ruby diagnostic aliasing, a Java fixture import warning, and CLI artifact
probe assumptions; none is counted as a passing proof.

All SDK packages build. Root units (including the independently constructed
catalog neutral fixture), Python type checks, TypeScript checks and full
`just check` pass. The full check preceded the final Ruby copy/test-fixture fixes;
the installed reruns above include them. Complete semantic inventory coverage and
the final committed-HEAD `ci-clean` remain separate gates.

### Application host and editor diagnostics — 2026-10-03

`Host.runDiagnostic` preserves original compile/format context and records the
actual signed-command dispatch boundary. Local request/scope/digest rejection
cannot become an uncertain send. Unknown forwarding retains exact sequence and
request digest; native rejection and failed status reads do not become terminal
publication outcomes. Pure continuation projections explicitly label supplied
observations as caller facts. The browser owns and validates optional detail while
preserving the primary HTTP error and pending signed operation.

Executed application package units, shared browser client tests (10 cases), Board
frontend checks/types/tests (38 cases), and `just test::application-grammar`:
**passed**. Cases include missing revision/foreign graph reference, full-width
publication identities, local digest rejection, denied reads, malformed optional
detail, and stale member/option attribution at a subsequent statement. The parser
now locates the failing keyword instead of inheriting the preceding member.

Executed `just test::application-browser`: **passed**, browser schedule 53.6
seconds. Real HTTP checks cover invalid request shape, original compiler detail,
host operator denial, native signature rejection and a changed request digest.
An owned proxy loses an actual successful native reply; the host returns
`application.send_unknown` with the exact sequence, and the identical signature
recovers the receipt. The actual browser checks SQL/Form/Canvas editing, diagnostic
clearing, explicit rollback limits, publication and exact saved request recovery.
The full proof also restarts the worker/node/disk store and denies/restores current
interface reads. An earlier run stopped at a human-text assertion and exposed the
stale parser context; it is not counted as a pass.

Full `just check` passes after the parser correction, including generated contract
checks, 481 CLI diagnostic cases, frontend validation and the production handbook
build. This host increment does not claim durable publication/migration failure
witnesses or complete semantic inventory coverage.

### Shared Workspace diagnostics in application gateways — 2026-10-03

Board and the work-items gateway use `Workspace.applyStructured` to retain
compiler detail and distinguish validation before dispatch from an actual unknown
forwarding result. The work-items browser renders owned query/application detail
and preserves exact saved request recovery.

Executed root units, work-items frontend formatting/lint/types, full `just check`,
and `just test::work-items-browser`: **passed**. The browser proof completed in
77.29 seconds, including missing publication, unknown column with its original
SQL offset, locally rejected malformed saved token, migration/publication, gateway
replacement, exact upload recovery/cancellation and current denial.

Executed `just test::unified-ingress table`: **passed**, 222.14 seconds. Native,
port, CLI and Board/browser callers retain exact signed retries across worker,
node and disk-store restart. The two Board instances exercise concurrent prepared
sequences, current prefix denial, finite draft budgets and browser recovery.
Installed SDK profiles were not selected in this run.

### Board inspection diagnostics — 2026-10-03

Inspection errors retain separate semantic codes for authority denial, unsafe
principal, changed cuts, reclaimed history, unavailable sources, replay gaps,
coverage mismatch, invalid capture, protocol mismatch and inspector capacity.
Every projection describes a failed read with no complete observation, never a
domain write result or permission to repeat an external effect. The browser
renders owned validated detail and preserves primary errors when detail is invalid.

Executed Board API package units, Board ingress units and frontend formatting,
lint, types and 39 tests: **passed**. Executed `just transit-board::browser`: **passed**,
five browser cases in 20.3 seconds. Real HTTP assertions cover current grant
denial, read-only principal enforcement, native history reclamation and authority
outage, preserving primary status and exact safe next actions.

Full `just check` passes, including 481 CLI cases and the production handbook
build. The complete `just transit-board::http-browser`, `grpc-test` and `document-test`
proofs also pass. HTTP took 661.59 seconds, including its browser case, sixteen
sends/eight applications, explicit retry/redirect/reconciliation/cancellation,
partial capture, exact recovery and disk restart. gRPC took 492.85 seconds for
all four RPC shapes, nine sends/eight applications and source-bound metadata.
Document took 449.65 seconds, including reordered edits, conflict resolution,
worker/store recovery, exact cuts and current grant revocation. Each metadata
adapter now asserts semantic changed-cut and denied-read detail. These times
exclude compilation; all use disk-backed Ursula.

### Retained publication conflict basis — 2026-10-03

Application publication receipts retain the absent/head basis from the rejecting
turn. The head variant records revision and body digest; exact retry, later heads
and explicit abandonment/collection preserve it and the original input position.
The receipt uses at most 159 bytes; activation still uses four mutations. A
coordinated definition cutover rejects older persisted and signed semantics.
Generated contracts, bindings and independent signing/record fixtures are updated.

Package tests exercise a competing publication followed by a newer head, exact
retry and cleanup, and reject an old receipt without the basis. Native observations
carry a separate `receipt_diagnostic`; an input disposition remains independent.
Browser client tests (11) include invalid optional detail without losing the
primary receipt. Board frontend checks/types/tests (39) pass.

Executed `just test::application`: **passed**. The four restart phases take
1.258/1.108/0.757/0.816 seconds, with 21 turns, 152 reads, three killed workers and
one resident page during recovery. A real conditional conflict retains its exact
receipt after worker/node/disk-store restart; revoked resource access denies its
later disclosure. Applied receipts preserve their original input as well.

Executed `just test::application-browser`: **passed**, 55.7-second browser
schedule. SQL/Form/Canvas, exact lost admission reply, saved review recovery,
published receipt guidance for attempted cleanup, worker/store restart and current
read denial pass. Full `just check` passes after regenerating the dependent
mutation/catalog commitments and reactive signature fixture. Earlier qualification
stopped on those stale fixtures and a TypeScript test annotation; they are not
counted as passing runs. Durable publication input-rejection detail, migration and
reactive/effect mappings remain separate increments.

### Retained publication input rejection — 2026-10-03

The owner commits a bounded primary failure record and original witness after
rolling back the rejected input's entire attempted transition. It retains a frame
commitment, exact input/operation identities, policy revision, upload counts or
compiler member/option and assembled-body/nested-SQL coordinates. The compiler
witness binds the verified body digest. Infrastructure/read failures remain
unresolved. The primary record and witness occupy at most 249 and 245 bytes;
the signed status selection uses all eight available keys when fully populated.

Executed package tests, independent publication/signing fixtures, 12 browser-client
tests, full `just check` and an explicit root unit build summary: **passed** (71/71
root build steps succeeded). Tests cover every finite publication rejection,
maximum record sizes, absent/malformed optional browser detail, old bare reasons,
policy restoration, incomplete chunks, invalid declarations and nested SQL.

Executed `just test::application`: **passed**. Restart phases take
1.207/1.057/1.158/1.318 seconds, with 26 turns, 187 reads, three killed workers and
one recovery resident page. Original invalid-program detail survives staging,
node/store restart and later abandonment/collection. Original policy denial
survives policy restoration alongside an independently applied receipt. Current
resource revocation prevents later disclosure of both records.

Executed `just test::application-browser`: **passed**, 56.2-second browser case;
executed `just test::work-items-browser`: **passed**, 77.99 seconds. Both use actual
native publication, browser recovery and disk-backed Ursula. An earlier package
invocation used an invalid build-file working directory; corrected package and
root checks passed. Migration, reactive/effect mappings and complete semantic
inventory coverage remain separate increments.

### Original migration rejection evidence — 2026-10-03

Migration owners retain the original policy, epoch/contract, plan/step commitment,
ordinal and phase evidence at the rejecting check. Work-items adds cursor,
verification, target Table and submitted-state witnesses. Its handler discards
the attempted transition before committing the two rejection records. A shared
definition cutover rejects older stored framework semantics and signed requests;
generated contracts/bindings and independent fixtures are regenerated.

Executed application package and work-item unit tests: **passed**. Independent
Python bytes pin full-width migration failure records and frame commitments.
Tests cover every shared expected reason's outcome/actions, maximum 159-byte
primary and 125-byte shared witness records, original policy/ordinal/digest
evidence, cursor and state detail after activation, missing/old records, counter
exhaustion before transform execution and failed-read rollback. Invalid stored
source values use a distinct unresolved error and cannot commit tentative rows
or a caller rejection.

Executed `just test::work-items`: **passed**, 13.58 seconds excluding compilation,
55 turns, at most four mutations/142 value bytes and 20 bounded page reads. It
covers nineteen rows, exact operator/worker retries, two fresh-key replacements
and two node/disk-store restarts. Historical policy, cursor and ordinal witnesses
survive later activation and restored policy. Current resource read revocation
returns `AccessDenied` before disclosure. An earlier run expected the less specific
`Rejected` error at that assertion; it is not counted as a pass.

Executed `just test::work-items-browser`: **passed**, 80.30 seconds. The real browser
retains publication/schema migration, exact recovery/cancellation, gateway
replacement and current denial. Executed `just test::server-applications`:
**passed**, 41.547 seconds, nineteen rows and 21 receipts through installed CLI
applications and replacement/recovery. The real operator emits structured invalid
state detail without a Zig stack trace, and exact saved replay after activation
returns byte-equivalent parsed diagnostic content. Full `just check` passes,
including generated contracts, 481 CLI cases, frontend tests and the handbook build.
Reactive/effect mappings and complete semantic inventory coverage remain open.

### Original serving and reactive control rejection — 2026-10-03

Serving input rejection now stores its reason/cause, complete original frame
commitment and check-time witness in one record of at most 194 bytes. Expected
and observed revisions/codecs, policy, identity commitments, quotas, generations,
subscriptions and lease/session phase survive later changes. Read outages remain
unresolved. Current authorized status reads expose typed summaries and optional
shared diagnostics; explicit closure and lease expiry have distinct reasons.
A coordinated shared definition cutover rejects the old bare-string layout.

Executed serving package tests: **passed**, including all 44 finite reason
projections crossed with the 15 witness variants, bounded encoding/JSON, original
policy/binding evidence, one-write rollback, old-record rejection, closed versus
observed-deadline state, and Follow controls after explicit closure. Browser
validation tests reject foreign, malformed and outcome/input-mismatched optional
detail without resending; a later current denial suppresses protected facts and
keeps the original control reason distinct. Four shared diagnostic library tests
and the application/query consumer suites pass.

Executed `just test::serving`: **passed**, 8.49 seconds excluding compilation.
Independent Python commitments match the original conflicting submit and frame.
A rejected uint64-maximum identity remains exact decimal text. Original conflict
facts survive worker/gateway/node/disk restart and binding retirement; current
service/native revocation blocks later disposition reads.

Executed `just test::serving-lifetimes`: **passed**, 23.51 seconds, including the
original limiting process deadline with explicitly unrecorded clock, cancellation,
timeout/duplicate observation and late replies after physical recovery. Executed
`just test::reactive-client`: **passed**, 3.58 seconds, including an SSE `closed`
terminal and a retained rejected renewal carrying the original closed phase and
frame commitment through repeated private-host observation.

Executed `just test::reactive-limits`: **passed**, 61.17 seconds overall; the
capacity/lifetime phase takes 51.55 seconds. It exercises four durable sessions,
four held streams, recorded 4/4 capacity detail, reserved renewal, 0.002-second
health response, idle revocation, signed cursors, malformed frames, twelve
reconnects and absent-observer lease/source expiry. Two gateways use 48,586,752
RSS bytes under the 268,435,456-byte ceiling. Executed
`just test::reactive-browser`: **passed**, 13.34 seconds, including actual Chromium
WebCrypto, same-origin TLS WebSocket bootstrap, exact HTTP fallback, SSE resume
and gateway/worker/node/store recovery.

Full `just check`: **passed**, including 481 real CLI cases, 45 Board tests,
12 application-client tests, 27 query-client tests, generated contracts and the
production handbook. Final focused checks also cover the Follow closure mapping,
shared dependency cleanup and presentation of a later denial separately from
the original rejection. Initial invocations with an incorrect root test-step
name, an unquoted digit-leading definition identifier, a redundant `try` around
`catch`, and an input-oriented diagnostic schema in the new output validator did
not pass; corrected invocations are the evidence above. Follow terminal causes,
adapter read/transport witnesses, effects and semantic inventory completion remain
separate work. No committed-HEAD clean qualification is claimed here.

### Original Follow stop and independent query failure — 2026-10-03

Follow retains its original scheduling stop, committed input and bounded witness
separately from the selected query status. Session closure records its stop in
the same successful transition before removing the scheduler's session slot.
Cancelled/retired uploads stop stale copying/admitted presentation before bounded
collection; resource unavailability does not masquerade as permission denial.
Private reads acquire head/view/query together and recheck current disclosure
rights. A current-v1 definition cutover replaces the stored view and status shape.

Executed serving package tests: **passed**. All 19 scheduler reason projections
fit a maximum 251-byte view; combined status JSON with a maximum-field runtime
query witness stays within 16 KiB. All 47 serving reason projections crossed with
21 witness variants pass the existing 194-byte control-record and JSON bounds.
Original policy evidence survives restoration and requester reconstruction;
closure/pause preserves accepted query completion; cancellation collects within
the existing four-write turns. Watch schema, absent/future progress marker and
Table absence retain the evidence from the failing read.

Executed `just test::reactive-refresh`: **passed**, 96.26 seconds excluding
compilation. Independent peers exercise two shared-principal views, lost Follow
receipt, fair progress, worker replacement, exact full-width namespaces and
current entry-read denial. Pause retains its original input through closure. A
fresh complete template establishes an idle Follow before policy revocation;
a subsequent invalidation produces the separate original source-policy query
rejection. Restoring policy leaves both diagnostics unchanged. An earlier 88.32 s
run passed but used a potentially racing policy transition. Moving revocation
before template acquisition instead rejected the Follow input, correctly, and
that test invocation failed; the deterministic fixture above distinguishes the
two boundaries.

Full `just check`: **passed**, including 481 CLI cases, 52 Board tests, generated
contracts, 5078 documentation links and the handbook build. Final focused browser
checks pass all 30 reactive/live-view cases and strict types, including wrong
resource/generation/namespace and malformed optional details, and failed refresh
without replacement query or loss of the exact snapshot. A test-fixture edit
initially failed to alter the foreign resource; the corrected fixture passes.
Final package tests also exercise the maximal runtime witness. Executed
`just test::reactive-views`: **passed**, 164.02 seconds excluding compilation.
Actual Chromium and TLS exercise the shared counter/Board clients, exact query
recovery, bounded full-result verification, finite refresh, pause and current
read-only revocation. Measured mutation-to-visible times were 2348 ms for the
counter and 35857 ms for verified query replacement; observed browser heaps were
6,034,240 and 15,525,608 bytes respectively. The final added wrong-resource
optional-diagnostic check is covered by the focused browser suite above.
Adapter read/transport diagnostics, effects and semantic inventory completion
remain separate work. No committed-HEAD clean qualification is claimed here.

### Serving HTTP and stream attempt diagnostics — 2026-10-03

The request-local projection distinguishes local rejection, failed read, unknown
signed send, explicit native rejection and known native receipt. Stored/domain
outcomes remain independent. HTTP error bodies and SSE/WebSocket terminals share
the envelope. Separate concurrent socket tasks retain their own failure evidence;
started responses cannot receive a second HTTP status. Unit checks preserve a
truncated command's original `EndOfStream` as invalid input while transport EOF
remains unavailable. API schema references keep both generated descriptions
inside the existing 256 KiB bound.

Executed `just test::serving`: **passed**, 8.39 seconds excluding compilation.
Executed `just test::reactive-client`: **passed**, 3.62 seconds, including an
independent peer's lost-submit reply with exact unknown identity and explicit
closed-session SSE detail. Executed `just test::reactive-browser`: **passed**,
13.25 seconds, covering actual Chromium/TLS, diagnostic bootstrap timeout,
fragmented authentication, exact fallback and current authority/recovery.
The initial browser and limits runs expected a close frame before the newly
introduced diagnostic terminal and failed; their corrected assertions require
the precise local-before-dispatch timeout before closure. Package tests and full
`just check` pass. The first local follow-up unit invocation had a missing brace;
a second invocation used the wrong build-file working directory. Corrected
component-directory invocations pass.

Logs: `/var/tmp/transit-serving-adapter-{native,native-client,integration2,check2}.log`.
Executed `just test::reactive-limits`: **passed**, 62.24 seconds for the complete
trace (52.58 seconds for its limit schedule), reserved health 0.004 seconds and
two-gateway RSS 51,568,640 bytes below 256 MiB. After the full check, the final
SSE HTTP decoder and closure/expiry presentation refinements pass strict
TypeScript and **44/44** focused browser cases; log
`/var/tmp/transit-serving-adapter-browser-unit4.log`. No committed-HEAD clean qualification is claimed by
these focused results. Semantic inventory and operation/effect outcomes remain
separate work.

### Serving operation outcomes and original reply limits — 2026-10-03

Component tests cover all five serving phases, exact outcome/evidence/actions,
maximum safe-counter identities, a maximum 170-byte record and complete
SSE/WebSocket operation messages within 8192 bytes. An authenticated 65-byte
reply retains its exact count against the 64-byte result limit, clears its active
slot, preserves its failed outcome across exact retry/metadata changes and
rejects inconsistent stored phase/count/result evidence. Diagnostic projection
neither resends work nor treats wait cancellation as remote rollback.

Executed `just test::serving-lifetimes`: **passed**, 22.95 seconds excluding
compilation. Independent peers compare cancelled/timed-out diagnostics through
worker/gateway/node/disk replacement and late replies, and compare status/result
read evidence. Current service/native revocation remains enforced. Executed
`just test::reactive-browser`: **passed**, 13.47 seconds, including identical
serving status and SSE operation detail, actual Chromium/TLS and exact recovery.
Logs: `/var/tmp/transit-serving-outcome-native.log`.

Strict TypeScript and **50/50** reactive/live-view tests pass. They preserve
primary outcomes with malformed/wrong-resource/wrong-input/wrong-phase optional
evidence, and retain operation failure detail across continued snapshot updates.
An initial test callback used the generated wire type instead of the owned client
type; the public callback now exposes the validation flag. A subsequent fixture
lacked cursor progress and timed out; the corrected fixture passes. Logs:
`/var/tmp/transit-serving-outcome-browser-unit4.log` and
`/var/tmp/transit-serving-outcome-unit2.log`.

Full-check attempts first stopped on definition-identifier formatting and then
its lexical inventory drift. A later run reached frontend validation and exposed
the callback type issue. One redundant check was terminated after the fixture
failure; it is not passed evidence. Final full-check qualification is recorded
below when complete. Effect mappings and full semantic inventory remain separate
work; these results are not committed-HEAD clean qualification.

Final full **`just check` passes**, including native units, generated contracts
and bindings, 481 real CLI diagnostics, strict frontend checks/tests and the
production handbook; log `/var/tmp/transit-serving-outcome-check5.log`.

### Original connector admission witnesses — 2026-10-03

HTTP and gRPC rejections retain their original delivered input and payload
commitment, check, field, cause and typed expected/supplied values in one
232-byte correlated reply. The current native definition replaces the previous
five-byte layout. Generation updates all contracts, signing fixtures and SDK
resources together; old records fail decoding rather than acquiring new evidence.

Executed worker builds and `just test::unit`: **passed**. The runtime checks
cover each service policy dimension, exhausted attempt-budget values with no
child allocation, original commitment, and identical disclosure for missing and
foreign-caller parents. Allocation and authority/storage failures propagate
without committing a caller rejection. Executed `just bindings::native`:
**passed**, including 427 status/outcome mappings, **122 detailed** admission
witnesses and **498 malformed** records independently constructed for both native
and isolated port callers. These cover every check/scalar tag, full-width values,
UTF-8 truncation, explicit withholding, control-character escaping, every truncated
length, invalid padding and absent-input commitments. Native ownership, exact
host/disk recovery and query/materialization proofs also pass.

Full **`just check` passes**, including 554 CLI cases, 75 Board tests, strict
frontend checks, generated contracts/bindings and the production handbook.
Initial invocations failed on a shadowed Zig method name, an incorrect build
step, and a malformed-record test expecting no error detail; corrected invocations
are the evidence above. Logs: `/var/tmp/transit-admission-context2.log`,
`/var/tmp/transit-admission-native2.log`, `/var/tmp/transit-admission-check.log`.
All installed SDK packages build; their new recovery/admission schedules are
running and are not yet passed evidence. No committed-HEAD clean qualification
is claimed by this increment.

### Original JSON syntax and duplicate-member coordinates — 2026-10-03

The token observer retains an owned JSON Pointer, parser stop byte and both
original duplicate-member positions while the pinned `std.json` parser retains
syntax, duplicate and number-lexeme authority. Framing preserves invalid UTF-8
positions and BOM length. CLI machine offsets are absolute within the failing
file; human output labels record-relative positions. Missing tokens and preflight
failures do not acquire fabricated member paths.

Executed Fuze component tests: **passed**, including parser differential cases,
escaped duplicate names with nested values, Unicode paths and allocation-failure
cleanup. The initial observer omitted `BufferUnderrun` from its declared peek
error set; a later allocation test allowed nondeterministic allocator resizing.
The corrected test disables backing-allocator resizing while exhausting each
allocation failure. All 141 component tests pass. Executed CLI diagnostics:
**566 real cases passed**, including twelve new source/schema cases, BOM/Unicode
coordinates, later source/record attribution and required validation after
`LIMIT 0` and `LIMIT 1`. Earlier CLI invocations exposed UTF-8 validation at the
framer before JSON parsing, and an old wording expectation; the framer now retains
its own original position and the final suite passes.

Executed `just test::file-query`: **190 cases passed**, including a 192 MiB source
under a 96 MiB address-space limit, exact codecs, gzip, quotas, cancellation and
immutable capture. Full **`just check` passes**, including 75 Board tests,
generated contracts and the handbook. Logs:
`/var/tmp/transit-json-witness-{unit3,cli3,files,check}.log`.
No wire definition changes or committed-HEAD clean qualification are claimed.

### Installed connector admission parity — 2026-10-03

All **20 installed SDK schedules pass** against the connector-admission native
definition in `dcf06d21`: HTTP and gRPC for Python, TypeScript, Rust, Ruby, C,
C++, Java, .NET, Erlang and Elixir. The application receives the original input
commitment and provided failing field through the owned diagnostic. Independent
wire assertions compare that commitment to the actual submitted follow-up and
check the original expected/observed parent disposition. Rejection allocates no
child and performs no send. Existing staged-host recovery, full-width identity,
binary TLS, owned replay, current revocation, joined local disposal and durable
authenticated disposal schedules also pass.

An initial C fixture used the diagnostic structure instead of its JSON buffer;
an initial Elixir fixture filtered `nil` rather than the neutral decoder's null
atom. Both fixture checks are corrected and the affected installed schedules
pass. Logs: `/var/tmp/transit-admission-installed{,2}.log` and
`/var/tmp/transit-admission-{beam-http,grpc-languages,grpc-native,grpc-managed}.log`.
These artifacts predate later definition changes; they do not qualify future
ABI/schema cutovers or replace committed-HEAD clean verification.

### Original Follow reader evidence — 2026-10-03

Executed `just test::unit` and `just test::reactive-refresh`: passed. Independent
TLS peers deny source entry reads while metadata remains readable; the rejected
Follow input retains `AccessDenied`, source operation, original resource and
principal. Restoring permission returns the identical original observation. The
recovery schedule also retains its lost receipt, worker replacement, fair shared
principal scheduling and full-width query identity assertions (97.43 seconds,
excluding compilation).

Component cases cover missing/wrong PID, required permission bits with original
policy revision, writer/lifecycle with original resource revision, all ten known
reader causes, actual nested result resource, absent template and every incomplete
phase, and owned codec round trips. Memory, connection and integrity failures do
not fabricate a terminal reader witness. All 47 serving reason projections cross
25 witness variants within the unchanged 194-byte control-record/JSON bounds.
Generated contract, Board/client descriptions and all binding resources pass their
respective generators. The first integration attempt found the HTTP 403 path had
lost its witness; the corrected run covers it. An intermediate compile rejected
an optional resource ID and an invalid diagnostic-field name; those attempts did
not pass. Logs: `/var/tmp/transit-refresh-reader-proof{,2,3}.log`.

Full `just check` also passes: generated-contract/binding drift checks, 566 real
CLI diagnostic cases, 75 Board tests, shared frontend suites and production
handbook build. Log: `/var/tmp/transit-refresh-reader-check.log`. These runs do
not replace the final committed-HEAD clean checkout verification.

### Original connector follow-up policy fields — 2026-10-03

HTTP/gRPC follow-up checks retain original failed field, check, cause and permitted
comparison values. Component tests cover nested canonical policy differences,
separate method/shape/schema/provenance gates, credential-reference redaction,
retry key count and 0/128/129-byte bounds, missing/disallowed HTTP status/Location,
redirect scope and missing policy. Equal slices in different buffers compare by
contents; retained witnesses own their field/value bytes. Final unit checks also
verify private routing is withheld while permitted byte limits remain exact.

Executed full `just test::http-worker`: passed in 593.45 seconds excluding
compilation, with disk recovery, lost receipts, original cause retention and
retirement. The actual rejected follow-up replies expose the changed request
target and exact retry-policy revision 1 versus 2, remain `input_rejected`, and
cause no extra remote send. The existing full schedule records seventeen sends,
nine applications and two cancellation requests. Executed full
`just test::grpc-worker`: passed in 419.07 seconds, nine sends/eight applications.
Both use disk-backed captures beyond the 8 MiB hot-memory bound.

Executed `just test::unit`, both debug worker builds and full `just check`: passed.
The final routing-disclosure restriction received another unit run after those
integration binaries were built; it changes only withheld scalar projection.
An attempted unsupported `-Dtest-component` selector and an intermediate use of
an obsolete Zig reflection member did not pass; corrected tasks use the pinned
compiler's field-name reflection. Logs:
`/var/tmp/transit-policy-detail-{unit2,unit3,unit4,http-proof,grpc-proof,check}.log`.
Final committed-HEAD clean checkout verification remains separate.

### Exchange diagnostic read boundary — 2026-10-03

The shared HTTP/gRPC native and port read action projects original capture failure
or native effect evidence independently. Installed fixtures for all ten SDKs
assert absent capture failure and the exact observed native effect identity/code;
revocation fixtures exercise the new read where the language permits access while
a replay cursor is borrowed. The HTTP disk schedule additionally compares the
original cause after lost failure-input receipt, worker/node/store replacement and
retirement, and verifies that capture grants alone cannot inspect the connector PID.

Executed `just test::unit` and full `just check`: passed. The first integration
attempt exposed a missing paging position; the next attempts exposed the distinct
PID scope and principal-epoch/resource-grant requirements. Those attempts did not
pass. A stale redirect fixture now expects the original `policy.redirect` field.
The first full check found the C public API definition needed regeneration;
`just bindings::generate` followed by the complete check passed. Logs:
`/var/tmp/transit-exchange-diagnostic-{build,check2,regenerate}.log`.

All twenty installed ordinary HTTP/gRPC schedules passed: Python, TypeScript,
Rust, Ruby, C, C++, Java, .NET, Erlang and Elixir. Each retained the exact native
effect identity and completed outcome, absent capture failure, original follow-up
rejection evidence, current replay denial, owned bytes and one external send.
C/C++ HTTP was repeated after regenerating and rebuilding its public API definition.
Logs: `/var/tmp/transit-exchange-diagnostic-sdk-group{1,2}.log` and
`/var/tmp/transit-exchange-diagnostic-c-final.log`.

Full `just test::http-worker` passed in 1083.97 seconds excluding compilation,
with seventeen sends, nine applications and two cancellation requests. Native
capture-failure reads exactly match the original cause after failure-input receipt
loss, worker/node/store replacement and retirement; native effect reads match the
original reconciliation closure. Capture-resource access alone fails the independent
connector-PID inspection check. The 8 MiB hot limit spills 810 cold objects and
94,682,099 bytes. Log: `/var/tmp/transit-exchange-diagnostic-http-proof.log`.
This qualification is for the exchange diagnostic read definition at `8be70f5f`;
subsequent preparation-evidence work requires its own proof. Committed-HEAD clean
checkout verification remains outstanding.

### Accepted connector preparation failures — 2026-10-03

`just bindings::connector-preparation` runs two installed Python SDK schedules
against disk-backed Ursula. HTTP records the original 513-byte body against a
one-byte bound; gRPC records the ungranted credential reference at metadata index
3, withholding both private comparison values. Each loses the admitted EXP1 input
receipt, kills the worker, restarts the authority and store, corrects configuration
and removes the credential file. Recovery publishes the original closure without
reading that file or dispatching. Current denial blocks diagnostic reads; restored
access and later exchange retirement retain byte-equivalent original diagnostics.
The exact exchange identity, distinct original/current input positions, absent
native intent and inspection-only recovery action are asserted.

Both focused schedules passed: HTTP **13.10 s**, gRPC **13.18 s**, zero external
sends. The first gRPC attempt exposed a wrong fixture expectation: duplicate
metadata entries place the credential at index 3, not 2. That attempt did not
pass. Exchange unit tests passed for the independent 216-byte EXP1 fixture,
canonical decoding, malformed records, atomic rollback, first-cause preservation,
retirement and refusal after intent/attempt creation. HTTP render units passed for
later target/header fields, redaction and measured limits. Python artifacts and
both worker binaries built with the replacement current-v1 definition. Logs:
`/var/tmp/transit-preparation-{http,grpc}-proof2.log`,
`/var/tmp/transit-preparation-build2.log` and
`/var/tmp/transit-preparation-http-unit2.log`.
Full `just check` passed after adding Board's preparation-outcome explanation.
The first check correctly rejected the missing exhaustive reason mapping. A
subsequent focused Board check passed for browser acceptance of the original
preparation cause/input and rejection of invented dispatch evidence, after
formatting the added fixture. Logs: `/var/tmp/transit-preparation-check2.log` and
`/var/tmp/transit-preparation-board-check2.log`. Committed-HEAD clean qualification
remains separate.

### Connector preparation field witnesses — 2026-10-03

The gRPC transport, Station gRPC and Station HTTP unit suites passed. They exercise
each transport limit's exact bound, shape/count precedence, later metadata/message
indices, original batch truncation and framed byte counts, twelve policy failure
classes, eleven request-reference checks, noncanonical/invalid-hex input and
allocation failure without fabricated rejection evidence. HTTP units distinguish
duplicate, omitted and missing Location from invalid retained framing. The first
adapter run exposed a fixture reusing a diagnostic across independent operations;
resetting that fixture preserves the production first-failure rule.

Rebuilt installed Python recovery schedules passed for HTTP (**13.17 s**) and
gRPC (**13.43 s**), with original field evidence after admitted-input receipt loss,
corrected configuration, worker/node/store restart, current denial and retirement,
and zero external sends. Full `just test::grpc-worker` passed in **358.95 s**
excluding compilation: nine sends, eight applications, an 8 MiB hot limit,
656 cold objects and 63,895,897 object-store bytes. Full `just check` passed.
Logs: `/var/tmp/transit-connector-field-{final-build,recovery,grpc-worker,check}.log`,
`/var/tmp/transit-grpc-field-unit2.log`,
`/var/tmp/transit-grpc-transport-field-unit.log` and
`/var/tmp/transit-http-field-unit.log`. Clean committed-HEAD qualification remains
separate; source inventory enhancements made afterward have their own check.

### Diagnostic declaration drift inventory — 2026-10-03

`just test::diagnostic-inventory` passes over 328 production owners, 2,924
owner/error pairs, 406 qualified enum/union surfaces, 13 declared error sets,
2,405 error-return boundaries and 153 grammar productions. Nested/anonymous tags,
changed explicit error sets and aliases, open/inferred returns, propagation and
new source owners all participate in drift detection. Synthetic filesystem tests
verify that ignored dependency/output directories do not affect the result.
The prior inventory accidentally included 193 local dependency-cache files; those
are excluded rather than required in a clean checkout. Documentation links and
`git diff --check` pass. Log: `/var/tmp/transit-diagnostic-declarations-check.log`.
This is a source review gate, not a whole-program reachability or executed
semantic-mapping completeness claim.

### Closed compiler semantic mapping gate — 2026-10-03

`just test::diagnostic-mappings` and full `just check` passed. The independent
manifest covers 59 stable SQL codes/categories and all 60 literal owner/error
pairs in the selected compiler/cursor sources, including two reviewed boundary
exceptions. Negative mutations reject a new error, missing/stale exception,
changed code, missing executable owner and newly matching source file even if
the source inventory is recorded. The owning runtime case now sends every code
through the public SQL classifier, validates its envelope and rejects resume or
cancel advice for compilation failure. Query units distinguish editor cursors
and malformed typed predicates while retaining unknown submission evidence.
The CLI suite passed 566 actual command cases. Logs:
`/var/tmp/transit-diagnostic-mappings-{unit,check}.log`.
The gate's declared scope is compiler semantics. Runtime/adapter and grammar
alternative completeness, and final committed-HEAD clean evidence, remain
separate requirements.

### Capture diagnostic inspection identity (2026-10-03)

Pinned-shell `transit-exchange` package tests passed after capture diagnostics were
bound to the retained exchange before an effect exists, or to the exact effect
afterward. Both projections retain `not_applicable` for the independent remote
outcome, report saved owner evidence and offer only identity-bound inspection.
The test includes a maximum uint64 exchange identity. Log:
`/var/tmp/transit-capture-inspection-unit4.log`. An initial invocation from the
wrong build directory and an incorrect Decimal accessor did not pass; the recorded
run includes the corrected fixture. No wire/persisted layout changed. Full clean
committed-HEAD qualification remains separate.

### Retained outcome semantic gate (2026-10-03)

`just test::diagnostic-outcomes` passed in the pinned shell: **498 projections**
cover **208 enum variants in 14 declared surfaces**. Query failures cross both
recorded stages and denied/rejected/retired presentation. Independent reviewed
expectations check stable codes/categories, stages, outcomes, evidence, complete
identities, fact origins/availability and exact recovery targets. Negative checker
mutations reject missing/duplicate cases, new enum tags, changed meaning, wrong
targets, hidden facts and fresh-retry advice for unknown outcomes.

The executable uses valid synthetic owner records; its first serving/effect
fixtures were rejected by production validators and were corrected before this
passing run. This is projection coverage, not additional transition/restart or
current-authority proof. The source inventory and documentation checks also
passed (5,135 local links in 510 files). Final log:
`/var/tmp/transit-diagnostic-outcomes-check2.log`. The first check invocation used
a nonexistent documentation task after the outcome/inventory checks passed;
the documented rerun executes the actual documentation checker. Clean CI remains
separate and unclaimed.

### Migration progress and closed error boundary (2026-10-03)

Pinned `test::unit`, `test::diagnostic-mappings`, `test::diagnostic-outcomes` and
`test::work-items` passed. The migration boundary covers 13 classified input
causes and four explicit unresolved configuration/transform faults; the new fault
test verifies no initial mutations and full rollback of tentative domain writes.
The complete projection matrix now runs 514 cases across 16 declared surfaces,
including the three plan phases and all shared input causes. Maximum uint64 plan
identity and invalid progress records are checked separately.

The actual work-item worker proof passed in **13.53 seconds** with 19 rows, two
fresh-key fenced replacements, node/disk restart, exact operator/worker retries,
complete verification and old-epoch rejection. It now reads and checks the plan
diagnostic through the same current-authorized native resource path before/after
recovery and activation. It observed 55 turns, at most four mutations, 142-byte
values and 20 pages. Log: `/var/tmp/transit-migration-diagnostics-check.log`.
The real example worker/operator binaries built from their component manifest
(`/var/tmp/transit-migration-operator-build.log`); the standalone operator's new
JSON inspection field is compiled, not separately exercised by that native proof.
The final mapping/outcome/documentation checks passed in
`/var/tmp/transit-migration-diagnostics-final.log`. Clean committed-HEAD CI is not
claimed by these focused results.

### Query caller diagnostic boundary (2026-10-03)

The pinned semantic mapping and outcome gates pass: 105 query caller causes,
49 owner/error pairs and 724 total projections across seventeen declared surfaces.
Each caller cause is exercised as a failed status read and after dispatch, with
distinct native rejection and uncertain-send expectations. Native ABI units check
an actual refused connection, exact realm/resource/namespace action targets and
preserved saved submission identity. Corrupt final result coverage is tested
separately from a pending result. Full `just check` passes, including native,
generated, CLI, frontend and handbook checks; log
`/var/tmp/transit-query-caller-full.log`.

`just test::public-query` passes real shell/host execution, 41 exact int64/null
rows, exact retries, fenced crash recovery, busy admission, schema rejection,
incomplete-result refusal, cancellation and read-time revocation. The proof now
asserts that denied resume preserves the bundle and query selection without
advancing the caller sequence, and that result disclosure remains denied. Its
first run exposed stale expectations that denial erased the selected namespace;
those were corrected to the documented retained-work behavior before the passing
rerun (`/var/tmp/transit-query-caller-public-proof2.log`). These are focused/local
checks; committed-HEAD clean CI remains separate.

### Grammar alternatives and semantic diagnostics (2026-10-03)

`just test::diagnostic-grammar` passes **197 actual public compiler cases** and
**243 parser rule/alternative/boundary obligations** across both checked grammars.
ANTLR regenerates without diagnostics; coverage follows actual trees independently
of Zig. Reviewed expectations distinguish accepted offline compilation, binding
failures, malformed inputs, unavailable interfaces and unvalidated grammar-only
families. They check stable codes/categories, no-send outcomes, action safety and
original source/type/key context. Checker mutations reject changed semantic
meaning; EBNF fixtures verify branch and repetition accounting.

Pinned `just test::unit` and the **566-case CLI diagnostic matrix** pass in
`/var/tmp/transit-diagnostic-grammar-check5.log`. Initial fixtures exposed missing
reference branch examples and differences between guessed cause names and the
actual public classifier; those were reviewed and corrected. The first unit run
after the placeholder improvement exposed two assertions expecting the previous
generic cause; both now require `UnboundParameters`. These tests contain no
authority or submission and do not replace runtime/restart qualification.

### Application caller mappings and capacity witnesses (2026-10-03)

Pinned `just test::unit`, `test::diagnostic-mappings`, `test::diagnostic-outcomes`,
`test::diagnostic-grammar` and `test::application-grammar` pass. The compiler/host
registries contain fifty/forty-six causes across 38/28 owner-error pairs with no
unmapped literal causes in those selected owners. The independent matrix executes
**916 projections in nineteen declared surfaces**, including every compiler cause
at parse/output and every host cause during reads and after dispatch. Unknown
sends keep exact recovery targets; native rejection establishes no publication
receipt. Actual invalid operator configuration is rejected before transport.

Capacity tests check missing themes/screens, all four collection maximums, the
third parsed theme, the 17th option/comment level, the 4,097th decoded literal
byte and a 65,537-byte program. Actual human/JSON CLI cases assert first dimension,
unit, minimum/maximum rule and exact counts without option-value disclosure.
Independent application grammar/model agreement and visual formatting round trips
still pass. Logs: `/var/tmp/transit-app-semantic-{unit,check,final}.log`.
These local checks do not claim committed-HEAD clean or installed adapter recovery
qualification.

### Board and Flight caller diagnostic parity (2026-10-03)

Pinned native units, semantic mappings, inventory, documentation and the independent
outcome matrix pass. The matrix checks **1,174 projections across 21 declared
surfaces**, including all 117 shared query caller causes through Board's HTTP
fallback and Flight's RPC projection. Specific native dispositions retain their
priority; corrupt result evidence maps to Flight DATA_LOSS and unavailable memory
to UNAVAILABLE. These projections invent no selected query identity.

`just transit-board::query-test` passes actual unbound-parameter/editor-cursor
errors, current grant and cut enforcement, and exact recovery after unavailable
submit/next replies (`/var/tmp/transit-adapter-board-query.log`). An earlier command
used the nonexistent `test::board-query` task; this corrected invocation passed.
The pinned Flight shell's `zig build test-flight -Doptimize=ReleaseSafe` passes
finite schemas/rows/metadata/retry, installed Python and C ADBC consumers, saved
arithmetic failure after gateway replacement, exact retry and current-disclosure
denial. The first run exposed a stale assertion requiring no caller facts after
denial; the test now allows only the literal caller label while rejecting any
retained identity or execution facts. The complete rerun passed in
`/var/tmp/transit-adapter-flight2.log`. Clean committed-HEAD qualification remains
separate from these focused results.

### Mutation and catalog caller evidence (2026-10-03)

Pinned native units, semantic mappings, the 566-case CLI suite, inventory and
documentation checks pass. The mutation/catalog caller registries cover 54/49
causes and 20/37 selected owner-error pairs without unmapped literal causes.
The independent matrix passes **1,380 projections across 23 declared surfaces**.
Units execute actual refused native status reads, full uint64 operation identities,
original reference/request scope preservation, malformed-reference rejection,
native conflict detail and every registered read/dispatch classification. Canonical
Document integer overflow now returns its owning invalid-integer cause.
Logs: `/var/tmp/transit-write-caller-{unit,check}.log`.

`just test::catalog` passes real CREATE, name conflicts, metadata, exact lost-receipt
recovery and explicit cancellation limits in **17.03 seconds**.
`just test::table-query-writer` passes in **39.779 seconds**, including both
initialization receipts through recovery, atomic row rejection, exact lost replies,
interruption, policy-raced input rejection, cancellation and retained snapshots.
It observes 84 turns, at most four mutations, 256-byte values and eight resident
pages. Logs: `/var/tmp/transit-write-caller-{catalog,writer}.log`. These focused
runs selected no installed SDK variants; they do not replace final clean CI.

### Board inspection semantic coverage (2026-10-03)

Pinned native units, mapping/inventory gates and documentation pass. The closed
inspection boundary combines 48 Board causes with shared query mappings for 138
reviewed causes and six selected local owner-error pairs. Independent projections
cross every cause with current denial and check all 109 native error tags, for
**1,765 total projections across 25 declared surfaces**. Native tags without an
inspection-specific meaning remain explicit authority causes, not invented domain
outcomes. Log: `/var/tmp/transit-inspection-semantic.log`.

`just transit-board::test` passes the actual server, generated-client validation,
private access, scope/revocation, gaps, effects, outage and load checks, with maximum
control latency **0.100 seconds**. Log:
`/var/tmp/transit-inspection-board-proof.log`. The asset build reports its existing
large-chunk warning; the proof completes successfully. Browser and clean
committed-HEAD qualification remain separate.

### Flight RPC causes and result conversion (2026-10-03)

Pinned units, inventory, semantic mappings and documentation checks pass. The RPC
registry covers 36 causes and twelve selected command/ticket/metadata/result
owner-error pairs. Independent status projections bring the matrix to **1,801
cases across 26 declared surfaces**. Actual Table result conversion tests exercise
COUNT at maximum uint64, preserving the output alias, exact value, int64 maximum
and incomplete-output marker without claiming failed computation.
Logs: `/var/tmp/transit-flight-rpc-{unit,semantic,docs}.log`.

The pinned Flight shell's `zig build test-flight -Doptimize=ReleaseSafe` passes
actual Flight and installed Python/C ADBC schema, row, metadata and exact-retry
checks, plus saved arithmetic failure after gateway replacement and current denial.
Denied detail retains only the caller operation and native AccessDenied cause.
The same task with `-Dflight-faults=true` also passes delayed concurrent fetches,
data admission limits with control progress, one-byte HTTP/2 credit stall, malformed
frames, pooled authentication, sequence conflicts, foreign/tampered tickets,
revocation after a real batch, interrupted duplicate fetch, gateway/worker/node/store
restart and permanent source retirement. Observed gateway RSS was **79,896,576
bytes**. Logs: `/var/tmp/transit-flight-rpc-{proof,faults}.log`. These focused results
remain distinct from final clean committed-HEAD qualification.

### Serving adapter semantic coverage (2026-10-03)

Pinned native units, mapping/inventory gates and documentation pass. The finite
registry covers 90 causes and 84 selected client, adapter, model and codec
owner-error pairs. Five independent evidence scenarios per cause check local
input, failed reads, unknown dispatch, received receipt and native rejection,
including HTTP status where applicable. The matrix passes **2,251 projections
across 27 declared surfaces**. Logs:
`/var/tmp/transit-serving-caller-{unit,semantic,docs}.log`.

The pinned serving shell's real TLS reactive client proof passes preparation,
exact lost-reply recovery, committed controls, private Origin enforcement,
metadata-only watch/coverage, reserved close and denial in **3.66 seconds**.
The reactive limits proof passes four durable sessions/four held streams,
reserved renewal and health (**0.004 seconds**), idle revocation, cursor rejection,
malformed frames, twelve reconnects and absent-observer expiry checks. Two-gateway
RSS is **51,945,472 bytes**, below the 256 MiB bound; that schedule reports
**51.04 seconds**. The full initial/adversarial trace also passes snapshots,
WebSocket-to-HTTP exact retry, SSE resume, attachment fencing and physical
recovery (**60.82 seconds**). These execute the corresponding `test-serving`
flags with `TMPDIR=/var/tmp` after entering the pinned shell. Logs:
`/var/tmp/transit-serving-caller-{client,limits}.log`. Browser and final clean
committed-HEAD qualification remain separate.

### Compiler-inferred diagnostic boundary coverage (2026-10-03)

The pinned native unit suite and `just test::diagnostic-errors` pass. The gate
checks sixteen public inferred error sets and eleven unknown-callback projections,
including read versus exact uncertain dispatch and received native receipt.
Changed/new finite causes, a newly open set, omitted projections, fabricated
rejection and changed recovery targets fail mutation checks. An initial fixture
used an incomplete catalog cursor; it was corrected to the public null first-page
selection and rerun. File I/O remains an explicitly open boundary with separate
CLI projection ownership. The gate does not prove every inferred cause reachable.

The actual typed mutation compiler rejects a foreign target schema version with
`sql.unsupported_schema`, original version 2, required version 1, no SQL caret
and a no-send outcome. Existing native fixture and unit suites pass unchanged.

### File caller diagnostic registry (2026-10-03)

The pinned native unit suite, semantic mapping/type gates and outcome matrix pass.
The registry covers 122 causes and 139 selected owner/error pairs without mapping
exceptions. Component-owned projections check every cause at execution and schema
file decoding, bringing the complete declared matrix to **2,495 projections across
28 surfaces**. Unit cases render every entry across four local stages, preserve
incomplete-output truth and exercise unknown callbacks, capture-storage precedence,
allocation/interruption and scalar-versus-arithmetic overflow. An initial test used
an obsolete generic cancellation tag; it was corrected to the actual two action
kinds before the passing run.

`just test::file-query` passes **190 real CLI cases**, including independent exact
codecs/results, checked gzip, quotas, cancellation/cleanup, immutable capture and
192 MiB input under a 96 MiB address-space limit. `just test::cli-diagnostics`
passes **566 real command cases** with no credential/configuration disclosure,
stdout contamination or provisioning. Documentation links also pass. Open external
callbacks and OS errors are not claimed to be a finite enumerated set.

### Query lifecycle and saved Flight status matrix (2026-10-03)

`just test::diagnostic-outcomes` passes **2,851 projections across 30 declared
surfaces**. All eight requester phases invoke the actual status projector with
valid encoded status. Uploading, sealed, admitted and complete have no diagnostic;
the mutation checks reject fabricated pending failures. Cancelled/retired and
original denied/rejected outcomes retain their independent meanings. Every saved
query failure also crosses both stages and denied/rejected/retired presentation
through the real Flight detail and RPC status projector. Retired presentation
preserves the original cause and returns FAILED_PRECONDITION. An initial checker
assumed every observation had an outcome field; it was fixed to accommodate
explicit diagnostic absence and rerun. Documentation links pass. This fixture
does not replace authorization, durable transition or restart proofs.

### Local transport denial versus authority rejection (2026-10-03)

The pinned socket API declares `AccessDenied` for local firewall/OS refusal. A
real injected `netConnectIp` denial through the HTTP client now produces
`AuthorityTransportDenied`, with one connection attempt and no native rejection
or HTTP status. The ABI projects it as uncertain for commands and unavailable for
reads; the original cause remains in the owned error buffer. Valid authority
rejection behavior is unchanged. All caller registries and shared Board/Flight
projections retain the local-denial meaning and exact uncertain-send guidance.

Native units, inferred-boundary/mapping gates and **2,868 semantic projections
across 30 surfaces** pass. `just test::client-abi` passes actual authority grants,
host-loss recovery, malformed/lost replies and revoked retry. Full `just check`
passes, including generated contracts, frontends and documentation. The existing
TypeScript catch-parameter warning remains nonfatal; no new warning is introduced.
There is no wire, persisted record or ABI layout change.

The earlier clean run at `74fea68e` was deliberately interrupted during growth
qualification after all core tasks passed. Its metadata has `completed: false`
and is retained at `/var/tmp/transit-ci-b97ktvkx/src/.cache/ci/complete.meta.json`.
The concurrent connector run completed nine HTTP consumers before interruption;
it is not counted as an all-language/all-protocol pass. Both are superseded by
qualification of the corrected committed revision.

### Flight clock and expiry counter bounds (2026-10-03)

Pinned native units and the 2,868-case semantic matrix pass. The actual gateway's
time addition rejects values beyond the native counter range as `ClockUnavailable`,
including values that still fit uint64. A boundary ticket issued at the maximum
valid timestamp decodes immediately before expiry and reports expiry exactly at
that timestamp. The failure projection remains UNAVAILABLE without a fabricated
query outcome or caller credential fault.

The pinned Flight suite passes real finite statements, exact full-width/null rows,
metadata and retries, installed Python and C ADBC, and original overflow detail
after gateway replacement with current-disclosure denial. Documentation links
pass. This changes no ticket bytes, ABI layout or current definition.

### File I/O cause and framing attribution (2026-10-03)

Native units and all 2,868 semantic projections pass. Component cases retain a
local permission errno through human and structured rendering, distinguish an
unknown schema-read cause from an internal callback failure, and separate generic
truncation from actual gzip-decompression context. `just test::cli-diagnostics`
passes **568 real commands**, including absent input and schema paths with original
OS/read causes and no result output. `just test::file-query` passes all **190 cases**,
including checked gzip, exact codecs, cancellation, immutable capture and the
192 MiB input under a 96 MiB address-space bound. No wire format changes.

### Rejected connector admission before capture inspection (2026-10-03)

Clean `just ci-clean --complete` at `20c88a421543eeb3ac7855cc987b71bfbdb7db9f`
passed its first 45 tasks, then failed the HTTP worker's rejected-followup case:
an accepted-preparation diagnostic lookup replaced `MissingHttpCall` with
`ExchangeNotFound` for a child that had never been admitted. Both HTTP and gRPC
workers now establish the admitted route before reading capture failure evidence.
The shared installed SDK schedule exercises a fresh `accept` activation after
each rejected followup, preserving the single original correlated rejection and
asserting no result output or invented capture failure.

Full pinned `just check` and the installed Python HTTP schedule pass with the fix.
The complete worker, all-language and clean-checkout reruns remain separate
qualification. The failed clean checkout is retained at
`/var/tmp/transit-ci-hko3_uj9`, with `completed: false`; it is not a clean pass.
Logs: `/var/tmp/transit-diagnostics-qualified-clean.log` and
`/var/tmp/transit-diagnostics-admission-{check,http,sdk}.log`.

The corrected HTTP worker proof passes in **692.33 seconds**, including original
failure-input receipt loss, restart, retirement, rejected followups and explicit
retry/redirect/status/cancel. It observes seventeen sends, nine applications and
two cancellation requests. `bindings::connector-outcomes` also passes all twenty
installed schedules: HTTP and gRPC for Python, Node, Rust, Ruby, C, C++, Java,
.NET, Erlang and Elixir. Each rejected followup now includes the fresh `accept`
regression check. These qualify the implementation committed as `8ff184f1`.

### Abrupt TLS close proof boundary (2026-10-03)

Clean qualification at `8ff184f1276f0e80913fa623c5c08140c2e388b4` passed forty
tasks, then the independent gRPC peer's deliberate abrupt close returned
`ConnectionResetByPeer` where the fixture required `TlsConnectionTruncated`.
Closing a socket with unread request data can expose either transport cause.
The fixture now admits only those two exact failure records, both with zero
received messages and without a status or completion claim. Runtime behavior is
unchanged. Three consecutive pinned `just test::grpc-transport` runs pass,
including all four shapes, finite budgets, flow control and malformed terminals.
Log: `/var/tmp/transit-diagnostics-tls-close-proof.log`.

The failed clean run remains incomplete at `/var/tmp/transit-ci-__ng_3be` and
`/var/tmp/transit-diagnostics-complete-clean.log`; completed tasks do not establish
a full clean pass. Final qualification must include the corrected fixture.

### Java local startup failure attribution (2026-10-03)

The installed Java Station preflight at `77919e97` failed while two workers
extracted 162,931,597-byte native artifacts into the JVM's default `/tmp`, which
had only 196 MiB free. `TMPDIR` did not select JVM temporary storage. The SDK
discarded the extraction exception and reported incompatible native artifacts.
Java now reports extraction/configuration/process-start I/O as `LOCAL_IO`, with
the original exception and type, no native status or authority rejection, and
explicit temporary-storage guidance. Cleanup errors cannot replace that cause.
Genuine version failures preserve their original compatibility classification.

Installed raw-client cases pass actual invalid temporary-directory failures at
extraction and configuration creation, and a missing process interpreter. They
assert original cause, local phase, absent durable outcome and removal of temporary
artifacts. All Java proof consumers select fixture-owned `java.io.tmpdir` paths
and exclude inherited JVM option injection. Full pinned `just check` passes.
Logs: `/var/tmp/transit-diagnostics-java-{check,io}.log`.

The earlier clean run at `77919e97` passed all core, growth, experience and launcher
tasks plus `bindings::check`, including HTTP worker recovery in **1,008.02 seconds**.
It was deliberately interrupted during `bindings::native` for this correction:
58 passed tasks and one interrupted task, `completed: false`, retained at
`/var/tmp/transit-ci-hp6auj1_`. It does not establish a full clean pass.
The independent browser preflight measured **3.314 seconds** against the unchanged
three-second Board control bound while other checks ran. That failed run is not
counted as browser qualification; isolation and a complete rerun remain required.

### Reactive reconnect diagnostic retention (2026-10-03)

The isolated browser lane at `1786ce1d` passed its first six tasks, then failed
the lifecycle fixture's obsolete expectation that source retirement means denial.
The current adapter reports source unavailability separately from permission
revocation. Investigation also found that the reconnect loop replaced a valid
stream/HTTP diagnostic with generic connection advice. The shared view now keeps
that diagnostic through the next attachment attempt; current denial still clears
protected state, while unavailable sources retain the already disclosed exact
snapshot and basis without claiming replacement coverage.

Full pinned `just check` passes, including **77 Board tests**. Two new cases
exercise actual view-loop scheduling for interrupted stream and HTTP 410
diagnostics, retaining the original snapshot and session across reconnect. The
real TLS/Chromium lifecycle proof passes in **60.84 seconds** excluding compilation:
shared-principal tabs, actual network loss/resume, unchanged sessions, pagehide,
generation reset, explicit resnapshot and source retirement with visible semantic
detail. Logs: `/var/tmp/transit-diagnostics-reconnect-{check,lifecycle}.log`.
The failed browser lane remains incomplete at `/var/tmp/transit-ci-kmpsq18h`;
qualification of the three affected reactive tasks in a fresh checkout remains
separate from this focused pass.

### Embedded recursive schema references

`transit-protocol`'s package tests pass 34/34 in the pinned development shell
(`recursive-schema-nested1.log` in the local Table-schema campaign).
`Schema.writeRecursiveAt` emits references relative to an explicit enclosing
JSON pointer. The test traverses every generated reference in an embedded
recursive schema and resolves it against the complete document. Existing scalar
codecs, safe integer ranges and field-specific bounds remain covered. This is
schema-generation evidence, not runtime admission or browser validation.

### Catalog-backed logical query cutover

The current `transit-query` package passes 109/109 tests and compiles its public
schema exporter (`query-native-cutover-build18.log` in the local Table-schema
campaign). Its 106 owner/unit tests plus three standalone catalog integration
cases run on private turns and an in-memory reference store. They exercise
complete schema-bound UQS1/UQB1/FQP1 requests; retained schema/head cuts across
ALTER, DROP and name reuse; distinct requester/principal mappings; current read
revocation including empty results; exact discarded proposals and terminal
replay; maximum checkpoint bytes; and owned neutral parameters for all 21 scalar
families. Table rows use internal RowIDs, while complete key equality uses the
collision-safe primary-key index. KV and Document decoder semantics remain
separately bounded. The independent source/bundle/publication Python vectors
also pass.

The catalog query owner cases cover four-write initialization, multiple explicit
requester delegations, conditional revisions, same-number process spoofing,
undelegated calls before request-body access, foreign continuations, rollback
after disposition write exhaustion and sticky denied reads. Runtime witnesses
retain complete UTF-8 prefixes at both Table and decoder-source byte boundaries.
The migrated assistance corpus caught and verifies fixes for unresolved-column
operator suggestions, partial source completion and unsupported aggregate LIMIT
suggestions; full Fuze tests pass 253/253.

The diagnostic mapping gate passes all eleven declared boundaries. The executable
outcome matrix passes 3136 projections across 34 declared surfaces, including
current catalog failures and their Board/Flight projections
(`native-cutover-outcomes4.log`). These are projection tests, not native transport
qualification. Verification catalog and fixture checks pass. Full root build,
installed callers, catalog owner disk/restart schedules, resident-memory budgets
and matched ReleaseSafe measurements remain to be completed for this cutover.
Historical two-column owner schedules do not qualify the replacement.

### Logical query callers and contextual diagnostics

The CLI renders owned logical Arrow batches in interactive and durable modes;
neutral results preserve logical descriptors and cells. The native binding codec
uses the same schema/plan/value conversion. Query tests pass 110/110, including
allocation-failure coverage proving that converted plans retain their own schema
and output names (`query-native-cutover-build21.log`). Native binding package
tests pass 18/18 (`native-cutover-bindings4.log`).

Fuze tests pass 254/254 (`fuze-native-cutover9.log`), including original SQL token
locations, owned quoted identifiers, active alias context and literal mismatch
evidence. The real CLI diagnostic corpus passes 592 subprocess cases
(`native-cutover-cli-diagnostics8.log`); lifecycle tests pass 30/30 and diagnostic
projections pass 3142 cases across 34 surfaces (`native-cutover-outcomes5.log`).
Logs are in the local Table-schema campaign. These checks qualify codecs,
diagnostics and local rendering; installed SDK transports and complete root/clean
checks remain separate work.

### Catalog-bound Flight codec migration

Flight package tests pass 14/14 (`flight-logical-build6.log` in the local
Table-schema campaign). The actual gateway executable compiles into an isolated
prefix (`flight-logical-app1.log`). Logical result adaptation preserves declared
nullability and owned names across 128 columns, rejects unsupported output types
before admission, checks unsigned COUNT narrowing, and binds tickets to the
current Transit definition and complete immutable Table declaration.

Pinned PyArrow independently reads the native producer's standard metadata and
128-column schema, quoted Unicode names, typed text filtering and text COUNT
outputs. Selecting text as a primitive Flight output rejects
(`flight-logical-metadata2.log`, ReleaseSafe). The shared parser refactor also
passes 254 Fuze and 110 query tests (`fuze-native-cutover10.log` and
`query-native-cutover-build22.log`). These are codec/compiler checks; the migrated
catalog-backed gateway still requires native disk, TLS, ADBC and recovery
qualification. Earlier two-column provisioning schedules do not qualify it.

### Bounded query memory failure isolation

Query tests pass 112/112 (`query-memory-budgets5.log` in the local Table-schema
campaign). Private catalog turns exercise explicit admission-buffer exhaustion,
execution-buffer exhaustion, Arrow workspace exhaustion, exact repeated
continuations and a later successful query. Failed candidates publish no result
segment and release their original captured pin. Separate injected ordinary
allocator, request-publication and poisoned Table-read failures preserve their
original infrastructure errors and untouched proposals.

The same owner reads a committed 600 KiB UTF-8 Table value using its normal 1 MiB
adapter buffer, records `adapter_memory_budget` and retains the unchanged stored
row. The five standalone catalog cases took approximately three minutes in
Debug with reported peak RSS 27 MiB; this is reference-store execution, not a
disk throughput or ReleaseSafe latency result. A redundant rerun was stopped
after the completed pass (`query-memory-budgets6.log`) and adds no evidence.

Fuze tests pass 254/254 (`fuze-memory-budgets2.log`). The real file-query corpus
passes 190 cases, including bounded Arrow output, exact codecs, cleanup and
192 MiB input under a 96 MiB address-space limit (`query-memory-file1.log`). Its
ordered batch splitting handles the new explicit workspace error. Diagnostic
mappings pass and 3179 projections across 34 surfaces pass
(`query-memory-mappings2.log`, `query-memory-outcomes2.log`). General allocator
failures are not relabeled as observed workspace exhaustion, and no required-byte
measurement is invented.

### Recursive query JSON admission

Shared query JSON preflight admits all 16 logical descriptor levels inside the
96-level JSON wrapper budget and rejects excessive nesting, invalid UTF-8 and
over-bound input before allocating. Query package tests pass 114/114, including
allocation-failure coverage for the deepest admitted descriptor and unchanged
private catalog schedules (`query-json-bounds1.log` in the local Table-schema
campaign). Native binding tests pass 18/18 (`bindings-json-bounds2.log`); a
hostile submit-shaped envelope reports `not_submitted` with local evidence, and
the same handle remains usable. The CLI diagnostic corpus passes 592 cases and
console lifecycle tests pass 31/31 (`cli-json-bounds2.log`). These are local parser/codec checks; Board and native
Flight transport qualification remains part of the wider cutover.

### Current schema inspection and retained authorization

ReleaseSafe query tests pass 114/114 (`query-current-metadata2.log` in the local
Table-schema campaign), including current definition rejection after ALTER and
DROP while the authorized original captured pages remain readable. Flight
package tests pass 14/14 (`flight-current-metadata1.log`). `describe` validates
current Table metadata; exact upload recovery and retained-result authorization
use the independent current-rights check. These package checks do not qualify
the in-progress native transport fixture migration.

### General grammar at read-only query boundaries

Fuze tests pass 254/254 (`fuze-query-grammar1.log` in the local Table-schema
campaign). Valid implicit-column INSERT, DEFAULT VALUES, general CREATE, ALTER
and DROP receive interface guidance from the shared production grammar; the
query compiler reports non-SELECT input as unsupported. The real CLI diagnostic
corpus passes 592 cases, and 3179 diagnostic projections across 34 surfaces pass
(`query-grammar-outcomes1.log`). The native query/Flight fixture migration is
still being qualified separately.

### Catalog-backed native query and Flight callers

`zig build test-public-query -Doptimize=ReleaseSafe` passes on native disk-backed
Ursula with the configured cold tier (`public-query-catalog-native3.log` in the
local Table-schema campaign). Provisioning uses the production catalog owner,
CREATE/INSERT lifecycle, immutable source metadata and explicit requester policy.
The actual console and query hosts return 41 exact int64/null rows and preserve
lost-response retry, fenced restart, busy admission, current schema rejection,
incomplete-result refusal, cancellation and read-time revocation.

The pinned Flight shell's `zig build test-flight -Doptimize=ReleaseSafe` also
passes (`flight-catalog-native3.log`). PyArrow verifies finite schemas, exact
full-width/null rows, metadata and retry; installed Python and C ADBC consumers
verify native schema, values, aliases, empty results, counts and supported SUM.
The separately provisioned overflow source preserves the original diagnostic
through exact retry and gateway replacement, and denies details after current
disclosure revocation. The finite PyArrow portion took 55.47 seconds; the complete
Flight proof took approximately 13 minutes excluding compilation. These elapsed
times describe this functional schedule, not matched mutation latency.

Earlier migration attempts failed: two provisioning runs exceeded their original
60-second setup deadline; the next console run exposed the non-SELECT grammar
classification defect; and the next Flight run passed PyArrow but reached hot-tier
backpressure during ADBC. The final fixtures use the existing bounded cold-store
configuration and a 300-second provisioning deadline. No resident quota was
raised. Compose/Substrate placements, Flight fault/concurrency schedules, wider
SDK transports and matched performance remain separate qualification work.

### Logical query browser contracts and rendering

The query browser suite passes 35 tests and the Board browser suite passes 77
tests, with strict TypeScript, formatting and lint checks. Work-items browser
type and lint checks also pass (`browser-contract-final1.log` and
`board-browser-lint1.log` in the local Table-schema campaign). Cases cover all
integer widths, exact decimals, finite floats including signed zero, temporal
and UUID values, nested containers, canonical map keys, bounded JSON, all five
cell states, Unicode names, 128 columns and hostile recursive inputs. A maximal
retained-query bundle fits the shared 64 KiB request envelope; oversized requests
reject before transport. The existing live-view coverage projection is tested,
but this does not qualify the native reactive owner migration.

Query and Board contract exports regenerate with resolvable embedded recursive
references. Browser declarations and validators pass drift checks, the schema
correspondence check passes, and shared declaration generation rejects foreign
references (`browser-schema-types1.log`). Native ReleaseSafe query tests pass
114/114 and Board API tests pass 13/13 (`query-browser-native1.log` and
`board-api-logical1.log`). Subsequent sequence-bound schema annotations compile
through the exporters and pass the browser schema checks; the native test runs
precede those annotation-only changes.

The locked frontend install and Vite+ build pass (`board-browser-build1.log`).
Reported chunks include index 406.36 kB, query 1060.71 kB and inspection
1576.71 kB before gzip; the build still warns about large generated-validator
chunks. This browser build does not qualify the embedded Board binary or the
still-pending native reactive/work-items migration. Earlier browser migration
attempts failed on stale basis and cell fixtures before the recorded passes.

### Recursive Node port admission

The native Node port bounds JSON depth, nodes and text before invoking recursive
generated validators. Tests reject cyclic/deep requests, invalid Unicode and
nonfinite numbers without calling the validator, then successfully reuse the
same port with shared object references. Deep responses preserve read failure
versus uncertain mutation outcomes. All three port cases and the existing error
case pass, with strict TypeScript, formatting and lint checks
(`node-query-fullcheck1.log` in the local Table-schema campaign). These local
transport tests do not establish catalog authority or native query completion.

### Catalog commitments and TypeScript logical query callers

Neutral catalog metadata includes the immutable publication commitment needed
to build a query declaration without reproducing catalog hashing in a host SDK.
Catalog ReleaseSafe tests pass 98/98, including commitment changes on rename and
agreement between lookup and listing (`catalog-metadata-commitment1.log` in the
local Table-schema campaign). Recursive Station ABI exports and host declarations
regenerate, pass drift checks and retain root-local schema references. Native
binding tests pass 18/18 (`sdk-query-native1.log`). Explicit empty output-name
arrays reject instead of being reinterpreted as omitted aliases.

The native ABI and local port pass 108 shared cases in `test-unified-codec`
(`unified-logical-codec3.log`): three source bundles, nine independently encoded
schema-bound Boolean plans, six scalar Arrow columns, all five states, exact
values, empty results and malformed rejection. The producer supplies the exact
canonical schema header required by logical decoding; PyArrow independently
interprets the generated values and writes the tested record batches. This
qualifies that header/payload profile, not arbitrary foreign Arrow schemas.

Fresh Node tarballs pass the installed codec schedule, including 128 Unicode
columns, a uint128 predicate, nested uint128/null results, owned bundle bytes and
malformed rejection (`node-query-installed2.log`). Strict TypeScript, formatting
and lint checks pass; 53 existing Station tests and two query boundary tests
pass. The latter preserve recursive inspection types and freeze catalog metadata
and binary/full-width SQL parameters before asynchronous transport. Their fake
host deliberately returns an invalid compilation response and proves no remote
authority or query completion (`node-query-fullcheck1.log` and
`node-query-boundary1.log`).

Earlier attempts exposed the empty-alias regression, stale null-kind fixture
tags and a nested fixture that used a noncanonical root field name; corrected
runs pass. A TypeScript build also rejected an unavailable target-library string
method before its replacement. Remaining language query models, native SDK
recovery schedules and the coordinated definition cutover are separate work;
regenerated resources alone do not qualify those callers.

### Python logical query caller

Strict mypy passes all 25 client, Station and example source files
(`python-query-build1.log` in the local Table-schema campaign). Fresh wheels
installed outside the checkout pass the shared three-source/nine-Boolean-plan
codec schedule, six scalar Arrow columns and five states, plus 128 Unicode
columns, uint128 comparison and nested uint128/null decoding
(`python-query-installed1.log`). The public query API reuses immutable logical
descriptors/cells, constructs Table declarations from catalog metadata and
preserves the retained manifest head. The initial type-check caught an accidental
conversion of a KV decoder as a predicate atom; it was corrected before the
passing build. Native synchronous/asynchronous query recovery schedules remain
unqualified until their shared catalog fixture migration is complete.

### Ruby logical query caller

Fresh Ruby gems pass the installed three-source/nine-Boolean-plan codec schedule,
six scalar Arrow columns and all five states, 128 Unicode columns and a uint128
predicate, and nested uint128/null decoding (`ruby-query-build1.log` and
`ruby-query-installed1.log` in the local Table-schema campaign). The nested
fixture uses the production Arrow encoder and is independently interpreted by
PyArrow before the installed SDK reads it. Ruby reuses its owned logical values,
retains the source-head digest and takes Table source identity from catalog
metadata and its mandatory immutable commitment. Syntax checks pass
(`ruby-query-syntax1.log`). Native recovery and authorization schedules remain
unqualified until the common catalog query fixture is migrated.

### Rust logical query caller

Rust's nine Station unit tests pass with locked offline dependencies, including
missing/foreign/oversized catalog metadata commitments and retained metadata
identity (`rust-query-test3.log` in the local Table-schema campaign). A fresh
crate installation passes the shared codec schedule, 128 Unicode columns, a
uint128 predicate, nested uint128/null decoding and malformed Arrow rejection;
the independent compile-failure check still rejects overlapping mutable client
borrows (`rust-query-installed1.log`). Registry dependency identities match the
packaged lockfile. Query descriptors/atoms/cells reuse the logical API and
manifests retain the source-head digest.

The first source test invocation lacked the required native library location;
the next exposed a catalog fixture without the newly mandatory commitment.
Both were corrected before the passing run. These local checks do not qualify
signed native query recovery; its shared fixture migration remains outstanding.

### Java logical query caller

Fresh Java JARs and examples compile with Java 21, all lint warnings enabled and
warnings treated as errors (`java-query-build1.log` in the local Table-schema
campaign). Their installed public query consumer passes the shared codec cases,
128 Unicode columns, a uint128 predicate and nested uint128/null results
(`java-query-installed1.log`). Query results and bindings use shared immutable
logical models; Table declarations own catalog metadata and its commitment.
The installed catalog boundary schedule passes generated recursive-schema checks,
owned full-width/nested values, missing/foreign/oversized commitment rejection,
large frames, uncertain receipts and joined cancellation
(`java-query-boundary1.log`). Its injected port outcomes prove ownership and
classification, not durable query admission. Native query recovery remains
pending the common catalog fixture migration.

Python and Ruby's installed catalog boundary schedules also pass after migrating
their metadata fixtures to mandatory commitments
(`python-ruby-query-boundary1.log`). They verify retained commitment ownership,
reject missing/foreign/oversized/malformed commitments and preserve their existing
uncertain-receipt and joined-cancellation checks. These use the fresh query
wheels/gems recorded above, with injected boundary responses; live catalog
recovery remains separately qualified by its native schedule.

### .NET logical query caller

Fresh NuGet packages and examples build from the local feed
(`dotnet-query-build1.log` in the local Table-schema campaign). Their isolated
query consumer compiles with warnings as errors and passes the shared codec
schedule, 128 Unicode columns, uint128 predicates and nested uint128/null results
(`dotnet-query-installed1.log`). The isolated catalog boundary consumer passes
retained immutable commitment checks, malformed commitment rejection, schema
history, recursive budgets, uncertain receipts and actual native read
cancellation/join (`dotnet-query-boundary1.log`). Query inputs/results reuse the
logical model, and Table sources carry catalog metadata commitments. These
checks do not establish admitted-mutation cancellation or native query recovery;
the latter still requires the common catalog query fixture migration.

### Erlang and Elixir logical query callers

Fresh BEAM packages and examples compile with warnings as errors
(`beam-query-build1.log` in the local Table-schema campaign). Both isolated
installed callers pass the shared source/predicate/Arrow codec schedule,
128 Unicode columns, uint128 predicates and nested uint128/null results
(`beam-query-query1.log`). Both catalog boundary consumers pass retained
commitment checks, missing/malformed commitment rejection, schema history,
recursive bounds, large frames, uncertain receipts and joined waiter loss
(`beam-query-boundary1.log`). Catalog and query values survive their client
lifetimes. These local codecs and boundary schedules do not establish native
query recovery; the common catalog query fixture migration remains required.

### C and C++ catalog metadata commitments

The C SDK ReleaseSafe build and C++ ownership/codec check pass after adding
mandatory metadata commitments (`c-metadata-build1.log` and
`cpp-metadata-check1.log` in the local Table-schema campaign). Fresh installed
C/C++ artifacts pass 46 actual native-library boundary cases
(`c-metadata-installed2.log`): lookup/history identity, retained commitment bytes,
missing/malformed commitments, bounded requests, uncertain receipts and deferred
POSIX cancellation with close joining native work. This boundary schedule does
not establish durable catalog or query recovery.

### C and C++ logical query callers

The C ReleaseSafe query library and C++ ownership/codec check pass with
catalog-bound Table sources, shared logical descriptors/atoms/cells and owned
inspection results (`c-query-package-build1.log`, `cpp-query-check1.log` in the
local Table-schema campaign). Fresh installed C11/C++17 consumers compile with
warnings as errors and pass independent source/Boolean/Arrow fixtures, all five
cell states, input-buffer release, 128 Unicode columns, uint128 predicates,
nested uint128/null results and malformed Arrow rejection
(`c-query-installed3.log`). C++ client-copy rejection is preserved. These local
checks do not establish current-source authorization, retained inspection/page
lifetimes or durable query recovery; those require the common catalog query
fixture migration.

### SQL and typed single-predicate identity

Literal SQL, parameter binding and typed plans preserve identical canonical
bytes for one comparison or state atom, including redundant parentheses. Real
Boolean programs retain every instruction. ReleaseSafe Fuze checks pass 255
tests (`fuze-atom-canonical2.log` in the local Table-schema campaign); the query
package passes 109 tests with its five native catalog tests cached from the
preceding successful native run (`query-atom-canonical3.log`). The allocation
failure schedule disables backing-allocator resizing so each injected failure
uses the same arena-growth allocation path; it still verifies release at every
allocation failure.

The initial migrated disk-backed KV and Table schedules stopped at inspection
because SQL had encoded single atoms as one-instruction programs. Table seed
provisioning and the original lost-receipt retry completed in that failed run
(`unified-catalog-native1.log`); this is not a passed recovery schedule. The next
KV run exposed the separate predicate nesting limit regression. Its companion
Table run was interrupted before qualification. Full native query recovery
remains pending those corrections.

### Bounded typed Boolean parsing

Typed SELECT/UPDATE/DELETE parsing uses a fixed 64-entry operator stack with the
separate 64-instruction postfix budget. Boundary checks admit 63 NOT operators
plus one atom, 64 parentheses, and a mixed 64-entry stack; the next instruction
or stack entry rejects with its respective budget error. Existing precedence,
five-state truth and eager-error checks remain. ReleaseSafe Fuze passes 256
tests (`fuze-boolean-stack2.log` in the local Table-schema campaign) and query
passes all 114 tests, including five native catalog cases
(`query-boolean-stack1.log`). The first Fuze run retained an obsolete 16-level
rejection assertion; that failed run is not qualification. The native recovery
schedules and installed-SDK reruns are separate evidence.

### Catalog-backed unified query recovery

The common disk-backed query fixture now provisions Tables through the production
CatalogQueryOwner and public CREATE/INSERT operations, persists the actual
metadata-bound source, and delegates the authenticated catalog principal. It no
longer fabricates a positional Table declaration. The native Table schedule
passes recovery, current prefix denial, release and COUNT continuation checks
(`unified-catalog-native3.log` in the local Table-schema campaign): 41 rows,
six segments, 15,120 result bytes, eight resident authority pages and an 8 MiB
hot store. COUNT preserves partial 8/10 progress through exact upload retry and
worker/node/store replacement, and rejects partial results after cancellation.

The compound Table schedule passes with all ten freshly installed SDKs
(`unified-catalog-all-sdk1.log`): Python, TypeScript/Node, Ruby, Rust, C, C++,
Java, .NET, Erlang and Elixir. Thirteen enabled native/port/SDK consumers agree
on inspection, 64-instruction predicates, literal/typed/frozen compound bundles,
parameter errors, 39 selected rows, five segments and 13,328 result bytes.
The schedule loses seed/upload replies, preserves the original signed retry and
receipt, replaces source/requester/node/disk store after segment staging, denies
reads after revocation and releases the original source pin. All packages are
installed into fresh isolated consumers; local codec checks alone are not the
basis of this recovery claim.

The native KV and Document schedules also pass recovery and lifecycle
(`unified-logical-native3.log`): 41 and 12 rows respectively. Original budget,
policy and KV cell-decoder witnesses survive lost replies, live repair,
worker/node/store replacement and retirement. These two schedules do not include
installed SDKs. Provisioning and elapsed recovery durations in these logs are
not matched mutation-latency measurements.

The shared shell/Board/count/example oracles now read logical descriptors and
cells. COUNT and the native lifecycle paths above have executed; shell, Board,
browser, expiry and the combined writer schedule require their separate runs.
The combined fixture's Zig provisioning uses the new catalog owner, while its
Python interleaving/fault schedule is still being migrated and is not qualified.

### Catalog-backed reactive observations and refresh authority

ReleaseSafe serving checks pass all 48 tests (`serving-catalog-watch6.log` in the
local Table-schema campaign). Real catalog-backed snapshots test every read
boundary against concurrent cuts, full column names, explicit watch shape
admission, atomic multi-row publication, metadata invalidation and current
caller catalog denial. Head reservations may notify possible changes before
publication but expose only committed rows. Retained refresh diagnostics require
current caller catalog rights without requiring their old metadata to remain
live. Native resource access and service policy checks remain separate.

Generated OpenAPI/AsyncAPI/client schemas and the private host reflection check
pass (`reactive-catalog-generate1.log`, `reactive-catalog-contract1.log`); Board
TypeScript checking and 52 reactive/live-view cases pass
(`reactive-catalog-ts-check1.log`, `reactive-catalog-ts-test1.log`). Board builds
against the migrated reader (`serving-catalog-board2.log`). The final status
catalog-authorization addition is covered by serving package compilation and
local checks; the deployed native SSE/WebSocket/Follow examples still require
migration and qualification. These checks do not qualify that remaining work or
the coordinated shared-definition cutover.

### Logical parameter correction evidence

All 257 Fuze ReleaseSafe tests pass (`fuze-logical-preview1.log` in the local
Table-schema campaign). Binding errors retain the original parameter site,
expected descriptor and exact supplied atom: int128/uint128, decimal coefficient,
float, boolean, temporal units, interval and UUID. Text/binary previews own at
most 32 escaped bytes with explicit truncation; subsequent bindings reset that
flag. Invalid values require no allocation or source reads to format. The actual
CLI compiles with its 65-binding limit reflected in failure guidance
(`typed-table-point-preview1.log`); that run's separate native lifecycle schedule
failed a new residual-predicate scan-count assertion and is not a passed proof.

### Canonical comparison point routing

The general Table SELECT adapter recognizes a canonical single comparison as
well as a conjunction of qualified primary-key terms. The full native typed
Table schedule passes (`typed-table-point-preview2.log`): a matching equality
scans one row, an absent key scans zero, and a residual non-key predicate retains
the declared finite scan while evaluating the complete expression. Console
EXPLAIN reports the actual primary-key route. The schedule also executes the
existing catalog lifecycle, owner-loss recovery, typed console diagnostics,
exact lost-receipt resume/cancellation, metadata evolution and native bridge
cases with the four-write and 256-byte native value bounds. The first run's new
residual assertion incorrectly required key routing for an unqualified predicate;
that failed assertion is retained in `typed-table-point-preview1.log`.

The neutral SQL parameter boundary also preserves typed previews when decoding
fails against the expected descriptor (`query-neutral-preview1.log`: all 114
query ReleaseSafe tests pass; `console-neutral-preview-build1.log`: CLI builds).
A valid signed JSON atom supplied to unsigned LIMIT displays the exact number;
malformed canonical integer text retains its escaped encoding. Temporal units
and valid intervals remain typed; malformed intervals name the original failing
component. Preview scratch is bounded to 64 bytes and reads no additional source
state. The preceding console run exposed the quoted-number difference
(`console-logical-kv2.log`) and was not a passed console qualification.

### Console logical-value recovery qualification

The native KV console schedule passes with the generalized logical cells and
parameter atoms (`console-logical-kv3.log`, 480.18 seconds, ReleaseSafe CLI).
It exercises saved exact upload/resume after changed or deleted parameter files,
no-send binding diagnostics, command/file/stdin stopping, terminal completion and
history, uncertain-send and streamed-prefix Ctrl-C races, prompt reuse, batch
exit 130, and explicit private-CA TLS with trust/hostname rejection. Terminal
cold/warm measurements were 53.69/16.01 ms with a 19,980,288-byte RSS high-water;
these are fixture observations, not matched performance controls. The separate
offline history proof passes (`console-logical-history1.log`) with a valid KV
configuration and a network trap. Native Table lifecycle coverage remains in the
Table schedule above; this console run does not qualify the remaining Table
interactive, Board/browser or deployed reactive consumers.

### Exact-cut Table metadata reader

The public bounded resource reader passes all 19 client ReleaseSafe tests
(`client-cached-metadata2.log`), including cached absence, eviction/refetch,
coalesced misses and sticky rejection of a changed resource cut. All 115 query
ReleaseSafe tests pass (`query-cached-metadata2.log`), including interpretation
of current authorization against its original requested keys without another
policy lookup or borrowing a formerly mapped principal's rights. The console
build passes (`interactive-metadata-build2.log`).

The native interactive KV schedule still passes in 2.69 seconds with unchanged
request ceilings (`interactive-logical-kv3.log`). The Table schedule now executes
its complete value, predicate, cancellation, fresh-cut and current-denial
checks, but **fails** its final request-budget gate
(`interactive-logical-table3.log`). Exact-cut scratch reduces Table inspection
from 39 requests to 19. The general immutable row/index representation still
costs 231 requests for this 41-row scan, 63 for short LIMIT and 39 for a key point
lookup. Those measurements expose further batching work; they are not a passed
performance qualification. The prior run failed Table capture with
`UnrequestedResourceKey` (`interactive-logical-table2.log`).

### Recursive result-page bounds and real Board browser

The reflected query/Board page contract preserves independent bounds of eight
rows and 128 columns, with recursive logical collections retaining their own
bounds. All 34 protocol ReleaseSafe checks pass (`protocol-matrix-bounds4.log`),
and owning query/Board schemas agree. The native KV Board plus Chromium schedule
passes (`unified-logical-board-kv3.log`, 78.17 seconds), including generated
validators on actual responses, nine-row/129-column rejection, 128-column and
nested-list acceptance, competing readers, exact uncertain retry, explicit
submission, editing/result provenance and current prefix denial. Two Board
readers used at most 54,890,496 sampled RSS bytes in that run. Query, Board and
Station schemas and all host binding resources were regenerated from Zig
(`board-matrix-generate1.log`).

The preceding browser run failed a stale lowercase type-label expectation
(`unified-logical-board-kv2.log`); the console/browser now render canonical
`UINT64`. The earlier API run caught the lost outer row bound
(`unified-logical-board-kv1.log`). Native Table Board draft/generation schedules
and the remaining consumer migrations still require qualification. A prematurely
started root test build was stopped after compile failures in the not-yet-migrated
work-items example and the first schema-bound expression; its partial output in
`protocol-matrix-bounds1.log` is not a root-check pass.

### General Table page acquisition batching

All 87 Station and 115 query ReleaseSafe tests pass with bounded metadata/chunk
prefetch (`station-table-prefetch1.log`, `query-table-prefetch1.log`). A 4,100-byte
record acquires one header pair and three chunk batches (8+8+1); every read still
uses the ordinary publication decoder. Corrupt digest, retired descriptor and
current read denial reject, with no chunk acquisition after retirement. Catalog
definition reads group four known record addresses only after catalog rights
are checked. The actual console and Board builds pass
(`table-prefetch-app-build1.log`). Native request measurements and Table Board
integration are running separately and are not established by these local tests.

### Bounded Table index-node reuse

All 88 Station and 115 query ReleaseSafe tests pass with eight verified immutable
index bodies cached independently of the native entry buffer
(`station-table-node-cache2.log`, `query-table-node-cache1.log`). The adversarial
cache case verifies reuse through a second adapter, refetch at a changed cut,
output-buffer bounds, incompatible manifests, retirement, current access denial
and corrupt chunk rejection after a new basis. The first test run correctly
kept a failed Station read sticky; the test now acquires a fresh turn before
its separate corruption case (`station-table-node-cache1.log`).

The preceding native Table scan improved from 231 to 157 requests for 41 rows,
but still **failed** its old request ceiling (`interactive-logical-table4.log`).
It passed the correctness, cancellation and disclosure schedules before that
final budget gate. Those old limits describe a different physical layout and
are not a performance pass for the generalized row/index representation. The
latest node-cache runtime measurements remain a separate check.

### General Table Board and browser qualification

The Table native/Board/Chromium schedule passes in 739.02 seconds
(`unified-logical-board-table4.log`) using the frozen executables from the page
prefetch build. It preserves a 41-row, six-segment, 15,120-byte result through
lost upload receipts and worker/node/disk-store replacement, with eight authority
pages, an 8 MiB hot store and released source pins. Separate inspection/query
rights, current prefix denial, generated recursive validators, competing Board
instances, identical signed retries and bounded readers pass. Two Board processes
peak at 53,866,496 sampled RSS bytes in this run.

The Table draft schedule passes atomic start accounting, exhausted finite budget,
cross-instance exact retries, closed-generation replay and current source denial.
Chromium passes explicit SQL, editing/result provenance, finite Live drafts,
saved exact recovery and denial. The previous run reaches the budget boundary
but fails a stale HTTP 409 expectation (`unified-logical-board-table3.log`). The
corrected test requires HTTP 400, `query.draft_start_limit`, limit category and
unchanged draft state, matching the existing semantic response owner; no runtime
status mapping was changed to satisfy the test.

### General Table explicit catalog CLI

The explicit `transit catalog` command builds against `TableClient` and the same
`TableBridge` intent/session contract used by the enabled SDKs
(`catalog-cli-general-build1.log`). Its real CLI diagnostic schedule passes
**656 cases** (`catalog-cli-general-diagnostics4.log`), including local CREATE,
full-width identities, mandatory saved definitions and summary/byte agreement,
private non-replacing files, UTF-8 lookup names, saved-page consistency, malformed
artifacts before credential loading, offline help and output privacy. The native
lifecycle/large-artifact/exact-recovery schedule remains a separate running check.

Three earlier diagnostic runs fail test expectations: the removed `--table`
option now reports an unknown argument; a shallowly shared fixture scope changed
both sides of an intended mismatch; and general DDL reports its own precise code
and end-of-statement validation coordinate. Those cases now assert the selected
interface directly (`catalog-cli-general-diagnostics1.log` through `3.log`). A
first native invocation names an uninstalled proof executable and does not run;
the subsequent owning `test-typed-tables` task builds its actual artifacts before
qualification (`catalog-cli-general-native1.log`, `2.log`).

### General catalog CLI lifecycle and metadata retry

`zig build test-typed-tables -Doptimize=ReleaseSafe --summary all` passes all
nine build/run steps (`catalog-cli-general-native4.log` in the local Table-schema
campaign). The native schedule takes 162.930 seconds and includes 525 observed
turns, 141 sends, accepted-but-lost caller and supplied-host replies, exact
reconciliation and original versus replacement object identities. Each observed
turn stays within four native mutations and every inline value within 256 bytes.
These recovery timings are not a matched mutation-latency benchmark.

The CLI adapter uses original private compiled/prepared output files. It verifies
multi-column CREATE/INSERT, separate no-op matched/changed counts, late duplicate
atomic rejection, a lost send followed by a new caller instance, ALTER and
historical schema lookup, DELETE and DROP/recreate identity safety. A 142,101-byte
typed intent exceeds the former 64 KiB artifact limit; this framing case remains
locally saved and undispatched, and does not claim a 70 KiB row was executed by
this particular CLI schedule. The shared native/port schedule independently
qualifies typed large-value storage.

The first attempted CLI proof referenced an uninstalled executable and did not
run. The next found a real `StaleStateResource` race while preparing ALTER's next
step. The initial fix failed to compile; neither run passed. The corrected CLI
uses a separate response arena and at most eight retries within its request
deadline for locally unsubmitted reads with that exact native rejection. It does
not retry submit, permission denial or changed cursors, or replace saved intent.
The successful schedule above includes the corrected path.

### General Table owner with interleaved queries and writes

The migrated combined fixture passes in 51.275 seconds
(`combined-general-native5.log` in the local Table-schema campaign), using
frozen ReleaseSafe native/host/proof/library/CLI artifacts identified in that
log. The supplied owner recovers the exact original accepted catalog
initialization and query-delegation commits after lost replies, fresh ownership
and node/disk-store restart. Reader/writer policy is a separate explicit action;
initialization does not manufacture those permissions.

The schedule performs general catalog CREATE/DML through ABI and private CLI
artifacts, holds an actual final `STW1` applied publication, and verifies both a
retained durable query and an interactive snapshot keep their original rows.
The mutation uses the same numeric namespace as the query. Ordered self-delivery
is preserved: explicit resume advances the original Table operation while the
query continuation is withheld. The final interactive pause is 0.075 seconds;
the snapshot is not held through the whole upload.

Console checks cover separate matched/changed counts, no-op/zero-match DML,
late duplicate atomic rejection and attributed diagnostics, exact lost-send
recovery after caller restart, altered recovery identity rejection, applied
cancellation, staged-upload SIGINT cancellation and stopping subsequent SQL.
An admitted upload part rejected by policy remains `uploading` with a separate
`denied` input disposition, rather than fabricating a terminal operation result.
Cancellation closes that original upload; restoring DML policy leaves rows
unchanged. Query delegation, DML rights and native disclosure denial remain
independent.

Observed bounds are four native writes and 256-byte inline values across 186
turns. The 18,623 instrumented reads include busy polling and fault setup and
are not a production request budget or latency baseline. This run uses ABI and
CLI consumers, with no installed SDKs. The fixture's optional SDK lane now
selects the general catalog lifecycle scenarios; it needs separate execution.

Earlier migration attempts are retained as failed evidence: the old selective
self-delivery schedule hit `RouteBlocked`; the next failed to drain earlier
Table continuations before capturing a query; later assertions incorrectly
assumed every small request uses upload and that input rejection replaces the
operation phase. None of those runs is counted as passed.

### Bounded Table row acquisition

Station's 90 tests and query's 115 tests pass in ReleaseSafe with bounded
reference gathering and row prefetch (`station-table-row-prefetch1.log`,
`query-table-row-prefetch1.log`). One page gathers at most eight row references,
checks every Table manifest/publication header, then prefetches at most 32 chunk
keys in native batches of eight. Normal reads still check lifecycle, lengths,
digests, decoded schema and stable row identity. Large rows continue through
bounded incremental chunk reads. Partial page ownership unwinds on read or
allocation failure; no advanced cursor escapes. The current authorization check
still precedes page disclosure. These changes do not enlarge native values,
query page size, the 64-entry immutable read cache or the eight-node cache.

The real ReleaseSafe interactive Table schedule
(`interactive-logical-table6.log`) executes correctness, cancellation, prefix
and current-denial checks, then **fails** its unchanged historical request
ceilings. The 41-row full scan and COUNT now take 89 requests, down from 149 after
node caching and 231 before the metadata/chunk batching work. LIMIT 3 takes 28
instead of 40; LIMIT 0 remains 13, complete-key equality remains 24 and inspection
remains 11. Non-key ranges use the general Table's finite scan and take 89 in
this fixture; the earlier ordered-int64 range budget of three does not describe
this hash-key index.

The two full JSON scans take 0.347 and 0.305 seconds with about 22.1 MB sampled
caller RSS. These are instrumented observations from one run, not a matched
baseline latency claim. No durable updates occur. The failed request ceilings
remain active in the test; no warning threshold or assertion was raised to turn
this result into a pass. Resolving the current physical-profile budgets, wider
resident/cold-growth evidence and matched mutation performance remains open.

### General Table grammar and independent compiler oracles

The ReleaseSafe full SQL proof passes all seven build/run steps
(`general-table-sql-full2.log` in the local Table-schema campaign). All 76
published SQL examples parse. The 174 shared SELECT ASTs agree with
libpg_query, 142 scalar plans and paged Arrow results agree with the independent
reference, and the existing three-source/six-scalar/five-state suite retains
72 successful results and 27 explicit failures. Parameter qualification retains
26 canonical plans/results and 20 exact rejections. Its private scalar corpus
is not the public logical Table parameter ABI.

The new DDL oracle checks 270 grammar/compiler cases, including 238 exact
schema/identity/type/default/evolution comparisons and independently encoded
FTS1 bytes. Coverage includes all logical families, aliases, nested defaults,
128 columns, nullable columns, composite/no primary key, selected ALTER and
DROP, and separate offline KV/Document compilation. The DML oracle checks 44
cases: 37 PostgreSQL/ANTLR AST comparisons and 33 exact independent typed FDM1
plans. It covers reordered/omitted fields, DEFAULT, multi-row input, multiple
assignments, general Boolean/state predicates and compound literals. Decoding
the canonical intent retains its original fingerprint. These are pure
compilation proofs, not evidence of admission, stored uniqueness or atomic
publication; those have separate native schedules above.

`just test::table-ddl-sql` and `just test::table-dml-sql` are focused entry points
using the same implementations and oracles as `just test::sql`. Earlier runs
failed to unwrap the schema-evolution transition and then found a stale scalar
parameter fixture API in the full suite; neither is counted as passed.

### General Table diagnostic grammar and logical values

The migrated public diagnostic fixture passes 311 compiler cases and all 411
reference parser rule/alternative/optional/repetition obligations
(`general-table-diagnostic-grammar5.log`). It now executes general Table DDL and
DML compilers, while retaining scalar SELECT/template and offline KV/Document
profiles. New cases cover recursive descriptors/constructors, aliases, defaults,
primary keys, every selected ALTER form, DROP, omitted INSERT lists, multiple
assignments and precise malformed-value failures. Duplicate input primary keys
compile into an immutable intent; runtime uniqueness/publication proofs above
own their atomic rejection. SQL MAP constructors normalize key order; duplicate
keys remain errors.

ReleaseSafe Fuze tests pass 258/258 (`general-table-logical-diagnostics-unit1.log`).
Malformed date/time/timestamp/UUID/JSON values retain their original typed cause;
temporal and JSON failures retain the original literal location even with a
later column in the declaration. The structured result is locally not-submitted
and offers no resume/cancel action. JSON validation occurs during literal binding
rather than first reporting an error at a later schema validation boundary.
The independent mapping gate passes (`general-table-diagnostic-mappings3.log`),
including the already implemented reactive catalog denial and caught metadata
invalidation translations. No native serving schedule ran in this checkpoint.

Earlier diagnostic runs exposed unmapped temporal causes and incomplete new
parser-branch coverage. A proposed unsorted MAP rejection was incorrect because
SQL construction canonicalizes map order; its reviewed case now requires
successful compilation. None of those earlier runs is counted as passed.

### Application completion alongside staged Table writes

Station ReleaseSafe tests pass 92/92 (`table-application-completion1.log`).
`TableWrite.stepWithReserve` leaves one or two additional mutation slots on
terminal returns so an application can commit its progress and receipt with the
Table head/outcome. Building turns retain the existing four-write staging bound.
The reservation is physical scheduling, not part of logical mutation identity.

The new cases exercise small and 600-byte values with both reservation sizes,
discard every proposed turn before repeating it, and observe old rows and absent
application progress until one final commit. The final commit publishes the row
and application records together within four writes. Repeated terminal requests
retain the original completion identity and prepare no writes. Duplicate keys
retain room for the application's rejected receipt; invalid reservations and an
exhausted private turn restore the proposal. This is local transition evidence;
the serving/work-items example migrations and native restart schedules remain
separate, unfinished qualification.

### Typed serving counter and reactive consumers

The serving example uses the general catalog Table representation. Native
bootstrap waits for authorized discovery of the published `counter` metadata;
watch callers receive separate inspect/read policies, and finite query policy
maps the authenticated requester to its configured catalog principal.
Independent Python peers encode that discovered metadata, logical descriptors
and FQP1 plans. They do not synthesize a metadata commitment or turn a source
digest into authority.

ReleaseSafe evidence on 2026-10-06:

- `general-counter-unit2.log`: 3/3 local tests. Nineteen accepted calls exceed a
  native page; discarded turns reproduce the same frozen deltas and original
  replies. Overflow leaves row/progress unchanged, zero deltas retain exact
  results, foreign origins reject, and an exhausted output budget restores all
  tentative row/index/application writes. Peak test RSS is 13 MiB.
- `general-serving-native4.log`: native signed service, original delivery/commit
  retries, two-gateway retry, worker/node/disk recovery and current revocation
  pass in 7.19 seconds. Fault delivery IDs are selected from the actual service
  call/reply outbox entries, excluding bootstrap and counter self continuations.
- `general-reactive-native1.log`: real nginx TLS, WebSocket/SSE, attachment
  fencing, current denial and full native restart pass (8.72-second trace).
- `general-reactive-limits1.log`: four sessions/held streams, reserved health and
  renewal, malformed frames, signed cursors, twelve reconnects and an actually
  published finite Table's expiry pass. Gateway RSS is 57,311,232 bytes under the
  existing 256 MiB ceiling; health takes 4 ms. The full trace takes 51.76 seconds.
- `general-reactive-client2.log`: private Zig caller preparation, exact lost
  receipt recovery, committed controls, source-cut coverage and denial pass
  (2.92-second trace).
- `general-reactive-refresh3.log`: two views under one principal, one admitted
  query, fair successor, lost follow receipt, worker replacement, full-width
  identities, and current entry-read denial pass (46.04-second trace).
- `general-reactive-views2.log`: actual Chromium Board/counter lifecycle,
  shared-principal tabs, transport resume, pagehide/expiry, explicit resnapshot
  after watch reset and retained source basis after retirement pass in 49.60
  seconds.

Earlier attempts caught an excessive fixture row quota, an incorrect CLI build
artifact, old neutral-type/source-cut expectations and a digest-only query policy
that correctly denied the new Table source. Those runs failed; the first browser
build was cancelled before its corrected policy run. Physical placement runners
are migrated but have not run at this checkpoint. Full clean-source CI and the
coordinated contract definition replacement remain pending.

The complete SQL suite also passes after the diagnostic additions and Table
completion reservation (`general-table-sql-full3.log`, seven build steps). This
retains the separately recorded independent grammar/AST/schema/plan counts.

### Counter continuation across chunked Table indexes

`general-counter-unit3.log` passes 4/4 ReleaseSafe tests. The new case inserts
nineteen distinct keys, crossing inline-index and native-page bounds, and checks
all prior rows after each completion. It retains the discarded-turn and exhausted
output-budget schedules. Test execution takes 184 ms with 13 MiB peak RSS.

The first combined serving lifetime/growth run failed with
`PublicationReadAfterMutation`: a frozen counter command was written before the
same turn acquired a chunked immutable index. The owner now commits that frozen
command before a subsequent turn stages its Table write. The final Table,
application progress and reply boundary remains unchanged. The second run passed
64 retained operations but reached the cold-disabled fixture's 64 MiB hot-store
ceiling at operation 169. It is failed growth evidence, not a lifetime/growth pass;
qualification with bounded hot storage and cold spill remains separate.

### General Table serving on Compose

`general-serving-compose3.log` passes the real static ReleaseSafe Compose
placement in 19.70 seconds: two nginx TLS gateways, exact HTTP retry, worker,
gateway, node and disk-store replacement, fresh ownership activation, immutable
counter outcome, retirement and current denial. The reactive trace also passes
WebSocket/SSE replacement fencing and retained session/source meaning; its lease
did not elapse during this recovery schedule. Authority retains eight resident
pages and Ursula eight MiB of hot storage. The owned native MinIO fixture holds
25 cold data objects and 1,255,689 filesystem bytes at the final observation.

The placement now binds pinned native MinIO to its own private storage bridge
and includes the exact selected port in its caller/gateway denial probes. Cleanup
owns the native process independently of placement teardown. Signed provisioning
includes the current explicit collection/history fields. The first attempt failed
because the runner expected the removed Docker cold-store API; the second failed
native authentication because those signed fields were missing. Neither attempt
passed. Reference placement and the combined cold-growth trace remain unqualified
at this checkpoint.

### Staged application migration steps

`application-staged-migration3.log` passes 41/41 ReleaseSafe Station application
tests (28 ms execution, 8 MiB peak test RSS). Independent Python fixtures pin the
new 191-byte-maximum pending-step envelope alongside existing plan, progress,
receipt and diagnostic layouts. The pending envelope and terminal receipt share
one key; completion replaces it without an additional deletion mutation.

The new schedules freeze admission before domain work, discard and reconstruct
staging/completion turns, reject changed arguments, check current revocation and
original plan ownership, preserve prior proposals after read/domain/budget
failures, and retain pending evidence after abandonment. Three building rounds
use all four domain writes without advancing ledger progress. Normal completion
uses two domain plus two ledger writes; activation uses one plus three. Completed
receipts retain first admission separately from the final progress input and
replay without invoking the domain. Only an owner self-message can continue an
already admitted step; it cannot admit work or bypass revoked operator policy.

The first package run failed a new discarded-turn assertion because the test
reset the mandatory captured view as well as its proposal. The corrected
40-test run passed before the owner-continuation cases were added. These are
local ledger proofs; they do not qualify a migrated work-item application or
native placement. The coordinated current-definition cutover remains pending.

### Serving retained growth with bounded hot storage

`general-serving-growth6.log` passes the combined ReleaseSafe lifetime/growth
trace in 419.31 seconds (all nine build steps). It retains 128 additional exact
operations, rereads early receipts and preserves immutable outcomes across worker,
gateway, node and disk restart, cancellation, authenticated timeout, late replies,
finite expiry and current policy/native revocation. Authority retains eight
resident pages. The eight MiB hot-store profile spills to 488 cold data objects,
with 128,143,451 filesystem bytes at the measured point. Authority, both workers
and one gateway together use 81,838,080 resident bytes under the existing
536,870,912-byte ceiling. This end-to-end fault trace is not a point-mutation
latency benchmark; matched mutation measurements remain separate work.

The third growth attempt was interrupted to correct cold metric collection before
its final assertion. The fourth encountered temporary native `HttpCapacity`
after recovery. The fixture now retries identical serialized signed submission
bytes within ten seconds for that specific unavailable response; explicit
503/fault assertions still observe their original result. The fifth attempt
caught a null diagnostic in that fixture helper. Only the sixth complete run is
counted as passed. The hot-store ceiling was reduced from the cold-disabled
fixture's 64 MiB to the existing cold fixture's eight MiB, not enlarged.

### Stored staged-migration evidence before caller attribution

`application-staged-migration4.log` passes 42/42 ReleaseSafe Station application
tests (29 ms execution, 8 MiB peak test RSS). The added corruption schedule checks
zero admission input, wrong stored ordinal, changed digest, invalid operation and
changed stored arguments. Each remains `InvalidApplicationRecord`, preserves the
existing proposal and invokes no domain transform. Validation of frozen evidence
precedes comparing the caller's requested digest; stored corruption cannot become
a terminal `MigrationStepConflict`. The public authority check also permits an
application to gate target inspection before invoking `begin`.

`general-work-items-mappings2.log` passes the declared semantic diagnostic mapping
gate, including the explicit invariant exception tied to that executable test.
Its preceding run correctly failed because the newly surfaced stored-record error
had no reviewed disposition. Native application and browser runs are separate
qualification; these package results do not establish their completion.

### Work-item typed Tables and staged application migration

`general-work-items-unit4.log` passes 9/9 ReleaseSafe tests (280 ms execution,
13 MiB peak test RSS). The application uses general catalog Tables, stable hidden
row cursors and actual published source metadata. Thirty-three rows require 69
logical migration steps: one-row copies, a phase transition, one-row verification,
a second transition and activation. Each step freezes its original input before
Table staging. Completion publishes the Table head, Table outcome, migration
progress and exact step receipt in four native writes. Tests include empty and
abandoned targets, changed cursors, corrupt stored values, current policy denial,
explicit write release and separately authorized catalog/read policy. Accepted
queued puts prevent a new migration until their Table publication completes.

`general-work-items-native3.log` passes all eight build/proof steps in 142.71
seconds of native execution: nineteen rows, two fresh-key worker replacements,
authority/disk restarts, exact operator and worker retries, retained rejection
witnesses, complete verification and old-epoch rejection. The transport observes
583 accepted turn submissions, 287 bounded page reads, at most four mutations and
256-byte native values. Its 39 transport disconnects occur during owned caller or
authority replacement; exact recovery still must finish within the fixture's
finite deadlines. The first run failed because completion observation used a
stale resource revision; whole-read retries now preserve the signed command.
The second completed its domain schedule but failed the fixture's disconnect
classification. Only the third run counts as a native pass.

`general-work-items-browser2.log` passes all twelve build/proof steps in 185.65
seconds, including 51.47 seconds provisioning. Actual Chromium covers all nineteen
rows, three result pages, application schema/interface publication, gateway
replacement, original upload recovery/cancellation, the new schema and current
denial. Peak RSS bytes are 49,737,728 for authority, 18,898,944 for the data owner,
11,583,488 for publication, 15,314,944 for the requester, 12,333,056 for delivery,
and 28,372,992/33,071,104 for the two gateway incarnations. The first browser run
failed after the publication worker's initial ownership read encountered temporary
native capacity pressure. Startup now retries availability within its configured
request deadline before writing the activation marker; it still refuses denied
or stale ownership. The fixture uses bounded hot storage with cold spill.

Standalone package builds pass, as do the independent WI1 cursor/command fixtures
and documentation links. Physical placements and local application installation
remain separate schedules; these results do not qualify either or the coordinated
current-definition cutover.

### Retained startup and strict definition spelling

`node-retained-recovery5.log` passes all five build/proof steps over a disk-backed
Ursula restart. An owned storage peer closes the first connection and returns
503 on the next; ordinary recovery succeeds on its third attempt. Persistent
503 exhausts three attempts. Denied/missing history, wrong genesis, corrupt
JSON, foreign definitions and missing definitions fail immediately. The published
tail stays at one and the peer observes no storage mutations. Provider-request
duration is not a whole-startup deadline. The earlier baseline fault schedule
passed, while expanded runs exposed an all-zero enum alias and fixture issues;
only the fifth run covers the complete rejection schedule.

The all-zero fingerprint was previously accepted as enum ordinal zero by Zig's
generic JSON decoder. The shared definition now accepts only the exact current
identifier string in both streaming and value-based JSON decoding.
`strict-definition-unit1.log` passes 35/35 ReleaseSafe protocol tests (9 ms,
5 MiB peak test RSS), including numeric/all-zero/nonstring rejection and exact
round trips. Documentation and semantic diagnostic mapping checks pass. These
checks do not substitute for the coordinated identifier replacement or full CI.

### Local work-item installation and staged recovery

`general-work-items-install6.log` passes the standalone local installation
schedule in 242.698 seconds: nineteen typed rows, 41 logical migration steps,
full target verification, schema activation/release, fresh worker generations and
retained authority/storage recovery. Its largest application checkpoint is 3,207
bytes, manager peak RSS is 42,057,728 bytes, and the installation retains 23
management receipts. Explicit `prepare-table` commands reconcile domain readiness
separately from the manager's native readiness record.

`general-work-items-install-faults4.log` passes in 68.796 seconds. It loses spawn,
worker-rotation, migration-send, worker-turn and activation-send replies, checks
exact recorded retries, and preserves current denials. A deliberately unavailable
authority liveness read leaves the live owners unchanged; three consecutive
unavailable observations still enter the bounded restart path. The concurrent
management denial schedule observes a one-millisecond control response in this
run; this is a fixture observation, not a latency guarantee. The local courier
explicitly selects all destinations when applications are enabled and retains
bounded native pages and independently authorized delivery.

Earlier installation/fault runs are not passes: they exposed missing self-message
delivery, temporary observation errors, a restart triggered by one unavailable
probe, and fixture retries that confused unavailable reads with domain denials.
One installation attempt was invalidated by replacing a referenced executable
during the run; the installation correctly rejected its changed artifact identity.
The passing runs keep their referenced binaries fixed. Expected mutation errors
still reconcile the same saved command through temporary availability failures;
an unavailable observation never counts as the expected domain rejection.

### Explicit root catalog administration

`catalog-root-administrator1.log` passes 99/99 ReleaseSafe catalog tests (265 ms,
22 MiB peak test RSS). General catalog configuration accepts native principal zero
as an explicitly chosen administrator, consistently with policy and operation
principal fields. The new test creates and discovers a typed Table under that
identity, refuses another initializer, rejects invalid owner/principal bounds,
and verifies that repeated initialization cannot restore revoked read rights.
Root has no implicit catalog policy when another administrator was selected.

### Physical work-item placements

`general-work-items-compose2.log` passes in 328.33 seconds, including 126.02
seconds of image work, with 124,264,730 retained cold bytes.
`general-work-items-reference2.log` passes in 345.79 seconds, including 6.74
seconds of image work, with 62,419,677 retained cold bytes. Each uses actual
physical owners and Chromium, private TLS ingress and role isolation, original
query recovery across worker/node/store/gateway replacement, application schema
publication, complete pagination and current denial. Reference placement uses
fresh registered owners in separate Substrate Actors. These are finite recovery
proofs, not matched throughput measurements.

The physical runner owns a native cold fixture bound to the private IPv4 Docker
bridge; it retains the cold fixture independently of role/storage replacement.
Dual-stack networks select their IPv4 gateway explicitly. The first Compose run
failed on a transient connection closure opening retained history; the first
reference run failed because it assumed the first network address had an IPv4
gateway. Neither counts as a pass. Both passing runs complete their owned
placement teardown. Local installation and physical placement now have separate
executed evidence for the migrated work-item application.

### Station ledger on general Tables and finite query publications

At `96ec89a4` plus the following Station ledger migration, the ReleaseSafe
example build passed all four build steps (`general-station-ledger-build4.log`).
The isolated disk-backed core schedule passed
(`general-station-ledger-native5.log`): 7 + 5 - 2 = 10; identical retry bytes
after a lost terminal receipt; worker, node and disk-store replacement; stale
ownership rejection; independently decoded typed Arrow segments and coverage;
replacement of both query hosts after capture; policy denial before capture and
revocation during capture; and inspectable poisoned input with working native
termination. The terminal mutation is observed to contain exactly four KV writes
(Table head, exact Table outcome, application audit and pending-work removal)
and the original call reply in the same turn. Queue admission is not completion.

The service schedule passed (`general-station-ledger-services2.log`): registry
rebind retains the resolved old PID, a timed-out call still completes its
accepted application work without reopening the wait, and separately scoped
supervision reaches every child across multiple pages. The lifetime schedule
passed (`general-station-ledger-lifetime1.log`): typed state survives suspension
and recovery, expired dependencies never reactivate, and opted-in reclamation
survives authority restart. Both use the real courier for staged self-messages.

The first native run against the new application (`native4`) failed when
PID-scoped readers lacked optional query-peer associations despite having resource
grants. Provisioning now supplies both. The first service schedule incorrectly
waited for a reply to a registry-routed cast; it now checks that cast's committed
audit entry. Neither failed run is completion evidence. These logs are in
`/var/tmp/transit-table-75-_el6xx0v`, with the full `general-station-ledger-`
prefix. Local/Compose/reference ledger placements and the final clean checkout
remain separate qualification work; earlier placement results do not qualify
this changed application.

### Board metadata follows general Table and query records

At `86b11d69` plus the metadata projection change, standalone ReleaseSafe Station
tests passed **93/93** (`general-board-metadata-station1.log`, 2 seconds, 13 MiB
maximum resident memory), and Board API tests passed **13/13**
(`general-board-metadata-api2.log`, 5 ms, 4 MiB). They verify exact typed-head
keys/resource identity, incompatible definitions, full-width object/revision and
publication namespace identities, and rejection of superseded metadata layouts.
Generated Board OpenAPI/types/validators match their Zig owner
(`general-board-metadata-contract1.log`). Frontend formatting, lint, strict types
and **77 tests** passed (`general-board-metadata-web1.log`); the embedded
ReleaseSafe Board and ledger build passed (`general-board-metadata-build1.log`).

The first browser schedule (`general-board-metadata-native1.log`) passed actual
API metadata validation but failed two browser assertions: the fixture still
expected the removed Table key, and a query JavaScript chunk had grown to
1,070,791 bytes, exceeding the existing 900,000-byte bound. The key expectation
is migrated with the head fixture. The asset regression requires a separate
validator-generation correction; this run is **not** a passing browser or
complete native Board proof. A preceding generator build failed on a removed
Zig array repetition operator; the corrected second generator/API run passed.
Logs remain in `/var/tmp/transit-table-75-_el6xx0v`.

### General Station ledger: local deployment and courier replacement

The changed ledger and Board metadata passed the actual local launcher schedule
(`general-station-ledger-local1.log` in `/var/tmp/transit-table-75-_el6xx0v`).
The selected ReleaseSafe artifacts record `86b11d69` plus the Board migration.
The proof verifies 12 → 10 → 13 → 14 totals through exact repeated sends, worker
replacement and a genuine Debug upgrade of all three roles; stable PIDs/resources;
no-op update; persistent down/up; and current typed-head/request/execution lenses
with source provenance. Audit scans use one bounded native snapshot, so concurrent
commits cannot mix revisions. The owned installation `station-9fab12` was stopped
and reset after success.

During intentional courier readiness failure, 292 reads were refused and one
replacement completed in **30.241 seconds**, within the original 60-second
replacement deadline. The submitted query completed **3.933 seconds** after
recovery, within its separate fixed 60-second completion deadline. The recorded
reply elapsed time is **32.836 seconds**. All assertions passed before cleanup;
a cleanup restart cannot turn an incomplete query into a passing result. This
is a fault schedule, not normal query latency. Compose and reference remain
separate pending placement checks for this application revision.

### General Station ledger: Compose and reference deployments

The same application subsequently passed both physical placement schedules:
`general-station-ledger-compose1.log` and
`general-station-ledger-reference1.log` in
`/var/tmp/transit-table-75-_el6xx0v`. Both verify registry/call/typed Arrow
exchange, same-PID recovery, upgrades across all three workers, current Board
provenance, and persistent stop/start. Their disposable installations were
stopped and reset after success. The reference schedule also replaces the
ledger's actual Kubernetes pod. These runs qualify the API metadata and
application recovery paths; they do not substitute for Board's separate browser
asset and startup proof.

### General Table validators and bounded Board assets

The recursive-schema sharing correction preserves JSON-pointer ancestors and
reference scopes while extracting repeated closed types. Six differential AJV
tests and all five generated-validator drift checks pass
(`general-validator-contract1.log`). Board's standalone validator decreases
from 2,298,933 to 1,372,590 source bytes. The generated public schemas are unchanged.
The five embedded JavaScript chunks are approximately 0.58, 405.54, 611.95,
768.06 and 851.36 kB; the original five-file/900,000-byte browser bounds remain.

`general-validator-board-native2.log` passes **8/8** ReleaseSafe build/proof
steps, including all **5** real embedded browser tests in 17.9 seconds. It also
checks actual API responses, current typed-head metadata, private access,
revocation, gaps/effects, outages and load; maximum measured control latency is
16 ms. Board and query formatting/lint and **77/35** unit tests pass
(`general-validator-web-final0.log`, `general-validator-web-final1.log`), as do
their strict TypeScript checks (`general-validator-board-types1.log`,
`general-validator-query-types1.log`). Reactive source checks passed with its
existing exception-assignment lint warning; that package has no standalone test
files, so the attempted package test command was not a passing test run. Its
consumer tests run in the Board suite.

The preceding embedded run (`general-validator-board-native1.log`) failed all
five browser cases on a module-initialization cycle after splitting query and
reactive validators. The caller gate now has a small public entry and shares its
error class without importing the reactive transport entry. A static browser
startup check and the complete second native run verify the correction. An
intermediate build invoked from the repository root failed to find an entry;
the subsequent build ran in the owning app directory. Failed attempts are not
counted as qualification. Logs remain in `/var/tmp/transit-table-75-_el6xx0v`.

### Signed bodies require explicit contract definitions

The signed-envelope decoder derives a required-definition wire body from the
unsigned authoring type. Both JSON entry points reject missing/foreign definitions,
quoted enum ordinals, string signatures and string snapshot nonces; saved wrappers
cannot restore the omitted field. Ordinary unsigned construction still supplies
the current definition before signing. Shared opaque values retain their owned
lowercase-hex codec when decoded from a JSON tree.

`general-signed-definition-unit3.log` passes **37/37** ReleaseSafe protocol tests
(9 ms, 5 MiB), including unchanged independent signing fixtures and ordinary/
recursive schema parity. `general-signed-definition-native1.log` passes the real
disk-backed inspection schedule, including command/query missing and foreign
definitions, invalid signature shape, no authority-position advance on rejection,
scoped pagination, revocation and node/store recovery. Native, installation,
ABI/binding and browser resources were regenerated and their drift checks pass
(`general-signed-definition-contract1.log`); documentation links also pass.

The first unit compile rejected an overly broad custom-parser error set. The
second run exposed that opaque `Value` had only a token decoder; its matching
JSON-tree decoder fixes the signed body round-trip. Those attempts failed and
are retained as `general-signed-definition-unit1.log`, `unit2.log` and the focused
debug logs in `/var/tmp/transit-table-75-_el6xx0v`. The shared definition replacement
for the complete Table cutover remains a separate pending step.

### General catalog seeded publication and recovery oracle

The catalog domain simulation uses the general `TableCatalog` owner and
three-column typed schemas. Each 64-operation schedule checks successful
creation, name/object conflicts and IF NOT EXISTS against retained intent and
original outcomes. It injects point-read failures, independently revokes inspect
or create rights during staging, discards private candidates, and replaces the
owner's in-memory fixture after lost replies. Every stage checks bounded writes,
unchanged state on failure/discard, invisible partial publication, exact terminal
retries, historical definitions and stale-page rejection.

`general-catalog-simulation-unit1.log` passes **99/99** ReleaseSafe catalog tests
(482 ms, 21 MiB). `general-catalog-simulation-domains1.log` passes **8/8** steps
and ten component schedules across two seeds, with identical replay in 1.488
seconds. These dynamic-map fixtures test deterministic contracts, not provider
durability. The four catalog mutation guards now target the general owner; the
refresh generation guard is aligned with its retained diagnostic implementation.
All nine guard anchors match once. Their committed-source mutation run remains
separate pending qualification. Logs are in `/var/tmp/transit-table-75-_el6xx0v`.

The subsequent committed-HEAD run at `9953b670` passed its unmodified baseline
and detected **all nine** independently compiled domain defects, including the
four general catalog defects (create permission, inspection permission, changed
original completion position, and mixed-revision pagination). The
[recorded mutation results](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/general-table-catalog-mutations-2026-10-06.json)
retain revision and per-defect status/timing. Full baseline, failure traces and
minimized reports remain in `.cache/verification/domain-simulation-mutations`;
the command log is `general-catalog-simulation-mutants1.log` in the same campaign.
Compile errors and stale source anchors were not counted as detected defects.

### General Table cold catalog growth

`general-table-growth-native2.log` in the local Table-schema campaign passes all
**9/9** ReleaseSafe build/run steps with `--grow 65 --cold` (564.604 seconds for
the complete native lifecycle, console, bridge, CLI and growth schedule). The
new schedule adds **65** three-column Tables with INTEGER primary keys, bounded
VARCHAR values and BOOL defaults, enumerates **10** metadata pages, replaces the
authority, disk store and application workers, and verifies identical metadata,
the first original saved mutation outcome and typed first/middle/last rows.
Optional installed SDK consumers were not selected in this run.

The actual cold provider holds **532** data objects and **139,708,974** bytes with
an **8 MiB** hot-store limit and eight authority resident pages. Sampled per-role
resident high-water marks are authority **35,393,536**, store **134,701,056**, and
workers **15,663,104 / 22,556,672** bytes, within the unchanged 512 MiB aggregate
proof ceiling. The complete schedule records 1,630 committed turns and 596 sends;
no turn exceeds four mutations or a 256-byte native value. This is process/store
replacement evidence, not a host power-loss proof.

The growth phase takes 397.798 seconds. Its median CREATE/INSERT wall times are
5.560/0.545 seconds through the subprocess-driven staged proof and deliberately
small cold-store working set. These measurements are not a matched console
latency comparison: the lifecycle includes separate saved-step invocations,
other local processes were active, and compilation overlapped part of growth.
The first build attempt
was deliberately interrupted before runtime after correcting an expected neutral
integer atom; `general-table-growth-native1.log` is not a passed schedule.

Failure retention now has a shared fixture helper, independent of the retired
creation-only runner. `general-table-growth-retention1.log` passes the fixture
checks for cold chunk/pack accounting, joining a native child before moving its
owned state, and retaining an unjoined provider privately without deletion. The
new general native runner invokes that helper after joining its owned authority
and workers on failure. This successful growth run did not exercise that failure
branch; the helper's injected lifecycle checks are separate evidence.

### General catalog implementation cutover

The creation-only catalog owner, signed/neutral callers, two-column record codecs
and their fixtures are removed. General `TableCatalog` / `TableClient` /
`TableBridge` supply the current catalog contract; `test::catalog` uses the real
general lifecycle runner, and `test::catalog-growth` selects 139 additional
Tables with cold storage. The shared scope/fingerprint and native page validators
remain without a legacy schema decoder. Historical results above describe the
source revision at which they ran, not an additional supported catalog profile.

`general-catalog-removal-unit2.log` passes **76/76** current ReleaseSafe component
tests (467 ms, 21 MiB test RSS). It replaces the former 99-test suite after
removing tests specific to the retired APIs; the general lifecycle, exact-recovery,
authorization and seeded-oracle tests remain. The first invocation used
`--build-file` from the root and failed configuration before running tests; the
successful run uses the owning package directory.

`general-catalog-removal-diagnostics5.log` passes **9/9** steps, **3,216** semantic
projections over **33** complete declared outcome surfaces, **18** inferred error
sets and **11** unknown-cause projections, including adversarial drift mutations.
The catalog registry now covers 67 explicit causes across 47 caller/source error
pairs, including saved-intent ownership, upload state and typed-operation limits.
All DDL operation states, delegated ALTER, unchanged CREATE and current catalog
denial in serving/Follow have explicit reviewed projections. Uncertain sends
retain their exact transport identity; a name lookup invents no operation ID.

The first diagnostics build exposed the retired bridge entry and an obsolete
reactive-source fixture. The second compiled and passed inferred-boundary checks,
but the outcome manifest lacked the already implemented catalog-denial variants.
The next isolated mapping run exposed the distinct serving catalog-denial code.
Those failed runs are retained as `general-catalog-removal-diagnostics1.log`,
`diagnostics2.log` and `outcomes3.log`; `outcomes4.log` passes the pre-DDL-phase
3,210-case matrix. Only `diagnostics5.log` includes the complete expanded matrix.

`general-catalog-removal-docs2.log`, `mappings2.log`, `fixtures1.log` and
`invariants2.log` pass local documentation links, semantic cause maps, independent
metadata/control/query-source bytes, and the 59-invariant/53-bound ownership
catalog. `general-catalog-removal-sdk-diagnostic2.log` validates the replacement
synthetic DML diagnostic against the current JSON schema with a full-width
operation ID; it does not run installed SDK consumers. Its first invocation
omitted a required CLI argument in the imported fixture module and did not run
validation. The larger cold native run and final definition/clean qualification
remain separate checkpoints.

### Root-authored catalog page recovery

The explicit CLI validates saved metadata authors as native principals, including
zero, rather than positive resource identities. `general-catalog-root-page-cli1.log`
passes **659** real CLI diagnostic cases and all **4/4** ReleaseSafe build/run
steps. The new cases accept authors zero, 1,234 and the maximum native principal
through local page validation, then require the missing signing credential as
before; an author above the native bound rejects as `InvalidCatalogPage`.
`general-catalog-root-page-negative1.log` runs the same regression against the
prior built binary and fails on zero with `InvalidCatalogIdentity`. Neither test
confers catalog rights or dispatches a request after local validation.

### General Table catalog growth beyond the former fixed capacity

`general-catalog-removal-growth139-1.log` in the local Table-schema campaign
passes **9/9** ReleaseSafe build/run steps and the complete native schedule in
**1,064.616 seconds**. The growth portion adds **139** three-column Tables,
enumerates **19** metadata pages, replaces the authority, disk store and workers,
and verifies the same metadata, original saved outcome and typed sampled rows.
The cold provider retains **1,010** data objects and **265,188,208** bytes under
the unchanged **8 MiB** hot-store limit and eight authority resident pages.
Resident high-water bytes are authority **34,967,552**, store **141,467,648**,
and workers **15,695,872 / 24,059,904**, within the existing 512 MiB aggregate
ceiling. Across the schedule, **2,888** turns and **1,114** sends never exceed
four mutations or a 256-byte native value. The growth portion takes 898.938
seconds. Compilation and other owned experiments overlapped this run; these
are growth/recovery results, not a controlled latency comparison. Installed SDK
consumers were not selected.

### Mutation latency harness on general Tables

The persistent public-client control uses `TableClient` intents and checkpoints
the exact intent, signed command and admission before observing each input and
its separate Table outcome. The console reader assembles typed snapshot frames
and requires matching final basis/plan evidence. The seven existing mutation
cases check matched/changed counts, including unchanged and absent rows, and
verify values through the general query path. The baseline uses its own revision's
harness; no obsolete result decoder is retained in the current harness.

`general-mutation-latency-reader1.log` passes **4/4** reader/timeline tests,
including fragmented frames, timing arriving first and rejection of a changed
completion plan. `general-mutation-latency-build1.log` builds the ReleaseSafe
CLI, node, query host, Board and persistent client into a private campaign prefix.
`general-mutation-latency-console-smoke1.json` and
`general-mutation-latency-client-smoke1.json` each complete one repetition of all
seven cases with **zero errors, unknown outcomes or supervisor restarts**. Both
use eight resident pages; only the client run enables native/provider probes.
Cold catalog growth overlaps these functional checks. Single samples and
instrumentation differences do not support a matched performance conclusion.
The console's single-row INSERT/UPDATE take 705/980 ms and its three-row INSERT
takes 5,112 ms; the instrumented client takes 1,544/1,994/11,356 ms respectively.
This exposes work to investigate, not a passed latency target. Controlled
baseline/current runs and staging/request-count analysis remain outstanding.

### Packed general Table publication

`Publication.stage` packs already-owned finite bytes into the remaining native
mutation slots, coalescing private descriptor/quota updates. General Table pages
and catalog metadata use it without changing the four-write boundary. The
regression matrix crosses 257/512/513/1,025-byte records with zero through four
occupied slots, discards and replays proposals, rejects conflicting immutable
content and inconsistent chunk evidence, verifies quota release, and refuses
private publication cursors. Existing cancellation tests still cancel every
committed CREATE/ALTER phase. Their former minimum phase counts and two-write
helper assumptions are replaced by bounded packed-progress checks.

`general-table-staging-unit2.log` passes **95/95** Station ReleaseSafe tests
(1 second, 14 MiB), and `general-catalog-staging-unit2.log` passes **76/76**
catalog tests (460 ms, 21 MiB). The first runs failed two and three assertions
respectively that encoded the former per-call write/phase counts; the raw and
direct-run detail logs retain those failures.
`general-table-staging-native1.log` passes **9/9** build/run steps and the signed
native lifecycle, console, bridge and catalog CLI schedule in **119.991 seconds**.
It records **401** turns and **141** sends, at most four mutations and 256 bytes
per native value, accepted-but-lost send/turn replies, supplied-host receipt loss
and two injected disconnects. Saved work continues to identify the original
objects after replacement. The earlier corresponding CLI/native schedule used
525 turns; wall-clock differences are not a matched latency comparison. Installed
SDK consumers were not selected. `general-table-staging-docs1.log` checks 5,313
local documentation links.

### Catalog acquisition cache and initial matched mutation comparison

`TableClient` uses the shared 64-key, one-revision resource cache for each
metadata acquisition, with chunk prefetch and shared failure poisoning across
point/page reads. `general-mutation-latency-staged-build1.log` builds the current
ReleaseSafe callers into a separate private prefix.
`general-table-cache-native1.log` passes the signed lifecycle/console/bridge/CLI
schedule in **120.318 seconds**, with **401** turns, **141** sends, lost receipts
and an injected disconnect. The callers use the new cache; the unchanged proof
and Station host binaries come from the preceding staging qualification.
All native writes remain at most four mutations and 256 bytes.

After that proof and all compilation finished, the owned runner executes the
baseline and candidate benchmarks sequentially with eight resident pages, no
proxies, no extra rows/history/readers and three repetitions per case. Each
revision uses its own harness. `general-mutation-latency-baseline2.json` records
clean baseline `cc5f57e7`; `general-mutation-latency-staged1.json` records `be358aeb`
plus the acquisition-cache changes and exact executable hashes. Both finish all
21 samples with zero errors, unknown outcomes or supervisor restarts.

| Case             | Baseline median ms | Candidate median ms |
| ---------------- | -----------------: | ------------------: |
| INSERT one       |             84.929 |             834.129 |
| UPDATE one       |             92.991 |             921.899 |
| UPDATE unchanged |             69.377 |             177.602 |
| UPDATE absent    |             76.444 |             166.060 |
| DELETE one       |             68.143 |             183.819 |
| DELETE absent    |             89.865 |             168.663 |
| INSERT three     |             70.212 |           3,866.094 |

Three samples do not establish tail percentiles. This is a measured regression,
not passed performance qualification; worker read amplification and polling
between staged outcomes remain under investigation. The first baseline attempt
failed before workload execution because its Board binary was absent. The first
Board build failed before locked frontend dependencies were installed; the second
build succeeded after installation. These setup failures remain in
`general-mutation-latency-baseline1.log` and `performance-baseline-board1.log`.

### General Table outcome scheduling

The console and persistent control call `TableClient.waitForChange` after a
running outcome. Its process-inspection hint uses the native authority position
from the same metadata acquisition, is tied to the exact connection/intent, and
requires a fresh outcome acquisition after the bounded wait. It does not infer
completion from a wakeup or mailbox progress. Known wait-capacity exhaustion
falls back to the existing bounded read-side delay.

`general-table-wait-client-unit1.log` passes **19/19** ReleaseSafe client tests;
`general-table-wait-catalog-unit1.log` passes **77/77** catalog tests, including
rejection of hints belonging to another connection, namespace or operation before
transport access. Documentation and declared diagnostic mappings pass in the
corresponding `general-table-wait-docs1.log` and `mappings1.log`.
After the private ReleaseSafe build completes, `general-mutation-latency-wait1`,
`wait-probe1` and `wait-client1` run sequentially, with respectively three console
repetitions, one instrumented console repetition and one public-client repetition.
All finish without errors, unknown outcomes or supervisor restarts. The console
medians are INSERT **811.5 ms**, UPDATE **922.7 ms**, DELETE **191.8 ms** and
three-row INSERT **3,568.2 ms**. These small samples do not establish a latency
improvement over the preceding candidate. The instrumented schedule records
four turns and 23/24 caller metadata batches for INSERT/UPDATE, and 16 turns with
88 caller metadata batches for the three-row INSERT. Staging and worker reads
still dominate; the matched baseline regression remains unresolved. Reports and
exact binary hashes remain in the local Table-schema campaign.

### Point admission and the captured metadata working set

Point writes check the fresh candidate's complete native write cost before
attempting direct publication. When staging is required, admission uses spare
slots for the first immutable records alongside the busy-head reservation and
original receipt. A two-row regression verifies that those bytes remain hidden
behind the old root, complete in at most three turns, and preserve exact terminal
replay. Large admission reserves its publication quota without exposing a row.

The captured-turn cache holds at most **64** validated point reads, independent
of durable cardinality. Native prefetch stays limited to **eight** keys. Catalog
policy pairs, metadata records/chunks and Table staging checks use bounded
batches. The cache regression exercises a working set larger than one native
page, eviction at the fixed capacity, private-write precedence, committed reads,
new-turn reacquisition and poisoned reads. This is a measured-workload cache
budget change; native storage pages, values, write slots and Table size limits
do not change.

`general-table-working-unit3.log` passes **97/97** Station ReleaseSafe tests
(1 second, 15 MiB), and `general-catalog-working-unit3.log` passes **77/77** catalog
tests (465 ms, 22 MiB). The first builds fail syntax checking because a constant
was placed between container fields; the second fail because a test-local name
shadowed a declaration. Neither is counted as executed proof.
`general-mutation-latency-working-build3.log` passes **18/18** private-prefix
ReleaseSafe build steps. `general-table-working-native1.log` passes **9/9**
steps and the signed native lifecycle, console, bridge and CLI schedule in
**107.772 seconds**, with **400** turns and **141** sends. It verifies lost
send/turn receipts, supplied-host receipt loss and an injected disconnect, and
never exceeds four native mutations or a 256-byte value. The component and native
results include both the admission and bounded-read changes. Optional installed
SDK consumers were not selected. Documentation, declared diagnostic mappings
and verification registry checks pass in the corresponding
`general-table-working-docs1.log`, `mappings1.log` and `invariants1.log`.
Latency measurements follow separately after compilation and native tests stop.

### Committed general Table latency and native-cache controls

After all builds and the native proof finish, the baseline and committed
`1504e2db` candidate run sequentially with three repetitions of the seven cases,
no extra rows/history/readers, and no probes. Both source trees are clean.
`general-mutation-latency-baseline3.json` and `working1.json` use eight authority
resident pages. A second sequential pair, `baseline-cache64-1.json` and
`working-cache64-1.json`, uses 64 authority resident pages. The larger cache is
an explicit experiment override; the server default remains eight. All four
schedules complete their 21 samples without errors, unknown outcomes or
supervisor restarts. These three-sample medians do not establish tails.

| Case          | Baseline, 8 pages ms | General, 8 pages ms | Baseline, 64 pages ms | General, 64 pages ms |
| ------------- | -------------------: | ------------------: | --------------------: | -------------------: |
| insert 1      |               78.361 |             554.492 |                59.061 |              344.574 |
| update 1      |               82.478 |             559.577 |                65.181 |              366.765 |
| update same   |               75.129 |             157.041 |                60.408 |              105.876 |
| update absent |               84.336 |             165.191 |                55.948 |              110.001 |
| delete 1      |               70.191 |             181.481 |                58.373 |              113.229 |
| delete absent |               95.081 |             153.869 |                62.287 |              113.296 |
| insert 3      |               83.881 |            3262.655 |                58.743 |             1976.484 |

Separate instrumented single repetitions (`baseline-probe1.json` and
`working-probe1.json`) show the structural cost: the baseline uses one admitted
command and one turn for each case; the current candidate uses one command and
three turns for changed single-row INSERT/UPDATE, and four commands with sixteen
turns for the three-row INSERT. The latter includes command upload and complete
statement staging. Candidate worker point reads/batches are 22/18 for INSERT,
22/24 for UPDATE and 203/49 for the three-row statement. Provider POST counts
are respectively 40/57/321 versus 9/11/9 in the baseline. No-op and DELETE cases
still complete in one turn. These are request counts under the instrumented
controls, not uninstrumented latency samples.

The single-repetition persistent-client control (`working-client1.json`) also
passes without unknown outcomes or supervisor restarts. All reports retain
controls and executable hashes in the local Table-schema campaign. The admission
and bounded-read changes reduce avoidable work, but the generalized representation
still has a substantial latency regression. A larger cache helps without removing
the extra commit cost. This does not pass the remaining performance review or
justify changing deployment budgets without recording the tradeoff.

### Bounded INSERT batches and compact primary-key lookup

`bd064760` builds at most eight INSERT rows within the existing 196-record and
candidate byte ceilings. Only the final reachable root is staged. Partial next-row
construction rolls back privately when the overlay fills. Final batches publish
without an unnecessary cursor/reservation commit. Lost proposals, a duplicate in
a later saved batch, consumed-ID cleanup, allocation failures and large multi-level
indexes remain covered. `general-table-batch-unit2.log` passes **99/99** Station
ReleaseSafe tests (700 ms, 15 MiB); `general-catalog-batch-unit1.log` passes **77/77**
(470 ms, 22 MiB). The first Station run failed an old cleanup fixture that assumed
one interval per row; its replacement crosses two complete batches before failing.
The failed run is retained and is not a passing result.

The clean committed three-repetition `general-mutation-latency-batch1.json` control
records three-row INSERT median **1,816.821 ms**, versus **3,262.655 ms** in the
preceding three-repetition candidate. The separate one-repetition instrumented
`batch-probe1.json` records **four sends and ten turns**, down from sixteen turns;
provider POSTs fall from 321 to 199. Instrumented elapsed times are not compared
with uninstrumented samples. Both runs complete without errors, unknown outcomes
or supervisor restarts.

`c906661f` stores a 128-bit SHA-256 prefix in each primary-key lookup entry.
Every bucket candidate still requires full typed-key comparison; immutable node
and row commitments retain all 256 bits. Collision injection continues to prove
that a matching prefix cannot establish equality. Two keyed rows use a 234-byte
leaf, allowing a changed point write to fit the four-write native boundary.
The third row still exercises staged admission, old-root visibility and replay.
`general-table-key-prefix-unit2.log` passes **99/99** (644 ms, 15 MiB), and catalog
`key-prefix-unit1.log` passes **77/77** (459 ms, 22 MiB). The first Station run fails
only the explicitly asserted old maximum head size, 245 versus 229 bytes; the
updated assertion and contract record the new exact encoding. This incompatible
storage layout participates in the outstanding coordinated definition cutover.

`general-table-key-prefix-native1.log` passes **9/9** build/proof steps and the
signed lifecycle, console, CLI and port recovery schedule in **97.372 seconds**:
**364 turns, 141 sends**, lost send/turn replies, supplied-host receipt loss and
one injected disconnect. Native writes/values stay at four/256 bytes. No installed
SDK consumer is selected in this run. Documentation validation passes.

After builds and native recovery finish, clean `c906661f` and baseline `cc5f57e7`
run sequential **20-repetition** controls with eight authority pages and no extra
rows, pre-aging, concurrent readers or probes. Both 140-sample schedules complete
without errors, unknown outcomes or supervisor restarts. Reports
`general-mutation-latency-key-prefix1.json` and `baseline4.json` retain exact source
revisions, controls and binary hashes in the local Table-schema campaign.

| Case          | Baseline median / p95 ms | General median / p95 ms |
| ------------- | -----------------------: | ----------------------: |
| insert 1      |        112.845 / 126.055 |       197.453 / 237.981 |
| update 1      |        127.008 / 164.999 |       222.542 / 256.279 |
| update same   |        113.702 / 125.521 |       173.805 / 198.112 |
| update absent |        130.650 / 157.161 |       211.218 / 227.303 |
| delete 1      |        115.978 / 128.972 |       188.129 / 207.016 |
| delete absent |        133.193 / 172.776 |       205.886 / 257.363 |
| insert 3      |        122.674 / 131.667 |     1946.881 / 2158.296 |

These empirical p95 values meet the fixture's minimum sample count; no p99 or
latency SLO is claimed. Point-write overhead is substantially reduced, but the
remaining general-schema metadata, upload and staged-publication cost still
requires review. The multi-row regression is not resolved by this checkpoint;
wide/nested, age/readers and final committed-source controls remain separate.

### Fixed mutation caller removal

The separate fixed-table writer, query-package mutation caller/bridge, native
mutation handle/port profile, `transit mutate` route and ten SDK mutation adapters
are removed. General Catalog DDL/DML owns replacement dispatch and exact saved
recovery. Old generated ABI/schema declarations and dedicated tests/tasks are
removed with their implementation. The [historical record](../fixed-table-mutations.md)
retains the earlier contracts and executed SDK observations; those observations
are not counted as new general-Table qualification. The remaining Station
handler Table/query helpers and pure fixed SQL compiler are a separate migration.

`general-query-mutation-removal-unit1.log` passes **89/89** Query tests;
`general-station-bindings-mutation-removal-unit1.log` passes **17/17** binding tests.
The regenerated Station ABI and language resources pass their owner generators.
`general-mutation-removal-boundaries1.log` passes **12/12** steps, **3,083** executed
diagnostic projections across **29** surfaces, **17** compiler-inferred error sets
and **nine** unknown-cause projections. The subsequent explicit removed-command
check raises CLI coverage from 595 to **596** real cases, retaining privacy and
no-provisioning assertions. General Catalog diagnostics replace the removed
writer family; unknown-send recovery remains separately asserted.

`general-mutation-removal-native1.log` passes **11/11** steps, including the CLI
checks and the signed general native/console/port lifecycle in **95.562 seconds**.
It records **364 turns/141 sends**, lost send/turn receipts, supplied-host receipt
loss, one disconnect and unchanged four-write/256-byte maxima. No installed SDK
is selected. Strict Python checking passes 24 source files, TypeScript no-emit
checking passes, and locked Rust checking passes with the explicit source-development
library directory. The first Rust attempt lacks that required artifact setting
and fails before SDK compilation; it is not an installed-language qualification.
Recursive generated-host declaration checks and the recorded diagnostic inventory
also pass. Documentation (`docs5`), semantic mappings (`mappings1`) and the
updated verification registry (`invariants2`) pass. The first registry run fails
on the removed request-bound source and is retained; its replacement classifies
the general intent and existing private batch budgets rather than dropping bounds.
The global definition cutover, installed-language requalification and full clean
CI remain outstanding.

### General typed component compiler migration

The fixed `Sql.Mutation`/`Fuze.TableMutation`/`Station.TableMutation` paths and
`Declaration.tableSchema` conversion are removed. DDL/DML compiler measurements
now use `TableDdl`/`TableDml`. The existing non-executable state-definition
formatter remains separate. Diagnostic reflection removes the old mutation
boundary and six obsolete declaration-conversion causes; general Table compiler
boundaries retain their reviewed mappings and unknown-cause fallback.

`component-general-fuze2.log` passes **250/250** tests; Station's matching
`station1` run passes **97/97**. The first Fuze run fails one obsolete binary-cast
highlighting fixture; the corrected fixture uses the general parser's `X'00ff'`
constructor. The first root build finds the removed parser's classifier branch
and an obsolete neutral scalar conversion in the parameter benchmark; both are
migrated before `build3` passes **7/7** steps, including **16** compiler-inferred
error sets and **nine** unknown-cause checks. `build4` recompiles the final
parameter benchmark. Its first runtime attempt rejects old cast literals; the
second uses typed numeric/binary literals and passes all **12** neutral parameter
cases, preserving ordinary/prepared bundle equality and two description reads.
The default pure SQL benchmark passes its **13** compilation/aggregate cases.
These single-sample smoke runs are correctness checks, not latency comparisons.

The general declarative consumer passes **33** components and **nine** capability
probes with 257 rows/three-row pages and separately with empty input. SQLite
checks complete typed mutation rows and matched/changed counts; PyArrow checks
SELECT cells and schemas. Decimal, wide-schema and compound-predicate probes
now require acceptance. Full TPC inventories remain blocked. Mutation timing is
named `build_candidate` and includes immutable row/index construction, bounded
overlay allocation and decoded result traversal; it cannot be compared with the
historical fixed-cell `propose_mutation` phase as equivalent work. The SQL probe
also marks its general DDL/DML workload contract to reject mismatched controls.
Runner checks pass **9/9**, including unchanged-row and zero-match oracle cases.

Raw reports are retained in the local campaign (one sample, ten component
compile iterations, one query execution; parameter/default probes retain their
own fixed iteration counts):

| Report                               | SHA-256                                                            |
| ------------------------------------ | ------------------------------------------------------------------ |
| `component-general-report1.json`     | `dc6ffbc70fe2067da3bf70ac12ad1e9ed5754820f230c1c2cbcde8b1cc3b0702` |
| `component-general-empty1.json`      | `8790d3e3848f1b511a24e1625f381281a136b74adfff8dd1a034897d5cf55e95` |
| `component-general-sql1.json`        | `ddf50e7ab2cfcb1b2ed3971221743a5cd62560326b1593f6937f478a248c9af4` |
| `component-general-parameters2.json` | `d599ce91049ebdd93fe0e0b1ab7003757b650c684888d4818b0125a6c2f0fbf2` |

Documentation and diagnostic semantic mappings pass. The updated source
inventory records 375 owners, 3,499 owner/error pairs, 445 enum/union surfaces,
13 declared sets, 2,887 error-return boundaries and 194 grammar productions;
this inventory is not executable proof. The verification registry passes with
the superseded three-row compiler bounds removed. Handler Table/query migration,
installed SDKs, current-definition regeneration and complete clean qualification
remain separate gates.

### General Table handler foundation

`TableReader` owns the current general schema and bounded typed rows at one
captured or retained cut. `TableCreation` freezes an application-owned schema
and publication quotas, stages its original immutable schema, and publishes the
initial head and original completion receipt in one native turn. These helpers
provide no catalog name, operation authorization or implicit continuation.
The final SDK/handler dispatch migration remains separate from this foundation.

`general-handler-reader-unit1.log` passes **99/99** Station tests and
`general-handler-creation-unit1.log` passes **101/101**. The complete
`general-handler-reader-creation-unit3.log` passes **103/103**, four build steps,
2 seconds and 27 MiB test-process MaxRSS. Coverage includes typed decimal/nested
rows wider than two columns, stable identity ordering, moved-cut rejection,
private-write invisibility, retained original schema after rename, retired-head
rejection, read denial/poisoning and independently owned row lifetimes.

Small and large initialization schemas are replayed after discarded proposals
at every stage. Changed schemas/quotas reject with no private writes; all accepted
steps retain the four-write maximum. Original receipts survive rename and
retirement without restoring the original head. Independently populated Table
namespaces cannot be adopted. The independent Python storage oracle adds the
84-byte STC1 receipt and namespace key, and Zig verifies those exact bytes,
foreign definitions, truncation, invalid positions and missing data.

The first combined run (`unit2`) passes 101/103: one allocation-failure harness
sees variable allocator resizing, and a truncated fixture violates native Value
padding before reaching the intended record-length check. The corrected test
uses the existing no-resize allocator pattern and canonical truncated Values.
The final run exhausts creation/read allocation failures, checks released
ownership, and verifies that failed final creation leaves no partial proposal.
`general-handler-storage2`, `docs2`, `invariants2` and the recorded diagnostic
inventory pass. The registry classifies the eight-row operation bound separately
from total Table cardinality and query execution-vector size. This is unit and
layout evidence; installed-host/SDK and disk-backed lifecycle qualification
remain outstanding for the new handler dispatch surface.

### Self-describing logical Arrow delivery foundation

`LogicalInspect.infer` reads only the bounded Arrow metadata tables, validates
the embedded logical descriptor, and checks the complete canonical schema before
Arrow traverses physical field trees. `segment` additionally validates every cell
and expected row count. The existing plain-segment, workspace and logical value
budgets remain; neither helper admits external Arrow profiles or supplies source
or computation authority. This prepares general handler result delivery.

`general-handler-arrow-unit2.log` passes **252/252** Fuze tests in six build steps,
3 seconds and 80 MiB test-process MaxRSS. Inference covers all **46** independent
type/value fixtures and recursive states, owned descriptor lifetimes, empty
results, every partial-allocation failure, every truncated segment length and
single-byte corruption at every position of the complete schema prefix. The
first build (`unit1`) fails on a local name shadowing an existing decoder method;
it executes no tests and is not counted as a pass.

`general-handler-arrow-oracle1.log` passes **5/5** steps and **126 PyArrow 23.0.0
cases**: exact scalar/recursive values and all five states, metadata, owned
batches, bounded splitting and failed-prefix completion. The fixture producer
now verifies inferred schemas and sealed segment fingerprints before the
independent PyArrow checks. Documentation, invariant registry and the refreshed
diagnostic inventory pass. Handler dispatch and installed SDK migration remain
separate from these codec checks.

### General typed handler query capture and delivery

Station private queries now retain the general Table head/schema, persist an
FQP1 plan in one or two native cells, and resume with a stable 20-byte row
identity and FQS1 progress. Job/correlation plus two plan cells still consume
at most four native writes. Logical Arrow delivery verifies canonical schema
metadata and every cell through the shared inspector. The transport keeps u16
lengths with a 65535-byte buffer (aligned streams fit at most 65528 bytes),
eight-row pages and the existing 4 MiB Arrow workspace. These are operation
bounds; durable source/result cardinality remains paged.

`handler-query-unit6.log` passes **109/109** Station tests, four build steps,
4 seconds and 28 MiB test-process MaxRSS. It preserves the prior restart,
authenticated-origin, current-policy, cancellation, read-poison, duplicate,
fragment-conflict and credit checks over general typed storage. New cases cover
empty source/successor pages, a filtered tail, independent decimal/list cells,
full-width Table identities, two-cell frozen plans, missing/changed/oversized
plans, and four-write admission at 128 columns. That last empty result exceeds
the per-segment output budget and records a terminal `result_too_large`; schema
admission does not promise every projection fits one output segment. Explicit
workspace exhaustion also records failure and releases the source. An earlier
sealed prefix cannot become a complete result after failure. Host allocator
failure restores the private proposal and does not manufacture a terminal result.

`handler-query-bindings1.log` passes **17/17** shared Zig binding tests. Neutral
query plans now reuse the general logical plan model and manifests preserve
full-width Table IDs as decimal strings. Generated binding resources reflect
this change; language-native handler wrappers and installed SDK qualification
remain part of the subsequent Table API migration.

`handler-query-native5.log` passes **6/6** steps against disk-backed Ursula:
**41 rows, six segments, 22880 bytes**. Worker/provider/node replacement resumes
staging, sealing and partial receipt; four lost-reply sites reconcile identical
requests and receipts. Source access stops before publication, completion occurs
once, local cancellation preserves uncertain proposals, and acknowledgement is
retained. Independent Python checks reconstruct the 152-byte GQJ1 job and
126-byte FQS1 progress, verify logical descriptor metadata and every PyArrow
cell, ordered segment digests, complete source binding and received-byte identity.
Phase times are write 33.461 s, seal 8.934 s, recover 13.652 s, publish 0.517 s,
and delivery 22.927 s. These fault-injection proof times are not matched latency
controls. Authority residency is 64 pages initially, one after the first restart,
and 64 for final capture/delivery; no default deployment bound changes.

The first native build fails on an unused fixture parameter. Native runs 2–4
complete all service phases but fail independent final checks that still use
the old descriptor fixture shape, null-kind convention and progress basis.
They are not counted as passing proofs. The final oracle uses shared independent
logical type/cell encoders and verifies the new manifest head binding and schema
fingerprint. Unit runs 1 and 4 fail on fixture field/enum names; run 2 accidentally
invokes the broader root test target (943 tests pass, two binding builds fail
before their API migration). Focused runs 3 and 5 pass 103 and 107 tests; run 6
adds the output-budget and incomplete-prefix adversaries. Documentation and
classified-bound checks pass. The final shared-definition cutover, all installed
SDKs, full checks, performance controls and committed-HEAD clean CI remain pending.

Raw `handler-query-unit6.log` SHA-256: `56ca7cc707fd6cd2cd3bfe7c0364bbf942e3013619b4f9696f4f787fbee829bc`.

Raw `handler-query-bindings1.log` SHA-256: `09556090d8786e89f76c75df5abd471b756674c6c9c41d44d939986752a1892a`.

Raw `handler-query-native5.log` SHA-256: `e22dea584887532f4e48b8cd359bd899be6367a04501eeb1de583ccbfe5e4227`.

### General typed handler Table boundary and TypeScript API

The private handler bridge replaces the two-column Table actions with schema
creation/discovery, stable row identities, composite primary-key lookup, bounded
pages and exact resumable mutations. Creation and mutation prepare one private
turn; the application owns durable intent capture and continuation scheduling.
Saved work binds the current definition, realm, resource, schema, principal and
operation. Applied counts, rejection witnesses and original admission/completion
positions remain distinct. Current grants, retained cuts and four-write commits
are unchanged. The neutral action budget is 256 KiB, independent of the native
row bound. Generated schemas distinguish 128 columns, eight returned page rows
and 1024 insert rows; schema acceptance does not promise an action fits its byte
budget.

`handler-table-bridge-unit7.log` passes **20/20** native binding tests, four build
steps, 116 ms and 31 MiB test-process MaxRSS. Cases use four columns including
nullable UTF-8, decimal and nested lists, full-width object/operation identities,
exact duplicate/conflicting intents, changed realm/resource, committed and
retained reads, moved cursors, cancellation and read poisoning. Independent
Arrow-cell checks retain nested descriptors/values after input/workspace reuse.
`handler-table-bridge-build3.log` builds the ReleaseSafe shared library in a
private prefix; no live workspace installation is replaced.

`handler-table-ts-final2.log` passes formatting, lint, strict TypeScript checking
and **54/54** tests. Six new boundary tests cover immutable saved typed work,
foreign/missing definitions, malformed/full-width identities, resource routing,
owned row identities, general projection/predicates, action budgets and the
128-column/1024-row schema distinction. The first final check stops on Markdown
formatting before type checking/tests and is not counted as a passing run.
Earlier native attempts fail on identity-array typing and an incorrect expected
conflict error; the final suite includes both corrections and the later Arrow
ownership test. Other language wrappers, installed SDK integration, the shared
definition cutover, performance controls and full clean checks remain pending.

Raw `handler-table-bridge-unit7.log` SHA-256: `d0f9542b2ec0ad65a613a5dda0d54edcd9d8eacfadd10faaee13d7462b58fdab`.

Raw `handler-table-bridge-build3.log` SHA-256: `0097519a84734af8db38f1e62edf2e55af4145c2481d2f0f0e1d4982cc9c061b`.

Raw `handler-table-ts-final2.log` SHA-256: `77ac1efd7750b1d38b77c02f57cf3676cd6f12355bc0f0a95890510c2f8d0c35`.

### Python handler Table values and outcome identity checks

The Python handler API replaces fixed key/value Tables with the shared general
schema/logical value model, owned row identities, bounded pages, typed creation
and immutable saved mutations. Saved work validates before dispatch, binds the
original realm/resource/schema/operation and advances one private turn at a time.
Handler queries reuse the general immutable plan model and manifest head binding.
Current/retained reads preserve scope checks; no API loops or silently schedules
work. Returned mutation outcomes must match the requested operation; status and
cancellation also match the saved digest. TypeScript now enforces those same
outcome checks.

`handler-table-python-check2.log` passes strict mypy over **21 source files**, the
new handler boundary suite with **31 adversarial rejections**, and the existing
catalog ownership/lifetime suite. The handler suite covers exact saved values,
malformed/missing/foreign definitions, default/predicate recovery, nested decimal
and binary cells, 128-column/1024-row bounds, current/retained routing, moved cuts,
expired scopes, outcome counts, foreign returned identities and digest mismatch.
The first check fails on an explicit Python re-export declaration; no tests are
counted for that attempt. `handler-table-ts-routing3.log` passes formatting/lint,
strict source type checking and **55/55 tests**. Routing attempt 1 uses the wrong
formatter working directory; attempt 2 runs 54 passing tests but its new mock
omits the handler async context. Neither is counted as a complete pass. Attempt
3 invokes the real scope context and passes the foreign-outcome checks.

The Python test is registered in source and installed-consumer tasks. These
results are source-level boundary checks, not installed authority proof. Query
examples and the shared multi-turn SDK scenario still require migration before
the installed handler schedule can run. Documentation links pass.

Raw `handler-table-python-check2.log` SHA-256: `3bb73e17272862f0f3b1235f006dbaf9962ad75a03454bfadf9e0e8953f8f38b`.

Raw `handler-table-ts-routing3.log` SHA-256: `9a27c26153e3fe41f1ac78f3c90ff9871bd00eaf3ff1d098cb6ab6f0673dee1c`.

### Ruby handler Table values and scoped read materialization

Ruby handlers now use general catalog schemas and owned logical cells, stable
row identities, bounded pages and immutable saved mutation/reference values.
Query plans reuse `Unified::Plan`; manifests bind the complete Table head and
preserve full-width object IDs. Schema/row/page conversion and status identity
checks remain inside the read guard: catching a malformed result still poisons
the real Ruby turn. Mutation results match the original operation, and saved
status/cancellation match its digest.

`handler-table-ruby-final1.log` passes syntax checks for all three changed source
files, the handler value suite with **28 adversarial rejections**, and the
independent recursive-schema validator suite. Cases cover nested decimal/list
and binary ownership, saved definitions and canonical identities, 128 columns and
1024 rows, action-size rejection, foreign realm/resource, changed read cuts,
read poisoning, retained mutation rejection and mismatched outcomes. The new
suite is registered in source and installed handler tasks.

Earlier attempts do not count as passing full checks: the first catalog-suite
invocation lacks its staged relative schema fixture, the first new test uses an
incorrect Ruby endless-method conditional, and later standalone catalog runs
lack the installed-gem fixture environment. That installed catalog suite remains
pending; these source checks do not substitute for it or for the real-authority
handler scenario. The final handler test and recursive schema test both pass,
and documentation links pass. Query examples and the shared multi-turn installed
scenario remain part of the continuing SDK migration.

Raw `handler-table-ruby-final1.log` SHA-256: `d49edcf78bbffd0b2900554df4ce6f15b4e5f20776e79eb8dcf89ec263c23c7e`.

### Shared handler Table response budget

The native Table bridge now measures the complete `GrowingResult` JSON, including
its envelope, metadata and escaping, before publishing a response. Its 256 KiB
limit matches the existing direct-ABI read capacity and fits the native-host
frame. Oversized reads return `OutputBudgetExceeded` with budget status; they
cannot truncate rows, hide continuation or vary by SDK transport. Smaller pages
can reduce response size; a single row/schema above this transport bound remains
unreadable through this handler profile. Native row/schema storage admission is
separate and unchanged. Result validation restores the private proposal on error.

`handler-table-result-unit1.log` passes **21/21** binding tests, four steps,
138 ms and 31 MiB test-process MaxRSS. The added test independently serializes
an exact-fit response, tests one-byte overflow, JSON escaping, page envelope and
metadata overhead, and the exported budget status. Existing general Table
creation/read/mutation/recovery tests pass through the shared result guard.
`handler-table-result-build1.log` builds the ReleaseSafe shared library in four
steps into the campaign's private prefix (1 minute, 2 GiB compiler MaxRSS).
Contract attempt 1 imports the same Zig file through two module roots and fails;
attempt 2 reads the exported capability instead and regenerates successfully.

After regeneration, `handler-table-result-ts1.log` passes formatting, lint,
strict source type checking and **55/55** tests. The Python/Ruby source suites
pass **31/28** adversarial rejections respectively in
`handler-table-result-sdk1.log`. Diagnostic inventory, classified-bound registry
and documentation links pass. These are bounded-codec/API checks; installed
handler scenarios and final full qualification remain pending.

Raw `handler-table-result-unit1.log` SHA-256: `1614d07cd8f6bd06055e5c966e82666f489921b1030a1cf16e23e4afff0edde4`.

Raw `handler-table-result-build1.log` SHA-256: `0097519a84734af8db38f1e62edf2e55af4145c2481d2f0f0e1d4982cc9c061b`.

Raw `handler-table-result-ts1.log` SHA-256: `a29b4575553a19c361fe4435d35603361582aa52c2f8aebdb5d555724c49fb4f`.

Raw `handler-table-result-sdk1.log` SHA-256: `d876dc783d4f558f953cf56a4cff8a4a677df9e269d17eec78c2f35879a3f3ad`.

### Rust general handler Table values

Rust handlers now discover `catalog::Schema` through an exclusive Table borrow,
return owned logical rows and stable identities, and expose typed creation,
saved mutation/reference recovery and explicit one-turn steps. General handler
queries freeze `unified::Plan` and retain full-width object IDs/head digests.
The fixed `TableValue`/two-column cell API and its private schema decoder are
removed. Private schema/mutation codecs are shared with the catalog models;
no neutral JSON declaration becomes the public application type.

`handler-table-rust-check3.log` passes **14/14** tests (1.07 s), with zero ignored
cases and no compiler warnings. Five new handler/query tests cover immutable
nested decimal/binary/list inputs, original schema ownership, full-width IDs,
strict saved definitions and canonical recovery, default/predicate round trips,
128-column/1024-row/byte bounds, applied-only counts and frozen general query
projections/output names. The existing catalog and logical codec tests pass.
The initial build fails on a missing internal scalar decoder and a conflicting
borrow in the page builder; attempt 2 passes 13 tests and warns about the unused
superseded basis decoder. Attempt 3 removes that decoder and adds the query test.
`cargo fmt` and documentation link checks pass. Tests use the locked source
crate with an explicit native-library directory; they do not qualify installed
handler dispatch or examples, which still require the shared scenario migration.

Raw `handler-table-rust-check3.log` SHA-256: `a314df3c07317d7a1736612fbd7262001ca5d4e63290ab06f8044cab5b2b30b8`.

### Java general handler Table values

Java handlers use the general immutable `Catalog.Schema`, owned logical rows
and stable identities, with explicit creation and saved mutation/reference
steps. Catalog mutation decoding validates logical values and canonical recovery
before native dispatch. Handler query plans freeze `UnifiedQuery.Plan`; manifests
retain full-width Table IDs and the complete head digest. Scoped reads retain
the existing active-thread and failed-read gates.

`handler-table-java-check1.log` passes **34 adversarial rejections** plus positive
ownership, nested decimal/binary/list, saved-schema, default/predicate,
128-column/1024-row, full-width identity, outcome count and frozen query checks.
The source SDK and test compile with Java 21, `-Xlint:all -Werror` and the pinned
Gson dependency. The first compile attempt fails on missing optional annotations
referenced by Gson's static parser; using the SDK's existing Gson parsing pattern
removes those warnings, and build attempt 2 succeeds. Documentation checks pass
5259 local links across 524 files. The test is registered in the installed Java
Station schedule; its execution here is a source boundary check, not evidence
for installed dispatch, native authority or the still-unmigrated examples.

Raw `handler-table-java-check1.log` SHA-256: `91d3ead047504fdb562b14f44bf884736a28ad021bec921ddf5c8473c8b2fb62`.

### .NET general handler Table values

.NET handlers discover immutable catalog schemas, read owned logical rows and
stable identities, and explicitly advance saved creation/mutation work. Query
plans freeze the general unified plan; manifests preserve full-width Table IDs
and head digests. Saved mutations decode logical values before dispatch and bind
the original resource, schema and operation. Table reads compare digest bytes
and retain the active-thread, scope and failed-read guards.

`handler-table-dotnet-check4.log` restores a freshly built Station SDK NuGet
package into an isolated consumer and passes **34 adversarial rejections** plus
the existing logical and recursive-schema checks. It covers ownership, exact
saved identities, defaults/predicates, 128 columns, 1024 rows, byte limits,
applied-only counts, scope/resource checks, captured-basis changes and frozen
general query plans. A 15-map nested value exceeds the old 64-level JSON bound;
the actual handler action encoder accepts it under the shared 96-level bound.
SDK compilation and consumer compilation treat warnings as errors. Final consumer
build: 2.42 s, zero warnings/errors. Documentation checks pass 5261 links across
525 files. The Station package contains the new handler guide.

Check attempt 1 fails on a test syntax error; attempt 2 passes 33 rejection cases.
Build attempt 3 encounters a name collision in the depth fix, so the subsequent
check 3 uses the older package and fails on the missing encoder. Build/check 4
use the corrected package and pass. The log records package hashes. Dependency
packages are prior campaign artifacts; no native handler dispatch occurs in
this value suite. Fresh all-package builds, examples and the installed authority
schedule remain pending; these results do not qualify them.

Raw `handler-table-dotnet-check4.log` SHA-256: `d7c7fd0b57e74d54e31163d0395c5dfcaf2f3443268273cba5ae5f916b1de714`.

### Java handler transport nesting

The Java Station port now uses the shared 96-level JSON nesting bound. A valid
15-map logical value, its schema and complete mutation envelope round-trip in
`handler-table-java-depth2.log`; the previous 64-level parser rejects that same
envelope. All existing handler value checks pass, for **35 rejection cases**.
The first attempt fails to compile because the test omitted the parser's checked
I/O exception; the corrected test compiles with `-Xlint:all -Werror`. This source
test exercises the actual bounded parser, not a running native port or authority.

Raw `handler-table-java-depth2.log` SHA-256: `ae05f6eac9e440e3980aff5fc4980284bb398238a536466279150a704fbc8905`.

### Erlang and Elixir general handler Tables

The shared BEAM implementation discovers general catalog schemas and returns
logical rows, stable identities, full head bases and typed creation/mutation
outcomes. Saved mutation/reference handles bind the original work, validate
logical values and copy binaries on loading. The native handler port uses the
shared 96-level JSON profile. Elixir projects the same records into public
structs and reuses `Catalog.Schema` and `UnifiedQuery.Plan`; neither wrapper
reimplements Table execution or scheduling.

`handler-table-beam-build3.log` builds six OTP archives, including both language
wrappers, with Erlang and Elixir warnings treated as errors.
`handler-table-beam-check1.log` installs those archives into an independent
consumer and passes the existing logical-value/recursive-schema suites,
**27 Erlang rejection cases**, and Elixir schema, logical-row, saved-reference,
typed-outcome and general-plan checks. The handler cases cover full-width IDs,
canonical saved data, 128 columns/1024 rows/action bounds, defaults/predicates,
applied-only counts, 15 nested maps, foreign/expired scopes and caught-read
poisoning. Loaded saved data does not pin unrelated large parent binaries.
Package hashes are recorded in the raw log. The first build rejects a type name
that shadows Erlang's built-in `reference()`; the renamed opaque type builds.

Documentation passes 5264 local links across 526 files; the bound/invariant
registry and diagnostic inventory pass. These are installed value and scope
checks. The archives package existing native executables; the test opens no
native handler or authority. Shared examples, live installed schedules and final
full qualification remain pending.

Raw `handler-table-beam-check1.log` SHA-256: `971af456ae695565e47eb3d33652a591a0c17abfc4d2150c76018e60befbb9d9`.

### C schema and mutation codec reuse

The C SDK's internal catalog codecs now expose the existing owned schema decoder
and bounded schema/mutation writers for reuse by handler Tables. Catalog requests
continue to write their basis and mutation through the same bounded output
writer. `zig build check` in `sdks/c/transit-station`, under `nix develop`,
completes successfully with the package's C++17 `-Wall -Wextra -Werror` flags
(`handler-table-c-codecs-build1.log`, exit 0). This is compilation evidence for
the refactor; C/C++ handler replacement and runtime qualification are pending.

### C and C++ general handler Tables

The C SDK replaces fixed key/value Tables with catalog schemas, logical row
cells, stable identities, composite-key reads, captured head bases and explicit
saved creation/mutation steps. C++ exposes owned schema/row values, move-only
saved mutations and the same shared unified query model. Query object/policy
identities retain full u64 values. Public C symbols are regenerated against the
current definition; the final coordinated definition replacement remains pending.

Under `nix develop`, `zig build check` in `sdks/c/transit-station` passes
C11 public-header/ownership execution and **34 rejection cases**, plus local
scope/thread/retained-write/read-poison checks. The cases exercise saved input
ownership, current/missing/foreign definitions, full-width identities, bounded
rows/assignments/predicates, defaults, complete action envelopes (exact fit and
one-byte overflow), malformed outcomes/counts and 15 nested logical maps. The
shared 96-level JSON profile admits that valid envelope; a 64-level parser
rejects it. A companion C++ conversion error records a failed read under the
existing scope guard; a caught failure still blocks subsequent private work.
Local guard tests omit transport, so passing them establishes no native dispatch
or authority observation.

`zig build check` in `sdks/cpp/transit-station-sdk` passes C++17 ownership
and codec checks, including general schemas, owned inputs, saved recovery,
INSERT/UPDATE/DELETE construction, typed DEFAULT, malformed input and a frozen
copy of the unified plan. Both packages compile with `-Wall -Wextra -Werror`.
The initial C build was invoked from the repository root and correctly fails
because that build has no `check` step. Initial value checks reject a malformed
positive map fixture whose key was a cell rather than an atom; correcting the
fixture produces the passing runs. No failed attempt is counted as evidence.

Generated binding drift, diagnostic mappings/inventory and the verification
registry pass. Documentation passes 5272 local links across 528 files. These
are package source/value checks, not fresh installed SDK/native handler
qualification. Shared examples, live recovery/fault schedules, allocator-fault
coverage, coordinated definition cutover and full clean-CI remain separate work.

Raw `handler-table-c-check6.log` SHA-256: `0072a03edfde54b92d9a068eff9dd7e74d450d7cf1041dd7a4d32f612963a2eb`.

Raw `handler-table-cpp-check4.log` SHA-256: `00c2907e35f59d3380cca04e117e381405bdaad1f541addaac859411a2a30cb8`.

### Durable SDK Table work: independent format and Python model

The shared example contract now specifies a four-column Table, compact FIFO
records and explicit Advance/NotReady/Update/Delete messages. Python implements
that application queue with the original admitted input as the DML operation
identity. Enqueue and final bookkeeping are separate from bounded native steps;
a terminal step that fills the write budget records a continuation, and a later
turn observes the same receipt before advancing the FIFO. Pending accepted
commands survive handler replacement and are not held in host fields.

`tests/sdk_table_work.py` derives wire fixtures independently with `struct`, then
checks the Python encoders/decoders: **12 valid and 52 rejected queue/work/outcome
records**, plus **44 shared application-message cases**. Its scripted-domain
schedule executes **31 private turns**, discards/replays **5** and replaces the
handler between turns. Five original DML identities remain stable; a rejected
command does not strand later work; a busy Rows call returns NotReady; no turn
uses more than **4 writes**. The model also rejects an external Advance origin.
The mock scripts Table steps that consume all writes; it does not implement
Table storage or establish native publication, authority, crash recovery or
performance evidence.

The strict Python type check passes **26 source files**, including the new
example records and all existing client/Station modules. Documentation passes
5277 links across 529 files; the verification catalog passes. The initial type
check catches incorrect use of the SDK's `Found` wrapper and two constructor
inference errors; the corrected run passes. The source model is registered in
`just bindings::python-test`. The other language examples and shared live
schedule still require migration and execution; existing older fixture results
do not qualify this replacement application flow.

Raw `sdk-table-queue-python-model3.log` SHA-256: `18d2a0feb98dc344c90e00905af71871eb3bef937364cbb0924ffa046c4c767f`.

Raw `sdk-table-queue-python-type3.log` SHA-256: `5107f9446510710cfc458474a6bae8746bf7ed9a2bccb85b1de3b0a14e84c8ad`.

### Installed Python Table FIFO and nested query recovery

Fresh ReleaseSafe native libraries/hosts and five current Python wheels pass the
installed public Station and HTTP schedules (`sdk-table-queue-python-native4.log`,
exit 0). The shared live schedule queues commands before advancing them, loses
an accepted queue commit response, reconciles the original signed request,
observes an explicit NotReady reply, and replaces the service host with pending
work. It checks **46 terminal application outcomes**, FIFO completion after a
duplicate-key rejection, insert/update/delete counts, deleted work nodes and
stable original admission identities. These identities are global input
positions; mailbox ordinals are not interchangeable with them. Queue draining
takes **462 turns** within the unchanged four-write callback limit.

General retained reads verify the old nullable value after a later update, then
release the retained version. Six owned logical IPC streams contain **41 rows**,
**41,992 bytes**, text/list defaults and full-width signed values. Independent
PyArrow checks all four columns and nested cell states after runner disposal.
Publication/receipt takes **275 rounds**. Result access after grant revocation
fails. The existing fencing, expiry, callback failure, exact disk/host recovery
and joined disposal checks pass, as does the HTTP SDK schedule (**31.05 s**).
Installed pure-value checks reject **31** adversarial handler intents; the
application codecs pass the shared message and FIFO golden fixtures.

Earlier runs expose two fixture assumptions: using mailbox ordinals for outcome
keys, and limiting the former two-column query to 150 rounds. The replacement
progress cap is derived from six 65,535-byte streams, 221-byte fragments and
three capture writes per turn, with a separate 600-second deadline. A further
run correctly stops on hot-only storage backpressure at 64 MiB. The passing
schedule uses disk-backed cold storage with **8 MiB** provider hot/cache limits,
**64** authority pages and **294** observed cold objects. It does not increase
production memory bounds, disable retention or qualify latency. The other SDK
consumers and final shared-definition cutover remain separate checks.

Raw `sdk-table-queue-python-native4.log` SHA-256: `6deeca59fd5e33f8bb3deeeb3bae5400b6bbdfb313df853ca34df8ad25aeb68d`.

### Installed Ruby Table FIFO and general retained reads

Five fresh Ruby gems pass the same installed FIFO/retained-query schedule as
Python (`sdk-table-queue-ruby-native1.log`, exit 0). The application uses Ruby
value objects for the neutral queue records and general logical schema, with
explicit quotas, stable original inputs, insert/update/delete, self-origin
validation, and an authenticated NotReady reply. Golden application fixtures,
**28** adversarial handler-value checks, **46** terminal outcomes and **462**
drain turns pass. A rejected duplicate does not strand later work across host
replacement. The old retained cut remains readable after a queued update.

Independent PyArrow verifies **41 rows / 6 streams / 41,992 bytes** after runner
closure; capture and delivery take **275** rounds. The current-grant revocation,
exact signed recovery, thread/fiber scope and callback-failure checks pass. The
fixture keeps **8 MiB** provider hot/cache limits and **64** authority pages,
with **306** observed cold objects. The Ruby HTTP SDK schedule also passes
(**14.71 s**). This is installed correctness evidence, not a latency comparison
or qualification of the still-unmigrated language examples.

Raw `sdk-table-queue-ruby-native1.log` SHA-256: `cdee05106802e7f4687e129587c6dbb34a0510c15bafc12cc9916ad036686e7f`.

### Installed TypeScript Table FIFO and retained wire values

Fresh Node tarballs pass the installed Station/HTTP schedules
(`sdk-table-queue-node-native2.log`, exit 0). TypeScript implements the same
neutral queue records, four-column schema/defaults and bounded continuation
flow. The installed codec check exercises all shared message/FIFO fixtures;
**46** terminal outcomes, **462** drain turns, **41 rows / 6 IPC streams /
41,992 bytes**, and **275** publication/receipt rounds match the other migrated
examples. The retained cut survives a later update, and current revocation still
denies completed-result reads. Both independent PyArrow and the optional Node
Arrow adapter consume the original owned nested IPC after runner closure.

The first installed run exposes class instances being sent directly through the
port's plain-JSON boundary. ReadVersion now lowers explicitly for retained Table
schema/get/page, retained KV get/page, and release. Runtime boundary validation
remains strict. All **55** Station package tests pass, with no skips; strict
compilation, formatting and lint pass for the package/examples. The complete
installed schedule passes exact recovery, poisoned reads, host replacement,
fencing/expiry and callback/scope checks with **8 MiB** provider hot/cache limits,
**64** authority pages and **294** cold objects. The HTTP schedule passes
(**36.00 s**). These executions do not qualify latency or the remaining languages.

Raw `sdk-table-queue-node-native2.log` SHA-256: `bdfdcc6a9964c048aaf566a22941b2b522b509bda315515b99e0794b4da7ae9e`.

Raw `sdk-table-queue-node-unit1.log` SHA-256: `6d4d7362fee7286423db548db656b7e66b38e659511ea89f1c6271c63a315d93`.

### Installed Java Table FIFO and owned record codecs

Fresh Java native/client/Station/example JARs build under `--release 21`,
`-Xlint:all -Werror` and pass the installed Station/HTTP schedules
(`sdk-table-queue-java-native2.log`, exit 0). The examples use immutable records,
BigInteger queue identities/counts, general logical values and the shared
Advance/NotReady/Update/Delete formats. Golden FIFO/message fixtures and **35**
handler-value rejection checks pass. The initial external consumer compilation
catches its remaining fixed-Table getter/page calls; the migrated consumer uses
the current public API and passes.

The same **46** terminal outcomes and **462** drain turns qualify FIFO recovery,
rejection followed by later work, exact signed retries, retained old rows,
current-grant denial and host replacement. Independent PyArrow validates the
**41 rows / 6 streams / 41,992 bytes** after native/host handles close; delivery
takes **275** rounds. The fixture observes **301** cold objects while retaining
**8 MiB** provider hot/cache limits and **64** authority pages. The Java HTTP
SDK schedule passes (**27.67 s**). Artifact mismatch, compile-time wrong-value,
scope/thread and callback-failure checks remain enabled. No performance claim
or remaining-language qualification follows from this run.

Raw `sdk-table-queue-java-native2.log` SHA-256: `3bf83303cf2f57d2afa21cda262c01b8d43e1fbe4fb591221b2cf1ed71dd7df1`.

### .NET queued general Table example

The five freshly built NuGet packages pass the complete installed Station and
HTTP schedules against the selected ReleaseSafe native prefix
(`sdk-table-queue-dotnet-native3.log`, exit 0). .NET implements the shared
[application FIFO](../../../examples/station-sdk/TABLES.md) with strict neutral record
codecs, original mutation identities, bounded continuation casts and atomic
terminal bookkeeping. The schedule verifies 46 outcomes across 462 drain turns,
including duplicate-key rejection, insert/update/delete, defaults, pending-host
replacement and the authenticated busy reply followed by explicit retry. Retained
reads preserve the earlier row after update, and all four result columns survive
owned IPC disposal. The common decoder verifies 41 rows in six streams.

The installed consumer also passes 34 adversarial Table wrapper checks and the
shared message/FIFO golden cases. The normal HTTP schedule passes in 18.36 seconds.
The first two attempts failed before the authority schedule: reflection selected
an overloaded schema method ambiguously, then the fixture assumed an inline
schema instead of recursive references. The fixture now selects the public
validation entry signature and validates complete result envelopes, preserving
missing/null/numeric boundary checks. Those failed attempts are not passes.
These are correctness controls using the shared cold-store profile, not latency
measurements or final shared-definition qualification.

Raw `sdk-table-queue-dotnet-native3.log` SHA-256: `7d97dc9f83549baa9ebe32e2f68097bd6991b9636e9af46e64a8d9fb6406c921`.

### Rust queued general Table example

Fresh native/client/Station/example crates pass the full installed Station and
HTTP schedules (`sdk-table-queue-rust-native3.log`, exit 0). The Rust application
uses the shared [durable FIFO](../../../examples/station-sdk/TABLES.md), exact original
mutation identities, strict owned queue codecs and four-column logical values.
The installed consumer verifies the neutral message/FIFO fixtures, 46 terminal
outcomes in 462 drain turns, rejection followed by later queued work, authenticated
busy replies, retained old rows, current-grant denial and exact signed recovery.

Both core and optional Arrow consumers compile from locked offline dependencies;
compile-fail borrow/lifetime/value checks remain enabled. The Arrow adapter verifies
UTF8/list defaults, full-width signed integers and nullable values after the runner
closes and original IPC buffers are overwritten. Independent PyArrow verifies the
same 41 rows / 6 streams / 41,992 bytes after 275 delivery rounds. Storage observes
301 cold objects with the common 8 MiB hot cache and 64 authority pages. The full
HTTP schedule passes in 56.28 seconds.

The first run completes the queue but fails an obsolete Arrow null-kind assertion.
The second attempt is deliberately interrupted during compilation after finding
an incorrect value-kind edit; neither is a pass. The final fixture asserts kind
zero for null and kind one for present INT64, with bounded nested cell wrappers.
This schedule is correctness evidence, not a latency claim or final contract
cutover qualification.

Raw `sdk-table-queue-rust-native3.log` SHA-256: `97df38ae57248bae9bff2122a2bfdfab098abc02150b995d9b30993f8680cb02`.

### Erlang and Elixir queued general Table examples

Fresh OTP packages compile with warnings treated as errors and execute the shared
[durable Table FIFO](../../../examples/station-sdk/TABLES.md) through their public
record/struct APIs. Erlang completes both installed Station and HTTP schedules in
`sdk-table-queue-beam-native2.log`; that combined process then exits 1 in the Elixir
golden fixture before Elixir's authority schedule. After correcting the fixture's
JSON `null` handling, the selected Elixir run completes both schedules in
`sdk-table-queue-elixir-native3.log` (exit 0). No combined-run success is claimed.
The earlier selected Erlang attempt similarly failed nullable fixture decoding.

Each language verifies 46 terminal outcomes / 462 drain turns, original input
identities, host replacement, rejection followed by pending work, explicit busy
replies and query retry. Retained sources preserve pre-update rows; provenance,
read-failure poisoning, current grants and exact recovery gates remain exercised.
Shared message/FIFO golden cases and 27 Erlang handler-value rejection cases pass;
Elixir additionally verifies its public Table structs and saved operation wrappers.
Independent PyArrow decodes all four columns and defaults from 41 rows / 6 streams /
41,992 bytes after 275 publication rounds and host disposal. Each schedule observes
301 cold objects with 8 MiB hot/cache limits and 64 authority pages. HTTP completes
in 23.07 seconds (Erlang) and 25.09 seconds (Elixir). These are local correctness
controls, not latency measurements or final definition-cutover qualification.

Raw `sdk-table-queue-beam-native2.log` SHA-256: `6b8fa667ee85374ba6fe8cad0261fcb258413644a1bccb2de045d9ee4856f7b3`.

Raw `sdk-table-queue-elixir-native3.log` SHA-256: `bdae68aab46636262919a14ee55f534acc4238dfca518e0856bbdf451f682629`.

### C and C++ queued general Table examples

Fresh installed C and C++ archives pass both full Station and HTTP schedules
(`sdk-table-queue-c-native3.log`, exit 0). Both application libraries implement
the shared [durable Table FIFO](../../../examples/station-sdk/TABLES.md), with explicit
owned logical values, original input identities and resumable four-column
creation. Each schedule verifies 46 terminal outcomes / 462 drain turns, rejection
followed by queued work, worker replacement, authenticated busy replies, retained
old rows, current grants and exact signed recovery. Independent PyArrow decodes
41 rows / 6 streams / 41,992 bytes after 275 publication rounds and host disposal.
Each observes 301 cold objects with 8 MiB hot storage and 64 authority pages.
The HTTP schedules pass in 39.23 seconds (C) and 33.76 seconds (C++).

Strict C11/C++17 consumer compilation, wrong-codec and runner-copy rejection,
incompatible-native checks and shared message/FIFO fixtures remain enabled.
The standalone C wrapper check passes its 34 rejection cases; the C++ wrapper
check passes ownership, saved-operation and general-plan checks. The C query
manifest decoder now takes the object identity from the manifest's `table` field:
its captured basis contains resource/revision/head, unlike handler Table reads.
The preceding run passed the mutation queue but failed on that response-shape
mismatch; an earlier consumer build used an obsolete page field. Neither failed
run is a qualification pass. These are correctness controls, not performance or
final shared-definition cutover measurements.

Raw `sdk-table-queue-c-native3.log` SHA-256: `8f6252ec6c363a75b7dcf0a709080b9d1ad576b6e30ed64c663cf2444b86976a`.

### Ten-language queued Table interoperability

`sdk-table-queue-interop2.log` and its JSON report complete successfully (exit 0):
Python → Node → Rust → Ruby → C → C++ → Java → .NET → Erlang → Elixir → Python.
Every pair installs clean artifacts, exercises its counter CLI and durable reply,
then recovers a pending general Table FIFO after owner replacement. Each verifies
authenticated NotReady and explicit query retry, automatic schema creation,
three four-column rows with wide/null/UTF8/list values, and independently decoded
owned IPC. Each Table drains in 15 turns and publishes 6,696 IPC bytes in 47
rounds. This is a finite ring, not an all-pairs compatibility claim.

All ten injected lost turn receipts and unavailable reads reconcile with unchanged
signed attempts; the delivery retry likewise retains its exact request. The run
observes 306 cold objects / 80,373,167 cold file bytes with 8 MiB hot storage and
64 authority pages. Elapsed time is 491.181 seconds including 109.905 seconds of
clean consumer installation, excluding artifact builds. Concurrent local proofs
were running; these timings do not establish a latency or hosted CI budget.
The preceding run was interrupted during installation to rebuild the corrected
C manifest parser and is not a pass. Final shared-definition qualification remains
separate.

Raw `sdk-table-queue-interop2.log` SHA-256: `1ff494654e52d46550623dba3d1e14d16c5b50b2fcc98a97f1e6c88bfca489fd`.

Report `sdk-table-queue-interop2.json` SHA-256: `097a49df926dbe6bd0a54d3861c167df3498d2bd1136fdbdad6adbbe0fe071d7`.

### General Zig Table helpers and native recovery

The superseded fixed two-column Station `Table` helper is removed. Application
Table access uses `TableCreation`, `TableReader` and `TableWrite`; the growing
Station guide and GROWTH-08 registry point to these owners. General reader tests
now exercise 41 rows across six pages, signed extreme keys, exact point lookup,
neighbor/empty objects and every cursor basis field. Cross-resource writes and
exhausted private write budgets leave no accepted prefix. Generic Turn tests
retain private-versus-committed reads, sticky failures, point access independent
of retained cardinality and automatic retained-version dependency wiring. The
standalone Station unit suite passes (`general-station-unit3.log`, exit 0).

`general-station-native5.log` completes all three real caller phases (exit 0).
Forty sequential calls persist their original input, peer and correlation before
resuming typed Table creation/writes. An additional pending Table step survives
caller/node/disk replacement and rejects its old ownership generation. Current
reads verify 41 three-column rows in six pages; a retained source resumes six
bounded steps across another replacement, excludes the later row and releases
its dependency. Read poisoning and exact retry after an accepted reply loss
remain exercised. Writes use 64 authority pages; both recovery phases use one.
The local run records 55.403 seconds for writes, 16.595 seconds for recovery and
109 cold objects with the existing 8 MiB hot storage limit. These are correctness
controls, not interactive SQL latency measurements.

The initial native build failed a pointer argument; the next run rejected the
legitimate bounded empty-namespace check. Another run completed both caller
phases but its harness counted only ordinary turns, missing version-bearing
commits. The final harness recognizes both envelopes, admits only the exact
creation prefix page, and independently checks one then six committed retained
steps. None of the failed attempts is counted as passing evidence.

`general-station-abi1.log` also passes (exit 0), using the explicit qualified native
prefix. Its first staged creation commit loses its reply and is reconciled after
host/disk replacement. Ten atomic four-row mutations preserve full-width values
and UTF8 defaults; scoped and retained general readers verify 41 rows, stale
cursor rejection and a later 42nd row without changing the old cut. Existing
poison/stop, malformed-input, publication and HTTP/RPC checks remain enabled.
The ABI schedule uses cold storage and 64 authority pages; final shared-definition
and committed-source CI qualification remain separate. The broader check first
stopped on the removed helper's diagnostic inventory entry; the inventory is
updated and its closed mappings pass, without treating that partial check as a
full-suite pass.

Raw `general-station-native5.log` SHA-256: `81e183e2158ca83a05f9bc0f6423a882154a9ff42a112a8435f9e8bfabcb4c09`.

Raw `general-station-abi1.log` SHA-256: `1cc746eca2cbcb451836c56f78461e49d078e5e762a9580a475d0c67fbf2fb87`.

### Current declaration ownership and documentation checks

The offline `Declaration` API now owns KV and Document definitions only. Table
CREATE/ALTER/DROP use the shared `TableDdl` compiler and owned general schema;
the obsolete eight-column parser and fixed two-column diagnostic are removed.
`general-declaration-unit3.log`, `general-declaration-errors2.log` and
`general-declaration-oracle1.log` pass: Fuze unit tests, 16 inferred compiler error
sets with nine unknown projections, and 270 independent declaration cases with
238 exact schema identity/type/default/evolution comparisons. The first compile
attempt missed a highlighting parser call site and failed; its corrected rerun
passes. The registry accounts for both existing general schema bounds (128
columns and 65,536 encoded bytes); Markdown links and registry checks pass in
`general-declaration-docs3.log` and `general-declaration-registry3.log`.

The broader check reached documentation tests and exposed missing ALTER/DROP site
entries and a stale Python workload excerpt. Those failures are not a full check
pass; their corrections and site validation are recorded separately.

The documentation site adds ALTER/DROP navigation and refreshes the Python
workload excerpt to the durable general Table queue. Generated references to
nested JSON Schema `$defs` now link to their owning component heading, with a
recursive-reference regression test. `general-docs-check2.log` passes formatting,
lint, TypeScript, all eight content tests and the production site build with
strict anchor checking. The preceding run passed seven content tests but failed
the production build on a generated `#t0` anchor; it is not counted as a pass.

### Authenticated negative handler-query outcomes

`query-failure-native-unit2.log` passes the root Zig test target, including the
native/port codec fixtures. `query-failure-station-unit3.log` passes the Station
unit suite after adding all five negative reasons, malformed wire lengths/codes/
identities, forged or external sources, unknown correlations, conflicting prefix
identity, first-versus-late callbacks, partial evidence retention and private
write-budget rollback. Earlier deterministic capture tests still distinguish
host allocation failure from terminal query budget outcomes. The first root
attempt failed an absent public type export; its corrected rerun passes.

Negative outcomes use dedicated `result_failed` framing and a native-decoded ABI
`query_failure` value. No application codec parses framework error strings.
Generated host contracts, documentation links, diagnostic mappings and verification
registry checks pass. Typed language callbacks, installed-runtime negative-result
proofs and the final shared-definition cutover remain separate qualification work;
these unit results do not establish that those consumers are complete.

### Typed negative query callbacks in installed SDKs

All ten public Station SDKs expose a distinct typed query-failure callback and
owned position/origin/correlation/result/reason values. Application codecs do not
receive framework failures. `bindings::query-failures` runs the shared installed
schedule; the same cases run in each ordinary Station SDK task. The
`typed-query-failures` registry checks five reason codes, closure after owner
replacement, one injected lost commit receipt, one unavailable observation and
exact signed recovery. The raw authorized source isolates consumer framing from
the separately checked native computation/capture failure paths.

The focused Python, Node, Rust, Ruby, Java, .NET, C/C++, Erlang and Elixir runs
listed below all pass (exit 0). Every callback verifies its saved correlation,
records application state with the terminal native wait, and leaves the exact
negative-result payload retained. Each requester is replaced before another
source output; its first reason survives without another callback. Runs use disk
Ursula/cold storage, 8 MiB hot memory and 64 authority pages. These are correctness
checks, not latency measurements or an all-pairs compatibility claim. Native
artifacts were rebuilt at `6cbbf059`; the final shared-definition cutover and
committed-source clean qualification remain separate.

Python strict typing passes (26 files), Rust unit tests pass (14), and the Node
check passes (57 tests), including application-codec bypass, all five reasons,
maximum-width correlation and absent/malformed callback handling. Java/.NET
packages and both BEAM packages compile; C and C++ ownership/value checks pass.
The first C builds exposed missing optional callback initializers and colliding
C enum names; both are corrected. The first Node installed run failed a proof
key constructed from a string instead of owned bytes. The first Ruby installed
run exposed a new local variable shadowing its callback-error slot; the corrected
runner and fresh gem pass. Those failed attempts are not passing evidence.
The first focused Python attempt selected the public CLI instead of the raw
proof CLI; its corrected run passes. A broader Python run then found an import
side effect in the independent file-codec oracle; CLI argument parsing now runs
only from that proof's entry point. Its full rerun remains a separate result.

Raw `query-failure-python-native3.log` SHA-256: `058ba8224e5507bba554950f6802b0c745ae3ddd7122092a698ed57682e5cdf6`.

Raw `query-failure-node-native2.log` SHA-256: `f581f21f86589ae3262cf87493549c03fd244837a67ba115ed6346236008d0be`.

Raw `query-failure-rust-native1.log` SHA-256: `9ff90a0dac92e9bc44e1ce0a26c6bd6e81e62404f817cbff4ca517f9e95a02f0`.

Raw `query-failure-ruby-native2.log` SHA-256: `a49ff62415fcc857a4b2055fb255bbf8690af7c02c01c04d755c9b32c9e4c889`.

Raw `query-failure-java-native1.log` SHA-256: `933ed66927b87e617e52c9c56656e9a1a01f76f560f9067769bb9e01c5e853e8`.

Raw `query-failure-dotnet-native1.log` SHA-256: `91bec6d778b573564dc650b9d53664f68a6be756369da467248f77bb0d786866`.

Raw `query-failure-beam-native1.log` SHA-256: `be505695ecec58927417a8283c5c7e9bc5fc717133fd86807cb5c80bc616f8d9`.

Raw `query-failure-c-native2.log` SHA-256: `c165d0b83cfb33a1db034e8873235df98910bd43e2508e5d789e47fcc120556b`.

### General Table query ABI and checkpoint recovery

`general-query-abi2.log` passes the three-column capture migration, including
six bounded IPC segments, independent logical Arrow decoding, exact retry,
worker/store replacement, stale scopes and revocation. Its first attempt failed
a proof lookup of `creation` instead of the current `created` result; that failed
attempt is not passing evidence.

`general-bindings-native1.log` passes the complete native bindings schedule on a
single CPU: local codecs, growing state/turn ABI, query capture and checkpoint
materialization. The materializer uses three typed columns, a defaulted label,
original mutation identities and a fresh host for each of 25 callbacks. It
checks duplicate admission and 16 exact commit retries per callback, update and
delete/reinsert counts, physical checkpoint trimming, tail updates and node/store
recovery. Updates preserve row identity; reinsertion allocates a different row.
The fixture uses disk Ursula with cold storage (three objects) and 8 MiB hot memory.
The separate query fixture uses 64 authority pages, 83 cold objects and 117 setup
callbacks. These are recovery checks, not throughput measurements.

The broader installed Python Station schedule passes in
`query-failure-python-full2.log`: all five negative query reasons, 46 Table
outcomes, 462 drain turns and 41 rows in six owned Arrow segments (41,992 bytes,
275 publication rounds). Its two injected lost receipts and two unavailable
observations recover exact work. It uses 329 cold objects, 8 MiB hot memory and
64 authority pages. The earlier import-side-effect failure remains a failed run.

Raw `general-query-abi2.log` SHA-256: `3cf1e5194f1660a5b4a6d0bd5b70ac9680a8e5067f4a6452a4bb116cb8150ab3`.

Raw `general-bindings-native1.log` SHA-256: `db510373e9ba44b2a7ff06c9275d7c4d559d0e22e3c8156ea514769787ebe613`.

Raw `query-failure-python-full2.log` SHA-256: `8ac6d6247f674308f8e1f17f8deb1291432f79839f9606c05e7df8f389d3b5c9`.

### Bounded immutable index encoding

`packed-index-unit3.log` passes all 113 Station tests and
`packed-index-root-unit1.log` passes the root Zig test target. Independent Python
fixtures cover two three-row inline leaves, maximum-width identities, a direct
uncompressed leaf, full-size keys/values and a maximum-depth branch. Tests retain
all identities and 32-byte commitments, reject every truncated fixture and
malformed/noncanonical envelopes, and verify unchanged retained roots. Three
small point inserts each fit four writes; a fourth still exercises staged
publication and exact terminal replay. Encoding uses maximal key prefixes and
zero-byte presence masks, with direct bytes when masks do not reduce size.

The first compile failed on a reserved Zig identifier. The next run passed
112/113 tests and exposed a test whose third-row staging assumption was obsolete;
its replacement checks that third-row direct publication and fourth-row staging
both preserve the visibility and four-write boundaries. Those failed attempts
are not passes. The independent storage fixtures and 5,316 documentation links
pass; the combined command's registry invocation used a nonexistent script and
is not a registry pass. Native recovery and matched latency remain separate
checks. The final shared-definition replacement covers this incompatible v1
node encoding; no old-envelope decoder is retained.

Raw `packed-index-root-unit1.log` SHA-256: `f8a9f88dca914da04ad0b24f134ea462bee1ac3aaa7e922f83400f086f362c2f`.

### Lazy pull decoding with bounded Table prefetch

`table-pull-prefetch-station1.log` and `table-pull-prefetch-unit1.log` pass the
Station (114 tests) and query package suites. Catalog SELECT gathers at most
eight immutable row references and prefetches their bounded headers/chunks,
then decodes one owned row per pull. The complete source schema, blob commitment
and row identity still validate on load; current rights still precede output.
A source unit forbids all row-body loads during reference gathering, permits
one subsequent decode, rejects changed identities/digests and current denial,
and checks the final short page. Existing allocation-failure page tests pass.
Native lifecycle and request/latency measurements remain separate checks.

### Current local application and console capacity recovery

The work-item application audit retains its existing selected schedule.
`general-work-items-capacity1.log` passes `just test::server-application-capacity`:
an accepted application input survives actual ENOSPC on an owned ext4 image,
joined shutdown, space release and restart with the same receipt, PID and resource
(19.46 seconds after setup). The separately built example uses the general Table
implementation.

`general-console-capacity1.log` passes `just test::server-capacity` in 12.73 seconds
after setup. The console proof now uses the configured catalog and freezes an
admitted INSERT while its Table owner is stopped. It preserves the exact saved
intent/input outside the filled provider volume, resumes that owner under real
ENOSPC, checks bounded control/shutdown, releases space, and reconciles the same
operation after restart. The applied count is one matched/changed row and a fresh
SELECT verifies exactly one row with the original values. The old proof expected
a saved durable SELECT from an interactive console, which cannot establish that
recovery scenario. This migration preserves accepted-work recovery instead of
inventing a saved query.

Both fixtures fill only their owned 2 GiB ext4 image, leave 4 MiB metadata
headroom and verify that a real 32 MiB allocation returns ENOSPC. They do not
establish zero-free-byte progress or storage throughput. These current passes
close the local application capacity audit; final clean qualification remains.

Raw `general-work-items-capacity1.log` SHA-256: `78a3459e6e8898ae260eea82192ce11ae22b62541cae7294753e93702be69833`.

Raw `general-console-capacity1.log` SHA-256: `3698227870320d085ca12ffaa943cd88005ddbae4a6c3085850d043a1ca40113`.

### Remove superseded BEAM Table value helpers

The BEAM packages remove unused positional Table cell/basis codecs and the
obsolete basis slot on generic KV pages. Current Table pages continue to carry
their typed Table basis. `general-beam-cleanup2.log` builds all eight packages;
`general-beam-cleanup-native2.log` passes the full installed Erlang and Elixir
Station schedules. Both check five typed query failures, 46 Table outcomes,
462 queue drain turns, exact signed recovery and six owned Arrow segments.
Each retains the 8 MiB hot-store and 64-authority-page fixture. The initial build
command used an unsupported output flag, and the first runner call omitted its
required binary arguments; both setup failures are excluded from passing evidence.
These installed artifacts contain the native query-failure build, before the
separate compact-index change.

`packed-index-table-native1.log` independently passes the signed native general
Table lifecycle/console/bridge/CLI schedule with compact indexes and lazy pull
prefetch: 96.592 seconds, 364 turns, 141 sends, at most four mutations and 256
bytes per native value, lost send/turn replies, supplied-host receipt loss and
an injected disconnect. Original objects/receipts survive name reuse. This is
functional recovery evidence, not a matched latency sample. The corrected
verification registry check also passes: 59 invariants, 58 classified bounds
and 14 SDK scenarios.

Raw `general-beam-cleanup-native2.log` SHA-256: `30070f738ec805b94f7be0e33c3460faa947ec0f83c58cfb3981551a23ed4d3a`.

Raw `packed-index-table-native1.log` SHA-256: `22f5568cf3742c66776875495b9cac69cb1ab1fb5a133efb8970b0d486eda011`.

### Avoid duplicate schema envelopes in catalog DML

`compact-dml-catalog-unit2.log` and `compact-dml-fuze-unit2.log` pass the Catalog
and Fuze suites. TCQ1 already verifies its immutable metadata commitment and full
schema fingerprint before decoding, so its DML body now composes the shared
action/predicate payload without repeating the standalone FDM1 schema/name
envelope. Three two-INT64-row INSERTs fit one ordinary Station frame. The
standalone FDM1 representation remains unchanged and shares the same codec.

Tests check exact intent equivalence, independent FDM1 fixture body bytes,
allocation-failure ownership, truncation, stale schema/renamed metadata, foreign
current definitions and rejection of the superseded nested FDM1 envelope.
The first Fuze command used `--build-file` from the wrong working directory and
failed configuration; running the package from its own directory passes.
Documentation links pass in `compact-dml-docs1.log`. Native performance and fault
qualification remain separate; the final shared-definition replacement includes
this TCQ1 body cutover.

### INSERT staging during reservation

`statement-admission-unit3.log` passes all 114 Station tests and
`statement-admission-catalog1.log` passes all 77 Catalog tests. INSERT uses the
admission decision's spare write to stage its first reachable record, without
advancing the saved candidate cursor. The three-row fixture now requires at most
three turns, discards every first proposal, checks old-head visibility and
retains exact terminal counts. Large rows can commit only the reservation when
their first publication needs more than one remaining write. Native writes stay
bounded at four. Cancellation, competing work, allocation failures and late
duplicate rejection remain covered. The first test attempt failed compilation
on a temporary mutable borrow; the second exposed the large-record reservation
case. Neither is passing evidence. Native qualification remains separate.

### Batch original command metadata

`catalog-basis-prefetch2.log` passes all 77 Catalog tests. Command basis resolution
uses three bounded point-read batches for a small schema: current policy,
metadata/head addresses, then original acceptance receipt/schema addresses.
The test refuses every unbatched read, injects failure at each acquisition and
resolves the original schema after DROP/name reuse. Current execution and
inspection revocation checks remain. The first attempt omitted the fixture's
source-view ID and failed compilation; it is not passing evidence.

### General Table shared-definition cutover

The current native/ABI definition is
`b510f56ab152d03b55150b3a300bea04ebad75665371471ef0be3a30d4559032`.
It covers general Table schemas/storage/lifecycle, typed query failures, compact
immutable index bytes and the catalog DML payload. Public contracts, native/port
SDK resources, browser schemas/validators and signing fixtures are regenerated
together. Independent Python SHA-256/Ed25519 recomputation checks canonical
requests; the two inline turn/query vectors first reproduce their previous
digests before calculating the new ones. The previous compact-page definition
is retained only as an explicit rejection input. No legacy decoder or reset is
introduced.

`general-definition-generate1.log` and `general-definition-consumers1.log` complete
the generators. `general-definition-check4.log` passes `just check`, including
root tests, contract drift, diagnostic proofs, CLI/history checks, frontend checks
and the documentation production build. The earlier three attempts catch enum
formatting, its recorded inventory spelling and the two inline signing digests;
none is a complete check pass. This pass precedes the subsequent captured-reader
correction. Committed-HEAD clean CI remains a separate gate.

`general-definition-native-proofs1.log` passes the publication recovery schedule
but fails the Table and Document schedules. Table admission opens published
index data after composing its private reservation; Document page access can
reuse a fully cached small index after native permission revocation. The separate
interactive Table setup fails with the same `PublicationReadAfterMutation`. These
failures are retained and are not qualified native passes. Corrections and reruns
are required before closing the issue.

### Captured INSERT reconstruction after reservation

`statement-captured-admission2.log` passes all 114 Station tests. INSERT candidate
reads use a committed-source borrow while composing the private reservation;
bounded prefetch still uses the same captured cut and poisoned-read handling.
The large-value/multilevel fixture now admits another two-row statement after
40 accepted rows, discards/reconstructs proposals and then verifies 22 predicate
deletions. The first attempt accidentally reused a test operation ID and correctly
rejected changed intent. Native reruns remain separate.

### Cached Document disclosure rechecks native access

`document-current-page-unit3.log` passes 30 Document tests;
`document-current-page-station1.log` passes 114 Station tests. A public Document
read/resynchronization through a cached turn now reacquires the head through its
native reader before using cached values. The new test primes the cache, revokes
access, then rejects both a repeated path read and resynchronization, with a
poisoned turn that cannot commit. Station separately proves an uncached read
cannot return a privately overwritten/cached key after source failure. Mapping,
format and updated diagnostic inventory checks pass in
`document-current-page-check1.log`. The original native revocation schedule is
unchanged and its rerun remains the qualification gate.

### Native correction reruns

`general-definition-native-proofs2.log` passes the signed general Table lifecycle,
console, bridge and CLI schedule in 85.502 seconds: 340 turns, 127 sends, at most
four writes/256 bytes, lost send/turn replies, supplied-host receipt loss and one
injected disconnect. Original objects/receipts survive replacement names; exact
CLI recovery settles input 922. Installed SDK consumers and growth are not
selected. The combined command still exits nonzero because the Document harness
asserts an obsolete exact 256-byte maximum. This is a Table pass, not a combined
proof pass.

The Document harness now checks its measured maximum against the unchanged
256-byte ceiling, already enforced independently for every observed write.
Compact index nodes need not fill a value. `general-definition-document3.log`
passes the complete original Document recovery/revocation schedule: 347 turns,
3065 reads, three killed workers, four exact-retry phases, one authority page
during recovery, an 8 MiB hot store, 65 cold objects/17,077,055 cold bytes, maximum
four mutations and 169-byte values. Stage/accept/checkpoint/finish take
1.008/5.333/10.715/24.072 seconds in this functional fixture; concurrent
compilation means these are not matched latency measurements.

Raw `general-definition-native-proofs2.log` SHA-256: `d16ad85beb819e2d532a04ff2436f5f78893806f1fc8c576643fb8e4b96f02d9`.

Raw `general-definition-document3.log` SHA-256: `3a66227b028c5cfe06572716e9a47ad2993c9792a031217ba3fbdb8c86d560ce`.

### Concurrent mutation control configuration

`general-mutation-latency-current-load1.json` completes its 21 writer samples but
fails the concurrent-reader gate: the reader rejects a superseded top-level
`recovery_file` in its `catalog_v1` configuration before executing any SQL. It
records `cli.invalid_configuration`, zero completed reader queries and a failed
report. It is not concurrent-load performance evidence. The fixture now uses the
same interactive catalog configuration as its independent verifier; readers own
separate console processes and need no durable query recovery files. A corrected
native rerun is required.

### General Table performance qualification checkpoint

The [2026-10-07 campaign](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/mutation_latency/results/2026-10-07/README.md) retains
ten original compressed reports, source/binary identities, controls, distributions
and failed attempts. The matched baseline/general runs each complete 140 cases;
wide and nested runs each complete 21 cases with exact typed readback. The
corrected retained-data pair completes 21 mutations and 88/156 concurrent reads.
All completed controls have zero errors/unknown outcomes and no observed
supervisor restart. The harness reader tests pass 4/4. Separate instrumentation
completes seven cases; its counts are not uninstrumented latency measurements.

Point, multi-row and retained-data costs exceed the earlier profile. Wide/nested
writes have substantial staging costs and no matching historical schema control.
`general-definition-interactive3.log` also fails the unchanged Table request
ceilings after completing its correctness, current-denial, cancellation and
incomplete-prefix checks. A 41-row scan uses 75 requests against nine; LIMIT 3
uses 23 against four; primary-key equality uses 22 against three. Performance
remains an open gate, not a passing check with larger allowances.

`general-definition-check5.log` passes the full `just check` at `1832f58a`, after
the captured INSERT and Document disclosure corrections. The later benchmark
reader fix passes `general-mutation-latency-reader2.log` and its corrected native
run. Committed-source clean CI remains separate.

The current-definition KV and Document interactive reruns both pass unchanged
request ceilings, fresh snapshot cuts, exact literal/parameter results, bounded
frames, zero durable updates, cancellation, current denial and incomplete-prefix
checks. `general-definition-interactive-kv1.log` completes its query schedule in
2.68 seconds; `general-definition-interactive-document1.log` in 112.65 seconds.
They overlap each other and are functional qualifications, not latency controls.
The Document fixture contains 12 rows; the KV fixture contains 41.

Raw `general-definition-interactive-kv1.log` SHA-256: `f265486dcfbdc82688ea11e6cf575b8a7ff52e618a7e811b44e87578cb91638f`.

Raw `general-definition-interactive-document1.log` SHA-256: `b342dd0f8400b80bda7480138a6a25f11d8fdccb2f70fbfd2d8a39f9e4c191fd`.

### Clean binding compiler resolution

`general-definition-ci-clean1.log` stops in the first ordinary task at committed
`c82a01eb`: the recursive TypeScript declaration proof invokes `tsc` from the
workspace root, which has no compiler dependency. A stale root executable in
the working checkout masked this failure. The proof now invokes the already
pinned compiler through `@transit/client`, its declared package owner. No
dependency version or lockfile changes. `general-definition-clean-binding-types1.log`
passes that corrected proof against the isolated checkout's frozen installation,
including recursive shapes and expected type errors. This focused pass does not
complete the interrupted 75-task clean suite; a fresh committed run is required.

### Signed envelope byte-array serialization

`general-definition-ci-clean2.log` passes 17 ordinary tasks at `043188bf`,
including the clean core check, package builds, client ABI, Station and storage.
It then fails the service schedule when a signed runtime intent's fixed byte
arrays happen to be valid UTF-8: an ordinary JSON writer emits strings that the
strict signed-envelope decoder rejects. This is not a completed clean run.

Signed request/query owners now preserve schema-declared arrays through ordinary
JSON writers, including envelopes nested in saved work. The signing CLI and
native responses use the shared schema-aligned writer. Existing typed signing
digests and rejection of malformed array strings remain unchanged. Protocol
tests cover control-byte runtime identities, printable snapshot nonces, signatures
and nested saved-envelope round trips. The reviewed inventory adds only the
serializer error-return boundaries.

`general-definition-byte-arrays-unit1.log` passes the protocol suite.
`general-definition-byte-arrays-service1.log` passes the original full signed
service schedule: independent signing vectors, native waits, bounded ingress,
current denial, worker fencing, disk recovery, checkpoint/trim, retirement and
effect replay without redispatch. A fresh committed clean run remains required.
The [clean development record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m46-clean-development-2026-10-07.json)
retains both incomplete runs' revisions, task outcomes, host metadata and raw-log
hashes; neither is labeled complete.
`general-definition-byte-arrays-check1.log` passes the full `just check`, including
contract/signature drift, strict decoding, CLI checks, frontend checks and the
documentation production build, with the serialization correction applied.

### Retained Table reconstruction during recovery

`general-definition-ci-clean3.log` passes 31 ordinary tasks at `5a6365ab`, then
fails the public query's unchanged 120-second post-fencing completion deadline.
The clean development record retains its incomplete outcome. Forwarding native
wait/control/trace headers through the fault proxy alone does not fix it:
`general-public-query-waits1.log` still fails. The diagnostic run
`general-public-query-trace1.log` records 3,009 retained point requests over 27
source reconstructions before the same deadline. Each bounded Arrow publication
step reconstructs its source page; uncached metadata and index reads repeat even
within one reconstruction.

An opened retained source now reuses at most 64 point entries when its host
enables read caching. The cache is private to that open and exact retained cut;
it never substitutes for current application authorization or native dependency
validation. Station unit checks cover repeated reads, absence, eviction, private
write exclusion, reopen/cut isolation, restored dependencies and poisoned reads.
The diagnostic inventory changes only propagation of the existing dependency
check. No format definition, resident authority limit or proof deadline changes.

`general-retained-cache-unit1.log` passes Station's tests.
`general-public-query-cache1.log` passes the complete original public-query
schedule: transient startup failure, lost send receipt, 41 exact int64/null rows,
fenced source recovery, busy admission, schema rejection, incomplete-result
refusal, cancellation and read-time revocation. The proxy also verifies that
native wait hints were exercised. This is a functional recovery pass, not a
replacement for the matched performance campaign or full clean qualification.
`general-retained-cache-check1.log` passes the full root `just check`, including
the contract/diagnostic inventory, unit and CLI checks, frontend checks and
documentation production build.

Raw public-query pass SHA-256: `1e6570781aee5d91ccaa35be31ddc87d2fa082837f63ac06c75d086b1141f7eb`.

### Accepted general Table performance baseline

On 2026-10-07 the user explicitly accepts the documented general Table costs
for issue #75 and selects separate optimization tracking in
[issue #76](https://github.com/spoke-sh/transit/issues/76). This decision supersedes the
earlier pending-budget checkpoints; it does not relabel their failed runs.
`tests/interactive_query.py` applies the recorded ceilings only to the 41-row,
64-resident-page, unaged Table fixture. Other sizes/source profiles keep their
prior checks. The public performance reference and archived mutation report
describe the accepted costs and their limits; M47 owns subsequent improvement.

`general-interactive-accepted1.log` passes the real Table console schedule on
runtime `436a0797` with the updated budget assertions: metadata 11 requests,
scan/COUNT/scalar ranges 75, LIMIT 3 23, LIMIT 0 13, key equality 22, equality
COUNT 20, and ten additional requests for explicit bindings. Fresh cuts,
exact rows/parameters, bounded frames, zero durable writes, cancellation, current
denial and incomplete-result checks also pass. This functional/request-count
proof overlaps root checks and clean CI; its 25.26-second elapsed time is not an
ordinary latency comparison.
The [accepted interactive record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m46-accepted-interactive-2026-10-07.json)
retains all 26 measured statements, controls, binary/harness hashes and raw-log
digest, separately from the original failed-budget evidence.
`general-accepted-budgets-check1.log` passes the full root `just check`, including
documentation ownership/links, generated interfaces, unit/CLI/frontend checks
and the documentation production build.

### Clean Station SDK formatting gate

`general-definition-ci-clean4.log` at `436a0797` passes 50 ordinary tasks,
including every core/growth task, both real connector examples, Board checks
and the documentation production build. The Node binding task then rejects an
extra blank line in the Station SDK README. This remains an incomplete run in
the clean development record; its successful prefix is not the full suite.
Removing that blank line changes no runtime or interface. The focused
`general-node-check-format1.log` passes client tests, both package format/lint/type
checks and all 57 Station SDK tests, including general Tables, recursive metadata,
exact identities and recovery. Fresh clean consumer qualification remains required.

### Current Board and packaged-console result fixtures

The clean experience lane at `d4c4362f` passes five tasks, then rejects a
superseded fixed-Table `value_type` assertion. The incomplete lane and its exact
results remain in the clean development record. The Board proof now checks the
complete logical row descriptor, current typed parameters and nested exact-value
cells. Its generated-client negative control changes a valid current cell into
an unsafe JavaScript number; a separate control rejects the removed scalar
format. This avoids a false positive caused only by an obsolete envelope.

`general-board-query-shape1.log` passes the real Board query schedule, including
exact compilation, lost preparation/submission replies, native read capacity,
current denial, incomplete-result refusal, cancellation and retired-source
rejection. Its raw SHA-256 is
`5b6c4cf7d62968e993c3696d288b56ea56a27d4626e2606bc214c74815149be5`.
The packaged-console fixture also consumes the current schema/row/completion
stream through the shared helper, which checks basis, plan and row count before
asserting the empty Table COUNT. `general-server-board-package1.log` passes its Nix package proof: defaults,
YAML/environment identity, initialization/restart, the completion-qualified COUNT,
embedded Board/headless/re-enable and downstream manifest work without runtime
PATH tools. `general-board-query-browser1.log` passes the real Canvas/Browse
schedule (one browser test, 54.7 seconds), including exact integers, explicit
unchanged retry, retained resume, current revocation, retirement and accessibility.

The clean experience lane at `72d9a6e3` passes all seven tasks. Its Station
launcher proof recovers current reads after 293 injected refusals and one courier
replacement, finishes the query, then verifies cleanup and persistent restart.
The clean launcher lane at `d4c4362f` separately passes both tasks. The
[consumer checkpoint record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m46-consumer-checkpoints-2026-10-07.json)
retains each revision, task result and raw-log digest. These lanes and focused
passes do not constitute complete ordinary clean qualification.

### Distinct identities for composed catalog fixtures

The clean bindings lane at `d4c4362f` passes contract/native qualification and the
Python client, Station, retained query and HTTP/gRPC schedules, then fails the
installed catalog CREATE. The earlier CLI schedule and first SDK both use object 12001. DROP retains that original object, so the catalog correctly rejects its
reuse. The incomplete lane remains archived; its Python task is not a full pass.

The CLI fixture now uses 22001/22002, separately from bridge 9001/9002 and SDK
12001 + index * 10. Python also includes the returned outcome in a failed CREATE
assertion. `general-python-catalog-identity1.log` passes the full native lifecycle
and both independently installed Python modes in 116.215 seconds: 426 turns,
159 sends, four mutations/256-byte values, lost send/turn/host receipts and a
client disconnect. Both SDK modes retain their original typed mutation result
and historical schema after DROP/name reuse. The consumer checkpoint record
retains this result and log digest. No runtime identity or recovery rule changes.

### Current installed catalog consumer matrix

`general-all-catalog-build1.log` rebuilds every language package from the current
source. `general-all-catalog-identity1.log` then passes the complete native
schedule with all ten languages (eleven consumers including both Python modes)
at `738ac2cc`: Python, TypeScript, Rust, Ruby, C, C++, Java, .NET, Erlang and Elixir.
Each installed consumer performs typed CREATE/INSERT/UPDATE/ALTER/DELETE/DROP,
reopens its saved original intent after replacement and verifies the historical
schema and committed counts. The run takes 425.412 seconds, with 813 turns,
303 sends, at most four mutations/256-byte values, original lost-reply recovery
and one client disconnect. These are functional timings under concurrent checks,
not a matched performance measurement. The consumer record retains every outcome
and the raw-log digest. No language is skipped.

`general-consumer-checkpoint-check1.log` passes the full root `just check` at the
same source revision, including contract/diagnostic drift, units, CLI checks,
frontend checks and the documentation production build. This completes the
current catalog consumer checkpoint; the separate ordinary clean bindings lane
continues and is not yet a complete suite pass.

### Native complete logical-family Table matrix

The final coverage audit identifies a distinction: every family has independent
compiler/codec evidence, while the existing native lifecycle schedule exercises a
smaller subset. The ordinary `just test::typed-tables` profile now also runs
`table_logical_types.py`; explicit `--sdk` selections retain their separate
installed-consumer profile and report this additional matrix as unselected.

`general-native-logical-matrix3.log` passes 28 exact descriptors through SQL,
the supplied catalog owner, disk-backed Ursula and typed SELECT: all signed and
unsigned 8/16/32/64/128-bit widths, float32/64, decimal, boolean, UTF-8, binary,
date, time, civil/UTC timestamp, interval, UUID, struct, list, fixed array, map,
union and JSON. Independent expected values include integer extrema, negative
zero bits, precision-38 decimal, Unicode scalars, binary bytes, pre-epoch dates,
exact temporal units, nested MISSING/NULL, canonical map order and JSON integers
above JavaScript's exact range. Complete descriptors and per-cell evidence agree.

The proof inserts typed defaults and a separate all-NULL row, updates only that
NULL row with typed literals, then restarts both node and store and replaces
owners. Both complete rows and the original UPDATE result remain identical.
The whole lifecycle schedule passes in 110.868 seconds, with 420 turns, 176 sends
and the unchanged four-write/256-byte bounds. These are functional timings under
concurrent SDK qualification. The first two attempts reject fixture names and an
incorrect unwrapped-schema expectation; neither is a complete pass. The consumer
checkpoint record retains their hashes and the successful result. Clean growth
qualification must exercise this new default profile at committed source.

### Clean growth lane with complete native logical types

`general-definition-clean-growth1.log` passes all 26 growth tasks at committed
`e8585d6e` in 2207.28 seconds. It includes Arrow/logical codecs, growing services,
public queries, publication, the combined Table query/writer, catalog and typed
Tables, transports, Flight metadata, HTTP/gRPC recovery and both real connector
examples. Catalog and standalone Table tasks exercise the new 28-descriptor
matrix through node/store recovery. Publication retains exact append/collect/
publish retries after four killed workers and the four-write/256-byte bounds.

The completed lane metadata, every task result and raw-log digest are retained
in the consumer checkpoint record. The clean SDK lane remains active; this is
not a claim that the full ordinary suite has finished. All runtime source is
unchanged since `436a0797`; later commits migrate fixtures, accept the explicitly
selected performance ceilings and record/add qualification evidence.

### Final root check and clean Elixir formatting gate

`general-final-check1.log` passes the full root `just check` at `781b2da5`,
including generated contracts, native units, CLI/frontend checks and the
production documentation build. Its result and log digest are retained in the
consumer checkpoint record.

The clean bindings lane at `738ac2cc` passes its first ten tasks, including
Python, TypeScript, Rust, Ruby, C/C++, Java and .NET. The BEAM task builds its
artifacts and passes logical-value checks, then fails formatting of two Elixir
query-failure adapters. The clean development record retains the exact failed
lane; its BEAM runtime schedule and later tasks did not execute.

The pinned formatter corrects those files. The complete selected Elixir format
command passes, and independently normalized parsed ASTs compare equal before
and after formatting (`general-elixir-format-ast1.log`). This changes no runtime
semantics or definition. The remaining eight standard tasks require fresh clean
execution; the successful prefix is not relabeled a complete bindings lane.

### Final general Table clean task coverage

The final clean task record (archived)
covers all **75 ordinary tasks** with successful executions in clean checkouts:

| Selection                                                          | Source revision | Passing tasks |
| ------------------------------------------------------------------ | --------------- | ------------: |
| Complete core prefix of the interrupted ordinary run               | `436a0797`      |            22 |
| Complete growth lane, including the native 28-descriptor matrix    | `e8585d6e`      |            26 |
| Complete experience lane                                           | `72d9a6e3`      |             7 |
| Complete launcher lane                                             | `d4c4362f`      |             2 |
| Completed bindings prefix, through .NET                            | `738ac2cc`      |            10 |
| Fresh selected bindings suffix, BEAM through connector preparation | `9537839a`      |             8 |

This is task coverage across the stated revisions, **not one complete ordinary
run or five complete lanes at one revision**. The original interrupted runs
remain failed in the clean development record. Runtime semantics are unchanged
since `436a0797`; the later Elixir formatting has independently equal normalized
ASTs. The record checks changed paths, exact task coverage, source revisions,
completion metadata and log digests. It retains the selected-suffix driver and
fresh-checkout supervisor; each selected recipe and its assertions are unchanged.

The final suffix passes in **3248.88 seconds**. BEAM takes **2192.12 seconds**,
including Erlang/Elixir queue, retained-query, transport and catalog recovery.
The public SDK ring passes all ten counter/query pairs in **697.14 seconds**
including clean consumer installation, separately from artifact builds. Each
pair preserves exact replies after restart/loss, automatic schema creation,
queued Table recovery, authenticated busy replies and owned nested IPC.
The model, delivery-model, SQL rewrite and SQL tasks pass, followed by published
RPC crash/retirement and HTTP/gRPC preparation-failure recovery.

The 18 bindings task durations total **11038.99 seconds** across these clean
checkouts. This is an aggregate functional measurement, not one hosted job's
elapsed time or a feedback-budget qualification. The final full root check at
`781b2da5`, Board API/Chromium, packaged installation, all-type native recovery,
accepted interactive budgets and matched performance evidence remain separately
scoped. Same-revision hosted CI and integration are still pending.

## Direct catalog SDK selected roles — 2026-10-24

`nix develop .#bindings --command just bindings::authorization` qualified the
installed Python, Node, Rust, Ruby, C/C++, Java and .NET catalog callers with a
separate login that must explicitly select a non-inherited data role. The first
BEAM attempt failed because its controller still asserted the former principal;
`zig build test-direct-catalog-beam -Doptimize=ReleaseSafe` passed for Erlang and
Elixir after correcting that assertion. All ten language callers exercised the
selected role, its revocation/restoration, wide bulk staging, original uncertain
receipts, lost pin/release replies and caller/node replacement. Raw native
resource access remained denied.

The direct ABI schedule also passed with the restricted selected role (235 public
requests). ABI, Python and Node verified retained SQL after DROP/name reuse and
current denial before cached or terminal result disclosure. The other language
schedules verified retained metadata under current access; those runs do not
establish equivalent retained SQL coverage. These are finite native-local
schedules, not qualification of other storage providers.

## Opaque upstream availability responses — 2026-10-24

The reference Follow run stopped both workers when an intermediary returned a
95-byte, non-JSON HTTP 503 response. The native client previously classified that
response as malformed authority data. It now reports availability for opaque
502/503/504 responses without manufacturing a native rejection or receipt. The
worker retains its original uncertain request; the client performs no retry.

An independent TCP peer exercises eight status/body combinations, including
empty and opaque 503, opaque 502/504, valid native capacity/access rejections and
malformed successful/forbidden responses. It also checks that a previous parsed
rejection cannot survive a later opaque response. The test fails on the original
empty-503 classification and passes after the fix. All 37 client-package tests
pass. Diagnostic inventory, semantic mappings, inferred error boundaries and
3,401 outcome projections pass; documentation checks cover 5,995 local links.
The reference-placement rerun and final repository/clean-checkout gates remain
separate from this focused client evidence.

The subsequent `nix develop --command just check` run also passes with the client
fix, including contracts and independent fixtures, core units, CLI/console
checks, frontend validation and the handbook build. This working-tree result
does not establish the separately running growth/reference schedules or clean
CI against committed HEAD.

## Complete resource growth and installed SDK recovery — 2026-10-25

At `0567c9841b36032f5fc6440539c99ded8ad36e0f`, the fresh committed-source
growth lane passes its first 20 tasks. `just test::catalog` completes in
4,600.69 seconds, including the 139-edge dependency schedule, partial native
resource recovery and the complete 139-resource growth schedule. The latter
initializes 70 KV and 69 Document resources, reads every typed value before
SIGKILL, and reads every value again after node replacement. Its 1,437 typed
catalog calls also verify bounded eight-entry directory pages, saved bindings
and the original first receipt. The native/direct resident limits remain
eight/sixteen pages. Provisioning uses the explicit 5,400-second aggregate cap;
each full readback retains 900 seconds and individual caller requests retain
30 seconds. This pass completes the previously incomplete growth observation;
it does not establish completion within the earlier one-hour setup window.

The preceding direct Table schedule also passes all 1,418 calls, including
64 KiB point values, one actual initial `.tseg`, retained reads and three
restarts, with its original 180-second phase budgets. The growth lane then
fails at `test::sql-gateway` with `StaleStateResource`. The lane is incomplete;
the first 20 task results are individual passes, not a whole-lane pass.

At the same revision, `nix develop .#bindings --command just bindings::sdk-interop`
passes all ten installed counter/query pairs, from Python through Node, Rust,
Ruby, C, C++, Java, .NET, Erlang and Elixir and back to Python. It completes in
989.576 seconds, including 135.863 seconds of independent consumer installation,
and excludes artifact compilation. Ten lost replies reconcile, ten unavailable
reads retry, and one lost delivery-administration receipt uses the original
request. Nested Arrow/schema ownership, queued Table mutations and restarted
workers pass through the repaired Elixir adapter. The authority uses 64 resident
pages and an 8 MiB hot limit; 337 cold objects occupy 88,498,415 bytes. This is
one correctness schedule, not a throughput or hosted CI budget measurement.

## Cached Kubernetes helper CPU portability — 2026-10-25

The core job in hosted run
[40246531716](https://github.com/spoke-sh/transit/actions/runs/40246531716/job/121329237584)
at `7a41dc32b91cf4a4033ad56b500a7bd1bda5a664` fails the offline toolchain
check: `kubectl transit --version` terminates with an illegal instruction.
The helper's Nix derivation compiled for the builder's native CPU even though
its cached output could be restored on a different runner. The runtime packages
already select a baseline CPU; the helper now also passes `-mcpu=baseline`.
Compiler, library and flake lockfile versions are unchanged.

The actual previous and rebuilt Nix helper executables are run through QEMU
10.2.4 from the same locked nixpkgs input, using `qemu-x86_64 -cpu qemu64`.
Both `--version` and `--help` on the previous executable terminate with signal 4;
both commands on the baseline executable exit 0 and print their expected output.
The executable is the package's `bin/.kubectl-transit-wrapped`, avoiding the
shell wrapper so the emulated CPU applies directly to the Zig program. This
reproduces and resolves a CPU portability failure without contacting a cluster.
`nix flake check`, `nix develop --command just doctor`, Nix formatting and
documentation link checks also pass with the baseline helper and pinned
loader/library changes.
It does not establish results for every supported architecture or substitute
for the separate installed lifecycle qualification.

## Native C driver loader selection — 2026-10-26

Hosted bindings run [40246276730](https://github.com/spoke-sh/transit/actions/runs/40246276730)
fails the installed C native-image lifetime fixture with SIGSEGV. Independent
local probes show that `zig cc` selected the host ELF interpreter while native
Zig builds selected the Nix interpreter. A small local dynamic-library probe
executes successfully with either loader; that observation alone does not
reproduce or establish the cause of the hosted crash. The baseline full C SDK
rerun was stopped during compilation after its toolchain was superseded; it is
not a passing SDK result.

The Linux wrapper now selects the pinned glibc ABI/version and matching ELF
interpreter for native C/C++ drivers, preserving explicit caller target/loader
settings. The first expanded offline check exposes missing native ABI detection
inside the Nix sandbox: libc++ selects musl with glibc headers. The next attempt
selects GNU without a version and fails against OpenSSL's newer glibc symbols.
Explicitly matching the pinned glibc version resolves both; no dependency or
compiler pin changes.

`nix flake check` now passes on Linux x86_64, compiling and running OpenSSL
consumers through direct Zig compilation, the build runner and both C drivers.
It checks the exact ELF interpreter and deliberate caller overrides. Other
platforms and the hosted C SDK rerun remain separate qualification gates. The
intermediate full `just check` failed on the unfinished toolchain derivation;
that run does not qualify the final correction.

## Native C/C++ library search paths — 2026-10-25

The C-driver wrapper at `c1d23c14a` selects the pinned GNU libc ABI/version,
which disables the compiler's automatic native library-path discovery.
An independent control built from that revision's `nix/zig.nix` fails to link
an OpenSSL consumer with `-lcrypto` in both C and C++: the compiler reports no
searched library paths. Both control compile-only commands already pass under
`-Werror`; those are coverage checks, not reproduced failures.

The wrapper now forwards the Nix include, library and runtime search paths as
separate arguments without evaluating environment contents as shell code.
Compile-only invocations receive no linker arguments. A loader override keeps
the native GNU ABI and paths; an explicit target retains upstream behavior.
Compiler, library and lockfile versions are unchanged.

Both C/C++ linkage controls compile and run with the corrected wrapper.
The offline toolchain check additionally creates and joins native threads,
verifies exact interpreters and both loader-override spellings, checks
compile-only commands, and executes a static musl target without GNU headers or
an ELF interpreter. `nix flake check`, `just doctor`, Nix formatting and
documentation links pass on Linux x86_64. Other platforms and the complete
committed-source qualification remain separate gates.

An earlier diagnostic with unchanged SDK artifacts from
`4dc0d3ba01497e4cac9929e0817ce4bc221fde92` runs the native-lifetime fixture
with older glibc 2.40 and pinned 2.42 loaders. C and C++ both abort in
`allocate_stack` with the older loader and pass with the pinned loader. This
demonstrates the invalid pairing, without establishing that the local abort
and the previously recorded hosted segmentation fault have the same path.

## SDK query node build profile — 2026-10-26

Clean `bindings-1` at `6957584c4` passes the native binding proof and Python
client schedule, then reaches the common Station query's 600-second deadline.
The [hosted C schedule](https://github.com/spoke-sh/transit/actions/runs/40262338677/job/121377263556)
also reaches that deadline. These runs fail; neither is counted as a complete
SDK qualification.

A local control retains those Debug Python packages, admin and native client,
substituting the ReleaseSafe node from `6139782ba`. The two source revisions
differ only in this proof ledger. The existing common Python Station schedule
passes in 314.27 seconds total, including the query's 275 publication/receipt
rounds, 41 rows, six streams and 41,992 IPC bytes. The query is still receiving
at 147.165 seconds and round 250, then completes before the unchanged 600-second
limit. The 8 MiB hot cache, 64 authority pages, fault/recovery checks and exact
result assertions remain unchanged. Stage timings record progress without
additional authority requests or payload logging.

The [source/artifact record and compressed logs](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sdk-query-profile-2026-10-26/report.json)
retain the failure and passing control. This is a sequential profile comparison,
not a latency benchmark or a fix to Debug-node throughput. It covers the common
Python Station runner, not the later connector/catalog/relational schedules or
other languages. Installed Station SDK tasks now explicitly use a ReleaseSafe
node with Debug bindings, ports and workers. Their complete current-source clean
lanes remain separate acceptance gates.


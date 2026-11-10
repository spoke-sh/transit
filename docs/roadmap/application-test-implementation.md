# Application Table test runner implementation plan

[Milestone 12](12-application-modules-compilation-and-testing.md) · **Status: In Progress** · Approved implementation slice

Let an application author compose a reusable Table module, declare isolated tests
beside it, and run `transit test` without a server, network access or containers.
Compile setup and test statements through the production `.transit` graph and
SQL emitter, then inspect actual typed rows, command outcomes and failures from
the ordinary database owners. A test passes only after every selected assertion
has complete evidence and its owned runtime has shut down cleanly.

Deliver this bounded part of M12 P5 in one implementation PR, with the logical
commits below. It follows the merged [compiler PR #437](https://github.com/spoke-sh/transit/pull/437)
and the [first-slice plan](application-build-implementation.md). It does not
complete P5 or M12. Clock/effect simulation, workflow replay, runtime-private
modules, migration synthesis and the full Platform workload remain explicit
follow-ups.

## Why this slice next

The compiler now produces independently executable SQL for a useful Table
subset. Authors still need an external process harness to check the resulting
behavior. A declarative test runner closes that feedback loop using capabilities
already admitted by the compiler and database. The first-slice plan explicitly
allows this work after the emitter lands, without waiting for definition
replacement policies.

PROFILE/GUARD/PROCEDURE expansion and full Platform compilation depend on a much
broader executable SQL and authority surface. Building a simulator for those
proposed forms would create apparent support ahead of their runtime owners.
Migration synthesis remains valuable but requires its own explicit-basis and
evolution contract. Neither is a prerequisite for testing the delivered Table
module boundary.

## Source basis and existing owners

Reviewed main at `91be427a8`, after merges of #437 and #436. The latter advanced
the shared native definition for log storage and STREAM_SLICE. Locks, cache
manifests and test inputs must bind the current definition; earlier compiler-PR
validation is historical evidence, not a pass at this revision.

| Existing owner | Reuse and remaining work |
| --- | --- |
| [Application source contract](../../contracts/APPLICATION_SOURCE_V1.md), [Syntax](../../packages/zig/transit-compiler/src/Syntax.zig), [Graph](../../packages/zig/transit-compiler/src/Graph.zig) | Modules, interfaces, targets, imports and typed constructor arguments exist. TEST declarations and test targets do not. Extend this grammar and graph rather than introducing a test manifest or script language. |
| [Compiler](../../packages/zig/transit-compiler/src/Compiler.zig), [WorkingCatalog](../../packages/zig/transit-compiler/src/WorkingCatalog.zig) | Fresh public Tables, literal mutations and finite single-Table SELECT already lower through Fuze. Independent reparse/rebind compares ordered fingerprints. Reuse these passes for every executable test statement; keep test controls outside SQL. |
| [BuildSources](../../apps/transit-cli/BuildSources.zig), [Build](../../apps/transit-cli/Build.zig) | Exact transitive locks, verified cached trees, explicit overrides, bounded source loading and provenance exist. Share their resolution and identity calculation between build and test; never call the build CLI recursively. |
| [DatabaseRuntime](../../packages/zig/transit-sql/src/DatabaseRuntime.zig), [SQL service](../../packages/zig/transit-sql-service/README.md) | `initEndpoint` accepts the existing typed local endpoint. Session preparation, admission, current disclosure checks, result completion and original-operation recovery already have owners. This is an integration seam, not an existing test harness. |
| [LocalEndpoint](../../packages/zig/transit-client/src/LocalEndpoint.zig), [NativeServer](../../apps/transit-node/NativeServer.zig), [LocalTableService](../../apps/transit-node/LocalTableService.zig) | Typed local calls retain signed request validation, policy checks and owned responses. Host construction is currently coupled to node composition; expose the minimum reusable lifecycle without starting listeners or bypassing the real local dispatch path. |
| [Application build proof](../../tests/interfaces/cli/application_build.py) | Contains independent hand-written SQL, network denial, source-free execution and failure/recovery controls. Its installed server fixture is a differential oracle, not the proposed container-free runner. |

Use the current [application model](../handbook/reference/applications.md#application-source-builds),
[SQL result contract](../../contracts/SQL_SESSION_V1.md#logical-results-and-fetch-acknowledgement),
[authorization contract](../../contracts/AUTHORIZATION_V1.md),
[query semantics](../handbook/reference/queries.md) and
[verification limits](../handbook/reference/verification.md). The compiler stays
pure and independent of Station, storage, clocks and runtime credentials.

## Review boundary

The first test profile supports exactly the compiler's existing executable Table
subset. Each case starts from an empty private temporary installation, composes
its own modules with explicit Table names, runs setup, executes statements and
checks complete results. Cases run sequentially and cannot share mutable state.
Repeated Table names in different cases are valid; duplicate bindings inside
one case retain the compiler's existing refusal.

Include:

- Explicit test targets and reusable test compositions in `build.transit` and
  imported `*.test.transit` files, including independently selected child builds,
  higher-order constructors and pinned repository modules.
- Complete typed row/schema assertions, authoritative command-count assertions
  and exact expected runtime-refusal assertions. Expected runtime refusals still
  require compilable SQL; syntax/type failures remain compilation failures.
- A real local Catalog, Table storage, SQL runtime and session lifecycle under
  an isolated test identity. Infrastructure proofs exercise denied/revoked access
  through the same owners, including after buffering.
- Frozen offline execution, located diagnostics, bounded reports, deterministic
  case ordering and reliable failure/cleanup behavior.

Defer the public `SET TEST SUBJECT ... WITH GRANTS` DSL, virtual application
clocks, MOCK SINK/OBSERVATION, INVOKE COMMAND, SIMULATE HTTP REQUEST,
`--verify-replay`, property generators and parallel cases. Subject administration
and replay hooks in qualification code must not appear as implemented source
features. Unsupported controls reject before runtime startup. This slice does
not expand the compiler to Streams, Queues, Documents, transactions, procedures,
effects or broader query forms merely because some runtime owners support them.

## Contract decisions before implementation

Extend [APPLICATION_SOURCE_V1](../../contracts/APPLICATION_SOURCE_V1.md),
[TRANSIT_CLI_V1](../../contracts/TRANSIT_CLI_V1.md) and the
[shared grammar](../../contracts/sql/README.md) together. Keep the existing build
syntax and source visibility rules. The following is proposed syntax for the
first contract commit, not a runnable example today:

```text
-- build.transit
IMPORT checks FROM 'rows.test.transit';
CREATE TEST TARGET tests AS BEGIN
  USE checks.Cases();
END;

-- rows.test.transit
IMPORT rows FROM 'rows.transit';
CREATE PUBLIC MODULE Cases() AS BEGIN
  TEST 'inserts are visible'
    USING MODULES (rows.Rows(NAME 'items', TYPE BIGINT, 7))
  AS BEGIN
    ASSERT COMMAND (INSERT INTO items VALUES (9))
      MATCHED 1 CHANGED 1;
    ASSERT ROWS (SELECT id FROM items)
      EQUAL ((7), (9));
  END;
END;
```

The rows constructor here is the existing typed module shape in the source
contract. Final grammar must unambiguously delimit ordinary SQL operands and
preserve inner spans through the shared scanner. Assertions are runner controls,
not new SQL statements or expressions interpreted by a second SQL engine.

### Selection and stage separation

- Retain one source symbol namespace. `transit test` selects `tests` by default,
  so it can coexist with the ordinary build's `default` target in one entry file.
  Explicit target selection must match the command's target kind; wrong-kind
  selection and duplicate source names reject.
- A test target composes test declarations using existing USE/IF/module rules;
  each TEST explicitly selects its setup constructors. Test bodies cannot contain
  nested TEST declarations. Module parameters and source privacy use the existing
  resolver. Give every expanded case a unique stable identity from its target,
  expansion path and case name; duplicate identities are errors.
- Files are parsed and graph-checked under the same bounded source inventory as
  builds. File suffixes organize source; they do not grant execution or cause
  automatic test discovery in downloaded packages. Only cases reached from the
  selected test target run. A build target that reaches TEST is a stage error;
  unrelated valid test declarations do not prevent normal builds.
- Compile and verify all selected cases before creating any runtime. A test
  product owns each case's canonical executable SQL, source maps and separate
  assertion/control records. The runtime receives SQL, never source ASTs.
  An ordinary client can execute that SQL without the control records; those
  records are needed only to evaluate the test's expectations.
- Test compilation uses the same expansion, typed binding, canonical emission
  and independent reparse/rebind as builds. No alternate Table interpreter or
  permissive mode is allowed. Reuse immutable graph state but reset each case's
  proposed catalog. Count total expansion and output across the suite.

### Assertions and truthful completion

Define closed, typed assertion records for row equality, command completion and
expected refusal. Propose `ASSERT STATEMENT (<sql>) FAILS WITH '<owner-code>';`
for the latter, with exact admitted codes/stages fixed in the contract commit.
Bind expected literals against the query's schema using shared
Fuze types/codecs. Validate schema shape, column order and logical types; preserve
NULL and every supported cell-state distinction without string/JSON-number
coercion. Unsupported cell literals fail compilation, not silent conversion.

Implementation audit: the current compiler does not admit ORDER BY. Use bounded
multiset equality over the shared canonical typed value encoding, retaining
duplicate counts, rather than expanding executable SQL. This compares exact
values, not SQL collation equivalence or physical storage order. Every case
consumes its complete result and verifies terminal counts and observation basis.

Command assertions use the shared typed command outcome and its applicable
matched/changed counts, never SQL-text heuristics. Expected-refusal assertions
match a documented owner error code and execution stage, not message substrings.
A transport timeout, pending operation, cancellation, incomplete result or memory
limit cannot satisfy an expected database refusal. A refused write is followed by
an independent state assertion in the qualification corpus.

Row consumers stream bounded batches and own any cells retained across pulls.
Reaching an assertion budget before verified completion fails the case; it is
not exhaustion. Repeat/fetch semantics and current authorization remain with
the service. Missing terminal evidence cannot produce a passing prefix.

### CLI, reports and reproducibility

Propose this initial command surface:

```text
transit test [-f build.transit] [--target tests]
             [--override NAME=DIRECTORY] [--format text|json]
```

No implicit fetch, install, deployment connection or configuration discovery.
Dependency preparation remains the explicit `transit build --fetch` operation;
tests use its current lock and verified cache. Neither `.transitrc`, deployment
credentials nor ambient server URLs affect a case. Unsupported flags, including
`--verify-replay`, fail with a located CLI diagnostic instead of being ignored.

Use the build command's exit convention: 0 only for a completely passed selected
suite, 2 for invalid CLI usage, 1 for compilation, assertion, runtime or cleanup
failure. Zero selected cases is an error. Execute remaining isolated cases after
an ordinary assertion failure; stop on a host failure and explicitly record the
unexecuted suffix. JSON emits one bounded final report, with diagnostics through
[DIAGNOSTICS_V1](../../contracts/DIAGNOSTICS_V1.md). Distinguish passed, failed and
not-run cases, and `complete` coverage from `passed`. Process death produces no
successful terminal report; an earlier run's output cannot establish this run.

Report target/case identities, source and dependency digests, SQL digests,
compiler executable/revision, source/native definition, limits and safe source
locations. Keep expected/actual payloads, signing keys and private installation
files out of reports. Default mismatch facts identify schema/row/column/state,
not arbitrary values. Test labels and diagnostics must also obey report budgets.
Cache compiled content only under complete input identity; never cache a passing
test outcome. Compare deterministic SQL, selection and logical outcomes while
treating elapsed times, temporary paths and runtime-generated identities as
run-specific observations.

Assess source/test format compatibility in the contract commit. Apply the
current-v1 hard cutover to any incompatible persistent shape and reject foreign
definitions; do not introduce a v2 or upgrade old locks implicitly. A test-only
feature does not by itself require changing native persisted semantics.

## Runtime composition, authority and resource lifecycle

Put reusable pure test compilation in `transit-compiler`. Put assertion execution
in a real Zig library, proposed `packages/zig/transit-test`, with its own manifest,
public module, README and checks. It consumes SQL service/result APIs and a
host-supplied local endpoint; it owns no provider or authorization evaluator.
The CLI composes that runner with the production local host and source loader.
Keep current version pins aligned. Do not import repository test fixtures into
the distributed executable or add sibling-source shortcuts.

First extract or expose the node's listener-free local host lifecycle through a
proper module boundary, preserving existing routing, signature verification,
current policy, activation/fencing and resident memory accounting. If the
extraction is a reusable library, give it a package manifest and use it from
both node and CLI. Prove ordinary node behavior unchanged by that extraction.
Use the existing `LocalEndpoint` for every runtime client and reject missing
routes locally; no HTTP fallback is permitted in the test profile.

For each case, own a fresh private temporary directory and real local
TransitLog/TransitObjectStore-backed Catalog/Table state. Prefer this existing
disk-backed profile over introducing a second in-memory storage implementation.
Bootstrap only synthetic case-owned credentials, a database/schema binding and
explicit grants through the normal owners. Keep bootstrap authority separate
from the statement caller. No source export, imported test or generated SQL
acquires privilege by virtue of compilation.

The lifecycle is: validate suite, initialize authority, activate database runtime,
establish caller session, execute setup, execute/assert the body, close result
readers and sessions, stop/join recovery tasks, release the endpoint and storage,
then delete only the case-owned installation. Close/join even on allocation,
assertion or I/O failure; cleanup failure makes the run fail. Recovery preserves
the original frozen SQL/operation identity. It never recompiles source or
resubmits a write under a new token to obtain a convenient result. Unresolved
work is reported as failure, with safe identity evidence where authorized.

Abrupt process-death qualification may retain its owned directory for original
outcome investigation. Do not sweep unrelated temporary installations on startup
or publish credentials/raw recovery files as test artifacts. Test teardown is
destruction of explicitly disposable fixture data, not an application retention
policy or cancellation promise.

Deterministic ordering and explicit inputs establish repeatable Table behavior.
The existing host still needs clock, randomness, storage I/O and recovery work;
this slice does not claim deterministic scheduling or virtual time. Real monotonic
deadlines bound hangs separately from future application test clocks.

Retain the compiler's existing per-file, aggregate source, depth, work, memory,
SQL-output and statement limits. Proposed additional runner defaults for review
are 128 cases, 1,024 actions per case, 10,000 observed rows/16 MiB decoded result
bytes per case, a 1 MiB suite report, 30 seconds per case and 5 minutes per suite.
Execute one case at a time. Use separately accounted compiler/tooling allocations
and a proposed 256 MiB host/runner allocation budget plus 256 MiB temporary
storage quota per case. Audit provider caches, stacks and unmetered OS resources;
an allocator ceiling alone is not an RSS guarantee. Establish exact enforcement
points in the contract/host commits before publishing limits. Budgets are
deployment/test quotas, not fixed total database cardinality arrays. Exhaustion
must fail with bounded cleanup and cannot silently truncate coverage.

## Implementation sequence and logical commits

| Commit | Scope | Gate before moving on |
| --- | --- | --- |
| 1. Specify the Table test profile | Source/test roots, example suite, selection, typed assertion/report records, CLI, quotas and compatibility in the owning contracts and grammar. Add independent expected SQL/results. | Every syntax/control is classified as source, runner-only or executable SQL; deferred controls and zero-case selection reject. |
| 2. Compile test compositions | Extend Syntax/Graph/Compiler with test targets, per-case catalogs and owned test products. Share resolver, provenance and production emission; preserve ordinary build behavior. | Root/child/remote compositions, interfaces, deterministic ordering, private symbols, stage errors, source spans, reparse equivalence, every limit and allocation cleanup. |
| 3. Expose isolated local runtime composition | Factor listener-free initialization/dispatch/teardown from node ownership and compose real storage, authorization, DatabaseRuntime and sessions. | No socket creation or fallback; current grants and fencing; fresh state per case; joined cleanup and node regression checks. This is the main integration risk and must pass before the CLI reports any executable test support. |
| 4. Execute typed assertions | Implement the runner over ordinary preparation, operation settlement and complete result consumption; add bounded safe reports. | Typed full-width values/NULL, zero and multi-batch results, exact command counts, real constraint refusals, denied/revoked disclosure, missing terminal evidence and owned batch lifetimes. |
| 5. Wire `transit test` | Reuse source loading/locks/overrides, target selection and diagnostics; install the real command and documented exit behavior. | Offline root/child/repository tests work with Git/server binaries absent; no ambient configuration reads; missing/stale locks, unsupported flags, failing cases and unexecuted suffixes are visible. |
| 6. Qualify and publish the supported profile | Differential installed-caller journey, failure schedules, resource measurements, task registration and public documentation. | Exact final-source required gates pass; evidence records scope and failures. Update M12 delivered/remaining scope without claiming full P5. |

## Acceptance evidence

| Journey | Executable oracle and negative controls |
| --- | --- |
| Same source language and emitter | Root and child targets compose a typed module twice and a pinned transitive dependency/subdirectory. Explicit override provenance differs correctly. Locked network-denied repeats produce identical SQL and logical outcomes. Missing/foreign locks, corrupt cache, private references, cycles and expansion limits fail before startup. Existing `transit build` output stays equivalent. |
| Ordinary SQL equivalence | Compare test SQL with independently hand-written SQL; run both through ordinary installed SQL clients with source packages absent. Compare schemas, complete typed rows and authoritative command counts. Normalization may map fresh runtime identities only; it cannot erase type, value, count or outcome differences. |
| Isolated Table lifecycle | Multiple cases reuse the same bound Table names with different data and independent state. Exercise INSERT/UPDATE/DELETE, empty results, at least three fetch batches, NULL and full-width integer values. PK/constraint refusal leaves independently observed state unchanged. |
| Truthful assertion outcomes | Deliberately wrong rows, schema, counts and refusal codes fail. A timeout cannot satisfy an expected rejection. Dropped/duplicated/reordered batches, absent terminal completion, exhausted row/byte budgets and scratch reset cannot manufacture a pass. Unsupported test/runtime forms fail with source locations. |
| Current authority | Bootstrap a restricted caller, deny a write, revoke read rights after buffering and inspect empty/final batches. Compare the same denial through the installed service. Test hooks use real policy changes; the runner cannot fake a refusal result or borrow bootstrap rights. |
| Original identity and cleanup | Inject a lost response after a verified commit and recover the original operation without a fresh write. If resolution is unavailable, report incomplete failure. Inject initialization, result-read, allocation, disk/quota and shutdown failures; assert no leaked tasks, cursors/pins or mutable state passed to the next case. A killed test process leaves no successful suite result. |
| Bounded and measured work | Exercise every proposed cap at/over its boundary, many cases with reused runtime names, and repeated runs. Record compiler/runner allocation peaks separately from host RSS and storage bytes. Measure cold/warm startup, compile and execution times on pinned hardware; do not assert M12's full-workload two-second target from this small corpus. |

The lost-reply and process-death cases qualify runner integration and original
Table outcomes. They do not expose `--verify-replay` or prove exhaustive workflow
fault schedules, remote effect idempotency, power-loss durability or distributed
execution. Keep the seven-file Platform corpus a source-attributed rejection
corpus until its runtime capabilities and compilation qualify.

## Validation and documentation gates

Register proposed `application-test` package/CLI checks in the root build,
[Just tasks](../../tasks/test.just), [suite inventory](../../tests/runner/suite.json)
and relevant [fast inventory](../../tests/runner/checks.json); those checks do not
exist yet. Retain `application-compiler` and `application-build` regression
coverage. Run generated grammar/contracts and dependent caller checks. Run the
baseline for every implementation PR:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Run `just check contracts`, the affected compiler/runner/CLI and local-host tests,
`just test server-sql-types` and `just test console-latency-gate` in the pinned
`ci-experience` shell. Run affected `just ci clean --lane NAME` gates on committed
HEAD before pushing: expect `core`, `storage-query`, `interfaces-sql`,
`installation-ui` and `launchers` for this host/CLI composition. Finalize the
matrix from actual dependencies and changes. A definition cutover or SQL type
change expands qualification to affected bindings and the
[SQL interface validation loop](../../tasks/README.md#sql-interface-validation).
Measure latency without concurrent heavy builds.

PR #437 records a failed KV latency gate and a publication exception specific to
that PR. It remains failed evidence; this plan inherits neither a pass nor an
exception. Establish the next implementation's baseline and satisfy its required
gates before opening the PR. Keep earlier failures attributable to their source
and conditions instead of deleting them after a later pass.

Promote the implemented profile to the application and CLI references, the
compiler/runner READMEs and exact contracts. Reconcile stale introductory claims
in README/architecture that still describe all builds as proposed, using the
current owners as the authority. Record executed commands, source revision,
results and limits in qualification history. This planning document and its
documentation checks establish no runtime evidence.

## Following work and review decisions

This proposal chooses one PR for isolated Table tests through the production
compiler and local database path, with explicit test targets, sequential cases
and the narrow typed assertions above. Approving it authorizes the six logical
implementation stages; it does not expand the executable source profile.

Afterward, extend tests as ordinary runtime owners qualify: subject/grant source
controls and clocks, command/Queue behavior, then sink/observation simulations
and yield-point replay with explicit unknown outcomes. Continue PROFILE/FUNCTION/
GUARD analysis, protected procedure/module enforcement and explicit-basis
migrations as their separate M12 slices. Full Platform refactoring and the
remaining ingress/browser/application runtime stay coordinated with
[#430](https://github.com/spoke-sh/transit/issues/430). None of these remaining
criteria is discharged by testing Tables.

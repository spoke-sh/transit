# SQL and database protocols: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

SQL grammar, prepared operations, sessions, database protocols and installed SQL recovery.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Database-owned SQL runtime — 2026-10-28

Source `3b4737ebe` replaces SQL's Station account actors with Catalog-owned
admission/progress, database activation fencing and persistent read-cache slots.
The [runtime guide](../../../packages/zig/transit-sql/docs/runtime.md) and
[direct Table contract](../../../contracts/DIRECT_TABLE_V1.md) own current semantics.
Verification uses Linux x86_64 and pinned Zig `0.17.0-dev.2267+48abf1a34`.

The full Catalog package run passes 99 tests. Its new schedules cover paged
pending/history recovery, exact CAS retries, cancellation, current authorization,
opaque complete bodies, retained byte/operation quotas, pending-capacity release
and stale activation rejection. The mandatory-root-field schedule additionally
rejects missing token, operation, pending and account-usage directories; it does
not initialize missing persisted compatibility state.

The disk-backed storage test `single partition autocommit` passes INSERT, UPDATE,
unchanged UPDATE and DELETE with one Table data WAL append each. It loses replies,
reopens the owner, repeats the exact original operation and verifies unchanged
outcomes and append counts. This is a single-partition data-commit result;
Catalog token acceptance and settlement remain separate control writes.

The native HTTP proxy schedule passes lost token-acceptance and DDL/DML commit
replies, process replacement, database-side stale request rejection, 31 retained
operations over four pages, exact mutation counts, and cancellation before data
admission. Its result-framing schedule preserves 70 rows in 32/32/6 batches,
empty results and metadata under 17 allocation refusals, 15 exact repeats, two
advanced-batch recoveries and three buffered-disclosure revocations. The proxy
observes zero Station sends and zero Station turns for this database workload.
Total fixture traffic includes background recovery and cannot be interpreted as
an isolated statement cost.

All seven SQL owner package checks plus the independent wire-byte oracle pass.
The full query package passes 134 tests after regenerating the independent
definition-bound source and bundle commitments. The complete fixture gate also
passes its signing, handoff, exchange and native/port codec checks (143 codec
cases). Initial runs exposed stale derived fixture hashes; updating the shared
definition bytes alone was insufficient. Independent encoders regenerated the
commitments before the owning checks were rerun.
All 18 generated contract checks pass after the single current-definition cutover;
3,417 diagnostic outcome projections pass. These checks do not by themselves
qualify installed setup, optional captured-source execution or end-to-end latency.
The first native fixture attempt used unsupported wire-profile DROP syntax; the
replacement uses a supported unchanged UPDATE. The first session fault attempt
omitted the native write token in its cache-invalidation setup; the correction
submits once with a token and waits for that exact operation. Failed attempts
remain in the local validation logs.

Runtime source `239485ce4` passes the complete native session schedule: retained
KV and Table results contain 41 rows in 32/9 batches, Document contains 12 rows,
and exact batch retries survive SQL service restart. The schedule also passes
original orphan-pin release, a three-second authority outage with readiness
restoration, source capacity refusals, sticky cancellation, buffered disclosure
revocation, session expiry, TLS/SCRAM, concurrent consoles and Unix peer access.
The direct Table service passes 2,130 typed calls, including lost snapshot
acquisition, warm reuse, replacement cleanup, delegated closure and current
revocation. These file-backed restart schedules do not model power loss.

Installed activation faults pass manager SIGKILL after activation reply loss,
identity retention, higher-generation replacement, occupied-port refusal and
credential revocation without credential recreation. Installed direct-operation
faults pass blocked data execution with available controls, caller death,
restart, exact original settlement and cancellation. The first multi-account
installation run exposed startup-budget exhaustion while a credential was bound
but its database grants were still absent. Source `fe1b34edb` keeps refreshing
enrollment without initializing the denied account; its rerun reaches all three
account enrollments. The complete configured lifecycle subsequently passes at
`d036c9c8f`: three explicit roles, both TLS CLIs, Unicode/NULL data, credential
rotation, disabled listeners, expired trust and exact original-operation recovery.

A separate clean checkout at `ac816e347` builds the native SQL integration but
its framing subprocess exceeds the existing 300-second deadline while other
validation is active. That attempt is failed, not qualified by the earlier native
pass; its log is `/tmp/transit-clean-native.log`.

Reproduction uses `zig build test` in `transit-catalog`, the filtered storage
owner test, `just test::sql-wire-contracts`, `zig build test-sql-gateway
-Doptimize=ReleaseSafe`, `zig build check-contracts` and
`zig build test-diagnostic-outcomes`, all inside the pinned shell. Routine output
is retained under `.cache/sql-cutover/`; the active fault/installation schedules
use the registered SQL checks. The following evidence identifies subsequent
source separately. No interactive transaction, atomic multi-source cut, Stream,
Queue or cross-build history migration is established by this cutover.

### Final recovery and shutdown checks

The separate clean checkout passes all 41 fast checks at `aafcfddc4`, all 18
contract checks with runtime source `453993076`, and the complete native SQL
fault schedule at `17be31692`. The latter completes in 32.177 seconds with 1,488
Table requests, zero Station sends/turns and one exact retry after token
acceptance succeeds but its reply is replaced by a capacity refusal. Both retry
attempts carry the identical frozen binding and return the same acceptance
receipt. An initial version armed that fault on the fixture's manual enqueue
path; that failed attempt did not exercise runtime admission and was corrected
before the clean pass. The earlier 300-second failure remains a failed run;
sequential validation does not establish an isolated-host latency guarantee.

Runtime `453993076` also completes the driver, settings, authorization,
credential/certificate, detached-operation, schema and wide-value phases of the
full wire schedule. The 40 KiB row is submitted once and all ten cells are read
back through both protocols. Its final drain fails the eight-second joined-exit
bound: a read-cache cleanup catch consumes task cancellation. Source `f0e3d3d52`
propagates cancellation from both cleanup-client resolution and pin cleanup,
and stops the recovery worker without reporting cancellation as a domain
failure. The native regression cancels an actual sleeping cleanup resolver,
requires the task to join with its cancellation error, and rejects a successful
return or a recorded cleanup failure. The complete native schedule against the
rebuilt artifacts at `4e83bb2e` passes in 31.022 seconds with 1,505 requests and
zero Station sends/turns; `cleanup_cancelled_and_joined` is true. All 41 fast checks also pass
at `f0e3d3d52`, including diagnostic mappings, generated-source consistency,
documentation links and whitespace.

Installed direct-Table attempts exposed old fixture assumptions: handwritten
signed requests omitted the new lease field, and diagnostic/data-operation IDs
were compared directly with Catalog acceptance IDs. The corrected checks inspect
the accepted immutable binding and preserve both identities. Additional attempts
encounter native-bootstrap authority timeouts; unchanged `fbbaeae12` reproduces
the same failures and exhausts its existing restart budget before SQL setup.
The default direct-Table, SQL-lifetime and bundled-authentication schedules
fail during native bootstrap at runtime source `f0e3d3d52`. A subsequent
direct-Table run with fixture `4e83bb2e` passes schema changes, conditional DDL,
namespace restrictions and the original diagnostic identity while the Query
worker is stopped, then fails native grant re-enrollment after restart. It is
incomplete, not a full installation pass. The core lifecycle also reaches its
SQL checks but its earlier attempt uses the wrong account-profile path; the
fixture now selects the public console account.

The initial baseline/candidate controls ran on the shared host while another
disk qualification was active. After it ends, initial bootstrap succeeds but
a restart still fails. These observations do not prove the cause of every
timeout. No deadline was increased and no uncertain mutation was resubmitted.

The final complete wire run against rebuilt runtime `f0e3d3d52` and fixture
checkout `4e83bb2e` passes in 246.900 seconds, followed by the separate fresh CLI
fixture in 24.101 seconds. It passes both pinned native database drivers,
settings/reload, selected roles, detached writes, credential and certificate
rotation, the 40 KiB row, schema invalidation, capacity reserves and joined drain
within the unchanged eight-second bound. The native-session follow-up at
`70007e3e` also passes TLS/SCRAM, wide logical values, original-token recovery,
concurrent consoles and buffered disclosure revocation. Its concurrent-read
fixture recognizes both current session-admission and typed query-transport
capacity diagnostics; any emitted prefix or exhausted deadline still fails.
An earlier diagnostic assertion failed, and an interrupted fixture attempt is
not counted as a pass.

### Matched client-completion measurements

The [retained comparison](../../../tests/evidence/sql-database-runtime-2026-10-28/README.md)
contains the identical driver's raw reports, executable hashes, exact source and
contract definitions, toolchain, commands and timing provenance. Control
`fbbaeae12` and candidate checkout `70007e3e` (runtime `f0e3d3d52`) each complete
400 measured reads and 36 mutations with independent expected rows, exact changed
counts and cross-protocol readback. Owned runs are sequential after builds and
correctness checks finish; ordinary background applications remain active.

Across the four literal/prepared PostgreSQL/MySQL paths, mutation p50 ranges
from 2,515.567–3,901.078 ms in the control to 1,019.320–1,679.165 ms in the
candidate. All 12 mutation cases improve in this observation. Nineteen of 20
read-case p50 values improve; **MySQL literal point lookup increases from
532.494 to 655.049 ms (23.0%)**, with p95 increasing from 586.846 to 672.877 ms.
The table retains that regression alongside the improved cases. Read p95 uses
20 observations; three mutation observations do not establish a tail bound.

These are client-completion observations over one four-row local-disk/TLS
profile, not isolated allocator, CPU-cycle, I/O or operator measurements. They
do not qualify cold-cache, maintenance-active, Flight or throughput profiles,
or establish a causal attribution to one mechanism. The architecture dependency
is removed, while the broader control-path latency/installed qualification
obligations remain open. The SQL request still validates, stages, accepts and
observes work around its single Table data commit; it is not one HTTP request.

## Admitted result memory and transport reuse — 2026-10-28

The completion branch builds on PR #198's reusable result, client and producer
owners. Source `b0cfcdbe` includes process-wide OpenSSL storage, prestarted
gateway workers, distinct-worker crypto cleanup, extended lifetime/failure
schedules and the installed bootstrap correction. The rebase onto `69f1c67d3`
changes documentation and diagnostic validation inputs; it preserves the runtime
and probe inputs used by the allocation, codec, wire and native-session runs.
The bootstrap correction is qualified separately below. The pinned environment
is Linux x86_64 with Zig `0.17.0-dev.2267+48abf1a34`.

The executed scopes are:

- The client allocation gate passes in a clean checkout of pre-rebase
  `293448483`: Unix and numeric IPv4 HTTP/HTTPS each execute 305 queries and
  1,453 requests with four connection turnovers. A 16,384-row stream runs while
  an independent 33-row wide window remains retained; an Arrow slice survives
  100 other response-slot uses. Prepared calls, exact retry, response exhaustion,
  cancellation and original-token settlement remain in the schedule. Every
  profile reports zero backing allocation/growing-resize/remap attempts, zero
  observed libc allocation calls and zero observed memory-acquisition events.
  The deliberate bypass control records libc calls and three OS events. This
  peer proves client semantics, not durable service acceptance.
- The real-authority producer schedule passes 17 response allocation refusals,
  15 byte-identical repeats, two recoveries after advancing to a new batch and
  three revocations of buffered results. Independent values verify 70 rows in
  32/32/6 batches, empty results and metadata. Existing lost-receipt, fenced
  replacement and original-operation recovery assertions remain intact.
- The required TLS gate passes 100 fresh connections for each PostgreSQL/MySQL
  upgrade path, alternating TLS 1.2 and 1.3. Crypto peaks at 2,128,128 bytes in
  its admitted 16 MiB reserve with zero backing growth. Worker-thread exchanges
  and all 12 existing trust, framing and deadline cases pass. The separate
  `transit-io` tests verify cleanup on four distinct workers before reserve
  release; TLS allocator units cover failed reallocation, concurrent borrowers,
  erasure and foreign initialization refusal.
- The full independent wire-client schedule passes settings/reload, revocation,
  retained write identity, certificate rotation, wide values, capacity,
  cancellation and drain. Its first capacity run failed because client close
  preceded server cleanup; the fixture now observes peer closure before beginning
  the next capacity schedule. The eight normal and four authentication limits,
  ninth-connection refusal and control-progress assertions are unchanged.
- Native sessions pass KV, Document and Table result recovery after service
  restart, byte-identical retries, pin/page refusal recovery, current denial of
  buffered data/empty/metadata disclosures and console completion. All 38
  standalone package checks, 18 generated-contract checks and the handbook
  check/build also pass. The six-task clean formal lane passes at pre-rebase
  `c04cb2377b83`; the result-model inputs are unchanged. These models do not
  establish buffer lifetimes or allocation behavior.

The [paired codec comparison](performance.md#result-reserves-and-codec-costs--2026-10-28)
passes the predeclared 5% median limit in all eight cases and preserves its raw
report, binary hashes and exact source reconstruction. It excludes service,
transport and source/storage costs. The
[coverage inventory](../../../tests/performance/allocations.json) identifies
component-only and pending owners: hostname resolution, AccountRuntime work,
source/authority/storage allocation and composed service OS attribution are not
qualified by these passes. Reserved stacks and retained capacity are charged
capacity, not measured RSS. No whole-service zero-allocation claim follows.

After the rebase and bootstrap correction, committed source `0755c493` passes
all 41 fast checks and all 18 generated-contract checks in separate clean
checkouts without inherited build outputs. Their evidence directories are
`.cache/ci/clean/0755c493d95d-transit-ci-x_9adm9l` and
`.cache/ci/clean/0755c493d95d-transit-ci-e45ziy32`.

Two broader runs remain failed or incomplete. The clean interfaces lane passes
the expanded client allocation gate, then times out after 300 seconds while
seeding the existing native gateway history, before the added producer cases.
That failure does not establish a cause or qualify the rest of the lane. The
installed SQL run first exposes `LocalTableMaintenanceRequiresOwner`: initial
native-only bootstrap disabled flushing but left archive/compaction enabled.
The launcher now defers all three policies until its existing Table-owner
restart. A frozen installed executable reaches native health with that config,
and enabling a physical policy without its owner still rejects. The full rerun
then fails with `AuthorityTimeout` during association recovery before the SQL
gateway starts. Its new assertion that all configured policies return after
Table activation is not reached. No deadline, workload or owner check is relaxed.

Local investigation logs are `/var/tmp/transit-completion-clean-interfaces.log`,
`/var/tmp/transit-advanced-framing-proof.log`,
`/var/tmp/transit-completion-required-tls.log`,
`/var/tmp/transit-completion-wire-gateway-fixed.log`,
`/var/tmp/transit-completion-native-sessions.log`,
`/var/tmp/transit-completion-clean-formal.log` and
`/var/tmp/transit-completion-installed-sql-fixed.log`. These are local records,
not portable artifacts or a claim that all clean lanes pass at one revision.

## Transport-independent statement results — 2026-10-27

The [result contract](../../../contracts/SQL_RESULTS_V1.md),
[semantic library](../../../packages/zig/transit-sql-results/README.md) and
[shared client](../../../packages/zig/transit-sql-client/README.md) separate a
command's owner-attributed outcome from a finite typed relation. PR #190 delivers
the model, bounded service batches, shared reader/settlement, console migration
and native binary carriage. The follow-up based on merge `e03cb007b` makes the
PostgreSQL/MySQL adapters consume the same `CommandCompletion`. Matched and
changed counts remain distinct; a database success frame requires a validated
applied/unchanged outcome. This follow-up does not replace the shared definition
`c28797e8d36912bfca884567bf72256f7304e0e64ed278b90894d7e22b311914`.

The pinned Linux x86_64 environment uses Zig
`0.17.0-dev.2267+48abf1a34` and ReleaseSafe installed executables. These are the
executed focused checks; broader integration and performance evidence are
recorded separately rather than inferred from package passes:

- `just test::sql-wire-contracts` passes the six semantic/protocol/client/service/
  adapter package suites and independent PostgreSQL/MySQL scalar fixtures after
  adapter commit `7b55d1c96`. Model tests enumerate all partitions of zero through
  eight occurrences, both terminal shapes and row/column layouts. The public
  consumer runs against scripted and native adapters without a fetch/status loop.
  Negative controls reject fabricated completion, duplicate delivery and altered
  identities/counts. Exhaustive allocator failures release ownership; the native
  reader consumes 16,384 rows with a 128 KiB accounted allocator. This finite
  correspondence is not a temporal proof of arbitrary network histories.
- `just test::sql-sessions` passes at `da4766c69`, including independent TLS/SCRAM,
  exact wide values, original-token recovery after service replacement, current
  denial on buffered data/metadata/empty-terminal repeats and retained pin recovery.
  Captured KV and Table results return 41 rows as 32 + 9; Document returns 12 in
  one batch. Every captured batch is repeated for exact equality. Observation
  remains an independent-source vector rather than an atomic snapshot.
- `just test::server-single-executable` passes the copied executable's default
  startup/Board, bare-console DDL/DML/lazy ALTER, exact values across restart,
  identical defaults/YAML/environment identities, child/manager death and
  UI disable/re-enable. The role-death schedule now waits for SQL readiness before
  killing a role. `just test::server-sql-lifetimes` passes after `5b9e2a1e9`
  initializes the independent binary decoder: PostgreSQL/MySQL idle sessions
  survive 32 seconds, a one-second native lease expires, and partial frames have
  finite lifetimes.
- At `8a866f513`, `just test::server-faults` passes the core lifecycle in 313.08 s
  and bootstrap/gateway/rollback schedules in 90.53 s. Reload rejection uses the
  shared rejected completion and authoritative pending-restart state. Lost SQL
  admission/status/fetch replies preserve one submission and original-token
  observation; a held response does not prevent another console progressing.
  `just test::server-sql-faults` also passes: accepted allocation and initialization
  requests recover their exact identities after manager SIGKILL, occupied ports
  reject before enrollment changes, and a revoked worker remains revoked.

The logs are `/var/tmp/transit-m4-completion-wire-owners.log`,
`/var/tmp/transit-m4-completion-native.log`,
`/var/tmp/transit-m4-completion-installed-rerun.log`,
`/var/tmp/transit-m4-completion-lifetimes-rerun.log`,
`/var/tmp/transit-m4-completion-server-faults.log` and
`/var/tmp/transit-m4-completion-sql-setup-faults.log`. These local paths are retained
investigation records, not portable artifacts or evidence for later source.

The first combined hosted run,
[40604349889](https://github.com/spoke-sh/transit/actions/runs/40604349889) at
`da4766c69`, passes core, formal, launchers and bindings-2 but fails four lanes.
Python typing needs an explicit narrowing after scalar-kind validation; the
installed DROP fixture still expects an English stderr rejection instead of the
typed result; the owned JSON allocation fixture expects `WriteFailed` instead
of `OutOfMemory`; and a repeated failed relational fetch loses its ordinal.
The first three corrections preserve the existing runtime behavior. The fourth
changes the reader: retain the requested ordinal before pulling, so a repeated
failure rechecks current rights and returns the original failure. Earlier/skipped
ordinals remain invalid; revocation takes precedence over the saved error.
The subsequent combined qualification uses `9867579d1`, including all four fixes.
These source identifiers describe the original pushed history before its
documentation-only rebase.

### Combined qualification

[Run 40608960557](https://github.com/spoke-sh/transit/actions/runs/40608960557)
passes all **108 ordinary tasks and seven Chromium tasks** at committed source
`9867579d15994927ee4dc114fd0a7df0242d21de`. Each lane starts from a hosted checkout
with dependency caches. Core, growth, interfaces, experience, launchers, formal
and both SDK lanes pass. This includes the complete native SQL/session and
PostgreSQL/MySQL schedules, relational repeat-failure/revocation regression,
installed direct Tables and faults, SQL listeners/lifetimes, generated language
resources, mixed SDK interoperability and embedded Board/reactive browser checks.
The separate documentation-site job is unselected; the handbook check/build
passes within experience. A cancelled intermediate run is not qualification.

Production sources are unchanged between that CI revision and measured `8a866f513`;
the latter adds the optional installed fault-fixture corrections executed above.
The rebase onto `9ab9baee3` adds documentation and agent guidance only. After that
rebase, locked `just transit-board::install` and `just check all` also pass locally,
including generated contracts, native tests, 193 CLI diagnostic cases, Board and
the handbook build. The log is
`/var/tmp/transit-m4-completion-repository-check.log`. Committed-HEAD
`just ci clean --check fast` passes all 40 groups at `b6a46b4b5`, with artifacts in
`.cache/ci/clean/b6a46b4b57ab-transit-ci-bahdehuf`.

The [matched performance qualification](performance.md#statement-result-batching-and-consumption--2026-10-27)
records response amplification, first-output/terminal latency, memory and codec
costs with independent values. These checks close the existing local result
profile; they do not implement transactions, general continuous queries, new
language-native SQL APIs, compression negotiation or arbitrary temporal proofs.

### Failed controls and recovery limits

The initial lifetime/direct-Table runs fail during bootstrap on unavailable
authority replies. `f1eb1734a` gives saved provisioning owners a finite 30-second
retry window while retaining their live processes and exact persisted request;
each transport attempt remains bounded by the configured two-second limit.
A deliberately dropped accepted spawn receipt replaces the node on the control
binary. The corrected schedule verifies identical node/proxy PIDs, byte-identical
request/receipt recovery and SQL readiness without an automatic restart. It does
not establish the cause of every earlier unavailable observation.

Two full fault attempts stop on fixture assumptions: rejected reloads were
expected to be applied, and a five-second observation budget could expire before
durable write admission. The write-loss schedule now gates its pause on accepted
admission and releases it at the selected status loss, using the console's normal
30-second budget. A separate five-second refusal case still proves bounded
uncertainty and no admitted operation. The frozen pre-result-model control takes
4.087–4.866 seconds merely to admit three ordinary writes (6.365–7.432 seconds
through completion). Some diagnostic attempts under concurrent disk work also
exceed 30 seconds. They remain failures; neither the corrected schedule nor the
later pass establishes a five-second latency bound or attributes all delay to
contention. No production SQL deadline was increased.

The earlier retained installed ALTER attempt under a foreign result definition
is still unresolved at original operation 174: inspection finds uploading work
with no terminal outcome. Original CREATE 81 and INSERT 126 are observed applied.
No SQL was submitted again to resolve those identities. Fresh compatible ALTER
passes do not turn the unresolved original into a pass, authorize data reset or
permit the current binary to reinterpret that installation.

## Finite retained SQL point reads — 2026-10-25

On `765b287b` plus finite point selection, the pinned-shell command
`just test::direct-table-service prepared` passes. A 17-row source needs three
ordinary scan pages; complete-key queries finish within eight charged native/
Table exchanges, or ten for prepared execution. Independent checks cover a
late key, absence, empty COUNT/SUM, LIMIT 0, inequality/OR/full-count controls,
and an additional non-key predicate that exhausts the same tight scan budget.
Prepared reads retain typed values, fresh snapshots, current denial and rejection
after ALTER or DROP/recreation. Composite Unicode/text/negative-integer equality
follows declared key order despite a different predicate order. Valid comparison
values beyond VARCHAR or encoded-key bounds remain successful empty queries.

The final focused run passes after correcting an intermediate Zig type-inference
compile error in the new key owner. Documentation checks and diagnostic inventory,
mapping, error-boundary and outcome checks pass. Full repository and clean-lane
qualification for this SQL change remain pending; this evidence does not qualify
inequality pushdown, encoded execution or a latency improvement.

## Direct SQL ledger recovery and pin authority — 2026-10-24

`nix develop --command just test::sql-gateway` passes the migrated direct Table
schedule in 26.796 seconds. It retains 33 account operations, fences three owner
replacements, and recovers the exact native admission, detached wait and pipelined
upload after lost replies. A separately lost committed Table outcome is recovered
through its original direct operation without executing that mutation again.
Current preparation/reads dispatch no native writes; parameterized PostgreSQL and
MySQL reads, a self-join sharing one retained pin, exact mutation counts and paged
history all pass. The independent control ledger records 153 turns and 156 sends.
All 30 shared SQL unit tests pass, including configuration checks for independent
Table data identities and the required capture executor.

After removing the obsolete private Table-reader principal, all 30 SQL units and
`nix develop .#sql-wire --command just test::server-sql-local` pass. The installed
CLI/node/gateway schedule qualifies the five-principal account, trust and password
authentication, TLS enforcement, revocation across restart, and exact bootstrap
credential publication after reply loss and manager SIGKILL.

`nix develop --command just test::direct-table-service` also passes 1,253 public
typed calls, including the updated SQL read-pin recovery schedule. A denied
current credential resolver preserves both original acquisition records. Recovery
then closes interrupted acquisitions and old-generation pins; current revocation
still refuses cleanup until access is restored. The complete command also checks
64 KiB point data, bulk `.tseg` publication, CRUD/DDL, namespace retirement,
retained SQL/joins, delegated reads and change-reader checkpoints across restart.

SQL Table sources now derive their direct route from the declared data scope;
their native resource holds independent computation progress. Interactive source
pins share the account's recovery journal, while captured admission publishes the
explicit original cut, executor and pin operation.

`nix develop .#sql-wire --command zig build test-sql-wire-gateway
-Doptimize=ReleaseSafe -- sessions` passes the complete native-session schedule.
It checks independent TLS/SCRAM sessions, concurrent reads, metadata recovery,
exact operation-token recovery and retained KV (41 rows), Document (12 rows)
and Table (9 rows) results after gateway replacement. Every returned batch is
retried for exact equality. Replacement releases the original abandoned Table
source pin. The focused `sessions-table` slice and all 30 shared SQL units pass.

Same-account pin acquisition now observes the prepared definition/frontier under
the acquisition/closure lock. An injected capacity refusal after acquisition
checks that cleanup preserves SQLSTATE `53000`. Concurrent fixture reads may
explicitly repeat a SELECT only before receiving any batch; measurements count
those attempts. Existing cursors, captured admissions and writes never use that
helper. These scoped passes do not qualify every SQL deployment or close the
coordinated cutover.

## Native SQL namespace lifecycle — 2026-10-24

The shared current-v1 definition is
`819b12b133443f6c0a269c818da0698cb222ac4cad1d7010da3ac602000a0f55`.
The previous definition rejects. Native SQL prepares CREATE/RENAME/DROP SCHEMA
without publication, stores the original namespace binding in its operation
ledger and dispatches to the direct catalog. Schema commands have a mandatory
null prepared result schema. Row-returning statements retain their logical
schema independently of whether execution returns any rows.

In the pinned Nix shell, ReleaseSafe SQL tests pass **30/30**, protocol tests
**51/51** and SQL protocol tests **7/7**. The ledger schedule preserves the
selected session namespace separately from the changed schema, checks exact
terminal evidence and replacement fencing, and validates rejection/cancellation
diagnostics. `just test::direct-table-service` passes **705** typed HTTP calls,
including the real SQL preparation/binding path, stale prepared and admitted
schema rejection, lost replies, name reuse and exact outcomes after restart.

`just test::server-direct-faults` passes Table and namespace operations under
blocked direct execution, killed callers and abrupt server restart. Reads and
control requests remain available; recovery uses the saved original intent,
and cancellation leaves the unpublished namespace change unapplied. The fixture
now sends the public cancellation wrapper instead of an invalid bare identity.

The installed namespace schedule exposed two defects: command preparation tried
to encode an invalid empty logical structure, and the console omitted the
recorded dependency reason for a rejected DROP. Both are fixed. The subsequent
installed run failed earlier, during Table DDL, while SQL readiness repeatedly
reported `AuthorityTimeout`; the console correctly preserved an unknown outcome.
That run is not passed. A subsequent `just test::server-direct-tables` run passes
the complete installed schedule: Table CRUD/DDL and schema lifecycle while the
query worker is stopped, inert preparation, stale schema rejection, visible
dependency diagnostics, abrupt restart, original outcomes and deliberate
default-Table deletion/name reuse. The fixture logs each static Table statement
to identify a failing stage without exposing saved credentials or requests.
The repository-wide `just check` subsequently passed. It began before the
following change-reader cutover, so it is not final committed-HEAD qualification.
Contract generation/checks, diagnostic inventory/mappings,
inferred error boundaries and **3411** diagnostic outcome projections pass.
The earlier documentation site check passes nine tests and its build, preceding
the final nullable-schema and diagnostic prose updates. These scoped results do
not close the milestone's remaining caller and provisioning gates.

## Lossless physical column admission and public SQL — 2026-10-23

The Fuze package's ReleaseSafe suite passes after replacing the shared definition
with `f2f9eecaf384f4ef6dde55ad0af62bf368ff17e76cfe0877665d1070a8460982`
and the standalone Table schema definition with
`transit.table.schema.v1.2026-10-23`. Physical pages require the current binary
definition; missing/foreign definitions and the previous schema definition reject.
`just test::table-schema` passes the independent fixtures and standalone checks.
The CP037 oracle covers every scalar U+0000–U+00FF and all 65,536 scalar pairs;
HFP fixtures use independent rational arithmetic and exact floating bits.
Mainframe page fixtures include signed 64-bit extrema. Regressions cover signed
zero through RLE/dictionary/HFP, unsupported descriptors, unmappable characters,
HFP range limits, trailing data and bitpacked overflow. The neutral JSON schema
adapter rejects physical attributes instead of dropping them.

`just test::direct-table-service` passes 420 typed calls against the real node.
Its added Table uses bitpacked integers and CP037 text. Retained SQL reads agree
for WAL-only and mixed WAL/segment cuts before and after restart, including
accents, punctuation, NUL and control scalars. ALTER of a separate column
containing `€` to CP037 records a durable constraint rejection without changing
the definition or logical-data frontier. A later ASCII_CI definition is usable
by storage but rejects direct SQL evaluation; old binary-collated pins retain
their original semantics. Existing reply-loss, CRUD/DDL, revocation and retained
query proofs also pass.

The focused storage run
`zig build test -Doptimize=ReleaseSafe '-Dtest-filter=physical value constraints'`
also passes in `packages/zig/transit-storage`. Rejected CP037/HFP rows leave the
WAL frontier and root unchanged; accepted integer extrema, a 31-digit decimal,
CP037 text and floating negative zeros agree between retained WAL and flushed
segment rows after disk reopen.

`just contract::check`, diagnostic error/outcome checks and documentation links
pass. This evidence does not establish non-binary SQL comparisons, ICU, other
codepages, neutral SDK physical descriptors or Arrow page borrowing. The full
`transit-storage` ReleaseSafe test suite also passes at commit `b6ba9deb`.

## Conditional SQL catalog outcomes — 2026-10-23

The direct catalog component passes **119/119** tests after adding exact name
assertions. Disk tests cover lost replies, restart, rename/name reuse, changed
intent and cross-kind identity rejection. Memory tests cover late authorization
denial before publication, cancellation, and 129 assertions with one resident
page. This catalog run precedes the subsequent HTTP/SQL wiring and definition
regeneration; it is evidence for the component transition logic.

With the shared definition derived from
`transit.native.v1.conditional-catalog-evidence.2026-10-23`, the SQL package passes
**29/29** tests in ReleaseSafe. The new cases verify the committed dispatch gate,
replacement, original catalog evidence, unchanged summaries, rejection and
cancellation, and rejection of fabricated Table terminals. Independent Python
fixtures include absent-name outcomes and full-width object/log identifiers.
An initial gateway compile exposed a missing unchanged-status projection; the
corrected gateway passes `zig build check` (Debug, MaxRSS 423 MiB).

`just test::direct-table-service` passes **370 typed HTTP calls**. The SQL compiler
produces retained existing-name and absent-name assertions, and ordinary Table
work for conditional DDL that does require mutation. The proxy corrupts the
first assertion acceptance response. Inspection recovers its unchanged outcome;
two node restarts preserve it, including after the original Table is dropped and
its name reused. A previously absent name created before acceptance produces
durable rejection; cancellation remains terminal. The earlier CRUD/DDL, query,
read-pin, revocation and `.tseg` checks also pass. The later terminal bound
correction is covered by the full-width SQL fixtures and gateway compilation.

`just contract::check`, diagnostic error/outcome checks and documentation links
pass after regeneration. These proofs do not qualify an installed SQL listener,
the default launcher, dependency enforcement or named-resource provisioning.

## Direct SQL references and read recovery — 2026-10-23

In the pinned Linux Nix shell, `just test::direct-table-service` passes
**316 typed HTTP calls** against real local native/Table owners and two node
restarts. The added cases cover retained self-join/grouping over an older source,
namespace listing, source/column completion, and current revocation after result
completion. A renamed Table rejects an older pin despite an unchanged column
schema. Existing full CRUD/DDL, 64 KiB point rows, bulk `.tseg` publication and
saved typed SQL mutations also pass.

The same proof exercises SQL's disk pin journal. It corrupts an accepted pin
reply, retains an active pin across restart, protects current-generation active
reads and releases earlier-generation/closing pins. A release denied by current
rights leaves durable cleanup work; restoring rights permits exact release and
idempotent closure. The helper supplies the gateway generation explicitly; this
does not independently qualify native SQL activation fencing or installed SQL
listeners.

SQL `zig build test -Doptimize=ReleaseSafe --summary all` passes **28/28** tests
(309 ms, MaxRSS 11 MiB). Cases cover committed dispatch eligibility, exact frozen
reference/content identity, replacement, local abandonment versus qualified
cancellation, terminal position attribution, paged growth and independent record/
control fixtures. The CLI and gateway executables compile with the changed session basis and
completion descriptors. Diagnostic checks pass 3387 outcome projections across
29 surfaces, plus 16 inferred error sets and nine unknown-cause projections.

The full storage run passed **56/58** tests and failed two ALTER fixtures that
reused one row identity for different rows. After assigning distinct ordinals,
`zig build test -Doptimize=ReleaseSafe -Dtest-filter='Table ALTER'
-Dtest-filter='Table identity index' --summary all` passes **4/4** tests (7 seconds,
MaxRSS 52 MiB), including a new point/bulk identity-alias rejection case. The
failed full run is not reported as a complete pass. Fuze **334/334** and Query
**141/141** had passed earlier in this work before the definition regeneration;
the current full-repository gate remains separate.

Two earlier pin-journal runs failed before acquisition: the parent descriptor
was unsuitable for directory sync, and new-file publication called the atomic
replacement API. The journal now owns a readable parent descriptor and uses
atomic link for creation, atomic replacement for updates. Only the completed
runs above count as passing evidence.

The shared definition derives from
`transit.native.v1.direct-sql-read-recovery.2026-10-23`; the previous identifier
remains an explicit rejection case. Contracts, binding resources, independent
signing/storage fixtures and SQL records are regenerated together, and
`just contract::check` passes. Installed SQL fault/recovery qualification,
conditional catalog DDL, launcher provisioning and physical GC remain open.

## Saved direct SQL mutation intent — 2026-10-23

The catalog package passes **115/115** tests in the pinned Linux Nix shell
(one minute, MaxRSS 71 MiB). The saved-intent cases verify independent Python
canonical bytes, full-width identities, copied binary/NULL parameters, exact
predicate/data-frontier binding and rejection of incompatible, missing,
truncated, altered and noncanonical work. Templates and parameter values can be
destroyed before loading and executing the independently owned intent.

`just test::direct-table-service` passes **193 typed HTTP calls**. Numbered
parameters drive INSERT, UPDATE and DELETE through metadata-only preparation
and binding, then explicit admission/execution. The proof checks unchanged
frontiers and absent operation records before admission, exact readmission,
saved-intent outcome inspection after restart, and a MySQL positional DELETE
saved before restart but first admitted afterward. Its unchanged outcome leaves
the logical-change frontier intact while operation history advances. Existing
retained reads, CRUD/DDL, revocation and two-restart checks also pass.

An earlier fixture run freed its newly retained intent buffers before saving
them; the fixture now returns an explicit arena owner. A subsequent run tried
to pin an old physical frontier after the unchanged DELETE. The final fixture
captures a new frontier for that new pin and checks the unchanged logical basis.
Only the final complete HTTP run is counted as passed.

Direct contract/schema generation, diagnostic error/outcome checks and local
documentation links pass. These typed caller checks do not qualify installed
SQL gateway execution or complete the default launcher cutover.

## Frozen SQL predicate mutations — 2026-10-23

The pinned storage suite passes **58/58 tests** with typed predicate intents and
private bounded execution. Run it with
`nix develop --command sh -c 'cd packages/zig/transit-storage && zig build test --summary all'`.
Its disk case
creates 1,400 rows, retains a snapshot, admits a compiled UPDATE, closes the
physical stores, reopens them, loses the final execution reply and verifies one
acceptance record for all 1,400 changes. Another reopen returns the exact outcome;
a no-op matches all rows without changing the logical frontier, and DELETE
removes all 1,400 rows while the original pin remains readable.

The failure case records terminal rejection for a late key collision, stale data
and exhausted row/byte budgets. Revocation at publication leaves the original
rows and admitted work intact. The suite used one resident index page, took
about **14 minutes** in Debug and reported **56 MiB** maximum resident memory.
That duration includes the whole suite and disk synchronization; it is not a
statement latency benchmark. Per-row immutable index publication still causes
substantial write amplification.

The catalog suite passes **110/110 tests**, including typed plan/digest binding,
predicate preservation, missing-data-basis rejection and action mismatch.
`just test::local-catalog` passes private UPDATE under an UPDATE-only native
Table grant while denying SELECT pin acquisition. The shared-definition cutover
also passes the full contract check and diagnostic boundary/outcome checks.
`just test::direct-table-service` passes **139 typed HTTP calls**, including
primary-key UPDATE and two predicate DELETEs, exact re-admission after commit,
and original outcomes after another service restart. The existing concrete
CRUD/DDL, finite SELECT, retained-pin and revocation cases still pass.
These checks do not establish the default launcher or SQL gateway cutover.

## Finite SQL over retained direct Tables — 2026-10-23

The query package passes **140/140 tests**, including its native catalog-query
composition, with `DirectTableQuery` and its bounded direct source adapter.
`just test::direct-table-service` passes **119 typed HTTP calls** after adding
Fuze SQL execution to the independent caller.

The caller filters the original retained Table with `WHERE` and `LIMIT`, returns
its 64 KiB binary value, and computes unsigned `COUNT(*) = 2` after the live Table
has been rewritten, dropped and replaced. These checks run before and after the
second service restart. Closing a query leaves the separately owned pin usable.
Exhausted request budget during open and exhausted result-byte budget produce
errors; a failed query cannot return a successful continuation. Revoking rights
after opening `LIMIT 0` denies its empty result at the final disclosure gate.
Diagnostic projections and documentation links also pass.

This is a public typed finite-query owner over an explicit pin, not the installed
SQL gateway or launcher cutover. It does not prepare parameters, acquire pins,
execute DML or join independent sources. Non-binary text collations reject before
execution; their SQL comparison semantics remain unfinished. These checks do not
qualify all logical types, predicates or physical profiles.

## SQL idle lifetimes and readiness observations

The [configuration reference](../../handbook/reference/configuration.md),
[wire contract](../../../contracts/SQL_GATEWAY_V1.md) and
[Internals lifetime model](../../handbook/internals/service-interfaces.md#distinct-lifetimes-and-result-disclosure)
distinguish idle wire connections, renewable HTTP session leases and finite
request deadlines.

Executed on Linux in the pinned development shell against isolated disk-backed
installations:

- `just test::server-sql-lifetimes`: real psql and independent PostgreSQL/MySQL
  sockets remain connected beyond 30 idle seconds, over plaintext and TLS.
  A concurrent console insert remains visible. Native HTTP handles independently
  expire under a one-second lease. A configured one-second wire timeout returns
  PostgreSQL `57P05` or MySQL `4031` without expiring a separate native handle.
  With idle expiry disabled, incomplete wire frames, partial TLS records and
  application bytes already buffered by TLS close under a one-second frame bound.
  The fixture verifies unchanged child PIDs during each scenario and joins them
  during teardown. Its piped psql client stops on SQL errors and includes SQLSTATE
  in stderr; an error cannot silently become a wait for a nonexistent row.
  Failures retain the current phase, query, exit status and bounded stderr tails
  in `.cache/verification/server-sql-lifetimes-failure.json`, included in CI
  artifacts. Configuration and native session credentials are excluded.
- `just test::server-logging`: four held native request bodies exhaust data
  admission. SQL status reports `busy` and `HttpCapacity` at warning level,
  withholds confirmed readiness, preserves child PIDs and emits no repeated
  connection instructions on recovery. Killing the SQL process still produces
  the existing failed error event and replacement behavior.

The initial reproduction on the preceding implementation completed a console
INSERT while psql was open, logged generic `AuthorityUnavailable`, and closed
psql after 30 idle seconds without replacing any server role. Preserving the
native rejection exposed `HttpCapacity` during the write. These finite schedules
qualify lifecycle and reporting behavior, not sustained-load throughput or a
promise that an admitted write cannot outlive its connection.

## Shared server-managed SQL sessions

The native console, PostgreSQL and MySQL adapters share the SQL service's
account coordinator. Local consoles authenticate through Unix peer credentials;
explicit remote clients use the HTTPS session API and SCRAM. The
[console guide](../../../apps/transit-cli/docs/console.md),
[session contract](../../../contracts/SQL_SESSION_V1.md) and
[Internals account](../../handbook/internals/service-interfaces.md#shared-sql-sessions-ownership-and-recovery)
own behavior and reasoning. [SQL sessions](../../../apps/transit-cli/docs/console.md) records delivery scope.

The [evidence record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sql-sessions-2026-10-21.json) preserves
exact source/binary hashes, commands, raw structured
reports and selected earlier failed or aborted attempts. The pinned Zig 0.17 development
shell supplies ordinary checks; the `sql-wire` shell supplies real database
clients. Fixtures use disposable disk-backed Ursula installations. The user's
installation and server processes are untouched.

Executed coverage includes:

- `just check`: Zig unit/protocol checks, generated contracts, 555 actual CLI
  diagnostic cases, terminal history/editor checks, frontend checks and handbook
  generation. Logical codec fixtures remain independent of the HTTP client.
- `just test::server`: automatic local discovery, independent console settings,
  concurrent admission, lost replies and original-token recovery, reserved
  control capacity, native transport/Host boundaries, real PTY output, catalog
  DDL/DML, revocation across restart, process recovery and shutdown. The full
  lifecycle at `3ceb1bb3` completes in 568.23 seconds.
- `just test::server-faults`: bootstrap loss/SIGKILL preserves installation
  identity and exact receipts; signed native denial, Host/framing limits, artifact
  checks and rollback rejection pass at `41d75db4` in 95.48 seconds.
- `just test::station`: object registration survives an injected unavailable
  observation, refused submission and lost accepted reply through its native
  binding ledger. An injected expired view renews at a fresh command sequence
  for the same durable input. Typed Table/audit/reply publication, worker/store
  recovery, query policy, lifetime and supervision checks also pass. The previous
  worker fails the new expired-view schedule; that negative control is retained.
- `just test::sql-sessions`: independent HTTPS/SCRAM client, local peer and real
  remote console, typed parameters, current revocation, token conflict/identity,
  service SIGKILL, configuration-owner recovery, lease/control isolation and
  exact fetch retries. Explicit KV (41 rows), Document (12) and Table (9) results
  survive replacement through their original captured operations. Injected
  source-metadata and retained-page refusals recover without SQL replay.
- `just test::sql-wire-gateway`: real psql/mysql and libpq/libmysqlclient,
  PostgreSQL text/binary and MySQL text/binary types, preparation/admission,
  settings, TLS rotation, authorization, detached writes, cancellation, oversized
  values, relational reads, transport fragmentation and capacity/drain behavior.
  The 40 KiB row is submitted once; the client wait ends before the original
  operation completes. Operator discovery verifies its identity and affected
  counts, then both wire clients verify all ten variable-size cells.

Committed-source `just ci-clean --lane core` at `314c8d0d` passes all 28 tasks in
2002.08 seconds; `just ci-clean --lane experience` at `74c18c41` passes all nine
in 1168.46 seconds. Exact task times, source revisions and binary hashes are in
the evidence record. The subsequent
source-binding retry is covered by `just check`, the full source fixture and the
experience lane at `74c18c41`. The full wire fixture builds at that revision.
The source fixture builds at `7973cf1e`, whose only change corrects the
retained-page fault target. The final documentation/evidence commit changes no
runtime behavior.

Planned matrix cases do not count as executed coverage. The measurements record
first-batch latency, HTTP body bytes, internal requests and sampled process/WAL
capacity. They include other host work and recovery. WAL capacity includes
allocated segments; it does not isolate retained operation bytes or cold-store
usage. The small sample does not establish a speedup or latency guarantee.

The current definition is a hard cutover. Missing/foreign definitions reject
without resetting installation history or accepted work. No conversion, rolling
upgrade, transaction, automatic SQL replay or resumable interactive-query claim
follows from these tests. Source owner groups are deliberately scheduled one at
a time and captured admission occurs while owners are paused; the test does not
qualify sustained simultaneous load from all three source types. The remote
client uses a fresh HOME and only connection/trust
credentials, but the test does not isolate its filesystem/network namespace or
execute a different-OS-UID client. The host refuses user namespace creation
(`uid_map: Operation not permitted`), and noninteractive privilege elevation is
unavailable; the evidence records these capability probes as blocked deployment
checks, not SQL test passes. Selected core/experience lanes do not replace
the full language, growth, browser or Arrow/Flight inventories.

## Database wire gateway

The [retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sql-wire-2026-10-14.json) records the
2026-10-14 UTC full gateway run at `858732ad`, its raw observations, local log
digests and failed attempts. `just test::sql-wire-gateway` passes in **1412.941
seconds**, with no tracked changes at measurement. It runs the actual TLS gateway,
Catalog host/courier and native authority over disk-backed Ursula and pinned
MinIO, with eight resident pages, 8 MiB hot storage and an 8 MiB cold cache.
The run flushes 1426 cold data objects; MinIO's sampled file size is 374415355 bytes.
This is a workspace run, not clean-checkout CI.

The pinned clients are Psycopg 3.3.4, psql/libpq 18.6, Connector/Python 9.4.0 and
Oracle mysql/libmysqlclient 8.4.11. In that recorded run, Python and C checks
execute CREATE, prepared INSERT/SELECT/UPDATE/DELETE and all six scalar types;
CLI checks execute literal SELECT. The independent C checks cover signed/unsigned
extremes, parameter/result metadata, NULL, binary values, reset and counts.
PostgreSQL checks both result
formats and duplicate rejection SQLSTATE 23505. MySQL checks changed-row and
CLIENT_FOUND_ROWS modes. Literal int64 joins/groups and defaults versus explicit
NULL use the shared owners.

The same run qualifies operator initialization, locked/synced signed controls,
paged discovery, current terminal inspection, processed-control retry and fenced
restart. Raw TLS tests reject write Flush/double Execute cycles before mutation,
close PostgreSQL portals at Sync, cancel suspended reads, reject stale cancellation
keys and recover the next request. An admitted INSERT completes once after losing
its database reply. Both protocols reject wrong credentials/account/database and
plaintext downgrade. Certificate replacement rejects old trust and accepts new
trust; PostgreSQL additionally checks invalid hostname/trust. Verifier revision
changes invalidate retained sessions, and disabled credentials reject new sessions.

Catalog administration uses principal 1234 independently of the gateway's Table
principal 1235. Read-only policy denies CREATE/INSERT/UPDATE/DELETE, including
retained prepared handles, without adding gateway operations; reads still work.
External ALTER, DROP and name reuse invalidate both protocols' prepared reads and
writes. Native read revocation denies retained handles and suspended portals.
The subsequent **210.596-second controls slice** additionally proves that new
preparation metadata and previously committed operator counts are suppressed after
native read revocation, with no partial stdout from failed control inspection.
That slice excludes the independent client matrix and wide values.

A single prepared INSERT carries ten 4096-byte variable fields, **40 KiB total**.
The 270-second SQL wait ends, while discovery identifies the one original durable
operation. Its terminal result is observed after **965.415 seconds**, with exactly
one matched and changed row and no SQL retry. Binary readback through both
protocols verifies the values; a supplemental read checks every one of the ten
cells, and the repeatable fixture includes that full readback. A 4097-byte bound
cell rejects with SQLSTATE 54000. The operator proof has a separate 1800-second
observation budget and two-second polling; these do not extend the SQL deadline.
This measured completion cost is not an interactive latency guarantee.

Eight-session saturation preserves private health and reserved TLS cancellation.
Four stalled authentication attempts expire at their absolute deadline. The
fixture checks 16 prepared handles, four portals, oversized header refusal,
readiness withdrawal and joined SIGTERM drain. Package tests additionally cover
malformed Sync recovery, dependent portal cleanup, remembered MySQL parameter
types, invalid cursors, monotonic handles and no replay after partial output.
Exhaustive allocation-failure schedules pass both session owners.

The report separates framed-row encoding, verified connection startup,
preparation, first-row/complete-read and durable write timings. It retains raw
samples, native/provider request and byte counters, and sampled gateway RSS/HWM.
`just test::sql-wire-encoding` measures all six scalar types plus NULL in 10000-row
samples, independently of TLS, sockets, authority and storage; it also runs before
the full gateway proof. The native read comparison includes a fresh helper process
and compilation, while driver paths retain connections/preparations. Instrumented
request windows include concurrent account maintenance; Catalog host/courier
traffic bypasses that proxy. No causal subtraction or throughput claim follows.

Failed attempts remain failures. Early wide tests exposed the 4096-byte scalar
bound, command/native-read deadlines and the 64 MiB hot-only Ursula limit; the
latter produced ColdBackpressure/DeadlineExpired. The cold fixture removes that
capacity condition. A later inventory race required fresh read-conflict retries
and ordered operation cursors across forward revisions. The 900-second operator
observation still ended with an active, unblocked original operation; it did not
establish completion. The longer passing observation retains the SQL deadline.
Initial policy/DDL fixtures also misclassified successful `policy_applied` and
`delegated`/Table-applied dispositions; their corrected assertions pass.

`just test::sql-gateway` passes again in **74.181 seconds** during concurrent wire
qualification: 33 retained operations, three fenced replacements, lost receipts
for Table/ingress principals and a detached wait, 214 turns and 208 sends. It checks
original signed bytes, counts, paged recovery and control decisions against disk.
Its scope is native ledger/runtime recovery, independently of database framing.

`just test::sql-wire-placement compose` passes in **277.639 seconds** and the
`reference` placement passes in **326.564 seconds**, including image preparation.
Both use the pinned OpenSSL package, actual TLS, six scalar values, typed prepared
queries/mutations and original counts. Both stop the gateway, Catalog host,
courier, node and store, then recover the same state with fresh native generations
before another write. Reference additionally runs the Catalog host in Substrate,
retains gateway activation markers on a PVC and executes independent egress
denials. These replacements occur after completed mutations; the separate native
ledger schedules cover pending steps, lost receipts and fencing.

The full `just check` passes at `858732ad`. `just transit-board::query-browser`
also passes its real Chromium recovery, Canvas/Browse and current-grant/cut checks.
The diagnostic inventory includes the gateway application; its preexisting mapping
manifest covers its declared boundaries, not this entire new wire surface.
Application/session tests and actual negative cases own the SQLSTATE mappings.
Final clean qualification uses `just ci-clean` (all five ordinary lanes at one
committed revision) or `just ci-clean --complete` with the installed browser.
Individual `--lane` runs provide scoped clean evidence. When composing them,
record each source revision and intervening changes; a failed complete run is
not a complete pass, even when all tasks in an earlier lane finished successfully.
Those runs create revision-qualified timing/completion reports under `.cache/ci/clean`;
focused and deployment results do not stand in for them. Hosted CI status is
reported separately in the implementation PR.

The clean SDK run at `c5d46e8f` passed the Python Table consumer checks but failed
the enclosing prepared-parameter schedule: its hot-only Ursula store reached
the 64 MiB total limit and returned `ColdBackpressure`. The supplied host then
stopped; this is a failed task, not a Python qualification pass. Installed SDK
Table recipes now select the existing cold-store fixture, with 8 MiB hot/cache
bounds and eight resident authority pages. They retain all cases and deadlines.

Board query setup also exceeded its former 60-second fixture budget in two clean
attempts, at `c5d46e8f` and `2fa8da42`. The latter log still shows successful
commits through position 257 at the cutoff, before any browser/query assertion.
Board now uses the same 300-second provisioning budget as `public_query.py`,
which invokes the identical setup helper, and reports setup time separately.
Other administrative waits, native requests and query deadlines are unchanged.
The clean experience lane at `fec5dd68` passed separately; it does not turn
either timed-out attempt into a pass.

The clean browser run at `534c334d` passed its first five tasks, then failed
`test::reactive-views`: a newer completed query retained the source resource,
contract and schema, but Board reported reset-required when its bound execution
fingerprint changed. A focused diagnostic run reproduced the same failure.
That fingerprint includes the captured source basis. Board now compares the
source/contract/schema across refreshes; the native owner still copies and
verifies the original template, and complete-result verification still requires
one identical manifest across every page and the current-authority reread.
The browser proof explicitly checks the new namespace, advanced cut, unchanged
source contract/schema and changed execution fingerprint before testing denial.
These failed attempts remain separate from the subsequent qualification results.
The corrected focused run passes in **190.09 seconds**; its measured mutation to
verified visible query result is **27012 ms**, followed by successful denial
between full verification and the visible reread. `just check` also passes with
the correction. These are workspace results; the committed-source browser lane
is recorded separately.

The expanded gateway run at `12236039` passed its CLI/C/Python matrix and raw
write cycle but failed the 1800-second wide-write observation. The original
operation remained active and unblocked; the native log still records successful
turns and delivery through position 12662. Completion was not established. The
added CLI mutations had changed the accumulated history before that measurement.
The full gateway task now runs those CLI lifecycles in a separate owned fresh
fixture, preserving the earlier wide workload and its deadlines. Both schedules
must pass; neither the failed observation nor the passing client prefix qualifies
the complete task.

### Committed-source qualification

The clean qualification record (archived)
retains passing evidence for all **89 inventory tasks**, including the seven
browser tasks. This is composed coverage across committed-source clean checkouts,
not one complete run at a single HEAD. Exact task scopes, revisions, durations,
log digests, orchestration scripts and failed attempts remain in the record.

| Lane       | Passed tasks | Source revisions       |
| ---------- | -----------: | ---------------------- |
| core       |        23/23 | `d9c0e599`             |
| growth     |        32/32 | `6cfeab83`, `f3687a86` |
| experience |          7/7 | `fec5dd68`             |
| launchers  |          2/2 | `c5d46e8f`             |
| bindings   |        18/18 | `2fa8da42`, `74391333` |
| browser    |          7/7 | `74391333`             |

The original complete run at `6cfeab83` finished all 32 growth tasks, then failed
in the TypeScript SDK inspection decoder. Later clean runs qualify that correction,
Board asset grouping, SDK cold-store selection, provisioning setup and refresh
identity. Native runtime and wire/ABI definitions are unchanged after that growth
source. The expanded CLI fixture has a fresh full gateway pass.

Bindings combines eight completed tasks from its original clean run with complete
Java/.NET and BEAM/remaining-task subsets executing unchanged canonical recipes.
The original sequence was intentionally interrupted during duplicate Java work
after Java had passed in its separate clean subset. Its incomplete enclosing run
is retained as interrupted; it is not counted as a complete bindings-lane pass.

The fresh gateway task passes at `f3687a86` in **1709.14 seconds** across two owned
fixtures. Both `psql` and Oracle `mysql` execute CREATE, INSERT, UPDATE and DELETE
in their own fresh history with Unicode/NULL and independent-connection row readback.
The original fixture retains its wide workload and deadlines alongside the full
C/Python prepared matrix and authority, credential, schema, bounds and drain cases.
Its one original 40 KiB operation completes after **1056.655 seconds**
with original matched/changed counts and all ten cells verified through both
protocols. The SQL wait remains 270 seconds, the operator observation budget
remains 1800 seconds, and SQL is sent once. The earlier 965.415-second workspace
measurement remains a separate observation; neither establishes a latency bound.

The first expanded CLI run at `fed0ed76` completed the client matrix, then failed
when the raw fault client used its ten-second connection timeout for a valid
durable INSERT. Only that command now receives one absolute 300-second client
response deadline around the existing 270-second SQL wait. Authentication and
malformed-cycle checks retain ten seconds; no mutation is resent. The failed
587.02-second enclosing task remains recorded separately from the later pass.

The complete clean browser lane at `74391333` passes all seven tasks. Its live-view
fixture takes **306.73 seconds**, with **52500 ms** from mutation to verified display,
then denies the visible reread after revocation. Lifecycle reset also passes in
**69.81 seconds**. The full source manifest remains fixed within each finite result;
a later source cut may change the bound execution fingerprint without changing
the original template, resource, contract or schema.

Local timing sums inform CI execution caps, separately from hosted setup and
feedback budgets. Parallel local qualification can affect those measurements.
Hosted status is reported in the PR and cannot be inferred from these passes.

## Database wire foundation

Issue #48 implementation starts from merged `b775e2b7`. On 2026-10-13,
`just test::sql-wire-reference` passes against owned PostgreSQL 18.6 and Oracle
MySQL 8.4.11 servers with verified TLS. Psycopg 3.3.4 and Connector/Python 9.4.0
execute prepared reads, INSERT, UPDATE and DELETE where exercised by the
[probe](../../../tests/interfaces/sql_wire/reference.py); psql/mysql execute literal reads. The
[sanitized transcript](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/sql_wire/reference-transcript.json) retains message kinds
and selected driver settings, never authentication, parameter or result bytes.
The PostgreSQL intermediary actively withholds Execute through Sync; the
prepared executions complete without a Flush dependency. The MySQL intermediary
removes unsupported capability flags from both sides of negotiation. Connector
configuration explicitly selects autocommit, `utf8mb4_0900_bin` and
`ANSI_QUOTES,NO_BACKSLASH_ESCAPES`; the initial handshake still proposes
collation ID 255, before its SET NAMES command. The repeated reference run
checks the observed settings, trailing-space/case inequality and literal
backslashes. It replaces the initial PAD SPACE `utf8mb4_bin` probe setting;
NO PAD matches the intended gateway comparison profile.

`just test::sql-wire-tls` passes the standalone Zig/OpenSSL server transport:
both database upgrade request formats, TLS 1.2/1.3, fragmented application input,
certificate trust and hostname rejection, plaintext refusal and absolute
handshake timeout. Its MySQL upgrade probe begins at SSLRequest; the reference
server probe separately exercises a real greeting and password authentication.
The TLS package unit test also checks the exact OpenSSL version and rejects
missing credentials. `just doctor` passes in the new shell. The locked Nix input
revisions and Zig compiler are unchanged.

These are client and transport foundation checks. Neither Transit database
listener, gateway authentication, prepared Table binding nor durable gateway
write recovery is qualified by them. Later gateway, fault and placement results are recorded above; these foundation
checks alone do not establish them or clean-suite completion.

## Database wire primitives

On 2026-10-13, `just test::sql-wire-contracts` passes bounded PostgreSQL/MySQL
frame decoding, fragmented/coalesced input, lengths and sequence rejection,
PostgreSQL write deferral through Sync, failed-cycle draining and suspended-read
identity checks. Common scalar admission refuses unsupported logical types and
non-SQL cell states. Authentication tests verify an independently generated
PBKDF2/SCRAM fixture, wrong credentials/proofs, unsupported password characters,
channel binding and consumed authentication state. The Python fixture checker
recomputes all credential and proof bytes using hashlib and hmac.

The extended codec corpus also passes: 25 independently generated PostgreSQL
scalar cases and 26 MySQL cases cover full signed/unsigned ranges, signed zero,
subnormal/max finite floats, Boolean, UTF-8, empty values and all 256 binary byte
values. Python struct/base-10000 encoders produce the expected wire bytes. Zig
checks both decoding and emitted binary bytes; text round trips preserve values.
Message tests distinguish NULL/empty, reject malformed bodies/flags/overflow,
and retain MySQL parameter types only after complete valid input. PostgreSQL
text rejects NUL while length-encoded MySQL values retain it.

PostgreSQL backend/startup package tests also pass independent framed SCRAM,
parameter metadata, numeric RowDescription, text/binary DataRow with NULL,
full-width UPDATE count, SQLSTATE error and minor-version negotiation fixtures.
Startup tests reject duplicate accounts, ambiguous termination and unsupported
major versions. Aggregate frame overflow and invalid logical cells clear the
backend buffer. These checks supply protocol bytes, not a live session proof.

Independent MySQL backend fixtures cover all six scalar fields in text/binary
rows, NULL bitmap offset two, UTF-8 collation 309, binary metadata, full uint64
counts, prepare replies, EOF/OK, errors and full-auth negotiation. Handshake units
reject truncated/changed TLS negotiation, nonzero reserved bytes, unsupported
capabilities and trailing password bytes. The combined
`just test::sql-wire-contracts` passes these fixtures and all three package suites.

These are library-level checks, registered in ordinary core CI. They do not
qualify an authenticated listener, session resource enforcement or durable write
recovery. The complete native `just test::unit` also passes after replacing two
stale inline signed-request digests and preserving shared Python dependencies in
the SQL-wire development shell. Later gateway results are recorded above; this primitive checkpoint alone does
not establish gateway or clean-suite completion.

The full `just check` passes after the nullable-predicate browser validator is
updated; its focused TypeScript package has 35 passing tests. Saved-step codec
checks preserve the existing Table client's canonical signed JSON byte for byte,
verify signatures and reject truncation/foreign definitions/tampering. A private
Station-turn fixture checks 1301-byte publication across discarded turns, exact
retries after lost replies, conflicting parts, committed-only visibility and
current read denial. This fixture models atomic turns; it is not disk durability,
native fencing or gateway recovery evidence.

The ledger model tests also pass nonce recovery after a lost begin reply, staged
intent admission, one active sequence owner, stale-generation rejection, a
sequence-conflicting unpublished step, explicit abandoned-step collection,
committed-only pending dispatch evidence, retained receipt/processed/terminal
facts, operator/coordinator role separation, local pre-dispatch cancellation,
quota reservation/release and 27-item paged discovery. Independent Python bytes
check full-width quota and outcome counters. These tests use an atomic in-memory
turn fixture; real disk, signed control transport and host replacement remain
separate required proofs.

The subsequent `just test::sql-gateway` run passes the
[native coordinator schedule](../../../tests/interfaces/sql/sql_gateway_native.py) in 31.102 seconds: 31 retained
operations, 191 owner turns and 185 native sends, on disk-backed Ursula with eight
resident pages. Lost ingress and Table receipts replay the identical signed bytes
and recover the original receipt. The schedule kills both authority and storage,
replaces the ledger owner three times, records old-generation rejection through
the new owner, abandons/collects an interrupted unpublished step and resumes a
published step after dispatch without a recorded receipt. CREATE and three-row
INSERT complete once; an unchanged UPDATE retains matched=1, changed=0. Four
inventory pages preserve nonce discovery and terminal history while the separate
scheduling indexes are empty. Inspection issues no sends; all observed turns
remain within four mutations and 256-byte values.

The shared `Statement` integration repeats this schedule in 32.956 seconds with
the same operation/turn/send counts. It prepares and binds actual CREATE/DML
intents, then reads through PostgreSQL `$n` and MySQL backtick/`?` syntax, including
a NULL comparison and a MySQL self-join/grouped SUM. Preparing and reading adds
no native sends. Fuze unit checks independently compare dialect plan fingerprints
and exercise quoted CREATE names and rejected DDL/relational parameters.

The live `AccountRuntime` extension passes in 37.772 seconds with 33 retained
operations, 214 owner turns and 208 sends. The worker, coordinator, Table worker
and ingress caller run concurrently. A delayed accepted ingress reply is cut off
by cancelling the caller task; the account retains the exact signed request,
recovers its original receipt and completes a subsequent SQL UPDATE. The detached
reservation remains discoverable and is explicitly cancelled afterward. Two
downstream replies encounter joined/cancelled sockets; those are recorded
separately from upstream failures. The initial concurrent run exposed a stale
ledger-read race, corrected by reacquiring exact-current reads without replacing
pending commands. The next run completed the SQL operation but failed because
the proxy counted cancellation's broken response sockets as upstream failures;
the corrected classification and full schedule pass.

This proof exercises the library coordinator and native GenServer adapter through
a dedicated harness. It does not qualify a deployed database listener, concurrent
wire sessions, account credential rotation, slow sockets or placement lifecycle.
Those matrices remain open. Initial runs found a CREATE-only identity incorrectly
supplied to INSERT by the harness; the corrected, complete schedule passes.

## Catalog Table parameters

On 2026-10-13, the shared SQL-wire implementation adds caller-owned
`TablePrepared`, `TablePreparedDml` and nullable logical bindings. Fuze and query
package unit suites pass, including allocation-failure ownership, quoted/comment
placeholder handling, defaults versus NULL, NULL LIMIT/non-null constraints,
exact uint64, predicate unknown truth and all five vector lane states.

`zig build test-typed-tables -Doptimize=ReleaseSafe` passes in 251.621 seconds
through disk Ursula, signed native clients and real catalog/Station hosts. The
[prepared lifetime schedule](https://github.com/spoke-sh/transit/blob/b861597c460896f0bfb7d8568f95ce549e94f38e/tests/table_parameters_native.py) keeps the same Zig
objects alive across data changes, read denial/restoration, ALTER and
DROP/recreate. Preparation and binding issue no native sends; execution observes
new data cuts. DML returns an owned intent for the existing exact-send recovery
path. The complete existing lifecycle schedule also passes; its largest observed
turn has four mutations and values remain at most 256 bytes. This run is not a
wire-driver or gateway-ledger qualification.

The native definition is
`138bd4043de660b50db60d909ab7e29c3d1ab64b1b0658a8a8e000fd15d72365`,
SHA-256 of `transit.native.v1.sql-wire-parameters.2026-10-13`. FQP1 replaces its
codec definition for nullable comparison atoms. Shared schemas, language binding
resources, independent plan fixtures and native/SDK signing vectors migrate
together. Historical execution records retain their original definitions.
Earlier compilation failures from missing exhaustive cases and new test setup
were corrected before these passes; full clean qualification remains pending.

## SQL parameter integration with Boolean main — 2026-10-01

The SQL stack rebases onto main `fe2fbd81` through the combined COUNT branch
`95730437`. Conflict resolution preserves Boolean postfix programs, owned AST
lowering, file aliases, value-count progress and both SDK interfaces. The combined
native definition is `e412a074bf01f92cb62c7953051930d81a78cc1a0f45472b7eff17d9931f8633`;
the FZP1 definition is `772db79a4ed16fff507c2b5ea28580a266ee2552548329e7107842c90413a88c`.
Schemas, binding resources and independent signing/plan fixtures are regenerated.
Tests reject both earlier Boolean-only and value-count-only definitions.

Pinned Fuze, protocol and query package tests pass after integration. Full
`just check` passes at parameter revision `8ed8f52f`; the later move onto
`95730437` changes only inherited qualification documents and retained results.
Additional `just test::sql` cases combine value counts, Boolean truth, output and
derived-input aliases, input LIMIT and eager predicate errors across all three
sources and eight page widths. The independent suite passes 174 ASTs, 142 plan
cases, 72 query results and 27 query exclusions. Parameter checks pass 37 reference
ASTs, 26 canonical plan/Arrow results and 20 exact rejections. Log:
`/var/tmp/transit-sql-main-495-combined-regressions-fixed.log`.

The template grammar still admits one comparison or state test. Compound
parameter templates reject before binding, while ordinary SQL retains Boolean
composition. The first added corpus run failed because a literal-only rejection
case was incorrectly marked as containing placeholders; the fixture now records
`has_parameters: false`, keeping ordinary Boolean acceptance and template rejection
separate. No parser behavior or limit was weakened to satisfy that check.

These checks do not qualify every clean lane, the remaining performance budgets,
named prepared-statement lifetimes or continuous SQL. Earlier source-qualified
failures and measurements below retain their original scope.

## Typed parameter compiler foundation

The `feat/sql-query-parameters` continuation starts from `fbb4ebc9` in its own
worktree. It compiles typed comparison/LIMIT parameters through the shared
parser and lowering. Templates and bound plans own their data independently;
ordinary lowering rejects unresolved placeholders. Existing plan/native bytes
and definitions are unchanged. Resource identity, installed callers, named
PREPARE/EXECUTE and persistence remain separate work.

On this working source, pinned Fuze package tests pass, including every
allocation failure during preparation/binding, released-input/template lifetime,
all six scalar types, repeated/gapped ordinals, mismatched schema/name and exact
value bounds. The first build failed on a removed Zig reflection API; replacing
it with the pinned `std.meta.fieldNames` fixes compilation. Logs:
`/var/tmp/transit-sql-parameters-component.log` and
`/var/tmp/transit-sql-parameters-component-fixed.log`.

`just test::sql` passes the ordinary 157 AST / 125 plan-and-Arrow cases,
57 unified results across three source bases/eight widths, mutation and
declaration proofs. The new shared 44-case parameter corpus independently checks
37 reference ASTs, 26 canonical bound plans and actual paged Arrow results, plus
18 exact parse/binding rejections. The reference binds an independently parsed
AST, never substituted SQL text. Parameter values use the existing neutral
scalar decoder. Log: `/var/tmp/transit-sql-parameters-independent.log`.
These are compiler/component results; full checks, performance, committed-HEAD
clean qualification and public caller integration remain pending.

The subsequent query layer adds exact definition binding and owned source paths
to `SqlTemplate`; `UnifiedClient.prepareSql`/`bindSql` use the same current
description boundary before and after their work. All 69 query package tests
pass, including three new tests covering KV/Table/Document identity changes,
canonical literal-bundle equality, independent path/value ownership and every
allocation failure, revocation at either observation and budget reduction. A
read-only fake exposes no submission method. This is component authority-order
evidence, not a signed transport or installed-caller proof. The first run passed
68/69 and failed because the test's source factory returned a runtime-created
borrowed path; static fixture storage fixes that lifetime. Logs:
`/var/tmp/transit-sql-parameters-source-binding.log` and
`/var/tmp/transit-sql-parameters-source-binding-fixed.log`.

After the Document revision/path cases are extended, package tests and all 4944
documentation links pass; log
`/var/tmp/transit-sql-parameters-source-binding-final.log`. At clean committed
`9412e439`, the ReleaseSafe
[parameter measurements](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/benchmarks/results/2026-10-01-sql-parameters.json.gz)
retain nine CPU-1 samples, exact binaries/drivers/source patch and canonical
plan checks. Across six scalar types, literal compilation medians are
1032–1186 ns, preparation 1295–1367 ns, and subsequent binding 386–417 ns.
Preparation is excluded from the binding interval. These are pure Fuze costs,
not full source-definition/authorization or public query latency.

The alternating frozen `fbb4ebc9` control compares the unchanged thirteen
compiler/mutation/declaration/aggregate cases. All ratios meet the existing
1.15 budget, ranging from 0.9932 to 1.0798; samples and overlapping ranges remain
in the archive. Neither this shared-host observation nor reuse of ordinary plan
bytes establishes a full file or installed-caller performance pass. Logs:
`/var/tmp/transit-sql-parameters-costs.log` and
`/var/tmp/transit-sql-parameters-unchanged-control.log`.

Full `just check` at `731bf348` passes native/unit/generated-contract, CLI and
Board checks, then fails the handbook navigation inventory because the new
parameter reference is absent from `catalog.ts` (six of seven content tests
pass). Adding its SQL navigation entry corrects that omission. The failed run
remains recorded at `/var/tmp/transit-sql-parameters-check.log`; the final
full-check and committed-HEAD clean results are tracked separately in the PR.

## M12 declarative interface readiness

`just test::sql` regenerates the ANTLR reference parser and runs the pinned
pglast/libpg_query differential corpus, then invokes the actual Zig public-package
consumer in [sql_driver.zig](../../../tests/query/sql/sql_driver.zig). All 103 admitted SELECT statements
must have identical normalized ASTs across the three parsers. Fourteen are
unchanged PostgreSQL REL_17_5 regression statements; source provenance, hashes,
license and exact exclusions live in [the grammar contract](../../../contracts/sql/README.md).
Seventeen syntax exclusions and thirteen grammar-only administrative forms must
be rejected by the production parser. Twelve admitted SELECTs deliberately fail
schema/type/limit compilation; the other 91 compile to independently checked
`FZP1` bytes and execute through `Stream.step` over 70 rows in seven-row pages.
Plan and progress round trips precede continued execution. PyArrow independently
checks original result segments, column order, nulls and exact values against a
Python result oracle. Omitted limits must not truncate at 32 rows.

The SQL unit suite (ordinary `just check`, or standalone `zig build test` in
`packages/zig/transit-fuze`) covers manually constructed plan equivalence,
AST ownership after text destruction, invalid encodings/names, statement/literal/
comment bounds, integer extrema, trailing input, and 2,000 seeded arbitrary or
mutated statements. Actual compiled sum plans retain cross-page overflow,
source-revision fencing and cancellation; a limited input excludes later
row overflow. Tests do not claim unbounded fuzz coverage.

`just test::sql-grammar` is the focused reference-only check. Ordinary bindings CI
owns `test::sql` and `test::sql-rewrites`; generation always reruns, and a cache
hit cannot substitute old trees. The optional tools come from existing Nix pins.
No PostgreSQL server or ANTLR/Lean runtime enters Fuze. These local proof commands
are executable evidence; a hosted timing measurement for the expanded lane is
still deferred, as it was for M11.

This qualifies parsing → typed plan → bounded paged Arrow execution, not a
network query service or SQL DDL/writes. Current authorization, durable Station
publication, recovery and foreign SDK behavior retain their existing owners and
proofs. The parser does not change those boundaries. The Lean model's separate
assumptions and evidence are recorded in the grammar contract.

`just test::sql-rewrites` checks four complete Lean theorems. Filter reordering
and projection pruning print only `propext`; predicate pushdown with first-error
preservation and its downstream-consumer corollary print no axioms. The runner
requires all four names and rejects warnings, incomplete proofs and unexpected
axioms. This is specification evidence with explicit correspondence assumptions,
not implementation refinement or an enabled optimizer. False/generalized limit
and sum rewrites remain excluded, with reasons in the model.

## SQL reference operation coverage

The SQL reference now indexes unsupported INSERT/UPDATE/DELETE operations and
separates types, functions/operators and streaming/effect boundaries. The
[SQL and dataflows](../../roadmap/11-sql-and-dataflows.md) records proposed contracts and proof
gates; it does not establish executable mutation or continuous SQL support.

Working-tree validation with the pinned Nix development shell:

- `just check` passes, including native/contract/unit checks, 174 CLI diagnostic
  cases, frontend checks and the production documentation build. The site runs
  six ownership/content checks and validates its published links and anchors.
- `just test::sql-grammar` passes: 37 public SQL examples parse, all statement
  rules and the historical fragment are covered, 103 SELECT ASTs agree with
  libpg_query, 17 syntax exclusions and 13 administrative examples pass, and
  ANTLR reports zero diagnostics. This establishes syntax coverage only.

No grammar, compiler or runtime behavior changes in this revision. These checks
do not qualify any proposed mutation, maintained-query or effect-binding profile.

## Neutral SQL parameter callers — 2026-10-01

`SqlCompilation` provides one current-authority operation for native/port
`Bridge.compile` and configured `Workspace.compile`. Shared fixtures exercise
all six exact scalar encodings, maximum integers, negative zero, binary bytes,
SQL-looking UTF-8 values, ordinary/empty bindings, input aggregation and Document
paths. Returned bundles and metadata are independent of request/template owners.
The read-only test client has no dispatch interface; denial, source replacement
and budget reductions at either observation return no candidate. Exhaustive
allocation-failure schedules cover released inputs and output conversion.
The query package passes **73/73 tests**. The initial 72/73 result had an incorrect
expected test error (`InvalidQueryInteger` versus the existing shared codec's
`InvalidDocumentInteger`); correcting that expectation preserves the codec.
Logs: `/var/tmp/transit-sql-parameter-callers-query{,-fixed}.log`.

Generated ABI, port, workspace, Board and binding resources follow the Zig
owners. The separate `sql_capabilities` action preserves every previous native
and workspace response variant, including the original capability object.
An exact schema comparison against `2e45f6bf` verifies unchanged ABI definition,
function signatures, configuration schemas and all pre-existing action/result
variants, accounting for the port's nested `unified_query` union. Workspace
request reflection now uses input defaults, so ordinary `{compile:{sql}}`
requests remain valid. JSON Schema probes reject numeric wide-integer bindings,
ambiguous scalar variants and null scalar values. The initial full check caught
request fields incorrectly reflected as required outputs; corrected reflection
passes generated boundary and frontend validation. No stored/native definition
or bundle format is changed.

Full `just check` and independent `just test::sql` pass at `1b92acd9`, including
59 documentation examples, 157 ordinary ASTs, 125 plan/Arrow cases and the 44-case
parameter corpus. Log `/var/tmp/transit-sql-parameter-callers-final-check.log`.
The later Board error-mapping correction returns bad requests for invalid
parameter ordinals/counts/types; its real HTTP proof passes through
`just transit-board::query-test`, including exact equality with literal bundles,
full-width values, no command-sequence allocation, upload/result verification
and revocation. Log `/var/tmp/transit-sql-parameter-callers-board-fixed.log`.
The earlier nonexistent `test::board-query` recipe executed no proof. Full
`just check` also passes after this correction at `943c4d78`; log
`/var/tmp/transit-sql-parameter-callers-submission-check.log`.

The signed native ABI/port and actual SQL-shell KV schedule passes at `1b92acd9`
in 77.63 s, with 41 rows/six segments, lost upload response, exact original retry,
worker/node/disk-store restart, current prefix denial and permanent retirement.
The parameter compiler's bundle equals the separately constructed Zig plan;
that returned bundle becomes the recovery schedule's input. Invalid bindings
and compilation after revocation/retirement reject without dispatch. Log
`/var/tmp/transit-sql-parameter-callers-final-native-kv.log`. A preceding working-tree
prototype also passed KV/Table/Document, but its capability envelope differs;
current Table/Document repetitions are separate qualification, not inherited
passes. The initial log is `/var/tmp/transit-sql-parameter-callers-native.log`;
current remaining-source log is
`/var/tmp/transit-sql-parameter-callers-final-native-remaining.log`.

The neutral caller performance archive (archived)
retains nine CPU-1 ReleaseSafe samples at clean `1b92acd9`, exact source/driver
bytes and patch, commands and frozen binary hashes. One-shot parameter medians
are **6732–6851 ns**, including template preparation, source/scalar conversion,
binding, canonical encoding and owned neutral result conversion. Equivalent
literal requests through the same owner cost **4156–4372 ns**. Both execute two
stub description checks per iteration; these numbers exclude real authorization
I/O, signing, transport and query admission. Reusable compiler binding remains
a different measurement in the preceding section. The unchanged thirteen-case
workload passes every existing 1.15 regression gate against frozen `9412e439`:
ratios **0.8615–1.0183**. Shared-host variations are retained and are not claimed
as an optimization. Probe timeouts, runtime budgets and quotas are unchanged.

Language convenience methods, CLI binding inputs, named PREPARE/EXECUTE lifetime,
file-source parameters and installed all-language recovery remain unfinished.
This checkpoint does not close the parameter family or issue #37.

The subsequent Table repetition passes in **73.20 s**, with 41 rows/six
segments. Document fails during provisioning with `AuthorityUnavailable`,
before parameter compilation/execution. The same fixture logs record native
MinIO `507 XMinioStorageFull` and Ursula cold-store backpressure; this is not a
Document parameter pass. The preceding remaining-source log retains the failure.
No quota, deadline or storage threshold is increased.

Committed-HEAD `just ci-clean --lane core --work-root /var/tmp` passes all
**22 tasks in 693.03 s** at `945bd68c`. Completion and task evidence are
`.cache/ci/clean/945bd68cbb4f-transit-ci-68l1v0ai/core{,.meta}.json`; log
`/var/tmp/transit-sql-parameter-callers-clean-core.log`. This proves that revision's
core lane only, not the other four ordinary lanes or a later rebase.

The four-PR stack (#63–#66) is rebased onto `21e9569c` from `origin/main`.
All 42 commits retain their author dates as committer dates. No conflicts occur;
range comparison finds only an already-merged TypeScript documentation-formatting
hunk disappearing from the COUNT commit. Main's bounded Board capacity-read
recovery, exact frozen-request recovery tests, delivery batching and failed
cold-store fixture retention remain integrated. Post-rebase validation is recorded
in the PR and issue handoff separately from these earlier results. Unfinished
SDK convenience methods are preserved in the separate `feat/sql-parameter-sdk`
worktree and are not part of #66's submitted shared-compilation scope.

The first post-rebase Board proof fails to build: main's new exhaustive
read-retry switch lacks `sql_capabilities`. Classifying this local read-only
operation explicitly resolves the integration error without a fallback arm.
The real HTTP fixture also injects two native capacity refusals during parameter
compilation, disables the fixture's outer retry and requires the identical bundle
with no command-sequence allocation. This uses main's existing attempt/deadline
bounds. The failed build is retained in
`/var/tmp/transit-sql-parameter-callers-rebase-recovery.log`; subsequent executions
are separate evidence.
The first injection control incorrectly selected `resource`; compilation uses
the shared `read_entries` batch operation. The fixture rejected the unreached
fault instead of reporting a pass. The corrected control targets `read_entries`;
the failed run remains in the corresponding `rebase-recovery-fixed.log`.

## Typed configuration and SQL settings

The configuration-v1 implementation separates immutable installation/artifact
identity from active and configured generations. Its public owners are the
[configuration reference](../../handbook/reference/configuration.md),
[SQL reference](../../handbook/reference/sql/settings.md) and
[wire contract](../../../contracts/CONFIGURATION_V1.md). Tests use disposable directories;
the developer's installation is not a fixture.

During the 2026-10-16 implementation on `feat/sql-configuration`, the pinned
`nix develop` environment ran these checks successfully:

- `just doctor`, locked `just transit-board::install`, configuration/query package
  tests, native authorization/core tests, and CLI lifecycle tests. The lifecycle
  suite includes a real optional source becoming present, file removal rejection,
  atomic replacement, key deletion and captured environment precedence.
- `just test::cli-diagnostics`: **594 real command cases**. Input diagnostics
  preserve private values and source locations without stdout contamination.
- `just test::sql-grammar`: **174 finite SELECT AST comparisons**, **32 syntax
  exclusions**, **24 extensions**, **33 relational AST comparisons** and
  **113 public SQL examples**, with zero ANTLR generation diagnostics.
- `just test::diagnostic-grammar`: **434 compiler cases** covering **633 parser
  rule/alternative/boundary obligations**, including standalone-only reload,
  immutable session settings, invalid units and bounded history ordering.
- `just test::diagnostic-outcomes`: **3,384 projections** across **29 declared
  outcome surfaces**. The native error vocabulary and independent expected
  mappings changed together.
- `just check`: generated contracts/fixtures, source inventories, Nix checks,
  Zig unit checks, CLI/history diagnostics, frontend checks and public site build.
  The site includes configuration and settings SQL in navigation and search.

The installed server's new configuration subproof passed SQL metadata/filtering,
YAML coordinates, real Host-policy changes, session limits, pending restart and
normal restart application, immutable/artifact rejection, expected-generation
races, tampered signature rejection and same-operation retry after file edits.
It also reconstructs the exact checkpoint state between acceptance and history
indexing, removes the two indexes, and verifies idempotent repair. This is an
explicit modeled crash point; it is not arbitrary filesystem power-loss evidence.

Initial broader runs exposed an empty SQL command-result schema, a missing
readable directory descriptor for recovery fsync, and completed reload records
shadowing later Table recovery controls. Those defects were corrected. A later
server run encountered a concurrent native `StaleStateResource` during a pure
Table status read; status now uses bounded read-only retry without resubmitting
accepted work. The broader server and TLS database-wire runs and committed-HEAD
clean qualification are recorded separately below when complete. Their earlier
failed runs do not count as passes.

Reproduction commands are `just test::server` and `just test::sql-wire-gateway`.
For focused adapter diagnosis, use
`nix develop .#sql-wire --command zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- settings`.
The focused `-- lifecycle` slice adds socket/account capacity, reserved cancellation
and bounded shutdown to the settings proof.
The full task also exercises pinned PostgreSQL/MySQL command-line clients,
independent drivers, revocation, prepared execution, account recovery and TLS.
Configuration tests add no user-facing commands or flags. Metadata work is
bounded by page and sort limits; these checks establish no latency or throughput
guarantee and do not qualify distributed configuration rollout.

Subsequent qualification passes `just check`, the installed
`just test::server` lifecycle in **85.78 seconds**, and `just test::server-faults`
with its repeated core lifecycle in **88.23 seconds** and bootstrap/gateway/
rollback faults in **46.19 seconds**. The fault proof uses current native domain
grants and exact signed retries; it checks permitted Host-policy changes on
restart without replacing installation identity or grants. Automatic child
restart exposed and now covers the retained endpoint's process-arena lifetime.

The focused TLS settings adapter proof passes PostgreSQL/MySQL SHOW, SET/RESET,
prepared reload, session default/ceiling isolation, bounded statement deadlines,
metadata and reload revocation. It includes the corrected text-cell encoding:
owned text and hexadecimal operation IDs are SQL text without JSON quotes.
A broader driver run encountered MinIO `XMinioStorageFull` on an existing Table
update when the host crossed its free-drive threshold. That run remains failed;
the rerun retains disk-backed fixtures and unchanged storage safety limits.

`just test::server-applications` passes the real installation/replacement profile
in **971.46 seconds** (19 rows/steps, 21 receipts, generation 9; maximum manager
RSS 43,335,680 bytes and checkpoint 3,056 bytes). `just test::server-board` passes
defaults/toggles, embedded assets, replacement, revocation and owned failures in
**43.96 seconds**, plus exact Board bootstrap recovery after lost replies and
manager death. These are local functional observations, not performance bounds.

Final recovery review adds a missing-checkpoint refusal before child startup,
records installation completion after first settings publication, and requires
the persisted completion field. The installed proof also checks that refusal
leaves installation/history bytes unchanged and that restoring the checkpoint
retains reload history. The preceding clean run was interrupted to qualify this
change; partial results are not a completed clean qualification.

The final installed lifecycle passes in **116.84 seconds**, including the retained
checkpoint/completion-field refusal, and `just check` passes on that implementation.
A broader wire attempt passes the independent CLI/C clients, settings, authority,
failure schedules, schema invalidation and exact recovery of a 40 KiB mutation
in **3,560.366 seconds** within its unchanged 3,600-second observation bound.
It then fails at the final capacity test; the enclosing task is not a pass.
A fresh diagnostic reproduces libpq leaving OpenSSL error `0A000197` in the
Python caller thread after an expected rejected login. Isolating those negative
clients on a joined worker thread passes the unchanged capacity/cancellation
checks. This changes test-client ownership, not gateway limits or TLS behavior.

The committed-source configuration qualification record (archived)
accounts for **all 88 ordinary recipes**: 28 core, 32 growth, seven experience,
two launcher and 19 bindings recipes. Runtime source is `9dffe9e4`; the SQL
compiler/final fault scope uses `ac9d1db3`, whose only change is the compiler
proof harness. Every result retains its actual revision. Each canonical recipe
passes from a committed-source clean checkout. Complete lanes and complete task
scopes supply this coverage; the earlier failed/interrupted enclosing runs remain
incomplete. This is not one uninterrupted all-lanes invocation or a hosted timing
qualification. The record retains per-task revisions/results, six-lane coverage,
toolchain and log digests, continuation drivers, failure history and scope limits.
The [public SDK interoperability record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/configuration-clean-2026-10-17/sdk-interop.json)
retains the ten installed counter/query pairs, exact recovery, queued Tables and
owned IPC observations separately from artifact builds and other failure suites.

At the runtime revision, `just check` passes with **595 real CLI diagnostic cases**, and
the installed server lifecycle passes in **88.61 seconds**. The complete wire task
passes: its main TLS/driver/authority/recovery/schema/capacity/drain fixture takes
**6,410.701 seconds**, followed by a separate fresh-fixture `psql`/Oracle `mysql`
CLI lifecycle in **333.58 seconds**. The original 40 KiB mutation completes in
**3,494.134 seconds** within its unchanged 3,600-second bound, with **one SQL
attempt** and verified applied counts. These are functional observations, not
latency or throughput guarantees.

The final resolver correction reserves the exact existing build/launcher
`TRANSIT_` controls; unknown setting names still fail. An earlier clean startup
rejected Nix's build controls, and the installed diagnostic suite now covers
that case. The full corrected wire run also qualifies the rejected-login TLS
thread isolation described above.

The first final SQL compiler proof also fails: its harness assumes every
extension returns the initial `UnsupportedStatement` error. Configuration
SELECT forms enter the finite-query grammar and reject later; the test-only
correction asserts the exact `InvalidColumnName`/`UnsupportedConstruct` errors.
The complete compiler proof and remaining fault recipes pass from that commit.
No runtime parser or administration boundary changes for this correction.

An overlapping SDK batch exceeded the existing public-query fixture deadline in
Node, C++, Java and .NET; an initial Ruby setup exceeded its one-second authority
wait. Those attempts remain failed. Complete canonical recipes then pass on fresh
fixtures at bounded lower concurrency, without increasing deadlines. Interrupted
Rust/Ruby/BEAM runs are retained separately from their successful retries. The
remaining growth/experience scope starts after the deadline-sensitive SDK phases,
with at most two proof runs active; the shared/model tail follows SDK completion.

Hosted run `39014578659` executes no job steps: GitHub reports failed account
payments or a spending-limit restriction. No hosted pass or ordinary-suite time
budget is claimed. The separate browser lane is outside this 88-recipe inventory.

## Configured local SQL access — 2026-10-17

The local SQL qualification record (archived)
records the current-v1 definition, source and installed artifact hashes, actual
per-task revisions, log digests and scope. Shared runtime/protocol/SDK source is
unchanged from `ca90c312`; `51ad5c65` only supplies the gateway executable to an
isolated configuration fixture. The final local supervisor is `12c7ba3d`, which
moves temporary account paths into the existing per-tick arena so unavailable
activation reads cannot accumulate them for the server cycle's lifetime. Its
source/installed SQL workflows, setup faults, repository checks and clean
launcher/experience lanes are rerun. Earlier core/application regression
observations use `4e141752`, before these SQL-only allocation corrections; their
exact scope remains distinct from final-runtime SQL checks.

`just check` passes, including **605 actual CLI diagnostic cases**. The complete
source SQL workflow passes in **329.869 seconds**. The Nix local bundle is built
and tested outside the checkout using adjacent executable discovery and pinned
`psql`/Oracle `mysql`; that installed workflow passes in **354.678 seconds**.
The clean experience lane separately executes the source workflow in **278.718
seconds**. These tests use disk-backed Ursula and real TLS-verifying clients.

The workflow starts with no configured listener and verifies no SQL process or
enrollment. It enables both protocols on the compatible installation, explicitly
applies owner/writer/reader role and credential proposals, checks denied data
access before grants, then performs shared Unicode/NULL CRUD. It covers
PostgreSQL-only and MySQL-only exposure, retained rows, current-generation
fencing, revocation across restart, disabled accounts, password rotation,
expired trust and explicit replacement trust. For a lost write response it
observes an accepted, nonterminal operation, kills the client and manager,
removes that account and disables both listeners with unavailable PEM paths.
Public controls observe the original operation become applied; re-enabling SQL
verifies exactly one resulting row. The SQL mutation is never resubmitted.

The installed setup-fault proof passes in **37.154 seconds**. It loses accepted
root-allocation and initialization replies, kills the manager, and checks exact
request/identity recovery. Occupied-port preflight leaves enrollment unchanged;
releasing the port permits setup. Revoking worker authority leaves SQL
unavailable and core administration usable; restart does not restore the grant.
The proof observes installation records without editing private authority.

Existing local-server fault coverage passes with its core lifecycle in **85.24
seconds** and bootstrap/gateway/rollback cases in **45.80 seconds**. The real
application lifecycle passes in **994.076 seconds** (19 rows/steps, 21 receipts,
generation 9; maximum observed manager RSS 47,955,968 bytes, checkpoint 3,051
bytes). Application fault coverage passes in **153.78 seconds**, including saved
receipts, lost replies, native fencing, revocation and capacity observations
without replacing healthy owners. The application fault peer preserves native
control/wait admission headers and retains the original 40-second observation
budget. These earlier-runtime observations do not substitute for final-runtime
SQL qualification.

All **89 ordinary recipes** pass through committed-source
`just ci-clean --lane` invocations: 28 core, 32 growth, eight experience, two launcher and 19
bindings recipes. Every canonical recipe and deadline is retained. Core and
bindings-2 use `ca90c312`; growth and bindings-1 use `51ad5c65`; launchers and
experience use `12c7ba3d`. The final supervisor change only moves temporary
account paths into the per-tick arena; its source/installed SQL workflows and
setup faults are rerun, and shared protocol/runtime/SDK sources are unchanged.
This composes six complete lane results with exact revisions; it is
not one uninterrupted all-lanes invocation or a hosted timing qualification.

The complete wire recipe passes with its main driver/authority/recovery fixture
in **5,617.809 seconds** and a separate fresh-fixture `psql`/Oracle `mysql`
lifecycle in **256.782 seconds**. It retains its original 40 KiB mutation and
3,600-second observation bound. That operation completes in **3,354.186 seconds**, with **one
SQL attempt** and verified applied counts after the client wait ends. The final
record retains the independent client, authority, fault, schema and capacity
profiles separately from these local timing observations.

Qualification exposed test fixture drift: the independent SQL record generator
still named the preceding definition, and the isolated configuration fixture
omitted the now-required gateway artifact. Those enclosing attempts failed;
the generator and fixture are corrected, and their complete owning recipes are
rerun. An application fault peer dropped control/wait admission headers, causing
ordinary request-capacity exhaustion; preserving those headers passes the
original deadlines. Receipt-first recovery is checked against the original
accepted body and receipt, without requiring an already-receipted operation to
be sent again. Failed and interrupted runs remain distinct from passing evidence.

The executed placement is trusted local Linux x86_64 with the existing autocommit
SQL/type profile. These are functional and recovery observations, not latency or
throughput guarantees. They do not establish remote exposure, general ORM or
transaction compatibility, arbitrary power-loss durability, distributed
activation or hosted CI timing. The separate browser lane is outside this
ordinary-suite inventory.

## Local SQL authentication — 2026-10-18

The local authentication qualification record (archived)
retains the shared definition, artifact/log digests, exact revisions and scope.
Runtime source is unchanged from `047c2fa7`. Source proofs and the clean
experience lane use `74c6d400`; `2b0b334d` adds only the installed bundle option
to the new harness, preserving its default source scenarios. The
[local SQL guide](../../../apps/transit-cli/docs/sql.md) owns the runnable configuration.

`just check` passes, including **613 real CLI diagnostic cases**. Focused
`just test::sql-wire-contracts`, `just test::server-sql-local`,
`just test::server-sql` and `just test::server-sql-faults` pass. The Nix local
bundle builds and passes `python3 -B tests/server_sql_local.py --bundle
.cache/transit-local-auth-package` in the pinned development shell. Its main
workflow runs outside the checkout without executable overrides, exercising
adjacent discovery; the interruption fixture uses the bundled artifacts through
its owned fault peer.

The new workflow exercises the documented YAML at first initialization,
empty-account preflight, automatic original-owner binding, plaintext trust with
real `psql` and Oracle `mysql`, shared Unicode/NULL CRUD and settings inspection.
It checks optional and required TLS, verified TLS, PostgreSQL SCRAM on either
transport, MySQL password rejection before plaintext exchange, unknown logins and
wrong passwords. Native credential revocation remains effective across restart;
the completed owner-binding receipt and account identities remain unchanged.
A separate fixture loses an accepted owner-binding publish response, kills the
manager, and verifies recovery of the exact saved request and usable login.

The existing TLS/password workflow still checks manual enrollment, data grants,
protocol toggles, rotation, expired trust and recovery of accepted work with both
listeners disabled. Setup faults retain exact root-allocation/initialization
recovery, occupied-port preflight and denial after worker revocation. An initial
new-client attempt rejected Oracle MySQL's single-NUL empty password response;
the corrected parser and negative proof cases pass the complete rerun. Earlier
failed attempts are not counted as passing evidence.

`just ci-clean --lane experience` passes **all nine experience recipes** from
committed source without inherited build outputs: frontend/docs checks,
TypeScript bindings, observability, both SQL workflows, Board inspection/query
checks and the local Station launcher. Canonical recipes and deadlines are
unchanged. Other ordinary lanes and the separate browser lane were not rerun;
this is scoped local Linux x86_64 qualification, not a whole-suite or hosted CI
claim. Functional durations do not establish latency or throughput guarantees.
The tests use isolated disk-backed installations; the user's YAML and data are
unchanged.

## Default SQL gateway installation — 2026-10-18

The local build investigation found that the default install target refreshed
the CLI, node, query host and Board but omitted the SQL gateway. An existing
`zig-out/bin/transit-sql-gateway` retained the preceding definition and rejected
the current initializer configuration with `InvalidEnumTag`. The supervisor
reported `GatewayOwnerUnavailable` and left the configured PostgreSQL port closed.
The earlier direct-artifact and Nix-bundle proofs did not exercise this default
source-installation dependency.

`df810cf4` adds the gateway to the default and `apps` install targets.
`just test::server-sql-local` now depends on the default installation and runs
its binaries under `.cache/transit-sql-local` through `--source-install`.
Transit dependencies use adjacent discovery; MinIO and Ursula retain explicit
provider paths from the development shell. The separate `--bundle` proof still
requires adjacent provider discovery as well. This distinguishes source builds
from the complete Nix bundle without weakening either workflow's checks.

The revised real-client workflow passes: first initialization, trust without TLS,
shared Unicode/NULL CRUD, optional/required TLS, PostgreSQL SCRAM, MySQL password
transport enforcement, current revocation and exact owner-binding recovery after
reply loss and manager SIGKILL. `just check` passes with 613 CLI diagnostic cases.
The default debug build also passes a real `psql` connection and `SELECT 1` on
port 5434 after the operator explicitly requests deletion and fresh initialization
of the mixed-binary installation. No stored definition or runtime code changes
are required for this build correction; retained executable identity checks remain.
The separate `apps` debug build installs the SQL gateway with the current
definition into an independent prefix as well.

At PR submission, `just ci-clean --lane experience` is running against committed
`df810cf4`. Its first eight recipes pass, including both SQL workflows, Board
inspection and Board query recovery. The local Station launcher is in progress.
This partial lane is not a completed clean-checkout pass; the
other ordinary lanes and separate browser lane are outside this run's scope.

## Live storage engine and SQL execution cutover

Source-audit correction (2026-10-22): the installed executables do not attach
`TableStorageEngine` or the segment scan. `TableBehavior.attachStorageEngine`
and `TableScan.openSegmentReader` are not implemented APIs. The component
helpers and existing Ursula cache/gateway changes must be assessed separately.
The previously reported gateway timing below does not prove `.tseg` use, and
changes to cache/transport controls prevent attributing that comparison solely
to a storage engine replacement. Preserve the reported observation without
treating it as qualification of a live cutover. No new benchmark was run for
this correction.

Working-tree verification in the pinned Nix development shell exercises the live
catalog and query `.tseg` storage integration (`TableStorageEngine`,
`TableSegmentScan`), `PackedPageStore` candidate seal write-through, epoch-tracked
cross-lane page cache synchronization in `transit-node`, condition-variable
wakeups and multi-step turn draining in `AccountRuntime` / `transit-sql-gateway`,
and low-latency worker polling in `transit-cli` / `transit-query-host`:

- `zig build test` in `packages/zig/transit-backend-ursula` passes 11/11 unit
  tests, verifying that `PackedPageStore.finish` populates the resident page cache
  immediately upon candidate verification and seal (`misses == 0`, `hits == 1` on
  subsequent `load` without additional provider requests).
- `zig build test` in `packages/zig/transit-catalog` passes 88/88 unit tests,
  exercising `TableStorageEngine` WAL-backed `insertRow` / `deleteRow`, `.tseg`
  and `.tdel` flush + `TableManifest` conditional CAS publication, Tier 2
  `NvmeCache` byte-range population, $O(\log N)$ primary-key point lookups across
  flushed segments and active memtables, crash recovery from `TableManifest` +
  `LocalWal` replay, and disjoint-primary-key multi-writer OCC rebasing via
  `TableBehavior.attachStorageEngine`.
- `zig build test` and `zig build test-catalog-query` in
  `packages/zig/transit-query` pass 151/151 unit tests and the catalog-query suite,
  verifying `TableSegmentScan` Zone-Map + 64-bit Bloom-filter row-group pruning,
  `.tdel` deletion filtering, active `TableMemtable` delta merging, vectorized
  `Fuze` `Batch` (`nextBatch`) emission, and end-to-end `LogicalQuery.Execution`
  (`SELECT ... WHERE ... ORDER BY ...`) over `.tseg` segments.
- `zig build test-sql-gateway -Doptimize=ReleaseSafe` (`just test::sql-gateway`)
  passes the 33-operation, 217-turn `native_gateway_ledger` fault, recovery,
  fencing and pipelined-admission schedule in **55.770 seconds** (down from the
  **122.759-second** pre-cutover baseline on the same host, a **2.20x** wall-clock
  speedup).

## SQL admission and detached inspection revision races — 2026-10-25

The clean growth attempt at `0567c9841` fails at the runtime UPDATE in
`just test::sql-gateway` with `StaleStateResource`; an isolated unchanged rerun
passes. Diagnostic fault injection then reproduces two independent gaps:
the initial admission lookup propagates a stale-revision rejection, and, after
that path is repaired, the fixture's final detached-control inspection does too.
The natural failure does not identify which of those two reads lost its cut.

`AccountRuntime.admit` now retries only its initial pure lookup under the
original deadline, nonce and fingerprint. The final fixture inspection also
reopens only its read while the worker remains active. The shared retry
classification preserves denial, cancellation and conflicting-retry failures;
neither repair repeats SQL admission or changes accepted work.

The full focused schedule passes after both repairs. Its proxy injects one
stale-revision rejection into each lookup, and retains the existing delayed
detached reply, lost first upload receipt and successor-admission ordering.
The run completes 33 operations, three fenced replacements, exact replay of
all three lost control replies and direct outcome recovery without direct
re-execution. The UPDATE reports one matched and one changed row, its value is
read back, and the detached reservation is explicitly cancelled to abandonment.
The workload takes 26.014 seconds, excluding compilation. The runtime's
60-second deadline, native four-mutation/256-byte turn limits and existing
receipt assertions are unchanged. This focused pass does not complete the
remaining ordinary CI tasks.

## Direct Table SQL wire diagnostics and current authority — 2026-10-25

At `341365c62f8710e69c2949b792c3d991e420478f`, the fresh committed-source
`just test::sql-gateway` completes in 287.34 seconds, including compilation.
The following wire schedule fails because its revocation fixture inspects an
arbitrary old operation and assumes SELECT controls mutation receipts. The
direct Table owner instead checks CONNECT, USAGE and the original mutation
privilege. The corrected fixture identifies the exact detached INSERT, checks
its one matched/changed row, retains its receipt under SELECT revocation,
suppresses it under INSERT revocation, and recovers the same receipt after
restoration. Row and metadata disclosure remain denied without SELECT. These
assertions complete in the subsequent wire run, which then fails at schema
invalidation; neither invocation is a complete wire pass.

That failure exposes a diagnostic gap: the HTTP client returns a status-class
error while retaining the verified Table definition rejection separately.
The SQL adapter now maps that verified cause to the prepared-source diagnostic.
Ordinary current-state contention receives its own prerequisite-state diagnostic
while preserving any admitted operation identity. Neither classification retries
a write, retargets a prepared handle, or joins a new read to an earlier prefix.
Unit assertions cover both remote status classes, retained operation details,
denial precedence, unrelated failures and immediate stale-definition rejection.

The focused wire schema schedule subsequently completes its assertions through
both PostgreSQL and MySQL: ALTER invalidates the definition, DROP and same-name
replacement deny the original retired identity, fresh lookup of the absent name
reports a missing Table, and fresh preparation binds the empty replacement.
The default full wire schedule is unchanged; its remaining qualification is
still required.

## SQL settings observation recovery — 2026-10-26

At `6ee045205`, the shared SQL package's `zig build test` and the real TLS
PostgreSQL/MySQL settings slice pass. The slice is reproducible with
`nix develop .#sql-wire --command zig build test-sql-wire-gateway
-Doptimize=ReleaseSafe -- settings`. The recorded successful invocation uses
the same binaries installed by `test-sql-wire-build`, with hashes in the
[control report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sql-settings-recovery-2026-10-26/report.json).
The local documentation check and full handbook check/build also pass.

A settings-only `HttpCapacity` refusal during preparation reproduces the
generic PostgreSQL `Request failed` response on the baseline gateway from
`6f24c2d15`. Its diagnostic-only instrumentation identifies preparation and the
settings transport's refusal; the ordinary session diagnostic reports only
`AuthorityUnavailable`. All other executables are byte-identical in the
before/after control. The earlier installed SHOW failure lacked phase
attribution, so this establishes a reproducible cause rather than proving the
exact phase of every prior failure.

Both drivers pass two refused preparation observations, first-page recovery,
and continuation recovery for unordered and ordered metadata. Failed and
repeated page actions retain the same cursor; exact result comparison detects
lost or duplicated rows. Permission denial and changed configuration snapshots
remain terminal. A reload accepted before a lost reply escapes the first SQL
statement; a subsequent explicit request reconciles the same original identity
and adds exactly one history entry. Existing SET/RESET, captured defaults,
administrator ceilings, the one-millisecond deadline and reload revocation
checks pass. Request/statement budgets, page bounds and current authorization
are unchanged.

Two intermediate runs failed test expectations that used PostgreSQL SQLSTATEs
for MySQL. Their logs are retained beside the successful control; the correction
asserts MySQL's existing error numbers, SQLSTATEs and snapshot-change message.
No MySQL error mapping changed. This focused slice does not complete installed
SQL, the SDK matrix or combined clean-checkout qualification.

## SQL observation budgets — 2026-10-26

The shared SQL unit suite and real-console protocol fixture pass the
[focused controls](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sql-observation-budgets-2026-10-26/report.json).
The baseline control-preparation test fails after 64 unavailable observations,
before its five-second deadline; the corrected owner survives 80 refusals and
publishes one exact signed control. Current denial remains terminal, moving
metadata retains its 64-retry bound, and both expired and live short deadlines
prevent publication. The exact prepared request cannot be replaced while pending.

The baseline console exits with `SqlOutcomeUnknown` after one status response
reports `AuthorityTimeout`. The corrected client observes the same token again
and receives the applied outcome, with two status calls and one SQL submission.
Continued timeouts during admission discovery still exhaust the original budget.
Existing denial, changed-instance, session-expiry, lost-execute, incomplete-result
and cancellation schedules pass. No SQL text is replayed by recovery.

The [retained installation observations](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/sql-outcome-observations-2026-10-26/report.json)
recover original INSERT 216 as applied with one matched/changed row and original
RENAME 348 as applied. They restart the same installations and inspect public
status without resubmitting either mutation. These later observations do not
establish the instant of acceptance relative to the earlier client failure.
Original CREATE 155 remains uploading and execution-ineligible after restart;
its installed five-minute wait and the follow-up observation are failures, not
successful qualification. The original incidents lack the phase/status-code
trace needed to attribute them to either focused regression above.

Full installed SQL, lifecycle history replay, SDK lanes and combined committed
clean-checkout qualification remain separate gates.

## SQL lifetime failure reporting — 2026-10-26

Follow-up hosted run [40337023008](https://github.com/spoke-sh/transit/actions/runs/40337023008)
tests head `717f55793` at merge `2ed8ead0f`. Launchers completes 2/2 tasks in
699.80 seconds. Experience completes its first seven tasks, then fails
`test::server-sql-lifetimes` after 46.10 seconds. The first psql
`SELECT value FROM items` yields no stdout row within 30 seconds after the
console reports an applied INSERT. The fixture did not capture psql stderr in
the failure or upload the retained installation, so the reason is unknown.
The [artifact and job log](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-browser-closeout-2026-10-26/hosted-717/report.json)
retain the failure; subsequent tasks did not execute.

The fixture now starts psql with `ON_ERROR_STOP=1` and verbose SQLSTATE reporting,
includes bounded stderr in EOF/deadline failures, and publishes a bounded JSON
failure report with the active phase and manager stderr. This makes a SQL error
observable without mislabelling it as an unanswered query. It adds no retry and
keeps the original 30-second response deadline. This diagnostic correction does
not identify the historical cause or establish a runtime fix.

## Signed filtered Table reads and finite SQL — 2026-10-26

`just test::direct-table-service projection` passes against the signed local disk
owner with finite scans lowering predicates through `filter_scan`. The fixture
contains 17 wide segment rows and an accepted WAL row, then a later write outside
the retained cut. It verifies two empty eight-identity pages before matches at
source positions 17 and 18, 1 KiB projected pages, complete skipped-row coverage,
LIMIT zero/one, empty COUNT, COUNT(column), SUM and prepared ASCII_CI predicates.
A keyless fixture skips a NULL before SUM overflow and reports original row 3,
column name and plan identity. Wrong-source plans reject as InvalidRequest and
wrong fingerprints as Conflict. Revocation after physical evaluation denies
both selected rows and empty aggregate results; repeated terminal disclosure and
released-pin reads also reject.

The catalog reader/protocol suite passes **7/7** tests. Independent signed
fixtures bind the filtered cursor domain and full plan fingerprint. Malformed
coverage, offsets, failure instruction/column, source positions, foreign plans,
schemas/collations and incomplete rows reject without advancing traversal.
Exhaustive allocation failures cover owned plans, empty prefixes, selected rows
and deferred failures; the failure injector disables backing-allocator resizing
to keep allocation counts deterministic. Returned rows and copied diagnostics
outlive their reader.

`zig build test-local-catalog` passes **3/3** tests, including filtered execution
through original delegation and an exact borrowed snapshot, substituted-pin
rejection and revocation before the reply. Projected and filtered actions select
the same per-Table host lock as ordinary reads. The focused logical/batch suite
passes **91/91** tests, and the direct/logical/relational query suite passes
**47/47**, including the 16,840-row relational growth fixture. Reflected direct
contracts, diagnostic mappings/error boundaries/outcomes (**3,411** projections,
**24** surfaces), verification catalog and documentation checks pass.

The earlier service attempt reached the wrong-plan rejection but expected the
wrong local error tag; the assertion now expects the client's existing Conflict
translation. The passing rerun includes the corrected assertion and host lock
routing. These focused runs do not close the broad history-replay timeout or
establish final committed-HEAD clean qualification, borrowed batches, relational
text pushdown, physical Table collection or a performance improvement.

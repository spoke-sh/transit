# 21. Service and SDK coverage

[Roadmap](README.md) · **Status:** In Progress

Extend source, type and lifecycle limits documented by
[connectors](../handbook/reference/connectors.md), [reactive APIs](../handbook/reference/reactive.md),
[Flight/ADBC](../handbook/reference/flight.md) and the [SDKs](../handbook/reference/sdks.md).
Transport support alone does not establish a new execution profile.

Consume the neutral catalog/snapshot operations in
[#125](https://github.com/spoke-sh/transit/issues/125), changefeed/consumer
positions in [#127](https://github.com/spoke-sh/transit/issues/127), and array/state
export contract in [#128](https://github.com/spoke-sh/transit/issues/128).
Each adapter must preserve the selected transaction/feed profile, current
authorization and loss/error representation; transport convenience cannot
silently downgrade complete changes to refresh notifications or five-state
values to ordinary NULLs.

Expand APIs over the earlier [shared client foundation](09-client-foundation-and-language-apis.md)
and [transaction contract](05-transactions-and-atomic-composition.md). Preserve
delivered raw-client and console evidence; new data/SQL coverage uses the agreed
package direction and language-native ownership before extending the matrix.
No SDK may invent independent transaction recovery or require Station for ordinary
data use. Qualify each adapter's transaction control, isolation, savepoints,
provisional statement outcomes and commit uncertainty, or reject unsupported
features explicitly, including Flight/ADBC capability reporting.

## Console assistance slice

The [console assistance](../../apps/transit-cli/docs/console.md#terminal-editing-and-history) extends the
existing grammar/catalog assistance operation with typed coverage and context
status, cursor-local statement scope and settings routing. It retains eight
candidates and the 128-page metadata acquisition budget. Partial scans are
reported as limited; no new catalog authority or full resident catalog is added.
This slice is implemented independently of broader service/SDK parity. Its
current-v1 cutover migrates the native session and shared query consumers together.
[Executed evidence](../history/qualification/interfaces.md#console-completion-and-editing--2026-10-24)
covers native units, terminal peers and actual TLS session completion. Manual
terminal/SSH delivery and broader service/SDK parity are not established by it.

## SQL type parity and installed interface smoke loop

**Implementation plan — 2026-11-04. Status: Planned.** Make ordinary Table
definitions usable through the native console, PostgreSQL and MySQL interfaces,
and catch differences in the normal build/test loop. This slice belongs here;
it does not depend on the later [dialect ergonomics audit](43-sql-grammar-and-dialect-ergonomics.md).

### Failure and current coverage

The motivating sequence is:

```sql
CREATE TABLE employees (id INT, name VARCHAR, salary DECIMAL(10, 2));
SELECT * FROM employees;
```

Source inspection at `d6cc22663` explains why creation can succeed in psql while
the read returns `Operation is outside the selected SQL profile`:

- [SQL aliases](../../packages/zig/transit-fuze/src/SqlTypes.zig) resolve `INT`
  to int32 and `VARCHAR` to UTF-8; decimal retains its precision and scale.
- [WireType](../../packages/zig/transit-sql-protocol/src/WireType.zig) admits
  only int64, uint64, float64, Boolean, UTF-8 and binary. Both int32 and decimal
  fail this boundary, independently of whether the Table contains rows.
- [Statement preparation](../../packages/zig/transit-sql/src/Statement.zig)
  checks result columns and parameters for the wire profile. CREATE has neither,
  so it does not check whether its declared columns can subsequently be returned.
- [Session diagnostics](../../packages/zig/transit-sql-service/src/Session.zig)
  collapse unsupported types, statements and execution cycles into one message.

The [installed local SQL check](../../tests/interfaces/installation/server_sql_local.py)
and [CLI wire round trips](../../tests/interfaces/sql_wire/clients.py) use
BIGINT/text declarations. Driver value checks exercise the existing six-type
matrix. The [single-executable check](../../tests/interfaces/installation/server_board_package.py)
and [console gate](../../tests/performance/console/gate.py) protect useful installed
journeys, but do not exercise this declaration through all three clients.
This diagnosis is source evidence; execution evidence for the expanded matrix
must come from the checks below.

### Contract and coverage decisions

Define the matrix in the existing [gateway contract](../../contracts/SQL_GATEWAY_V1.md)
before extending codecs. Retain the logical descriptor through preparation,
metadata, binding and output; a six-value kind enum cannot carry decimal
precision/scale or narrower integer bounds. Reuse Fuze's logical value validation
and decimal rules. Adapter mappings describe transport representations, not a
new catalog, type system, permission authority or stored schema.

The first required delivery covers the following families on native SQL,
PostgreSQL and MySQL. Test SQL aliases as well as canonical names, so INT cannot
escape coverage merely because BIGINT works.

| Family | Required cases and semantics |
| --- | --- |
| Signed integers | INT8/TINYINT, INT16/SMALLINT, INT32/INT/INTEGER, INT64/BIGINT; exact values, declared range and lossless documented wire mappings |
| Unsigned integers | UINT8/16/32/64; zero, full maximum, sign rejection and exact metadata/mapping; preserve existing uint64 support |
| Floating point | FLOAT32/REAL and FLOAT64/DOUBLE/FLOAT aliases; finite values, declared width, signed zero and nonfinite rejection |
| Decimal | DECIMAL/NUMERIC with explicit precision/scale, including (10,2), scale zero and native precision up to 38; exact sign/coefficient/scale and owning rounding policy |
| Text and binary | VARCHAR/TEXT/UTF8 and supported binary aliases; empty values, Unicode, declared character limits and embedded binary zero bytes |
| Boolean and NULL | Both Boolean values; nullable and required columns; SQL NULL distinct from empty text, zero and all other cell states |

Record descriptor/value restrictions separately. For example, PostgreSQL text's
NUL restriction remains an explicit value refusal; supporting UTF-8 does not
promise that every byte sequence can traverse every protocol. Decimal values
must never pass through binary floating point or be advertised as generic text
to evade missing numeric support. Compare metadata as well as displayed values.
Specify each protocol's precision/scale domain against its pinned reference
peers before choosing metadata. Native descriptor combinations outside that
domain require an explicit tested refusal, not truncated scale or a changed
stored definition. Include default DECIMAL/NUMERIC declarations as well as
explicit parameters in alias coverage.

Inventory every other native family, including 128-bit integers, temporal types,
UUID, JSON, nested and domain types, with an explicit disposition per interface
and operation. Initially retain precise refusals outside the required matrix;
add positive coverage in separately qualified increments. Date/time/timestamp
and UUID mappings are the next scalar increment and require explicit precision,
timezone and representation decisions. An unclassified new descriptor or alias
must fail coverage validation. A planned capability cannot count as supported.

Flight/ADBC, Board and SDKs retain their owning profiles. Include their documented
dispositions in coverage navigation and reuse the corpus when extending them;
the current [Flight int64 profile](../handbook/reference/flight.md) does not become
general SQL type support through this work. The required installed smoke below
is console/psql/mysql; native session checks additionally verify typed metadata
and exact values without depending on console formatting.

### Implementation sequence

1. **Freeze the regression and neutral corpus.** Add the exact employees case,
   isolated INT-only and DECIMAL-only cases, and independent expected values and
   metadata under the existing [SQL wire test owner](../../tests/interfaces/sql_wire/README.md).
   Share data vectors and scenario identifiers with native-session and installed
   drivers. Keep expected numeric values, bytes and descriptors independent of
   production codecs. A completeness check may enumerate production descriptors
   and aliases, but must not derive expected support or values from actual output.
   Demonstrate the employees positive test failing against the current build;
   do not turn that failure into a permanent expected-successful-refusal test.
2. **Define capability checks and diagnostics.** Extend the shared wire descriptor
   and protocol-specific mappings in `transit-sql-protocol`, `transit-postgres`
   and `transit-mysql`. Use one capability decision in statement preparation,
   parameter binding and result encoding, carrying the selected protocol where
   representations differ. Keep immutable schema identity and logical types
   unchanged by transport mapping. Provide a bounded failure witness naming the
   authorized column or parameter, logical type, protocol and failed operation.
   Retain SQLSTATE `0A000` for unsupported capability; distinguish it from range,
   conversion and syntax failures. For example: `PostgreSQL cannot return column
   salary with type DECIMAL(10,2)`. Never include row payloads or credentials.
3. **Close the DDL admission gap.** Before accepting wire CREATE TABLE, require
   each declared column to have both supported input and output mappings for that
   protocol. Validate the whole definition before any durable admission or
   publication. Apply the same check when a wire schema-changing operation is
   introduced; this does not enable currently unsupported ALTER syntax. Native
   declarations retain their broader profile. A Table created or changed through
   another interface may still exceed wire capabilities: validate only the
   actual result projection and parameters on reads, so supported-column queries
   remain possible. Refusals must leave no published Table or durable write.
4. **Implement exact codecs in both directions.** Extend PostgreSQL simple and
   extended execution, text/binary result encodings, parameter OID inference and
   descriptor metadata. Extend MySQL text results, prepared binary rows, parameter
   decoding and column metadata. Thread complete descriptors through Scalar,
   Backend and session consumers rather than dropping precision at a kind-only
   call site. Qualify integer widths and float32 first, then exact signed/scaled
   decimals; preserve existing uint64 numeric behavior. Use bounded reusable
   buffers and include allocation-failure and post-warmup allocation checks for
   changed codec paths. Publish a type as supported only after input, metadata
   and both result modes pass for its adapter.
5. **Add the installed smoke and focused protocol slice.** Introduce the proposed
   `tests/interfaces/installation/server_sql_types.py` driver and
   `just test::server-sql-types` task. Reuse owned-process, port, console and
   installation helpers from the current installed checks; add only the setup
   needed for this scenario, without executing the entire authentication/fault
   campaign. Add a `types` slice to the existing gateway driver with a proposed
   `just test::sql-wire-types` task for the full independent-client matrix.
   The gateway `all` slice must include it, with nested ownership recorded rather
   than counting duplicate executions as separate coverage.
6. **Wire required gates and publish the supported profile.** Register tasks and
   build steps, update local/hosted selection, and qualify committed source with
   pinned clients. Update current references and generated contracts together
   with the implementation. Follow the [current-v1 policy](../handbook/reference/versioning.md):
   review compatibility explicitly, replace the shared definition identifier for
   incompatible wire/ABI/persisted-semantic changes, regenerate affected resources
   and migrate consumers together. Do not reinterpret saved schemas, silently
   reset installations, or introduce a parallel legacy profile.

### Installed scenario and independent assertions

Run one copied, matching ReleaseSafe `transit` executable outside the checkout
with its embedded roles, a disposable disk-backed installation and explicitly
enabled PostgreSQL/MySQL listeners. Enable the native local console in the same
fixture. All clients must select the same database, namespace and authorized
catalog; read back stable Table identities/definitions through public metadata
to detect accidental use of separate stores. Use real pinned psql/mysql clients,
not raw protocol emulation as a substitute for the user journey.

For each creating interface (console, psql, mysql), create a separate fixture
Table and read it through all three interfaces: a full 3-by-3 create/read matrix.
For the employees case, retain the user's exact declaration without rewriting
INT to BIGINT or removing DECIMAL. Require an empty `SELECT *` immediately after
creation, then insert/update/delete through each interface in turn and verify
the resulting values and counts through the others. Include supported projections
and aliases. Verify affected-row conventions according to each protocol; MySQL's
matched/changed distinction is not a mismatch in stored data.

Use the same corpus for deeper checks, with a small named subset in the early smoke:

| Boundary | Required evidence |
| --- | --- |
| Empty and NULL results | Typed empty result, all-NULL row, required-column rejection, verified terminal count; no inference from first-row values |
| Numeric precision | Integer minima/maxima and one outside each range; decimal positive/negative/zero, trailing zeros, precision 38, coefficient beyond 2^53, overflow and inexact input under the declared rounding rule |
| Result delivery | 0, 1, 32, 33 and 65 rows; exact ordered values across fetch boundaries and final completion; no success from an incomplete prefix or a display limit |
| Real drivers | psql/mysql CLI literals; psycopg text/binary and prepared binding; mysql-connector prepared/text execution; libpq/libmysqlclient metadata and exact independent scalar vectors |
| Prepared metadata | Correct integer representation, decimal precision/scale, nullability and parameter compatibility before any row; repeat execution and schema-change invalidation |
| Negative capability | Unsupported wire DDL rejects before acceptance; unsupported projection/parameter names the cause; supported projection from a broader native Table succeeds; no implicit text/float conversion |
| Restart and storage | Close clients, restart the same installation, reopen and read exact values through each interface without recreating Tables; deeper coverage also flushes/reads retained segment data |
| Authority and lifecycle | Revocation before buffered/terminal disclosure, suspended portal continuation, early close, truncated output, schema change and retained original operation recovery continue to pass |

The early smoke runs the exact employees regression, at least one representative
of every required family, empty/NULL results, a result exceeding one 32-row batch,
one unsupported-definition refusal and one retained restart. The full slice owns
all aliases, extreme values, driver modes and fault cases; reuse existing
authority/schema/fault schedules instead of copying their recovery machinery.
Do not retry an uncertain write as fresh SQL or splice a restarted SELECT into
an earlier result.

### Build and test loops

Keep compilation, ordinary correctness checks and latency measurements distinct.
The following new commands are proposed interfaces, not existing passing checks.

| Loop | Command or integration | Purpose |
| --- | --- | --- |
| Codec edit | Owning package `zig build test`; existing `just test::sql-wire-contracts` before integration | Check exact encodings, descriptors, error classification and allocation bounds without starting the installed server |
| User journey | Proposed `just test::server-sql-types` → `zig build test-server-sql-types -Doptimize=ReleaseSafe` in `.#ci-experience` | Build the matching single executable and run the bounded console/psql/mysql smoke |
| Prepared and binary matrix | Proposed `just test::sql-wire-types` → existing gateway build target with `-- types` in `.#sql-wire` | Use pinned psycopg/mysql-connector and C clients for the complete type corpus |
| Affected integration | Existing `server-sql-local`, `server-single-executable`, `sql-sessions`, `sql-wire-gateway` and `console-latency-gate` tasks | Preserve installation, native result, wire lifecycle, recovery and performance guarantees |
| Clean qualification | Existing `just ci::clean --lane installation-ui` and `--lane interfaces-sql`, plus affected core/contracts checks | Run committed source and retain attributable evidence; expand scope for ABI/schema changes |

Support build-once/repeat-run development using the proposed driver's explicit
binary argument. The build command exists; the driver is delivered in step 5:

```sh
nix develop .#ci-experience --command zig build transit -Doptimize=ReleaseSafe --prefix .cache/transit-sql-types/release
nix develop .#ci-experience --command python3 -B tests/runner/launch.py tests/interfaces/installation/server_sql_types.py --cli .cache/transit-sql-types/release/bin/transit
```

Each repeat uses a fresh owned installation and one retained restart within that
run. Record source revision/dirty state, binary digest, definition identity,
client versions, durability profile and the expected/executed case set. Separate
build time from startup and scenario time; reuse immutable build artifacts, not
mutable server state. Missing clients, cases, completion records, failed startup
or timeouts must fail the required gate. Do not skip them or increase runtime
deadlines to make the suite pass.

Add the smoke as a separate correctness step to the existing early console gate
jobs in [CI](../../.github/workflows/ci.yml) and
[release](../../.github/workflows/release.yml), reusing their matching optimized
binary. The [ci-experience shell](../../nix/ci-experience.nix) already supplies
psql and mysql; the [sql-wire shell](../../nix/sql-wire-tools.nix) supplies the
deeper driver dependencies. Keep the console gate's timing workload, resource
assertions and budgets unchanged. Run the added smoke serially outside measured
intervals and set a separate finite test timeout after measuring its workload.
Either correctness or latency failure must block the dependent jobs and release
completion. Upload sanitized per-case outcomes on failure as well as success;
private installations containing credentials remain local.

Register execution ownership in [suite.json](../../tests/runner/suite.json), the
installation lane and required early-job controls, and add inventory/completeness
validation to [checks.json](../../tests/runner/checks.json). Keep
[build/checks.zig](../../build/checks.zig), [task recipes](../../tasks/test.just),
task documentation, CI path selection and runner regression tests aligned.
Changed logical descriptors, SQL aliases, catalog schema binding, result codecs,
adapters, installed packaging or this corpus must select the relevant gates.
Do not hide the scenario in an optional performance job or run the heavy matrix
inside `just check fast`.

### Completion gates for this slice

- The original employees declaration and empty/populated reads pass through all
  three creating and reading interfaces, including exact salary values after
  restart. INT-only and DECIMAL-only regressions pass independently.
- Every required type/alias has positive input, metadata and output evidence in
  each claimed protocol mode. Other families have explicit tested dispositions;
  adding a descriptor/alias cannot silently bypass the inventory.
- Unsupported wire declarations leave no accepted work or published object.
  Errors identify authorized column/parameter, type and interface; unrelated
  unsupported statements retain their own diagnostics.
- The required early smoke fails under an injected type refusal, wrong decimal
  value, missing row, missing test case or unavailable client. The full driver
  matrix detects incorrect metadata even when text output looks correct.
- Current authorization, bounded buffers, exact completion and original-operation
  recovery remain covered by their owning checks. Record executed evidence in
  [SQL qualification](../history/qualification/sql.md), including failures and
  unexecuted scopes; planned commands and compilation alone cannot close this slice.
- Publish actual support and limits in the
  [database protocol reference](../handbook/reference/database-protocols.md),
  [SQL type reference](../handbook/reference/sql/types.md), gateway contract,
  package guides and [contributor workflow](../handbook/guides/contributing.md).
  Users must not need this roadmap to discover current supported types.

## Remaining work

### Go SDK

The raw Go client slice implements typed input preparation, current capability
reads, canonical saved-operation recovery and explicit dispatch over the shared
Zig ABI. A bounded native worker preserves stack, cancellation and joined-close
requirements. Go module/native archives, installed consumers, a runnable recovery
example and a required bindings task accompany it. See the
[Go guide](../../sdks/go/README.md) and
[executed raw-client evidence](../history/qualification/sdk.md#go-raw-client).

Remaining Go work is catalog/Table, KV/Document and finite-query coverage,
followed by Station handlers, durable calls and recorded HTTP/gRPC outcomes.
Each slice needs idiomatic types, current authorization, bounded ownership and
the existing installed-language recovery schedules. Add Go to the Station
interoperability ring only when both service and requester adapters execute.
Broader relational/SQL-session APIs, supervisor integration and additional
platform distribution retain their own shared-contract and qualification gates.
The raw slice does not complete this milestone or establish those profiles.

### Shared coverage

- Expose the qualified data/computation lifecycle through each selected SDK and
  service adapter: definitions, apply/recovery, dependencies, policy references
  and observed progress. Reuse neutral types and owning operations; transport
  parity does not imply every kind, lifetime or administrative action is supported.
- Extend Flight/ADBC and reactive interfaces beyond selected source/type profiles
  with shared codecs, metadata, current authorization and exact source bases.
  Finite results, refresh and continuous subscriptions remain distinct.
- Define interactive outbound streaming/resumption: durable acknowledgements,
  receiver admission, cancellation, unknown outcomes, reconciliation and restart.
  A reopened socket cannot imply safe replay.
- Broaden SDK/host/platform coverage through the shared Zig implementation,
  installed consumers and neutral fixtures. Host scheduling and temporary handler
  memory are not durable state.
- Define identity/sharing before exposing private inspection or collaboration to
  multiple users. Viewer authentication, upstream grants and application rights
  remain separate responsibilities.

Enterprise identity/delegation is owned by the
[Control & Policy Plane milestone](27-control-and-policy-plane.md).
The complete [Board reimplementation](30-board-reimplementation.md) owns the
data-first interface and installed browser journeys. Existing Board adapter
coverage and consumer migrations required by this milestone stay here; a later
interface cutover does not defer parity or recovery obligations.
The earlier [statement-result milestone](04-statement-results-and-consumption.md)
owns shared command completion, bounded result readers and terminal evidence;
this milestone extends qualified service/language coverage over that contract.
The [published-resource milestone](28-published-resources-and-investigations.md)
owns publication/disclosure and retained investigations; [MCP and Apps](31-mcp-service-and-apps.md)
adapt them to selected hosts. This milestone's existing native adapter work may
proceed independently; it must not imply those new access or collaboration
profiles are already supported. Extend parity only after each owner qualifies it.

[Client foundation](09-client-foundation-and-language-apis.md) owns reusable
packages, shared runtime infrastructure and the initial idiomatic data APIs.
[Programming model and mixed composition](34-programming-model.md) owns the
complete direct/Station/mixed application experience after the capability owners
land. This milestone's operation/platform promises and delivered slices remain
here; their package/API foundation is a prerequisite, not deferred cleanup. A larger adapter matrix alone does not establish that ordinary data
applications and Station behaviors compose naturally.

## Completion evidence

Carry [index lifecycle](11-indexing-and-access-paths.md) operations and inspection
through every claimed adapter using shared outcomes and recovery. Repeat the
[database/runtime scorecard](13-data-structures-and-performance.md) for actual
installed language and transport paths, reporting allocation/copy overhead,
batching, tail latency and verified completion separately from native-library
measurements. Adapter convenience cannot change index coverage, transaction
truth or acknowledgement durability to improve a benchmark.

Use pinned independent peers and real installed clients. Qualify revocation, slow
consumers, partial replies, leases/expiry, accepted-operation recovery, shutdown
and bounded memory. Measure admission/control fairness across callers. Update the
support matrix per delivered slice; one client/platform does not prove universal
interoperability.

Run the same declare/apply/inspect/change/recover scenario through the qualified
interfaces and compare object identities, definition revisions and outcomes.
Document differences in type and lifecycle coverage beside each caller.

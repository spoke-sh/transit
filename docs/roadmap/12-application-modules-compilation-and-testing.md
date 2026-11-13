# 12. Recursive `.transit` modules, SQL compilation, builds and testing

[Roadmap](README.md) · **Status:** In Progress

The [remaining implementation plan](application-remaining-implementation.md)
proposes the delivery sequence from the merged compiler and typed-target baseline
at `bc849156a`: public-data Queue program emission, richer typed composition,
runtime module boundaries, protected workflows, explicit-basis migrations,
definition replacement and deterministic replay qualification. It preserves the
P0–P6 scope and outstanding qualification below. Its public-data Queue build/test
increment merged in [PR #450](https://github.com/spoke-sh/transit/pull/450).
The [next-slice implementation](application-typed-queue-implementation.md) adds
actionable build/test diagnostics, source discovery and nominal types through
public Queue programs. [Executed qualification](../history/qualification/query.md#actionable-source-diagnostics-and-nominal-queue-programs--2026-11-13)
records the passing gates, retained failures and proof limits. This completes
only the first part of richer typed composition.
Later increments remain proposals; merge status does not
replace their qualification gates.

Let an application compose data definitions, queries, dataflows, effect bindings
and publications in a typed declarative application language stored as `.transit`,
with SQL as its relational foundation and independently executable output.
`build.transit` is a program in that same language: `transit build` and
`transit test` recursively compose local and pinned repository modules, typecheck
the program and lower it to executable `.sql`. Execute that output as ordinary
statements or synthesize immutable migration SQL against an explicit prior state.
Reuse typed modules, profiles, functions, guards and procedures. Make domain
identities, effects, capability ownership, state transitions and declared
invariants explicit, and preserve them through compilation, execution and
recovery. Exercise the same generated SQL through deterministic local tests,
selected TLA+ models, Lean proofs and implementation correspondence checks.

The bounded recursive Table compiler and `transit build` landed in
[PR #437](https://github.com/spoke-sh/transit/pull/437); the
[current source contract](../../contracts/APPLICATION_SOURCE_V1.md) defines that
implemented subset and the delivered isolated Table profile of `transit test`.
The broader source forms, clock/effect/replay controls and examples below remain
proposed except where explicitly identified as delivered. The
[public language model](../handbook/reference/applications.md#planned-source-language-and-build-model)
owns the concepts; the [compiler analysis](../handbook/internals/query-engine.md#planned-source-to-sql-compilation)
owns the equivalence argument and its limits. The existing `transit-app` tool
compiles interface definitions within its documented profile; it is not this
build system. This milestone adds no `transit app` command family.

**Grammar baseline:** the source compiler now has a dedicated
[ANTLR reference and correspondence corpus](../../contracts/application-source/README.md)
for `.transit` modules, builds and tests, alongside its Zig parser. The existing
[SQL grammar](../../contracts/sql/TransitExtensions.g4) and
[application interface grammar](../../contracts/application/Application.g4)
cover different entry points. The source slice supplies full template syntax,
bounded source formatting, nominal source domains, closed variants, exhaustive
compile-time matching and typed public Table exports. Its finite
comparisons do not prove general language correctness. New syntax, static checks, runtime semantics and formal evidence
have separate acceptance gates throughout this milestone.

Extend the [shared data lifecycle](01-declarative-data-lifecycle.md),
[statement outcomes](04-statement-results-and-consumption.md),
[multi-object transactions](05-transactions-and-atomic-composition.md),
[declarative streams, queues and durable runtime](06-streams-queues-and-durable-runtime.md),
[logical document storage](07-document-storage-and-station-decoupling.md),
[direct-plane gateway ingress](08-gateway-architecture-and-protocol-ingress.md),
[shared clients](09-client-foundation-and-language-apis.md),
[historical catalogs and constraints](10-standards-and-catalogs.md) and
[indexing and online rewrites](11-indexing-and-access-paths.md). Start from the
[application guide](../handbook/reference/applications.md),
[SQL reference](../handbook/reference/sql.md),
[migration contract](../../contracts/MIGRATION_V1.md),
[declarative catalog contract](../../contracts/DECLARATIVE_CATALOG_V1.md),
[versioned catalog definitions contract](../../contracts/CATALOG_DEFINITIONS_V1.md),
[dataflow contract](../../contracts/DATAFLOW_V1.md) and
[source contract](../../contracts/SOURCE_V1.md).

## Problem statement and empirical baseline

This gap assessment records the pre-compiler Platform baseline. Shared block
framing, migration file validation and bounded Table builds have since advanced;
the [first implementation plan](application-build-implementation.md) and
[next-slice source audit](application-test-implementation.md#source-basis-and-existing-owners)
distinguish delivered scope from the remaining work described here.

As declarative SQL in Transit expands beyond passive `CREATE TABLE` DDL to
encompass versioned documents, queues, streams, transactional command handlers
(`CREATE DATAFLOW ... FROM COMMAND ... AS BEGIN ATOMIC`), asynchronous effect
workflows (`FROM QUEUE ... EXECUTE SINK ... AWAIT OBSERVATION ... ON FAILURE`),
HTTP route bindings (`CREATE SOURCE ... FROM HTTP REQUEST`) and read APIs
(`CREATE PUBLICATION`), SQL becomes a complete systems and application
programming language.

Authoring a production control-plane application directly inside numbered
migration files—as exercised by the 3,513-line, seven-file Spoke Platform
baseline (`0001-auth.sql` through `0007-https-endpoints.sql` across `auth`,
`catalog`, `tenancy`, `networking`, `deployments` and `publication`, declaring
26 command dataflows, 14 queue/stream workflows, 16 publications, 26 HTTP
sources and 15 external sinks)—exposes five structural bottlenecks in the
current toolchain and language surface:

| Bottleneck | Concrete manifestation in current codebase and consumer migrations | Architectural consequence if unaddressed |
| --- | --- | --- |
| **1. Chronological migration files vs. logical source tree** | [`MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md) and [`DirectMigration.zig`](../../packages/zig/transit-catalog/src/DirectMigration.zig) (`TMD1`/`TMV1`) enforce byte-for-byte immutability (`source_sha256`) on applied `<version>-<name>.sql` files and cap each version at `max_steps = 64`. `networking` is already split across `0004-networks.sql` (385 lines) and `0007-https-endpoints.sql` (825 lines), while `0005-transit-instances.sql` spans 1,047 lines. | Once `0001`–`0007` are applied, changing a single guard or parameter in a 70-line dataflow (`deployments.replace_instance`) requires appending a `0008-*.sql` patch file. Understanding current domain behavior requires mentally replaying the chronological migration log instead of reading a logical module tree. |
| **2. Flat schema namespaces without module encapsulation** | `CREATE SCHEMA` in [`DirectNamespace.zig`](../../packages/zig/transit-catalog/src/DirectNamespace.zig) provides a flat naming prefix and coarse `GRANT USAGE` boundary with no `PUBLIC` vs. `PRIVATE` object visibility or explicit cross-module interface contract. Within a single file, storage schemas, command handlers, background workflows, `AUTHORIZE`/`ACTIVATE` wiring, `PUBLICATION`s and HTTP `SOURCE`s are interleaved in topological order. | External schemas directly mutate or query another module's internal storage tables (for example, `deployments.register_instance` and `deployments.purge_retained_storage` directly executing `INSERT` and `UPDATE` on `networking.attachments`, and `publication.publish_bundle` querying `networking.target_holds` internal columns), coupling physical table schemas across domain boundaries. |
| **3. Repetitive ceremony and missing compile-time abstractions** | Every command repeats a 17-line `CREATE SOURCE ..._http FROM HTTP REQUEST` block with identical `request_profile`, `authentication`, `origin`, `request_id_header`, `max_body_bytes` and `request_timeout` options plus paired `AUTHORIZE`/`ACTIVATE` statements (~450 lines of duplicate route boilerplate across 26 commands). Every `CREATE PUBLICATION` repeats the same 12-line `WITH (...)` block (~200 lines across 16 catalogs). Dataflows repeat identical revision/authority `REQUIRE` checks, `DIGEST` $\to$ `NATIVE_AUTHORIZES` $\to$ `ACCEPT OPERATION` $\to$ `ENQUEUE` sequences, and `GUARD EXISTS (SELECT 1 FROM ..._current_operations WHERE id = operation.id)` clauses. | High-signal domain invariants and state transitions are buried under hundreds of lines of copy-pasted wiring; updating a shared security header, timeout, or operation-acceptance invariant requires error-prone edits across dozens of declarations. |
| **4. Statement-level scanner limits and late runtime planning** | [`MigrationClient.loadSourceFile`](../../packages/zig/transit-sql-client/src/MigrationClient.zig) validates whole migration files against `Sql.validateText`'s 4,096-byte single-statement ceiling (`StatementTooLarge` on the 19.5 KiB `0001-auth.sql`). [`MigrationRunner.splitStatements`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig) splits on `;` whenever parenthesis `depth == 0`, breaking on semicolons inside `CREATE DATAFLOW ... AS BEGIN ... END;` compound bodies. Semantic validation happens only when planning against a live catalog. | Authors cannot run a fast, offline whole-program compiler (`transit build` with check-only compilation) that resolves cross-schema imports, typechecks `LET` bindings and `ROW(...)` fields, verifies `CAPABILITY` response/handoff completeness, and prevents `SECRET` taint leaks before starting a server or container. |
| **5. No unit-test harness or deterministic effect/clock simulator** | Testing a command (`deployments.prepare_candidate`) or multi-step workflow (`auth.complete_github_signin`, `networking.issue_certificate`) currently requires standing up a live process or container harness and exercising full wire/provider paths. | Developers cannot unit-test individual dataflows in milliseconds with deterministic clocks (`ADVANCE CLOCK`), stubbed `SINK` outcomes and `AWAIT OBSERVATION` replies, or automated crash/replay fault injection across `BEGIN ATOMIC` and effect yield points. |

## Architectural decisions (`D1`–`D6`)

### `D1` — One source dialect and build graph, executable SQL outputs

- **One typed semantic core:** Resolve source into a bounded typed graph carrying
  stable object/definition identities, domain types, query cardinality and cell
  states, ordered guards/read sets, effects, transaction boundaries, capability
  transfers and transition contracts. Canonical SQL emission and selected formal
  abstractions consume this graph. Generating both from one graph is not a proof
  that either is correct; retain independent properties and runtime comparisons.
- **Same language at every composition level:** `.transit` combines ordinary
  SQL with typed imports, modules, constructors and compile-time evaluation.
  `build.transit` uses those same constructs to export target compositions,
  output declarations and tests. A child build module can build independently
  or be imported by its parent. `transit build` and `transit test` resolve one
  graph; nested projects do not require recursive shell invocations or a second
  manifest language that independently defines module semantics.
- **SQL is the executable output:** Canonical `.sql` contains the complete
  database program, runnable through ordinary statement owners without the
  `.transit` source tree or a build interpreter. Typed ASTs, Fuze plans and
  Catalog descriptors are shared compiler internals. Preserve source maps,
  dependency provenance, compiler/contract identity and target compatibility
  alongside outputs, without hiding executable semantics in sidecars. Imports,
  target selection and emission are consumed at compile time; unsupported
  runtime constructs reject instead of producing apparently runnable SQL.
- **Statement and migration targets have different inputs:** A statement target
  compiles against declared schemas and dependencies. A migration target also
  consumes an explicit prior definition graph and required transforms, producing
  ordered `migrations/<version>-<name>.sql`. Stateful `TABLE`, `KV`, `DOCUMENT`,
  `STREAM` and `QUEUE` changes require explicit DDL/backfill steps. Runtime
  definitions use conditional replacement where supported by `D5`; erased
  compile-time helpers affect the emitted definitions that depend on them.
- **One migration authority:** [`DirectMigration`](../../packages/zig/transit-catalog/src/DirectMigration.zig)
  (`TMD1`/`TMV1`) retains immutable applied SQL, original accepted identities and
  step receipts. Builds do not apply migrations or discover their basis from a
  live cluster implicitly. Recovery never recompiles changed source or packages.
  Offline migration replay must produce the same logical fingerprints and
  definition digests as preparing emitted desired-state SQL under the same
  instance bindings. Preserve historical revisions separately from that final
  logical-state comparison.

### `D2` — Recursive typed modules, repository dependencies and explicit stateful instances

- **Separate composition units:** A workspace coordinates packages and targets;
  a package distributes modules and dependencies; a module owns typed parameters,
  imports and exports; a target selects an output or test composition. A SQL
  schema remains a catalog namespace. Pure helper modules need no schema, and
  module interfaces must not be inferred from directory names or schema grants.
- **Higher-order recursive composition:** Modules may accept types, values and
  modules satisfying declared interfaces, and export constructors or composed
  modules. Local paths and remote packages use identical interfaces. Resolve
  imports explicitly and reject undeclared references and import/build cycles.
  Compile-time recursion has deterministic work/depth/memory/output budgets and
  attributable exhaustion diagnostics; runtime recursion keeps its own contract.
- **Behavioral resource interfaces:** Exports describe typed references, queries,
  commands and atomic procedures, including effects and pre/postconditions.
  Reference-only exports permit native foreign-key binding without exposing row
  reads or mutation. Abstract nominal types distinguish an object's ID, revision,
  operation and evidence; stable instance bindings, not source paths, determine
  their identity. Interface conformance cannot silently widen effects or assume
  an unproved behavioral contract. Compilation supplies no runtime grants.
- **Reproducible repository resolution:** Pin repository URL, optional package
  subdirectory, exact revision and verified content digest in a transitive lock.
  Explicit local overrides remain visible in provenance. After fetching, frozen
  builds and tests work offline. Include compiler/contract identity, source
  contents, target options, bindings and dependency closure in cache keys.
  Fetch/update operations and build evaluation have separate effects.
- **Explicit durable instances:** Bind stateful declarations to namespaces and
  stable object identities independently of source paths and import aliases.
  Reject conflicting versions mapped to the same stateful instance. Multiple
  instances require explicit bindings, and dependency upgrades require reviewed
  migration consequences rather than implicit state creation or replacement.
- **Encapsulation survives lowering:** Default internal storage/helpers to
  private source visibility and expose typed views/functions/procedures through
  exports. Replace the Platform baseline's cross-module storage mutations with
  exported procedures. Define runtime module ownership and enforcement before
  claiming private storage is protected from ordinary SQL callers; retain that
  meaning in emitted SQL and catalog definitions. Imports/exports grant no rights,
  and inlining must not turn a public procedure into an unchecked privileged write.

### `D3` — Composable compile-time abstractions (`PROFILE`, `FUNCTION`, `GUARD`, `PROCEDURE`)

Provide typed higher-order constructors over modules, declarations and
expressions, including the four abstractions below. Name resolution,
specialization and hygienic expansion produce canonical executable SQL using
the same Fuze/Catalog semantics as handwritten statements. Preserve both
definition-site and invocation-site source locations. Distinguish compile-time
functions that construct SQL from scalar functions evaluated over runtime rows.
Imports, module constructors and build operations are erased; any retained
`FUNCTION`, `PROCEDURE` or other declaration needs an executable runtime contract.
The intended expansion adds no hidden actor turns or implicit authority.

Extend these abstractions with typed query/predicate and command constructors:
helpers accept and return checked expressions/declarations rather than SQL text.
Pure expression composition, ordered guard composition, atomic command
composition and durable workflow sequencing have distinct effect contracts.
Specialize higher-order arguments at compile time initially. Runtime closures,
unrestricted dependent types and implicit parallel effect dispatch are outside
the initial profile. Any later parallel operator must specify concurrency/work
bounds, ordering, failure and cancellation without promising remote rollback.

The following snippets illustrate proposed `.transit` source, not currently
executable SQL:

1. **Reusable option profiles (`CREATE PROFILE ... FOR SOURCE | SINK | PUBLICATION`):**
   Factor shared transport, authentication, framing, pagination and recovery
   policies into named, schema-qualified profiles:
   ```text
   CREATE PROFILE tenancy.command_http_v1 FOR SOURCE WITH (
     request_profile = 'command_json_v1',
     authentication = 'native_session_or_bearer',
     origin = SETTING('browser.public_origin'),
     request_id_header = 'Idempotency-Key',
     max_body_bytes = 65536,
     request_timeout = '10s'
   );

   CREATE SOURCE tenancy.create_project_http
     FROM HTTP REQUEST INTO COMMAND tenancy.create_project
     USING PROFILE tenancy.command_http_v1
     WITH (
       method = 'POST',
       path = '/platform/v1/organizations/{organization_id}/projects',
       path_arguments = JSON '["organization_id"]',
       body_arguments = JSON '["expected_revision","name"]',
       result_path = '/platform/v1/requests/tenancy.create_project/{request_id}',
       response_status = 201
     );
   ```
   Profile expansion merges profile defaults with explicit `WITH (...)`
   overrides at compile time, validating option types and rejecting unknown or
   conflicting keys before emitting concrete SQL whose ordinary preparation
   yields the canonical `SourceDeclaration` or `PublishedProjection`. Runtime
   `SETTING` and secret references remain references; compilation cannot read
   deployment credentials or freeze live private values into output.
2. **Pure scalar and row functions (`CREATE [PUBLIC] FUNCTION`):**
   Deterministic, side-effect-free typed functions over scalar and `ROW(...)`
   values (e.g., digest computation, URI/key formatting, status mapping) that
   expand into typed SQL expressions, prepared through the shared `Fuze` scalar
   programs (`ScalarProgram.zig`), with full five-state
   (`value`, `null`, `missing`, `type_error`, `conflict`) and checked-arithmetic
   propagation.
3. **Named invariant and authority guards (`CREATE [PUBLIC] GUARD`):**
   Parameterized predicate + refusal-code bundles that can be invoked in both
   `REQUIRE <guard>(...)` statements and `EXECUTE SINK ... GUARD <guard>(...)` /
   `AWAIT OBSERVATION ... GUARD <guard>(...)` clauses:
   ```text
   CREATE PUBLIC GUARD tenancy.require_scope_action(
     scope ROW(authority OBJECT_ID, revision BIGINT),
     action TEXT,
     expected_revision BIGINT
   ) AS
     REQUIRE scope IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), action, scope.authority)
       ELSE 'Forbidden',
     REQUIRE scope.revision = expected_revision
       ELSE 'StaleTarget';
   ```
   Guards preserve exact source-location provenance (reporting both the guard
   definition site and the caller invocation site in diagnostics) and record
   their full read-set basis for native guard verification. Ordered guards retain
   refusal precedence, cell/error behavior and evaluation dependencies; they
   cannot be reordered using the laws of total Boolean predicates.
4. **Inline transactional procedures (`CREATE [PUBLIC] PROCEDURE ... AS BEGIN ATOMIC ... END`):**
   Parameterized transactional blocks that can be called (`CALL schema.proc(...)`
   or `LET res = CALL schema.proc(...)`) inside an enclosing `BEGIN ATOMIC`
   block. Procedures inline into the caller's single atomic transaction commit
   envelope ([Milestone 5](05-transactions-and-atomic-composition.md) /
   [Milestone 6](06-streams-queues-and-durable-runtime.md)), enforcing the
   callee module's table encapsulation while committing all state mutations,
   operation acceptances and queue enqueues atomically in one `TransitLog`
   decision. To keep effect recovery and replay coordinates unambiguous,
   `EXECUTE SINK` and `AWAIT OBSERVATION` remain top-level `DATAFLOW` steps and
   are forbidden inside inline `PROCEDURE` bodies.

### `D4` — Shared compiler, bounded evaluation and canonical SQL emission (`transit build`)

- **Independent source grammar:** Maintain a dedicated ANTLR source root beside
  the source contract, using the pinned grammar tools. Distinguish source/build,
  test and ordinary runtime SQL entry points; share SQL productions where
  appropriate without copying a divergent SQL dialect or admitting arbitrary
  bodies as unchecked text. Compare independent source ASTs with the production
  Zig parser, including embedded SQL operands, precedence, block boundaries and
  diagnostics. ANTLR remains a verification dependency, not a runtime parser.
- **Block-aware lexical splitting and application-sized file bounds:**
  Upgrade [`SqlInput.zig`](../../packages/zig/transit-fuze/src/SqlInput.zig) and
  [`MigrationRunner.splitStatements`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig)
  to track compound lexical block depth across `BEGIN [ATOMIC] ... [ON FAILURE ...] END`,
  `CASE ... END [CASE]`, `IF ... THEN ... [ELSIF ...] [ELSE ...] END IF`, and
  `FOR ... IN ... DO ... END FOR` in addition to parenthesis depth, while
  separating single interactive statement limits (4,096–65,536 bytes) from
  multi-statement source/migration file limits (proposed 1 MiB per file and 256
  steps per migration version, with bounded scratch memory).
- **Offline whole-program semantic validation and linear capability checking:**
  Provide `transit build` and a check-only mode over `build.transit`, backed by
  shared Zig compiler components using
  [`transit-fuze`](../../packages/zig/transit-fuze/src/root.zig) and the Catalog
  type/definition owners. Keep the database compiler independent of Station;
  the existing interface compiler can integrate through that shared boundary.
  Validate a resolved multi-module application without a running server:
  1. **Dependency & symbol resolution:** Resolve all `SCHEMA`, `TABLE`, `KV`,
     `DOCUMENT`, `STREAM`, `QUEUE`, `VIEW`, `FUNCTION`, `GUARD`, `PROCEDURE`,
     `PROFILE`, `CONNECTION`, `SINK`, `SOURCE`, `DATAFLOW` and `PUBLICATION`
     references across the module graph and explicit instance bindings; verify
     import/export interfaces and visibility
     and `AUTHORIZE`/`ACTIVATE` ordering (every `SOURCE` must activate after its
     target `COMMAND` or `QUEUE` consumers are authorized and activated).
  2. **Strict type & 5-state checking:** Typecheck every `LET` binding,
     `SELECT` projection, `ROW(...)` constructor, `PUT`/`INSERT`/`UPDATE`
     target, `JSON_OBJECT` call and `RETURN` value against bound `ColumnId`
     types ($\tau$), collations ($\kappa$) and nullability. Add nominal domain
     types, tagged unions with exhaustive matching and a bounded refinement
     subset with explicit external-input validation. Distinguish one/optional/many
     row cardinality from nullable values and all five cell states. Keep logical
     types, semantic descriptors and physical codecs orthogonal.
  3. **Linear `CAPABILITY` & `OPERATION` lifecycle analysis:** Verify on every
     control-flow path (including `IF`/`ELSE` branches and `ON FAILURE` blocks)
     that each inbound `CAPABILITY` (`request_ref`) and `OPERATION` (`native_ref`)
     is consumed **at most once** and **never leaked**—every path must terminate
     in `RESPOND TO`, `RESPOND ERROR TO`, `HANDOFF ... TO`, `COMPLETE OPERATION`,
     or `PRESERVE OPERATION`.
     Static path settlement does not prove crash-safe exactly-once processing;
     native durable identities, fencing and current authorization remain required.
  4. **Information-flow & `SECRET` taint analysis:** Track `SECRET(...)`,
     `DERIVE_SECRET(...)`, `RANDOM_SECRET(...)`, `HTTP_SECRET_*` and
     `SECRET_JSON_VALUE(...)` values as tainted `Secret<T>` types that may only
     flow into `COMMITMENT(...)`, `S256(...)`, `SECURE_EQUAL(...)`,
     `BEARER(...)`, `SET COOKIE ... VALUE`, or `EXECUTE SINK` protected
     fields—statically rejecting any attempt to store raw secret bytes in a
     `TABLE`, `KV`, `DOCUMENT`, `STREAM`, `QUEUE` or unredacted `RESPOND` body.
     Protected encodings such as `BEARER` retain their disclosure restrictions;
     wrapping a secret is not a general-purpose declassification operation.
  5. **Effect and transition checking:** Infer/check resource reads, writes,
     enqueue/produce, external dispatch, time/random inputs, protected disclosure
     and capability transfer through every call and higher-order argument.
     Forbid hidden effects in pure helpers and external dispatch in atomic
     procedures. Declare transition preconditions, postconditions and named
     invariants over existing authoritative state; lower admitted transitions to
     native transactions, not another workflow store. Keep desired state,
     external observations and operation progress distinct. Check explicit
     success/refusal/unknown branches and evidence bound to the matching object,
     definition, generation and operation; dynamically received evidence needs
     runtime validation. Refinements never cache current permission across an
     effect, suspension or commit boundary.
- **Canonical emission and independent execution:** Emit SQL, reparse it using
  the ordinary statement compilers, and verify bound definition/plan equivalence
  with the checked expansion. Execution must preserve source attribution,
  current authorization, transaction boundaries and accepted identities without
  loading source modules. Compile-time evaluation and output growth are bounded;
  a budget failure cannot leave an output marked complete. Deterministic output
  and cache invalidation include all locked and declared inputs.

### `D5` — Safe live evolution of definitions (`CREATE OR REPLACE`) and in-flight generation draining

- Include domain/variant definitions, refinement predicates, effects, transition
  contracts and evidence schemas in definition dependency/digest analysis.
  Changes can require explicit data transforms and revalidation of proof evidence.
  Accepted continuations retain their original interpretation and capability
  obligations; changing source types cannot reinterpret their recorded values.
- Extend [`DirectMigration.zig`](../../packages/zig/transit-catalog/src/DirectMigration.zig)
  (`TMV1`), [`DirectDefinition.zig`](../../packages/zig/transit-catalog/src/DirectDefinition.zig)
  and [`ManagedDataflow.zig`](../../packages/zig/transit-catalog/src/ManagedDataflow.zig)
  so versioned definitions (`DATAFLOW`, `VIEW`, `PUBLICATION`, `SINK`, `SOURCE`)
  support conditional replacement (`CREATE OR REPLACE ... IF REVISION = ...`)
  inside migrations without dropping and recreating dependents.
- When a `DATAFLOW` or `SOURCE` is replaced at catalog revision $R_{k+1}$:
  - Newly admitted HTTP requests, commands and queue leases bind to definition
    revision $R_{k+1}$.
  - Already-claimed queue leases and in-flight `OPERATION` continuations
    admitted under $R_k$ carry their frozen `definition_revision` and either
    complete under $R_k$'s immutable plan or drain/fence before $R_{k+1}$
    activates, governed by explicit `WITH (on_replace = 'drain_active' | 'pin_generation' | 'require_idle')`
    policy. In-flight work is never silently reinterpreted under a mutated
    workflow AST.

### `D6` — Deterministic offline unit testing, effect/clock simulation and yield-point fault injection (`transit test`)

- **Container-free declarative test runner (`*.test.transit`):**
  Let developers write fast, hermetic unit and property tests alongside each
  module (`modules/auth/auth.test.transit`, `modules/deployments/instances.test.transit`).
  `transit test` reads the same `build.transit`, resolves the same locked module
  graph and lowers test bodies through the production SQL emitter. Execute the
  generated SQL over an isolated, zero-network `DatabaseRuntime` + `DirectCatalog`
  instance. Runner-owned assertions, clocks, mocks and schedules remain test-only
  controls, separate from deployable SQL. Proposed source syntax:
  ```text
  -- modules/tenancy/tenancy.test.transit
  TEST 'create_project enforces parent revision and authority'
    USING MODULES (tenancy)
  AS BEGIN
    SET TEST CLOCK '2026-11-09T12:00:00Z';
    SET TEST SUBJECT 'subj_alice' WITH GRANTS (
      'onboard' ON SETTING('tenancy.onboarding_resource')
    );

    LET org = INVOKE COMMAND tenancy.create_owned_scope(name => 'Acme')
      WITH REQUEST_ID 'req-org-1';
    ASSERT org.revision = 1;

    -- Stale revision must refuse without mutating state
    ASSERT COMMAND tenancy.create_project(
      organization_id => org.id,
      expected_revision => 99,
      name => 'Core'
    ) FAILS WITH 'StaleTarget';

    -- Unauthorized subject must refuse with Forbidden
    SET TEST SUBJECT 'subj_mallory' WITH GRANTS ();
    ASSERT COMMAND tenancy.create_project(
      organization_id => org.id,
      expected_revision => 1,
      name => 'Core'
    ) FAILS WITH 'Forbidden';
  END;
  ```
- **Deterministic `MOCK SINK`, `MOCK OBSERVATION` and `ADVANCE CLOCK`:**
  Queue- and stream-driven workflows (`FROM QUEUE ... EXECUTE SINK ... AWAIT OBSERVATION`)
  can be stepped deterministically in tests by registering scripted or
  predicate-matched sink/observation outcomes (`MOCK SINK auth.github_token
  RETURNS STATUS 200 BODY JSON '{"access_token":"gho_test"}';`,
  `MOCK SINK networking.create_stack RETURNS OUTCOME 'unknown';`,
  `MOCK OBSERVATION AWS STACK 'arn:aws:cloudformation:...' RETURNS (complete => TRUE, status => 'CREATE_COMPLETE', ...);`)
  and advancing virtual time (`ADVANCE TEST CLOCK BY INTERVAL '10 minutes';`) to
  test challenge expiry, lease timeouts, and `ON FAILURE` preservation paths.
- **Automated yield-point crash/replay verifier:**
  `transit test --verify-replay` automatically snapshots the in-memory catalog
  and partition state at every `EXECUTE SINK`, `AWAIT OBSERVATION` and
  `BEGIN ATOMIC` boundary in a tested workflow, simulates worker interruption or
  lost response, and re-runs the workflow under `ON REPLAY OBSERVE ONLY` to
  verify that replay does not redispatch, no reservation or resource binding is
  dropped on an `unknown` outcome, and terminal evidence agrees where completion
  is known. Preserve uncertainty when it cannot be resolved. Simulation proves
  only the tested schedules; real provider idempotency and physical durability
  require their owning integration proofs.

- **Contracts connected to formal evidence:** Named invariants and temporal
  properties have explicit owners and assumptions. Use small TLA+/TLC models for
  races, replacement, revocation, crash/recovery and uncertain outcomes; state
  finite domains and exploration completeness. Liveness requires separately
  stated fairness and availability assumptions. Use Lean for selected type/core
  semantics, invariant-preserving transitions and hygienic/ordered lowering laws,
  including checked arithmetic and cell/error semantics. Review theorem meanings,
  reject unfinished proofs and audit axioms. Neither backend verifies arbitrary
  application code or the Zig implementation automatically.
- **Correspondence and attributable results:** Connect formal transitions to
  real native operations through explicit projections and counterexample replay.
  Preserve independent specifications and negative controls even when models are
  generated from the typed graph. Classify evidence as parsed, typechecked,
  executed, model checked under bounds, or proved under assumptions; bind it to
  source/dependency, compiler/core/contract, generated SQL and model/proof identities.
  Timeouts, unsupported properties and incomplete exploration cannot pass.

---

## Delivery sequence and implementation plan (`P0`–`P6`)

The [first-slice implementation plan](application-build-implementation.md)
reconciles this sequence with the merged application foundation and scopes
the first recursive module build through independently executable SQL. The
bounded Table compiler is implemented in `transit-compiler` and exposed through
`transit build`; [its public contract](../../contracts/APPLICATION_SOURCE_V1.md)
keeps unsupported runtime capabilities explicit. Qualification and remaining work
are tracked by the implementation plan. It scopes
the initial runtime subset, package/compiler owners, logical commits and caller
proofs; the broader P0–P6 completion criteria below remain required.

The [Table test runner slice](application-test-implementation.md) delivers explicit
test targets, production SQL emission and isolated execution through real local
database owners. Typed row multisets, command counts and exact constraint refusals
use ordinary SQL sessions and require complete results and joined cleanup.
[Executed qualification](../history/qualification/interfaces.md#isolated-application-table-tests--2026-11-10)
records the bounded profile and its limits. This is part of P5; subject/clock
controls, effect simulation and workflow replay remain subsequent work. The
merged build PR's validation and latency failure retain their original scope.
Neither delivered slice completes the milestone.

### Next language slice

The [source grammar and typed-core implementation plan](application-source-grammar-implementation.md)
records the bounded syntax/core increment: independent ANTLR/production-parser
comparison, complete embedded-SQL syntax/stage rules, source round-trips and the
core extension contract. It implements none of the domain/effect forms below.

The [typed-target implementation plan](application-typed-target-implementation.md)
records the delivered nominal source values, closed variants, exhaustive compile-time
matching and typed public Table exports. The slice extends grammar, static semantics, ordinary
SQL lowering and selected Lean preservation laws together. The first executable
case specializes a build for one of two resource kinds; dynamic command inputs,
query cardinality, runtime domain enforcement and reference-only foreign-key
exports remain subsequent work. The source contract owns the exact symbolic-checking restrictions and Lean premises.
[Executed qualification](../history/qualification/query.md#typed-target-rebase-and-shared-sql-framing--2026-11-11)
records passing component and clean-lane checks and unresolved installation/UI
and console-latency gates at that source. The later public Queue foundation's
final CI results are reconciled in the
[next-slice plan](application-typed-queue-implementation.md#source-basis-and-existing-owners).
Keep these source-specific results and failures distinct. Develop three synthetic design cases
incrementally:

| Case | Language and proof obligation |
| --- | --- |
| A command selecting one of two resource kinds | Nominal references, tagged unions, exhaustive matching, cardinality and typed module exports |
| One-use request admission with a continuation | Atomic claim/enqueue/handoff, protected values, current authority and explicit unknown effects; two competing callers and interruption schedules |
| Admission against a bounded resource budget | Ordered guards, exact revision/operation binding and atomic reservations; concurrent admission must preserve capacity |

These cases define reusable native capabilities without copying private consumer
source or product policy. Their full execution depends on the owning runtime
contracts; grammar or model delivery must not mark unavailable operations as
implemented. Each later construct extends grammar, typed core, lowering, negative
cases and evidence together. Keep exact new spellings proposed until the source
contract and checked grammar agree.

### `P0` — Source/build contracts, compilation stages and block-aware scanning

**Owners:** [`contracts/MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md), [`packages/zig/transit-fuze/src/SqlInput.zig`](../../packages/zig/transit-fuze/src/SqlInput.zig), [`packages/zig/transit-sql-service/src/MigrationRunner.zig`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig), [`packages/zig/transit-sql-client/src/MigrationClient.zig`](../../packages/zig/transit-sql-client/src/MigrationClient.zig), [`packages/zig/transit-catalog/src/DirectMigration.zig`](../../packages/zig/transit-catalog/src/DirectMigration.zig).

Source syntax and the typed core belong to
[`APPLICATION_SOURCE_V1`](../../contracts/APPLICATION_SOURCE_V1.md) and
[`transit-compiler`](../../packages/zig/transit-compiler/README.md). Reuse the
[pinned grammar/proof tools](../../contracts/sql/README.md) and the
[model correspondence harness](../../tests/verification/models/README.md).

1. **Define the source/build boundary before adapters:**
   - Specify one `.transit` SQL dialect, with `build.transit` using the same
     module and evaluation semantics. Define typed modules, constructors,
     imports/exports, targets, source spans and compile-time versus runtime forms.
   - Define package/workspace resolution, transitive lock and local-override
     provenance, exact compiler/contract identity, deterministic evaluation
     budgets, canonical SQL output and optional source maps. These are proposed
     current-v1 contracts, not a parallel runtime protocol or separate semantic
     module manifest. Apply the existing cutover policy to affected contracts.
   - Specify statement targets and migration targets with an explicit prior
     definition basis. Identify target runtime capabilities before emitting SQL.
2. **Extend `SqlInput` and `MigrationRunner.splitStatements` for compound SQL blocks:**
   - Track lexical block nesting across `BEGIN [ATOMIC] ... END`, `CASE ... END [CASE]`,
     `IF ... END IF`, and `FOR ... END FOR` tokens so internal statement-terminating
     semicolons inside `CREATE DATAFLOW`, `CREATE PROCEDURE`, `CREATE FUNCTION`
     and `TEST` bodies are never misclassified as top-level migration step
     boundaries.
   - Preserve exact 1-based `(line, column, byte_offset)` coordinates for both
     the enclosing declaration and each inner statement inside a compound block.
3. **Separate single-statement interactive limits from source/output file limits:**
   - Keep `Sql.max_Interactive_statement_bytes` bounded for ad-hoc wire queries
     while raising `MigrationClient.loadSourceFile` and `MigrationRunner` source
     file bounds to `max_migration_file_bytes = 1024 * 1024` (1 MiB) and
     `DirectMigration.max_steps = 256` per version, using caller-supplied
     bounded scratch arenas so memory residency stays $O(\text{single statement})$
     during scanning.
   - Keep whole-program symbol/graph memory separately budgeted from scanning
     scratch; an O(single statement) scanner does not make compilation constant
     space. Define deterministic declaration ordering independent of filesystem
     enumeration, and reject output that exceeds the target's statement limits.
4. **Formalize the source grammar and continuously compare parsers:**
   - Add `contracts/application-source/TransitSource.g4` with an owning README
     and independent positive/negative corpus. This is a planned path, distinct
     from `contracts/application/Application.g4`. First cover every delivered
     import, dependency, interface, module, target, typed operand, expression,
     conditional and Table-test form in `APPLICATION_SOURCE_V1`; then extend it
     with each reviewed source feature. One source dialect serves builds/tests;
     semantic target checks enforce which constructs may execute in each stage.
   - Specify lexical rules, identifier quoting/case, comments, literal escapes,
     operator precedence/associativity, source spans, compound statements and
     typed holes. Reuse/factor the SQL reference productions where applicable;
     fully parse embedded SQL and reject malformed bodies, trailing tokens and
     source-only forms at ordinary SQL entry points. Lexer/parser recovery
     diagnostics fail the check; require full input consumption. Keep syntax acceptance
     distinct from type, budget, target-capability and runtime rejection.
   - Generate with pinned ANTLR and warnings as errors; require no reported
     ambiguities on the corpus using exact ambiguity detection. Compare normalized
     independent ASTs and locations with Zig, including malformed nesting and
     inert holes inside strings/comments, and check formatter round-trips.
     This does not establish global grammar unambiguity or semantic correctness.
   - Register a dedicated source-grammar task in the runner/affected clean lanes,
     diagnostic inventory and invariant inventory. Keep generated files in the
     ignored verification cache. Require grammar/corpus updates with language
     changes; publish source support separately from runtime SQL/interface support.
5. **Specify the typed core and verification boundary before richer lowering:**
   - Define nominal identities, variants/refinements, query cardinality, typed
     expression/command constructors, effect signatures, ownership/disclosure,
     transitions and named contracts. Classify each obligation as statically
     decidable, runtime-enforced or requiring a separately checked proof; unknown
     obligations cannot be assumed. Define supported SQL encodings or reject.
   - Specify explicit abstractions into temporal models and Lean semantics with
     independent properties and native correspondence obligations. Preserve one
     current-v1 contract identity through intentional incompatible cutovers;
     source-only additions do not imply a native-format change by themselves.

### `P1` — Recursive module resolution, package locks and encapsulation

**Owners:** [`contracts/DECLARATIVE_CATALOG_V1.md`](../../contracts/DECLARATIVE_CATALOG_V1.md), [`packages/zig/transit-catalog/src/DirectNamespace.zig`](../../packages/zig/transit-catalog/src/DirectNamespace.zig), [`packages/zig/transit-catalog/src/DirectCatalogDependencies.zig`](../../packages/zig/transit-catalog/src/DirectCatalogDependencies.zig), [`packages/zig/transit-fuze/src/SqlBinding.zig`](../../packages/zig/transit-fuze/src/SqlBinding.zig).

1. **Resolve local and repository modules through one typed graph:**
   - Implement child build imports, module-valued parameters/exports, package
     subdirectory selection, exact locks, explicit local overrides and frozen
     offline resolution. Report missing exports, interface mismatches, cycles,
     digest mismatches and undeclared inputs before SQL emission.
   - Separate package, module and instance identities from SQL schemas; bind
     stateful instances explicitly and reject conflicting dependency versions.
     Cache keys cover compiler/contract identity and all transitive inputs.
   - Check exported nominal/reference types, query cardinalities, effects and
     behavioral obligations. A helper accepting a command/module cannot erase
     its reads, authority requirements or disclosure effects. Sharing a reference
     does not instantiate storage again or permit access to private fields.
2. **Enforce source visibility and preserve runtime encapsulation:**
   - Check private/exported symbols during binding. Define catalog ownership and
     visibility evidence for runtime objects in the owning v1 contracts and
     represent it in emitted SQL; schema `USAGE` alone cannot bypass it.
   - Prove that exported procedure expansion preserves the callee's permitted
     operations under current caller rights without accepting forged module
     ownership. Ordinary SQL callers must not bypass any promised runtime
     encapsulation. Reuse `DirectCatalogDependencies` for actual runtime object
     dependencies without treating source imports as grants.

### `P2` — Compile-time `PROFILE`, `FUNCTION`, `GUARD` and inline `PROCEDURE` lowering

**Owners:** [`contracts/sql/TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4), [`packages/zig/transit-fuze/src/SqlLowering.zig`](../../packages/zig/transit-fuze/src/SqlLowering.zig), [`packages/zig/transit-fuze/src/ScalarProgram.zig`](../../packages/zig/transit-fuze/src/ScalarProgram.zig), [`packages/zig/transit-catalog/src/DeclarativeIngress.zig`](../../packages/zig/transit-catalog/src/DeclarativeIngress.zig).

1. **Implement `CREATE PROFILE ... FOR SOURCE | SINK | PUBLICATION` and `USING PROFILE`:**
   - Parse and validate typed option profiles, resolve `USING PROFILE <name>`
     during declaration lowering, merge explicit `WITH (...)` overrides, and
     emit expanded executable SQL. Verify that ordinary preparation yields the
     expected `SourceDeclaration` / `PublishedProjection` descriptors. Retain
     profile content digests in source/dependency provenance; any runtime
     provenance field needs its owning contract and an executable SQL encoding.
2. **Implement pure `CREATE [PUBLIC] FUNCTION` and `CREATE [PUBLIC] GUARD`:**
   - Evaluate typed module/declaration constructors with hygienic binding and
     deterministic recursion budgets. Expand pure scalar/row functions into
     executable SQL expressions using shared `ScalarProgram` semantics; reject
     unsupported runtime recursion separately from compile-time recursion.
   - Compile `CREATE GUARD` definitions into parameterized `REQUIRE` / `GUARD`
     predicate trees that preserve call-site and definition-site source spans
     and register all referenced tables/views/secrets in the guard read-set
     verifier.
3. **Implement transactional `CREATE [PUBLIC] PROCEDURE ... AS BEGIN ATOMIC ... END`:**
   - Support `CALL <schema>.<procedure>(...)` and `LET <var> = CALL <schema>.<procedure>(...)`
     inside `BEGIN ATOMIC` blocks.
   - Expand the procedure's bound statements into SQL within the caller's atomic
     transaction, with hygienic local variables and the runtime encapsulation
     evidence defined in `P1`. Verify that the callee only mutates its bound
     module instance's storage (or invokes further exported procedures) and
     contains no non-transactional `EXECUTE SINK` or `AWAIT OBSERVATION` steps.
4. **Lower typed operators and contracts through the same core:**
   - Add exhaustive variant matching, cardinality checks and the selected
     refinement constructors. Preserve type/error/refusal behavior, secret labels
     and complete transactional read/write sets through specialization/inlining.
     Retain persisted constraints and runtime obligations in executable SQL.
   - Establish a small Lean law for ordered guard expansion or atomic transition
     invariant preservation and independently compare generated SQL outcomes.
     Record correspondence assumptions; a proof about an abstract expander alone
     does not certify the production compiler.

### `P3` — Whole-program checking, SQL emission and `transit build`

**Owners:** [`packages/zig/transit-fuze/src/SqlCheck.zig`](../../packages/zig/transit-fuze/src/SqlCheck.zig), [`packages/zig/transit-catalog/`](../../packages/zig/transit-catalog), [`apps/transit-cli/`](../../apps/transit-cli). Source I/O and resolution belong to tooling; shared compiler semantics remain independent of Station.

1. **Build the multi-file working catalog and symbol table:**
   - Extend `transit-compiler`'s in-memory `WorkingCatalog`, using shared Fuze and
     Catalog type/definition owners, to ingest an
     ordered module graph or migration sequence, resolving all schemas, storage
     types, views, functions, guards, procedures, profiles, connections, sinks,
     sources, dataflows and publications in dependency order with explicit bounded
     passes. The semantic core receives resolved inputs without disk/network I/O;
     the tool owns source reads and explicit dependency fetching.
2. **Typecheck compound dataflow bodies and SQL expressions:**
   - Verify every `LET` binding, `SELECT ... INTO` / scalar subquery, `ROW(...)`
     field count and type, `PUT` / `INSERT` / `UPDATE` / `DELETE` column
     compatibility, `CASE` branch type unification, `FOR` loop cursor schema,
     and `RETURN` / `RESPOND` payload type.
   - Check nominal identity mismatches, incomplete variant matches, invalid
     refinement construction, one/optional/many cardinality and observation-basis
     mismatches. Apply `P0`'s effect and transition rules across the full graph;
     runtime checks remain mandatory for external inputs and current policy.
3. **Enforce linear `CAPABILITY` / `OPERATION` handling and `SECRET` taint rules:**
   - Run static control-flow graph (CFG) analysis over each `DATAFLOW` body:
     - Every path from entry (including early `REQUIRE ... ELSE` exits and
       `ON FAILURE` handlers) must settle inbound `CAPABILITY` (`request_ref`)
       and `OPERATION` (`native_ref`) handles exactly once (`UnsettledCapabilityOnPath`
       or `DoubleCapabilitySettlement` on violation).
     - Values derived from `SECRET(...)`, `DERIVE_SECRET(...)`, `RANDOM_SECRET(...)`,
       `HTTP_SECRET_*` or `SECRET_JSON_VALUE(...)` carry a `secret_tainted` flag;
       any flow into persistent column values, queue/stream payloads, or
       unprotected response fields fails compilation (`UnredactedSecretFlow`).
       Only contract-approved commitment/challenge operations may produce public
       values; `BEARER(...)`, cookie encodings and other protected values remain
       restricted to their designated disclosure sinks. Track explicit and
       control-dependent flows for the admitted profile; do not claim timing or
       general side-channel noninterference from taint tracking alone.
4. **Verify lifecycle activation order (`AUTHORIZE` / `ACTIVATE`):**
   - Statically reject any module or migration that activates an inbound
     `SOURCE` before its target `COMMAND` dataflow or queue-consuming
     `DATAFLOW`s and their required `SINK`s are authorized and activated.
5. **Expose `transit build` over `build.transit`:**
   - Support default/named targets, check-only compilation and structured
     [`DIAGNOSTICS_V1.md`](../../contracts/DIAGNOSTICS_V1.md) envelopes (file,
     line, column, module instance, definition/call site, rule and rewrite hint).
     Share source formatting with the compiler; settle exact option spellings
     in the CLI contract before implementation.
   - Emit deterministic SQL plus source/provenance mappings, reparse with ordinary
     statement compilers and compare bound definitions/plans. Execute output
     through ordinary clients without access to source packages. Reject unsupported
     target capabilities and incomplete output; test cache invalidation and
     diagnostics through nested and remote modules.

### `P4` — Desired-state-to-migration synthesizer, schema/definition diffing and `CREATE OR REPLACE` lifecycle

**Owners:** [`contracts/MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md), [`packages/zig/transit-catalog/src/DirectMigration.zig`](../../packages/zig/transit-catalog/src/DirectMigration.zig), [`packages/zig/transit-catalog/src/DirectDefinition.zig`](../../packages/zig/transit-catalog/src/DirectDefinition.zig), [`packages/zig/transit-sql-service/src/MigrationRunner.zig`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig).

1. **Extend `DirectMigration` and `MigrationRunner` with `CREATE OR REPLACE` for versioned definitions:**
   - Add `replace_view`, `replace_dataflow`, `replace_publication`, `replace_sink`
     and `replace_source` effects to `DirectMigration.StepEffect`, binding both
     `expected_prior_definition_sha256` and the new `object_definition` in
     `StepReceipt`.
   - Enforce the declared `on_replace` policy (`drain_active`, `pin_generation`,
     `require_idle`) when activating a replacement definition revision so
     in-flight queue leases and `OPERATION` continuations never execute against
     a mismatched definition revision.
2. **Implement structural catalog diffing (`CatalogDiff`) against an explicit basis:**
   - Compare the desired `WorkingCatalog` obtained by preparing emitted SQL from
     `.transit` against an explicit prior definition graph, including the state
     produced by offline replay of `migrations/*.sql`:
     - **Unchanged objects:** Emit no migration steps.
     - **New or replaced runtime definitions (`VIEW`, `DATAFLOW`, `SINK`, `SOURCE`, `PUBLICATION`, and other kinds with executable contracts):**
       Synthesize dependency-ordered `CREATE` or `CREATE OR REPLACE ... IF REVISION = ...`
       and explicitly requested `AUTHORIZE` / `ACTIVATE` steps. Erased helpers
       affect their emitted dependents rather than acquiring a second runtime
       identity merely because they exist in source.
     - **Additive storage changes (`CREATE TABLE/KV/DOCUMENT/STREAM/QUEUE`, `ALTER TABLE ADD COLUMN`):**
       Synthesize the canonical DDL step and verify lazy schema projection
       compatibility ([Milestone 10](10-standards-and-catalogs.md)).
     - **Destructive or ambiguous storage changes (column drop, type/collation rewrite, table split):**
       Refuse automatic synthesis with an actionable diagnostic requiring an
       explicit user-authored data-transform step or online rewrite plan
       ([Milestone 11](11-indexing-and-access-paths.md)) in the new migration file.
3. **Compose migration synthesis and verification as build targets:**
   - `build.transit` declares the desired composition, prior basis, transforms
     and migration output. `transit build` emits reviewable `<version>-<name>.sql`
     without applying it or rewriting previously recorded files.
   - Include nominal/variant representations, constraints, effects and transition
     contracts in the diff. Reject ambiguous state conversions; invalidate affected
     proof evidence and recheck replacement obligations without recompiling or
     changing the interpretation of already accepted work.
   - A verification target compares final logical fingerprints/definition digests
     between migration replay and emitted desired-state SQL under identical
     instance bindings. Integrate a bounded fixture in the fast checks; qualify
     real application execution separately. The existing `transit migrate`
     lifecycle plans/applies/resumes the frozen output and rejects live drift.

### `P5` — Deterministic SQL unit-test runner, sink/observation simulator and yield-point fault injector

**Owners:** [`packages/zig/transit-compiler/`](../../packages/zig/transit-compiler), [`packages/zig/transit-test/`](../../packages/zig/transit-test), [`packages/zig/transit-sql-service/`](../../packages/zig/transit-sql-service), [`apps/transit-cli/`](../../apps/transit-cli).

The [isolated Table profile](../../contracts/APPLICATION_SOURCE_V1.md#isolated-table-tests)
delivers item 1 for the existing compiler subset and typed row/count/refusal
assertions from item 3. The controls, broader SQL and replay schedules below
remain required to complete P5.

1. **Implement the `TEST ... USING MODULES (...) AS BEGIN ... END` grammar and in-process runner:**
   - Resolve `*.test.transit` suites through the same `build.transit` graph and
     production SQL emitter as build targets. Execute emitted SQL against an
     isolated in-memory/tempdir `DirectCatalog` + `DatabaseRuntime` instance.
     Keep test controls in the runner, and test nested/local/remote module
     compositions without listeners or containers. Measure startup rather than
     assuming a millisecond bound.
2. **Provide deterministic `SET TEST CLOCK`, `SET TEST SUBJECT`, `MOCK SINK` and `MOCK OBSERVATION` controls:**
   - Allow tests to control `NOW()` (`SET TEST CLOCK`, `ADVANCE TEST CLOCK BY`),
     switch caller identity and native grants (`SET TEST SUBJECT ... WITH GRANTS (...)`),
     invoke commands or enqueue requests (`INVOKE COMMAND`, `SIMULATE HTTP REQUEST`),
     and script external `SINK` and `AWAIT OBSERVATION` responses (including
     HTTP status/body, AWS stack/distribution/certificate states, DNS TXT
     replies, and `unknown` / timeout outcomes).
3. **Add `ASSERT` primitives and `--verify-replay` yield-point fault injection:**
   - Support `ASSERT <expr>`, `ASSERT COMMAND ... FAILS WITH '<ErrorCode>'`,
     `ASSERT WORKFLOW ... OUTCOME '<state>'`, and `ASSERT SINK <name> DISPATCH COUNT = <n>`.
   - In `--verify-replay` mode, automatically fork/snapshot execution at each
     `EXECUTE SINK`, `AWAIT OBSERVATION` and `BEGIN ATOMIC` step, inject
     simulated crash and unknown-outcome faults, and verify that replay
     (`ON REPLAY OBSERVE ONLY`) and `ON FAILURE` handlers preserve all
     tested invariants, reservations and observe-only replay. Unknown external
     outcomes remain unresolved; mocks do not prove provider idempotency.
4. **Execute selected language models, proofs and correspondence checks:**
   - Model the three synthetic language cases as small independent specifications
     where temporal behavior applies. Explore concurrent admission, revision and
     policy changes, capability transfer, crash/recovery and unknown effects.
     Require complete safe-model exploration and intended invariant failures from
     removed guards; parser/tool failures are not detected negative controls.
   - Replay counterexample schedules against real native owners and compare
     independent state/effect projections. State whether coverage is selected
     traces or every finite edge; neither implies unbounded implementation
     refinement. Keep provider/storage integration qualification separate.
   - Run the selected Lean core/lowering/transition proofs with explicit premises
     and audited axioms. Pin tooling and all evidence inputs, report missing or
     unsupported obligations, and preserve assumption changes across revisions.

### `P6` — Refactoring qualification on the multi-module application baseline and handbook promotion

**Owners:** [`docs/handbook/reference/applications.md`](../../docs/handbook/reference/applications.md), [`docs/handbook/reference/sql.md`](../../docs/handbook/reference/sql.md), [`contracts/MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md), [`tests/`](../../tests/README.md).

1. **Qualify recursive composition and repository reuse:**
   - Build a multi-package monorepo with independently buildable child
     `build.transit` modules, a pinned external repository package, a package
     subdirectory and an explicit local override. Repeat with a populated cache
     and networking disabled; compare SQL bytes and provenance.
   - Exercise higher-order module parameters, hygienic repeated instances,
     private/exported symbol failures, import cycles, evaluation/output budgets,
     content mismatches, cache invalidation and conflicting stateful versions.
     Move source paths without changing durable object bindings.
   - Run source ANTLR/Zig differential checks and formatter round-trips alongside
     the semantic suites. Require negative cases for wrong nominal IDs, unmatched
     variants, invalid cardinality, hidden effects, reordered refusals, duplicate
     handoff, secret disclosure and stale evidence at the appropriate layer.
2. **Qualify full SQL compilation and migration synthesis on the Platform workload:**
   - Express the seven-file baseline's six named domains (`auth`, `catalog`,
     `tenancy`, `networking`, `deployments`, `publication`) as `.transit` modules,
     replacing cross-module storage writes with exported procedures/views and
     factoring profiles, guards and operation admission.
   - Execute the emitted SQL through ordinary clients with source files absent;
     compare definitions and outcomes to hand-expanded SQL. Verify migration
     replay against the explicit prior basis, including dependency upgrades,
     destructive-change refusal, live drift and recovery after source changes.
   - Measure the original targets of more than 35% less duplication, check-only
     compilation below 500 ms, and build/test replay coverage of all 26 commands
     and 14 workflows below two seconds offline. Pin hardware, source inventory,
     cache state and fault schedules; these are evaluation targets, not measured
     guarantees. Missing cases or unresolved faults cannot pass.
3. **Promote implemented behavior to the public handbook and contracts:**
   - Update the source/build model, executable SQL boundary, package locks,
     visibility, diagnostics, migration and test profiles in
     [`applications.md`](../handbook/reference/applications.md),
     [`sql.md`](../handbook/reference/sql.md) and their exact owning contracts.
     Preserve existing interface-compiler behavior until an explicit cutover.
   - Publish the source grammar/support inventory and the type/effect/transition
     contracts with their limits. Record model bounds, Lean premises and actual
     implementation correspondence in the verification owners and proof ledger;
     passing grammar checks or documentation builds add no runtime proof.

---

## Coordination with adjacent milestones

| Milestone | Shared boundary | Handoff and non-duplication rule |
| --- | --- | --- |
| [M1](01-declarative-data-lifecycle.md)–[M5](05-transactions-and-atomic-composition.md) | `CatalogId`/`DefinitionId`/`ColumnId` identities, `.tseg` storage, `DirectCatalog`, `DirectMigration` (`TMD1`/`TMV1`) and serializable multi-Table transactions | M12 reuses `DirectCatalog`, `DirectMigration` and M5's transaction commit envelope; inline `PROCEDURE`s lower into the caller's M5/M6 atomic transaction without creating a second transaction coordinator or migration ledger. |
| [M6](06-streams-queues-and-durable-runtime.md) & [M7](07-document-storage-and-station-decoupling.md) | `STREAM`, `QUEUE` and `DOCUMENT` catalog primitives and mixed transactions | M12's module compiler, `CREATE OR REPLACE` lifecycle and `transit test` harness consume M6/M7's direct `StreamPartition`, `QueuePartition` and `DocumentPartition` owners directly. |
| [M8](08-gateway-architecture-and-protocol-ingress.md) & [M9](09-client-foundation-and-language-apis.md) | Co-hosted direct-plane HTTP/SQL ingress, command deadlines and `MigrationClient` | M12's `SOURCE` profiles and `MigrationClient` file-bound increases plug directly into M8's co-hosted command ingress and M9's shared SQL client. |
| [M10](10-standards-and-catalogs.md) & [M11](11-indexing-and-access-paths.md) | `DirectDefinition` (`TCDESC01`), `CHECK`/`FOREIGN KEY` dependency graph, lazy schema projection and online phased rewrites | M12's migration synthesizer uses M10's `logicalFingerprint` and lazy-projection rules to classify additive vs. rewrite DDL, and delegates physical table rewrites to M11's online rewrite lifecycle. |
| [M13](13-sql-and-dataflows.md) | Managed computations, WAL-activated DBSP dataflows and 5-state lifecycle (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) | M12 owns recursive `.transit` source composition and SQL emission, static type/capability/secret checking, compile-time `PROFILE`/`GUARD`/`PROCEDURE` lowering, `CREATE OR REPLACE` revision migration and offline unit testing; M13 owns runtime WAL-driven incremental dataflow execution, analytical SQL operators and bitemporal `AS OF JOIN`. |
| [M16](16-data-centric-compilation-and-specialization.md) | Shared build graph, executable SQL and AOT targets | M12 owns recursive `.transit` composition and canonical `.sql` emission; M16 extends `transit build` with optional specialization/AOT outputs from the same bound SQL semantics, without a separate module system or runtime authority. |
| [M21](21-branches-merges-and-restore.md) & [M30](30-reviewed-data-collaboration.md) | Catalog/schema diffing (`DIFF_SCHEMA`) and reviewed branch proposals | M12's offline module-to-migration synthesizer shares the canonical schema/definition diff representation extended across branches and remotes in M21 and M30. |
| [M23](23-formal-semantics-and-correspondence.md) | Temporal models, Lean semantics and implementation correspondence | M12 delivers the language-specific models, selected lowering/transition theorems and native trace checks with each admitted construct. M23 extends systematic coverage and composition; it is not a reason to defer these language correctness gates. Reuse the existing model harness, invariant inventory and proof ledger. |
| [M28](28-control-and-policy-plane.md) & [M29](29-published-resources-and-investigations.md) | Declarative `SECRET` catalog, OAuth2/PKCE flows and `PUBLICATION` disclosure policies | M12 enforces static `SECRET` taint analysis and compiles `CREATE PROFILE ... FOR PUBLICATION` templates consumed by M28 and M29. |
| [M31](31-board-reimplementation.md) | Board inspection and module/lineage visualization | Board inspects module boundaries, `PUBLIC`/`PRIVATE` definitions, profile provenance and `CREATE OR REPLACE` revision histories read-only through shared catalog operations. |
| [M44](44-sql-grammar-and-dialect-ergonomics.md) | Pre-release grammar harmonization and `FROM`-first / dialect ergonomics | M12 delivers independent source ANTLR grammar, source/build/test stage checks, Zig AST comparisons, formatter round-trips and SQL emission. M44 audits their composition with the complete dialect and shared productions; it does not own the first source grammar. Grammar generation alone does not prove unambiguity or execution. |

---

## Completion evidence

The delivered compiler and Table-test slices establish only the bounded evidence
linked above. Every row still requires its full journey, including capabilities
outside those profiles; this plan and documentation checks establish no runtime
result. Record performance against the pinned conditions in `P6`.

| Journey | Required executable evidence |
| --- | --- |
| **Formalize source syntax (`P0`, `P6`)** | Every delivered source/build/test form has a checked ANTLR production and positive/negative corpus. Pinned generation, ambiguity diagnostics, independent AST/location agreement, formatter round-trips and runtime rejection of source-only forms pass; grammar-only and unsupported semantics remain explicit. |
| **Check types, effects and transitions (`P1`–`P3`)** | Synthetic typed-target, one-use admission and capacity cases preserve nominal identities, variant exhaustiveness, cardinality, ordered guards, atomic state/output, ownership, protected disclosure and explicit uncertainty. Unsupported runtime obligations reject before output; current authorization and evidence validation remain enforced at execution. |
| **Connect contracts to formal evidence (`P2`, `P5`, `P6`)** | Selected TLA+ configurations finish with stated bounds/assumptions; negative controls fail their intended invariants and traces replay against native owners. Selected Lean core/lowering/transition theorems pass with audited premises/axioms and no unfinished proofs. Evidence names exact artifacts and correspondence limits; no claim of universal compiler/runtime verification follows. |
| **Resolve recursive builds and packages (`P0`, `P1`, `P6`)** | Root and child `build.transit` files use the same dialect and typed module interfaces. A monorepo, external repository/subdirectory and local override produce deterministic SQL under locked offline rebuilds; stale/missing locks, digest mismatches, undeclared imports, cycles and conflicting stateful versions reject with source locations. |
| **Bound evaluation and preserve identity (`P1`, `P2`)** | Higher-order and recursive constructors preserve hygiene; depth/work/memory/output exhaustion rejects without complete artifacts. Source relocation preserves durable bindings; explicit repeated instances remain distinct. Compiler, dependency, option and binding changes invalidate affected cache entries. |
| **Scan and check whole programs (`P0`, `P3`)** | Compound files above 50 KiB with nested `BEGIN ATOMIC`, `ON FAILURE`, `IF`, `CASE` and `FOR` never split at internal semicolons. Type errors, unsettled capabilities, secret leaks and invalid activation ordering report definition/call sites without network access. |
| **Execute generated SQL independently (`P2`, `P3`)** | Reparse emitted `.sql` and compare canonical definitions/plans and ordered outcomes with hand-expanded equivalents. Ordinary clients execute it with source packages absent; unsupported runtime constructs reject at build time. Revocation after compilation, atomicity, stable bindings and runtime encapsulation remain enforced. |
| **Synthesize and verify migration outputs (`P4`)** | A build target with an explicit prior basis emits ordered SQL for additive and supported definition changes. Replay matches desired logical fingerprints/digests; ambiguous or destructive transitions require explicit transforms. Dependency upgrades do not apply themselves. Recorded migration bytes and original outcomes survive source/compiler changes and lost replies. |
| **Replace running definitions safely (`P4`, `D5`)** | Applying replacement while queue leases and operations are in flight preserves their prior definition basis or drains/fences under the selected policy. Restart and uncertain replies never reinterpret accepted work. |
| **Run tests through the production emitter (`P5`)** | `transit test` reads the same graph and executes SQL generated from `*.test.transit`. Clock/effect controls remain runner-only. Replay sweeps preserve reservations, observe-only recovery and known terminal outcomes; unresolved external outcomes remain explicit. Real provider/durability qualification remains separate. |

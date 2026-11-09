# 12. Declarative application modules, compilation, migration synthesis and testing

[Roadmap](README.md) · **Status:** Planned

Let an application organize its declarative SQL definitions, dataflows, effect
bindings and publications as encapsulated, dependency-checked modules; reuse
compile-time profiles, pure functions, guards and transactional procedures
without repeating boilerplate; compile and typecheck the whole program offline;
synthesize or verify immutable migration plans from desired module state; and
run fast, deterministic local unit and fault-injection tests before touching a
live cluster or cloud provider.

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
| **4. Statement-level scanner limits and late runtime planning** | [`MigrationClient.loadSourceFile`](../../packages/zig/transit-sql-client/src/MigrationClient.zig) validates whole migration files against `Sql.validateText`'s 4,096-byte single-statement ceiling (`StatementTooLarge` on the 19.5 KiB `0001-auth.sql`). [`MigrationRunner.splitStatements`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig) splits on `;` whenever parenthesis `depth == 0`, breaking on semicolons inside `CREATE DATAFLOW ... AS BEGIN ... END;` compound bodies. Semantic validation happens only when planning against a live catalog. | Authors cannot run a fast, offline whole-program compiler (`transit app check`) that resolves cross-schema imports, typechecks `LET` bindings and `ROW(...)` fields, verifies `CAPABILITY` response/handoff completeness, and prevents `SECRET` taint leaks before starting a server or container. |
| **5. No unit-test harness or deterministic effect/clock simulator** | Testing a command (`deployments.prepare_candidate`) or multi-step workflow (`auth.complete_github_signin`, `networking.issue_certificate`) currently requires standing up a live process or container harness and exercising full wire/provider paths. | Developers cannot unit-test individual dataflows in milliseconds with deterministic clocks (`ADVANCE CLOCK`), stubbed `SINK` outcomes and `AWAIT OBSERVATION` replies, or automated crash/replay fault injection across `BEGIN ATOMIC` and effect yield points. |

## Architectural decisions (`D1`–`D6`)

### `D1` — Separate logical module source (`modules/<schema>/*.sql`) from immutable migration ledger artifacts (`migrations/<version>-<name>.sql`)

- **Two distinct representations with one durable authority:** Developers author
  and maintain a logically organized module tree (`modules/<schema>/`) that
  describes the **desired state** of each domain (`schema.sql`, `views.sql`,
  `commands.sql`, `workflows.sql`, `sinks.sql`, `sources.sql`,
  `publications.sql`), while [`DirectMigration`](../../packages/zig/transit-catalog/src/DirectMigration.zig)
  (`TMD1`/`TMV1`) remains the single durable execution ledger over ordered,
  immutable `migrations/<version>-<name>.sql` files. No second migration ledger
  or runtime source loader is introduced.
- **Stateful storage transitions vs. versioned definition replacements:**
  - **Stateful storage objects** (`TABLE`, `KV`, `DOCUMENT`, `STREAM`, `QUEUE`)
    hold durable data whose physical or logical layout changes require explicit
    `CREATE`, `ALTER`, `DROP` or data-backfill steps in a migration version.
  - **Code and interface definitions** (`VIEW`, `PUBLICATION`, `DATAFLOW`,
    `SINK`, `SOURCE`, `FUNCTION`, `GUARD`, `PROCEDURE`, `PROFILE`) are
    versioned catalog interpretations bound to immutable `DefinitionId` and
    content digests ([`DirectDefinition.zig`](../../packages/zig/transit-catalog/src/DirectDefinition.zig),
    [`ManagedDataflow.zig`](../../packages/zig/transit-catalog/src/ManagedDataflow.zig)).
    When edited in the module tree, the compiler synthesizes deterministic
    `CREATE OR REPLACE <KIND> <name> ... IF REVISION = <prior_digest>` steps in
    the next migration file, updating the active definition revision atomically
    while preserving historical receipts and prior definition provenance.
- **Compiler-verified round-trip equivalence:** Replaying `migrations/0001-*.sql`
  through `migrations/NNNN-*.sql` in the offline catalog simulator must produce
  a catalog definition graph with the **exact same `logicalFingerprint` and
  definition digests** as compiling `modules/**.sql` from scratch. Uncovered
  module edits or hand-edited migration drift fail `transit app verify-migrations`
  in `just check fast`.

### `D2` — Elevate `SCHEMA` into an encapsulated module with `PUBLIC` / `PRIVATE` visibility and explicit `IMPORT` interfaces

- **Explicit dependency DAG (`IMPORT SCHEMA`):** Each schema module declares its
  direct schema dependencies at the module header (`ALTER SCHEMA deployments
  IMPORT (tenancy, networking);` or in the module manifest), establishing a
  statically checked, acyclic module dependency graph (`tenancy` $\leftarrow$
  `networking` $\leftarrow$ `deployments`, `tenancy` $\leftarrow$ `publication`
  $\leftarrow$ `networking`). Cyclic schema dependencies and undeclared
  cross-schema references reject at compile time.
- **Encapsulated storage by default (`PRIVATE` vs. `PUBLIC`):**
  - Within a module, storage objects (`TABLE`, `KV`, `DOCUMENT`, `STREAM`,
    `QUEUE`), internal helper views, work queues, and sinks default to
    **module-private (`PRIVATE`)** visibility unless explicitly marked `PUBLIC`
    (or `EXPORT`).
  - External modules may **never** execute direct `INSERT`, `UPDATE`, `DELETE`,
    `PUT` or `ENQUEUE` statements against another module's `TABLE`, `KV`,
    `DOCUMENT` or `QUEUE`, even when granted schema `USAGE`.
  - Cross-module reads must target `PUBLIC VIEW`s or `PUBLIC FUNCTION`s (which
    expose a stable logical projection decoupled from physical table columns),
    and cross-module state mutations must invoke `PUBLIC PROCEDURE`s (for
    example, `CALL networking.attach_consumer(network.id, id, 'transit_instance')`
    and `CALL networking.release_consumer(instance.id, 'transit_instance')`
    instead of `deployments` directly mutating `networking.attachments`).

### `D3` — Composable compile-time abstractions (`PROFILE`, `FUNCTION`, `GUARD`, `PROCEDURE`)

Provide four zero-overhead, compile-time abstractions that desugar after name
resolution and schema binding into canonical `Fuze` plans and `DirectCatalog`
descriptors—adding zero runtime dynamic dispatch, hidden actor turns, or
implicit authority:

1. **Reusable option profiles (`CREATE PROFILE ... FOR SOURCE | SINK | PUBLICATION`):**
   Factor shared transport, authentication, framing, pagination and recovery
   policies into named, schema-qualified profiles:
   ```sql
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
   conflicting keys before emitting the canonical `SourceDeclaration` or
   `PublishedProjection`.
2. **Pure scalar and row functions (`CREATE [PUBLIC] FUNCTION`):**
   Deterministic, side-effect-free typed functions over scalar and `ROW(...)`
   values (e.g., digest computation, URI/key formatting, status mapping) that
   inline into `Fuze` scalar programs (`ScalarProgram.zig`) with full five-state
   (`value`, `null`, `missing`, `type_error`, `conflict`) and checked-arithmetic
   propagation.
3. **Named invariant and authority guards (`CREATE [PUBLIC] GUARD`):**
   Parameterized predicate + refusal-code bundles that can be invoked in both
   `REQUIRE <guard>(...)` statements and `EXECUTE SINK ... GUARD <guard>(...)` /
   `AWAIT OBSERVATION ... GUARD <guard>(...)` clauses:
   ```sql
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
   their full read-set basis for native guard verification.
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

### `D4` — Block-aware scanner and offline whole-program static compiler (`transit app check`)

- **Block-aware lexical splitting and application-sized file bounds:**
  Upgrade [`SqlInput.zig`](../../packages/zig/transit-fuze/src/SqlInput.zig) and
  [`MigrationRunner.splitStatements`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig)
  to track compound lexical block depth across `BEGIN [ATOMIC] ... [ON FAILURE ...] END`,
  `CASE ... END [CASE]`, `IF ... THEN ... [ELSIF ...] [ELSE ...] END IF`, and
  `FOR ... IN ... DO ... END FOR` in addition to parenthesis depth, while
  separating single interactive statement limits (4,096–65,536 bytes) from
  multi-statement module/migration file limits (up to 1 MiB per file and 512
  steps per migration version, with bounded scratch memory).
- **Offline whole-program semantic validation and linear capability checking:**
  Provide an offline compiler (`transit app check --dir <path>`) in
  [`transit-fuze`](../../packages/zig/transit-fuze/src/root.zig) and
  [`transit-station-app`](../../packages/zig/transit-station-app/README.md) that
  validates an entire multi-module application without a running server:
  1. **Dependency & symbol resolution:** Resolve all `SCHEMA`, `TABLE`, `KV`,
     `DOCUMENT`, `STREAM`, `QUEUE`, `VIEW`, `FUNCTION`, `GUARD`, `PROCEDURE`,
     `PROFILE`, `CONNECTION`, `SINK`, `SOURCE`, `DATAFLOW` and `PUBLICATION`
     references across the module graph; verify `PUBLIC`/`PRIVATE` visibility
     and `AUTHORIZE`/`ACTIVATE` ordering (every `SOURCE` must activate after its
     target `COMMAND` or `QUEUE` consumers are authorized and activated).
  2. **Strict type & 5-state checking:** Typecheck every `LET` binding,
     `SELECT` projection, `ROW(...)` constructor, `PUT`/`INSERT`/`UPDATE`
     target, `JSON_OBJECT` call and `RETURN` value against bound `ColumnId`
     types ($\tau$), collations ($\kappa$) and nullability.
  3. **Linear `CAPABILITY` & `OPERATION` lifecycle analysis:** Verify on every
     control-flow path (including `IF`/`ELSE` branches and `ON FAILURE` blocks)
     that each inbound `CAPABILITY` (`request_ref`) and `OPERATION` (`native_ref`)
     is consumed **at most once** and **never leaked**—every path must terminate
     in `RESPOND TO`, `RESPOND ERROR TO`, `HANDOFF ... TO`, `COMPLETE OPERATION`,
     or `PRESERVE OPERATION`.
  4. **Information-flow & `SECRET` taint analysis:** Track `SECRET(...)`,
     `DERIVE_SECRET(...)`, `RANDOM_SECRET(...)`, `HTTP_SECRET_*` and
     `SECRET_JSON_VALUE(...)` values as tainted `Secret<T>` types that may only
     flow into `COMMITMENT(...)`, `S256(...)`, `SECURE_EQUAL(...)`,
     `BEARER(...)`, `SET COOKIE ... VALUE`, or `EXECUTE SINK` protected
     fields—statically rejecting any attempt to store raw secret bytes in a
     `TABLE`, `KV`, `DOCUMENT`, `STREAM`, `QUEUE` or unredacted `RESPOND` body.

### `D5` — Safe live evolution of definitions (`CREATE OR REPLACE`) and in-flight generation draining

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

- **Container-free declarative test runner (`*.test.sql`):**
  Let developers write fast, hermetic unit and property tests alongside each
  module (`modules/auth/auth.test.sql`, `modules/deployments/instances.test.sql`)
  executed by `transit test` over an in-process, zero-network `DatabaseRuntime`
  + `DirectCatalog` instance:
  ```sql
  -- modules/tenancy/tenancy.test.sql
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
  prove that no external sink is dispatched twice, no reservation or cloud
  resource binding is dropped on `unknown` outcome, and the terminal state is
  identical.

---

## Delivery sequence and implementation plan (`P0`–`P6`)

### `P0` — Block-aware statement scanner, application-sized bounds and module manifest contract

**Owners:** [`contracts/MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md), [`packages/zig/transit-fuze/src/SqlInput.zig`](../../packages/zig/transit-fuze/src/SqlInput.zig), [`packages/zig/transit-sql-service/src/MigrationRunner.zig`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig), [`packages/zig/transit-sql-client/src/MigrationClient.zig`](../../packages/zig/transit-sql-client/src/MigrationClient.zig), [`packages/zig/transit-catalog/src/DirectMigration.zig`](../../packages/zig/transit-catalog/src/DirectMigration.zig).

1. **Extend `SqlInput` and `MigrationRunner.splitStatements` for compound SQL blocks:**
   - Track lexical block nesting across `BEGIN [ATOMIC] ... END`, `CASE ... END [CASE]`,
     `IF ... END IF`, and `FOR ... END FOR` tokens so internal statement-terminating
     semicolons inside `CREATE DATAFLOW`, `CREATE PROCEDURE`, `CREATE FUNCTION`
     and `TEST` bodies are never misclassified as top-level migration step
     boundaries.
   - Preserve exact 1-based `(line, column, byte_offset)` coordinates for both
     the enclosing declaration and each inner statement inside a compound block.
2. **Separate single-statement interactive limits from migration/module file limits:**
   - Keep `Sql.max_Interactive_statement_bytes` bounded for ad-hoc wire queries
     while raising `MigrationClient.loadSourceFile` and `MigrationRunner` source
     file bounds to `max_migration_file_bytes = 1024 * 1024` (1 MiB) and
     `DirectMigration.max_steps = 256` per version, using caller-supplied
     bounded scratch arenas so memory residency stays $O(\text{single statement})$
     during scanning.
3. **Define the application module manifest (`transit.application.modules.v1`):**
   - Specify the directory layout and deterministic file-ordering rules for a
     modular SQL application (`modules/<schema>/{schema,profiles,functions,guards,procedures,views,sinks,commands,workflows,sources,publications}.sql`),
     mapping each module to its owning SQL `SCHEMA` and declared `IMPORT`
     dependencies.

### `P1` — Schema module encapsulation, `PUBLIC` / `PRIVATE` visibility and cross-module dependency DAG

**Owners:** [`contracts/DECLARATIVE_CATALOG_V1.md`](../../contracts/DECLARATIVE_CATALOG_V1.md), [`packages/zig/transit-catalog/src/DirectNamespace.zig`](../../packages/zig/transit-catalog/src/DirectNamespace.zig), [`packages/zig/transit-catalog/src/DirectCatalogDependencies.zig`](../../packages/zig/transit-catalog/src/DirectCatalogDependencies.zig), [`packages/zig/transit-fuze/src/SqlBinding.zig`](../../packages/zig/transit-fuze/src/SqlBinding.zig).

1. **Add `IMPORT` declarations and cycle detection to `DirectNamespace`:**
   - Extend `CREATE SCHEMA <name> AUTHORIZATION ... [IMPORT (<schema>, ...)]`
     and `ALTER SCHEMA <name> IMPORT (<schema>, ...)` to record explicit
     cross-schema dependency edges in `DirectCatalogDependencies`.
   - Reject undeclared cross-schema references and cyclic schema imports before
     admission with a structured diagnostic naming the offending reference cycle.
2. **Enforce `PUBLIC` vs. `PRIVATE` visibility across schemas:**
   - Persist `visibility: enum { private, public }` on catalog descriptors
     (`TableMetadata`, `DirectKV`, `DirectDocument`, `DirectStream`,
     `DirectQueue`, `CatalogDefinition`, `ManagedDataflow`, `SourceDeclaration`).
   - Enforce in `SqlBinding` and `DatabaseRuntime` that cross-schema `INSERT`,
     `UPDATE`, `DELETE`, `PUT` and `ENQUEUE` on another schema's storage objects
     are rejected at compile/prepare time (`CrossModuleStorageMutationForbidden`),
     and cross-schema `SELECT` / `CALL` is permitted only on objects declared
     `PUBLIC` in an imported schema.

### `P2` — Compile-time `PROFILE`, `FUNCTION`, `GUARD` and inline `PROCEDURE` lowering

**Owners:** [`contracts/sql/TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4), [`packages/zig/transit-fuze/src/SqlLowering.zig`](../../packages/zig/transit-fuze/src/SqlLowering.zig), [`packages/zig/transit-fuze/src/ScalarProgram.zig`](../../packages/zig/transit-fuze/src/ScalarProgram.zig), [`packages/zig/transit-catalog/src/DeclarativeIngress.zig`](../../packages/zig/transit-catalog/src/DeclarativeIngress.zig).

1. **Implement `CREATE PROFILE ... FOR SOURCE | SINK | PUBLICATION` and `USING PROFILE`:**
   - Parse and validate typed option profiles, resolve `USING PROFILE <name>`
     during declaration lowering, merge explicit `WITH (...)` overrides, and
     emit canonical `SourceDeclaration` / `PublishedProjection` descriptors with
     both the expanded options and the bound `profile_definition_digest` for
     provenance and drift detection.
2. **Implement pure `CREATE [PUBLIC] FUNCTION` and `CREATE [PUBLIC] GUARD`:**
   - Compile pure scalar/row functions into reusable `ScalarProgram` fragments
     with static parameter/return type checking and recursion rejection.
   - Compile `CREATE GUARD` definitions into parameterized `REQUIRE` / `GUARD`
     predicate trees that preserve call-site and definition-site source spans
     and register all referenced tables/views/secrets in the guard read-set
     verifier.
3. **Implement transactional `CREATE [PUBLIC] PROCEDURE ... AS BEGIN ATOMIC ... END`:**
   - Support `CALL <schema>.<procedure>(...)` and `LET <var> = CALL <schema>.<procedure>(...)`
     inside `BEGIN ATOMIC` blocks.
   - Inline the procedure's bound statements into the caller's atomic transaction
     plan with hygienic local variable scoping, verifying that the callee only
     mutates tables owned by its declaring schema (or invokes further exported
     procedures) and contains no non-transactional `EXECUTE SINK` or
     `AWAIT OBSERVATION` steps.

### `P3` — Whole-program static typechecker, capability/secret flow analysis and `transit app check`

**Owners:** [`packages/zig/transit-fuze/src/SqlCheck.zig`](../../packages/zig/transit-fuze/src/SqlCheck.zig), [`packages/zig/transit-station-app/README.md`](../../packages/zig/transit-station-app/README.md), [`apps/transit-cli/`](../../apps/transit-cli).

1. **Build the multi-file working catalog and symbol table:**
   - Construct an in-memory `WorkingCatalog` in `transit-fuze` that ingests an
     ordered module graph or migration sequence, resolving all schemas, storage
     types, views, functions, guards, procedures, profiles, connections, sinks,
     sources, dataflows and publications in one pass with zero disk or network I/O.
2. **Typecheck compound dataflow bodies and SQL expressions:**
   - Verify every `LET` binding, `SELECT ... INTO` / scalar subquery, `ROW(...)`
     field count and type, `PUT` / `INSERT` / `UPDATE` / `DELETE` column
     compatibility, `CASE` branch type unification, `FOR` loop cursor schema,
     and `RETURN` / `RESPOND` payload type.
3. **Enforce linear `CAPABILITY` / `OPERATION` handling and `SECRET` taint rules:**
   - Run static control-flow graph (CFG) analysis over each `DATAFLOW` body:
     - Every path from entry (including early `REQUIRE ... ELSE` exits and
       `ON FAILURE` handlers) must settle inbound `CAPABILITY` (`request_ref`)
       and `OPERATION` (`native_ref`) handles exactly once (`UnsettledCapabilityOnPath`
       or `DoubleCapabilitySettlement` on violation).
     - Values derived from `SECRET(...)`, `DERIVE_SECRET(...)`, `RANDOM_SECRET(...)`,
       `HTTP_SECRET_*` or `SECRET_JSON_VALUE(...)` carry a `secret_tainted` flag;
       any flow into persistent column values, queue/stream payloads, or
       unprotected response fields fails compilation (`UnredactedSecretFlow`)
       unless wrapped in `COMMITMENT(...)`, `S256(...)`, `BEARER(...)` or an
       explicitly designated `SET COOKIE` / protected sink field.
4. **Verify lifecycle activation order (`AUTHORIZE` / `ACTIVATE`):**
   - Statically reject any module or migration that activates an inbound
     `SOURCE` before its target `COMMAND` dataflow or queue-consuming
     `DATAFLOW`s and their required `SINK`s are authorized and activated.
5. **Expose `transit app check` and `transit app format`:**
   - Provide `transit app check --dir <modules_or_migrations>` with `--diagnostics=json`
     emitting structured [`DIAGNOSTICS_V1.md`](../../contracts/DIAGNOSTICS_V1.md)
     envelopes (file, line, column, module, declaration, rule and rewrite hint).

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
2. **Implement structural catalog diffing (`CatalogDiff`) between module state and migration history:**
   - Compare the compiled `WorkingCatalog` of `modules/**.sql` against the
     catalog state produced by replaying `migrations/*.sql`:
     - **Unchanged objects:** Emit no migration steps.
     - **New or replaced `PROFILE` / `FUNCTION` / `GUARD` / `PROCEDURE` / `VIEW` / `DATAFLOW` / `SINK` / `SOURCE` / `PUBLICATION` definitions:**
       Synthesize dependency-ordered `CREATE` or `CREATE OR REPLACE ... IF REVISION = ...`
       and `AUTHORIZE` / `ACTIVATE` steps automatically.
     - **Additive storage changes (`CREATE TABLE/KV/DOCUMENT/STREAM/QUEUE`, `ALTER TABLE ADD COLUMN`):**
       Synthesize the canonical DDL step and verify lazy schema projection
       compatibility ([Milestone 10](10-standards-and-catalogs.md)).
     - **Destructive or ambiguous storage changes (column drop, type/collation rewrite, table split):**
       Refuse automatic synthesis with an actionable diagnostic requiring an
       explicit user-authored data-transform step or online rewrite plan
       ([Milestone 11](11-indexing-and-access-paths.md)) in the new migration file.
3. **Deliver `transit migrate synthesize` and `transit migrate verify-modules`:**
   - `transit migrate synthesize --modules <dir> --migrations <dir> --name <slug>`
     generates the next `<NNNN>-<slug>.sql` migration file in canonical format.
   - `transit migrate verify-modules --modules <dir> --migrations <dir>` verifies
     in CI (`just check fast`) that replaying `migrations/*.sql` is
     fingerprint-identical to compiling `modules/**.sql`.

### `P5` — Deterministic SQL unit-test runner, sink/observation simulator and yield-point fault injector

**Owners:** [`packages/zig/transit-sql-service/`](../../packages/zig/transit-sql-service), [`apps/transit-cli/`](../../apps/transit-cli).

1. **Implement the `TEST ... USING MODULES (...) AS BEGIN ... END` grammar and in-process runner:**
   - Execute `*.test.sql` suites against a fast, isolated in-memory/tempdir
     `DirectCatalog` + `DatabaseRuntime` instance that boots the selected
     modules (and their transitive `IMPORT` closure) in milliseconds without
     starting network listeners or external containers.
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
     invariants, reservations and single-dispatch guarantees.

### `P6` — Refactoring qualification on the multi-module application baseline and handbook promotion

**Owners:** [`docs/handbook/reference/applications.md`](../../docs/handbook/reference/applications.md), [`docs/handbook/reference/sql.md`](../../docs/handbook/reference/sql.md), [`contracts/MIGRATION_V1.md`](../../contracts/MIGRATION_V1.md), [`tests/`](../../tests/README.md).

1. **Qualify full modular compilation and migration synthesis on the 7-schema Platform workload:**
   - Express the complete 7-schema (`auth`, `catalog`, `tenancy`, `networking`,
     `deployments`, `publication`) application as encapsulated modules using
     `IMPORT`, `PUBLIC`/`PRIVATE` visibility (replacing direct cross-schema
     table writes on `networking.attachments` and `networking.target_holds` with
     exported `networking` procedures/views), `CREATE PROFILE` for HTTP sources
     and publications, `CREATE GUARD` for authority/revision checks, and
     `CREATE PROCEDURE` for operation admission.
   - Verify that compiling the modular source tree synthesizes a migration plan
     with identical logical schema and definition fingerprints, reduces source
     duplication by $>35\%$, and passes `transit app check` and `transit test
     --verify-replay` across all 26 commands and 14 workflows in $<2\text{ seconds}$
     offline.
2. **Promote current behavior to the public handbook and contracts:**
   - Document module organization, visibility rules, profiles/functions/guards/procedures,
     migration synthesis, `CREATE OR REPLACE` semantics and `transit test` in
     [`applications.md`](../../docs/handbook/reference/applications.md) and
     [`sql.md`](../../docs/handbook/reference/sql.md).

---

## Coordination with adjacent milestones

| Milestone | Shared boundary | Handoff and non-duplication rule |
| --- | --- | --- |
| [M1](01-declarative-data-lifecycle.md)–[M5](05-transactions-and-atomic-composition.md) | `CatalogId`/`DefinitionId`/`ColumnId` identities, `.tseg` storage, `DirectCatalog`, `DirectMigration` (`TMD1`/`TMV1`) and serializable multi-Table transactions | M12 reuses `DirectCatalog`, `DirectMigration` and M5's transaction commit envelope; inline `PROCEDURE`s lower into the caller's M5/M6 atomic transaction without creating a second transaction coordinator or migration ledger. |
| [M6](06-streams-queues-and-durable-runtime.md) & [M7](07-document-storage-and-station-decoupling.md) | `STREAM`, `QUEUE` and `DOCUMENT` catalog primitives and mixed transactions | M12's module compiler, `CREATE OR REPLACE` lifecycle and `transit test` harness consume M6/M7's direct `StreamPartition`, `QueuePartition` and `DocumentPartition` owners directly. |
| [M8](08-gateway-architecture-and-protocol-ingress.md) & [M9](09-client-foundation-and-language-apis.md) | Co-hosted direct-plane HTTP/SQL ingress, command deadlines and `MigrationClient` | M12's `SOURCE` profiles and `MigrationClient` file-bound increases plug directly into M8's co-hosted command ingress and M9's shared SQL client. |
| [M10](10-standards-and-catalogs.md) & [M11](11-indexing-and-access-paths.md) | `DirectDefinition` (`TCDESC01`), `CHECK`/`FOREIGN KEY` dependency graph, lazy schema projection and online phased rewrites | M12's migration synthesizer uses M10's `logicalFingerprint` and lazy-projection rules to classify additive vs. rewrite DDL, and delegates physical table rewrites to M11's online rewrite lifecycle. |
| [M13](13-sql-and-dataflows.md) | Managed computations, WAL-activated DBSP dataflows and 5-state lifecycle (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`) | M12 owns modular source organization, static type/capability/secret checking, compile-time `PROFILE`/`GUARD`/`PROCEDURE` lowering, `CREATE OR REPLACE` revision migration and offline unit testing; M13 owns runtime WAL-driven incremental dataflow execution, analytical SQL operators and bitemporal `AS OF JOIN`. |
| [M16](16-data-centric-compilation-and-specialization.md) | Data-centric push fusion and `transit-app` AOT Zig query compilation | M12 lowers modules, functions, guards and procedures to canonical `Fuze` plans and `DirectCatalog` descriptors; M16 compiles hot `Fuze` plans to specialized machine stencils or AOT Zig modules. |
| [M21](21-branches-merges-and-restore.md) & [M30](30-reviewed-data-collaboration.md) | Catalog/schema diffing (`DIFF_SCHEMA`) and reviewed branch proposals | M12's offline module-to-migration synthesizer shares the canonical schema/definition diff representation extended across branches and remotes in M21 and M30. |
| [M28](28-control-and-policy-plane.md) & [M29](29-published-resources-and-investigations.md) | Declarative `SECRET` catalog, OAuth2/PKCE flows and `PUBLICATION` disclosure policies | M12 enforces static `SECRET` taint analysis and compiles `CREATE PROFILE ... FOR PUBLICATION` templates consumed by M28 and M29. |
| [M31](31-board-reimplementation.md) | Board inspection and module/lineage visualization | Board inspects module boundaries, `PUBLIC`/`PRIVATE` definitions, profile provenance and `CREATE OR REPLACE` revision histories read-only through shared catalog operations. |
| [M44](44-sql-grammar-and-dialect-ergonomics.md) | Pre-release grammar harmonization and `FROM`-first / dialect ergonomics | M12's `IMPORT`, `PUBLIC`/`PRIVATE`, `PROFILE`, `FUNCTION`, `GUARD`, `PROCEDURE`, `CREATE OR REPLACE` and `TEST` productions are integrated into [`TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4) with zero ANTLR ambiguity and audited in M44. |

---

## Completion evidence

| Journey | Required executable evidence |
| --- | --- |
| **Scan and compile compound multi-module applications (`P0`, `P3`)** | `transit app check` parses and typechecks a multi-module application containing $>50\text{ KiB}$ files and nested `BEGIN ATOMIC ... ON FAILURE ... END`, `IF`, `CASE` and `FOR` blocks with zero false semicolon splits; reports exact `(file, line, column)` diagnostics for type mismatches, unsettled `CAPABILITY` paths, `SECRET` taint leaks, and out-of-order `ACTIVATE` statements in $<500\text{ ms}$ with zero network I/O. |
| **Enforce module encapsulation and `IMPORT` DAG (`P1`)** | Cross-schema direct `INSERT`/`UPDATE`/`DELETE`/`PUT`/`ENQUEUE` on another module's table/KV/queue and references to `PRIVATE` objects or undeclared `IMPORT` schemas fail compilation deterministically; exported `PUBLIC VIEW` reads and `PUBLIC PROCEDURE` calls succeed within a single atomic transaction. |
| **Expand `PROFILE`, `FUNCTION`, `GUARD` and `PROCEDURE` abstractions (`P2`)** | Declarations using `USING PROFILE`, pure `FUNCTION` calls, `REQUIRE`/`GUARD` invocations and `CALL <schema>.<procedure>(...)` lower deterministically to canonical plan and catalog bytes identical to their hand-expanded equivalents, while preserving source-location attribution in runtime and compile-time diagnostics. |
| **Synthesize and verify migrations from module edits (`P4`)** | Editing a module's `DATAFLOW`, `VIEW`, `PUBLICATION`, `SOURCE` or additive `TABLE` schema and running `transit migrate synthesize` emits a minimal, dependency-ordered `<version>-<name>.sql` migration; `transit migrate verify-modules` proves exact fingerprint agreement between replaying `migrations/*.sql` and compiling `modules/**.sql`, and rejects unmigrated module drift or unsafe destructive DDL. |
| **Replace running definitions safely (`P4`, `D5`)** | Applying a `CREATE OR REPLACE DATAFLOW` migration while queue items and `OPERATION` continuations from the prior revision are in flight preserves the prior generation's execution basis (or drains/fences according to `on_replace`), never reinterprets an in-flight continuation against a mutated AST, and recovers cleanly across restart and lost replies. |
| **Run deterministic unit tests and yield-point replay sweeps (`P5`)** | `transit test --verify-replay` executes `*.test.sql` suites with `SET TEST CLOCK`, `SET TEST SUBJECT`, `MOCK SINK` (including `unknown` outcomes) and `MOCK OBSERVATION`, injecting crashes at every yield point and proving single-dispatch sink idempotency, reservation preservation and terminal state agreement without Docker or external network access. |

# 35. SQL grammar, standards comparison and dialect ergonomics

[Roadmap](README.md) · [Standards & Multi-Model #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Audit and harmonize Transit's complete declarative SQL grammar against formal ISO
standards (**SQL:2023** `Foundation`, `SQL/JSON`, `SQL/PGQ`, `SQL/MED` and
**GQL**) and industry-standard analytical, transactional and streaming dialects
(**PostgreSQL**, **DuckDB**, **Snowflake**, **ClickHouse**, **GoogleSQL** and
**Materialize / RisingWave / Flink SQL**) before the
[1.0 qualification scorecard](36-qualification-and-benchmarks.md) and
[release distribution](37-releases.md). Adopt high-leverage ergonomic syntax—such
as DuckDB's `FROM`-first query composition (`FROM people SELECT id, name;`),
`GROUP BY ALL`, `ORDER BY ALL`, `SELECT * EXCLUDE (...) REPLACE (...)`, trailing
commas and readable numeric literals—as deterministic compile-time desugarings to
canonical `Fuze` plan bytes (`FQP1`, `FDM1`, `FTS1`), standardize declarative
dataflow lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`),
and provide actionable compiler diagnostics when callers write foreign dialect
spellings.

## Prerequisites and architectural rationale

Build on the delivered and planned foundations across
[statement results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[declarative streams and queues](06-streams-queues-and-durable-runtime.md),
[logical Document storage](07-document-storage-and-station-decoupling.md),
[gateway wire protocols](08-gateway-architecture-and-protocol-ingress.md),
[standards, collations and historical catalogs](10-standards-and-catalogs.md),
[indexing and access paths](11-indexing-and-access-paths.md),
[managed computations and dataflows](12-sql-and-dataflows.md),
[first-class strings and search](14-vectorized-strings-and-search.md),
[data-centric compilation](15-data-centric-compilation-and-specialization.md),
[Document profiles](16-document-profiles-and-gateway-exchange-lifecycle.md),
[geospatial and spatio-temporal computing](17-geospatial-and-spatio-temporal-computing.md),
[multi-model and foreign relations](18-multi-model-and-foreign-relations.md),
[branches and merges](20-branches-merges-and-restore.md),
[enterprise control and policy](27-control-and-policy-plane.md),
[Board workbench](30-board-reimplementation.md) and
[language-native application composition](34-programming-model.md). Start from
the [SQL statement reference](../handbook/reference/sql.md),
[grammar surface inventory](../handbook/reference/sql/grammar-surface.md),
[checked grammar and rewrite proofs](../../contracts/sql/README.md) and
[query engine architecture](../handbook/internals/query-engine.md).

Placing this milestone immediately after [Milestone 34](34-programming-model.md)
and before [Milestone 36](36-qualification-and-benchmarks.md) resolves three
pre-release requirements once every data, stream, queue, document, branch and
computation primitive is defined:

1. **Unified grammar coherence across all data and computation primitives:**
   Earlier milestones introduce syntax for Tables, KV, Documents, Streams
   (`PRODUCE INTO`, `CONSUME ... FROM`, `STREAM_SLICE`), Queues (`ENQUEUE INTO`,
   `CLAIM ... FROM`, `ACK`, `NACK`), bitemporal queries (`FOR SYSTEM_TIME AS OF`,
   `PERIOD FOR`, `AS OF JOIN`), managed dataflows, property graphs (`SQL/PGQ`),
   foreign tables (`SQL/MED`) and branches (`CREATE BRANCH`, `MERGE`). Before
   freezing the 1.0 contract definition, the complete grammar
   ([`TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4) and the
   production Zig compilers) must be verified as a single conflict-free language
   with consistent keyword reservation, identifier rules and clause precedence.
2. **Ergonomic authoring with zero runtime or plan divergence:**
   Modern analytical SQL dialects—most notably
   [DuckDB's "Friendly SQL"](https://duckdb.org/docs/sql/query_syntax/from.html)
   and [GoogleSQL pipe syntax](https://research.google/pubs/sql-has-problems-we-can-fix-them-pipe-syntax-in-sql/)—demonstrate
   that aligning surface syntax with logical evaluation order (`FROM` $\to$
   `JOIN` $\to$ `WHERE` $\to$ `GROUP BY` $\to$ `SELECT`) and eliminating
   repetitive projection boilerplate (`GROUP BY ALL`, `SELECT * EXCLUDE (...)`)
   dramatically improves interactive authoring, CLI ergonomics and schema-aware
   autocomplete. Because Transit binds every query against an explicit catalog
   snapshot (`CatalogId`, `DefinitionId`, `ColumnId`) before emitting canonical
   binary plans (`FQP1`, `FDM1`, `FTS1`), these ergonomic constructs can be
   implemented purely as **deterministic compile-time desugarings** that produce
   byte-identical plans to standard SQL without adding runtime operators or
   weakening strict typing and five-state cell semantics.
3. **Explicit dialect boundaries and actionable diagnostics for humans and agents:**
   Developers and LLM agents routinely bring habits from PostgreSQL, DuckDB,
   Snowflake, ClickHouse and MySQL. Auditing those dialects systematically lets
   Transit either accept clean, unambiguous ergonomic forms or recognize foreign
   constructs in the diagnostic grammar (`just test::diagnostic-grammar`) and
   return a targeted rewrite hint naming the exact Transit syntax instead of a
   generic parse error.

## Standards and industry dialect comparison scope

| Standard or dialect | Primary audit scope | Target adoption & boundary in Transit |
| --- | --- | --- |
| **ISO/IEC 9075 SQL:2023** (`Foundation`, `SQL/JSON`, `SQL/PGQ`, `SQL/MED`), **ISO/IEC 13249-3 SQL/MM Spatial** & **ISO/IEC 39075 GQL** | Core relational algebra, window frames, `MATCH_RECOGNIZE` / `GRAPH_TABLE`, `GEOMETRY` / `GEOGRAPHY` / `MESH3D` / `SOLID3D` & `ST_*` / `ST_3D*` spatial & volumetric functions ([Milestone 17](17-geospatial-and-spatio-temporal-computing.md)), temporal periods (`FOR SYSTEM_TIME AS OF`), foreign tables (`CREATE FOREIGN TABLE`), collations and 3-valued $\to$ 5-state truth tables | Primary normative baseline for standard relational, 2D/3D spatial, graph, temporal and foreign-table clauses; document exact feature IDs and Transit's intentional 5-state (`missing`, `type_error`, `conflict`) and checked-arithmetic deviations |
| **PostgreSQL 17 & PostGIS / SFCGAL** (`libpg_query` baseline) | Lexical rules, `standard_conforming_strings`, `::type` casts, `RETURNING`, `ON CONFLICT`, `LATERAL`, CTEs, `RANGE` / `MULTIRANGE` (`&&`, `@>`, `-|-`), `GEOMETRY(subtype, srid)` / `ST_*` / `ST_3D*` / `<->` & `<<->>` 2D/3D $k$-NN operators, `GRANT`/`REVOKE`, `ALTER SUBSCRIPTION ... ENABLE \| DISABLE` and wire-protocol (`transit-postgres`) metadata queries | Preserve AST agreement on the shared compatibility subset; map PostgreSQL-specific administrative and replication idioms (`ENABLE`/`DISABLE`, `pg_catalog` / `geometry_columns` introspection) to Transit's catalog and dataflow operations |
| **DuckDB ("Friendly SQL", Secrets Manager & DuckDB Spatial)** | `FROM`-first queries (`FROM tbl SELECT ...`, bare `FROM tbl;`), `SELECT * EXCLUDE (...) REPLACE (...)`, `GROUP BY ALL`, `ORDER BY ALL`, `QUALIFY`, `AS OF JOIN`, `CREATE [PERSISTENT \| TEMPORARY] SECRET` / `DROP SECRET` / `SHOW SECRETS`, `ST_*` / `H3_*` functions, trailing commas and numeric underscores (`1_000_000`) | Adopt `FROM`-first syntax, `EXCLUDE`/`REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`, trailing commas and numeric underscores as first-class compile-time desugarings to canonical `FQP1` plans; support declarative `CREATE/ALTER/DROP SECRET` and `SHOW SECRETS` ([Milestone 27](27-control-and-policy-plane.md)) bound to KMS/Vault/OAuth2 providers, `SCOPE` prefixes and `USAGE ON SECRET` RBAC while diagnostically rejecting unsealed plaintext secret literals in durable SQL text |
| **Snowflake & Databricks / Delta Lake** | Dynamic Tables and Tasks (`CREATE \| ALTER DYNAMIC TABLE ... SUSPEND \| RESUME \| REFRESH`), `QUALIFY`, `CHANGES AT/BEFORE`, `table_changes(...)` CDC feeds, semi-structured path navigation and time-travel selectors | Align stateful computation lifecycle verbs (`SUSPEND`, `RESUME`, `REFRESH`) with Transit's 5-state dataflow lifecycle and linear `CHANGES(table, ...)` TVF while keeping publication, authorization, activation and retirement explicit |
| **Dolt ("Git for Data") & Relational Diff Prior Art** | `DOLT_DIFF`, `DOLT_DIFF_SUMMARY`, `DOLT_SCHEMA_DIFF`, `DOLT_MERGE` and ISO SQL `EXCEPT [ALL]` / `FOR SYSTEM_TIME FROM a TO b` | Provide first-class key-aligned 2-way and 3-way `DIFF(...)` and `DIFF_SCHEMA(...)` table-valued functions plus declarative `REMOTE` / `FETCH` / `MIRROR` / `PROPOSE` syntax over `.tseg` segment skipping, `ColumnId` lineage and 5-state `IS CONFLICT` cells without doubling column count into `from_*`/`to_*` |
| **ClickHouse** | Vectorized string/search functions, `LIMIT n BY ...`, codec/compression clauses, parameterized views and array/tuple higher-order idioms | Compare physical codec (`ENCODING`) and search/BM25 query ergonomics; keep logical types ($\tau$), collations ($\kappa$) and physical codecs ($\epsilon$) strictly orthogonal |
| **Materialize / RisingWave / Flink SQL** | `CREATE SOURCE`, `CREATE SINK`, `CREATE MATERIALIZED VIEW`, `SUBSCRIBE`, watermark/lateness declarations and savepoint/checkpoint job controls | Compare streaming DDL and watermark/retraction contracts against Transit's `STREAM`, `QUEUE` and WAL-activated dataflows ([Milestone 6](06-streams-queues-and-durable-runtime.md), [Milestone 12](12-sql-and-dataflows.md)) |

## Delivery sequence

1. **Publish the machine-readable grammar & dialect comparison matrix and verification corpus.**
   Extend [Milestone 10's](10-standards-and-catalogs.md) standards ledger and
   [`contracts/sql/corpus/`](../../contracts/sql/README.md) with a comprehensive,
   reproducible comparison corpus spanning **SQL:2023**, **PostgreSQL 17**,
   **DuckDB**, **Snowflake**, **ClickHouse** and **Streaming SQL**. Assign every
   audited syntax construct to one of four verified dispositions:
   - **Canonical Transit SQL:** The primary documented form emitted by canonical
     formatters and catalog definition dumps.
   - **Ergonomic compile-time sugar:** Accepted by [`TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4)
     and production Zig compilers, desugaring deterministically after schema
     binding to the **exact same canonical `FQP1` / `FDM1` / `FTS1` plan bytes**
     as the canonical spelling.
   - **Recognized foreign dialect syntax (diagnostic rejection):** Matched by
     dedicated error productions in the diagnostic grammar so the compiler
     rejects the statement before execution with a stable error code and a concrete
     hint showing the exact Transit equivalent (for example, suggesting
     `ALTER DATAFLOW name SUSPEND` or `ACTIVATE` when a user writes
     `ALTER ... DISABLE` / `ENABLE`, or suggesting `PRODUCE INTO stream ...` when
     a user writes `INSERT INTO stream ...`).
   - **Outside selected profile:** Explicitly unsupported syntax with documented
     rationale.

2. **Implement DuckDB-style `FROM`-first query syntax and compositional relational ergonomics.**
   Extend the reference grammar, production Zig relational/analytical compilers,
   `transit console` and [Board's](30-board-reimplementation.md) SQL editor/autocomplete
   to support prefix `FROM` queries and schema-bound projection shorthands:
   - **`FROM`-first clause ordering (`FROM ... SELECT ...` and bare `FROM ...`):**
     Allow any query block (top-level queries, CTEs, derived subqueries and
     `EXPLAIN` targets) to begin with `FROM target` followed by optional `JOIN`,
     `WHERE`, `GROUP BY`, `HAVING`, `WINDOW`, `QUALIFY`, `SELECT`, `ORDER BY` and
     `LIMIT` clauses:
     ```sql
     -- Prefix FROM with explicit projection
     FROM people
     SELECT id, name;

     -- Full query in logical evaluation order (enabling immediate schema autocomplete)
     FROM people AS p
     JOIN orders AS o ON p.id = o.person_id
     WHERE p.active = true
     GROUP BY p.id, p.name
     SELECT p.id, p.name, COUNT(o.id) AS order_count, SUM(o.amount_cents) AS total_cents
     ORDER BY total_cents DESC
     LIMIT 20;

     -- Implicit SELECT * when SELECT is omitted in interactive/relational profiles
     FROM people
     WHERE active = true
     LIMIT 10;
     ```
     Both `FROM people SELECT id, name;` and `SELECT id, name FROM people;` must
     lower to **byte-identical `FQP1` plans** against the bound `DefinitionId`.
     When `SELECT` is omitted (`FROM people WHERE active = true;`), the compiler
     expands the projection against the bound source schema at compile time just
     like `SELECT *`.
   - **Schema-bound projection modifiers (`SELECT * EXCLUDE (...)` and `SELECT * REPLACE (...)`):**
     ```sql
     FROM users
     SELECT * EXCLUDE (password_hash, totp_secret)
              REPLACE (LOWER(email) AS email);
     ```
     Resolve `EXCLUDE` and `REPLACE` identifiers against the pinned source
     `DefinitionId` at compile time, rejecting unknown or duplicate column names
     and emitting an explicit `ColumnId` projection list in `FQP1` so physical
     execution and saved plans never carry runtime wildcard ambiguity.
   - **`GROUP BY ALL` and `ORDER BY ALL`:**
     Deterministically expand `GROUP BY ALL` to the ordered list of
     non-aggregate expressions in the `SELECT` projection, and `ORDER BY ALL` to
     the ordered list of all projected output columns, before emitting `FQP1`.
   - **List and literal ergonomics:**
     Support optional **trailing commas** in `SELECT` projections, `GROUP BY` and
     `ORDER BY` clauses, `VALUES` tuples and `CREATE TABLE` column lists, together
     with **numeric literal underscores** (`1_000_000`, `0xfeed_face`) across all
     SQL compilers.

3. **Standardize declarative lifecycle DDL across Dataflows, Materialized Views, Streams, Queues and Subscriptions.**
   Harmonize state-management DDL across [Milestone 6](06-streams-queues-and-durable-runtime.md)
   and [Milestone 12](12-sql-and-dataflows.md) so every long-lived declarative
   computation and connector binding exposes an inspectable, unambiguous state
   machine (`Published`, `Authorized`, `Active`, `Suspended`, `Retired`):
   - **Explicit lifecycle transitions and watermark disposition:**
     ```sql
     -- Activate an authorized dataflow or materialized view
     ALTER DATAFLOW order_summary ACTIVATE;

     -- Pause background delta scheduling while preserving checkpointed watermarks
     ALTER DATAFLOW order_summary SUSPEND;

     -- Resume from the exact checkpointed TransitLog LSN or recompute from a fresh cut
     ALTER DATAFLOW order_summary RESUME WITH (on_resume = 'replay_history');
     ALTER DATAFLOW order_summary RESUME WITH (on_resume = 'recompute_snapshot');

     -- Trigger an explicit bounded refresh
     REFRESH MATERIALIZED VIEW order_summary;

     -- Permanently retire a definition revision while preserving historical provenance
     ALTER DATAFLOW order_summary RETIRE;
     ```
   - **Dialect mapping for `ENABLE` / `DISABLE` vs. `SUSPEND` / `RESUME`:**
     Keep `SUSPEND` / `RESUME` (operational pause/resume with explicit watermark
     retention and last-completed-revision read availability) distinct from
     `ACTIVATE` (initial or replacement activation under current `policy_epoch`
     authorization) and `RETIRE` (permanent closure to new work). Provide
     targeted compiler diagnostics when callers use PostgreSQL/Oracle-style
     `ENABLE` / `DISABLE` on a stateful dataflow or materialized view so the
     caller chooses the intended lifecycle transition explicitly.

4. **Standardize declarative `DIFF`, `DIFF_SCHEMA` and Git-like remote/branch sync SQL grammar.**
   Audit relational and schema diff syntax across ISO SQL (`EXCEPT [ALL]`,
   `FOR SYSTEM_TIME FROM a TO b`), Dolt (`DOLT_DIFF`, `DOLT_SCHEMA_DIFF`), and
   Snowflake/Delta (`CHANGES` / `table_changes`), and expose [Milestone 20's](20-branches-merges-and-restore.md)
   segment-skipping diff, five-state conflict algebra and remote mirroring
   through composable SQL:
   - **Two-way and three-way relational/document `DIFF(...)` and `DIFF_SCHEMA(...)`:**
     ```sql
     -- Key-aligned 2-way data diff between branches or snapshots (skipping shared .tseg segments in O(1))
     FROM DIFF(people, FROM => BRANCH 'main', TO => BRANCH 'feature')
     SELECT _diff_op, id, name, email;

     -- 3-way branch diff surfacing cell-level merge conflicts via 5-state IS CONFLICT
     FROM DIFF(people, BASE => BRANCH 'main', SOURCE => BRANCH 'feature', TARGET => BRANCH 'prod')
     WHERE email IS CONFLICT OR balance IS CONFLICT
     SELECT id, _diff_op, email, balance;

     -- Catalog, schema and dataflow definition diff across branches or remotes (tracking ColumnId renames)
     FROM DIFF_SCHEMA(FROM => REMOTE 'prod/main', TO => BRANCH 'local_migration')
     SELECT object_name, object_kind, change_kind, column_id, before_type, after_type;
     ```
   - **Declarative remote mirroring and branch proposal verbs (`CREATE REMOTE`, `FETCH`, `MIRROR`, `PROPOSE`):**
     ```sql
     CREATE REMOTE prod FROM 'https://transit.example.com' WITH (credential = SECRET('prod_reader'));
     FETCH FROM REMOTE prod BRANCH 'main';
     CREATE BRANCH local_migration FROM REMOTE 'prod/main';
     ```
     Ensure remote sync and diff statements bind to immutable `manifest/v{N}`
     cuts, enforce current `policy_epoch` security-barrier RLS and dynamic
     masking, and fence external connector effects during local branch
     execution.

5. **Qualify grammar unambiguity, canonical plan equivalence, formatter round-trips and editor autocomplete.**
   - **Zero parser ambiguity:** Regenerate [`TransitExtensions.g4`](../../contracts/sql/TransitExtensions.g4)
     with `-Werror` and verify zero ANTLR ambiguity or conflict reports across the
     expanded multi-dialect positive and negative corpus (`just test::sql-grammar`).
   - **Canonical plan equivalence:** Prove in `just test::sql` and
     `just test::sql-rewrites` that every ergonomic sugar form (`FROM`-first,
     bare `FROM`, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`, `ORDER BY ALL`,
     trailing commas and numeric underscores) produces **byte-for-byte identical
     `FQP1` / `FDM1` / `FTS1` plans** and identical execution results to its
     canonical SQL expansion across five-state values (`value`, `null`, `missing`,
     `type_error`, `conflict`).
   - **Formatter and AST round-tripping:** Verify that the shared SQL formatter
     can format both `SELECT`-first and `FROM`-first forms losslessly without
     changing bound identities, collations or literal types.
   - **Interactive console and Board autocomplete:** Verify in `transit console`
     and [Board](30-board-reimplementation.md) that writing `FROM <table_name> `
     immediately provides schema-scoped column completions for subsequent
     `WHERE`, `JOIN`, `GROUP BY` and `SELECT` clauses.

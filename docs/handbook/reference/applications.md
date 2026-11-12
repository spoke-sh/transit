# Application installation, definitions and migration

An installed application, a published interface and a data migration are separate
objects. Installing new code does not authorize new operations, publish a UI or
transform durable data. Use the [first application guide](../guides/applications.md)
for a separately compiled Zig worker and [work-items](../../../examples/work-items/README.md)
for the complete example.

## Application source builds

`transit build` compiles `.transit` modules to ordinary SQL for new Tables,
Streams and Queues, literal mutations and log appends, and finite single-Table SELECT. Typed constructors
accept values, types and other modules; interfaces check module arguments.
Imports expose public source symbols, and bounded constructor recursion can
compose repeated instances with explicit, caller-chosen resource names.

A minimal `build.transit` is:

```text
CREATE MODULE Rows(name IDENTIFIER, initial BIGINT) AS BEGIN
  CREATE PUBLIC TABLE $name (id BIGINT PRIMARY KEY);
  INSERT INTO $name VALUES ($initial);
END;
CREATE TARGET default AS BEGIN
  USE Rows(NAME 'items', 7);
  SELECT * FROM items;
END;
```

Run `transit build --check` to check the selected target, or `transit build` to
publish `application.sql` and its provenance under `.transit/build/`. Execute
that SQL separately through an ordinary caller, for example
`transit console --no-rc -f PATH/application.sql`. Source packages and build
metadata are unnecessary at execution; current authorization still applies.
`PUBLIC` exposes a runtime resource for ordinary access and grants no permission.
The compiler starts with an empty proposed catalog and does not consult a server.

Repository dependencies name exact commits and package subdirectories in source.
`transit build --fetch` explicitly populates the content-verified cache and lock;
subsequent builds run offline. Explicit local overrides enter provenance and
build identity. The [build CLI](cli.md#application-source-builds) and
[source contract](../../../contracts/APPLICATION_SOURCE_V1.md) define syntax,
resolution, artifacts, diagnostics and resource limits.

The [source grammar](../../../contracts/application-source/README.md) formalizes
these forms separately from runtime SQL and interface/UI declarations. Complete
resource-template and expected-row syntax is checked in every body, including unused
modules and unselected branches. Name resolution, types, target placement and
execution remain separate stages. A bounded compiler-package formatter supports
independent source round-trip checks; it is not a CLI command.

Nominal source domains distinguish values with equal underlying scalars. For
example, `CREATE PUBLIC DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id';`
and a separate `SiteId` require explicit constructors and reject cross-domain
substitution. Closed variants such as `Target.Machine(MachineId(7))` select an
exhaustive compile-time MATCH. Every reached arm is typechecked, including those
not emitted. This does not dispatch on a live request or prove that ID `7` exists.

Named instances (`USE Rows(...) AS machines;`) expose typed public Table handles
through `EXPORT TABLE $name AS rows;`. A parameter such as
`rows TABLE(id MachineId PRIMARY KEY)` checks the complete admitted signature.
Assignments and equality predicates preserve the column's nominal type even
when SQL uses a literal Table name. Final SQL contains ordinary scalar values;
direct SQL retains its ordinary type and authorization rules. The
[source specialization contract](../../../contracts/APPLICATION_SOURCE_V1.md#typed-source-specialization)
owns exact syntax, symbolic-checking limits and proof premises. The
[synthetic example](../../../tests/fixtures/application-typed-targets/README.md)
shows both resource kinds with raw ID `7` and isolated Table tests.

`STREAM(...)` and `QUEUE(...)` parameters and matching exports preserve distinct
resource kinds and exact column signatures. Log declarations use single-partition
defaults with unlimited retention. Literal `PRODUCE INTO` and `ENQUEUE INTO`
statements use ordinary log preparation and permissions. Non-null log fields can
carry source domains: matching values remain typed through appends and finite
CONSUME projections and equality predicates. Raw or foreign-domain values reject,
including through literal resource names. These annotations do not validate
externally supplied IDs or grant permission. Explicit log configuration,
append metadata and RETURNING remain outside this source profile.

Public Queue programs compose those resources through `CREATE PUBLIC DATAFLOW`
and separate AUTHORIZE/ACTIVATE controls. LET, REQUIRE, IF, Table inserts and log
appends use the installed ordered-program binder; mutations require an atomic
block. Building emits SQL and never activates it. The
[program source profile](../../../contracts/APPLICATION_SOURCE_V1.md#public-queue-programs)
defines exact supported instructions, schemas and limits.
Nominal Queue, Stream and Table fields retain their source types through LET,
record projections, nullable one-record lookups and matching CASE arms. Writes and
equality comparisons require the same domain, even for identical scalar values.
Every runtime branch is checked. A domain annotation does not prove that a sender
is authorized or a referenced row exists; use a lookup and REQUIRE for existence.
Ordinary SQL still receives scalar columns and values.

This profile rejects runtime-private storage, privileged procedures, protected
effects, COMMAND programs and unsupported Table/query forms. Migration synthesis and full Platform compilation remain planned. The existing
interface-definition compiler and installation APIs below retain their scope.

## Isolated application Table tests

`transit test` selects `CREATE TEST TARGET tests` from the same source graph and
frozen dependencies as a build. Declare explicit cases inside a test target or
composed module. Each case has its own setup modules and empty local database:

```text
CREATE TEST TARGET tests AS BEGIN
  TEST 'inserted rows are visible' USING MODULES () AS BEGIN
    CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY);
    ASSERT COMMAND (INSERT INTO items VALUES (7)) MATCHED 1 CHANGED 1;
    ASSERT ROWS (SELECT id FROM items) EQUAL ((7));
    ASSERT STATEMENT (INSERT INTO items VALUES (7)) FAILS WITH 'duplicate_key';
    ASSERT ROWS (SELECT id FROM items) EQUAL ((7));
  END;
END;
```

All selected cases compile before a runtime starts. Setup and asserted SQL use
the production emitter and ordinary SQL session owners. Row expectations bind to
the query schema and compare exact typed values as a multiset, preserving NULL
and duplicate counts without requiring physical row order. Command assertions
check authoritative matched/changed counts. Expected refusals support only
recorded DML `duplicate_key` and `check_violation` outcomes. A timeout, denied
request, incomplete read or exhausted budget fails the run.

Cases run sequentially in private temporary local databases without listeners,
server configuration or containers. The runner uses real grants, storage and
current disclosure checks, then closes sessions and deletes each owned database.
Passing requires complete assertions and successful cleanup. The
[test CLI](cli.md#application-table-tests) owns invocation and reporting; the
[source contract](../../../contracts/APPLICATION_SOURCE_V1.md#isolated-table-tests)
owns syntax and exact limits. Subject/grant controls, virtual clocks, effects,
HTTP simulation and workflow replay remain unsupported source features.

Public Queue programs use the same isolated cases. After submitting inputs,
`ASSERT WORKFLOW NAME 'process' COMPLETED 1 REFUSED 2 WITHIN 1000 OBSERVATIONS;`
waits for exact recorded counters under current rights. Active programs can still
have a pending acquisition for their next input; this assertion does not establish
Queue emptiness or program idleness.
It does not treat activation as completion or replay input. Follow it with Table
and `CONSUME` row assertions to check state and Stream output. Exhausted polling
or session budgets fail. The [Queue source fixture](../../../tests/fixtures/application-queue-programs/README.md)
and [nominal lookup fixture](../../../tests/fixtures/application-typed-queue/README.md)
illustrates success, refusal, atomic rollback and isolation; the
[test contract](../../../contracts/APPLICATION_SOURCE_V1.md#queue-program-tests)
defines observation limits and scope.

## Planned source language and build model

The proposed authoring language is a higher-order Transit SQL dialect stored in
`.transit` files. Ordinary SQL forms its executable foundation; typed modules,
imports, parameters and compile-time composition organize larger programs.
`build.transit` is a program in that same dialect. The implemented build profile
above covers recursive public-resource and Queue-program composition. The
proposed broader language uses the same graph to select richer
outputs and tests. The following sections describe that larger design; they do
not extend the executable capabilities listed above.

```text
build.transit + imported .transit modules + locked dependencies
    -> resolve, typecheck, specialize and compose
    -> executable Transit .sql
    -> ordinary statement execution or explicit migration application
```

The output is Transit SQL, including the target runtime's supported extensions;
it does not imply portability to other database engines. Generated SQL must be
independently parseable and executable through the ordinary statement owners,
without fetching source packages or interpreting a build file on the server.
Compilation alone publishes nothing, grants no rights and starts no computation.

### Recursive modules and repository composition

Composition uses the same module interface at every level. A module can import
and compose other modules, export modules or typed constructors, and accept
types, values or modules satisfying declared interfaces. A child build module can
be built independently or composed into a parent build. A local workspace module
and a module from another repository expose the same import/export semantics.
The compiler resolves their shared graph; nesting does not require invoking a
separate compiler process for each directory.

| Concept | Proposed responsibility |
| --- | --- |
| Workspace | Coordinates packages and targets developed together, including a monorepo |
| Package | Distributes source modules and declares their dependencies; a repository can contain several packages |
| Module | Encapsulates typed source declarations, imports, parameters and exports; may contain only pure helpers |
| Build target | Selects a composition and its SQL outputs or test suite |
| SQL schema | Names instantiated database objects in a catalog; remains distinct from a source module or package |

Composition explicitly binds stateful module instances to catalog namespaces
and stable object identities. Moving a source file, changing its import alias or
reorganizing a repository must not recreate durable data. Conflicting dependency
versions cannot silently select or duplicate the same stateful instance; separate
instances require explicit bindings. Imports and exported interfaces grant no
runtime privileges. Any encapsulation guarantee that must hold for direct SQL
callers must survive lowering into runtime-enforced definitions and permissions.

Remote dependencies resolve by repository, optional package subdirectory, exact
revision and verified content digest. A committed lockfile records the transitive
selection; explicit local overrides support development across repositories and
remain visible in build provenance. Once dependencies are fetched, frozen builds
and tests must work offline. Compiler/contract identity, source contents, locked
dependencies, target options and instance bindings participate in reproducibility
and cache keys. A package version is separate from a database definition revision.

### Compile-time evaluation and executable SQL

Higher-order functions compose typed declarations and expressions with hygienic
names, preserving definition-site and invocation-site source locations. Build
targets, imports, specialization and file emission are compile-time operations;
database reads, mutations, transactions and effects remain explicit runtime SQL.
Build evaluation cannot inspect a live catalog or dispatch application effects
implicitly. Runtime settings and secret references stay runtime-bound rather
than being captured as private values in generated SQL.

Recursive composition is supported throughout this proposed model. Recursive
compile-time evaluation needs deterministic work, depth, memory and output
budgets with attributable failures. Import/build dependency cycles reject;
runtime recursive queries and durable workflows keep their own execution rules.
Language syntax and those budgets require contracts before implementation.

Canonical SQL emission must preserve types, collations, cell-state behavior,
atomic boundaries, authorization and definition binding. Compile-time helpers
expand into executable forms; constructs retained in emitted SQL require support
from their owning runtime. Source maps and dependency manifests may accompany the
SQL for diagnostics and provenance; they cannot supply missing execution semantics.
The [compiler analysis](../internals/query-engine.md#planned-source-to-sql-compilation)
describes the equivalence and rejection evidence needed for this boundary.

### Statement outputs, migrations and tests

A statement target compiles source against its declared dependency and schema
inputs. A migration target additionally requires an explicit prior definition
state and any necessary data transformations. Desired-state compilation can
describe a table; synthesizing its evolution requires comparison with that prior
state. Ambiguous or destructive changes need an explicit transformation or rewrite
plan. Build evaluation never discovers the migration basis by silently contacting
a live deployment.

Generated migration files use the existing
[SQL migration lifecycle](cli.md#application-sql-migrations). Applied bytes remain
immutable: recovery uses the original migration and accepted operation identities,
even after source, compiler or dependency changes. A successful build neither
applies a migration nor proves that an existing deployment matches its basis.

The delivered Table and public Queue test profile above resolves the same graph and uses the same
SQL emitter as `transit build`. Extensions for application clocks, effect mocks
and workflow fault schedules remain planned. Test controls stay distinct from
deployable SQL. Local tests qualify only their executed scenarios, not external
providers, physical durability or distributed recovery.

## Installation and bootstrap

The language-neutral declaration describes roles, resources, artifacts and
compatibility. It grants no rights on its own. The local manager performs scoped
native provisioning and reconciles physical worker processes, while Transit
history remains the authority for grants and ownership.

Install under an explicit operation ID and retain the frozen signed request.
Accepted management intent, installed/ready state and successful domain behavior
are separate observations. After uncertainty, reconcile that operation rather
than preparing a new installation with fresh identities.

| Revision or identity | Meaning |
| --- | --- |
| Installation/application identity | Durable management and application scope |
| Artifact revision | Selected compatible executable |
| Ownership generation | Current eligible worker, fenced independently from artifact selection |
| Data epoch | Active domain/schema state |
| Published interface revision | Conditional active UI/service definition |

The local server supports separate installed applications, scoped
caller exports, compatible replacement and exact recovery on Linux x86_64.
The supervisor hosts independently compiled Zig workers. Worker adapters for
other SDK languages are not available. Pinned neighborhood upgrades,
arbitrary incompatible executable replacement and automatic history migration
remain outside the profile.

Version-1 server configuration includes Board inspection. Applications declare
resource access explicitly through the version-1 installation declaration's
`inspection` list. These grants belong to Board's separate identity; restarting
or replacing a worker does not restore revoked access. See
[application inspection](../../../apps/transit-cli/docs/applications.md#board-inspection).

## Declarative application interfaces

The shared compiler validates a bounded complete definition and its reference
graph. Query declarations, explicit commands, renderer/theme compatibility and
source capabilities are distinct. Follow supports int64 Table sources;
KV and Document sources support finite queries without watches.

SQL text, visual edits and generated modules use that same neutral model and
semantic validation. Offline parse/format/module generation performs no publication,
query submission or effect dispatch. Structural schema validity alone cannot
validate graph references, grants or runtime capability.

Capacity errors name the first failing collection or parser bound, with its
count, unit, limit and minimum/maximum rule. A missing required screen or theme
is distinct from exceeding its maximum. Literal, option, comment-depth and
program-byte failures retain their original measurements without disclosing
option values.

The [application SQL reference](sql/application.md) describes `CREATE INTERFACE`,
`CREATE THEME`, `CREATE SCREEN`, `CREATE BINDING` and `CREATE ACTION`, including
their required options and a complete program.

Publication uses a frozen reviewed proposal and conditional active revision.
Bounded upload/staging is recoverable; only final validated activation changes
the published interface. Status reads use the operator's current policy, not a
host's stronger inspection credential. Conflicts or unknown replies require
reconciliation of the exact operation before editing another proposal.

Application host errors preserve the compiler's member, option and source
location and distinguish local validation from signed-command dispatch. Unknown
admission identifies the exact saved sequence; native rejection and failed reads
do not imply a terminal publication outcome. Board's definition editor displays
this shared evidence and retains pending signed work for explicit recovery.

Invalid operator configuration and malformed authority/resource evidence have
separate diagnostics. Unavailable or truncated reads preserve the selected
application; if the truncation's origin was not recorded, that absence is explicit.

Publication status retains rejected-input detail separately from the operation's
receipt. Original compiler locations refer to the verified assembled body;
policy denials retain the rejecting policy, and incomplete uploads retain their
written and required chunk counts. Later policy changes, activation or explicit
cleanup do not rewrite those explanations. A rejected input alone does not settle
a staged operation or undo an applied interface. Current read access is required
to disclose either the receipt or its diagnostic evidence.

## Data migration

Migration belongs to the data owner. Its separate policy and ledger bind a
reviewed supported plan, source epoch, target schema and ordered steps. Each step
has durable receipt/cursor evidence, so recovery does not reapply committed work
under a fresh ordinal.

The selected work-item transformation enforces a write pause, bounded copying,
complete target verification and explicit activation. Interface publication and
administrator release of writes follow separately. A changed UI definition
cannot claim data has migrated. Abandonment cannot undo activation or erase plan
and step evidence; broader transforms need their own implementation and proof.

Rejected migration inputs retain the original policy, epoch/contract, step
commitment or ordinal conflict. Work-item rejections also identify mismatched
cursor commitments, incomplete verification counts and invalid submitted states.
These records survive later progress or activation and remain separate from
committed step receipts. Plan diagnostics distinguish active work, confirmed
activation and explicit abandonment, with the original plan identity, reviewed
epoch/contracts and next step ordinal. They offer inspection; the application
selects any continuation and its exact arguments. Abandonment leaves earlier
committed steps and staged data intact. Inspection requires current resource access. Stored-data
corruption and infrastructure failures leave the input unresolved rather than
claiming a terminal caller rejection.

## Contracts and commands

Named relational queries retain an immutable typed plan, source identities,
schemas and captured/maintained lifetime. Publishing a definition and authorizing
it are separate from explicitly activating its original publishing peer's call.
Later name revisions cannot relabel accepted work; current native and catalog
rights still govern every result. The [typed naming guide](../../../packages/zig/transit-station-app/docs/named-relational.md)
describes conditional revisions, quotas, exact retries and retained attribution.
This profile does not enable SQL view declarations, subscriptions or connector
dispatch.

- [Local installation guide](../../../apps/transit-cli/docs/applications.md): management commands, exports, replacement and recovery.
- [Installation/bootstrap contract](../../../contracts/APPLICATION_INSTALLATION_V1.md): neutral fields, identity and host obligations.
- [Application definition contract](../../../contracts/APPLICATION_V1.md): compiler and conditional publication.
- [Named relational contract](../../../contracts/NAMED_RELATIONAL_V1.md): immutable query names, separate authorization and explicit activation.
- [Migration contract](../../../contracts/APPLICATION_MIGRATION_V1.md): data-owner steps and exact recovery.
- [Compiler package](../../../packages/zig/transit-station-app/README.md): real parse/format/schema/module commands and native APIs.
- [Browser package](../../../packages/ts/transit-application/README.md): generated runtime validation, scoped signing and proposal recovery.

The application declaration compiler handles application definitions. KV and
Document declarations have an offline compiler. Table CREATE/ALTER/DROP uses
shared typed DDL compilation and publishes through authorized catalog callers,
including a console with a configured catalog. The dedicated
[authorization compiler](sql/authorization.md) lowers supported role, privilege
and schema statements to typed plans for explicit administration; query sessions
do not apply those plans. Connector DDL remains grammar-only. See the
[SQL grammar surface](sql/grammar-surface.md) for implemented and planned forms.

# Application source and build v1

This contract specifies the first `.transit` compiler profile. Source compilation
is separate from SQL execution and from the immutable [migration ledger](MIGRATION_V1.md).
The [application reference](../docs/handbook/reference/applications.md#application-source-builds)
describes its supported authoring and execution workflow.

The executable source parser is
[`transit-compiler/Syntax.zig`](../packages/zig/transit-compiler/src/Syntax.zig).
Its independent syntax reference is
[`TransitSource.g4`](application-source/TransitSource.g4), with a
[finite corpus and correspondence check](application-source/README.md).
[`TransitExtensions.g4`](sql/TransitExtensions.g4) checks ordinary SQL and
[`Application.g4`](application/Application.g4) checks interface/UI declarations;
neither covers `.transit` imports, modules, builds or tests. The source check
compares complete ANTLR and production ASTs, byte coordinates, source formatting
and compiled products. This finite evidence is distinct from native execution
and formal preservation proofs.

## Source language

`build.transit` and imported files use the same grammar. Names are case-insensitive
ASCII identifiers; quoted SQL identifiers retain SQL semantics. Source declarations
are modules, interfaces, targets, imports and repository dependencies. Modules and
interfaces are private unless declared PUBLIC. Targets are selected by name in
the entry file. Imports expose only public declarations. All source files are
parsed before evaluation; duplicate names, missing imports and cycles reject.

```text
IMPORT rows FROM 'rows.transit';
CREATE INTERFACE Factory(table_name IDENTIFIER, element TYPE, initial BIGINT);
CREATE MODULE Twice(factory MODULE Factory, first IDENTIFIER, second IDENTIFIER)
AS BEGIN
  USE factory(first, TYPE BIGINT, 7);
  USE factory(second, TYPE BIGINT, 9);
END;
CREATE TARGET default AS BEGIN
  USE Twice(rows.Rows, NAME 'first_items', NAME 'second_items');
  SELECT * FROM first_items;
END;
```

```text
-- rows.transit
CREATE PUBLIC MODULE Rows(table_name IDENTIFIER, element TYPE, initial BIGINT)
AS BEGIN
  CREATE PUBLIC TABLE $table_name (id $element PRIMARY KEY);
  INSERT INTO $table_name VALUES ($initial);
END;
```

Parameters are `BIGINT`, `TEXT`, `BOOLEAN`, `IDENTIFIER`, `TYPE`, or `MODULE
interface_name`. Module interfaces describe ordered parameter types; parameter
names need not match. Qualified references use an import alias and public member.
Constructors can accept and forward module values, call local/private helpers,
and recurse under explicit work/depth limits. Import cycles remain forbidden.

`USE constructor(arguments);` evaluates a constructor. Compile-time expressions
include parameter references, module references, signed integer/text/Boolean
literals, `NAME 'identifier'`, `TYPE BIGINT|TEXT|BOOLEAN`, parentheses, checked
integer `+`, `-`, `*`, comparisons and Boolean AND/OR/NOT. Conditional bodies use
`IF expression THEN ... [ELSE ...] END IF;`. Conditions must be Boolean.
Expressions have no ambient environment, time, random, database or effect access.
Module bodies contain USE, IF and executable SQL statements; nested declarations
and runtime-private Table declarations reject in this profile.

Expression precedence, from tightest to loosest, is unary minus/NOT,
multiplication, addition/subtraction, comparisons, AND, OR. Binary operators
associate left; comparisons are not comparison chains. AND and OR evaluate both
operands, so an error in either operand is observable even when the other operand
determines the Boolean result. This precedence is separate from SQL precedence.
Names are at most 63 ASCII bytes and source names are unquoted. Empty top-level
statements are allowed; empty body statements are not. Strings use doubled
single quotes, comments may nest, and no keyword interpretation occurs inside
strings or quoted SQL identifiers.

### Validation stages

| Stage | Required checks | Does not establish |
| --- | --- | --- |
| Encoding/framing | UTF-8, bounded complete tokens and blocks | Source or SQL syntax |
| Source/template syntax | Complete declarations, expressions, admitted Table templates and expected rows in **all** bodies | Name resolution, operand type, target reachability or valid schema |
| Graph/type/target | Imports/interfaces, typed bounded evaluation, target/case placement and ordinary schema/plan binding | Runtime authority or execution |
| Native execution | Current permission, constraints, original accepted operations and complete outcomes | Broader effect/provider qualification |

Structural template checks include unused modules and both branches of IF.
Malformed SQL and SQL outside the closed Table source profile cannot be hidden
in unreachable bodies. This is an intentional earlier refusal than the former
framing-only body parser. It changes no emitted SQL for valid supported programs
and changes no persisted lock/cache or native definition. Unresolved names,
wrong operand kinds and invalid target/case placement retain their later checks.
The parser never invents catalog bindings or dummy SQL values to validate a hole.

Spans are zero-based UTF-8 byte offsets with exclusive ends; diagnostic lines
and byte columns start at one. ANTLR character offsets must be converted before
comparison. Source spelling, source digests and expansion-position-derived test
identities are provenance, separate from explicit durable object bindings.

`$parameter` is a typed source syntax operand, never string interpolation.
Identifier operands encode one quoted identifier; values encode one SQL literal;
type operands encode an admitted logical type. Holes inside strings, comments or
quoted identifiers are inert. Module operands cannot become SQL tokens. Expanded
statements are checked by the ordinary typed SQL owners before emission. Runtime
positional parameters are not part of this fully bound target profile.

## Executable target

The initial target supports CREATE TABLE, literal INSERT/UPDATE/DELETE and finite
single-Table SELECT through Fuze's typed Table owners. Tables are explicitly
PUBLIC in source, with ordinary runtime permissions; PUBLIC is erased before
runtime SQL preparation and grants no access. CHECK/key/type/predicate restrictions
are those of the shared owners. Views, foreign-key resolution, ALTER/DROP,
multi-source queries, procedures, effects, Queue/COMMAND programs, deadlines,
publication and migration synthesis reject. No unsupported declaration is omitted.

Declarations and statements execute in lexical composition order. Each Table must
precede its users, and each object name may be declared once. Explicit identifier
arguments bind instances independently of file paths and aliases. Two modules
claiming one Table name reject, including different dependency versions. Compiler
ordinals used to compare schemas are not allocated durable object identities.

The compiler maintains a bounded proposed catalog and checks every emitted
statement against it. Canonical SQL removes source-only forms and comments,
normalizes token spacing and unquoted word case, and preserves literal/quoted
identifier bytes. It reparses emitted output through the same ordinary typed
owners and compares schema/plan fingerprints and statement order. The SQL is
complete without source maps, package source, a build interpreter or privileged
execution. Current runtime authorization and operation identity checks still apply.

The package's bounded source formatter writes the parsed AST to a caller-owned
writer. It normalizes source names/keywords and expression parentheses, omits
comments and retains quoted SQL bytes and lexical adjacency. It does not resolve
imports, bind a catalog or execute tests, and has no public CLI command. Source
round-trips preserve ordered SQL, bindings, fingerprints and logical test plans;
source coordinates, input digests and expansion-derived case identities are
checked separately for the new spelling. Exhausted writer/depth budgets fail
without establishing a complete artifact.

## Typed source specialization

Nominal domains, closed variants and Table instance exports are compile-time
forms. They provide source type checking and do not install runtime domain types,
validate external IDs, grant access or dispatch on live request values.

```text
CREATE PUBLIC DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id';
CREATE PUBLIC DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id';
CREATE PUBLIC VARIANT Target AS (Machine(id MachineId), Site(id SiteId));
```

A domain wraps BIGINT, TEXT or BOOLEAN. Its identity is 1–128 UTF-8 bytes,
compared exactly; its definition fixes the base type. Import the original public
declaration to share a domain. Independent declarations with the same identity
reject, even with equal base types. Paths, aliases and physical representations
are not nominal identity. Constructors such as `MachineId(7)` accept a base
value; implicit conversion, rebranding, unwrapping, arithmetic and ordering
reject. Equality/inequality require the same domain. Named parameter kinds and
`TYPE imported.MachineId` retain that type through module interfaces.

A variant has 1–64 unique constructors, each with at most 64 unique scalar/domain
fields. Nested/recursive variants reject. `Target.Machine(MachineId(7))` constructs
a value; imported constructors use `types.Target.Machine(...)`. Source references
have at most three components. A variant cannot become an SQL operand.

`MATCH value WHEN Target.Machine(id) THEN ... WHEN Target.Site(id) THEN ...
END MATCH;` requires every constructor exactly once, with exact arity. Binders
are lexical and cannot shadow existing bindings/imports. All arms of a reached
specialization are typechecked with symbolic payload types; unselected arms
produce no output. No dummy source value establishes a binding. Branch catalogs
are isolated and only the selected branch contributes definitions afterward.
Recursion and all-arm checking share the existing work/depth/memory quotas.

`USE Factory(arguments) AS instance;` retains an immutable instance export map.
`EXPORT TABLE $name AS rows;` exports an already declared PUBLIC Table owned by
that invocation. `EXPORT TABLE instance.rows AS rows;` forwards an existing
export without re-instantiation. An instance has at most 64 unique exports.
A parameter such as `rows TABLE(id MachineId PRIMARY KEY)` requires an exact
ordered column/key/nullability/collation signature. Signature columns use the
three scalar types or nominal domains, with optional NULL/NOT NULL, PRIMARY KEY
and COLLATE clauses. Runtime schema limits also apply. Defaults, CHECK constraints
and other semantic column options cannot be hidden by a smaller signature.
A Table value becomes a quoted name only in a Table position; it is not an
IDENTIFIER, scalar, type, permission or durable catalog ID.

A nominal TYPE hole annotates a non-null Table column before erasure to its
ordinary physical type. Defaults and CHECK expressions involving nominal columns
reject. Source accesses through literal names and identifier parameters consult
the same annotated schema. Direct projection, same-domain equality/inequality,
and direct typed INSERT/UPDATE assignments are admitted; raw nominal-position
literals, casts, arithmetic, ordering and nominal-discarding functions/aggregates
reject. Unannotated columns retain the ordinary Table profile. Row assertions
observe base values and do not construct source values from database results.

The checked representation retains nominal definitions, operand roles and exact
Table bindings separately from scalar SQL fingerprints. Generated SQL contains
only ordinary Table operations, in selected lexical order. Direct SQL remains
subject to its scalar contract and current authorization; no type sidecar is
needed to execute it. Source/provenance digests include type and export inputs.
This extension does not change native wire/storage or lock/cache definitions.

## Compilation core and extension obligations

The implemented chain is source AST, resolved graph, bounded typed evaluation,
ordered SQL/test products, then independent ordinary SQL rebind. These are
in-process compiler stages, not a persisted public IR or a new execution
authority. A verification projection does not become a runtime dependency.

Future language extensions must carry the following information through their
typed representation and ordinary SQL lowering. They are obligations, not
implemented syntax or proved properties:

| Information | Static/lowering obligation | Runtime or proof owner |
| --- | --- | --- |
| Object/domain/definition identity | Keep nominal references distinct despite identical scalar encodings; preserve explicit instance bindings in SQL | Catalog definition and operation checks; selected identity-preservation lemmas |
| Types, cardinality and cell states | Preserve one/optional/many and value/NULL/missing/type-error/conflict; check variants and refinements | Shared Fuze types and native constraints; selected type/refinement preservation |
| Query/command/module signatures | Check inputs, outputs and behavioral obligations; specialization cannot widen effects | Ordinary statement preparation and current authorization |
| Ordered guards and effects | Retain refusal order, read/write dependencies, atomic boundaries and time/random inputs in executable operations | Transaction/effect owners; temporal interleavings and native trace correspondence |
| Capabilities and protected values | Track ownership, settlement and disclosure; emit explicit authorized operations and secret references | Live policy/fencing, connector settlement and information-flow proofs |
| Transitions and observation basis | Preserve before/after states, original operation identity and exact evidence; unknown is not success | Durable history and observation owners; temporal safety/liveness under stated fairness |
| Proof basis | Identify property, assumptions, abstraction, bounds and exact source/SQL/tool artifacts | Independently executed models, native traces and selected Lean theorems |

Absent information is unsupported, never an empty effect set or presumed proof.
Later transition/effect constructs must supply explicit TLA+ abstractions and
native trace projections when introduced. Later typed-core transformations must
state and check selected Lean preservation obligations with their lowering.
Shared generation of a model and SQL does not itself prove correspondence.
This source grammar slice adds no temporal-model result or Lean theorem.

## Resolution and locks

Relative imports resolve beneath their package root; absolute paths, `..`, empty
components, symlinks and undeclared file kinds reject. A package consists of
UTF-8 `.transit` files selected from a bounded tree, sorted by relative path.
Directories named `.git` or `.transit` are excluded. Other regular files are
ignored; symlinks and special file kinds reject. Repository dependencies are
explicit source declarations:

```text
DEPENDENCY common FROM 'https://example.invalid/team/library.git'
  REVISION '0123456789012345678901234567890123456789'
  SUBDIRECTORY 'transit';
IMPORT shared FROM PACKAGE common FILE 'build.transit';
```

An exact 40-hex Git revision is required. HTTPS and explicitly named local Git
repositories are supported; URLs cannot include userinfo, queries or fragments. `transit build --fetch` is the only
network-enabled resolution mode. It fetches explicit revisions without hooks,
submodules, build scripts or working-tree execution, verifies selected source,
and writes `transit.lock` plus content-addressed package cache entries. A normal
build never fetches or changes the lock. Transitive dependencies use the same
rules and cannot choose conflicting resolutions for one package name.

The lock includes its source-format identity, the current native contract
definition and a sorted dependency list of name, repository, revision,
subdirectory and source-tree SHA-256. Hash the domain `transit.source.tree.v1\0`
then each sorted UTF-8 relative path and file content with unsigned 64-bit
little-endian byte lengths. A cache entry must match the complete tree digest.
No hostname or revision string substitutes for content verification. Cache entries
are `.transit/packages/DIGEST/` directories containing a source tree and a
format/definition/digest manifest. Package names are global within the graph.

CLI override names use normalized lowercase package names.
`--override name=directory` explicitly replaces one declared dependency with
local source. Record its content digest and override status in provenance and
cache identity; never rewrite a repository lock entry to pretend it was fetched.
Missing locks, missing cached content, undeclared imports and changed bytes reject.

## Bounds, ownership and artifacts

Default maximums are 1 MiB per file, 16 MiB aggregate source, 256 source files,
64 import/constructor levels, 100,000 evaluation steps, 64 MiB accounted compiler
allocations and 8 MiB output SQL. Statement owners retain their 4,096-byte bound.
Compiler callers may lower quotas; they cannot use budgets to enable unsupported
syntax. Bounds cover both conditional branches' syntax; execution work covers
the evaluated branch. Parser recursion has an independent bounded depth.

Tooling separately bounds owned allocations to 256 MiB, directory entries to
16,384, dependency declarations to 256 and resolved dependency names to 255.
Locks are at most 64 KiB; provenance is at most 64 MiB. Each Git command has a
120-second deadline and bounded captured output. Git transport/object storage
cost is separate from compiler resident quotas. Fetch requires an installed Git;
offline build/check requires no Git executable.

Inputs remain immutable for a compile. Retained output is independently owned;
scratch resets cannot invalidate it. Allocation failure leaves no result. A work,
depth, memory or output limit produces a located diagnostic and no complete
artifact. Source files and graph state count against resident budgets separately
from reusable statement scratch. No statement or atomic unit is split to fit.

The artifact contains executable SQL and a provenance/source-map JSON file.
Record source/dependency digests, selected target, explicit instance-input digests,
compiler source revision and executable digest, source-format identity, native contract definition,
SQL digest and per-statement definition/call sites. Cache keys include all these
inputs and the compiler budgets. Paths may change provenance/cache identity but
cannot change explicitly bound runtime names. Cache bytes are verified and never
serve as an authorization or correctness oracle.

Publish artifacts using an owned temporary directory and one final directory
rename, after complete compilation/verification. Existing outputs are never
partially overwritten. Check-only performs compilation, emission and equivalence
checking without publishing. An interrupted build has no successful completion
record; previous successful artifacts retain their original input identity.

## CLI and diagnostics

```text
transit build [-f build.transit] [--target default] [--out DIRECTORY]
              [--check] [--fetch] [--override NAME=DIRECTORY] [--format text|json]
```

`--fetch` prepares dependencies/lock only and cannot combine with `--check` or
`--out` or `--override`. `--check` publishes nothing and cannot combine with `--out`. The default
output is `.transit/build/<target>/<input-digest>/`; explicit output directories
must be absent. Build and fetch never read `.transitrc` or connect to Transit.
The build command does not apply migrations or activate application work.

Human status goes to stderr; JSON mode emits one success or diagnostic envelope
on stdout. Failures use [DIAGNOSTICS_V1](DIAGNOSTICS_V1.md), with bounded source
locations, definition/call-site facts, rule and correction guidance. Diagnostic
source locations use one-based lines/byte-columns and zero-based byte offsets.
Values, credentials and fetched source bodies are excluded from diagnostics.
Invalid CLI usage exits 2; compilation/resolution/I/O failures exit 1; success
exits 0. A successful check/build is not execution or installation evidence.

Source/lock/cache formats have one current v1 identity. Foreign/missing format
and native definitions reject; no fallback interpretation exists. This new
source profile changes no accepted native operation, stored runtime format or
wire schema and therefore does not itself change the shared native definition.

## Isolated Table tests

`CREATE TEST TARGET tests AS BEGIN ... END;` selects a test composition.
Build and test targets share the source symbol namespace; command selection must
match the target kind. A test target composes USE and compile-time IF through the
same module evaluator. It may reach declarations of this form:

```text
TEST 'inserts are visible' USING MODULES (rows.Rows(NAME 'items', TYPE BIGINT, 7))
AS BEGIN
  ASSERT COMMAND (INSERT INTO items VALUES (9)) MATCHED 1 CHANGED 1;
  ASSERT ROWS (SELECT id FROM items) EQUAL ((7), (9));
  ASSERT STATEMENT (INSERT INTO items VALUES (7)) FAILS WITH 'duplicate_key';
END;
```

TEST may occur in a module or test target. Every case has an independent proposed
catalog and local runtime. Setup constructors and body SQL use the ordinary
production emitter and independent reparse/rebind. A build reaching TEST, a
nested TEST, an assertion outside TEST, or executable SQL directly in the test
target rejects. All selected cases compile before any runtime starts. Imported
files are parsed normally; only explicitly composed cases execute. File suffixes
do not enable discovery or grant permission. Empty suites reject.

Cases execute in lexical composition order, one at a time. Test identity binds
the target, constructor expansion path and case name. Duplicate identities
reject. Name/alias changes may change test identity, never the explicitly bound
runtime Table names. Case labels are at most 128 UTF-8 bytes and may not contain
control characters. Source spans retain case, definition and invocation sites.

ASSERT COMMAND accepts CREATE TABLE or literal INSERT/UPDATE/DELETE and compares
verified applied/unchanged command outcomes and exact unsigned matched/changed
counts. ASSERT STATEMENT accepts literal mutations and matches only the native
terminal DML reasons `duplicate_key` or `check_violation`; a compiler rejection,
transport error, missing terminal, cancellation or budget failure never satisfies
it. Ordinary statements require successful completion; unasserted SELECTs are
fully consumed. Every assertion contains one ordinary statement without its
terminating semicolon. The Table execution profile is unchanged.

ASSERT ROWS binds each expected literal to the prepared output schema using
Fuze's shared typed literal parser. EQUAL () expects an empty result. Rows are an
unordered multiset of exact canonical schema-bound typed values, including
multiplicity. This is exact-value equality, not collation-based SQL equality or
an implicit ORDER BY. Types, field names/order, NULL and supported cell states
are preserved. No JSON-number conversion or presentation string comparison is
permitted. Every expected row is bounded by the shared value codec; expected
literal text retains the 4,096-byte statement-parser limit. The observed schema
must match, and success requires complete terminal coverage and the exact row
count. Missing/extra/duplicate rows fail; reaching a result limit is not success.

The compiler retains its existing source, work, memory and aggregate SQL-output
limits across the whole suite. Additional ceilings are 128 cases, 1,024 actions
per case and 10,000 expected/observed rows per case. The runner separately bounds
observed canonical cell bytes to 16 MiB per case and reports to 1 MiB per suite.
A case has a 30-second awake-clock budget and a suite has five minutes. Runtime
shutdown has a separate five-second cleanup scope; failure to close/join fails the
run. Host/runner allocations and temporary storage each have a 256 MiB per-case
budget. The local provider reserves at most 192 MiB for ordinary storage plus
32 MiB for control progress; private key/credential files fit in the remaining
allowance. This Table profile does not spill query intermediates. Source/tooling/
compiler allocations retain their separate owner limits.
These are accounted quotas, not guarantees about total process RSS, stack or OS
page-cache usage or filesystem allocation-unit overhead. Exhaustion never silently omits actions or results.

The runner composes real local storage, signed native dispatch, Catalog policy,
DatabaseRuntime and SQL sessions without listeners. It bootstraps synthetic
case-owned credentials and explicit grants; bootstrap authority is distinct
from the statement caller. Test controls never enter deployable SQL. Local
routing has no remote fallback. Private directories are created under `TMPDIR` (otherwise `/tmp`), with mode
0700 and mode-0600 key files. Cases cannot use application configuration,
credentials or installations. Disposal of case-owned data is explicit fixture
cleanup, not application retention or cancellation semantics. Original accepted
operation identities govern settlement after uncertainty; writes are not
recompiled or resubmitted with new identities. Unresolved work fails explicitly.

```text
transit test [-f build.transit] [--target tests]
             [--override NAME=DIRECTORY] [--format text|json]
```

Tests share frozen build resolution and override provenance. Use the explicit
`transit build --fetch` operation to prepare dependencies. Tests never fetch,
change locks, read `.transitrc` or discover server configuration. Success is not
cached. JSON emits one bounded final report; text status uses stderr. Reports
identify source/compiler/native definitions, input/SQL digests, target and cases,
coverage and outcome. Payloads and private installation/credential files are
excluded. Mismatch facts identify the assertion/location rather than print data.

Exit 0 requires all selected cases and cleanup to pass. Invalid invocation exits
2; compilation, assertion, runtime, reporting or cleanup failure exits 1.
Ordinary assertion failures allow later isolated cases to run. A host failure
stops execution and records the not-run suffix. Report coverage (`complete`) is
separate from successful assertions (`ok`); no cases may disappear from either.
Process death supplies no successful terminal report. Compilation diagnostics
use DIAGNOSTICS_V1 and do not imply any SQL acceptance. Runtime reports preserve
failure/uncertainty rather than relabeling them as compile-time non-submission.

Subject/grant DSL controls, virtual clocks, effect mocks, commands, HTTP
simulation, property generators and `--verify-replay` are unsupported. Table
results do not qualify workflow replay, provider idempotency or physical
power-loss durability. This additive source grammar and local test product
change no persistent source lock/cache shape or native format; existing format
and native-definition rejection remains in force.

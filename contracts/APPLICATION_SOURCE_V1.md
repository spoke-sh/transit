# Application source and build v1

This contract specifies the first `.transit` compiler profile. Source compilation
is separate from SQL execution and from the immutable [migration ledger](MIGRATION_V1.md).
The [application reference](../docs/handbook/reference/applications.md#application-source-builds)
describes its supported authoring and execution workflow.

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
shutdown has a separate bounded cleanup scope; failure to close/join fails the
run. Host/runner allocations and temporary storage each have a 256 MiB per-case
budget; source/tooling/compiler allocations retain their separate owner limits.
These are accounted quotas, not guarantees about total process RSS, stack or OS
page-cache usage. Exhaustion never silently omits actions or results.

The runner composes real local storage, signed native dispatch, Catalog policy,
DatabaseRuntime and SQL sessions without listeners. It bootstraps synthetic
case-owned credentials and explicit grants; bootstrap authority is distinct
from the statement caller. Test controls never enter deployable SQL. Local
routing has no remote fallback. Cases cannot use application configuration,
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

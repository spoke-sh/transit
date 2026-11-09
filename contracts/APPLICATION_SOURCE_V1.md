# Application source and build v1

This contract specifies the first `.transit` compiler profile. Source compilation
is separate from SQL execution and from the immutable [migration ledger](MIGRATION_V1.md).
The [implementation plan](../docs/roadmap/application-build-implementation.md)
defines delivery gates. Until those gates execute, this is an implementation contract.

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
Repository dependencies are explicit source declarations:

```text
DEPENDENCY common FROM 'https://example.invalid/team/library.git'
  REVISION '0123456789012345678901234567890123456789'
  SUBDIRECTORY 'transit';
IMPORT shared FROM PACKAGE common FILE 'build.transit';
```

An exact 40-hex Git revision is required. `transit build --fetch` is the only
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
No hostname or revision string substitutes for content verification.

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

Inputs remain immutable for a compile. Retained output is independently owned;
scratch resets cannot invalidate it. Allocation failure leaves no result. A work,
depth, memory or output limit produces a located diagnostic and no complete
artifact. Source files and graph state count against resident budgets separately
from reusable statement scratch. No statement or atomic unit is split to fit.

The artifact contains executable SQL and a provenance/source-map JSON file.
Record source/dependency digests, selected target, explicit instance inputs,
compiler source revision, source-format identity, native contract definition,
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
`--out`. `--check` publishes nothing and cannot combine with `--out`. The default
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

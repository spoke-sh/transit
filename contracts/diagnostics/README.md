# Declarative diagnostic coverage

`inventory.json` records the production owners of SQL compilation, query/state
operations, application publication/migration, serving/reactive/effect outcomes
and their public adapters. It includes literal error references, qualified
named/anonymous enum/union tags, declared error sets, error-return signatures,
open `anyerror` uses, propagation counts, imports and the complete checked
SQL/application grammar productions.
Error-reference counts also detect another occurrence of an already known error
in the same owner; line numbers and formatting are not identity.

The source check lexes out comments, string contents and inline tests. Standalone
test/fixture files and generated dependency/output trees (`zig-pkg`, `zig-out`,
`node_modules` and hidden directories) are excluded. Local dependency caches must
not determine the checked surface; imported external failures belong to their
calling boundary. References include error handlers as well as
error origins: this is a conservative review surface, not inferred reachability.
New owners, imports, errors, tags and grammar alternatives require an explicit
inventory review. Changes to ordinary implementation text do not churn the
inventory. Type and function scopes qualify nested declarations and inline field
types, so two different `phase` fields cannot silently collapse into one entry.
Grammar-only and proposed syntax do not become executable by appearing
here.

The inventory does not resolve Zig types or prove that every error propagating
through an inferred error set is listed. Explicit signatures are retained as
token expressions; inferred and open error sets are identified without inventing
their members. External I/O/allocation failures, dynamic handler errors and
native rejections need owning boundary mappings. Nor does a recorded error prove
that its diagnostic has context, valid recovery advice or an executed negative
case. Those are separate requirements tracked by
[#69](https://github.com/rupurt/rey/issues/69).

Run `just test::diagnostic-inventory` in the pinned development shell. After
reviewing a changed surface and its mappings/evidence, use
`python3 -B tests/diagnostic_inventory.py --record` to update the source record.
Recording does not certify diagnostic implementation or test coverage.

`mappings.json` records the implemented semantic coverage boundaries separately.
Each entry owns its source patterns, stable codes/categories, stage, outcome,
available context, disclosure, recovery, propagation policy and executable test
owners. The SQL compiler boundary covers every literal cause in its selected
owners; a consumed cursor sentinel and the separately mapped editor-cursor
failure are explicit exceptions with rationale and cases. A new matching source
file participates automatically. Changing the inventory cannot make an unmapped
cause, changed stable code or untested exception pass this independent gate.

Run `just test::diagnostic-mappings` for mapping drift and mutation checks. Full
`just check` also executes the owning unit cases. The SQL registry case routes
every registered cause through the public classifier and validates its resulting
envelope, outcome and absence of unsafe recovery actions. Finding a test in source
only establishes ownership; it does not count as executing that test. The mapping
manifest certifies its named compiler, migration and query caller boundaries, not every inventoried
runtime/adapter boundary or every grammar alternative. Those remaining mappings
must be added with their own executable cases before completeness is claimed.


`outcomes.json` owns reviewed semantic expectations for retained query failures,
mutation phases/reasons/input rejections, catalog receipts/input dispositions,
serving waits/input rejections, Follow stops, exchange capture closure, native
effect phases/closures and publication phases/input rejections. Shared migration progress and input rejections are included. Each family names
its actual source enum or closed classification registry, projection, context, disclosure and recovery contract.
Every enum tag requires an executable projection. Query codes run across both
recorded stages and all three supported failure phases.

`just test::diagnostic-outcomes` executes those public projections and checks the
stable code/category, stage/outcome, evidence, complete operation identity, fact
origin/availability and exact action targets. Expectations are separate from the
implementation and source inventory; updating `inventory.json` cannot admit a
new outcome or change its meaning. There is no automatic expectation-recording
mode. Review changes against the owner contract and its transition evidence.
Negative mutations check omitted/duplicate cases, new enum tags, changed semantic
fields, wrong recovery targets, withheld facts and unsafe retry advice.

The projection fixture uses valid synthetic retained records. It does not execute
an authority, prove current access, reproduce a rejecting turn or verify all
optional witness values. Owner tests and restart/commit/disclosure proofs retain
those responsibilities. A listed enum's completeness is not completeness across
all runtime adapters or grammar alternatives. In particular, query lifecycle status without a failure and application-owned transform errors
remain separate coverage obligations.

The query caller boundary checks its own finite causes and delegated retained
query/transport classifications. Reviewed overlaps are explicit; an added cause
cannot silently inherit a different classifier. The executable matrix projects
every mapped cause as both a failed status read and a dispatched command. This
tests that local classifications never erase submission uncertainty. Native
authority rejection remains distinct. `diagnostic_case_codes.py` only generates
test inputs from the reviewed manifest; it cannot record expected semantics.


The migration ledger mapping boundary covers all thirteen terminal input causes.
Invalid/changed owner configuration, absent initialization and oversized transform
output are explicit unresolved exceptions, tested for unchanged decisions and
rollback. Allocation/storage and application-defined transform failures still
propagate to their owning boundary; the shared ledger cannot invent their meaning.

`grammar.json` connects the two checked reference grammars to actual public
query/template, mutation, state-declaration and application compiler outcomes.
`just test::diagnostic-grammar` regenerates independent ANTLR parsers and checks
every parser rule, every nested alternative, both optional branches, and zero,
one and multiple repetitions where admitted. Coverage follows actual parse-tree
children; a declared case label cannot assert that an unvisited branch ran.
New parser rules/branches fail unless the reviewed corpus exercises them.

The public compiler consumer checks the same inputs against reviewed acceptance,
semantic codes/categories, no-send outcomes, safe actions and selected original
context. Cases include malformed complete inputs and valid-but-unavailable
routes. Grammar-only families explicitly preserve unvalidated syntax; reference
acceptance never makes them executable. The corpus also covers token framing,
comments, quotes, full-width literals, constraints and source/type attribution.
The EBNF gate measures parser alternatives, not every possible lexical byte,
combination, implementation budget or authority schedule. Those continue to use
the owning unit, CLI and runtime proofs. No execution authority is present in
this compiler-only fixture. Expected semantics have no automatic record mode.

The application compiler and host have separate closed boundaries. The compiler
projects all fifty registered causes at parse/output boundaries; the host projects
all forty-six causes as failed reads and dispatched commands. The finite entries
also own named explanations, avoiding a second cause shortlist. Owner unit and
actual compiler fixtures verify first-dimension capacity witnesses and no-send
configuration validation. These mappings do not certify arbitrary application
transform errors or unlisted external-library failures.

The query boundary includes typed values, draft records, source/bundle codecs and
template callers. The matrix also projects every mapped query cause through
Board's HTTP fallback and Flight's RPC adapter, checking actual transport status
against reviewed expectations. Flight sequence/protobuf mappings are explicit
profile differences. Native route dispositions and actual admission/disclosure
remain covered by their real adapter proofs. A passing shared-cause matrix does
not certify unrelated adapter startup/configuration or arbitrary library errors.

The mutation and catalog caller registries cover their selected bridge, client,
request/record and catalog inspection/model owners. Independent read/dispatch
projections distinguish authority rejection from operation identity conflict,
retain exact selected read targets, and preserve uncertainty after dispatch.
Transport truncation records an unrecorded origin rather than inventing a remote
outcome. Native ABI tests exercise real refused status reads; this mapping scope
does not certify every transitive framework or application handler error.

Board inspection combines its finite registry with the shared query caller
mappings. The independent matrix checks each selected cause both as a failed read
and under current denial, plus retention of every native error tag. Read-specific
native meanings override generic rejection only where the owner defines them;
other tags remain explicit native causes without inventing a domain outcome.

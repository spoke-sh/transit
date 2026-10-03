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
manifest currently certifies the named compiler boundary, not every inventoried
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


The migration ledger mapping boundary covers all thirteen terminal input causes.
Invalid/changed owner configuration, absent initialization and oversized transform
output are explicit unresolved exceptions, tested for unchanged decisions and
rollback. Allocation/storage and application-defined transform failures still
propagate to their owning boundary; the shared ledger cannot invent their meaning.

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

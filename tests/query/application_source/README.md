# Application source correspondence

The [source contract](../../../contracts/APPLICATION_SOURCE_V1.md) owns semantics;
the [ANTLR grammar and independent corpus](../../../contracts/application-source/README.md)
own the reference syntax. This directory checks those against the actual compiler
package, independently of SQL execution and interface/UI declaration parsing.

`driver.zig` projects production ASTs and compiled products and calls the package
formatter. It imports package modules through the build graph. `reference.py`
derives ASTs only from the ANTLR parse tree. `verify.py` requires exact record
coverage, compares both with independent expectations, checks byte coordinates,
formatter idempotence and equivalent ordered SQL/schema/plan/test results.
Only source spans/digests and source-derived test identity may differ after
formatting; literals, bindings, actions, expected typed bytes and counts remain.

Run `just test::application-source-grammar` inside `nix develop`. The task uses
the existing pinned SQL tools; those tools are absent from the installed runtime
dependency graph. Generation, compiled projection and comparison have separate
failure outcomes. Every run retains its inputs, outputs, seed, source/tool/binary
identities and coverage under a unique ignored
`.cache/verification/application-source-grammar/run-*` directory. Missing or
incomplete evidence cannot pass. ANTLR warnings, recovery and reported exact
ambiguities fail. Each subprocess has a 120-second deadline. The private driver
bounds input/output at 16 MiB, requests at 512 and per-case allocations at
128 MiB; production compiler bounds remain unchanged.

Negative controls corrupt expected ASTs, hole kinds, literals, precedence,
case/action/result coverage. They must fail the intended comparison. The finite
generated cases retain a fixed seed and case number. This is parser/lowering
correspondence, not exhaustive verification, authorization evidence, runtime
execution, effect replay or provider qualification. Existing real application
build/test schedules own runtime consumer regressions.

The SQL emitter preserves contiguous decimal/exponent, cast and comparison
lexemes. Decimal/exponent and `!=` build cases close earlier whitespace-insertion
refusals; cast recognition alone does not enable native Table casts. These fixes
do not change SQL for previously accepted inputs. Source
formatting retains SQL token adjacency and quoted bytes while normalizing words
and source-expression parentheses. It does not bind a catalog or execute tests.

## Typed-target laws and correspondence

`types.py` drives `just test::application-source-types` with the repository-pinned
Lean 4 tool. [TypedTarget.lean](../../../contracts/application-source/TypedTarget.lean)
models exact scalar/domain types, typed de Bruijn variables, checked total variant
arm tables and ordered inserts into explicitly typed Table bindings. It proves
nominal substitution, exhaustive selection and specialization preservation.
The premise that constructor labels are complete and unique is supplied by the checker; the law
does not prove that checker. Other premises and omissions are explicit beside
the definitions. No source parser, SQL encoder, bounded Zig evaluator, storage,
authority, liveness or effect claim follows from these laws.

Sixteen independent descriptors vary constructor, signed/equal raw values, arm
order and explicit Table names. They generate source and Lean examples against
independent expected actions. Forty-eight finite Lean checks cover constructor selection, source
and specialized interpretations; the production driver separately exposes
checked column/domain/operand records and ordinary SQL. A scalar SQL fingerprint
cannot detect a swapped domain, so both projections are required. The compiler
also reparses its emitted SQL through ordinary Fuze owners. Native rows/counts,
restart and revocation belong to the real CLI fixture schedules.

The task audits exact theorem/output inventories. Nominal substitution and
specialization permit only `propext`; exhaustive selection and its finite uses
also permit `Quot.sound`, inherited from Lean's list filter/count lemmas. These
are standard logical axioms, not assumed application/compiler properties.
An actually incomplete Lean proof, omitted output and unreviewed axioms fail the
guard. Swapped domains/Tables, changed values/SQL and missing actions must fail
comparisons; real wrong-domain source programs must fail without a product.
Unique `.cache/verification/application-source-types/run-*` directories retain
inputs, products, specification/driver hashes, Lean identity and complete evidence.
The subprocess deadline is 120 seconds; the private projection keeps the grammar
check's input/output/request bounds. The fast `--check-inventory` mode checks
registration and audit controls only and never claims to execute Lean.

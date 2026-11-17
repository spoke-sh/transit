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
arm tables, ordered inserts into explicitly typed Table bindings, five-state
pure function expressions, ordered guard checks and single-decision atomic
procedure steps. Its eleven laws cover nominal substitution, exhaustive selection,
specialization preservation, domain-preserving record projection, program
substitution, ordered event erasure, five-state pure function substitution,
lexical guard-sequence refusal preservation, guard-reordering non-equivalence
and hygienic inline atomic procedure rollback and returning values. The program and procedure
fragments model typed scalar guards/writes and explicit acquisition/read/atomic
markers; physical typing, nullability and well-formed execution remain premises,
not proved runtime behavior.
The premise that constructor labels are complete and unique is supplied by the checker; the law
does not prove that checker. Other premises and omissions are explicit beside
the definitions. No source parser, SQL encoder, bounded Zig evaluator, storage,
authority, liveness or effect claim follows from these laws.

Sixteen independent descriptors vary constructor, signed/equal raw values, arm
order and explicit Table names. They generate source and Lean examples against
independent expected actions. Ninety-six finite Lean checks cover constructor
selection, source and specialized interpretations, eight explicit nominal
program traces and forty helper function/guard-order/procedure outcomes; the
production driver separately exposes checked column/domain/operand records and
ordinary SQL. A scalar SQL fingerprint cannot detect a swapped domain, so both
projections are required. The compiler also reparses its emitted SQL through
ordinary Fuze owners. Native rows/counts, restart and revocation belong to the
real CLI fixture schedules.

`program_types.py` supplies eight independent nominal program cases and eight
independent helper/guard/procedure cases varying domain identity, signed hole
values and guard placement/order. Checked expression/binding nodes, source
offsets, physical types, nullability, record fields, domains, complete ordered
event sequences, write-expression associations and hand-authored ordinary SQL
are compared, alongside explicit compiler refusals for domain mismatch, Table
interface mismatch, recursive helper cycles and impure functions. This selected
finite fragment complements the larger installed
[typed Queue fixture](../../fixtures/application-typed-queue/README.md) and
[modular Queue fixture](../../fixtures/application-modular-programs/README.md).
Negative controls erase/swap domains, move/swap guards, inject nested atomics,
omit boundaries and alter SQL.

The task audits exact theorem/output inventories. Nine named laws permit only
`propext`; exhaustive selection and its finite uses also permit `Quot.sound`,
inherited from Lean's list filter/count lemmas. These
are standard logical axioms, not assumed application/compiler properties.
An actually incomplete Lean proof, omitted output and unreviewed axioms fail the
guard. Swapped domains/Tables, changed values/SQL and missing actions must fail
comparisons; real wrong-domain source programs must fail without a product.
Unique `.cache/verification/application-source-types/run-*` directories retain
inputs, products, specification/driver hashes, Lean identity and complete evidence.
The subprocess deadline is 120 seconds; the private projection keeps the grammar
check's input/output/request bounds. The fast `--check-inventory` mode checks
registration and audit controls only and never claims to execute Lean.

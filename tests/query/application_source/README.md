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

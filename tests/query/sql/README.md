# SQL conformance

Independent ANTLR/PostgreSQL references, SQLite comparisons and expected binary
plans check the supported SQL profiles. Read the [grammar contract](../../../contracts/sql/README.md)
and [contribution instructions](AGENTS.md).

| Responsibility | Driver |
| --- | --- |
| Reference grammar and AST adapters | [grammar.py](grammar.py), [reference.py](reference.py) |
| Compiler plans and Arrow results | [compiler.py](compiler.py), [unified.py](unified.py) |
| Parameters and logical Table literals | [parameters.py](parameters.py), [table_reference.py](table_reference.py) |
| Declarations, mutations and relational results | [declarations.py](declarations.py), [mutations.py](mutations.py), [relational.py](relational.py) |
| Lean rewrite properties | [rewrites.py](rewrites.py), [specification](../../../contracts/sql/FuzeRewrite.lean) |

Use `just test::sql`, `just test::sql-grammar`, `just test::sql-rewrites` and the
owning DDL/DML recipes. Tasks supply pinned tools and actual native drivers.
Grammar agreement does not establish execution support; SQL protocol/session
qualification lives under [interfaces](../../interfaces/README.md).

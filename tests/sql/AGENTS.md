# Working on SQL conformance

Follow [test instructions](../AGENTS.md). Start with the
[grammar contract](../../contracts/sql/README.md), [SQL reference](../../docs/handbook/reference/sql.md)
and `compiler.py`. This directory owns independent grammar, plan, parameter and
rewrite checks. Installed database transport/session checks have separate owners
in `../sql_wire/` and `../sql_sessions/`.

Use independent expected values and upstream reference parsers only for their
stated profiles. Parser agreement is not execution support. Preserve logical
types, codecs, collations, five-state values, source ordering and unsupported-case
rejection. Keep SQL text, typed operations and result completion distinct.

Run the affected `just test::sql`, `test::sql-grammar`, `test::sql-rewrites` or
DDL/DML task from the repository root. Use the task recipes for pinned tools and
binary inputs. Keep corpus ownership with its contract; add no second generated
definition. Record executed outcomes in qualification history, not the root index.

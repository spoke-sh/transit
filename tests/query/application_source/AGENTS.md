# Working on application source correspondence

Follow the [query instructions](../AGENTS.md) and [owner guide](README.md).
Keep the ANTLR adapter and hand-authored expectations independent of the Zig
compiler. Project production ASTs through package imports; do not add a second
resolver or evaluator. Preserve source coordinates, complete case/action coverage,
typed SQL holes and all compiled bindings through round-trip comparisons.

Run `just test::application-source-grammar` in the pinned development environment.
Keep generated parsers and raw run evidence ignored and unique. A grammar/tool
failure is not an expected program refusal, and correspondence does not prove
native execution or formal preservation.

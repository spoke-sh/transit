# transitc CLI

Composes `transitc-workspace` and the pure compiler. Supports `build`, including
`--check` and `--fetch`, and help/version. See the
[complete CLI contract](../../docs/handbook/reference/cli.md). Runtime execution
is absent; `test` is rejected. Source report rendering, parsing of build options,
resolution and publication are shared library code rather than CLI copies.

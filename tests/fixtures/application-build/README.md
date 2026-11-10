# Application build fixtures

The small module graph exercises typed value/type/module arguments, recursive
constructors, explicit repeated Table instances and ordinary SQL operations.
`expected.sql` is hand-expanded; expected final rows are `first_items = [8]` and
`second_items = [9]`. Tests must use the production compiler and real SQL caller.

`platform/inputs.json` freezes the seven-file Platform source basis. Those files
are unsupported-target rejection/scanner inputs, not a runnable build example.
They retain their exact upstream bytes. The earlier three-file application
program fixtures remain independent regressions.

See [the source contract](../../../contracts/APPLICATION_SOURCE_V1.md) and
[implementation plan](../../../docs/roadmap/application-build-implementation.md).

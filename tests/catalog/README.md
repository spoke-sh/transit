# Catalog and declaration checks

This owner covers stable object/definition identities, schemas, dependency and
authorization contracts. Read the [catalog package](../../packages/zig/transit-catalog/README.md),
[data model](../../docs/handbook/reference/data-model.md) and
[contribution instructions](AGENTS.md).

| Boundary | Checks |
| --- | --- |
| Independent Table schema bytes | [Schema](tables/table_schema.py) |
| Signed direct declarations and policy | [Envelope validator](tables/direct_table_contract.py), [catalog fixtures](tables/table_catalog.py) |
| Definition/dependency and index lifecycle fixtures | [Catalog](tables/catalog_fixture.py), [indexes](tables/index_lifecycle_contract.py) |
| Native/port result ownership and rejection | [Catalog ABI](tables/catalog_abi.py), [direct ABI](tables/direct_catalog_abi.py) |
| Current authorization through native operations | [Authority schedule](authorization/authorization_native.py) |
| Native declaration and dependency callers | [Lifecycle](tables/direct_table_lifecycle.zig), [dependencies](tables/direct_dependencies.zig), [named resources](tables/direct_named_resources.zig) |

The [test task module](../../tasks/test.just) owns executable commands and matching
binary inputs. ABI helpers are invoked by their real caller schedules; copied
fault-host programs run inside private installations. Installed SDK adapters live
in [sdk/](../sdk/README.md), and direct disk/restart acceptance has a storage owner.
Fixture agreement alone does not establish publication, activation or recovery.

[Logical-family round trips](tables/table_logical_types.py) is an unregistered
helper retained for its independent expected values. No current task invokes its
`qualify` function; it does not establish SQL-to-disk coverage. Validate it against
the current logical schema before attaching it to an executable caller schedule.

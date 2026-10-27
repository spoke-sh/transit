# Logical SQL results

`transit_sql_results` defines statement outcomes and finite typed result progress
independently of communications. It depends on Fuze logical types and native
domain identities, and has no SQL wire, transport, service or renderer dependency.

`CommandCompletion` separates owner-defined counts from row-returning results.
`Observation` distinguishes data cuts from catalog, settings and plan observations.
`Progress` checks immutable attribution, received/delivered counters and terminal
counts. Closing or failing a reader preserves an incomplete prefix; releasing an
already completed result preserves its evidence. `copyRow` copies validated nested
values into a caller-owned bounded arena before iterator scratch can change.

The [semantic contract](../../../contracts/SQL_RESULTS_V1.md) defines the model.
These primitives do not themselves execute SQL, verify source authority or manage
a transport. Concrete session/client adapters own those obligations.

Run `nix develop --command sh -c 'cd packages/zig/transit-sql-results && zig build test'`.
Units enumerate bounded chunk partitions and terminal framing, reject invalid
transitions and verify nested scratch ownership. They do not establish network,
service-recovery or allocator bounds for an integrated client.

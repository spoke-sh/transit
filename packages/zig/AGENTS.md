# Working on shared Zig packages

Start with the [component directory](../../docs/handbook/reference/components.md),
the package README, its `build.zig` and `build.zig.zon`, and the owning public
contract. Keep reusable implementation, unit tests and direct dependencies with
the package. Use exported modules instead of importing a sibling source file.

Follow the data lifecycle and dependency direction. Catalog/control policy,
direct WAL/Table storage and query execution have their own owners; Station
actors provide application execution. Do not move direct ingestion or scans
through an actor fixture merely because a historical test used one. Runtime
packages must not depend on consumer SDKs.

Enter `nix develop`. In the package directory, use `zig build --help` to find its
actual `check` and `test` targets and filtering options. Run the focused owner
while iterating, then its affected cross-component schedules from the
[test index](../../tests/README.md). Package tests can include disk and process
failures; do not assume the word "test" means an in-memory unit check.

Keep standalone package-manifest checks distinct from root graph compilation.
Use `just test::packages-build` when changing shared package wiring, and
`just check contracts` plus dependent callers for public type/ABI changes.
Use committed-source clean qualification for changed build or fixture inputs;
a fast check alone does not qualify native behavior. Preserve finite bounds,
allocation/ownership failures and accepted-work recovery assertions.

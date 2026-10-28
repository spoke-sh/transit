# transit-sql-service

Shared SQL sessions over the [database runtime](../transit-sql/README.md), public
Query source clients and configuration service. Native SQL, PostgreSQL and MySQL
adapters share authentication, preparation, bounded result buffers, current
permission checks and original-operation recovery through this package.

`Registry` owns bounded sessions and retained response batches. `Session` maps
configured database names to Catalog bindings. `ReadSources` composes cleanup
for explicitly configured source connections above the database runtime; it
introduces no database permission or storage authority.

`ConfigurationOperations` records the original reload identity and expected
configuration generation in Catalog before dispatch. `CapturedOperations` stages
a complete compiled bundle and publishes each complete signed Query request
before dispatch. `CapturedRecovery` serializes each source's uncertain request in
a Catalog CAS lane. It records the original receipt and processed-input evidence
before allowing a successor. Status reads never initialize a lane. Source actors
remain the owners of explicit captured Query execution, independently of SQL
account recovery and direct database DDL/DML.

See [source bindings](docs/sources.md), the [SQL session contract](../../../contracts/SQL_SESSION_V1.md)
and [gateway configuration](../../../apps/transit-sql-gateway/docs/configuration.md).
Run `zig build test` or `zig build check` here. The real service proofs use the
[registered SQL checks](../../../tasks/test.just).

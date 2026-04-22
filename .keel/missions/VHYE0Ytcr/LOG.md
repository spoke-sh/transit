# Add Hosted Materialization Primitives For External Daemon Consumers - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-22T13:33:00Z

- Landed hosted cursor, hosted materialization checkpoint, and hosted resume protocol primitives through the shared engine and remote server boundary.
- Exposed the client-first Rust workflow on `TransitClient`, including durable cursor progress, hosted checkpoint persistence, and incremental replay after a verified anchor.
- Added the public hosted materialization proof path plus operator guidance so external-daemon consumers can validate the workflow without opening `LocalEngine`.

## 2026-04-22T13:25:48

Mission achieved by local system user 'alex'

# Unified state queries

The public `unified` module exposes v1 KV/Table/accepted Document sources, plans,
explicit finite budgets and owned nested Arrow results. Shared Zig implements
validation, signatures, admission observation and result verification. Rust owns
typed values, allocation and native-worker lifetimes. Existing Table v1 APIs
remain available; importing the crate performs no work or credential access.

Construct `Source::KV` with versioned key/value `Decoder`s, `Source::Table` with
an exact table/schema, or `Source::Document` with an accepted reference and
bounded projections. `Bundle::prepare` validates them and returns canonical owned
bytes. This local operation grants no access and admits no work.

`Client::open(config, credential, connection)` binds a caller to source/requester
PIDs and resources in one realm. It requires neither activation nor writer
ownership. One owned worker runs native operations on the required stack. Methods
take an exclusive mutable borrow; concurrent access cannot be hidden in an
unbounded executor queue. The API blocks: move the owner into a host blocking
task when integrating with an executor. `close` and drop join native destruction.

`inspect_sql(&source, name, sql, budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...` through the shared Zig inspection owner.
The owned `Inspection` returns source/schema digests, current resource/policy
revisions and an `InspectionDetails` enum: `Description`, `Tables` or
`Explanation`. Explanation includes ordered `InspectionOperator` values,
`InspectedPredicate` structure without literal values, projection/output columns
and explicit budgets. Wide limits and revisions remain `u64`. Inspection checks
current authorization before and after resolution, creates no snapshot and
admits no query. The Table listing covers only the configured source.

Call `describe` to check current policy and limits. `prepare_next(namespace,
&bundle)` prepares one command; persist `Prepared::data()` before `submit(&prepared)`.
The receipt's input position is admission, not query completion. Observe that
position until committed before preparing again. A rejected observation is a
durable behavior rejection. None from preparation means inspect `status`; it
does not prove a complete result.

Submission borrows the prepared command, leaving its exact token owned by the
caller on both success and failure. `ErrorKind::UnknownOutcome` requires retrying
those identical bytes, including on a replacement client. Never parse/re-encode
them or assign a fresh identity to resolve the old attempt. Cancellation,
retirement and collection each have explicit preparation methods with the same
persistence/submission/observation sequence. Dropping a host wait does not cancel
accepted work.

`page(namespace, cursor.as_ref())` returns one owned IPC segment, exact typed
manifest provenance and optional continuation. Every read rechecks current grants
and lifecycle. Retain a cursor only with its connection/namespace; it grants no
permission. Failure cannot advance the borrowed cursor. None next establishes
verified complete coverage. A page's `decode` uses shared Zig to preserve five
cell states and ordered conflict IDs. The optional pinned Arrow 59.1.0 feature
adds `to_arrow`, retaining the nested state/alternative schema.

Bounds are 16 KiB per bundle, eight rows/columns per batch, 4 KiB per scalar and
64 KiB per IPC segment. Full-width counters, integers and float bits survive the
foreign representation. Native response conversion rejects unsupported shapes.

`nix develop .#bindings --command just bindings::unified-rust table` builds fresh
source crates and runs the installed codec/recovery schedule. `kv` and `document`
select the other sources. [Evidence](../../../../tests/README.md) distinguishes
completed runs from planned matrix coverage.

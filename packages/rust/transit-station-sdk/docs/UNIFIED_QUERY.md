# Unified state queries

The public `unified` module exposes v1 KV/Table/accepted Document sources, plans,
explicit finite budgets and owned nested Arrow results. Shared Zig implements
validation, signatures, admission observation and result verification. Rust owns
typed values, allocation and native-worker lifetimes. Importing the crate
performs no work or credential access.

Construct `Source::KV` with versioned key/value `Decoder`s, `Source::Table` with
a catalog `Metadata`, `Schema` and owner `ProcessRef`, or `Source::Document` with an accepted reference and
bounded projections with `DecoderColumn` declarations. Query `Type`, `Scalar`
and cell types reuse the shared logical models; `Column` has a descriptor and
explicit nullable/optional flags. `DecoderType` retains the six-scalar KV/Document
profile. The native query owner verifies the metadata commitment and current
catalog rights. `Bundle::prepare` validates them and returns canonical owned
bytes. This local operation grants no access and admits no work.

`Predicate::Program(Vec<PredicateInstruction>)` accepts one to 64 owned postfix
instructions. `PredicateInstruction::Atom` wraps `PredicateAtom::All`, `State`
or `Compare`; `Negate`, `Conjunction` and `Disjunction` combine them. The atom
type cannot contain another program. Shared Zig validates stack shape and types
before encoding. Evaluation keeps instruction order, unknown truth and eager
errors. EXPLAIN exposes owned `InspectedPredicate::Program` instructions with
`InspectedAtom` structure and no literals. These host values are not durable
state; preserve the resulting canonical bundle for query recovery.

`Client::open(config, credential, connection)` binds a caller to source/requester
PIDs and resources in one realm. It requires neither activation nor writer
ownership. One owned worker runs native operations on the required stack. Methods
take an exclusive mutable borrow; concurrent access cannot be hidden in an
unbounded executor queue. The API blocks: move the owner into a host blocking
task when integrating with an executor. `close` and drop join native destruction.

`compile_sql(&source, name, sql, budgets, parameters)` returns an owned `Bundle`
under the client's exclusive mutable borrow. `parameters` is `Option<&[Scalar]>`:
`None` selects ordinary SQL; `Some(&[])` selects a template without placeholders.
The result owns its bytes independently of the borrowed source and bindings.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

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
manifest provenance including the retained source-head digest, and optional
continuation. Every read rechecks current grants
and lifecycle. Retain a cursor only with its connection/namespace; it grants no
permission. Failure cannot advance the borrowed cursor. None next establishes
verified complete coverage. A page's `decode` uses shared Zig to preserve five
cell states and ordered conflict IDs. The optional pinned Arrow 59.1.0 feature
adds `to_arrow`, retaining the nested state/alternative schema.

Bounds are 25,069 bytes per bundle, eight rows and 128 result columns per batch,
4 KiB per predicate byte literal and 64 KiB per IPC segment. KV sources have two
columns and Document projections remain bounded to eight. Source/output names
are nonempty UTF-8 of at most 255 bytes without NUL. Full-width counters, integers and float bits survive the
foreign representation. Native response conversion rejects unsupported shapes.

`nix develop .#bindings --command just bindings::unified-rust table` builds fresh
source crates and runs the installed codec/recovery schedule. `kv` and `document`
select the other sources. [Evidence](../../../../tests/README.md) distinguishes
completed runs from planned matrix coverage.

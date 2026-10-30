//! Direct-plane managed computations (`MATERIALIZED VIEW`, `DATAFLOW`,
//! `SUBSCRIPTION`), the five-state computation lifecycle (`Published`,
//! `Authorized`, `Active`, `Suspended`, `Retired`), explicit DDL verbs
//! (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`), `TransitLog` (`TWAL1`)
//! delta scheduling under fenced `_lease_epoch` worker leases, atomic
//! snapshot-to-live handoff (`T5`), Milestone 5 multi-object `Transaction.Cut`
//! (`0x54584331`) commit alignment, upstream schema evolution gates (`T8`), and
//! governed `CONNECTION`/`SOURCE`/`SINK` catalog lifecycle with atomic outbox
//! effect recording (`D1`–`D4`, `D8`, `P0`, `P6`–`P9`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const AnalyticalSql = fuze.AnalyticalSql;
const FuzeDelta = fuze.FuzeDelta;
const OperatorTraits = fuze.OperatorTraits;
const Types = fuze.Types;
const v = Types.Values;

pub const definition = "transit.catalog.dataflow.v1.2026-10-30";
pub const max_sources_per_dataflow: usize = 8;
pub const max_pending_tx_records: usize = 64;
pub const max_outbox_intents: usize = 64;
pub const max_catalog_endpoints: usize = 32;

pub const DataflowKind = enum(u8) {
    materialized_view = 1,
    dataflow = 2,
    subscription = 3,
};

/// Five-state computation lifecycle (`D2`, `T8`).
/// Replaces boolean `ENABLE`/`DISABLE` toggles so publication, authorization,
/// active scheduling, operational suspension, and permanent retirement remain distinct.
pub const LifecycleState = enum(u8) {
    published = 1,
    authorized = 2,
    active = 3,
    suspended = 4,
    retired = 5,
};

/// Explicit DDL lifecycle verbs plus dialect-ergonomic aliases (`M34`).
pub const LifecycleCommand = enum(u8) {
    authorize = 1,
    activate = 2,
    suspend_computation = 3,
    resume_computation = 4,
    refresh = 5,
    retire = 6,
    dialect_enable = 7, // PostgreSQL alias -> lowers to .activate
    dialect_disable = 8, // PostgreSQL alias -> lowers to .suspend_computation

    pub fn canonical(self: LifecycleCommand) LifecycleCommand {
        return switch (self) {
            .dialect_enable => .activate,
            .dialect_disable => .suspend_computation,
            else => self,
        };
    }
};

pub const ConsumerContract = enum(u8) {
    complete_ordered_changes = 1,
    net_relation_changes = 2,
    finite_recomputation = 3,
};

pub const ResumePolicy = enum(u8) {
    replay_history = 1,
    recompute_snapshot = 2,
};

pub const BlockedReason = enum(u8) {
    none = 0,
    awaiting_authorization = 1,
    policy_revoked = 2,
    history_expired = 3,
    incompatible_source_schema = 4,
    source_phased_rewrite_in_progress = 5,
    sink_unavailable = 6,
    budget_exhausted = 7,
    lease_fenced = 8,
    credential_pending = 9,
};

pub const SourceEvolutionClass = enum(u8) {
    unchanged = 0,
    class_a_lazy_compatible = 1,
    class_b_phased_rewrite = 2,
    incompatible_ddl = 3,
};

pub const SourceBinding = struct {
    object_id: u64,
    definition_id: u64,
    checkpoint_lsn: u64 = 0,
    checkpoint_manifest_version: u64 = 0,
};

/// Completed revision receipt (`DFR1`).
pub const CompletedRevisionReceipt = struct {
    revision_number: u64 = 0,
    source_manifest_version: u64 = 0,
    source_commit_lsn: u64 = 0,
    tx_cut_id: u64 = 0,
    row_count: usize = 0,
};

/// Recorded connector sink outbox intent committed atomically with the dataflow's
/// watermark (`DFW1`) and completed revision (`DFR1`).
pub const SinkOutboxIntent = struct {
    intent_id: u64,
    dataflow_id: u64,
    dataflow_definition_id: u64,
    revision_number: u64,
    sink_object_id: u64,
    sink_definition_id: u64,
    policy_epoch: u64,
    delta_row_count: usize,
    claimed_by_connector: bool = false,
    acked_by_connector: bool = false,
};

/// Multi-object transaction decision state from Milestone 5's `TransactionDecisionLog`
/// (`0x54584331`).
pub const TxDecisionState = enum(u8) {
    pending_participants = 1,
    committed_cut = 2,
    aborted = 3,
};

pub const WalDeltaRecord = struct {
    source_object_id: u64,
    source_definition_id: u64,
    evolution_class: SourceEvolutionClass = .unchanged,
    tx_id: u64,
    tx_cut_id: u64,
    tx_decision: TxDecisionState = .committed_cut,
    commit_lsn: u64,
    manifest_version: u64,
    row: AnalyticalSql.Row,
    weight: i64,
};

pub const DataflowDeclaration = struct {
    catalog_id: u64,
    dataflow_id: u64,
    name: []const u8,
    definition_id: u64,
    kind: DataflowKind = .materialized_view,
    consumer_contract: ConsumerContract = .net_relation_changes,
    default_resume_policy: ResumePolicy = .replay_history,
    sources: []const SourceBinding,
    target_sink_object_id: ?u64 = null,
    target_sink_definition_id: ?u64 = null,
    max_work_rows: usize = 256,

    pub fn validate(self: DataflowDeclaration) !void {
        if (self.catalog_id == 0 or self.dataflow_id == 0 or self.definition_id == 0) {
            return error.InvalidDataflowIdentity;
        }
        if (self.name.len == 0 or self.name.len > 63) {
            return error.InvalidDataflowName;
        }
        if (self.sources.len == 0 or self.sources.len > max_sources_per_dataflow) {
            return error.InvalidDataflowSourceCount;
        }
        if (self.max_work_rows == 0) return error.InvalidDataflowWorkBudget;
        for (self.sources) |s| {
            if (s.object_id == 0 or s.definition_id == 0) return error.InvalidDataflowSourceBinding;
        }
        if (self.target_sink_object_id != null and self.target_sink_definition_id == null) {
            return error.InvalidDataflowSinkBinding;
        }
    }
};

pub const DataflowInspectionStatus = struct {
    dataflow_id: u64,
    definition_id: u64,
    state: LifecycleState,
    blocked_reason: BlockedReason,
    current_lease_epoch: u64,
    authorized_policy_epoch: ?u64,
    completed_revision: CompletedRevisionReceipt,
    checkpoint_lsn: u64,
    checkpoint_manifest_version: u64,
    observed_head_lsn: u64,
    freshness_lag_lsn: u64,
    has_pending_successor: bool,
    pending_buffered_tx_count: usize,
    outbox_pending_count: usize,
};

pub const DataflowRuntime = struct {
    declaration: DataflowDeclaration,
    state: LifecycleState = .published,
    blocked_reason: BlockedReason = .awaiting_authorization,
    authorized_policy_epoch: ?u64 = null,
    current_lease_epoch: u64 = 0,

    // Bound source lineage & watermarks (DFW1)
    source_count: usize = 0,
    sources: [max_sources_per_dataflow]SourceBinding = undefined,
    checkpoint_lsn: u64 = 0,
    checkpoint_manifest_version: u64 = 0,
    checkpoint_tx_cut_id: u64 = 0,
    handoff_cut_lsn: u64 = 0,
    skipped_duplicate_at_handoff_count: usize = 0,
    discarded_aborted_tx_records: usize = 0,

    // Completed materialized state & receipt (DFR1 + DFA1)
    materialized_state: FuzeDelta.ZSet = .{},
    completed_revision: CompletedRevisionReceipt = .{},

    // Pending multi-object transaction buffer (awaiting M5 Transaction.Cut 0x54584331)
    pending_tx_len: usize = 0,
    pending_tx_buffer: [max_pending_tx_records]WalDeltaRecord = undefined,

    // Transactional sink outbox intents (D8, P7)
    outbox_len: usize = 0,
    outbox: [max_outbox_intents]SinkOutboxIntent = undefined,
    external_effects_dispatched_by_engine: usize = 0,

    pub fn publish(decl: DataflowDeclaration) !DataflowRuntime {
        try decl.validate();
        var rt: DataflowRuntime = .{
            .declaration = decl,
            .state = .published,
            .blocked_reason = .awaiting_authorization,
            .source_count = decl.sources.len,
        };
        for (decl.sources, 0..) |s, i| {
            rt.sources[i] = s;
        }
        return rt;
    }

    pub fn authorize(self: *DataflowRuntime, policy_epoch: u64) !void {
        if (policy_epoch == 0) return error.InvalidPolicyEpoch;
        switch (self.state) {
            .retired => return error.DataflowAlreadyRetired,
            .published, .authorized, .suspended => {
                self.authorized_policy_epoch = policy_epoch;
                if (self.state == .published) {
                    self.state = .authorized;
                }
                if (self.blocked_reason == .awaiting_authorization or self.blocked_reason == .policy_revoked) {
                    self.blocked_reason = .none;
                }
            },
            .active => {
                self.authorized_policy_epoch = policy_epoch;
            },
        }
    }

    /// Atomic snapshot-to-live handoff (`T5`) at initial `ACTIVATE` or
    /// `RESUME WITH (on_resume = 'recompute_snapshot')`.
    pub fn establishSnapshotToLiveHandoff(
        self: *DataflowRuntime,
        snapshot_cut_lsn: u64,
        snapshot_manifest_version: u64,
        snapshot_tx_cut_id: u64,
        initial_snapshot_rows: *const FuzeDelta.ZSet,
    ) !u64 {
        if (self.state == .retired) return error.DataflowAlreadyRetired;
        if (self.authorized_policy_epoch == null) return error.DataflowNotAuthorized;

        self.current_lease_epoch += 1;
        self.state = .active;
        self.blocked_reason = .none;
        self.handoff_cut_lsn = snapshot_cut_lsn;
        self.checkpoint_lsn = snapshot_cut_lsn;
        self.checkpoint_manifest_version = snapshot_manifest_version;
        self.checkpoint_tx_cut_id = snapshot_tx_cut_id;
        self.pending_tx_len = 0;

        self.materialized_state = initial_snapshot_rows.*;
        try self.materialized_state.consolidateCanonical();

        self.completed_revision = .{
            .revision_number = self.completed_revision.revision_number + 1,
            .source_manifest_version = snapshot_manifest_version,
            .source_commit_lsn = snapshot_cut_lsn,
            .tx_cut_id = snapshot_tx_cut_id,
            .row_count = self.materialized_state.len,
        };

        for (self.sources[0..self.source_count]) |*s| {
            s.checkpoint_lsn = snapshot_cut_lsn;
            s.checkpoint_manifest_version = snapshot_manifest_version;
        }

        return self.current_lease_epoch;
    }

    /// `SUSPEND` (or dialect `DISABLE` alias): pauses background delta consumption
    /// and sink outbox staging, fences any in-flight worker lease, preserves
    /// checkpointed watermarks, and continues serving the last completed revision.
    pub fn suspendDataflow(self: *DataflowRuntime) !void {
        switch (self.state) {
            .retired => return error.DataflowAlreadyRetired,
            .published => return error.DataflowNotAuthorized,
            .authorized, .active, .suspended => {
                self.current_lease_epoch += 1;
                self.state = .suspended;
            },
        }
    }

    /// `RESUME WITH (on_resume = 'replay_history' | 'recompute_snapshot')` (`D2`, `T5`, `T8`).
    pub fn resumeDataflow(
        self: *DataflowRuntime,
        policy: ResumePolicy,
        min_retained_wal_lsn: u64,
        recompute_snapshot_cut_lsn: ?u64,
        recompute_manifest_version: ?u64,
        recompute_tx_cut_id: ?u64,
        recompute_snapshot_rows: ?*const FuzeDelta.ZSet,
    ) !u64 {
        if (self.state == .retired) return error.DataflowAlreadyRetired;
        if (self.state != .suspended and self.state != .authorized) {
            return error.InvalidDataflowLifecycleTransition;
        }
        if (self.authorized_policy_epoch == null) return error.DataflowNotAuthorized;

        switch (policy) {
            .replay_history => {
                // If required WAL history after checkpoint_lsn was compacted during suspension,
                // fail closed and record BlockedReason.history_expired (never silently downgrade!).
                if (min_retained_wal_lsn > self.checkpoint_lsn + 1) {
                    self.blocked_reason = .history_expired;
                    return error.DataflowHistoryExpired;
                }
                self.current_lease_epoch += 1;
                self.state = .active;
                self.blocked_reason = .none;
                return self.current_lease_epoch;
            },
            .recompute_snapshot => {
                if (self.declaration.consumer_contract == .complete_ordered_changes and
                    min_retained_wal_lsn > self.checkpoint_lsn + 1)
                {
                    // A slow consumer requiring every ordered intermediate change cannot silently
                    // replace missing intermediate history with a snapshot diff.
                    self.blocked_reason = .history_expired;
                    return error.CompleteOrderedConsumerCannotSkipHistory;
                }
                const snap_lsn = recompute_snapshot_cut_lsn orelse return error.MissingRecomputeSnapshotCut;
                const snap_mv = recompute_manifest_version orelse return error.MissingRecomputeSnapshotCut;
                const snap_tx = recompute_tx_cut_id orelse 0;
                const snap_rows = recompute_snapshot_rows orelse return error.MissingRecomputeSnapshotCut;
                return self.establishSnapshotToLiveHandoff(snap_lsn, snap_mv, snap_tx, snap_rows);
            },
        }
    }

    /// `RETIRE`: permanently closes the definition revision to new activation or
    /// scheduling while preserving historical provenance and completed receipts (`DFR1`).
    pub fn retireDataflow(self: *DataflowRuntime) !void {
        if (self.state == .retired) return error.DataflowAlreadyRetired;
        self.current_lease_epoch += 1;
        self.state = .retired;
        self.pending_tx_len = 0;
    }

    /// Read the last completed result revision (`DFR1`). Works in `Active`,
    /// `Suspended`, and `Retired` states (with exact frozen source basis visible)
    /// while checking current `policy_epoch` read grants.
    pub fn readCompletedRevision(
        self: *const DataflowRuntime,
        has_read_grant_at_current_epoch: bool,
    ) !struct { receipt: CompletedRevisionReceipt, rows: *const FuzeDelta.ZSet } {
        if (!has_read_grant_at_current_epoch) return error.RowSelectPermissionDenied;
        if (self.completed_revision.revision_number == 0) return error.DataflowInitialRevisionNotReady;
        return .{
            .receipt = self.completed_revision,
            .rows = &self.materialized_state,
        };
    }

    /// Consume a batch of `TransitLog` (`TWAL1`) delta records under a fenced
    /// `_lease_epoch` worker lease, aligning multi-object changes to Milestone 5
    /// `Transaction.Cut` (`0x54584331`) boundaries and committing watermark +
    /// revision + sink outbox intent atomically (`D3`, `D8`, `T5`, `T8`).
    pub fn ingestWalDeltaBatch(
        self: *DataflowRuntime,
        worker_lease_epoch: u64,
        current_policy_epoch: u64,
        has_active_dataflow_grant: bool,
        has_active_sink_grant: bool,
        min_retained_wal_lsn: u64,
        records: []const WalDeltaRecord,
    ) !bool {
        if (self.state == .retired) return error.DataflowAlreadyRetired;
        if (self.state != .active) return error.DataflowNotActive;
        if (worker_lease_epoch != self.current_lease_epoch) {
            self.blocked_reason = .lease_fenced;
            return error.StaleDataflowLeaseEpoch;
        }

        // Recheck current authorization at current_policy_epoch before advancing
        const auth_epoch = self.authorized_policy_epoch orelse return error.DataflowNotAuthorized;
        if (current_policy_epoch > auth_epoch and !has_active_dataflow_grant) {
            self.state = .suspended;
            self.blocked_reason = .policy_revoked;
            self.current_lease_epoch += 1;
            return error.DataflowAuthorizationRevoked;
        }
        if (self.declaration.target_sink_object_id != null and !has_active_sink_grant) {
            self.state = .suspended;
            self.blocked_reason = .policy_revoked;
            self.current_lease_epoch += 1;
            return error.SinkAuthorizationRevoked;
        }

        if (min_retained_wal_lsn > self.checkpoint_lsn + 1) {
            self.blocked_reason = .history_expired;
            return error.DataflowHistoryExpired;
        }

        // 1. Validate source schema evolution (`T8`) before mutating state
        for (records) |rec| {
            var source_found = false;
            for (self.sources[0..self.source_count]) |*src| {
                if (src.object_id == rec.source_object_id) {
                    source_found = true;
                    if (rec.source_definition_id != src.definition_id) {
                        switch (rec.evolution_class) {
                            .unchanged, .class_a_lazy_compatible => {
                                // Compatible Class A lazy schema evolution projects seamlessly
                                src.definition_id = rec.source_definition_id;
                            },
                            .class_b_phased_rewrite => {
                                self.blocked_reason = .source_phased_rewrite_in_progress;
                                return error.SourcePhasedRewriteInProgress;
                            },
                            .incompatible_ddl => {
                                self.blocked_reason = .incompatible_source_schema;
                                return error.IncompatibleSourceSchemaEvolution;
                            },
                        }
                    }
                    break;
                }
            }
            if (!source_found) return error.UnboundDataflowSourceObject;
        }

        // 2. Filter handoff duplicates (`lsn <= checkpoint_lsn`) and align M5 multi-object transaction cuts
        var step_delta: FuzeDelta.ZSet = .{};
        var max_committed_lsn: u64 = self.checkpoint_lsn;
        var max_committed_manifest: u64 = self.checkpoint_manifest_version;
        var last_committed_tx_cut: u64 = self.checkpoint_tx_cut_id;
        var committed_any_cut = false;

        for (records) |rec| {
            if (rec.commit_lsn <= self.checkpoint_lsn) {
                self.skipped_duplicate_at_handoff_count += 1;
                continue;
            }

            switch (rec.tx_decision) {
                .aborted => {
                    self.discarded_aborted_tx_records += 1;
                    // Also purge any previously buffered pending records for this aborted tx_id
                    var write_i: usize = 0;
                    for (self.pending_tx_buffer[0..self.pending_tx_len]) |buffered| {
                        if (buffered.tx_id != rec.tx_id) {
                            self.pending_tx_buffer[write_i] = buffered;
                            write_i += 1;
                        } else {
                            self.discarded_aborted_tx_records += 1;
                        }
                    }
                    self.pending_tx_len = write_i;
                },
                .pending_participants => {
                    // Hold participant record until M5 Transaction.Cut (0x54584331) commits
                    if (self.pending_tx_len >= max_pending_tx_records) {
                        self.blocked_reason = .budget_exhausted;
                        return error.DataflowPendingTransactionBufferFull;
                    }
                    self.pending_tx_buffer[self.pending_tx_len] = rec;
                    self.pending_tx_len += 1;
                },
                .committed_cut => {
                    // Flush all previously buffered participant records belonging to rec.tx_id
                    var write_i: usize = 0;
                    for (self.pending_tx_buffer[0..self.pending_tx_len]) |buffered| {
                        if (buffered.tx_id == rec.tx_id) {
                            try step_delta.addRowWeight(buffered.row, buffered.weight);
                            if (buffered.commit_lsn > max_committed_lsn) max_committed_lsn = buffered.commit_lsn;
                            if (buffered.manifest_version > max_committed_manifest) max_committed_manifest = buffered.manifest_version;
                        } else {
                            self.pending_tx_buffer[write_i] = buffered;
                            write_i += 1;
                        }
                    }
                    self.pending_tx_len = write_i;

                    // Apply the committing record itself
                    try step_delta.addRowWeight(rec.row, rec.weight);
                    if (rec.commit_lsn > max_committed_lsn) max_committed_lsn = rec.commit_lsn;
                    if (rec.manifest_version > max_committed_manifest) max_committed_manifest = rec.manifest_version;
                    last_committed_tx_cut = rec.tx_cut_id;
                    committed_any_cut = true;
                },
            }
        }

        if (!committed_any_cut) {
            // Only pending or duplicate/aborted records arrived; preserve last completed revision!
            return false;
        }

        // 3. Stage candidate materialized state before committing revision + watermark + outbox atomically
        var candidate_state = self.materialized_state;
        try candidate_state.addZSet(&step_delta);
        try candidate_state.consolidateCanonical();
        if (candidate_state.len > self.declaration.max_work_rows) {
            self.blocked_reason = .budget_exhausted;
            return error.DataflowWorkBudgetExceeded;
        }

        const next_rev_num = self.completed_revision.revision_number + 1;
        if (self.declaration.target_sink_object_id) |sink_obj| {
            if (self.outbox_len >= max_outbox_intents) {
                self.blocked_reason = .sink_unavailable;
                return error.DataflowSinkOutboxFull;
            }
            self.outbox[self.outbox_len] = .{
                .intent_id = next_rev_num,
                .dataflow_id = self.declaration.dataflow_id,
                .dataflow_definition_id = self.declaration.definition_id,
                .revision_number = next_rev_num,
                .sink_object_id = sink_obj,
                .sink_definition_id = self.declaration.target_sink_definition_id.?,
                .policy_epoch = current_policy_epoch,
                .delta_row_count = step_delta.len,
            };
            self.outbox_len += 1;
        }

        // Commit watermark (DFW1) + materialized state (DFA1) + completed revision (DFR1) atomically
        self.materialized_state = candidate_state;
        self.checkpoint_lsn = max_committed_lsn;
        self.checkpoint_manifest_version = max_committed_manifest;
        self.checkpoint_tx_cut_id = last_committed_tx_cut;
        self.completed_revision = .{
            .revision_number = next_rev_num,
            .source_manifest_version = max_committed_manifest,
            .source_commit_lsn = max_committed_lsn,
            .tx_cut_id = last_committed_tx_cut,
            .row_count = self.materialized_state.len,
        };
        for (self.sources[0..self.source_count]) |*src| {
            src.checkpoint_lsn = max_committed_lsn;
            src.checkpoint_manifest_version = max_committed_manifest;
        }
        return true;
    }

    /// Zero-work `EXPLAIN DATAFLOW` (`P8`): inspects operator traits and lineage
    /// without acquiring snapshot pins, reading `.tseg` segments, mutating state,
    /// or dispatching external connector effects.
    pub fn explainZeroWork(self: *const DataflowRuntime) OperatorTraits.ExplainSummary {
        const traits: OperatorTraits.Summary = .{
            .effects = .{
                .read = true,
                .mutate = false,
                .capture = true,
                .dispatch = self.declaration.target_sink_object_id != null,
            },
            .deterministic = true,
            .fallible = true,
            .five_state_rule = .preserves_all_states,
            .collation_rule = .column_bound,
            .active_collations = 1,
            .change_mode = .retractable_zset,
            .work_bound = .{
                .max_output_rows = self.declaration.max_work_rows,
                .max_resident_bytes = null,
                .max_spill_bytes = null,
                .max_work_steps = null,
                .max_source_pins = @intCast(self.source_count),
                .acquires_data_pins = true,
                .reads_storage_segments = true,
                .mutates_durable_state = true,
            },
        };
        return OperatorTraits.Summary.forExplain(traits);
    }

    /// Read-only inspection surface for SQL (`SHOW`/`DESCRIBE`), SDKs, Flight and Board (`P8`).
    pub fn inspectStatus(self: *const DataflowRuntime, observed_head_lsn: u64) DataflowInspectionStatus {
        var unacked_outbox: usize = 0;
        for (self.outbox[0..self.outbox_len]) |intent| {
            if (!intent.acked_by_connector) unacked_outbox += 1;
        }
        return .{
            .dataflow_id = self.declaration.dataflow_id,
            .definition_id = self.declaration.definition_id,
            .state = self.state,
            .blocked_reason = self.blocked_reason,
            .current_lease_epoch = self.current_lease_epoch,
            .authorized_policy_epoch = self.authorized_policy_epoch,
            .completed_revision = self.completed_revision,
            .checkpoint_lsn = self.checkpoint_lsn,
            .checkpoint_manifest_version = self.checkpoint_manifest_version,
            .observed_head_lsn = observed_head_lsn,
            .freshness_lag_lsn = if (observed_head_lsn > self.checkpoint_lsn)
                observed_head_lsn - self.checkpoint_lsn
            else
                0,
            .has_pending_successor = self.pending_tx_len > 0,
            .pending_buffered_tx_count = self.pending_tx_len,
            .outbox_pending_count = unacked_outbox,
        };
    }
};

/// Governed `CONNECTION`, `SOURCE`, and `SINK` catalog lifecycle with dependency
/// graph enforcement (`DROP RESTRICT`, conditional `ALTER`/`RETIRE`, and secret
/// reference validation — `D8`, `P7`).
pub const EndpointKind = enum(u8) {
    source = 1,
    sink = 2,
};

pub const ConnectionDescriptor = struct {
    object_id: u64,
    definition_id: u64,
    name: []const u8,
    connector_type: []const u8,
    secret_ref_id: u64,
    contains_inline_plaintext_secret: bool = false,
    retired: bool = false,
};

pub const EndpointDescriptor = struct {
    object_id: u64,
    definition_id: u64,
    name: []const u8,
    kind: EndpointKind,
    connection_object_id: u64,
    topic_or_route: []const u8,
    retired: bool = false,
};

pub const ConnectorCatalog = struct {
    connection_count: usize = 0,
    connections: [max_catalog_endpoints]ConnectionDescriptor = undefined,
    endpoint_count: usize = 0,
    endpoints: [max_catalog_endpoints]EndpointDescriptor = undefined,
    external_sockets_opened_during_ddl: usize = 0,

    pub fn createConnection(self: *ConnectorCatalog, desc: ConnectionDescriptor) !void {
        if (desc.object_id == 0 or desc.definition_id == 0 or desc.secret_ref_id == 0) {
            return error.InvalidConnectionDescriptor;
        }
        if (desc.contains_inline_plaintext_secret) {
            return error.InlinePlaintextSecretRejected;
        }
        if (self.connection_count >= max_catalog_endpoints) return error.ConnectorCatalogFull;
        self.connections[self.connection_count] = desc;
        self.connection_count += 1;
    }

    pub fn createEndpoint(self: *ConnectorCatalog, ep: EndpointDescriptor) !void {
        if (ep.object_id == 0 or ep.definition_id == 0) return error.InvalidEndpointDescriptor;
        var conn_found = false;
        for (self.connections[0..self.connection_count]) |conn| {
            if (conn.object_id == ep.connection_object_id and !conn.retired) {
                conn_found = true;
                break;
            }
        }
        if (!conn_found) return error.UnknownOrRetiredConnection;
        if (self.endpoint_count >= max_catalog_endpoints) return error.ConnectorCatalogFull;
        self.endpoints[self.endpoint_count] = ep;
        self.endpoint_count += 1;
    }

    pub fn dropConnectionRestrict(self: *ConnectorCatalog, connection_object_id: u64) !void {
        for (self.endpoints[0..self.endpoint_count]) |ep| {
            if (ep.connection_object_id == connection_object_id) {
                return error.ConnectionReferencedByEndpoint;
            }
        }
        var found = false;
        var write_i: usize = 0;
        for (self.connections[0..self.connection_count]) |conn| {
            if (conn.object_id == connection_object_id) {
                found = true;
            } else {
                self.connections[write_i] = conn;
                write_i += 1;
            }
        }
        if (!found) return error.UnknownOrRetiredConnection;
        self.connection_count = write_i;
    }

    pub fn dropSinkRestrict(
        self: *ConnectorCatalog,
        sink_object_id: u64,
        dataflows: []const DataflowRuntime,
    ) !void {
        for (dataflows) |df| {
            if (df.state != .retired and df.declaration.target_sink_object_id == sink_object_id) {
                return error.SinkReferencedByActiveDataflow;
            }
        }
        var found = false;
        var write_i: usize = 0;
        for (self.endpoints[0..self.endpoint_count]) |ep| {
            if (ep.object_id == sink_object_id and ep.kind == .sink) {
                found = true;
            } else {
                self.endpoints[write_i] = ep;
                write_i += 1;
            }
        }
        if (!found) return error.UnknownSinkEndpoint;
        self.endpoint_count = write_i;
    }
};

//! Right-to-Erasure (GDPR/CCPA) crypto-shredding and audited cross-branch `.tseg`
//! purge compaction (`ERASURE_V1` / `ERS1`, magic `0x45525331`), Hierarchical
//! Workload Management (`WORKLOAD_MANAGEMENT_V1` / `WLM1`, magic `0x574C4D31`),
//! zero-work `EXPLAIN POLICY`, and post-revocation operation receipt inspection
//! (`Steps 7–9`, `D7`–`D9`, `P6`–`P8`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const Types = fuze.Types;
const v = Types.Values;
const OperatorTraits = fuze.OperatorTraits;
const RlsAndMasking = fuze.RlsAndMasking;
const Access = @import("AccessAndIdentity.zig");
const Delegation = @import("DelegationAndSecrets.zig");

pub const magic_ers1: u32 = 0x45525331; // "ERS1"
pub const magic_wlm1: u32 = 0x574C4D31; // "WLM1"
pub const contract_id_ers = "transit.catalog.erasure.v1";
pub const contract_id_wlm = "transit.catalog.workload-management.v1";

pub const max_subject_keys: usize = 64;
pub const max_erasure_receipts: usize = 64;

pub const SubjectKeyState = enum(u8) {
    active = 1,
    shredded = 2,
};

pub const SubjectKeyRecord = struct {
    realm_id: u64,
    table_object: u64,
    subject_blinded_commitment: [32]u8,
    dek_id: u64,
    kek_id: u64,
    state: SubjectKeyState = .active,
    shredded_at_policy_epoch: ?u64 = null,
};

pub const CompactionLineageEdge = struct {
    branch_id: u64,
    source_segment_id: u64,
    replacement_segment_id: u64,
    erased_row_count: usize,
    preserved_unrelated_row_count: usize,
};

/// Hash-chained, PII-free Right-to-Erasure audit receipt (`ERS1`, `Step 7`, `D7`).
pub const ErasureReceipt = struct {
    magic: u32 = magic_ers1,
    erasure_id: u64,
    realm_id: u64,
    table_object: u64,
    subject_blinded_commitment: [32]u8,
    shredded_dek_id: u64,
    shredded_kek_id: u64,
    affected_branch_count: usize,
    purged_segment_count: usize,
    total_erased_rows: usize,
    completed_at_lsn: u64,
    policy_epoch: u64,
    previous_receipt_digest: [32]u8,
    receipt_digest: [32]u8,

    pub fn containsRawSubjectPii(_: ErasureReceipt) bool {
        return false;
    }
};

pub const BranchSegmentPurgeSpec = struct {
    branch_id: u64,
    source_segment_id: u64,
    replacement_segment_id: u64,
    subject_row_count: usize,
    unrelated_row_count: usize,
};

pub const SubjectEnvelopeKeyRegistry = struct {
    keys: [max_subject_keys]SubjectKeyRecord = undefined,
    key_len: usize = 0,
    receipts: [max_erasure_receipts]ErasureReceipt = undefined,
    receipt_len: usize = 0,

    /// Computes a blinded HMAC-SHA256 commitment over `subject_raw_id` so raw PII
    /// is never persisted in `ErasureReceipt`s or catalog logs.
    pub fn computeBlindedSubjectCommitment(realm_id: u64, blind_salt: [32]u8, subject_raw_id: []const u8) [32]u8 {
        var mac: [32]u8 = undefined;
        var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(&blind_salt);
        var rbuf: [8]u8 = undefined;
        std.mem.writeInt(u64, &rbuf, realm_id, .little);
        hmac.update(&rbuf);
        hmac.update(subject_raw_id);
        hmac.final(&mac);
        return mac;
    }

    pub fn registerSubjectKey(
        self: *SubjectEnvelopeKeyRegistry,
        realm_id: u64,
        table_object: u64,
        subject_blinded_commitment: [32]u8,
        dek_id: u64,
        kek_id: u64,
    ) !void {
        if (self.key_len >= max_subject_keys) return error.SubjectKeyRegistryFull;
        self.keys[self.key_len] = .{
            .realm_id = realm_id,
            .table_object = table_object,
            .subject_blinded_commitment = subject_blinded_commitment,
            .dek_id = dek_id,
            .kek_id = kek_id,
            .state = .active,
        };
        self.key_len += 1;
    }

    /// Destroys the subject's envelope DEK/KEK (`crypto-shredding`), zeroes active
    /// memory buffers (`std.crypto.secureZero`), and advances `policy_epoch`.
    /// Requires a verified human-only `ApprovalAttestation` (`APV1`).
    pub fn shredSubjectKeysAndZeroBuffer(
        self: *SubjectEnvelopeKeyRegistry,
        approver_ctx: Access.AccessContext,
        approval: Delegation.ApprovalAttestation,
        current_policy_epoch: u64,
        now_ns: i64,
        target_head_digest: [32]u8,
        candidate_digest: [32]u8,
        subject_blinded_commitment: [32]u8,
        active_key_material_buf: []u8,
    ) !u64 {
        try approval.verifyHumanApproval(approver_ctx, current_policy_epoch, now_ns, target_head_digest, candidate_digest);
        var found = false;
        const next_epoch = current_policy_epoch + 1;
        for (self.keys[0..self.key_len]) |*rec| {
            if (rec.realm_id == approver_ctx.realm_id and
                rec.table_object == approval.target_object and
                std.mem.eql(u8, &rec.subject_blinded_commitment, &subject_blinded_commitment))
            {
                rec.state = .shredded;
                rec.shredded_at_policy_epoch = next_epoch;
                found = true;
            }
        }
        if (!found) return error.SubjectKeyNotFound;
        std.crypto.secureZero(u8, active_key_material_buf);
        return next_epoch;
    }

    /// Projects a cell encrypted under a subject DEK: once shredded, immediately
    /// projects `v.Cell.missing` (erasure tombstone) even before physical `.tseg` purge finishes.
    pub fn projectSubjectEncryptedCell(
        self: *const SubjectEnvelopeKeyRegistry,
        realm_id: u64,
        table_object: u64,
        subject_blinded_commitment: [32]u8,
        decrypted_cell: v.Cell,
    ) v.Cell {
        for (self.keys[0..self.key_len]) |rec| {
            if (rec.realm_id == realm_id and
                rec.table_object == table_object and
                std.mem.eql(u8, &rec.subject_blinded_commitment, &subject_blinded_commitment))
            {
                if (rec.state == .shredded) return .missing;
                return decrypted_cell;
            }
        }
        return .missing;
    }

    /// Executes cross-branch and cross-snapshot `.tseg` purge compaction, emitting
    /// `CompactionLineageEdge`s (so 3-way branch diffs/merges never invent false
    /// conflicts on unrelated rows) and a hash-chained `ErasureReceipt` (`ERS1`).
    pub fn executeCrossBranchPurgeCompaction(
        self: *SubjectEnvelopeKeyRegistry,
        erasure_id: u64,
        realm_id: u64,
        table_object: u64,
        subject_blinded_commitment: [32]u8,
        branch_specs: []const BranchSegmentPurgeSpec,
        completed_at_lsn: u64,
        policy_epoch: u64,
        out_lineage_edges: []CompactionLineageEdge,
    ) !ErasureReceipt {
        if (branch_specs.len == 0 or out_lineage_edges.len < branch_specs.len) {
            return error.InvalidPurgeCompactionSpec;
        }
        var key_rec: ?SubjectKeyRecord = null;
        for (self.keys[0..self.key_len]) |rec| {
            if (rec.realm_id == realm_id and
                rec.table_object == table_object and
                std.mem.eql(u8, &rec.subject_blinded_commitment, &subject_blinded_commitment))
            {
                key_rec = rec;
                break;
            }
        }
        const k = key_rec orelse return error.SubjectKeyNotFound;
        if (k.state != .shredded) return error.ErasureRequiresShreddedSubjectKey;
        if (self.receipt_len >= max_erasure_receipts) return error.ErasureReceiptLedgerFull;

        var total_erased: usize = 0;
        for (branch_specs, 0..) |spec, i| {
            total_erased += spec.subject_row_count;
            out_lineage_edges[i] = .{
                .branch_id = spec.branch_id,
                .source_segment_id = spec.source_segment_id,
                .replacement_segment_id = spec.replacement_segment_id,
                .erased_row_count = spec.subject_row_count,
                .preserved_unrelated_row_count = spec.unrelated_row_count,
            };
        }

        const prev_digest: [32]u8 = if (self.receipt_len == 0)
            @splat(0)
        else
            self.receipts[self.receipt_len - 1].receipt_digest;

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id_ers);
        hasher.update("\x00");
        hasher.update(&prev_digest);
        hasher.update(&subject_blinded_commitment);
        var buf: [24]u8 = undefined;
        std.mem.writeInt(u64, buf[0..8], erasure_id, .little);
        std.mem.writeInt(u64, buf[8..16], completed_at_lsn, .little);
        std.mem.writeInt(u64, buf[16..24], policy_epoch, .little);
        hasher.update(&buf);

        const receipt: ErasureReceipt = .{
            .erasure_id = erasure_id,
            .realm_id = realm_id,
            .table_object = table_object,
            .subject_blinded_commitment = subject_blinded_commitment,
            .shredded_dek_id = k.dek_id,
            .shredded_kek_id = k.kek_id,
            .affected_branch_count = branch_specs.len,
            .purged_segment_count = branch_specs.len,
            .total_erased_rows = total_erased,
            .completed_at_lsn = completed_at_lsn,
            .policy_epoch = policy_epoch,
            .previous_receipt_digest = prev_digest,
            .receipt_digest = hasher.finalResult(),
        };
        self.receipts[self.receipt_len] = receipt;
        self.receipt_len += 1;
        return receipt;
    }
};

/// Hierarchical Workload Management (`WORKLOAD_MANAGEMENT_V1` / `WLM1`, `Step 8`, `D8`).
pub const WorkloadKind = enum(u8) {
    sys_control_and_recovery = 1, // Non-preemptible reserve for policy_epoch revocations, leases & WAL recovery
    oltp_critical = 2,
    interactive_governance = 3,
    continuous_dataflow = 4,
    agent_burst = 5,
    background_maintenance = 6,
};

pub const CachePlacementHint = enum(u8) {
    pinned_hot = 1,
    scan_transient = 2, // Prevents agent bursts and background scans from evicting hot OLTP pages
};

pub const MorselExecutionOutcome = enum(u8) {
    continue_in_memory = 1,
    spill_to_nvme_tier2 = 2,
    yield_morsel_slot_drr = 3,
    bypass_preemption_control_reserve = 4,
};

pub const WorkloadGroupDescriptor = struct {
    magic: u32 = magic_wlm1,
    group_id: u64,
    name: []const u8,
    kind: WorkloadKind,
    cpu_weight_shares: u32 = 100,
    max_concurrent_queries: u32 = 8,
    soft_memory_spill_bytes: usize = 16 * 1024 * 1024,
    hard_memory_limit_bytes: usize = 64 * 1024 * 1024,
    max_cpu_micros_per_query: u64 = 500_000,
    max_read_iops: u32 = 10_000,

    pub fn cacheHint(self: WorkloadGroupDescriptor) CachePlacementHint {
        return switch (self.kind) {
            .sys_control_and_recovery, .oltp_critical, .interactive_governance => .pinned_hot,
            .continuous_dataflow, .agent_burst, .background_maintenance => .scan_transient,
        };
    }
};

pub const WorkloadGroupController = struct {
    descriptor: WorkloadGroupDescriptor,
    active_queries: u32 = 0,
    used_memory_bytes: usize = 0,

    /// Classifies an incoming operation and forbids delegated agents from escalating
    /// into `oltp_critical` or `sys_control_and_recovery` (`error.WorkloadGroupEscalationDenied`).
    pub fn classifyAndAdmit(
        self: *WorkloadGroupController,
        ctx: Access.AccessContext,
        requested_kind: WorkloadKind,
    ) !CachePlacementHint {
        if (ctx.has_delegation or ctx.actor_kind == .agent) {
            if (requested_kind != .agent_burst) {
                return error.WorkloadGroupEscalationDenied;
            }
        }
        if (self.descriptor.kind == .sys_control_and_recovery) {
            self.active_queries += 1;
            return .pinned_hot;
        }
        if (self.active_queries >= self.descriptor.max_concurrent_queries) {
            return error.WorkloadConcurrencyExceeded;
        }
        self.active_queries += 1;
        return self.descriptor.cacheHint();
    }

    pub fn releaseAdmission(self: *WorkloadGroupController) void {
        if (self.active_queries > 0) self.active_queries -= 1;
    }

    /// Charges a single `Batch` morsel's memory, CPU microseconds, and I/O at the
    /// morsel boundary (`Step 8`, `D8`, `P7`).
    pub fn chargeMorselAtBoundary(
        self: *WorkloadGroupController,
        query_memory_bytes: usize,
        query_cpu_micros: u64,
        drr_quantum_exhausted: bool,
        higher_priority_oltp_waiting: bool,
    ) !MorselExecutionOutcome {
        if (self.descriptor.kind == .sys_control_and_recovery) {
            return .bypass_preemption_control_reserve;
        }
        if (query_memory_bytes > self.descriptor.hard_memory_limit_bytes) {
            return error.WorkloadMemoryQuotaExceeded;
        }
        if (query_cpu_micros > self.descriptor.max_cpu_micros_per_query) {
            return error.WorkloadCpuBudgetExceeded;
        }
        self.used_memory_bytes = query_memory_bytes;
        if (query_memory_bytes > self.descriptor.soft_memory_spill_bytes) {
            return .spill_to_nvme_tier2;
        }
        if (drr_quantum_exhausted and higher_priority_oltp_waiting) {
            return .yield_morsel_slot_drr;
        }
        return .continue_in_memory;
    }
};

/// Bounded administration and zero-work `EXPLAIN POLICY` (`Step 9`, `D9`, `P8`).
pub const PolicyExplanationReport = struct {
    explain_work_bound: OperatorTraits.WorkBound = OperatorTraits.WorkBound.zero_work_explain,
    actor_principal: u64,
    subject_principal: u64,
    management_source: Access.ManagementSource,
    has_delegation: bool,
    delegation_depth: u8,
    branch_policy_profile: Delegation.BranchPolicyProfile,
    active_rls_policy_count: usize,
    active_masking_policy_count: usize,
    audience_policy_digest: [32]u8,
    assigned_workload_group: []const u8,
    assigned_workload_kind: WorkloadKind,
    permitted: bool,
    denial_code: Access.PolicyDenialCode,
};

pub fn explainPolicyForStatement(
    ctx: Access.AccessContext,
    branch_profile: Delegation.BranchPolicyProfile,
    rls_policies: []const RlsAndMasking.RlsPolicyDescriptor,
    masking_policies: []const RlsAndMasking.MaskingPolicyDescriptor,
    wlm_group: WorkloadGroupDescriptor,
    permitted: bool,
    denial_code: Access.PolicyDenialCode,
) !PolicyExplanationReport {
    try ctx.validate();
    const wb = OperatorTraits.WorkBound.zero_work_explain;
    if (wb.acquires_data_pins or wb.reads_storage_segments or wb.mutates_durable_state) {
        return error.ExplainPolicyMustPerformZeroWork;
    }

    const mgmt_source: Access.ManagementSource = if (ctx.enterprise_binding) |eb|
        eb.management_source
    else
        .native_local;

    const aud_digest = RlsAndMasking.audiencePolicyDigest(
        ctx.target.target_object,
        ctx.active_role,
        ctx.policy_epoch,
        rls_policies,
        masking_policies,
    );

    return .{
        .explain_work_bound = wb,
        .actor_principal = ctx.actor_principal,
        .subject_principal = ctx.subject_principal,
        .management_source = mgmt_source,
        .has_delegation = ctx.has_delegation,
        .delegation_depth = ctx.delegation_depth,
        .branch_policy_profile = branch_profile,
        .active_rls_policy_count = rls_policies.len,
        .active_masking_policy_count = masking_policies.len,
        .audience_policy_digest = aud_digest,
        .assigned_workload_group = wlm_group.name,
        .assigned_workload_kind = wlm_group.kind,
        .permitted = permitted,
        .denial_code = denial_code,
    };
}

pub const AcceptedOperationReceipt = struct {
    operation_id: u64,
    owner_principal: u64,
    accepted_at_policy_epoch: u64,
    accepted_at_lsn: u64,
    committed: bool,
    disclosed_row_count: usize = 0,
};

/// Inspects an original accepted operation after a lost reply (`Step 9`):
/// preserves receipt recovery by identity while refusing to disclose revoked data rows
/// when the caller's read rights were revoked at `current_policy_epoch`.
pub fn inspectOperationAfterLostReply(
    receipt: AcceptedOperationReceipt,
    caller_principal: u64,
    caller_still_has_data_read_grant: bool,
    request_result_rows: bool,
) !AcceptedOperationReceipt {
    if (receipt.owner_principal != caller_principal) {
        return error.OperationNotFoundOrUnauthorized;
    }
    if (request_result_rows and !caller_still_has_data_read_grant) {
        return error.AccessRevokedOnResultDisclosure;
    }
    return .{
        .operation_id = receipt.operation_id,
        .owner_principal = receipt.owner_principal,
        .accepted_at_policy_epoch = receipt.accepted_at_policy_epoch,
        .accepted_at_lsn = receipt.accepted_at_lsn,
        .committed = receipt.committed,
        .disclosed_row_count = if (request_result_rows and caller_still_has_data_read_grant) receipt.disclosed_row_count else 0,
    };
}

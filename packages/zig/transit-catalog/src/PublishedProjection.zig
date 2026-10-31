//! Single-source projection of `PublishedResourceDescriptor` (`PBR1`) and
//! `InvestigationBasis` (`INV1`) across qualified interfaces (SQL Console,
//! Shared Client/SDKs, OpenAPI/Serving, Board Workbooks, and MCP Resources/Tools/Apps),
//! bounded authorization-aware cursor discovery, streaming multi-batch evaluation
//! with mid-stream revocation checks, Flight ticket binding, and zero-steady-state
//! allocation workspace probing (`D3`, `D6`, `D7`, `P3`, `P6`, `P7`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const PublishedResource = c.PublishedResource;
const DisclosurePolicy = c.DisclosurePolicy;
const InvestigationBasis = c.InvestigationBasis;
const Attribution = c.Attribution;

pub const default_discovery_limit: u16 = 50;
pub const max_discovery_limit: u16 = 250;

pub const DiscoveryRequest = struct {
    owning_application: ?u64 = null,
    search_query: ?[]const u8 = null,
    after_resource_object: ?u64 = null,
    limit: u16 = default_discovery_limit,

    pub fn validate(self: DiscoveryRequest) !void {
        if (self.limit == 0 or self.limit > max_discovery_limit) {
            return error.InvalidDiscoveryLimit;
        }
        if (self.search_query) |q| {
            if (q.len > 128) return error.SearchQueryTooLong;
        }
    }
};

pub const DiscoveredResourceSummary = struct {
    resource_object: u64,
    definition_id: u64,
    publication_revision: u64,
    canonical_name: []const u8,
    business_title: []const u8,
    business_meaning: []const u8,
    tzdb_version_id: ?[]const u8,
    parameter_count: u8,
    column_count: u16,
    disclosure_mode: DisclosurePolicy.DisclosureMode,
    effective_audience: DisclosurePolicy.ConsumerAudienceKind,
    has_chart_bindings: bool,
    has_report_bindings: bool,
    has_spatial_bindings: bool,
    mcp_ui_template_uri: ?[]const u8,
};

pub const DiscoveryPage = struct {
    items: []const DiscoveredResourceSummary,
    next_cursor_resource_object: ?u64,
    verified_policy_epoch: u64,
};

pub const CatalogEntry = struct {
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy.DisclosurePolicy,
};

/// Bounded, cursor-paginated, authorization-aware discovery (`D6`).
/// Filters out unauthorized or withdrawn resources BEFORE applying lexical search
/// and cursor pagination so unauthorized resource metadata is never leaked and
/// large catalogs never need to fit into a model prompt.
pub fn discoverPublishedResources(
    catalog_entries: []const CatalogEntry,
    request: DiscoveryRequest,
    access: DisclosurePolicy.CallerAccessContext,
    current_policy_epoch: u64,
    out_buffer: []DiscoveredResourceSummary,
) !DiscoveryPage {
    try request.validate();
    if (out_buffer.len < request.limit) return error.DiscoveryBufferTooSmall;
    if (access.caller_source_grants.policy_epoch != current_policy_epoch) {
        return error.StalePolicyEpoch;
    }

    var count: usize = 0;
    var next_cursor: ?u64 = null;

    for (catalog_entries) |entry| {
        if (request.after_resource_object) |cursor| {
            if (entry.descriptor.resource_object <= cursor) continue;
        }
        if (request.owning_application) |app_id| {
            if (entry.descriptor.owning_application != app_id) continue;
        }
        // Authorization filter runs BEFORE lexical search or pagination.
        if (!access.canDiscover(entry.descriptor, current_policy_epoch)) continue;
        const audience = DisclosurePolicy.authorizeEvaluation(
            entry.descriptor,
            entry.policy,
            access,
            current_policy_epoch,
            false,
        ) catch continue;

        if (request.search_query) |query| {
            if (query.len > 0) {
                const matches_name = std.mem.indexOf(u8, entry.descriptor.canonical_name, query) != null;
                const matches_title = std.mem.indexOf(u8, entry.descriptor.business_title, query) != null;
                const matches_meaning = std.mem.indexOf(u8, entry.descriptor.business_meaning, query) != null;
                var matches_question = false;
                for (entry.descriptor.supported_questions) |q_tmpl| {
                    if (std.mem.indexOf(u8, q_tmpl.prompt_template, query) != null) {
                        matches_question = true;
                        break;
                    }
                }
                if (!matches_name and !matches_title and !matches_meaning and !matches_question) {
                    continue;
                }
            }
        }

        if (count == request.limit) {
            next_cursor = out_buffer[count - 1].resource_object;
            break;
        }

        out_buffer[count] = .{
            .resource_object = entry.descriptor.resource_object,
            .definition_id = entry.descriptor.definition_id,
            .publication_revision = entry.descriptor.publication_revision,
            .canonical_name = entry.descriptor.canonical_name,
            .business_title = entry.descriptor.business_title,
            .business_meaning = entry.descriptor.business_meaning,
            .tzdb_version_id = if (entry.descriptor.tzdb_version) |version| version.version_id else null,
            .parameter_count = @intCast(entry.descriptor.parameters.len),
            .column_count = @intCast(entry.descriptor.result_schema.columns.len),
            .disclosure_mode = entry.policy.mode,
            .effective_audience = audience,
            .has_chart_bindings = entry.descriptor.presentation.charts.len > 0,
            .has_report_bindings = entry.descriptor.presentation.reports.len > 0,
            .has_spatial_bindings = entry.descriptor.presentation.spatial_layers.len > 0,
            .mcp_ui_template_uri = entry.descriptor.presentation.mcp_ui_template_uri,
        };
        count += 1;
    }

    return .{
        .items = out_buffer[0..count],
        .next_cursor_resource_object = next_cursor,
        .verified_policy_epoch = current_policy_epoch,
    };
}

pub const ProjectedInterfaceKind = enum(u8) {
    sql_console = 1,
    shared_sdk_client = 2,
    openapi_serving = 3,
    board_workbook = 4,
    mcp_resource_and_app = 5,
};

pub const ProjectedResourceSurface = struct {
    interface_kind: ProjectedInterfaceKind,
    resource_object: u64,
    publication_revision: u64,
    definition_digest: [32]u8,
    canonical_name: []const u8,
    tzdb_version_id: ?[]const u8,
    schema_fingerprint: [32]u8,
    permitted_drilldown_count: usize,
    mcp_ui_template_uri: ?[]const u8,
};

/// Projects the same `PublishedResourceDescriptor` across SQL, SDK, OpenAPI/Serving,
/// Board (`M29`), and MCP (`M30`), filtering permitted drilldown actions according to
/// the caller's effective audience (`D6`).
pub fn projectResourceSurface(
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy.DisclosurePolicy,
    access: DisclosurePolicy.CallerAccessContext,
    current_policy_epoch: u64,
    interface_kind: ProjectedInterfaceKind,
) !ProjectedResourceSurface {
    const audience = try DisclosurePolicy.authorizeEvaluation(
        descriptor,
        policy,
        access,
        current_policy_epoch,
        false,
    );
    const def_digest = try descriptor.definitionDigest();
    const schema_fp = try descriptor.result_schema.fingerprint();

    var permitted_drilldowns: usize = 0;
    for (descriptor.presentation.drilldowns) |dd| {
        if (audience == .summary_or_report_only and
            dd.requires_source_row_rights and
            policy.boundary.forbid_raw_row_drilldown_for_report_only)
        {
            continue;
        }
        permitted_drilldowns += 1;
    }

    return .{
        .interface_kind = interface_kind,
        .resource_object = descriptor.resource_object,
        .publication_revision = descriptor.publication_revision,
        .definition_digest = def_digest,
        .canonical_name = descriptor.canonical_name,
        .tzdb_version_id = if (descriptor.tzdb_version) |version| version.version_id else null,
        .schema_fingerprint = schema_fp,
        .permitted_drilldown_count = permitted_drilldowns,
        .mcp_ui_template_uri = descriptor.presentation.mcp_ui_template_uri,
    };
}

/// Zero-steady-state-allocation probe and bounded scratch/result workspace (`D7`, `P7`).
pub const AllocationProbe = struct {
    warmup_complete: bool = false,
    steady_state_heap_allocations: usize = 0,
    active_readers: usize = 0,
    active_pin_leases: usize = 0,
    peak_Scratch_bytes_used: usize = 0,

    pub fn recordScratchReset(self: *AllocationProbe, bytes_used: usize) void {
        if (bytes_used > self.peak_Scratch_bytes_used) {
            self.peak_Scratch_bytes_used = bytes_used;
        }
    }

    pub fn assertZeroSteadyStateHeapAllocations(self: AllocationProbe) !void {
        if (self.steady_state_heap_allocations != 0) {
            return error.SteadyStateHeapAllocationDetected;
        }
    }

    pub fn assertCleanRelease(self: AllocationProbe) !void {
        if (self.active_readers != 0 or self.active_pin_leases != 0) {
            return error.UnreleasedInvestigationOrReaderResources;
        }
    }
};

pub const FlightResourceTicket = struct {
    resource_object: u64,
    publication_revision: u64,
    investigation_id: u64,
    basis_revision: u64,
    basis_digest: [32]u8,
    audience_policy_hash: [32]u8,
    issued_policy_epoch: u64,

    pub fn verifyForBatch(
        self: FlightResourceTicket,
        descriptor: PublishedResource.PublishedResourceDescriptor,
        policy: DisclosurePolicy.DisclosurePolicy,
        access: DisclosurePolicy.CallerAccessContext,
        current_policy_epoch: u64,
    ) !void {
        _ = try DisclosurePolicy.authorizeEvaluation(descriptor, policy, access, current_policy_epoch, false);
        const current_aud_hash = try access.effectiveAudienceHash(descriptor.resource_object);
        if (!std.mem.eql(u8, &self.audience_policy_hash, &current_aud_hash)) {
            return error.CrossAudienceTicketReuseForbidden;
        }
    }
};

/// Streaming multi-batch reader for a published resource bound to an `InvestigationBasis`.
/// Re-verifies current `policy_epoch` authorization and withdrawal status before every
/// batch disclosure, enforces $k$-anonymity and 5-state `type_error` scrubbing, and
/// tracks terminal completeness (`complete`, `window_truncated`, `interrupted_prefix`).
pub const PublishedResourceStreamReader = struct {
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy.DisclosurePolicy,
    basis: InvestigationBasis.InvestigationBasis,
    audience_kind: DisclosurePolicy.ConsumerAudienceKind,
    audience_policy_hash: [32]u8,
    params_digest: [32]u8,
    source_rows: []const DisclosurePolicy.GroupSummaryInputRow,
    key_column_count: usize,
    batch_row_limit: usize,
    display_window_max_rows: ?usize = null,
    freshness: Attribution.FourClockFreshness,
    freshness_status: Attribution.FreshnessStatus,
    admitted_policy_epoch: u64,
    cursor_index: usize = 0,
    disclosed_rows: u64 = 0,
    closed: bool = false,
    interrupted: bool = false,
    window_truncated: bool = false,
    probe: *AllocationProbe,

    pub fn open(
        descriptor: PublishedResource.PublishedResourceDescriptor,
        policy: DisclosurePolicy.DisclosurePolicy,
        basis: InvestigationBasis.InvestigationBasis,
        bindings: []const PublishedResource.ParameterValueBinding,
        access: DisclosurePolicy.CallerAccessContext,
        current_policy_epoch: u64,
        now_ms: u64,
        min_retained_manifest_version: u64,
        source_rows: []const DisclosurePolicy.GroupSummaryInputRow,
        key_column_count: usize,
        batch_row_limit: usize,
        display_window_max_rows: ?usize,
        freshness: Attribution.FourClockFreshness,
        probe: *AllocationProbe,
    ) !PublishedResourceStreamReader {
        if (batch_row_limit == 0) return error.InvalidBatchRowLimit;
        if (source_rows.len > descriptor.work_bound.max_rows) return error.ResourceWorkBoundExceeded;

        const audience = try basis.verifyForResourceEvaluation(
            descriptor,
            policy,
            access,
            current_policy_epoch,
            now_ms,
            min_retained_manifest_version,
        );
        const params_digest = try descriptor.validateAndDigestParameters(bindings);
        const audience_hash = try access.effectiveAudienceHash(descriptor.resource_object);
        const f_status = try freshness.evaluate(now_ms, descriptor.freshness_requirement);

        probe.active_readers += 1;
        return .{
            .descriptor = descriptor,
            .policy = policy,
            .basis = basis,
            .audience_kind = audience,
            .audience_policy_hash = audience_hash,
            .params_digest = params_digest,
            .source_rows = source_rows,
            .key_column_count = key_column_count,
            .batch_row_limit = batch_row_limit,
            .display_window_max_rows = display_window_max_rows,
            .freshness = freshness,
            .freshness_status = f_status,
            .admitted_policy_epoch = current_policy_epoch,
            .probe = probe,
        };
    }

    /// Fetches the next bounded batch into `out_row_cells` (pre-allocated scratch buffer).
    /// Re-verifies authorization at `current_policy_epoch` BEFORE disclosing any rows.
    pub fn fetchNextBatch(
        self: *PublishedResourceStreamReader,
        current_descriptor_state: PublishedResource.ResourceLifecycleState,
        access: DisclosurePolicy.CallerAccessContext,
        current_policy_epoch: u64,
        out_row_cells: [][]v.Cell,
    ) !usize {
        if (self.closed) return error.ReaderAlreadyClosed;
        if (current_descriptor_state == .withdrawn) {
            self.interrupted = true;
            return error.PublishedResourceWithdrawn;
        }
        var current_desc = self.descriptor;
        current_desc.state = current_descriptor_state;
        _ = DisclosurePolicy.authorizeEvaluation(
            current_desc,
            self.policy,
            access,
            current_policy_epoch,
            false,
        ) catch |err| {
            self.interrupted = true;
            if (err == error.RowSelectPermissionDenied or err == error.ResourceConsumePermissionDenied or err == error.DelegationExpiredOrRevoked) {
                return error.AuthorizationRevokedMidStream;
            }
            return err;
        };

        const current_aud_hash = try access.effectiveAudienceHash(self.descriptor.resource_object);
        if (!std.mem.eql(u8, &current_aud_hash, &self.audience_policy_hash)) {
            self.interrupted = true;
            return error.CrossAudienceStreamContinuationForbidden;
        }

        self.admitted_policy_epoch = current_policy_epoch;

        if (self.cursor_index >= self.source_rows.len) return 0;
        if (self.display_window_max_rows) |win_max| {
            if (self.disclosed_rows >= win_max) {
                self.window_truncated = true;
                return 0;
            }
        }

        const max_in_batch = @min(self.batch_row_limit, out_row_cells.len);
        var emitted: usize = 0;
        while (emitted < max_in_batch and self.cursor_index < self.source_rows.len) {
            if (self.display_window_max_rows) |win_max| {
                if (self.disclosed_rows >= win_max) {
                    self.window_truncated = true;
                    break;
                }
            }
            const src_row = self.source_rows[self.cursor_index];
            try DisclosurePolicy.applyDisclosureRowFilter(
                self.policy,
                self.audience_kind,
                src_row,
                self.key_column_count,
                out_row_cells[emitted],
            );
            self.cursor_index += 1;
            self.disclosed_rows += 1;
            emitted += 1;
        }

        self.probe.recordScratchReset(emitted * self.descriptor.result_schema.columns.len * @sizeOf(v.Cell));
        return emitted;
    }

    pub fn interrupt(self: *PublishedResourceStreamReader) void {
        if (!self.closed) {
            self.interrupted = true;
        }
    }

    pub fn close(self: *PublishedResourceStreamReader) !Attribution.AttributionReceipt {
        if (!self.closed) {
            self.closed = true;
            self.probe.active_readers -= 1;
        }
        const completeness: Attribution.CompletenessState = if (self.interrupted)
            .interrupted_prefix
        else if (self.window_truncated or self.cursor_index < self.source_rows.len)
            .window_truncated
        else
            .complete;

        return .{
            .investigation_id = self.basis.investigation_id,
            .basis_revision = self.basis.basis_revision,
            .basis_kind = std.meta.activeTag(self.basis.payload),
            .basis_digest = try self.basis.basisDigest(),
            .resource_object = self.descriptor.resource_object,
            .publication_revision = self.descriptor.publication_revision,
            .definition_digest = try self.descriptor.definitionDigest(),
            .parameter_bindings_digest = self.params_digest,
            .schema_epoch = self.descriptor.result_schema.revision,
            .verified_policy_epoch = self.admitted_policy_epoch,
            .disclosure_mode = self.policy.mode,
            .audience_policy_hash = self.audience_policy_hash,
            .freshness = self.freshness,
            .freshness_status = self.freshness_status,
            .completeness = completeness,
            .total_rows_observed = self.disclosed_rows,
        };
    }
};

pub const PublishedSnapshotJsonResult = struct {
    json_payload: []u8,
    receipt: Attribution.AttributionReceipt,
    cache_key: DisclosurePolicy.AudienceCacheKey,
};

/// Evaluates a `PublishedResourceDescriptor` (`PBR1`) into a canonical, lossless JSON
/// snapshot (`int64`/`uint64` formatted as decimal strings so browser `JSON.parse`
/// never loses 53-bit IEEE-754 precision), re-verifying disclosure authorization
/// and session validity AFTER reading all rows and BEFORE disclosing the response.
pub fn evaluatePublishedSnapshotJson(
    allocator: std.mem.Allocator,
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy.DisclosurePolicy,
    basis: InvestigationBasis.InvestigationBasis,
    bindings: []const PublishedResource.ParameterValueBinding,
    pre_read_access: DisclosurePolicy.CallerAccessContext,
    post_read_access: DisclosurePolicy.CallerAccessContext,
    post_read_descriptor_state: PublishedResource.ResourceLifecycleState,
    post_read_session_valid: bool,
    current_policy_epoch: u64,
    now_ms: u64,
    min_retained_manifest_version: u64,
    source_rows: []const DisclosurePolicy.GroupSummaryInputRow,
    key_column_count: usize,
    source_watermark_lsn: u64,
    freshness: Attribution.FourClockFreshness,
    probe: *AllocationProbe,
) !PublishedSnapshotJsonResult {
    var reader = try PublishedResourceStreamReader.open(
        descriptor,
        policy,
        basis,
        bindings,
        pre_read_access,
        current_policy_epoch,
        now_ms,
        min_retained_manifest_version,
        source_rows,
        key_column_count,
        16,
        descriptor.work_bound.max_rows,
        freshness,
        probe,
    );
    errdefer {
        reader.interrupt();
        _ = reader.close() catch {};
    }

    const col_count = descriptor.result_schema.columns.len;
    var row_storage: [16][16]v.Cell = undefined;
    var batch_slices: [16][]v.Cell = undefined;
    if (col_count > 16) return error.TooManyPublishedColumns;
    for (0..16) |r_idx| {
        batch_slices[r_idx] = row_storage[r_idx][0..col_count];
    }

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"view\":");
    try appendJsonEscapedString(allocator, &buf, descriptor.canonical_name);
    try buf.appendSlice(allocator, ",\"columns\":[");
    for (descriptor.result_schema.columns, 0..) |col, idx| {
        if (idx > 0) try buf.append(allocator, ',');
        try buf.appendSlice(allocator, "{\"name\":");
        try appendJsonEscapedString(allocator, &buf, col.name);
        try buf.appendSlice(allocator, ",\"type\":");
        try appendJsonEscapedString(allocator, &buf, publishedScalarTypeName(col.type));
        try buf.append(allocator, '}');
    }
    try buf.appendSlice(allocator, "],\"rows\":[");

    var first_row = true;
    while (true) {
        const count = try reader.fetchNextBatch(
            post_read_descriptor_state,
            post_read_access,
            current_policy_epoch,
            &batch_slices,
        );
        if (count == 0) break;
        for (0..count) |r_idx| {
            if (!first_row) try buf.append(allocator, ',');
            first_row = false;
            try buf.append(allocator, '[');
            for (batch_slices[r_idx], 0..) |cell, c_idx| {
                if (c_idx > 0) try buf.append(allocator, ',');
                try appendPublishedCellJson(allocator, &buf, cell);
            }
            try buf.append(allocator, ']');
        }
        if (buf.items.len > descriptor.work_bound.max_bytes) {
            return error.ResourceWorkBoundExceeded;
        }
    }

    // Post-read re-verification before disclosure: if session or policy was revoked
    // while reading rows, fail closed before returning the serialized snapshot.
    if (!post_read_session_valid) {
        reader.interrupt();
        return error.SessionRevokedBeforeDisclosure;
    }
    if (post_read_descriptor_state == .withdrawn) {
        reader.interrupt();
        return error.PublishedResourceWithdrawn;
    }
    _ = try DisclosurePolicy.authorizeEvaluation(
        descriptor,
        policy,
        post_read_access,
        current_policy_epoch,
        false,
    );

    const receipt = try reader.close();
    var attr_buf: [256]u8 = undefined;
    const attr_slice = try std.fmt.bufPrint(
        &attr_buf,
        "],\"attribution\":{{\"resource_object\":\"{d}\",\"publication_revision\":\"{d}\",\"verified_policy_epoch\":\"{d}\",\"watermark_lsn\":\"{d}\",\"row_count\":{d}}}}}",
        .{
            receipt.resource_object,
            receipt.publication_revision,
            receipt.verified_policy_epoch,
            source_watermark_lsn,
            receipt.total_rows_observed,
        },
    );
    try buf.appendSlice(allocator, attr_slice);
    if (buf.items.len > descriptor.work_bound.max_bytes) {
        return error.ResourceWorkBoundExceeded;
    }

    const cache_key: DisclosurePolicy.AudienceCacheKey = .{
        .resource_object = descriptor.resource_object,
        .publication_revision = descriptor.publication_revision,
        .basis_digest = receipt.basis_digest,
        .params_digest = receipt.parameter_bindings_digest,
        .audience_policy_hash = try post_read_access.effectiveAudienceHash(descriptor.resource_object),
        .policy_epoch = current_policy_epoch,
    };

    return .{
        .json_payload = try buf.toOwnedSlice(allocator),
        .receipt = receipt,
        .cache_key = cache_key,
    };
}

pub const ReactiveWatchPollOutcome = union(enum) {
    /// Source watermark LSN has not advanced since `last_emitted_lsn`; zero scans or frames emitted.
    no_change: void,
    /// Initial snapshot or watermark-advanced delta snapshot ready for WebSocket transmission.
    snapshot_frame: PublishedSnapshotJsonResult,
    /// RFC 6455 close code (`1000` Normal Closure on max lifetime, `1008` Policy Violation on revocation/logout/expiry, `1011` on internal error).
    close: u16,
};

/// Watermark-driven reactive watch session (`transit.reactive.v1` / `transit.browser.v1`)
/// over a catalog `PublishedResourceDescriptor` (`PBR1`). Replaces timer-based SQL polling
/// by emitting frames only on initial bind or when `source_watermark_lsn` advances, while
/// enforcing immediate `1008` termination on session logout, identity hold, or `policy_epoch` revocation.
pub const WatermarkReactiveWatchSession = struct {
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy.DisclosurePolicy,
    basis: InvestigationBasis.InvestigationBasis,
    opened_at_ms: u64,
    max_lifetime_ms: u64 = 50_000,
    last_emitted_lsn: ?u64 = null,
    frames_emitted: u64 = 0,
    skipped_unchanged_ticks: u64 = 0,
    closed: bool = false,
    close_code: u16 = 0,

    pub fn open(
        descriptor: PublishedResource.PublishedResourceDescriptor,
        policy: DisclosurePolicy.DisclosurePolicy,
        basis: InvestigationBasis.InvestigationBasis,
        access: DisclosurePolicy.CallerAccessContext,
        current_policy_epoch: u64,
        opened_at_ms: u64,
        max_lifetime_ms: u64,
    ) !WatermarkReactiveWatchSession {
        if (max_lifetime_ms == 0) return error.InvalidWatchLifetime;
        _ = try DisclosurePolicy.authorizeEvaluation(
            descriptor,
            policy,
            access,
            current_policy_epoch,
            false,
        );
        return .{
            .descriptor = descriptor,
            .policy = policy,
            .basis = basis,
            .opened_at_ms = opened_at_ms,
            .max_lifetime_ms = max_lifetime_ms,
        };
    }

    pub fn pollNextFrame(
        self: *WatermarkReactiveWatchSession,
        allocator: std.mem.Allocator,
        bindings: []const PublishedResource.ParameterValueBinding,
        current_descriptor_state: PublishedResource.ResourceLifecycleState,
        access: DisclosurePolicy.CallerAccessContext,
        session_still_valid: bool,
        current_policy_epoch: u64,
        now_ms: u64,
        min_retained_manifest_version: u64,
        source_rows: []const DisclosurePolicy.GroupSummaryInputRow,
        key_column_count: usize,
        source_watermark_lsn: u64,
        freshness: Attribution.FourClockFreshness,
        probe: *AllocationProbe,
    ) !ReactiveWatchPollOutcome {
        if (self.closed) return .{ .close = self.close_code };

        // 1. Immediate revocation / logout / withdrawal check (`1008 Policy Violation`):
        if (!session_still_valid or current_descriptor_state == .withdrawn) {
            self.closed = true;
            self.close_code = 1008;
            return .{ .close = 1008 };
        }
        var current_desc = self.descriptor;
        current_desc.state = current_descriptor_state;
        _ = DisclosurePolicy.authorizeEvaluation(
            current_desc,
            self.policy,
            access,
            current_policy_epoch,
            false,
        ) catch {
            self.closed = true;
            self.close_code = 1008;
            return .{ .close = 1008 };
        };

        // 2. Bounded connection lifetime check (`1000 Normal Closure`):
        if (now_ms >= self.opened_at_ms and (now_ms - self.opened_at_ms) >= self.max_lifetime_ms) {
            self.closed = true;
            self.close_code = 1000;
            return .{ .close = 1000 };
        }

        // 3. Watermark gate: if we already emitted at or above `source_watermark_lsn`,
        // do NOT re-scan rows or allocate a frame!
        if (self.last_emitted_lsn) |emitted_lsn| {
            if (source_watermark_lsn <= emitted_lsn) {
                self.skipped_unchanged_ticks += 1;
                return .no_change;
            }
        }

        // 4. Evaluate snapshot at the new watermark and re-verify post-read disclosure:
        const snapshot = evaluatePublishedSnapshotJson(
            allocator,
            current_desc,
            self.policy,
            self.basis,
            bindings,
            access,
            access,
            current_descriptor_state,
            session_still_valid,
            current_policy_epoch,
            now_ms,
            min_retained_manifest_version,
            source_rows,
            key_column_count,
            source_watermark_lsn,
            freshness,
            probe,
        ) catch |err| switch (err) {
            error.SessionRevokedBeforeDisclosure,
            error.PublishedResourceWithdrawn,
            error.RowSelectPermissionDenied,
            error.ResourceConsumePermissionDenied,
            error.DelegationExpiredOrRevoked,
            error.StalePolicyEpoch,
            => {
                self.closed = true;
                self.close_code = 1008;
                return .{ .close = 1008 };
            },
            else => return err,
        };

        self.last_emitted_lsn = source_watermark_lsn;
        self.frames_emitted += 1;
        return .{ .snapshot_frame = snapshot };
    }
};

fn publishedScalarTypeName(dt: t.Type) []const u8 {
    return switch (dt) {
        .int64 => "int64",
        .uint64 => "uint64",
        .float64 => "float64",
        .boolean => "bool",
        .utf8 => "utf8",
        .decimal => "decimal",
        else => "scalar",
    };
}

pub fn appendPublishedCellJson(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), cell: v.Cell) !void {
    var num_buf: [64]u8 = undefined;
    switch (cell) {
        .null, .missing => try buf.appendSlice(allocator, "null"),
        .value => |val| switch (if (val == .atom) val.atom else return error.UnsupportedPublishedCellType) {
            .signed => |n| {
                const s_num = try std.fmt.bufPrint(&num_buf, "\"{d}\"", .{n});
                try buf.appendSlice(allocator, s_num);
            },
            .unsigned => |n| {
                const s_num = try std.fmt.bufPrint(&num_buf, "\"{d}\"", .{n});
                try buf.appendSlice(allocator, s_num);
            },
            .decimal => |d| {
                const s_num = try std.fmt.bufPrint(&num_buf, "\"{d}\"", .{d});
                try buf.appendSlice(allocator, s_num);
            },
            .boolean => |b| try buf.appendSlice(allocator, if (b) "true" else "false"),
            .float => |f| {
                if (!std.math.isFinite(f)) return error.NonFinitePublishedFloat;
                const s_num = try std.fmt.bufPrint(&num_buf, "{d}", .{f});
                try buf.appendSlice(allocator, s_num);
            },
            .bytes => |str| try appendJsonEscapedString(allocator, buf, str),
            else => return error.UnsupportedPublishedCellType,
        },
        .type_error => return error.UnscrubbedPublishedTypeError,
        .conflict => return error.UnresolvedPublishedConflict,
    }
}

fn appendJsonEscapedString(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), value: []const u8) !void {
    try buf.append(allocator, '"');
    var esc_buf: [8]u8 = undefined;
    for (value) |ch| {
        switch (ch) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => {
                const s_esc = try std.fmt.bufPrint(&esc_buf, "\\u{x:0>4}", .{ch});
                try buf.appendSlice(allocator, s_esc);
            },
            else => try buf.append(allocator, ch),
        }
    }
    try buf.append(allocator, '"');
}

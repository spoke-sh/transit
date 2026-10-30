//! Three-way authority separation (`Computation`, `Publication`, `Consumption`),
//! non-amplifying `DisclosureBoundary` enforcement ($k$-anonymity minimum group
//! cardinality, parameter domain bounds, 5-state `type_error` scrubbing, and
//! drilldown whitelisting), revocation/withdrawal handling, and audience-isolated
//! cache keys (`D2`, `P2`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const HistoricalCatalog = c.HistoricalCatalog;
const PublishedResource = c.PublishedResource;

pub const DisclosureMode = enum(u8) {
    /// Consumer must hold `consume_resource` on the published resource AND
    /// current `select_rows` on every upstream source dependency at `current_policy_epoch`.
    caller_source_rights = 1,
    /// Consumer holds `consume_resource` (summary/report audience) without raw source
    /// `select_rows`, backed by an explicit `PublicationAttestation` whose publisher
    /// still holds upstream `select_rows` at `current_policy_epoch`.
    derived_publication = 2,
    /// Reads an independently owned, immutable published snapshot copy (`PublishedCopyArtifact`).
    retained_published_snapshot = 3,
};

pub const ConsumerAudienceKind = enum(u8) {
    full_resource_and_drilldown = 1,
    summary_or_report_only = 2,
};

pub const DelegationGrant = struct {
    delegator_principal: u64,
    agent_principal: u64,
    allowed_resource_objects: []const u64,
    audience_kind: ConsumerAudienceKind,
    delegated_select_objects: []const u64 = &.{},
    issued_at_policy_epoch: u64,
    expires_at_policy_epoch: u64,

    pub fn isActiveAt(self: DelegationGrant, current_policy_epoch: u64) bool {
        return current_policy_epoch >= self.issued_at_policy_epoch and current_policy_epoch <= self.expires_at_policy_epoch;
    }

    pub fn allowsResource(self: DelegationGrant, resource_object: u64) bool {
        for (self.allowed_resource_objects) |obj| {
            if (obj == resource_object) return true;
        }
        return false;
    }
};

pub const ResourceConsumerGrant = struct {
    principal_id: u64,
    resource_object: u64,
    min_publication_revision: u64 = 1,
    max_publication_revision: ?u64 = null,
    audience_kind: ConsumerAudienceKind = .full_resource_and_drilldown,
    allow_discover: bool = true,
    allow_evaluate: bool = true,
};

pub const PublisherGrant = struct {
    principal_id: u64,
    namespace_id: u64,
    can_publish: bool = true,
    can_withdraw: bool = true,
};

pub const PublicationAttestation = struct {
    publisher_principal: u64,
    resource_object: u64,
    publication_revision: u64,
    definition_digest: [32]u8,
    attested_policy_epoch: u64,

    pub fn validateAgainst(
        self: PublicationAttestation,
        descriptor: PublishedResource.PublishedResourceDescriptor,
        publisher_grants: []const PublisherGrant,
        publisher_source_grants: HistoricalCatalog.GrantSet,
        current_policy_epoch: u64,
    ) !void {
        if (self.publisher_principal == 0) return error.PublisherAttestationInvalid;
        if (self.resource_object != descriptor.resource_object or self.publication_revision != descriptor.publication_revision) {
            return error.PublisherAttestationIdentityMismatch;
        }
        const expected_digest = try descriptor.definitionDigest();
        if (!std.mem.eql(u8, &self.definition_digest, &expected_digest)) {
            return error.PublisherAttestationDigestMismatch;
        }
        if (self.attested_policy_epoch > current_policy_epoch) {
            return error.PublisherAttestationEpochMismatch;
        }
        var has_publish_grant = false;
        for (publisher_grants) |pg| {
            if (pg.principal_id == self.publisher_principal and pg.namespace_id == descriptor.namespace_id and pg.can_publish) {
                has_publish_grant = true;
                break;
            }
        }
        if (!has_publish_grant) return error.PublisherLacksPublishAuthority;

        // Verify the attesting publisher STILL holds `select_rows` on every upstream dependency at `current_policy_epoch`.
        if (publisher_source_grants.policy_epoch != current_policy_epoch) {
            return error.StalePolicyEpoch;
        }
        for (descriptor.dependencies) |dep| {
            try publisher_source_grants.authorize(dep.source_object, .select_rows);
        }
    }
};

pub const PublishedCopyArtifact = struct {
    copy_id: u64,
    owner_principal: u64,
    resource_object: u64,
    publication_revision: u64,
    captured_basis_digest: [32]u8,
    source_tables_retired: bool = false,
    copy_retired: bool = false,
};

pub const DisclosureBoundary = struct {
    min_group_cardinality: u32 = 1,
    scrub_restricted_type_errors: bool = true,
    forbid_ad_hoc_filter_pushdown: bool = true,
    forbid_raw_row_drilldown_for_report_only: bool = true,

    pub fn validate(self: DisclosureBoundary, mode: DisclosureMode) !void {
        if (self.min_group_cardinality == 0) return error.InvalidMinimumGroupCardinality;
        if (mode == .derived_publication and !self.forbid_ad_hoc_filter_pushdown) {
            return error.DerivedPublicationRequiresFilterBoundary;
        }
    }
};

pub const DisclosurePolicy = struct {
    mode: DisclosureMode,
    boundary: DisclosureBoundary = .{},
    attestation: ?PublicationAttestation = null,
    published_copy: ?PublishedCopyArtifact = null,

    pub fn validate(self: DisclosurePolicy, descriptor: PublishedResource.PublishedResourceDescriptor) !void {
        try self.boundary.validate(self.mode);
        switch (self.mode) {
            .caller_source_rights => {},
            .derived_publication => {
                if (self.attestation == null) return error.DerivedPublicationRequiresAttestation;
            },
            .retained_published_snapshot => {
                const copy = self.published_copy orelse return error.RetainedSnapshotRequiresCopyArtifact;
                if (copy.resource_object != descriptor.resource_object or copy.publication_revision != descriptor.publication_revision) {
                    return error.PublishedCopyIdentityMismatch;
                }
            },
        }
    }
};

/// Caller access context evaluated at `current_policy_epoch`.
/// Distinguishes the caller's own principal (or delegated agent chain) from any
/// worker/service transport credential so a privileged service credential never
/// silently supplies missing source or publication rights.
pub const CallerAccessContext = struct {
    caller_principal: u64,
    delegation: ?DelegationGrant = null,
    service_transport_principal: ?u64 = null,
    service_transport_has_admin_source_rights: bool = false,
    consumer_grants: []const ResourceConsumerGrant,
    caller_source_grants: HistoricalCatalog.GrantSet,
    publisher_grants: []const PublisherGrant = &.{},
    publisher_source_grants: ?HistoricalCatalog.GrantSet = null,
    rls_mask_profile_tag: []const u8 = "default",

    pub fn effectiveAudienceHash(self: CallerAccessContext, resource_object: u64) ![32]u8 {
        const audience_kind = try self.resolveAudienceKind(resource_object);
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.audience-policy.v1\x00");
        var buf: [17]u8 = undefined;
        std.mem.writeInt(u64, buf[0..8], resource_object, .little);
        std.mem.writeInt(u64, buf[8..16], self.caller_source_grants.policy_epoch, .little);
        buf[16] = @backingInt(audience_kind);
        hasher.update(&buf);
        hasher.update(self.rls_mask_profile_tag);
        hasher.update("\x00");
        return hasher.finalResult();
    }

    pub fn resolveAudienceKind(self: CallerAccessContext, resource_object: u64) !ConsumerAudienceKind {
        if (self.delegation) |del| {
            if (del.agent_principal != self.caller_principal) return error.InvalidDelegationPrincipal;
            if (!del.isActiveAt(self.caller_source_grants.policy_epoch)) return error.DelegationExpiredOrRevoked;
            if (!del.allowsResource(resource_object)) return error.DelegatedResourceNotPermitted;
            return del.audience_kind;
        }
        for (self.consumer_grants) |cg| {
            if (cg.principal_id == self.caller_principal and cg.resource_object == resource_object and cg.allow_evaluate) {
                return cg.audience_kind;
            }
        }
        return error.ResourceConsumePermissionDenied;
    }

    pub fn canDiscover(
        self: CallerAccessContext,
        descriptor: PublishedResource.PublishedResourceDescriptor,
        current_policy_epoch: u64,
    ) bool {
        if (descriptor.state != .published) return false;
        if (self.caller_source_grants.policy_epoch != current_policy_epoch) return false;
        if (self.delegation) |del| {
            if (del.agent_principal != self.caller_principal) return false;
            if (!del.isActiveAt(current_policy_epoch)) return false;
            return del.allowsResource(descriptor.resource_object);
        }
        for (self.consumer_grants) |cg| {
            if (cg.principal_id == self.caller_principal and cg.resource_object == descriptor.resource_object and cg.allow_discover) {
                if (descriptor.publication_revision < cg.min_publication_revision) return false;
                if (cg.max_publication_revision) |max_rev| {
                    if (descriptor.publication_revision > max_rev) return false;
                }
                return true;
            }
        }
        return false;
    }
};

pub fn authorizeEvaluation(
    descriptor: PublishedResource.PublishedResourceDescriptor,
    policy: DisclosurePolicy,
    access: CallerAccessContext,
    current_policy_epoch: u64,
    has_injected_ad_hoc_filter: bool,
) !ConsumerAudienceKind {
    try descriptor.validate();
    try policy.validate(descriptor);

    if (descriptor.state == .withdrawn) return error.PublishedResourceWithdrawn;
    if (descriptor.state != .published) return error.PublishedResourceNotPublished;
    if (access.caller_source_grants.policy_epoch != current_policy_epoch) return error.StalePolicyEpoch;

    if (has_injected_ad_hoc_filter and policy.boundary.forbid_ad_hoc_filter_pushdown) {
        return error.UnexposedFilterPushdownRejected;
    }

    const audience_kind = try access.resolveAudienceKind(descriptor.resource_object);

    switch (policy.mode) {
        .caller_source_rights => {
            // Check caller (or delegated agent's explicitly delegated source grants) on every upstream dependency.
            // A stronger service transport credential is NEVER allowed to substitute for missing caller source rights.
            for (descriptor.dependencies) |dep| {
                const caller_ok = if (access.delegation) |del| blk: {
                    const sub_set: HistoricalCatalog.GrantSet = .{
                        .policy_epoch = current_policy_epoch,
                        .select_objects = del.delegated_select_objects,
                    };
                    sub_set.authorize(dep.source_object, .select_rows) catch break :blk false;
                    break :blk true;
                } else blk: {
                    access.caller_source_grants.authorize(dep.source_object, .select_rows) catch break :blk false;
                    break :blk true;
                };
                if (!caller_ok) {
                    if (access.service_transport_has_admin_source_rights) {
                        return error.ServiceCredentialAmplificationForbidden;
                    }
                    return error.RowSelectPermissionDenied;
                }
            }
        },
        .derived_publication => {
            const att = policy.attestation orelse return error.DerivedPublicationRequiresAttestation;
            const pub_sources = access.publisher_source_grants orelse {
                if (access.service_transport_has_admin_source_rights) {
                    return error.ServiceCredentialAmplificationForbidden;
                }
                return error.PublisherAttestationInvalid;
            };
            att.validateAgainst(descriptor, access.publisher_grants, pub_sources, current_policy_epoch) catch |err| {
                if (err == error.RowSelectPermissionDenied and access.service_transport_has_admin_source_rights) {
                    return error.ServiceCredentialAmplificationForbidden;
                }
                return err;
            };
        },
        .retained_published_snapshot => {
            const copy = policy.published_copy orelse return error.RetainedSnapshotRequiresCopyArtifact;
            if (copy.copy_retired) return error.PublishedCopyRetired;
            // Independently owned published copies remain readable when source_tables_retired == true,
            // as long as the publication itself is not withdrawn and the copy is not retired.
        },
    }

    return audience_kind;
}

/// Validates a drilldown transition from `parent_descriptor` to `target_descriptor`.
/// Ensures a report-only or summary-only consumer cannot obtain raw rows through drilldown.
pub fn authorizeDrilldown(
    parent_descriptor: PublishedResource.PublishedResourceDescriptor,
    parent_policy: DisclosurePolicy,
    action_id: []const u8,
    target_descriptor: PublishedResource.PublishedResourceDescriptor,
    target_policy: DisclosurePolicy,
    access: CallerAccessContext,
    current_policy_epoch: u64,
) !void {
    const parent_audience = try authorizeEvaluation(parent_descriptor, parent_policy, access, current_policy_epoch, false);
    var matched_spec: ?PublishedResource.DrilldownSpec = null;
    for (parent_descriptor.presentation.drilldowns) |dd| {
        if (std.mem.eql(u8, dd.action_id, action_id)) {
            matched_spec = dd;
            break;
        }
    }
    const spec = matched_spec orelse return error.DrilldownActionNotWhitelisted;
    if (spec.target_resource_object != target_descriptor.resource_object or
        target_descriptor.publication_revision < spec.target_minimum_revision)
    {
        return error.DrilldownTargetIdentityMismatch;
    }
    if (parent_audience == .summary_or_report_only and
        (spec.requires_source_row_rights or target_policy.mode == .caller_source_rights) and
        parent_policy.boundary.forbid_raw_row_drilldown_for_report_only)
    {
        return error.DisclosureBoundaryViolation;
    }
    _ = try authorizeEvaluation(target_descriptor, target_policy, access, current_policy_epoch, false);
}

pub const GroupSummaryInputRow = struct {
    contributing_source_row_count: u32,
    cells: []const v.Cell,
};

/// Applies $k$-anonymity minimum group cardinality (`min_group_cardinality`) and
/// scrubs 5-state `type_error` cells for `summary_or_report_only` / `derived_publication`
/// outputs so crafted parameters cannot infer individual row values via small groups or
/// division-by-zero / cast error side channels.
pub fn applyDisclosureRowFilter(
    policy: DisclosurePolicy,
    audience_kind: ConsumerAudienceKind,
    input_row: GroupSummaryInputRow,
    key_column_count: usize,
    out_cells: []v.Cell,
) !void {
    if (out_cells.len != input_row.cells.len or key_column_count > out_cells.len) {
        return error.InvalidDisclosureRowArity;
    }
    const suppress_small_group = (policy.mode == .derived_publication or audience_kind == .summary_or_report_only) and
        input_row.contributing_source_row_count < policy.boundary.min_group_cardinality;

    for (input_row.cells, 0..) |cell, idx| {
        if (suppress_small_group and idx >= key_column_count) {
            out_cells[idx] = .missing;
            continue;
        }
        if (cell == .type_error and policy.boundary.scrub_restricted_type_errors and
            (policy.mode == .derived_publication or audience_kind == .summary_or_report_only))
        {
            out_cells[idx] = .missing;
            continue;
        }
        out_cells[idx] = cell;
    }
}

pub const AudienceCacheKey = struct {
    resource_object: u64,
    publication_revision: u64,
    basis_digest: [32]u8,
    params_digest: [32]u8,
    audience_policy_hash: [32]u8,
    policy_epoch: u64,

    pub fn computeDigest(self: AudienceCacheKey) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.published-resource.cache-key.v1\x00");
        var buf: [24]u8 = undefined;
        std.mem.writeInt(u64, buf[0..8], self.resource_object, .little);
        std.mem.writeInt(u64, buf[8..16], self.publication_revision, .little);
        std.mem.writeInt(u64, buf[16..24], self.policy_epoch, .little);
        hasher.update(&buf);
        hasher.update(&self.basis_digest);
        hasher.update(&self.params_digest);
        hasher.update(&self.audience_policy_hash);
        return hasher.finalResult();
    }

    pub fn canReuseFor(self: AudienceCacheKey, other: AudienceCacheKey) bool {
        return std.mem.eql(u8, &self.computeDigest(), &other.computeDigest());
    }
};

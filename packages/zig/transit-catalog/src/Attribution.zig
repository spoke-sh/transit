//! Attributable published results (`AttributionReceipt` / `ATB1`, magic `0x41544231`),
//! four-clock temporal truth (`source_observation_cut`, `domain_event_valid_time`,
//! `computation_completion_cut`, `requested_freshness_sla`), report artifact
//! consistency verification across charts/tables/pages, and evidence-linked
//! narratives with explicit assumption tags and non-oracle truth invariants (`D5`, `P5`).
const std = @import("std");
const c = @import("root.zig");
const DisclosurePolicy = c.DisclosurePolicy;
const InvestigationBasis = c.InvestigationBasis;
const PublishedResource = c.PublishedResource;

pub const magic_atb1: u32 = 0x41544231; // "ATB1"
pub const contract_id = "transit.catalog.attribution-receipt.v1";

pub const CompletenessState = enum(u8) {
    complete = 1,
    window_truncated = 2,
    interrupted_prefix = 3,
    budget_exceeded = 4,
};

pub const FreshnessStatus = enum(u8) {
    fresh = 1,
    stale_within_tolerance = 2,
    stale_exceeded = 3,
    unknown_freshness = 4,
    source_conflict = 5,
};

/// Distinguishes source observation time, business event time, computation completion,
/// and requested freshness SLA on every resource evaluation (`D5`).
pub const FourClockFreshness = struct {
    /// When Transit observed or captured the upstream sources (`0` if an external source lacks a timestamp).
    source_observation_cut_ms: ?u64,
    /// Business event-time watermark (`valid_time`).
    domain_event_valid_time_ms: ?u64,
    /// When the query or maintained dataflow revision completed computing.
    computation_completion_cut_ms: u64,
    /// Caller or resource freshness SLA bound in milliseconds.
    requested_freshness_sla_ms: u64,
    /// Set when 5-state `conflict` cells or divergent branch sources are present in the input.
    has_source_conflict: bool = false,

    pub fn evaluate(
        self: FourClockFreshness,
        evaluation_wall_clock_ms: u64,
        req: PublishedResource.FreshnessRequirement,
    ) !FreshnessStatus {
        if (self.computation_completion_cut_ms == 0 or self.requested_freshness_sla_ms == 0) {
            return error.InvalidFourClockFreshness;
        }
        if (self.has_source_conflict) return .source_conflict;
        const observed_ms = self.source_observation_cut_ms orelse return .unknown_freshness;
        if (evaluation_wall_clock_ms < observed_ms) return .fresh;
        const lag_ms = evaluation_wall_clock_ms - observed_ms;
        if (lag_ms <= self.requested_freshness_sla_ms) return .fresh;
        if (lag_ms <= req.max_staleness_ms and req.allow_stale_with_warning) {
            return .stale_within_tolerance;
        }
        return .stale_exceeded;
    }
};

pub const AttributionReceipt = struct {
    investigation_id: u64,
    basis_revision: u64,
    basis_kind: InvestigationBasis.BasisKind,
    basis_digest: [32]u8,
    resource_object: u64,
    publication_revision: u64,
    definition_digest: [32]u8,
    parameter_bindings_digest: [32]u8,
    schema_epoch: u64,
    verified_policy_epoch: u64,
    disclosure_mode: DisclosurePolicy.DisclosureMode,
    audience_policy_hash: [32]u8,
    freshness: FourClockFreshness,
    freshness_status: FreshnessStatus,
    completeness: CompletenessState,
    total_rows_observed: u64,

    pub fn validate(self: AttributionReceipt) !void {
        if (self.investigation_id == 0 or self.basis_revision == 0 or
            self.resource_object == 0 or self.publication_revision == 0 or
            self.schema_epoch == 0 or self.verified_policy_epoch == 0)
        {
            return error.InvalidAttributionReceipt;
        }
        if (std.mem.allEqual(u8, &self.basis_digest, 0) or
            std.mem.allEqual(u8, &self.definition_digest, 0) or
            std.mem.allEqual(u8, &self.audience_policy_hash, 0))
        {
            return error.InvalidAttributionReceiptDigest;
        }
    }

    pub fn receiptDigest(self: AttributionReceipt) ![32]u8 {
        try self.validate();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id ++ "\x00");
        var buf: [65]u8 = undefined;
        std.mem.writeInt(u32, buf[0..4], magic_atb1, .little);
        std.mem.writeInt(u64, buf[4..12], self.investigation_id, .little);
        std.mem.writeInt(u64, buf[12..20], self.basis_revision, .little);
        buf[20] = @backingInt(self.basis_kind);
        std.mem.writeInt(u64, buf[21..29], self.resource_object, .little);
        std.mem.writeInt(u64, buf[29..37], self.publication_revision, .little);
        std.mem.writeInt(u64, buf[37..45], self.schema_epoch, .little);
        std.mem.writeInt(u64, buf[45..53], self.verified_policy_epoch, .little);
        buf[53] = @backingInt(self.disclosure_mode);
        buf[54] = @backingInt(self.freshness_status);
        buf[55] = @backingInt(self.completeness);
        std.mem.writeInt(u64, buf[56..64], self.total_rows_observed, .little);
        buf[64] = if (self.freshness.has_source_conflict) 1 else 0;
        hasher.update(&buf);
        hasher.update(&self.basis_digest);
        hasher.update(&self.definition_digest);
        hasher.update(&self.parameter_bindings_digest);
        hasher.update(&self.audience_policy_hash);
        return hasher.finalResult();
    }

    pub fn verifyMatchesBasis(self: AttributionReceipt, basis: InvestigationBasis.InvestigationBasis) !void {
        try self.validate();
        const expected_digest = try basis.basisDigest();
        if (self.investigation_id != basis.investigation_id or
            self.basis_revision != basis.basis_revision or
            self.basis_kind != std.meta.activeTag(basis.payload) or
            !std.mem.eql(u8, &self.basis_digest, &expected_digest))
        {
            return error.AttributionBasisMismatch;
        }
    }
};

pub const AssumptionTag = enum(u8) {
    model_inference = 1,
    extrapolation = 2,
    external_unverified_claim = 3,
    human_annotation = 4,
};

pub const NarrativeClaim = struct {
    claim_id: []const u8,
    statement_text: []const u8,
    cited_receipt_digests: []const [32]u8,
    assumptions: []const AssumptionTag,
    /// Invariant: provenance identifies the data/computation basis, never proving
    /// an upstream external fact or a model conclusion objectively true (`D5`).
    provenance_establishes_truth: bool = false,

    pub fn validate(self: NarrativeClaim, available_receipt_digests: []const [32]u8) !void {
        if (self.claim_id.len == 0 or self.statement_text.len == 0) {
            return error.InvalidNarrativeClaim;
        }
        if (self.provenance_establishes_truth) {
            return error.ProvenanceCannotClaimObjectiveTruth;
        }
        if (self.cited_receipt_digests.len == 0) {
            return error.NarrativeClaimRequiresEvidenceCitations;
        }
        if (self.assumptions.len == 0) {
            return error.NarrativeClaimRequiresAssumptionTags;
        }
        for (self.cited_receipt_digests) |cited| {
            var found = false;
            for (available_receipt_digests) |avail| {
                if (std.mem.eql(u8, &cited, &avail)) {
                    found = true;
                    break;
                }
            }
            if (!found) return error.NarrativeClaimCitesUnknownReceipt;
        }
    }
};

pub const ReportArtifact = struct {
    report_id: []const u8,
    investigation_id: u64,
    basis_revision: u64,
    basis_digest: [32]u8,
    section_receipts: []const AttributionReceipt,
    narrative_claims: []const NarrativeClaim = &.{},

    /// Verifies that every chart, KPI summary, table page, and narrative claim in the
    /// report is bound to the exact same `(investigation_id, basis_revision, basis_digest)`.
    pub fn validateConsistentBasis(self: ReportArtifact, basis: InvestigationBasis.InvestigationBasis) ![32]u8 {
        if (self.report_id.len == 0 or self.section_receipts.len == 0) {
            return error.InvalidReportArtifact;
        }
        const expected_basis_digest = try basis.basisDigest();
        if (self.investigation_id != basis.investigation_id or
            self.basis_revision != basis.basis_revision or
            !std.mem.eql(u8, &self.basis_digest, &expected_basis_digest))
        {
            return error.AttributionBasisMismatch;
        }

        var receipt_digests: [32][32]u8 = undefined;
        if (self.section_receipts.len > receipt_digests.len) return error.TooManyReportSections;

        var report_hasher = std.crypto.hash.sha2.Sha256.init(.{});
        report_hasher.update("transit.catalog.report-artifact.v1\x00");
        report_hasher.update(self.report_id);
        report_hasher.update("\x00");
        report_hasher.update(&self.basis_digest);

        for (self.section_receipts, 0..) |receipt, i| {
            try receipt.verifyMatchesBasis(basis);
            receipt_digests[i] = try receipt.receiptDigest();
            report_hasher.update(&receipt_digests[i]);
        }

        const active_digests = receipt_digests[0..self.section_receipts.len];
        for (self.narrative_claims) |claim| {
            try claim.validate(active_digests);
            report_hasher.update(claim.claim_id);
            report_hasher.update("\x00");
        }

        return report_hasher.finalResult();
    }
};

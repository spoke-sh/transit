//! Durable investigation source bases (`INVESTIGATION_V1` / `INV1`, magic `0x494E5631`),
//! atomic domain cuts vs. explicit multi-source basis vectors, leased `TPINOBJ1` snapshot
//! pin accounting, transport-reconnect survival with zero implicit authorization,
//! historical schema projection (`AS OF` / `PROJECTING TO`), and immutable successor
//! refresh (`REFRESH INVESTIGATION`) (`D4`, `P4`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const TableSchemaProjection = fuze.TableSchemaProjection;
const HistoricalCatalog = c.HistoricalCatalog;
const PublishedResource = c.PublishedResource;
const DisclosurePolicy = c.DisclosurePolicy;

pub const magic_inv1: u32 = 0x494E5631; // "INV1"
pub const contract_id = "transit.catalog.investigation-basis.v1";
pub const max_basis_entries: usize = 32;

pub const InvestigationState = enum(u8) {
    active = 1,
    refreshed = 2,
    closed = 3,
    expired = 4,
};

pub const BasisKind = enum(u8) {
    /// Single native atomic domain (`BranchId` + `ManifestCut` + M5 `Transaction.Cut`).
    /// Mutually transaction-consistent across all native objects in the domain.
    atomic_domain_cut = 1,
    /// Explicit multi-source vector combining native cuts with captured external
    /// exchanges (M16) or foreign file manifests (M18). Never claims global atomicity.
    multi_source_basis_vector = 2,
};

pub const PinLease = struct {
    pin_id: u64,
    source_object: u64,
    owner_principal: u64,
    acquired_at_ms: u64,
    expires_at_ms: u64,
    released: bool = false,

    pub fn validate(self: PinLease) !void {
        if (self.pin_id == 0 or self.source_object == 0 or self.owner_principal == 0) {
            return error.InvalidInvestigationPinLease;
        }
        if (self.expires_at_ms <= self.acquired_at_ms) {
            return error.InvalidInvestigationPinLeaseWindow;
        }
    }

    pub fn isLiveAt(self: PinLease, now_ms: u64) bool {
        return !self.released and now_ms < self.expires_at_ms;
    }
};

pub const NativeSourceCut = struct {
    source_object: u64,
    source_revision: u64,
    branch_id: u64 = 1,
    manifest_version: u64,
    commit_lsn: u64,
    pin_lease: PinLease,
    source_deleted: bool = false,

    pub fn validate(self: NativeSourceCut) !void {
        if (self.source_object == 0 or self.source_revision == 0 or self.branch_id == 0 or
            self.manifest_version == 0 or self.commit_lsn == 0)
        {
            return error.InvalidNativeSourceCut;
        }
        try self.pin_lease.validate();
        if (self.pin_lease.source_object != self.source_object) {
            return error.PinLeaseSourceMismatch;
        }
    }
};

pub const CapturedExchangePin = struct {
    exchange_object: u64,
    exchange_revision: u64,
    payload_sha256: [32]u8,
    observed_at_ms: u64,
    capture_present: bool = true,

    pub fn validate(self: CapturedExchangePin) !void {
        if (self.exchange_object == 0 or self.exchange_revision == 0 or self.observed_at_ms == 0) {
            return error.InvalidCapturedExchangePin;
        }
        if (std.mem.allEqual(u8, &self.payload_sha256, 0)) {
            return error.InvalidCapturedExchangeDigest;
        }
    }
};

pub const ForeignSourcePin = struct {
    foreign_object: u64,
    uri: []const u8,
    etag_or_generation: []const u8,
    content_sha256: [32]u8,
    schema_epoch: u64,
    observed_at_ms: u64 = 0, // 0 indicates unknown upstream observation timestamp
    capture_present: bool = true,

    pub fn validate(self: ForeignSourcePin) !void {
        if (self.foreign_object == 0 or self.uri.len == 0 or self.etag_or_generation.len == 0 or self.schema_epoch == 0) {
            return error.InvalidForeignSourcePin;
        }
        if (std.mem.allEqual(u8, &self.content_sha256, 0)) {
            return error.InvalidForeignSourceDigest;
        }
    }
};

pub const SourceBasisEntry = union(enum) {
    native_source: NativeSourceCut,
    captured_exchange: CapturedExchangePin,
    foreign_source: ForeignSourcePin,

    pub fn objectId(self: SourceBasisEntry) u64 {
        return switch (self) {
            .native_source => |ns| ns.source_object,
            .captured_exchange => |ce| ce.exchange_object,
            .foreign_source => |fs| fs.foreign_object,
        };
    }

    pub fn revisionOrEpoch(self: SourceBasisEntry) u64 {
        return switch (self) {
            .native_source => |ns| ns.source_revision,
            .captured_exchange => |ce| ce.exchange_revision,
            .foreign_source => |fs| fs.schema_epoch,
        };
    }

    pub fn validate(self: SourceBasisEntry) !void {
        switch (self) {
            .native_source => |ns| try ns.validate(),
            .captured_exchange => |ce| try ce.validate(),
            .foreign_source => |fs| try fs.validate(),
        }
    }
};

pub const AtomicDomainCut = struct {
    branch_id: u64 = 1,
    manifest_cut: HistoricalCatalog.ManifestCut,
    tx_cut_id: u64,
    commit_lsn: u64,
    pins: []const PinLease,
    deleted_objects: []const u64 = &.{},

    pub fn validate(self: AtomicDomainCut) !void {
        if (self.branch_id == 0 or self.tx_cut_id == 0 or self.commit_lsn == 0) {
            return error.InvalidAtomicDomainCut;
        }
        if (self.manifest_cut.commit_lsn != self.commit_lsn) {
            return error.AtomicDomainCutLsnMismatch;
        }
        try self.manifest_cut.validate();
        if (self.pins.len == 0) return error.AtomicDomainCutRequiresPinLeases;
        for (self.pins) |pin| try pin.validate();
    }
};

pub const BasisPayload = union(BasisKind) {
    atomic_domain_cut: AtomicDomainCut,
    multi_source_basis_vector: []const SourceBasisEntry,
};

pub const BasisDiffSummary = struct {
    from_basis_revision: u64,
    to_basis_revision: u64,
    from_basis_digest: [32]u8,
    to_basis_digest: [32]u8,
    advanced_native_sources: u32,
    evolved_schema_sources: u32,
    changed_external_captures: u32,
};

pub const InvestigationBasis = struct {
    investigation_id: u64,
    basis_revision: u64,
    parent_basis_revision: ?u64 = null,
    created_by_principal: u64,
    created_at_ms: u64,
    state: InvestigationState = .active,
    payload: BasisPayload,

    pub fn isGloballyAtomic(self: InvestigationBasis) bool {
        return switch (self.payload) {
            .atomic_domain_cut => true,
            .multi_source_basis_vector => false,
        };
    }

    pub fn requireGlobalAtomicity(self: InvestigationBasis) !void {
        if (!self.isGloballyAtomic()) return error.NonAtomicBasisVector;
    }

    pub fn validate(self: InvestigationBasis) !void {
        if (self.investigation_id == 0 or self.basis_revision == 0 or self.created_by_principal == 0 or self.created_at_ms == 0) {
            return error.InvalidInvestigationIdentity;
        }
        if (self.basis_revision == 1) {
            if (self.parent_basis_revision != null) return error.InvalidInvestigationRevisionLineage;
        } else {
            const parent = self.parent_basis_revision orelse return error.InvalidInvestigationRevisionLineage;
            if (parent + 1 != self.basis_revision) return error.InvalidInvestigationRevisionLineage;
        }
        switch (self.payload) {
            .atomic_domain_cut => |adc| try adc.validate(),
            .multi_source_basis_vector => |entries| {
                if (entries.len == 0 or entries.len > max_basis_entries) return error.InvalidMultiSourceBasisVectorLength;
                for (entries, 0..) |entry, i| {
                    try entry.validate();
                    for (entries[0..i]) |earlier| {
                        if (earlier.objectId() == entry.objectId()) return error.DuplicateSourceInBasisVector;
                    }
                }
            },
        }
    }

    pub fn basisDigest(self: InvestigationBasis) ![32]u8 {
        try self.validate();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id ++ "\x00");
        var header: [37]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], magic_inv1, .little);
        std.mem.writeInt(u64, header[4..12], self.investigation_id, .little);
        std.mem.writeInt(u64, header[12..20], self.basis_revision, .little);
        std.mem.writeInt(u64, header[20..28], self.parent_basis_revision orelse 0, .little);
        std.mem.writeInt(u64, header[28..36], self.created_by_principal, .little);
        header[36] = @backingInt(std.meta.activeTag(self.payload));
        hasher.update(&header);

        switch (self.payload) {
            .atomic_domain_cut => |adc| {
                var cut_buf: [24]u8 = undefined;
                std.mem.writeInt(u64, cut_buf[0..8], adc.branch_id, .little);
                std.mem.writeInt(u64, cut_buf[8..16], adc.tx_cut_id, .little);
                std.mem.writeInt(u64, cut_buf[16..24], adc.commit_lsn, .little);
                hasher.update(&cut_buf);
                const m_digest = try adc.manifest_cut.digest();
                hasher.update(&m_digest);
            },
            .multi_source_basis_vector => |entries| {
                for (entries) |entry| {
                    switch (entry) {
                        .native_source => |ns| {
                            hasher.update(&[_]u8{1});
                            var b32: [32]u8 = undefined;
                            std.mem.writeInt(u64, b32[0..8], ns.source_object, .little);
                            std.mem.writeInt(u64, b32[8..16], ns.source_revision, .little);
                            std.mem.writeInt(u64, b32[16..24], ns.branch_id, .little);
                            std.mem.writeInt(u64, b32[24..32], ns.commit_lsn, .little);
                            hasher.update(&b32);
                        },
                        .captured_exchange => |ce| {
                            hasher.update(&[_]u8{2});
                            var b16: [16]u8 = undefined;
                            std.mem.writeInt(u64, b16[0..8], ce.exchange_object, .little);
                            std.mem.writeInt(u64, b16[8..16], ce.exchange_revision, .little);
                            hasher.update(&b16);
                            hasher.update(&ce.payload_sha256);
                        },
                        .foreign_source => |fs| {
                            hasher.update(&[_]u8{3});
                            var b16: [16]u8 = undefined;
                            std.mem.writeInt(u64, b16[0..8], fs.foreign_object, .little);
                            std.mem.writeInt(u64, b16[8..16], fs.schema_epoch, .little);
                            hasher.update(&b16);
                            hasher.update(fs.uri);
                            hasher.update("\x00");
                            hasher.update(fs.etag_or_generation);
                            hasher.update("\x00");
                            hasher.update(&fs.content_sha256);
                        },
                    }
                }
            },
        }
        return hasher.finalResult();
    }

    /// Verifies that the investigation basis is live at `now_ms`, that all referenced
    /// dependencies of `descriptor` are present in the frozen basis without missing
    /// captures, deleted sources, or expired snapshot pins, and that the caller's own
    /// `CallerAccessContext` authorizes evaluation at `current_policy_epoch`.
    /// Note: The investigation basis itself confers ZERO authorization.
    pub fn verifyForResourceEvaluation(
        self: InvestigationBasis,
        descriptor: PublishedResource.PublishedResourceDescriptor,
        policy: DisclosurePolicy.DisclosurePolicy,
        access: DisclosurePolicy.CallerAccessContext,
        current_policy_epoch: u64,
        now_ms: u64,
        min_retained_manifest_version: u64,
    ) !DisclosurePolicy.ConsumerAudienceKind {
        try self.validate();
        if (self.state == .closed) return error.InvestigationBasisClosed;
        if (self.state == .expired) return error.InvestigationBasisExpired;

        // First enforce caller authorization at `current_policy_epoch` (zero authority from basis).
        const audience = try DisclosurePolicy.authorizeEvaluation(descriptor, policy, access, current_policy_epoch, false);

        switch (self.payload) {
            .atomic_domain_cut => |adc| {
                if (adc.manifest_cut.manifest_version < min_retained_manifest_version) {
                    return error.InvestigationBasisExpired;
                }
                for (adc.pins) |pin| {
                    if (!pin.isLiveAt(now_ms)) return error.InvestigationBasisExpired;
                }
                for (descriptor.dependencies) |dep| {
                    for (adc.deleted_objects) |del_obj| {
                        if (del_obj == dep.source_object) return error.InvestigationSourceDeleted;
                    }
                    const table = HistoricalCatalog.findTableByObject(adc.manifest_cut.tables, dep.source_object) orelse return error.InvestigationSourceNotFound;
                    // If the table evolved between the resource's compiled revision and the basis cut,
                    // verify that M10's `TableSchemaProjection` can project the schema cleanly.
                    if (table.revision != dep.source_revision) {
                        for (dep.columns) |col_id| {
                            _ = table.schema.index(col_id) catch return error.IncompatibleInvestigationSchemaEvolution;
                        }
                    }
                }
            },
            .multi_source_basis_vector => |entries| {
                for (descriptor.dependencies) |dep| {
                    var found_entry: ?SourceBasisEntry = null;
                    for (entries) |entry| {
                        if (entry.objectId() == dep.source_object) {
                            found_entry = entry;
                            break;
                        }
                    }
                    const matched = found_entry orelse return error.DependencyMissingFromInvestigationBasis;
                    switch (matched) {
                        .native_source => |ns| {
                            if (ns.source_deleted) return error.InvestigationSourceDeleted;
                            if (ns.manifest_version < min_retained_manifest_version) return error.InvestigationBasisExpired;
                            if (!ns.pin_lease.isLiveAt(now_ms)) return error.InvestigationBasisExpired;
                        },
                        .captured_exchange => |ce| {
                            if (!ce.capture_present) return error.MissingExternalCapture;
                        },
                        .foreign_source => |fs| {
                            if (!fs.capture_present) return error.MissingExternalCapture;
                        },
                    }
                }
            },
        }
        return audience;
    }

    /// Creates an explicit successor basis revision (`basis_revision + 1`) and computes
    /// a `BasisDiffSummary` without mutating or relabeling `self`.
    pub fn refreshSuccessor(
        self: InvestigationBasis,
        next_payload: BasisPayload,
        refreshed_by_principal: u64,
        refreshed_at_ms: u64,
    ) !struct { successor: InvestigationBasis, diff: BasisDiffSummary } {
        try self.validate();
        if (self.state == .closed) return error.InvestigationBasisClosed;

        const successor: InvestigationBasis = .{
            .investigation_id = self.investigation_id,
            .basis_revision = self.basis_revision + 1,
            .parent_basis_revision = self.basis_revision,
            .created_by_principal = refreshed_by_principal,
            .created_at_ms = refreshed_at_ms,
            .state = .active,
            .payload = next_payload,
        };
        try successor.validate();

        const old_digest = try self.basisDigest();
        const new_digest = try successor.basisDigest();

        var advanced_native: u32 = 0;
        var evolved_schema: u32 = 0;
        var changed_external: u32 = 0;

        switch (self.payload) {
            .atomic_domain_cut => |old_adc| switch (successor.payload) {
                .atomic_domain_cut => |new_adc| {
                    for (new_adc.manifest_cut.tables) |new_tbl| {
                        if (HistoricalCatalog.findTableByObject(old_adc.manifest_cut.tables, new_tbl.object)) |old_tbl| {
                            if (new_adc.commit_lsn > old_adc.commit_lsn) advanced_native += 1;
                            if (new_tbl.revision != old_tbl.revision) evolved_schema += 1;
                        } else {
                            advanced_native += 1;
                        }
                    }
                },
                .multi_source_basis_vector => return error.IncompatibleBasisKindOnRefresh,
            },
            .multi_source_basis_vector => |old_entries| switch (successor.payload) {
                .atomic_domain_cut => return error.IncompatibleBasisKindOnRefresh,
                .multi_source_basis_vector => |new_entries| {
                    for (new_entries) |ne| {
                        for (old_entries) |oe| {
                            if (ne.objectId() == oe.objectId()) {
                                switch (ne) {
                                    .native_source => |n_ns| switch (oe) {
                                        .native_source => |o_ns| {
                                            if (n_ns.commit_lsn != o_ns.commit_lsn) advanced_native += 1;
                                            if (n_ns.source_revision != o_ns.source_revision) evolved_schema += 1;
                                        },
                                        else => return error.IncompatibleBasisKindOnRefresh,
                                    },
                                    .captured_exchange => |n_ce| switch (oe) {
                                        .captured_exchange => |o_ce| {
                                            if (!std.mem.eql(u8, &n_ce.payload_sha256, &o_ce.payload_sha256) or
                                                n_ce.exchange_revision != o_ce.exchange_revision)
                                            {
                                                changed_external += 1;
                                            }
                                        },
                                        else => return error.IncompatibleBasisKindOnRefresh,
                                    },
                                    .foreign_source => |n_fs| switch (oe) {
                                        .foreign_source => |o_fs| {
                                            if (!std.mem.eql(u8, &n_fs.content_sha256, &o_fs.content_sha256) or
                                                !std.mem.eql(u8, n_fs.etag_or_generation, o_fs.etag_or_generation))
                                            {
                                                changed_external += 1;
                                            }
                                            if (n_fs.schema_epoch != o_fs.schema_epoch) evolved_schema += 1;
                                        },
                                        else => return error.IncompatibleBasisKindOnRefresh,
                                    },
                                }
                            }
                        }
                    }
                },
            },
        }

        return .{
            .successor = successor,
            .diff = .{
                .from_basis_revision = self.basis_revision,
                .to_basis_revision = successor.basis_revision,
                .from_basis_digest = old_digest,
                .to_basis_digest = new_digest,
                .advanced_native_sources = advanced_native,
                .evolved_schema_sources = evolved_schema,
                .changed_external_captures = changed_external,
            },
        };
    }
};

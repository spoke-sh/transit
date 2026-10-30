//! Direct Document declarations, merge profiles, subcolumn shredding rules,
//! retention policies, operation budgets, and partition routing.
const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const Profile = enum {
    causal_crdt,
    versioned,
};

pub const Collation = enum {
    utf8_binary,
    ascii_ci,
    ebcdic_cp037,
};

pub const Partitioning = struct {
    count: u32,
    key_column: ?u64,
    hash: enum { sha256_64 },

    pub fn validate(self: Partitioning) !void {
        if (self.count == 0) return error.InvalidDocumentPartitioning;
        if (self.key_column) |column| if (column == 0) return error.InvalidDocumentPartitioning;
    }

    pub fn select(self: Partitioning, canonical_key: []const u8) !u32 {
        try self.validate();
        if (self.key_column == null) return error.DocumentPartitionKeyRequired;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(canonical_key, &digest, .{});
        return @intCast(std.mem.readInt(u64, digest[0..8], .big) % self.count);
    }
};

pub const Shredding = struct {
    frequent_path_threshold: u16,
    max_shredded_columns: u16,
    default_collation: Collation,

    pub fn validate(self: Shredding) !void {
        if (self.frequent_path_threshold == 0 or
            self.frequent_path_threshold > 4096 or
            self.max_shredded_columns == 0 or
            self.max_shredded_columns > 256)
        {
            return error.InvalidDocumentShredding;
        }
    }
};

pub const Retention = struct {
    max_age_ms: ?u64,
    merge_window_revisions: ?u64,

    pub fn validate(self: Retention) !void {
        if (self.max_age_ms) |age| {
            if (age == 0) return error.InvalidDocumentRetention;
        }
        if (self.merge_window_revisions) |revs| {
            if (revs == 0) return error.InvalidDocumentRetention;
        }
    }
};

pub const Configuration = struct {
    partitioning: Partitioning,
    profile: Profile,
    shredding: Shredding,
    retention: Retention,

    pub fn validate(self: Configuration) !void {
        try self.partitioning.validate();
        try self.shredding.validate();
        try self.retention.validate();
    }

    pub fn requireEvolution(self: Configuration, next: Configuration) !void {
        try self.validate();
        try next.validate();
        if (!std.meta.eql(self.partitioning, next.partitioning)) {
            return error.UnsupportedDocumentRepartition;
        }
        if (self.profile != next.profile or
            self.shredding.default_collation != next.shredding.default_collation)
        {
            return error.DocumentDeclarationConflict;
        }
    }
};

pub const Limits = struct {
    change_bytes: u32,
    operations_per_change: u16,
    path_depth: u16,
    read_steps: u32,
    read_bytes: u32,
    unresolved_conflicts: u16,

    pub fn validate(self: Limits) !void {
        inline for (@typeInfo(Limits).@"struct".field_names) |name| {
            if (@field(self, name) == 0) return error.InvalidDocumentLimits;
        }
    }
};

pub const Declaration = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    schema: d.Content,
    configuration: Configuration,
    limits: Limits,

    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        try self.schema.validate();
        try self.configuration.validate();
        try self.limits.validate();
        if (self.interpretation.object.branch != 1) return error.UnsupportedTransactionDomain;
    }

    pub fn requireSuccessor(self: Declaration, next: Declaration) !void {
        try self.validate();
        try next.validate();
        if (!std.meta.eql(self.interpretation.object, next.interpretation.object) or
            self.interpretation.revision == std.math.maxInt(u64) or
            next.interpretation.revision != self.interpretation.revision + 1)
        {
            return error.DocumentDeclarationConflict;
        }
        try self.configuration.requireEvolution(next.configuration);
    }
};

fn sampleDeclaration() Declaration {
    return .{
        .definition = p.Growth.current_definition,
        .interpretation = .{
            .object = .{
                .scope = .{ .realm = 1, .resource = 2, .catalog = 3 },
                .branch = 1,
                .object = 501,
            },
            .revision = 1,
            .digest = @splat(0x41),
        },
        .schema = .{
            .bytes = 256,
            .sha256 = @splat(0x52),
        },
        .configuration = .{
            .partitioning = .{ .count = 4, .key_column = 1, .hash = .sha256_64 },
            .profile = .causal_crdt,
            .shredding = .{
                .frequent_path_threshold = 64,
                .max_shredded_columns = 32,
                .default_collation = .utf8_binary,
            },
            .retention = .{
                .max_age_ms = 86_400_000,
                .merge_window_revisions = 1024,
            },
        },
        .limits = .{
            .change_bytes = 65_536,
            .operations_per_change = 64,
            .path_depth = 32,
            .read_steps = 4096,
            .read_bytes = 262_144,
            .unresolved_conflicts = 16,
        },
    };
}

test "document declaration validates shredding retention budgets and successor rules" {
    const base = sampleDeclaration();
    try base.validate();
    // Independent SHA-256("abc") prefix is ba7816bf8f01cfea.
    try t.expectEqual(@as(u32, 2), try base.configuration.partitioning.select("abc"));

    var next = base;
    next.interpretation.revision += 1;
    next.interpretation.digest[0] ^= 1;
    next.configuration.retention.max_age_ms = null;
    try base.requireSuccessor(next);

    next = base;
    next.interpretation.revision += 1;
    next.configuration.profile = .versioned;
    try t.expectError(error.DocumentDeclarationConflict, base.requireSuccessor(next));

    next = base;
    next.interpretation.revision += 1;
    next.configuration.partitioning.count = 8;
    try t.expectError(error.UnsupportedDocumentRepartition, base.requireSuccessor(next));

    var invalid = base;
    invalid.configuration.shredding.max_shredded_columns = 257;
    try t.expectError(error.InvalidDocumentShredding, invalid.validate());

    invalid = base;
    invalid.configuration.retention.merge_window_revisions = 0;
    try t.expectError(error.InvalidDocumentRetention, invalid.validate());

    invalid = base;
    invalid.limits.unresolved_conflicts = 0;
    try t.expectError(error.InvalidDocumentLimits, invalid.validate());

    invalid = base;
    invalid.configuration.partitioning.key_column = null;
    try invalid.validate();
    try t.expectError(error.DocumentPartitionKeyRequired, invalid.configuration.partitioning.select("abc"));
}

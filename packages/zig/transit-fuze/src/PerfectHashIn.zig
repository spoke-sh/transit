//! Compile-time (`comptime`) SQL keyword perfect-hash tables and plan-bound
//! constant `WHERE col IN (...)` literal lookup tables paired with 16-byte
//! `@Vector(16, u8)` SIMD prefix/equality comparisons and explicit collation
//! rules (`D5`, `P2`).
const std = @import("std");
const Collation = @import("Collation.zig");
const Types = @import("Types.zig");
const v = Types.Values;

pub const definition = "transit.fuze.perfect-hash-in.v1.2026-10-30";
pub const max_in_literals: usize = 64;
pub const table_capacity: usize = 128;
pub const simd_width: usize = 16;
pub const SimdVec = @Vector(simd_width, u8);

pub const EvalState = enum(u8) {
    value_true = 1,
    value_false = 2,
    null_unknown = 3,
    missing = 4,
    type_error = 5,
    conflict = 6,

    pub fn isTrue(self: EvalState) bool {
        return self == .value_true;
    }
};

pub inline fn loadSimdPrefix(bytes: []const u8, profile: Collation.Profile) SimdVec {
    const effective = if (profile == .ebcdic_037_pad)
        Collation.stripTrailingAsciiSpaces(bytes)
    else
        bytes;
    var buf: [simd_width]u8 = @splat(0);
    const n = @min(effective.len, simd_width);
    switch (profile) {
        .ascii_ci => {
            for (effective[0..n], 0..) |b, i| {
                buf[i] = Collation.asciiLower(b);
            }
        },
        else => {
            @memcpy(buf[0..n], effective[0..n]);
        },
    }
    return buf;
}

pub inline fn simdPrefixEqual(a: SimdVec, b: SimdVec) bool {
    return @reduce(.And, a == b);
}

pub fn hashNormalizedBytes(bytes: []const u8, profile: Collation.Profile, seed: u64) u64 {
    const effective = if (profile == .ebcdic_037_pad)
        Collation.stripTrailingAsciiSpaces(bytes)
    else
        bytes;
    var h: u64 = seed ^ 0x9e3779b97f4a7c15;
    for (effective) |b| {
        const norm: u8 = if (profile == .ascii_ci) Collation.asciiLower(b) else b;
        h ^= norm;
        h *%= 0x100000001b3;
    }
    h ^= @as(u64, @intCast(effective.len));
    h ^= h >> 33;
    h *%= 0xff51afd7ed558ccd;
    h ^= h >> 33;
    return h;
}

/// Compile-time perfect-hash lookup for Milestone 12 SQL keywords and lifecycle verbs.
pub const KeywordKind = enum(u8) {
    activate = 1,
    suspend_kw = 2,
    resume_kw = 3,
    refresh = 4,
    retire = 5,
    qualify = 6,
    lateral = 7,
    as_of = 8,
    changes = 9,
    stream_slice = 10,
    merge = 11,
    materialized = 12,
    dataflow = 13,
    subscription = 14,
    connection = 15,
    recursive = 16,
};

pub const KeywordEntry = struct {
    spelling: []const u8,
    kind: KeywordKind,
    prefix: [simd_width]u8,
};

fn buildKeywordPrefix(comptime s: []const u8) [simd_width]u8 {
    var out: [simd_width]u8 = @splat(0);
    for (s, 0..) |ch, i| {
        if (i < simd_width) out[i] = Collation.asciiLower(ch);
    }
    return out;
}

pub const keywords = [_]KeywordEntry{
    .{ .spelling = "ACTIVATE", .kind = .activate, .prefix = buildKeywordPrefix("ACTIVATE") },
    .{ .spelling = "SUSPEND", .kind = .suspend_kw, .prefix = buildKeywordPrefix("SUSPEND") },
    .{ .spelling = "RESUME", .kind = .resume_kw, .prefix = buildKeywordPrefix("RESUME") },
    .{ .spelling = "REFRESH", .kind = .refresh, .prefix = buildKeywordPrefix("REFRESH") },
    .{ .spelling = "RETIRE", .kind = .retire, .prefix = buildKeywordPrefix("RETIRE") },
    .{ .spelling = "QUALIFY", .kind = .qualify, .prefix = buildKeywordPrefix("QUALIFY") },
    .{ .spelling = "LATERAL", .kind = .lateral, .prefix = buildKeywordPrefix("LATERAL") },
    .{ .spelling = "AS_OF", .kind = .as_of, .prefix = buildKeywordPrefix("AS_OF") },
    .{ .spelling = "CHANGES", .kind = .changes, .prefix = buildKeywordPrefix("CHANGES") },
    .{ .spelling = "STREAM_SLICE", .kind = .stream_slice, .prefix = buildKeywordPrefix("STREAM_SLICE") },
    .{ .spelling = "MERGE", .kind = .merge, .prefix = buildKeywordPrefix("MERGE") },
    .{ .spelling = "MATERIALIZED", .kind = .materialized, .prefix = buildKeywordPrefix("MATERIALIZED") },
    .{ .spelling = "DATAFLOW", .kind = .dataflow, .prefix = buildKeywordPrefix("DATAFLOW") },
    .{ .spelling = "SUBSCRIPTION", .kind = .subscription, .prefix = buildKeywordPrefix("SUBSCRIPTION") },
    .{ .spelling = "CONNECTION", .kind = .connection, .prefix = buildKeywordPrefix("CONNECTION") },
    .{ .spelling = "RECURSIVE", .kind = .recursive, .prefix = buildKeywordPrefix("RECURSIVE") },
};

const KeywordTable = struct {
    seed: u64,
    slots: [64]?usize,
};

const comptime_keyword_table: KeywordTable = blk: {
    @setEvalBranchQuota(50_000);
    var seed: u64 = 1;
    while (seed < 1024) : (seed += 1) {
        var slots: [64]?usize = @splat(null);
        var collision = false;
        for (keywords, 0..) |kw, idx| {
            const h = hashNormalizedBytes(kw.spelling, .ascii_ci, seed);
            const pos: usize = @intCast(h & 63);
            if (slots[pos] != null) {
                collision = true;
                break;
            }
            slots[pos] = idx;
        }
        if (!collision) break :blk .{ .seed = seed, .slots = slots };
    }
    @compileError("Unable to find zero-collision comptime keyword seed");
};

/// O(1) zero-collision comptime perfect-hash + 16-byte SIMD keyword lookup.
pub fn lookupKeyword(token: []const u8) ?KeywordKind {
    if (token.len == 0 or token.len > simd_width) return null;
    const h = hashNormalizedBytes(token, .ascii_ci, comptime_keyword_table.seed);
    const idx = comptime_keyword_table.slots[@intCast(h & 63)] orelse return null;
    const entry = keywords[idx];
    if (entry.spelling.len != token.len) return null;
    const probe_vec = loadSimdPrefix(token, .ascii_ci);
    const entry_vec: SimdVec = entry.prefix;
    if (!simdPrefixEqual(probe_vec, entry_vec)) return null;
    return entry.kind;
}

/// Plan-bound perfect-hash lookup table for `WHERE col [NOT] IN (lit_1, ..., lit_k)`.
pub const StringInSet = struct {
    profile: Collation.Profile,
    negated: bool = false,
    has_null_literal: bool = false,
    seed: u64 = 0,
    count: usize = 0,
    literals: [max_in_literals][]const u8 = undefined,
    prefixes: [max_in_literals]SimdVec = undefined,
    effective_lengths: [max_in_literals]usize = @splat(0),
    slots: [table_capacity]?u8 = @splat(null),

    pub fn compile(
        raw_literals: []const ?[]const u8,
        profile: Collation.Profile,
        negated: bool,
    ) !StringInSet {
        try Collation.validateProfile(profile);
        if (raw_literals.len == 0 or raw_literals.len > max_in_literals) {
            return error.InvalidInSetCardinality;
        }

        var out: StringInSet = .{
            .profile = profile,
            .negated = negated,
        };

        // Deduplicate non-null literals under the declared collation profile
        for (raw_literals) |maybe_lit| {
            const lit = maybe_lit orelse {
                out.has_null_literal = true;
                continue;
            };
            try Collation.validateBytesProfile(lit, profile);
            var duplicate = false;
            for (out.literals[0..out.count]) |existing| {
                if (try Collation.compareBytesProfile(existing, lit, profile) == .eq) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                const idx = out.count;
                out.literals[idx] = lit;
                out.prefixes[idx] = loadSimdPrefix(lit, profile);
                out.effective_lengths[idx] = if (profile == .ebcdic_037_pad)
                    Collation.stripTrailingAsciiSpaces(lit).len
                else
                    lit.len;
                out.count += 1;
            }
        }

        // Find a zero-collision seed (or fall back to quadratic probing if hash collisions occur)
        var seed: u64 = 1;
        while (seed <= 512) : (seed += 1) {
            out.slots = @splat(null);
            var collision = false;
            for (0..out.count) |idx| {
                const h = hashNormalizedBytes(out.literals[idx], profile, seed);
                const pos: usize = @intCast(h & (table_capacity - 1));
                if (out.slots[pos] != null) {
                    collision = true;
                    break;
                }
                out.slots[pos] = @intCast(idx);
            }
            if (!collision) {
                out.seed = seed;
                return out;
            }
        }

        // Deterministic linear-probe fallback if two distinct strings share all 512 7-bit hashes
        out.seed = 1;
        out.slots = @splat(null);
        for (0..out.count) |idx| {
            const h = hashNormalizedBytes(out.literals[idx], profile, 1);
            var step: usize = 0;
            while (step < table_capacity) : (step += 1) {
                const pos = (@as(usize, @intCast(h)) + step) & (table_capacity - 1);
                if (out.slots[pos] == null) {
                    out.slots[pos] = @intCast(idx);
                    break;
                }
            }
        }
        return out;
    }

    pub fn containsBytes(self: *const StringInSet, candidate: []const u8) !bool {
        try Collation.validateBytesProfile(candidate, self.profile);
        if (self.count == 0) return false;
        const cand_vec = loadSimdPrefix(candidate, self.profile);
        const cand_eff_len = if (self.profile == .ebcdic_037_pad)
            Collation.stripTrailingAsciiSpaces(candidate).len
        else
            candidate.len;

        const h = hashNormalizedBytes(candidate, self.profile, self.seed);
        var step: usize = 0;
        while (step < table_capacity) : (step += 1) {
            const pos = (@as(usize, @intCast(h)) + step) & (table_capacity - 1);
            const idx = self.slots[pos] orelse return false;
            if (self.effective_lengths[idx] == cand_eff_len and
                simdPrefixEqual(self.prefixes[idx], cand_vec))
            {
                if (cand_eff_len <= simd_width) return true;
                if (try Collation.compareBytesProfile(self.literals[idx], candidate, self.profile) == .eq) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Evaluate `cell [NOT] IN (...)` preserving 5-state cell rules (`value`,
    /// `null`, `missing`, `type_error`, `conflict`).
    pub fn evaluateCell(self: *const StringInSet, cell: v.Cell) !EvalState {
        switch (cell) {
            .null => return .null_unknown,
            .missing => return .missing,
            .type_error => return .type_error,
            .conflict => return .conflict,
            .value => |val| switch (val) {
                .atom => |atom| switch (atom) {
                    .bytes => |bytes| {
                        const matched = self.containsBytes(bytes) catch |err| switch (err) {
                            error.UnrepresentableEbcdic037, error.UnrepresentableEbcdic1047, error.InvalidUtf8 => return .type_error,
                            else => return err,
                        };
                        if (matched) {
                            return if (self.negated) .value_false else .value_true;
                        }
                        if (self.has_null_literal) {
                            return .null_unknown;
                        }
                        return if (self.negated) .value_true else .value_false;
                    },
                    else => return .type_error,
                },
                else => return .type_error,
            },
        }
    }
};

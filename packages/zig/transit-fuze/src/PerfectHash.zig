//! Pure-Zig `comptime` and segment-sealed perfect hash tables using greedy
//! association-table construction (`slot = (len + asso[b0 + 256] + asso[b1]) & mask`)
//! paired with branchless 16-byte `@Vector(16, u8)` SIMD comparisons and
//! 4 KiB hardware page-boundary guards.
const std = @import("std");
const Collation = @import("Collation.zig");

/// Mandatory trailing zero-padding on internal `.tseg` page buffers, `Batch`
/// string arenas, and `Workspace` slabs so 16-byte `@Vector(16, u8)` loads
/// execute unconditionally without crossing buffer bounds.
pub const padding_bytes: usize = 64;
pub const page_size: usize = 4096;
pub const page_safe_max_offset: usize = page_size - 16;

pub const max_runtime_keys: usize = 1024;
pub const max_table_slots: usize = 2048;
pub const max_asso_attempts: u32 = 16384;
pub const empty_slot: u16 = std.math.maxInt(u16);

pub const Error = error{
    DuplicatePerfectHashKey,
    TooManyPerfectHashKeys,
    PerfectHashBufferTooSmall,
    UnsupportedColumnCollation,
    UnrepresentableEbcdic037,
    UnrepresentableEbcdic1047,
    InvalidUtf8,
};

pub const Mode = enum(u8) {
    perfect_hash = 1,
    sorted_fallback = 2,
};

const SelectorPair = struct {
    s0: u8,
    s1: u8,
    mix_tail: bool,
};

const candidate_selectors = [_]SelectorPair{
    .{ .s0 = 0, .s1 = 1, .mix_tail = true },
    .{ .s0 = 0, .s1 = 2, .mix_tail = true },
    .{ .s0 = 1, .s1 = 3, .mix_tail = true },
    .{ .s0 = 0, .s1 = 4, .mix_tail = true },
    .{ .s0 = 2, .s1 = 5, .mix_tail = true },
    .{ .s0 = 0, .s1 = 7, .mix_tail = false },
};

inline fn normalizeKeyByte(byte: u8, case_insensitive: bool) u8 {
    return if (case_insensitive) Collation.asciiLower(byte) else byte;
}

inline fn extractSignature(
    key: []const u8,
    sel: SelectorPair,
    case_insensitive: bool,
) struct { b0: u8, b1: u8 } {
    if (key.len == 0) return .{ .b0 = 0, .b1 = 0 };
    const idx0 = @as(usize, sel.s0) % key.len;
    const idx1 = @as(usize, sel.s1) % key.len;
    const raw0 = normalizeKeyByte(key[idx0], case_insensitive);
    const raw1 = normalizeKeyByte(key[idx1], case_insensitive);
    const tail = normalizeKeyByte(key[key.len - 1], case_insensitive);
    const mid = normalizeKeyByte(key[key.len / 2], case_insensitive);
    const b0 = if (sel.mix_tail) raw0 ^ (tail *% 3) else raw0;
    const b1 = if (sel.mix_tail) raw1 +% (mid *% 5) +% @as(u8, @truncate(key.len *% 17)) else raw1;
    return .{ .b0 = b0, .b1 = b1 };
}

pub inline fn computeSlot(
    key: []const u8,
    asso: *const [512]u16,
    mask: u16,
    sel: SelectorPair,
    case_insensitive: bool,
) usize {
    const sig = extractSignature(key, sel, case_insensitive);
    const len_u16: u16 = @truncate(key.len);
    const h: u16 = len_u16 +% asso[@as(usize, sig.b0) + 256] +% asso[@as(usize, sig.b1)];
    return @as(usize, h & mask);
}

/// Branchless 16-byte `@Vector(16, u8)` comparison against an internal buffer
/// guaranteed to carry at least 16 bytes of trailing zero-padding.
pub inline fn simdEql16Padded(
    candidate_padded_ptr: [*]const u8,
    candidate_len: usize,
    expected_vec: @Vector(16, u8),
    expected_len: u8,
    case_insensitive: bool,
) bool {
    if (candidate_len != expected_len) return false;
    if (expected_len == 0) return true;
    var cand_vec: @Vector(16, u8) = candidate_padded_ptr[0..16].*;
    if (case_insensitive) {
        cand_vec = simdAsciiLower16(cand_vec);
    }
    const valid_mask: u16 = if (expected_len == 16)
        0xFFFF
    else
        @intCast((@as(u32, 1) << @intCast(expected_len)) - 1);
    const eq_mask: u16 = @bitCast(cand_vec == expected_vec);
    return (eq_mask & valid_mask) == valid_mask;
}

/// Branchless 16-byte `@Vector(16, u8)` comparison for external caller slices
/// that may not have trailing padding. Guards against 4 KiB hardware page
/// boundaries (`(addr & 0xfff) <= 4080`) and falls back to a safe scalar loop
/// when the slice lies within 15 bytes of a page end.
pub inline fn simdEql16PageSafe(
    candidate: []const u8,
    expected_vec: @Vector(16, u8),
    expected_bytes: [16]u8,
    expected_len: u8,
    case_insensitive: bool,
) bool {
    if (candidate.len != expected_len) return false;
    if (expected_len == 0) return true;
    if (!@inComptime()) {
        const addr = @intFromPtr(candidate.ptr);
        if ((addr & 0xfff) <= page_safe_max_offset) {
            return simdEql16Padded(candidate.ptr, candidate.len, expected_vec, expected_len, case_insensitive);
        }
    }
    var diff: u8 = 0;
    for (candidate, expected_bytes[0..expected_len]) |c, e| {
        const nc = if (case_insensitive) Collation.asciiLower(c) else c;
        diff |= nc ^ e;
    }
    return diff == 0;
}

pub inline fn simdAsciiLower16(v: @Vector(16, u8)) @Vector(16, u8) {
    const a_vec: @Vector(16, u8) = @splat('A');
    const z_vec: @Vector(16, u8) = @splat('Z');
    const delta: @Vector(16, u8) = @splat('a' - 'A');
    const zeros: @Vector(16, u8) = @splat(0);
    const is_upper = (v >= a_vec) & (v <= z_vec);
    return v + @select(u8, is_upper, delta, zeros);
}

/// Page-safe arbitrary-length string equality using 16-byte SIMD vector chunks
/// on internal/page-safe regions and branchless scalar tail comparison near page boundaries.
pub fn eqlSlicePageSafe(
    candidate: []const u8,
    expected: []const u8,
    case_insensitive: bool,
) bool {
    if (candidate.len != expected.len) return false;
    var offset: usize = 0;
    while (offset + 16 <= candidate.len) : (offset += 16) {
        var c_vec: @Vector(16, u8) = candidate[offset..][0..16].*;
        var e_vec: @Vector(16, u8) = expected[offset..][0..16].*;
        if (case_insensitive) {
            c_vec = simdAsciiLower16(c_vec);
            e_vec = simdAsciiLower16(e_vec);
        }
        const eq_mask: u16 = @bitCast(c_vec == e_vec);
        if (eq_mask != 0xFFFF) return false;
    }
    const rem = candidate.len - offset;
    if (rem == 0) return true;
    var exp_pad: [16]u8 = @splat(0);
    for (expected[offset..], 0..) |b, i| {
        exp_pad[i] = if (case_insensitive) Collation.asciiLower(b) else b;
    }
    const exp_vec: @Vector(16, u8) = exp_pad;
    return simdEql16PageSafe(
        candidate[offset..],
        exp_vec,
        exp_pad,
        @intCast(rem),
        case_insensitive,
    );
}

pub fn nextPowerOfTwoSlots(key_count: usize) usize {
    if (key_count <= 4) return 8;
    return std.math.ceilPowerOfTwoAssert(usize, key_count * 2);
}

/// Compile-time (`comptime`) collision-free perfect hash map for static keyword,
/// DDL option, wire-protocol header, and diagnostic registries.
pub fn ComptimeMap(
    comptime V: type,
    comptime case_insensitive: bool,
    comptime entries: anytype,
) type {
    const entry_count = entries.len;
    if (entry_count == 0) @compileError("ComptimeMap requires at least one entry");
    if (entry_count > max_runtime_keys) @compileError("ComptimeMap exceeds max_runtime_keys");
    const slot_count = nextPowerOfTwoSlots(entry_count);
    const slot_mask: u16 = @intCast(slot_count - 1);

    const SlotEntry = struct {
        occupied: bool = false,
        key: []const u8 = "",
        prefix16: [16]u8 = @splat(0),
        prefix_len: u8 = 0,
        value: V = undefined,
    };

    const Built = struct {
        asso: [512]u16,
        selector: SelectorPair,
        slots: [slot_count]SlotEntry,
    };

    const built: Built = comptime blk: {
        @setEvalBranchQuota(2_000_000);
        var keys: [entry_count][]const u8 = undefined;
        for (entries, 0..) |entry, i| {
            keys[i] = entry[0];
            for (0..i) |prev| {
                if (eqlSlicePageSafe(keys[prev], keys[i], case_insensitive)) {
                    @compileError("Duplicate key in PerfectHash.ComptimeMap: " ++ keys[i]);
                }
            }
        }

        var asso: [512]u16 = @splat(0);
        var slot_to_key: [slot_count]u16 = @splat(empty_slot);
        var chosen_sel: ?SelectorPair = null;

        for (candidate_selectors) |sel| {
            if (tryBuildGreedyAsso(
                &keys,
                slot_count,
                sel,
                case_insensitive,
                &asso,
                &slot_to_key,
            )) {
                chosen_sel = sel;
                break;
            }
        }

        if (chosen_sel == null) {
            @compileError("PerfectHash.ComptimeMap failed to construct a collision-free association table within budget");
        }

        var final_slots: [slot_count]SlotEntry = @splat(.{});
        for (0..slot_count) |s| {
            const key_idx = slot_to_key[s];
            if (key_idx != empty_slot) {
                const k = entries[key_idx][0];
                var p16: [16]u8 = @splat(0);
                const plen: u8 = @intCast(@min(k.len, 16));
                for (k[0..plen], 0..) |b, bi| {
                    p16[bi] = if (case_insensitive) Collation.asciiLower(b) else b;
                }
                final_slots[s] = .{
                    .occupied = true,
                    .key = k,
                    .prefix16 = p16,
                    .prefix_len = plen,
                    .value = entries[key_idx][1],
                };
            }
        }

        break :blk .{
            .asso = asso,
            .selector = chosen_sel.?,
            .slots = final_slots,
        };
    };

    return struct {
        pub const count = entry_count;
        pub const table_slots = slot_count;

        pub fn get(candidate: []const u8) ?V {
            const slot_idx = computeSlot(
                candidate,
                &built.asso,
                slot_mask,
                built.selector,
                case_insensitive,
            );
            const entry = built.slots[slot_idx];
            if (!entry.occupied) return null;
            if (candidate.len != entry.key.len) return null;
            const exp_vec: @Vector(16, u8) = entry.prefix16;
            if (candidate.len <= 16) {
                if (!simdEql16PageSafe(
                    candidate,
                    exp_vec,
                    entry.prefix16,
                    entry.prefix_len,
                    case_insensitive,
                )) return null;
                return entry.value;
            }
            if (!simdEql16PageSafe(
                candidate[0..16],
                exp_vec,
                entry.prefix16,
                16,
                case_insensitive,
            )) return null;
            if (!eqlSlicePageSafe(candidate[16..], entry.key[16..], case_insensitive)) return null;
            return entry.value;
        }

        pub fn contains(candidate: []const u8) bool {
            return get(candidate) != null;
        }
    };
}

/// Greedy association-table builder shared by `comptime` and runtime frozen directories.
/// Places keys ordered by descending byte-signature frequency and searches displacements
/// within `max_asso_attempts`. Zero heap allocations.
fn tryBuildGreedyAsso(
    keys: []const []const u8,
    slot_count: usize,
    sel: SelectorPair,
    case_insensitive: bool,
    asso_out: *[512]u16,
    slot_to_key_out: []u16,
) bool {
    const n = keys.len;
    if (n > max_runtime_keys or slot_count > max_table_slots) return false;
    const mask: u16 = @intCast(slot_count - 1);

    // Check that no two keys share identical (len, b0, b1)
    var sig_b0: [max_runtime_keys]u8 = undefined;
    var sig_b1: [max_runtime_keys]u8 = undefined;
    var freq: [512]u16 = @splat(0);

    for (keys, 0..) |k, i| {
        const sig = extractSignature(k, sel, case_insensitive);
        sig_b0[i] = sig.b0;
        sig_b1[i] = sig.b1;
        freq[@as(usize, sig.b0) + 256] += 1;
        freq[@as(usize, sig.b1)] += 1;
    }

    for (0..n) |i| {
        for (i + 1..n) |j| {
            if (keys[i].len == keys[j].len and sig_b0[i] == sig_b0[j] and sig_b1[i] == sig_b1[j]) {
                return false;
            }
        }
    }

    // Order keys by decreasing constraint weight `freq[b0 + 256] + freq[b1]`
    var order: [max_runtime_keys]u16 = undefined;
    for (0..n) |i| order[i] = @intCast(i);
    for (1..n) |i| {
        const cur = order[i];
        const cur_w = @as(u32, freq[@as(usize, sig_b0[cur]) + 256]) + freq[@as(usize, sig_b1[cur])];
        var j: usize = i;
        while (j > 0) {
            const prev = order[j - 1];
            const prev_w = @as(u32, freq[@as(usize, sig_b0[prev]) + 256]) + freq[@as(usize, sig_b1[prev])];
            if (prev_w >= cur_w) break;
            order[j] = prev;
            j -= 1;
        }
        order[j] = cur;
    }

    asso_out.* = @splat(0);
    @memset(slot_to_key_out[0..slot_count], empty_slot);

    var placed: [max_runtime_keys]bool = @splat(false);
    var symbol_fixed: [512]bool = @splat(false);
    var attempts: u32 = 0;

    for (0..n) |ord_idx| {
        const key_idx = order[ord_idx];
        if (placed[key_idx]) continue;

        const s0_sym: usize = @as(usize, sig_b0[key_idx]) + 256;
        const s1_sym: usize = @as(usize, sig_b1[key_idx]);
        const tune_sym: usize = if (!symbol_fixed[s0_sym] and (symbol_fixed[s1_sym] or freq[s0_sym] >= freq[s1_sym]))
            s0_sym
        else if (!symbol_fixed[s1_sym])
            s1_sym
        else
            s0_sym;

        // Collect all unplaced keys sharing `tune_sym` whose other symbol is already fixed (or is the current key)
        var group: [max_runtime_keys]u16 = undefined;
        var group_len: usize = 0;
        for (0..n) |cand_ord| {
            const k_idx = order[cand_ord];
            if (placed[k_idx]) continue;
            const k_s0: usize = @as(usize, sig_b0[k_idx]) + 256;
            const k_s1: usize = @as(usize, sig_b1[k_idx]);
            if (k_s0 == tune_sym and (k_idx == key_idx or symbol_fixed[k_s1])) {
                group[group_len] = k_idx;
                group_len += 1;
            } else if (k_s1 == tune_sym and (k_idx == key_idx or symbol_fixed[k_s0])) {
                group[group_len] = k_idx;
                group_len += 1;
            }
        }

        var found_disp = false;
        var disp: u16 = 0;
        while (disp < slot_count) : (disp += 1) {
            attempts += 1;
            if (attempts > max_asso_attempts) return false;
            asso_out[tune_sym] = disp;

            var collision = false;
            var temp_slots: [64]usize = undefined;
            if (group_len > temp_slots.len) return false;

            for (group[0..group_len], 0..) |g_key, gi| {
                const slot = computeSlot(keys[g_key], asso_out, mask, sel, case_insensitive);
                if (slot_to_key_out[slot] != empty_slot) {
                    collision = true;
                    break;
                }
                for (temp_slots[0..gi]) |prev_slot| {
                    if (prev_slot == slot) {
                        collision = true;
                        break;
                    }
                }
                if (collision) break;
                temp_slots[gi] = slot;
            }

            if (!collision) {
                for (group[0..group_len], temp_slots[0..group_len]) |g_key, slot| {
                    slot_to_key_out[slot] = g_key;
                    placed[g_key] = true;
                    symbol_fixed[@as(usize, sig_b0[g_key]) + 256] = true;
                    symbol_fixed[@as(usize, sig_b1[g_key])] = true;
                }
                found_disp = true;
                break;
            }
        }

        if (!found_disp) return false;
    }

    return true;
}

/// Segment-sealed or plan-bound frozen lookup directory (`Plan.bind()` for
/// `WHERE col IN (...)`, `TableSchema` column lookup, and `.tseg` `.dictionary` pages).
/// Operates entirely inside fixed stack/struct storage or a caller-provided workspace
/// with zero steady-state heap allocations.
pub const FrozenDirectory = struct {
    mode: Mode = .perfect_hash,
    collation: Collation.Profile = .utf8_binary,
    key_count: u16 = 0,
    slot_count: u16 = 0,
    slot_mask: u16 = 0,
    selector: SelectorPair = candidate_selectors[0],
    asso: [512]u16 = @splat(0),
    slot_to_index: [max_table_slots]u16 = @splat(empty_slot),
    sorted_indices: [max_runtime_keys]u16 = @splat(0),
    prefix16_table: [max_runtime_keys][16]u8 = undefined,
    prefix_lens: [max_runtime_keys]u8 = @splat(0),

    /// Build a frozen directory over `keys` (where each entry's index `0..keys.len-1`
    /// is its dictionary code or ordinal). If `keys` exceeds the greedy association
    /// construction budget or uses a non-byte-injective collation, deterministically
    /// falls back to `.sorted_fallback` so lookups remain exact and allocation-free.
    pub fn init(keys: []const []const u8, collation: Collation.Profile) Error!FrozenDirectory {
        try Collation.validateProfile(collation);
        if (keys.len > max_runtime_keys) return error.TooManyPerfectHashKeys;

        var dir: FrozenDirectory = .{
            .collation = collation,
            .key_count = @intCast(keys.len),
        };
        if (keys.len == 0) return dir;

        const case_insensitive = (collation == .ascii_ci);
        for (keys, 0..) |k, i| {
            try Collation.validateBytesProfile(k, collation);
            dir.sorted_indices[i] = @intCast(i);
            var p16: [16]u8 = @splat(0);
            const plen: u8 = @intCast(@min(k.len, 16));
            for (k[0..plen], 0..) |b, bi| {
                p16[bi] = if (case_insensitive) Collation.asciiLower(b) else b;
            }
            dir.prefix16_table[i] = p16;
            dir.prefix_lens[i] = plen;
        }

        // Sort `sorted_indices` by declared collation and reject duplicate keys
        var i: usize = 1;
        while (i < keys.len) : (i += 1) {
            const cur = dir.sorted_indices[i];
            var j: usize = i;
            while (j > 0) {
                const prev = dir.sorted_indices[j - 1];
                const cmp = try Collation.compareBytesProfile(keys[prev], keys[cur], collation);
                if (cmp == .eq) return error.DuplicatePerfectHashKey;
                if (cmp == .lt) break;
                dir.sorted_indices[j] = prev;
                j -= 1;
            }
            dir.sorted_indices[j] = cur;
        }

        // `PAD SPACE` collations (`ebcdic_037_pad`) can match strings of different raw lengths,
        // so use the collation-sorted binary search directory unless `NO PAD` is active.
        if (collation == .ebcdic_037_pad) {
            dir.mode = .sorted_fallback;
            return dir;
        }

        const slots = nextPowerOfTwoSlots(keys.len);
        if (slots <= max_table_slots) {
            for (candidate_selectors) |sel| {
                if (tryBuildGreedyAsso(
                    keys,
                    slots,
                    sel,
                    case_insensitive,
                    &dir.asso,
                    dir.slot_to_index[0..slots],
                )) {
                    dir.mode = .perfect_hash;
                    dir.slot_count = @intCast(slots);
                    dir.slot_mask = @intCast(slots - 1);
                    dir.selector = sel;
                    return dir;
                }
            }
        }

        dir.mode = .sorted_fallback;
        return dir;
    }

    /// Look up `candidate` in `keys` and return its original index `0..keys.len-1`
    /// if present, or `null` if not a member. Executes with zero heap allocations.
    pub fn lookup(
        self: *const FrozenDirectory,
        keys: []const []const u8,
        candidate: []const u8,
    ) Error!?u16 {
        if (self.key_count == 0) return null;
        try Collation.validateBytesProfile(candidate, self.collation);

        if (self.mode == .perfect_hash) {
            const case_insensitive = (self.collation == .ascii_ci);
            const slot = computeSlot(
                candidate,
                &self.asso,
                self.slot_mask,
                self.selector,
                case_insensitive,
            );
            const idx = self.slot_to_index[slot];
            if (idx == empty_slot or idx >= keys.len) return null;
            const expected = keys[idx];
            if (candidate.len != expected.len) return null;
            const exp_vec: @Vector(16, u8) = self.prefix16_table[idx];
            if (candidate.len <= 16) {
                if (!simdEql16PageSafe(
                    candidate,
                    exp_vec,
                    self.prefix16_table[idx],
                    self.prefix_lens[idx],
                    case_insensitive,
                )) return null;
                return idx;
            }
            if (!simdEql16PageSafe(
                candidate[0..16],
                exp_vec,
                self.prefix16_table[idx],
                16,
                case_insensitive,
            )) return null;
            if (!eqlSlicePageSafe(candidate[16..], expected[16..], case_insensitive)) return null;
            return idx;
        }

        // Deterministic collation-sorted binary search fallback
        var lo: usize = 0;
        var hi: usize = self.key_count;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const key_idx = self.sorted_indices[mid];
            const cmp = try Collation.compareBytesProfile(candidate, keys[key_idx], self.collation);
            switch (cmp) {
                .eq => return key_idx,
                .lt => hi = mid,
                .gt => lo = mid + 1,
            }
        }
        return null;
    }

    pub fn contains(
        self: *const FrozenDirectory,
        keys: []const []const u8,
        candidate: []const u8,
    ) Error!bool {
        return (try self.lookup(keys, candidate)) != null;
    }
};

/// Compile-time collision-free perfect hash map for reserved SQL words (`Sql.isReserved`).
pub const ReservedSqlKeywordMap = ComptimeMap(bool, true, .{
    .{ "SELECT", true },
    .{ "WHERE", true },
    .{ "LIMIT", true },
    .{ "COUNT", true },
    .{ "SUM", true },
    .{ "IS", true },
    .{ "AND", true },
    .{ "OR", true },
    .{ "TRUE", true },
    .{ "FALSE", true },
    .{ "BYTEA", true },
    .{ "CREATE", true },
    .{ "CONNECTION", true },
    .{ "CONNECTIONS", true },
    .{ "SOURCE", true },
    .{ "SOURCES", true },
    .{ "SINK", true },
    .{ "SINKS", true },
    .{ "TABLE", true },
    .{ "TABLES", true },
    .{ "DOCUMENT", true },
    .{ "KV", true },
    .{ "TO", true },
    .{ "FROM", true },
    .{ "INTO", true },
    .{ "WITH", true },
    .{ "GRANT", true },
    .{ "REVOKE", true },
    .{ "ON", true },
    .{ "SHOW", true },
    .{ "DESCRIBE", true },
    .{ "NOT", true },
    .{ "NULL", true },
    .{ "SECRET", true },
    .{ "AS", true },
    .{ "OF", true },
    .{ "FOR", true },
    .{ "SYSTEM_TIME", true },
    .{ "INT64", true },
    .{ "BOOL", true },
    .{ "UTF8", true },
    .{ "BINARY", true },
});

pub const DdlOptionTag = enum(u8) {
    encoding_plain = 1,
    encoding_bitpacked = 2,
    encoding_rle = 3,
    encoding_dictionary = 4,
    encoding_fsst = 5,
    encoding_comp = 6,
    encoding_comp_3 = 7,
    encoding_zoned = 8,
    encoding_ibm_hfp = 9,
    encoding_ebcdic = 10,
    collation_utf8_binary = 11,
    collation_ascii_ci = 12,
    collation_ebcdic_cp037 = 13,
    collation_icu_root = 14,
    index_block_max_bm25 = 15,
    index_trigram_bitmap = 16,
    index_vector_ann = 17,
    collation_ebcdic_037_pad = 18,
    collation_ebcdic_1047_nopad = 19,
};

/// Compile-time collision-free perfect hash map for DDL codec, collation, and search index profiles.
pub const DdlOptionMap = ComptimeMap(DdlOptionTag, true, .{
    .{ "PLAIN", .encoding_plain },
    .{ "BITPACKED", .encoding_bitpacked },
    .{ "RLE", .encoding_rle },
    .{ "DICTIONARY", .encoding_dictionary },
    .{ "FSST", .encoding_fsst },
    .{ "COMP", .encoding_comp },
    .{ "COMP_3", .encoding_comp_3 },
    .{ "ZONED", .encoding_zoned },
    .{ "IBM_HFP", .encoding_ibm_hfp },
    .{ "EBCDIC", .encoding_ebcdic },
    .{ "UTF8_BINARY", .collation_utf8_binary },
    .{ "ASCII_CI", .collation_ascii_ci },
    .{ "EBCDIC_CP037", .collation_ebcdic_cp037 },
    .{ "EBCDIC_037_PAD", .collation_ebcdic_037_pad },
    .{ "EBCDIC_1047_NOPAD", .collation_ebcdic_1047_nopad },
    .{ "ICU_ROOT", .collation_icu_root },
    .{ "BLOCK_MAX_BM25", .index_block_max_bm25 },
    .{ "TRIGRAM_BITMAP", .index_trigram_bitmap },
    .{ "VECTOR_ANN", .index_vector_ann },
});

pub const WireHeaderTag = enum(u8) {
    content_type = 1,
    content_length = 2,
    authorization = 3,
    accept = 4,
    transfer_encoding = 5,
    connection = 6,
    x_transit_account = 7,
    x_transit_token = 8,
    x_transit_snapshot = 9,
    x_transit_branch = 10,
    client_encoding = 11,
    application_name = 12,
    TimeZone = 13,
    search_path = 14,
};

/// Compile-time collision-free perfect hash map for HTTP/PostgreSQL/MySQL wire headers and startup parameters.
pub const WireHeaderMap = ComptimeMap(WireHeaderTag, true, .{
    .{ "content-type", .content_type },
    .{ "content-length", .content_length },
    .{ "authorization", .authorization },
    .{ "accept", .accept },
    .{ "transfer-encoding", .transfer_encoding },
    .{ "connection", .connection },
    .{ "x-transit-account", .x_transit_account },
    .{ "x-transit-token", .x_transit_token },
    .{ "x-transit-snapshot", .x_transit_snapshot },
    .{ "x-transit-branch", .x_transit_branch },
    .{ "client_encoding", .client_encoding },
    .{ "application_name", .application_name },
    .{ "timezone", .TimeZone },
    .{ "search_path", .search_path },
});

//! 16-byte collation-prefixed inline strings ("Umbra / German Strings",
//! Neumann & Freitag CIDR 2020) for `Fuze` vectors, sort buffers, and
//! hash-join / `GROUP BY` working state.
//!
//! Layout (`extern struct`, 16 bytes aligned to 16 bytes):
//! - `len: u32`: Canonical collation-weight length $|W_\kappa(s)|$.
//! - `prefix: [4]u8`: First 4 bytes of the declared collation sort key $W_\kappa(s)[0..4]$.
//! - `tail: [8]u8`:
//!   - When `len <= 12`: inline continuation $W_\kappa(s)[4..12]$ (zero-padded),
//!     requiring zero out-of-line arena dereferences.
//!   - When `len > 12`: packed `PayloadHandle` (`offset: u32`, `byte_len: u24`,
//!     `generation: u8`) addressing a 64B-zero-padded `StringArena` / `Workspace`
//!     slab or pinned `.tseg` page buffer.
const std = @import("std");
const Collation = @import("Collation.zig");
const Ebcdic037 = @import("Ebcdic037.zig");
const Ebcdic1047 = @import("Ebcdic1047.zig");
const PerfectHash = @import("PerfectHash.zig");
const Types = @import("Types.zig");
const Values = @import("Values.zig");

pub const inline_max_bytes: u32 = 12;
pub const padding_bytes: usize = PerfectHash.padding_bytes;

pub const Error = error{
    StringArenaExhausted,
    StringTooLarge,
    StaleStringArenaHandle,
    InvalidStringArenaOffset,
    MissingStringArena,
    UnsupportedColumnCollation,
    UnrepresentableEbcdic037,
    UnrepresentableEbcdic1047,
    InvalidUtf8,
};

pub const PayloadHandle = packed struct(u64) {
    offset: u32 = 0,
    byte_len: u24 = 0,
    generation: u8 = 0,
};

/// Bounded string payload arena backed by a caller-owned slice or `transit-memory`
/// `Workspace` reservation. Enforces 64-byte trailing zero-padding for safe
/// unconditional `@Vector(16, u8)` SIMD loads and generation-checked handles.
pub const StringArena = struct {
    buffer: []u8,
    used: usize = 0,
    generation: u8 = 1,

    pub fn init(backing: []u8) Error!StringArena {
        if (backing.len < padding_bytes) return error.StringArenaExhausted;
        @memset(backing[0..padding_bytes], 0);
        return .{
            .buffer = backing,
            .used = 0,
            .generation = 1,
        };
    }

    /// Reset the arena for the next batch or morsel, incrementing `generation`
    /// so any stale `PayloadHandle` from an earlier batch is caught immediately.
    pub fn reset(self: *StringArena) void {
        self.used = 0;
        self.generation +%= 1;
        if (self.generation == 0) self.generation = 1;
        @memset(self.buffer[0..padding_bytes], 0);
    }

    pub fn usableCapacity(self: *const StringArena) usize {
        return self.buffer.len - padding_bytes;
    }

    pub fn append(self: *StringArena, bytes: []const u8) Error!PayloadHandle {
        if (bytes.len > std.math.maxInt(u24)) return error.StringTooLarge;
        if (self.used + bytes.len > self.usableCapacity()) return error.StringArenaExhausted;
        const offset: u32 = std.math.cast(u32, self.used) orelse return error.StringTooLarge;
        const dest = self.buffer[self.used .. self.used + bytes.len];
        @memcpy(dest, bytes);
        self.used += bytes.len;
        // Maintain 64-byte trailing zero-padding invariant after the written payload
        @memset(self.buffer[self.used .. self.used + padding_bytes], 0);
        return .{
            .offset = offset,
            .byte_len = @intCast(bytes.len),
            .generation = self.generation,
        };
    }

    pub fn resolve(self: *const StringArena, handle: PayloadHandle) Error![]const u8 {
        if (handle.generation != self.generation) return error.StaleStringArenaHandle;
        const start: usize = handle.offset;
        const len: usize = handle.byte_len;
        if (start + len > self.used) return error.InvalidStringArenaOffset;
        return self.buffer[start .. start + len];
    }

    /// Return a pointer guaranteed to have at least 64 bytes of trailing zero-padding.
    pub fn resolvePaddedPtr(self: *const StringArena, handle: PayloadHandle) Error![*]const u8 {
        const s = try self.resolve(handle);
        return s.ptr;
    }
};

pub const GermanString = extern struct {
    len: u32 = 0,
    prefix: [4]u8 = @splat(0),
    tail: [8]u8 = @splat(0),

    comptime {
        std.debug.assert(@sizeOf(GermanString) == 16);
        std.debug.assert(@alignOf(GermanString) == 4);
    }

    pub const empty: GermanString = .{};

    pub inline fn isInline(self: GermanString) bool {
        return self.len <= inline_max_bytes;
    }

    pub inline fn prefixU32(self: GermanString) u32 {
        return std.mem.readInt(u32, &self.prefix, .big);
    }

    pub inline fn tailU64(self: GermanString) u64 {
        return std.mem.readInt(u64, &self.tail, .big);
    }

    pub inline fn headerWord64(self: GermanString) u64 {
        return (@as(u64, self.len) << 32) | @as(u64, self.prefixU32());
    }

    pub inline fn handle(self: GermanString) PayloadHandle {
        std.debug.assert(!self.isInline());
        return @bitCast(self.tail);
    }

    pub inline fn inlineWeights(self: *const GermanString) [12]u8 {
        var out: [12]u8 = undefined;
        @memcpy(out[0..4], &self.prefix);
        @memcpy(out[4..12], &self.tail);
        return out;
    }

    /// Construct a 16-byte `GermanString` under `profile`.
    /// - Strings whose canonical collation weight sequence is $\le 12$ bytes are stored
    ///   completely inline inside `[prefix: 4B][tail: 8B]` with zero arena writes.
    /// - Strings with $> 12$ collation weights store their first 4 collation weights in
    ///   `prefix` and intern their payload into `arena`.
    pub fn init(
        bytes: []const u8,
        profile: Collation.Profile,
        arena: ?*StringArena,
    ) Error!GermanString {
        try Collation.validateBytesProfile(bytes, profile);
        const canonical = Collation.canonicalSliceProfile(bytes, profile);

        switch (profile) {
            .none, .utf8_binary => {
                const wlen: u32 = std.math.cast(u32, canonical.len) orelse return error.StringTooLarge;
                var gs: GermanString = .{ .len = wlen };
                const p_n = @min(canonical.len, 4);
                @memcpy(gs.prefix[0..p_n], canonical[0..p_n]);
                if (wlen <= inline_max_bytes) {
                    if (canonical.len > 4) {
                        const t_n = canonical.len - 4;
                        @memcpy(gs.tail[0..t_n], canonical[4..]);
                    }
                    return gs;
                }
                const ar = arena orelse return error.MissingStringArena;
                const h = try ar.append(canonical);
                gs.tail = @bitCast(h);
                return gs;
            },
            .ascii_ci => {
                const wlen: u32 = std.math.cast(u32, canonical.len) orelse return error.StringTooLarge;
                var gs: GermanString = .{ .len = wlen };
                const p_n = @min(canonical.len, 4);
                for (canonical[0..p_n], 0..) |b, i| gs.prefix[i] = Collation.asciiLower(b);
                if (wlen <= inline_max_bytes) {
                    if (canonical.len > 4) {
                        for (canonical[4..], 0..) |b, i| gs.tail[i] = Collation.asciiLower(b);
                    }
                    return gs;
                }
                const ar = arena orelse return error.MissingStringArena;
                const h = try ar.append(canonical);
                gs.tail = @bitCast(h);
                return gs;
            },
            .ebcdic_cp037, .ebcdic_037_pad => {
                var it = try Ebcdic037.Iterator.init(canonical);
                var weights_12: [12]u8 = @splat(0);
                var count: u32 = 0;
                while (try it.next()) |w| {
                    if (count < 12) weights_12[count] = w;
                    count = std.math.add(u32, count, 1) catch return error.StringTooLarge;
                }
                var gs: GermanString = .{ .len = count };
                @memcpy(&gs.prefix, weights_12[0..4]);
                if (count <= inline_max_bytes) {
                    @memcpy(&gs.tail, weights_12[4..12]);
                    return gs;
                }
                const ar = arena orelse return error.MissingStringArena;
                const h = try ar.append(canonical);
                gs.tail = @bitCast(h);
                return gs;
            },
            .ebcdic_1047_nopad => {
                var it = try Ebcdic1047.Iterator.init(canonical);
                var weights_12: [12]u8 = @splat(0);
                var count: u32 = 0;
                while (try it.next()) |w| {
                    if (count < 12) weights_12[count] = w;
                    count = std.math.add(u32, count, 1) catch return error.StringTooLarge;
                }
                var gs: GermanString = .{ .len = count };
                @memcpy(&gs.prefix, weights_12[0..4]);
                if (count <= inline_max_bytes) {
                    @memcpy(&gs.tail, weights_12[4..12]);
                    return gs;
                }
                const ar = arena orelse return error.MissingStringArena;
                const h = try ar.append(canonical);
                gs.tail = @bitCast(h);
                return gs;
            },
            .icu_root => return error.UnsupportedColumnCollation,
        }
    }

    /// Compare two `GermanString` values for equality under `profile`.
    /// - Short-circuits in a single 64-bit `(len, prefix)` register compare when lengths or
    ///   4-byte collation prefixes differ.
    /// - Completes in a second 64-bit register compare (`tailU64`) when `len <= 12`.
    /// - Touches out-of-line `StringArena` bytes only when `len > 12` AND `a.prefix == b.prefix`.
    pub fn eql(
        self: GermanString,
        other: GermanString,
        profile: Collation.Profile,
        arena: ?*const StringArena,
    ) Error!bool {
        if (self.headerWord64() != other.headerWord64()) return false;
        if (self.len <= inline_max_bytes) {
            return self.tailU64() == other.tailU64();
        }
        const ar = arena orelse return error.MissingStringArena;
        const left_bytes = try ar.resolve(self.handle());
        const right_bytes = try ar.resolve(other.handle());
        return switch (profile) {
            .none, .utf8_binary, .ebcdic_cp037, .ebcdic_037_pad, .ebcdic_1047_nopad => PerfectHash.eqlSlicePageSafe(
                left_bytes,
                right_bytes,
                false,
            ),
            .ascii_ci => PerfectHash.eqlSlicePageSafe(
                left_bytes,
                right_bytes,
                true,
            ),
            .icu_root => error.UnsupportedColumnCollation,
        };
    }

    /// Compare two `GermanString` values for ordering (`<`, `<=`, `>`, `>=`, `ORDER BY`)
    /// under `profile`:
    /// 1. 4-byte `prefixU32` register comparison decides immediately whenever `self.prefix != other.prefix`.
    /// 2. When both strings have `len <= 12`, `tailU64` + `len` decides inline with zero arena reads.
    /// 3. Out-of-line `StringArena` payload bytes are read only when `self.prefix == other.prefix`
    ///    and `@max(self.len, other.len) > 12`.
    pub fn order(
        self: GermanString,
        other: GermanString,
        profile: Collation.Profile,
        arena: ?*const StringArena,
    ) Error!std.math.Order {
        const p_cmp = std.math.order(self.prefixU32(), other.prefixU32());
        if (p_cmp != .eq) return p_cmp;

        if (self.len <= inline_max_bytes and other.len <= inline_max_bytes) {
            const t_cmp = std.math.order(self.tailU64(), other.tailU64());
            if (t_cmp != .eq) return t_cmp;
            return std.math.order(self.len, other.len);
        }

        const ar = arena orelse return error.MissingStringArena;
        var left_inline_utf8: [48]u8 = undefined;
        var right_inline_utf8: [48]u8 = undefined;

        const left_slice = if (self.isInline())
            try decodeInlineToSlice(&self, profile, &left_inline_utf8)
        else
            try ar.resolve(self.handle());

        const right_slice = if (other.isInline())
            try decodeInlineToSlice(&other, profile, &right_inline_utf8)
        else
            try ar.resolve(other.handle());

        return Collation.compareBytesProfile(left_slice, right_slice, profile);
    }

    /// Compute a 64-bit hash key directly from the collation-normalized representation
    /// (inline for `len <= 12`, or streaming over `arena` for `len > 12`) so `GROUP BY`
    /// and hash-join keys obey collation equivalence (`'a'` == `'a   '` under `PAD SPACE`).
    pub fn hash64(
        self: GermanString,
        profile: Collation.Profile,
        arena: ?*const StringArena,
    ) Error!u64 {
        var hasher = std.hash.Wyhash.init(0x5452414E53495431); // "TRANSIT1"
        const len_bytes = std.mem.asBytes(&self.len);
        hasher.update(len_bytes);
        if (self.isInline()) {
            const w = self.inlineWeights();
            hasher.update(w[0..self.len]);
            return hasher.final();
        }
        const ar = arena orelse return error.MissingStringArena;
        const raw = try ar.resolve(self.handle());
        switch (profile) {
            .none, .utf8_binary => hasher.update(raw),
            .ascii_ci => {
                var buf: [64]u8 = undefined;
                var idx: usize = 0;
                while (idx < raw.len) {
                    const chunk = @min(raw.len - idx, buf.len);
                    for (raw[idx .. idx + chunk], 0..) |b, i| buf[i] = Collation.asciiLower(b);
                    hasher.update(buf[0..chunk]);
                    idx += chunk;
                }
            },
            .ebcdic_cp037, .ebcdic_037_pad => {
                var it = try Ebcdic037.Iterator.init(raw);
                var buf: [64]u8 = undefined;
                var used: usize = 0;
                while (try it.next()) |b| {
                    buf[used] = b;
                    used += 1;
                    if (used == buf.len) {
                        hasher.update(&buf);
                        used = 0;
                    }
                }
                if (used > 0) hasher.update(buf[0..used]);
            },
            .ebcdic_1047_nopad => {
                var it = try Ebcdic1047.Iterator.init(raw);
                var buf: [64]u8 = undefined;
                var used: usize = 0;
                while (try it.next()) |b| {
                    buf[used] = b;
                    used += 1;
                    if (used == buf.len) {
                        hasher.update(&buf);
                        used = 0;
                    }
                }
                if (used > 0) hasher.update(buf[0..used]);
            },
            .icu_root => return error.UnsupportedColumnCollation,
        }
        return hasher.final();
    }
};

fn decodeInlineToSlice(
    gs: *const GermanString,
    profile: Collation.Profile,
    out: *[48]u8,
) Error![]const u8 {
    const weights = gs.inlineWeights();
    const w_slice = weights[0..gs.len];
    return switch (profile) {
        .none, .utf8_binary, .ascii_ci => blk: {
            @memcpy(out[0..w_slice.len], w_slice);
            break :blk out[0..w_slice.len];
        },
        .ebcdic_cp037, .ebcdic_037_pad => Ebcdic037.decode(w_slice, out) catch return error.InvalidUtf8,
        .ebcdic_1047_nopad => Ebcdic1047.decode(w_slice, out) catch return error.InvalidUtf8,
        .icu_root => error.UnsupportedColumnCollation,
    };
}

/// Five-state cell wrapper pairing a `Types.State` tag and error/conflict detail
/// with an inline 16-byte `GermanString` slot (`missing`, `null`, `type_error`,
/// `conflict`, `value`). Non-value states zero their `GermanString` slot.
pub const GermanCell = struct {
    state: Types.State = .null,
    error_kind: Types.Kind = .utf8,
    conflict_count: u32 = 0,
    string: GermanString = GermanString.empty,

    pub fn fromCell(
        cell: Values.Cell,
        profile: Collation.Profile,
        arena: ?*StringArena,
    ) Error!GermanCell {
        return switch (cell) {
            .missing => .{ .state = .missing },
            .null => .{ .state = .null },
            .type_error => |k| .{ .state = .type_error, .error_kind = k },
            .conflict => |alts| .{ .state = .conflict, .conflict_count = @intCast(alts.len) },
            .value => |v| .{
                .state = .value,
                .string = try GermanString.init(
                    if (v == .json) v.json else v.atom.bytes,
                    profile,
                    arena,
                ),
            },
        };
    }

    pub fn order(
        left: GermanCell,
        right: GermanCell,
        profile: Collation.Profile,
        arena: ?*const StringArena,
    ) Error!std.math.Order {
        const rl = stateRank(left.state);
        const rr = stateRank(right.state);
        if (rl != rr) return std.math.order(rl, rr);
        return switch (left.state) {
            .missing, .null => .eq,
            .type_error => std.math.order(@backingInt(left.error_kind), @backingInt(right.error_kind)),
            .conflict => std.math.order(left.conflict_count, right.conflict_count),
            .value => left.string.order(right.string, profile, arena),
        };
    }
};

fn stateRank(state: Types.State) u8 {
    return switch (state) {
        .missing => 0,
        .null => 1,
        .type_error => 2,
        .conflict => 3,
        .value => 4,
    };
}

/// Vectorized batch filter over a contiguous slice of `GermanString` slots and
/// orthogonal 5-state `tags`, comparing against a pre-encoded `literal: GermanString`
/// and populating a 64-bit bitmask of matching rows (`0..64`).
pub fn filterSliceMask64(
    strings: []const GermanString,
    tags: []const u8,
    op: enum { eq, ne, lt, le, gt, ge },
    literal: GermanString,
    profile: Collation.Profile,
    arena: ?*const StringArena,
) Error!u64 {
    std.debug.assert(strings.len <= 64 and tags.len == strings.len);
    var mask: u64 = 0;
    const lit_header = literal.headerWord64();
    const lit_prefix = literal.prefixU32();
    const lit_inline = literal.isInline();
    const lit_tail = literal.tailU64();

    for (strings, tags, 0..) |gs, tag, i| {
        // Only `.value` rows (`tag == 0` in PlainColumnBuffers/VectorPage convention) match value comparisons
        if (tag != 0) continue;
        const matched: bool = switch (op) {
            .eq => blk: {
                if (gs.headerWord64() != lit_header) break :blk false;
                if (lit_inline) break :blk (gs.tailU64() == lit_tail);
                break :blk try gs.eql(literal, profile, arena);
            },
            .ne => blk: {
                if (gs.headerWord64() != lit_header) break :blk true;
                if (lit_inline) break :blk (gs.tailU64() != lit_tail);
                break :blk !(try gs.eql(literal, profile, arena));
            },
            .lt, .le, .gt, .ge => blk: {
                const p_a = gs.prefixU32();
                const ord: std.math.Order = if (p_a != lit_prefix)
                    std.math.order(p_a, lit_prefix)
                else
                    try gs.order(literal, profile, arena);
                break :blk switch (op) {
                    .lt => ord == .lt,
                    .le => ord == .lt or ord == .eq,
                    .gt => ord == .gt,
                    .ge => ord == .gt or ord == .eq,
                    else => unreachable,
                };
            },
        };
        if (matched) mask |= (@as(u64, 1) << @intCast(i));
    }
    return mask;
}

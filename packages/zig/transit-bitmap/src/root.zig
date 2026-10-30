//! Shared Roaring array/bitmap/run containers. One container addresses 2^16
//! offsets. Owning paged directories select containers for larger durable sets.
//! No allocation or I/O; callers reuse Container scratch and own encoded output.
const std = @import("std");

pub const values_per_container: usize = 1 << 16;
pub const word_count = values_per_container / 64;
pub const header_bytes = 12;
pub const max_encoded_bytes = header_bytes + word_count * 8;
pub const Kind = enum(u8) { array = 1, bitmap = 2, run = 3 };

fn overlaps(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const a = @intFromPtr(left.ptr);
    const b = @intFromPtr(right.ptr);
    return if (a <= b) b - a < left.len else a - b < right.len;
}

fn get16(bytes: []const u8, at: usize) u16 {
    return std.mem.readInt(u16, bytes[at..][0..2], .little);
}
fn get32(bytes: []const u8, at: usize) u32 {
    return std.mem.readInt(u32, bytes[at..][0..4], .little);
}
fn put16(bytes: []u8, at: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[at..][0..2], value, .little);
}
fn put32(bytes: []u8, at: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[at..][0..4], value, .little);
}
fn selectedKind(cardinality: u32, runs: u32) Kind {
    const array_bytes = cardinality * 2;
    const run_bytes = 4 + runs * 4;
    if (array_bytes <= run_bytes and array_bytes <= word_count * 8) return .array;
    if (run_bytes <= word_count * 8) return .run;
    return .bitmap;
}

/// Reusable fixed scratch for one container; it is not a total-set capacity.
pub const Container = struct {
    words: [word_count]u64 align(64) = @splat(0),
    cardinality: u32 = 0,

    pub fn clear(self: *Container) void {
        @memset(&self.words, 0);
        self.cardinality = 0;
    }

    pub fn contains(self: *const Container, value: u16) bool {
        return self.words[value / 64] & (@as(u64, 1) << @as(u6, @truncate(value))) != 0;
    }

    pub fn set(self: *Container, value: u16) bool {
        const word = &self.words[value / 64];
        const bit = @as(u64, 1) << @as(u6, @truncate(value));
        if (word.* & bit != 0) return false;
        word.* |= bit;
        self.cardinality += 1;
        return true;
    }

    pub fn unset(self: *Container, value: u16) bool {
        const word = &self.words[value / 64];
        const bit = @as(u64, 1) << @as(u6, @truncate(value));
        if (word.* & bit == 0) return false;
        word.* &= ~bit;
        self.cardinality -= 1;
        return true;
    }

    pub fn unionWith(self: *Container, other: *const Container) void {
        self.cardinality = 0;
        for (&self.words, other.words) |*left, right| {
            left.* |= right;
            self.cardinality += @popCount(left.*);
        }
    }

    pub fn intersectWith(self: *Container, other: *const Container) void {
        self.cardinality = 0;
        for (&self.words, other.words) |*left, right| {
            left.* &= right;
            self.cardinality += @popCount(left.*);
        }
    }

    pub const Iterator = struct {
        owner: *const Container,
        word: usize = 0,
        remaining: u64,

        pub fn next(self: *Iterator) ?u16 {
            while (self.remaining == 0) {
                if (self.word >= word_count) return null;
                self.word += 1;
                if (self.word >= word_count) return null;
                self.remaining = self.owner.words[self.word];
            }
            const bit = @ctz(self.remaining);
            self.remaining &= self.remaining - 1;
            return @intCast(self.word * 64 + bit);
        }
    };

    pub fn iterator(self: *const Container) Iterator {
        return .{ .owner = self, .remaining = self.words[0] };
    }

    /// Canonical internal container codec. Persistent owners must wrap it with
    /// their mandatory contract definition, object/range binding and integrity.
    /// This is not the upstream portable Roaring serialization format.
    pub fn encode(self: *const Container, output: []u8) ![]const u8 {
        if (overlaps(std.mem.asBytes(self), output)) return error.BitmapBufferAlias;
        var runs: u32 = 0;
        var count: u32 = 0;
        var previous: ?u16 = null;
        var it = self.iterator();
        while (it.next()) |value| {
            if (previous == null or @as(u32, previous.?) + 1 != value) runs += 1;
            previous = value;
            count += 1;
        }
        if (count != self.cardinality) return error.InvalidBitmapCardinality;
        const kind = selectedKind(count, runs);
        const size: usize = header_bytes + switch (kind) {
            .array => count * 2,
            .bitmap => word_count * 8,
            .run => 4 + runs * 4,
        };
        if (output.len < size) return error.BitmapOutputTooSmall;
        const bytes = output[0..size];
        @memcpy(bytes[0..4], "RBC1");
        bytes[4] = @backingInt(kind);
        @memset(bytes[5..8], 0);
        put32(bytes, 8, count);
        var at: usize = header_bytes;
        switch (kind) {
            .array => {
                it = self.iterator();
                while (it.next()) |value| {
                    put16(bytes, at, value);
                    at += 2;
                }
            },
            .bitmap => for (self.words) |word| {
                std.mem.writeInt(u64, bytes[at..][0..8], word, .little);
                at += 8;
            },
            .run => {
                put32(bytes, at, runs);
                at += 4;
                it = self.iterator();
                var start = it.next().?;
                var end = start;
                while (it.next()) |value| {
                    if (@as(u32, end) + 1 != value) {
                        put16(bytes, at, start);
                        put16(bytes, at + 2, end - start);
                        at += 4;
                        start = value;
                    }
                    end = value;
                }
                put16(bytes, at, start);
                put16(bytes, at + 2, end - start);
            },
        }
        return bytes;
    }

    /// Parse before mutating scratch: malformed input preserves its old value.
    pub fn decode(self: *Container, bytes: []const u8) !void {
        if (overlaps(std.mem.asBytes(self), bytes)) return error.BitmapBufferAlias;
        const view = try View.parse(bytes);
        self.clear();
        var it = view.iterator();
        while (it.next()) |value| _ = self.set(value);
    }
};

/// Borrowed validated bytes. Keep them immutable and alive through every read.
pub const View = struct {
    bytes: []const u8,
    kind: Kind,
    cardinality: u32,

    pub fn parse(bytes: []const u8) !View {
        if (bytes.len < header_bytes or bytes.len > max_encoded_bytes or
            !std.mem.eql(u8, bytes[0..4], "RBC1") or
            !std.mem.allEqual(u8, bytes[5..8], 0)) return error.InvalidBitmapEncoding;
        const kind = std.enums.fromInt(Kind, bytes[4]) orelse return error.InvalidBitmapEncoding;
        const count = get32(bytes, 8);
        if (count > values_per_container) return error.InvalidBitmapEncoding;
        var runs: u32 = 0;
        switch (kind) {
            .array => {
                if (bytes.len != header_bytes + count * 2) return error.InvalidBitmapEncoding;
                var previous: ?u16 = null;
                for (0..count) |i| {
                    const value = get16(bytes, header_bytes + i * 2);
                    if (previous) |prev| {
                        if (value <= prev) return error.InvalidBitmapEncoding;
                        if (@as(u32, prev) + 1 != value) runs += 1;
                    } else runs += 1;
                    previous = value;
                }
            },
            .bitmap => {
                if (bytes.len != max_encoded_bytes) return error.InvalidBitmapEncoding;
                var actual: u32 = 0;
                var previous_high: u64 = 0;
                for (0..word_count) |i| {
                    const word = std.mem.readInt(u64, bytes[header_bytes + i * 8 ..][0..8], .little);
                    actual += @popCount(word);
                    runs += @popCount(word & ~((word << 1) | previous_high));
                    previous_high = word >> 63;
                }
                if (actual != count) return error.InvalidBitmapEncoding;
            },
            .run => {
                if (bytes.len < header_bytes + 4) return error.InvalidBitmapEncoding;
                runs = get32(bytes, header_bytes);
                if (runs == 0 or runs > values_per_container / 2 or
                    bytes.len != header_bytes + 4 + @as(usize, runs) * 4) return error.InvalidBitmapEncoding;
                var actual: u32 = 0;
                var previous: ?u32 = null;
                for (0..runs) |i| {
                    const at = header_bytes + 4 + i * 4;
                    const start: u32 = get16(bytes, at);
                    const length: u32 = @as(u32, get16(bytes, at + 2)) + 1;
                    if (start + length > values_per_container) return error.InvalidBitmapEncoding;
                    if (previous) |end| if (start <= end) return error.InvalidBitmapEncoding;
                    previous = start + length; // exclusive: adjacent runs must merge
                    actual += length;
                }
                if (actual != count) return error.InvalidBitmapEncoding;
            },
        }
        if (kind != selectedKind(count, runs)) return error.NonCanonicalBitmap;
        return .{ .bytes = bytes, .kind = kind, .cardinality = count };
    }

    pub fn contains(self: View, value: u16) bool {
        if (self.kind == .bitmap) {
            const word = std.mem.readInt(u64, self.bytes[header_bytes + @as(usize, value / 64) * 8 ..][0..8], .little);
            return word & (@as(u64, 1) << @as(u6, @truncate(value))) != 0;
        }
        var low: usize = 0;
        var high: usize = if (self.kind == .array) self.cardinality else get32(self.bytes, header_bytes);
        while (low < high) {
            const mid = low + (high - low) / 2;
            const at = if (self.kind == .array) header_bytes + mid * 2 else header_bytes + 4 + mid * 4;
            const first = get16(self.bytes, at);
            const last: u32 = @as(u32, first) + if (self.kind == .run) @as(u32, get16(self.bytes, at + 2)) else 0;
            if (value < first) high = mid else if (value > last) low = mid + 1 else return true;
        }
        return false;
    }

    pub const Iterator = struct {
        view: View,
        index: usize = 0,
        run_offset: u32 = 0,
        word: u64 = 0,

        pub fn next(self: *Iterator) ?u16 {
            switch (self.view.kind) {
                .array => {
                    if (self.index >= self.view.cardinality) return null;
                    defer self.index += 1;
                    return get16(self.view.bytes, header_bytes + self.index * 2);
                },
                .run => {
                    if (self.index >= get32(self.view.bytes, header_bytes)) return null;
                    const at = header_bytes + 4 + self.index * 4;
                    const value = @as(u32, get16(self.view.bytes, at)) + self.run_offset;
                    self.run_offset += 1;
                    if (self.run_offset > get16(self.view.bytes, at + 2)) {
                        self.index += 1;
                        self.run_offset = 0;
                    }
                    return @intCast(value);
                },
                .bitmap => {
                    while (self.word == 0) {
                        if (self.index == word_count) return null;
                        self.word = std.mem.readInt(u64, self.view.bytes[header_bytes + self.index * 8 ..][0..8], .little);
                        self.index += 1;
                    }
                    const value = (self.index - 1) * 64 + @ctz(self.word);
                    self.word &= self.word - 1;
                    return @intCast(value);
                },
            }
        }
    };

    pub fn iterator(self: View) Iterator {
        return .{ .view = self };
    }
};

test {
    _ = @import("container_test.zig");
}

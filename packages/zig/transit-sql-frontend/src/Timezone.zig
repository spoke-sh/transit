//! Content-bound TZif interpretation. All inputs are borrowed and immutable.
//! Loading validates once; conversion performs bounded binary searches without I/O.
const std = @import("std");
pub const max_zone_bytes = 128 * 1024;

pub const Version = struct {
    version_id: []const u8,
    digest: [32]u8,

    pub fn init(version_id: []const u8, digest: [32]u8) !Version {
        const result: Version = .{ .version_id = version_id, .digest = digest };
        try result.validate();
        return result;
    }
    pub fn validate(self: Version) !void {
        if (self.version_id.len == 0 or self.version_id.len > 64 or !std.unicode.utf8ValidateSlice(self.version_id) or std.mem.allEqual(u8, &self.digest, 0)) return error.InvalidTzdbVersion;
    }
    pub fn eql(a: Version, b: Version) bool {
        return std.mem.eql(u8, a.version_id, b.version_id) and std.mem.eql(u8, &a.digest, &b.digest);
    }
};

pub const Entry = struct { name: []const u8, tzif: []const u8 };
pub const Database = struct {
    version: Version,
    entries: []const Entry,

    /// Sorted exact zone names and complete TZif bytes form the identity.
    /// A version label alone never supplies rules or identifies their content.
    pub fn init(version_id: []const u8, entries: []const Entry) !Database {
        if (entries.len == 0) return error.EmptyTimezoneDatabase;
        var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
        hash.update("transit.tzdb.v1.2026-10-30\x00");
        hashBytes(&hash, version_id);
        for (entries, 0..) |entry, i| {
            if (entry.name.len == 0 or entry.name.len > 255 or !std.unicode.utf8ValidateSlice(entry.name)) return error.InvalidTimezoneName;
            if (i > 0 and std.mem.order(u8, entries[i - 1].name, entry.name) != .lt) return error.UnsortedTimezoneDatabase;
            _ = try Zone.init(entry.tzif);
            hashBytes(&hash, entry.name);
            hashBytes(&hash, entry.tzif);
        }
        return .{ .version = try Version.init(version_id, hash.finalResult()), .entries = entries };
    }
    pub fn requireVersion(self: Database, expected: Version) !void {
        try expected.validate();
        if (!self.version.eql(expected)) return error.TimezoneDefinitionMismatch;
    }
    pub fn utcToLocalMicros(self: Database, expected: Version, utc_micros: i64, name: []const u8) !i64 {
        try self.requireVersion(expected);
        var lo: usize = 0;
        var hi = self.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            switch (std.mem.order(u8, self.entries[mid].name, name)) {
                .lt => lo = mid + 1,
                .gt => hi = mid,
                .eq => {
                    // The immutable input was fully validated at database load.
                    const zone = try Zone.layout(self.entries[mid].tzif);
                    const offset = try zone.offsetSeconds(@divFloor(utc_micros, 1_000_000));
                    return std.math.add(i64, utc_micros, @as(i64, offset) * 1_000_000) catch error.TimestampOverflow;
                },
            }
        }
        return error.UnknownTimezone;
    }
    pub fn truncateLocalMicros(self: Database, expected: Version, utc_micros: i64, name: []const u8, bucket_micros: i64) !i64 {
        if (bucket_micros <= 0) return error.InvalidTimeBucket;
        const local = try self.utcToLocalMicros(expected, utc_micros, name);
        return std.math.mul(i64, @divFloor(local, bucket_micros), bucket_micros) catch error.TimestampOverflow;
    }
};
fn hashBytes(hash: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    var length: [8]u8 = undefined;
    std.mem.writeInt(u64, &length, bytes.len, .little);
    hash.update(&length);
    hash.update(bytes);
}
const Header = struct {
    standard: usize,
    universal: usize,
    leaps: usize,
    times: usize,
    types: usize,
    chars: usize,
    fn read(bytes: []const u8) !Header {
        if (bytes.len < 44 or !std.mem.eql(u8, bytes[0..4], "TZif") or (bytes[4] != '2' and bytes[4] != '3' and bytes[4] != '4')) return error.UnsupportedTimezoneFormat;
        if (!std.mem.allEqual(u8, bytes[5..20], 0)) return error.InvalidTimezoneData;
        const header: Header = .{
            .universal = std.mem.readInt(u32, bytes[20..24], .big),
            .standard = std.mem.readInt(u32, bytes[24..28], .big),
            .leaps = std.mem.readInt(u32, bytes[28..32], .big),
            .times = std.mem.readInt(u32, bytes[32..36], .big),
            .types = std.mem.readInt(u32, bytes[36..40], .big),
            .chars = std.mem.readInt(u32, bytes[40..44], .big),
        };
        if (header.types == 0 or header.types > 256 or header.times > max_zone_bytes / 9 or header.chars == 0 or header.chars > max_zone_bytes or
            (header.standard != 0 and header.standard != header.types) or (header.universal != 0 and header.universal != header.types)) return error.InvalidTimezoneData;
        if (header.leaps != 0) return error.LeapSecondTimezoneUnsupported;
        return header;
    }
    fn size(h: Header, width: usize) usize {
        return 44 + h.times * (width + 1) + h.types * 6 + h.chars + h.standard + h.universal;
    }
};
pub const Zone = struct {
    times: []const u8,
    indices: []const u8,
    types: []const u8,
    designations: []const u8,
    footer: []const u8,
    standard: []const u8,
    universal: []const u8,
    fn layout(bytes: []const u8) !Zone {
        if (bytes.len > max_zone_bytes) return error.TimezoneDataTooLarge;
        const first = try Header.read(bytes);
        const second_at = first.size(4);
        if (second_at > bytes.len) return error.InvalidTimezoneData;
        const h = try Header.read(bytes[second_at..]);
        if (bytes[4] != bytes[second_at + 4]) return error.InvalidTimezoneData;
        const end = second_at + h.size(8);
        if (end + 2 > bytes.len or bytes[end] != '\n' or bytes[bytes.len - 1] != '\n') return error.InvalidTimezoneData;
        const base = second_at + 44;
        const type_at = base + h.times * 9;
        const chars_at = type_at + h.types * 6;
        return .{ .times = bytes[base..][0 .. h.times * 8], .indices = bytes[base + h.times * 8 ..][0..h.times], .types = bytes[type_at..][0 .. h.types * 6], .designations = bytes[chars_at..][0..h.chars], .footer = bytes[end + 1 .. bytes.len - 1], .standard = bytes[chars_at + h.chars ..][0..h.standard], .universal = bytes[chars_at + h.chars + h.standard ..][0..h.universal] };
    }
    pub fn init(bytes: []const u8) !Zone {
        const zone = try layout(bytes);
        for (0..zone.indices.len) |i| {
            if (i > 0 and zone.transition(i) <= zone.transition(i - 1)) return error.InvalidTimezoneData;
            if (zone.indices[i] >= zone.types.len / 6) return error.InvalidTimezoneData;
        }
        for (0..zone.types.len / 6) |i| {
            const info = zone.types[i * 6 ..][0..6];
            const offset = std.mem.readInt(i32, info[0..4], .big);
            if (offset < -89999 or offset > 93599 or info[4] > 1 or info[5] >= zone.designations.len) return error.InvalidTimezoneData;
            if (std.mem.indexOfScalar(u8, zone.designations[info[5]..], 0) == null) return error.InvalidTimezoneData;
        }
        for (zone.standard) |flag| if (flag > 1) return error.InvalidTimezoneData;
        for (zone.universal, 0..) |flag, i| {
            if (flag > 1 or (flag == 1 and (zone.standard.len == 0 or zone.standard[i] == 0))) return error.InvalidTimezoneData;
        }
        for (zone.footer) |byte| if (byte < 0x20 or byte > 0x7e) return error.InvalidTimezoneData;
        return zone;
    }
    /// Only a fixed-offset POSIX footer can establish unlimited coverage in
    /// a file without transitions. DST rules require an implemented interpreter.
    fn fixedFooterOffset(footer: []const u8) !i32 {
        var end: usize = 0;
        if (footer.len > 0 and footer[0] == '<') {
            end = (std.mem.indexOfScalar(u8, footer, '>') orelse return error.TimezoneCoverageUnavailable) + 1;
            if (end < 5) return error.TimezoneCoverageUnavailable;
        } else {
            while (end < footer.len and std.ascii.isAlphabetic(footer[end])) : (end += 1) {}
            if (end < 3) return error.TimezoneCoverageUnavailable;
        }
        var offset = footer[end..];
        const negative = offset.len > 0 and offset[0] == '-';
        if (offset.len > 0 and (offset[0] == '-' or offset[0] == '+')) offset = offset[1..];
        var pieces = std.mem.splitScalar(u8, offset, ':');
        var seconds: i32 = 0;
        var count: usize = 0;
        while (pieces.next()) |piece| {
            if (count == 3 or piece.len == 0 or piece.len > 2) return error.TimezoneCoverageUnavailable;
            for (piece) |byte| if (!std.ascii.isDigit(byte)) return error.TimezoneCoverageUnavailable;
            const number = std.fmt.parseInt(i32, piece, 10) catch return error.TimezoneCoverageUnavailable;
            if (number > (if (count == 0) @as(i32, 24) else 59)) return error.TimezoneCoverageUnavailable;
            seconds += number * switch (count) {
                0 => @as(i32, 3600),
                1 => 60,
                else => 1,
            };
            count += 1;
        }
        return if (negative) seconds else -seconds;
    }
    fn transition(self: Zone, index: usize) i64 {
        return std.mem.readInt(i64, self.times[index * 8 ..][0..8], .big);
    }
    /// POSIX footer extrapolation is not implemented. A varying zone refuses
    /// times beyond its explicit transition coverage instead of freezing DST.
    pub fn offsetSeconds(self: Zone, seconds: i64) !i32 {
        const count = self.indices.len;
        if (count == 0 and self.types.len != 6) return error.TimezoneCoverageUnavailable;
        if (count > 0 and seconds > self.transition(count - 1)) return error.TimezoneCoverageUnavailable;
        var lo: usize = 0;
        var hi = count;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.transition(mid) <= seconds) lo = mid + 1 else hi = mid;
        }
        const index: usize = if (lo == 0) 0 else self.indices[lo - 1];
        const info = self.types[index * 6 ..][0..6];
        const name = self.designations[info[5]..];
        if (std.mem.startsWith(u8, name, "-00\x00")) return error.TimezoneCoverageUnavailable;
        const offset = std.mem.readInt(i32, info[0..4], .big);
        if (count == 0 and self.footer.len > 0 and try fixedFooterOffset(self.footer) != offset) return error.TimezoneCoverageUnavailable;
        return offset;
    }
};

test "timezone content pin controls exact DST conversion and unsupported coverage" {
    const t = std.testing;
    const entries = [_]Entry{
        .{ .name = "America/New_York", .tzif = @embedFile("timezone-fixtures/new-york.tzif") },
        .{ .name = "Etc/UTC", .tzif = @embedFile("timezone-fixtures/utc.tzif") },
    };
    const db = try Database.init("iana-2025b", &entries);
    const summer: i64 = 1751371200_000_000;
    try t.expectEqual(summer - 4 * 3600 * 1_000_000, try db.utcToLocalMicros(db.version, summer, "America/New_York"));
    const before: i64 = 1741503599_999_999;
    const after: i64 = 1741503600_000_000;
    try t.expectEqual(before - 5 * 3600 * 1_000_000, try db.utcToLocalMicros(db.version, before, "America/New_York"));
    try t.expectEqual(after - 4 * 3600 * 1_000_000, try db.utcToLocalMicros(db.version, after, "America/New_York"));
    try t.expectEqual(@as(i64, -1), try db.utcToLocalMicros(db.version, -1, "Etc/UTC"));
    try t.expectError(error.TimezoneDefinitionMismatch, db.utcToLocalMicros(try Version.init("iana-2025b", @splat(1)), summer, "America/New_York"));
    try t.expectError(error.UnknownTimezone, db.utcToLocalMicros(db.version, summer, "Unknown/Zone"));
    try t.expectError(error.TimezoneCoverageUnavailable, db.utcToLocalMicros(db.version, std.math.maxInt(i64), "America/New_York"));
    try t.expectError(error.TimestampOverflow, db.truncateLocalMicros(db.version, std.math.minInt(i64), "Etc/UTC", 3));
    const changed = try Database.init("iana-2025b", entries[1..]);
    try t.expect(!db.version.eql(changed.version));
    var broken: [entries[0].tzif.len]u8 = entries[0].tzif[0..].*;
    broken[0] = 'x';
    try t.expectError(error.UnsupportedTimezoneFormat, Zone.init(&broken));
}

test "timezone zero-transition files cannot invent fixed coverage from DST footers" {
    const utc = @embedFile("timezone-fixtures/utc.tzif");
    const footer_at = utc.len - "UTC0\n".len;
    const dynamic = utc[0..footer_at] ++ "UTC0DST,M3.2.0,M11.1.0\n";
    const zone = try Zone.init(dynamic);
    try std.testing.expectError(error.TimezoneCoverageUnavailable, zone.offsetSeconds(0));
    try std.testing.expectEqual(@as(i32, 19800), try Zone.fixedFooterOffset("<+0530>-5:30"));
    try std.testing.expectError(error.TimezoneCoverageUnavailable, Zone.fixedFooterOffset("UTC0junk"));
    try std.testing.expectError(error.TimezoneCoverageUnavailable, Zone.fixedFooterOffset("UTC0:60"));
}

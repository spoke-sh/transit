//! Immutable schema-owned TZif rules. Loading checks the complete selected
//! version/name/content digest once; row evaluation borrows the loaded rules.
const std = @import("std");
const tz = @import("Timezone.zig");
pub const Descriptor = struct {
    version: tz.Version,
    zone: []const u8,
    tzif: []const u8,

    pub fn init(version_id: []const u8, zone: []const u8, tzif: []const u8) !Descriptor {
        const database = try tz.Database.init(version_id, &.{.{ .name = zone, .tzif = tzif }});
        return .{ .version = database.version, .zone = zone, .tzif = tzif };
    }
    pub fn load(self: Descriptor) !Loaded {
        const expected = try init(self.version.version_id, self.zone, self.tzif);
        if (!self.version.eql(expected.version)) return error.TimezoneDefinitionMismatch;
        return .{ .version = self.version, .name = self.zone, .zone = try tz.Zone.init(self.tzif) };
    }
    pub fn validate(self: Descriptor) !void {
        _ = try self.load();
    }
    pub fn cloneInto(self: Descriptor, allocator: std.mem.Allocator) !Descriptor {
        try self.validate();
        return .{ .version = .{ .version_id = try allocator.dupe(u8, self.version.version_id), .digest = self.version.digest }, .zone = try allocator.dupe(u8, self.zone), .tzif = try allocator.dupe(u8, self.tzif) };
    }
};
pub const Fold = enum { reject, earlier, later };
pub const Loaded = struct {
    version: tz.Version,
    name: []const u8,
    zone: tz.Zone,

    pub fn utcToLocal(self: Loaded, utc_micros: i64) !i64 {
        const offset = try self.zone.offsetSeconds(@divFloor(utc_micros, 1_000_000));
        return std.math.add(i64, utc_micros, @as(i64, offset) * 1_000_000) catch error.TimestampOverflow;
    }
    /// Enumerate at most 256 TZif offset types, then verify each inverse against
    /// the exact transition table. Gaps and folds never silently choose a date.
    pub fn localToUtc(self: Loaded, local_micros: i64, fold: Fold) !i64 {
        var earliest: ?i64 = null;
        var latest: ?i64 = null;
        var incomplete = false;
        for (0..self.zone.types.len / 6) |i| {
            const offset = std.mem.readInt(i32, self.zone.types[i * 6 ..][0..4], .big);
            var duplicate = false;
            for (0..i) |j| if (std.mem.readInt(i32, self.zone.types[j * 6 ..][0..4], .big) == offset) {
                duplicate = true;
                break;
            };
            if (duplicate) continue;
            const candidate = std.math.sub(i64, local_micros, @as(i64, offset) * 1_000_000) catch return error.TimestampOverflow;
            const roundtrip = self.utcToLocal(candidate) catch |err| switch (err) {
                error.TimezoneCoverageUnavailable => {
                    incomplete = true;
                    continue;
                },
                else => return err,
            };
            if (roundtrip != local_micros) continue;
            earliest = if (earliest) |prior| @min(prior, candidate) else candidate;
            latest = if (latest) |prior| @max(prior, candidate) else candidate;
        }
        // A missing interval could contain another matching offset; do not
        // infer uniqueness or a gap from an incompletely interpreted artifact.
        if (incomplete) return error.TimezoneCoverageUnavailable;
        const first = earliest orelse return error.NonexistentLocalTime;
        if (first == latest.?) return first;
        return switch (fold) {
            .reject => error.AmbiguousLocalTime,
            .earlier => first,
            .later => latest.?,
        };
    }
    pub fn bucketLocal(self: Loaded, utc_micros: i64, width_micros: i64) !i64 {
        if (width_micros <= 0) return error.InvalidTimeBucket;
        const local = try self.utcToLocal(utc_micros);
        return std.math.mul(i64, @divFloor(local, width_micros), width_micros) catch error.TimestampOverflow;
    }
};

test "pinned timezone content distinguishes a DST gap a fold and incomplete coverage" {
    const t = std.testing;
    const pin = try Descriptor.init("iana-2025b", "America/New_York", @embedFile("timezone-fixtures/new-york.tzif"));
    const loaded = try pin.load();
    // Independent epoch coordinates: 2025-03-09 02:30 and 2025-11-02 01:30
    // represented as civil microseconds; these are a gap and a fold in NY.
    try t.expectError(error.NonexistentLocalTime, loaded.localToUtc(1741487400_000_000, .reject));
    const fold: i64 = 1762047000_000_000;
    try t.expectError(error.AmbiguousLocalTime, loaded.localToUtc(fold, .reject));
    try t.expectEqual(@as(i64, 1762061400_000_000), try loaded.localToUtc(fold, .earlier));
    try t.expectEqual(@as(i64, 1762065000_000_000), try loaded.localToUtc(fold, .later));
    var changed = pin;
    changed.version.digest[0] ^= 1;
    try t.expectError(error.TimezoneDefinitionMismatch, changed.load());
    try t.expectError(error.TimezoneCoverageUnavailable, loaded.utcToLocal(std.math.maxInt(i64)));
    const utc = try (try Descriptor.init("iana-2025b", "Etc/UTC", @embedFile("timezone-fixtures/utc.tzif"))).load();
    try t.expectEqual(@as(i64, -1), try utc.localToUtc(-1, .reject));
    try t.expectEqual(@as(i64, -1000000), try utc.bucketLocal(-1, 1000000));
}

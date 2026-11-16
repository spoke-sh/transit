//! Installed native storage boundary over an actual MinIO namespace. The driver
//! kills writers before their defers, then reopens the same durable owner.
const std = @import("std");
const storage = @import("transit_storage");
const backend = @import("transit_backend_local");
const t = std.testing;
const key = "table/tier-proof.tseg";
const content = "original accepted immutable segment";
fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn complete(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "tier-proof-complete\n");
    try io.sleep(.fromSeconds(30), .awake);
    return error.ExpectedProcessDeath;
}
pub fn run(init: std.process.Init, settings: storage.S3ObjectStore.Options, args: []const []const u8) !void {
    if (args.len != 4) return error.ExpectedNativeDirectory;
    const options: backend.Backend.ObjectStorage = .{ .endpoint = settings.endpoint, .region = settings.region, .bucket = settings.bucket, .prefix = settings.prefix, .credentials_file = settings.credentials_file, .ca_file = settings.ca_file, .allow_loopback_http = settings.allow_loopback_http, .request_timeout_ms = settings.request_timeout_ms, .cache_bytes = 32 * 1024 * 1024, .pending_objects = if (std.mem.eql(u8, args[2], "tier-outage")) 1 else 65536 };
    if (std.mem.eql(u8, args[2], "tier-disabled")) {
        try t.expectError(error.TierConfigurationRequired, backend.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), args[3], .{}));
        return complete(init.io);
    }
    var owner = try backend.Backend.openWithObjectStorage(init.gpa, init.io, std.Io.Dir.cwd(), args[3], .{}, options);
    defer owner.deinit();
    const tier = owner.objects.tier.?;
    const store = owner.objects.objectStore();
    const mode = args[2];
    const expected: storage.TransitObjectStore.ObjectMeta = .{ .size = content.len, .sha256 = hash(content) };
    if (std.mem.eql(u8, mode, "tier-write")) {
        try owner.put(key, content, false);
        try t.expectEqual(@as(u64, 1), (try tier.queue.current()).pending_objects);
        try t.expectEqual(@as(u64, content.len), (try tier.queue.current()).pending_bytes);
        // Disabling or changing a retained tier never creates another authority.
        try t.expectError(error.NativeStorageInUse, backend.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), args[3], .{}));
    } else if (std.mem.eql(u8, mode, "tier-drain")) {
        var iterations: usize = 0;
        while ((try tier.queue.current()).pending_objects > 0) : (iterations += 1) {
            if (iterations > 16) return error.UnboundedTierWork;
            try owner.tierStep();
        }
        try t.expectEqual(@as(u64, 0), (try tier.queue.current()).pending_bytes);
        try t.expectError(error.FileNotFound, owner.objects.local.objectStore().getObject(key, tier.upload_buffer));
        // Descriptor and trusted original identity survive eviction.
        try t.expectEqualDeep(expected, (try store.head(key)).?);
    } else if (std.mem.eql(u8, mode, "tier-read")) {
        var bytes: [128]u8 = undefined;
        try t.expectEqualDeep(expected, (try store.getObject(key, &bytes)).?);
        try t.expectEqualStrings(content, bytes[0..content.len]);
        try t.expectEqualStrings(content[3..12], try store.getRange(key, 3, 9, &bytes));
        try t.expect(tier.cache.hits > 0);
    } else if (std.mem.eql(u8, mode, "tier-cache-fill")) {
        const large = try init.gpa.alloc(u8, 17 * 1024 * 1024);
        defer init.gpa.free(large);
        @memset(large, 37);
        try owner.put("table/cache-a.tseg", large, false);
        @memset(large, 83);
        try owner.put("table/cache-b.tseg", large, false);
    } else if (std.mem.eql(u8, mode, "tier-cache-read")) {
        const large = try init.gpa.alloc(u8, 17 * 1024 * 1024);
        defer init.gpa.free(large);
        for ([_][]const u8{ "table/cache-a.tseg", "table/cache-b.tseg", "table/cache-a.tseg" }, [_]u8{ 37, 83, 37 }) |name, byte| {
            const meta = (try store.getObject(name, large)).?;
            try t.expectEqual(large.len, meta.size);
            try t.expect(std.mem.allEqual(u8, large, byte));
            try t.expect(tier.cache.used <= tier.options.cache_bytes);
        }
        try t.expect(tier.cache.evictions >= 2 and tier.cache.misses >= 3);
    } else if (std.mem.eql(u8, mode, "tier-recreate")) {
        _ = try owner.objects.reclaimImmutableObject(key, expected);
        // The delayed DELETE names the old generation even when its content is
        // recreated exactly before the background worker reaches it.
        try owner.put(key, content, false);
        try t.expectEqual(@as(u64, 2), (try tier.queue.current()).pending_objects);
    } else if (std.mem.eql(u8, mode, "tier-outage")) {
        // Credentials are deliberately unavailable: foreground durable staging
        // remains local while remote work fails with its original intent intact.
        try owner.put("table/offline.tseg", "offline accepted bytes", false);
        try t.expectError(error.UploadStagingQuota, owner.put("table/refused.tseg", "ordinary refused", false));
        try t.expect((try store.head("table/refused.tseg")) == null);
        // A pending-upload ceiling does not consume the native control reserve.
        // This path must stay local while provider credentials are unavailable.
        try owner.put("table/control.tseg", "control remains durable", true);
        const before = try tier.queue.current();
        try t.expectEqual(@as(u64, 2), before.pending_objects);
        if (owner.tierStep()) |_| return error.ExpectedProviderFailure else |_| {}
        try t.expectEqualDeep(before, try tier.queue.current());
        var bytes: [128]u8 = undefined;
        try t.expectEqualStrings("offline accepted bytes", try store.getRange("table/offline.tseg", 0, 22, &bytes));
        try t.expectEqualStrings("control remains durable", try store.getRange("table/control.tseg", 0, 23, &bytes));
    } else return error.InvalidTierMode;
    try complete(init.io);
}

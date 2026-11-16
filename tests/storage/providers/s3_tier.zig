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
    } else if (std.mem.eql(u8, mode, "tier-batch-write") or std.mem.eql(u8, mode, "tier-batch-read")) {
        var keys: [8][64]u8 = undefined;
        var values: [8][1024]u8 = undefined;
        var batch: [8]storage.TransitObjectStore.ImmutablePut = undefined;
        for (&keys, &values, &batch, 0..) |*name_buffer, *value, *item, i| {
            @memset(value, @intCast(i + 17));
            item.* = .{ .key = try std.fmt.bufPrint(name_buffer, "table/batch-{d}.tseg", .{i}), .bytes = value, .sha256 = hash(value) };
        }
        if (std.mem.eql(u8, mode, "tier-batch-write")) {
            var completed: [8]storage.TransitObjectStore.ObjectMeta = undefined;
            try owner.putBatch(&batch, &completed, false, true);
            const queued = try tier.queue.current();
            try t.expectEqual(@as(u64, 8), queued.pending_objects);
            try owner.putBatch(&batch, &completed, false, true);
            try t.expectEqualDeep(queued, try tier.queue.current());
        }
        // Check every staged generation before reopen can reconcile missing
        // metadata, then repeat from cold provider bytes in the next process.
        var out: [1024]u8 = undefined;
        for (batch) |item| {
            try t.expectEqualDeep(storage.TransitObjectStore.ObjectMeta{ .size = item.bytes.len, .sha256 = item.sha256 }, (try store.getObject(item.key, &out)).?);
            try t.expectEqualSlices(u8, item.bytes, &out);
        }
        if (std.mem.eql(u8, mode, "tier-batch-read")) {
            try t.expectEqual(@as(u64, 8), tier.cache.misses);
            const hits = tier.cache.hits;
            for (batch) |item| {
                _ = (try store.getObject(item.key, &out)).?;
                try t.expectEqualSlices(u8, item.bytes, &out);
            }
            try t.expectEqual(@as(u64, 8), tier.cache.misses);
            try t.expectEqual(hits + 8, tier.cache.hits);
        }
    } else if (std.mem.eql(u8, mode, "tier-cache-fill")) {
        const half = 17 * 1024 * 1024;
        const large = try init.gpa.alloc(u8, 2 * half);
        defer init.gpa.free(large);
        @memset(large[0..half], 37);
        @memset(large[half..], 83);
        const batch = [_]storage.TransitObjectStore.ImmutablePut{
            .{ .key = "table/cache-a.tseg", .bytes = large[0..half], .sha256 = hash(large[0..half]) },
            .{ .key = "table/cache-b.tseg", .bytes = large[half..], .sha256 = hash(large[half..]) },
        };
        var completed: [2]storage.TransitObjectStore.ObjectMeta = undefined;
        try owner.putBatch(&batch, &completed, false, true);
        const original = try tier.queue.current();
        try t.expectEqual(@as(u64, 2), original.pending_objects);
        try t.expectEqual(@as(u64, 2 * half), original.pending_bytes);
        try owner.putBatch(&batch, &completed, false, true);
        try t.expectEqualDeep(original, try tier.queue.current());
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
        const pending = (try tier.queue.current()).pending_objects;
        _ = try owner.objects.reclaimImmutableObject(key, expected);
        // Retirement names the old generation even when its content is
        // recreated exactly before the background worker reaches it.
        try owner.put(key, content, false);
        try t.expectEqual(pending + 2, (try tier.queue.current()).pending_objects);
    } else if (std.mem.eql(u8, mode, "tier-retired")) {
        var name: [96]u8 = undefined;
        const remote = try std.fmt.bufPrint(&name, "objects/{s}/0000000000000000", .{std.fmt.bytesToHex(hash(key), .lower)});
        const raw = tier.remote.objectStore();
        var bytes: [128]u8 = undefined;
        try t.expect(try raw.head(remote) == null);
        try t.expect(try raw.getObject(remote, &bytes) == null);
        try t.expectError(error.ObjectNotFound, raw.getRange(remote, 0, 1, &bytes));
        try t.expectError(error.ImmutableObjectConflict, raw.putImmutable(remote, content, expected.sha256));
        try tier.remote.retireImmutable(remote, expected);
        var reader = try storage.S3ObjectStore.S3ObjectStore.initReadOnly(init.gpa, init.io, settings);
        defer reader.deinit();
        try t.expectError(error.ReadOnlyObjectStore, reader.retireImmutable(remote, expected));
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

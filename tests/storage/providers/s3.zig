//! Real provider conformance; invoked only with an owned remote namespace.
const std = @import("std");
const storage = @import("transit_storage");
const s3 = storage.S3ObjectStore;
const check = std.testing;
fn hash(bytes: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &out, .{});
    return out;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 3) return error.ExpectedConfigurationAndMode;
    const raw = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16384));
    defer init.gpa.free(raw);
    const parsed = try std.json.parseFromSlice(s3.Options, init.gpa, raw, .{});
    defer parsed.deinit();
    if (std.mem.startsWith(u8, args[2], "tier-")) return @import("s3_tier.zig").run(init, parsed.value, args);
    var provider = try s3.S3ObjectStore.init(init.gpa, init.io, parsed.value);
    defer provider.deinit();
    const store = provider.objectStore();
    const mode = args[2];
    if (std.mem.eql(u8, mode, "write")) {
        try check.expect((try store.head("missing")) == null);
        var payload: [s3.chunk_bytes * 2 + 17]u8 = undefined;
        for (&payload, 0..) |*value, i| value.* = @truncate(i * 37 + 13);
        const expected = hash(&payload);
        const meta = try store.putImmutable("proof/data.tseg", &payload, expected);
        try check.expectEqual(payload.len, meta.size);
        const retried = try store.putImmutable("proof/data.tseg", &payload, expected);
        try check.expectEqualDeep(meta, retried);
        try check.expectError(error.ImmutableObjectConflict, store.putImmutable("proof/data.tseg", "different", hash("different")));
        try check.expectError(error.ImmutableObjectConflict, store.putConditional("proof/data.tseg", .{ .if_match = expected }, "different"));
        try check.expect(try store.putConditional("proof/manifest", .if_none_match, "original"));
        try check.expect(!try store.putConditional("proof/manifest", .if_none_match, "duplicate"));
        try check.expect(!try store.putConditional("proof/manifest", .{ .if_match = hash("wrong") }, "wrong"));
        try check.expect(try store.putConditional("proof/manifest", .{ .if_match = hash("original") }, "replacement"));
        var out: [s3.chunk_bytes * 2 + 17]u8 = undefined;
        try check.expectEqualDeep(meta, (try store.getObject("proof/data.tseg", &out)).?);
        try check.expectEqualSlices(u8, &payload, &out);
        const range = try store.getRange("proof/data.tseg", s3.chunk_bytes - 3, 23, &out);
        try check.expectEqualSlices(u8, payload[s3.chunk_bytes - 3 ..][0..23], range);
        try check.expectEqualSlices(u8, payload[payload.len - 1 ..], try store.getRange("proof/data.tseg", payload.len - 1, 2, &out));
        try check.expectError(error.RangeOutOfBounds, store.getRange("proof/data.tseg", payload.len + 1, 1, &out));
        try check.expectEqual(@as(usize, 0), (try store.getRange("proof/data.tseg", payload.len, 0, &out)).len);
        _ = try store.putImmutable("proof/empty", "", hash(""));
        try check.expectEqual(@as(u64, 0), (try store.getObject("proof/empty", &out)).?.size);
        try check.expect(try store.putConditional("proof/race", .if_none_match, "original"));
    } else if (std.mem.eql(u8, mode, "put")) {
        _ = try store.putImmutable("proof/lost", "original accepted content", hash("original accepted content"));
    } else if (std.mem.eql(u8, mode, "rotation")) {
        const credentials = try std.Io.Dir.cwd().readFileAlloc(init.io, parsed.value.credentials_file, init.gpa, .limited(16384));
        defer {
            std.crypto.secureZero(u8, credentials);
            init.gpa.free(credentials);
        }
        defer std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = parsed.value.credentials_file, .data = credentials }) catch @panic("credential fixture restore failed");
        try check.expect((try store.head("proof/manifest")) != null);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = parsed.value.credentials_file, .data = "{}" });
        try check.expectError(error.MissingField, store.head("proof/manifest"));
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = parsed.value.credentials_file, .data = credentials });
        try check.expect((try store.head("proof/manifest")) != null);
    } else if (std.mem.eql(u8, mode, "race")) {
        if (args.len != 4) return error.ExpectedCandidate;
        const result = store.putConditional("proof/race", .{ .if_match = hash("original") }, args[3]) catch |err| switch (err) {
            error.ObjectConditionalConflict => false,
            else => return err,
        };
        if (!result) std.process.exit(2);
    } else if (std.mem.eql(u8, mode, "read")) {
        var out: [s3.chunk_bytes * 2 + 17]u8 = undefined;
        const meta = (try store.getObject("proof/data.tseg", &out)) orelse return error.ObjectNotFound;
        try check.expectEqual(out.len, meta.size);
        for (out, 0..) |value, i| try check.expectEqual(@as(u8, @truncate(i * 37 + 13)), value);
        const manifest = try store.getRange("proof/manifest", 0, "replacement".len, &out);
        try check.expectEqualStrings("replacement", manifest);
    } else if (std.mem.eql(u8, mode, "corrupt")) {
        var out: [s3.chunk_bytes * 2 + 17]u8 = undefined;
        try check.expectError(error.ObjectDigestMismatch, store.getObject("proof/data.tseg", &out));
    } else if (std.mem.eql(u8, mode, "denied")) {
        try check.expectError(error.ObjectAccessDenied, store.head("proof/data.tseg"));
    } else if (std.mem.eql(u8, mode, "timeout")) {
        try check.expectError(error.ObjectRequestTimeout, store.head("proof/data.tseg"));
    } else if (std.mem.eql(u8, mode, "delete")) {
        for ([_][]const u8{ "proof/data.tseg", "proof/manifest", "proof/empty", "proof/race", "proof/lost" }) |key| {
            try store.delete(key);
            try store.delete(key);
            try check.expect((try store.head(key)) == null);
        }
    } else return error.InvalidMode;
}

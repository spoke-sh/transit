//! Subprocess driver for the real local object-store publication proof.
const std = @import("std");
const storage = @import("transit_storage");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 6) return error.InvalidArguments;
    var owner = try storage.LocalSegmentStore.LocalSegmentStore.openDisk(init.gpa, init.io, args[1]);
    defer owner.deinit();
    const store = owner.objectStore();
    const mode = args[2];
    const key = args[3];
    var output: [512]u8 = undefined;
    const bytes = if (std.mem.eql(u8, mode, "read")) blk: {
        var value: [128]u8 = @splat(0);
        const read = try store.getRange(key, 0, value.len, &value);
        break :blk try std.fmt.bufPrint(&output, "{{\"hex\":\"{s}\"}}\n", .{std.fmt.bytesToHex(value, .lower)[0 .. read.len * 2]});
    } else blk: {
        const accepted = if (std.mem.eql(u8, mode, "immutable")) acceptance: {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(args[5], &digest, .{});
            _ = store.putImmutable(key, args[5], digest) catch |err| switch (err) {
                error.ImmutableObjectConflict => break :acceptance false,
                else => return err,
            };
            break :acceptance true;
        } else if (std.mem.eql(u8, mode, "create"))
            try store.putConditional(key, .if_none_match, args[5])
        else if (std.mem.eql(u8, mode, "replace")) matched: {
            var expected: [32]u8 = undefined;
            if ((try std.fmt.hexToBytes(&expected, args[4])).len != expected.len) return error.InvalidDigest;
            break :matched try store.putConditional(key, .{ .if_match = expected }, args[5]);
        } else return error.InvalidArguments;
        break :blk try std.fmt.bufPrint(&output, "{{\"accepted\":{s}}}\n", .{if (accepted) "true" else "false"});
    };
    try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
}

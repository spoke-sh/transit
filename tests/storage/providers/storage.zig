//! Native log and signed semantic proofs over the exclusive local disk owner.
const std = @import("std");
const storage = @import("transit_storage");
const disk = @import("fixture_native_disk");
const check = std.testing;

pub fn main(init: std.process.Init) !void {
    const raw_args = try init.minimal.args.toSlice(init.arena.allocator());
    if (raw_args.len == 4 and !std.mem.eql(u8, raw_args[1], "storage")) {
        inline for (.{
            .{ "kernel", @import("proof_kernel") },
            .{ "effects", @import("proof_effects") },
            .{ "lifetime", @import("proof_lifetime") },
            .{ "outbox", @import("proof_outbox") },
            .{ "runtime", @import("proof_runtime") },
            .{ "deletion", @import("proof_deletion") },
            .{ "state", @import("proof_state") },
            .{ "readiness", @import("proof_readiness") },
        }) |entry| {
            if (std.mem.eql(u8, raw_args[1], entry[0])) return entry[1].main(init);
        }
        return error.UnknownProof;
    }
    const args = if (raw_args.len == 4) raw_args[1..] else raw_args;
    if (args.len != 3) return error.ExpectedDirectoryAndPhase;
    const path = try std.fs.path.join(init.gpa, &.{ args[1], "journal" });
    defer init.gpa.free(path);
    var owner = try storage.LocalWal.LocalWal.openDisk(init.gpa, init.io, path);
    defer owner.deinit();
    const log = owner.log();
    if (std.mem.eql(u8, args[2], "write")) {
        try check.expectEqual(@as(u64, 0), try log.tail(0));
        _ = try log.append(0, 0, 1, 1, .process_turn, "winner");
        try check.expectError(error.WalLsnConflict, log.append(0, 0, 1, 1, .process_turn, "loser"));
        _ = try log.append(0, 1, 1, 1, .process_turn, "uncertain");
        try check.expectError(error.WalLsnConflict, log.append(0, 1, 1, 1, .process_turn, "uncertain"));
        for (2..40) |i| {
            var value: [32]u8 = undefined;
            _ = try log.append(0, i, 1, 1, .process_turn, try std.fmt.bufPrint(&value, "value-{d}", .{i}));
        }
    } else if (std.mem.eql(u8, args[2], "recover") or std.mem.eql(u8, args[2], "checkpoint") or std.mem.eql(u8, args[2], "trim_recover")) {
        try check.expectEqual(@as(u64, 40), try log.tail(0));
        try check.expectError(error.WalLsnConflict, log.append(0, 0, 1, 1, .process_turn, "stale"));
        var at: u64 = 0;
        while (at < 40) {
            var batch = try log.read(init.gpa, 0, at, 1);
            defer batch.deinit();
            try check.expectEqual(@as(usize, 1), batch.frames.len);
            const frame = batch.frames[0];
            try check.expectEqual(at, frame.header.lsn);
            var value: [32]u8 = undefined;
            const expected = if (at == 0) "winner" else if (at == 1) "uncertain" else try std.fmt.bufPrint(&value, "value-{d}", .{at});
            try check.expectEqualStrings(expected, frame.payload);
            at += 1;
        }
    } else return error.UnknownPhase;
    try disk.completed(init.io);
}

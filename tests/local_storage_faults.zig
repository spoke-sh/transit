//! Real disk operations stopped at selected I/O boundaries for an external
//! SIGKILL. The parent owns the oracle; no production fault hook is involved.
const std = @import("std");
const storage = @import("transit_storage");
const Wal = storage.LocalWal.LocalWal;

const Fault = struct {
    var real: std.Io = undefined;
    var point: []const u8 = "none";
    var sync_count: usize = 0;
    var delete_count: usize = 0;

    fn stop() noreturn {
        std.Io.File.stdout().writeStreamingAll(real, "{\"stopped\":true}\n") catch std.process.exit(91);
        // A private pipe keeps this exact boundary held until the parent kills
        // the process. EOF or a byte is a failed harness, never a crash pass.
        var buffer: [1]u8 = undefined;
        var reader = std.Io.File.stdin().reader(real, &buffer);
        _ = reader.interface.takeByte() catch std.process.exit(92);
        std.process.exit(93);
    }
    fn numbered(prefix: []const u8, count: usize) bool {
        var bytes: [32]u8 = undefined;
        return std.mem.eql(u8, point, std.fmt.bufPrint(&bytes, "{s}-{d}", .{ prefix, count }) catch unreachable);
    }
    fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        try real.vtable.fileSync(context, file);
        sync_count += 1;
        if (numbered("sync", sync_count)) stop();
    }
    fn write(context: ?*anyopaque, file: std.Io.File, header: []const u8, data: []const []const u8, splat: usize, offset: u64) std.Io.File.WritePositionalError!usize {
        if (std.mem.eql(u8, point, "write")) {
            std.debug.assert(header.len == 0 and data.len == 1 and splat == 1 and data[0].len > 13);
            try file.writePositionalAll(real, data[0][0..13], offset);
            stop();
        }
        return real.vtable.fileWritePositional(context, file, header, data, splat, offset);
    }
    fn rename(context: ?*anyopaque, old: std.Io.Dir, from: []const u8, new: std.Io.Dir, to: []const u8) std.Io.Dir.RenameError!void {
        try real.vtable.dirRename(context, old, from, new, to);
        if (std.mem.eql(u8, point, "publish")) stop();
    }
    fn delete(context: ?*anyopaque, dir: std.Io.Dir, name: []const u8) std.Io.Dir.DeleteFileError!void {
        try real.vtable.dirDeleteFile(context, dir, name);
        // Atomic-file housekeeping is not a retained WAL segment deletion.
        if (std.mem.endsWith(u8, name, ".twal")) {
            delete_count += 1;
            if (numbered("delete", delete_count)) stop();
        }
    }
    fn arm(selected: []const u8) void {
        point = selected;
        sync_count = 0;
        delete_count = 0;
    }
    fn acknowledged() void {
        if (std.mem.eql(u8, point, "ack")) stop();
        std.debug.assert(std.mem.eql(u8, point, "none"));
    }
};

fn emit(init: std.process.Init, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn digest(bytes: []const u8) [32]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return hash;
}

fn wal(init: std.process.Init, io: std.Io, directory: []const u8, operation: []const u8, point: []const u8) !void {
    var owner = Wal.openDiskWithOptions(init.gpa, io, .cwd(), directory, .{
        .segment_bytes = storage.TransitLog.alignedFrameSize(1),
        .batch_frames = 8,
    }) catch |err| {
        if (std.mem.eql(u8, operation, "locked") and err == error.WalInUse) return emit(init, .{ .locked = true });
        return err;
    };
    defer owner.deinit();
    if (std.mem.eql(u8, operation, "locked")) return error.MissingExclusiveLock;
    const log = owner.log();
    const tail = try log.tail(17);
    if (std.mem.eql(u8, operation, "init")) {
        for ([_][]const u8{ "accepted-0", "accepted-1", "accepted-2" }, 0..) |payload, lsn| {
            const receipt = try log.append(17, lsn, 3, 5, .row_delta, payload);
            if (receipt.lsn != lsn) return error.WrongReceipt;
        }
        return emit(init, .{ .tail = try log.tail(17) });
    }
    if (std.mem.eql(u8, operation, "inspect")) {
        const floor = try std.fmt.parseInt(u64, point, 10);
        var batch = try log.read(init.gpa, 17, floor, 8);
        defer batch.deinit();
        const Row = struct { lsn: u64, writer: u64, policy: u64, payload: []const u8 };
        var rows: [8]Row = undefined;
        for (batch.frames, rows[0..batch.frames.len]) |frame, *row| row.* = .{
            .lsn = frame.header.lsn,
            .writer = frame.header.writer_epoch,
            .policy = frame.header.policy_epoch,
            .payload = frame.payload,
        };
        if (floor != 0) {
            var forbidden = log.read(init.gpa, 17, floor - 1, 1) catch |err| {
                if (err != error.WalHistoryTrimmed) return err;
                return emit(init, .{ .tail = tail, .rows = rows[0..batch.frames.len], .trimmed = true });
            };
            forbidden.deinit();
            return error.TrimFloorNotEnforced;
        }
        return emit(init, .{ .tail = tail, .rows = rows[0..batch.frames.len], .trimmed = false });
    }
    if (std.mem.eql(u8, operation, "stale")) {
        _ = log.append(17, tail, 3, 5, .row_delta, "forbidden") catch |err| {
            if (err != error.StaleWriterEpoch) return err;
            _ = log.append(17, tail, 7, 5, .row_delta, "forbidden") catch |policy_err| {
                if (policy_err != error.StalePolicyEpoch) return policy_err;
                return emit(init, .{ .fenced = true });
            };
            return error.PolicyFenceNotEnforced;
        };
        return error.WriterFenceNotEnforced;
    }
    Fault.arm(point);
    if (std.mem.eql(u8, operation, "append")) {
        _ = try log.append(17, tail, 3, 5, .row_delta, "uncertain");
    } else if (std.mem.eql(u8, operation, "advance")) {
        _ = try log.append(17, tail, 7, 9, .row_delta, "successor");
    } else if (std.mem.eql(u8, operation, "fence")) {
        try log.fence(17, 7, 9);
    } else if (std.mem.eql(u8, operation, "trim")) {
        try log.trim(17, 2);
    } else if (std.mem.eql(u8, operation, "trim-all")) {
        try log.trim(17, 3);
    } else return error.InvalidArguments;
    Fault.acknowledged();
    try emit(init, .{ .tail = try log.tail(17) });
}

fn objects(init: std.process.Init, io: std.Io, directory: []const u8, operation: []const u8, point: []const u8) !void {
    var owner = try storage.LocalSegmentStore.LocalSegmentStore.openDisk(init.gpa, io, directory);
    defer owner.deinit();
    const store = owner.objectStore();
    if (std.mem.eql(u8, operation, "init")) {
        if (!try store.putConditional("head", .if_none_match, "before")) return error.WrongCondition;
        return emit(init, .{ .initialized = true });
    }
    if (std.mem.eql(u8, operation, "inspect")) {
        const meta = try store.head(point);
        var bytes: [32]u8 = undefined;
        const value = if (meta != null) try store.getRange(point, 0, bytes.len, &bytes) else null;
        return emit(init, .{ .value = value, .meta = meta });
    }
    Fault.arm(point);
    if (std.mem.eql(u8, operation, "replace")) {
        const accepted = try store.putConditional("head", .{ .if_match = digest("before") }, "after");
        Fault.acknowledged();
        return emit(init, .{ .accepted = accepted });
    }
    if (std.mem.eql(u8, operation, "immutable")) {
        _ = try store.putImmutable("new.tseg", "immutable", digest("immutable"));
        Fault.acknowledged();
        return emit(init, .{ .accepted = true });
    }
    if (std.mem.eql(u8, operation, "conflict")) {
        _ = store.putImmutable("new.tseg", "conflict", digest("conflict")) catch |err| {
            if (err != error.ImmutableObjectConflict) return err;
            return emit(init, .{ .conflict = true });
        };
        return error.ImmutableIdentityNotEnforced;
    }
    return error.InvalidArguments;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.InvalidArguments;
    Fault.real = init.io;
    var vtable = init.io.vtable.*;
    vtable.fileSync = Fault.sync;
    vtable.fileWritePositional = Fault.write;
    vtable.dirRename = Fault.rename;
    vtable.dirDeleteFile = Fault.delete;
    var io = init.io;
    io.vtable = &vtable;
    const split = std.mem.indexOfScalar(u8, args[2], '-') orelse return error.InvalidArguments;
    const kind = args[2][0..split];
    const operation = args[2][split + 1 ..];
    if (std.mem.eql(u8, kind, "wal")) return wal(init, io, args[1], operation, args[3]);
    if (std.mem.eql(u8, kind, "objects")) return objects(init, io, args[1], operation, args[3]);
    return error.InvalidArguments;
}

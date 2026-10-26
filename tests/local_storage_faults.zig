//! Real disk operations stopped at selected I/O boundaries for an external
//! SIGKILL. The parent owns the oracle; no production fault hook is involved.
const std = @import("std");
const storage = @import("transit_storage");
const Wal = storage.LocalWal.LocalWal;
const p = @import("transit_protocol");
const f = @import("transit_fuze");

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

const TableAccess = struct {
    calls: usize = 0,
    fn acquire(context: *anyopaque) !storage.TablePartition.Guard.Fence {
        const self: *TableAccess = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (self.calls == 2) {
            if (std.mem.eql(u8, Fault.point, "before-accept")) Fault.stop();
            if (std.mem.startsWith(u8, Fault.point, "accept-")) Fault.arm(Fault.point[7..]);
        }
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *TableAccess) storage.TablePartition.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};

fn table(init: std.process.Init, io: std.Io, directory: []const u8, operation: []const u8, point: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, directory);
    const dir = try std.Io.Dir.cwd().openDir(io, directory, .{});
    defer dir.close(io);
    var log = try Wal.openDiskWithOptions(init.gpa, io, dir, "wal", .{ .segment_bytes = storage.TransitLog.alignedFrameSize(1) });
    defer log.deinit();
    var store = try storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(init.gpa, io, dir, "objects");
    defer store.deinit();
    const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    var owner = try storage.TablePartition.init(init.gpa, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, log.log(), store.objectStore(), .{ .resident_pages = 1 });
    defer owner.deinit();
    try owner.recover();
    var access: TableAccess = .{};
    const first: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = 1 }, .target = object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(7) };
    const pin_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 100 };
    if (std.mem.eql(u8, operation, "init") or std.mem.eql(u8, operation, "compact-init")) {
        const ingestion: storage.TablePartition.Ingestion = if (std.mem.eql(u8, operation, "compact-init")) .bulk else .point;
        _ = try owner.apply(first, &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 1 } } }} } } }}, ingestion, access.guard());
        _ = try owner.pin(pin_owner, .{ .partition = 17, .next_lsn = 1 }, access.guard());
        var second = first;
        second.identity.operation = 2;
        second.action = .insert;
        second.expected_definition = owner.root.interpretation;
        _ = try owner.apply(second, &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 2 } } }} } } }}, ingestion, access.guard());
        return emit(init, .{ .tail = owner.root.next_lsn });
    }
    if (std.mem.eql(u8, operation, "inspect") or std.mem.eql(u8, operation, "compact-inspect")) {
        const receipt = (try owner.observe(first, access.guard())).?;
        const pin = (try owner.pinState(pin_owner, access.guard())).handle.?;
        var page = try owner.scanSnapshot(init.gpa, pin, null, .{}, access.guard());
        defer page.deinit();
        if (page.count != 1 or page.next != null) return error.WrongSnapshot;
        const history = try owner.history(.{ .partition = 17, .next_lsn = 0 }, .{ .partition = 17, .next_lsn = 3 }, 3, access.guard());
        if (history.count != 2 or history.entries[0].?.receipt.binding.identity.operation != 1 or history.entries[1].?.receipt.binding.identity.operation != 2) return error.WrongHistory;
        var current: [2]i128 = undefined;
        for (&current, 1..) |*value, id| {
            var bytes: [4096]u8 = undefined;
            const key = try f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = id } } }}, false, &bytes);
            var row = (try owner.get(init.gpa, key, access.guard())) orelse return error.MissingRow;
            defer row.deinit();
            value.* = row.row().cells[0].value.atom.signed;
        }
        return emit(init, .{ .archived = owner.root.archive.through, .tail = owner.root.next_lsn, .rows = owner.root.live_rows, .pinned = page.rows[0].?.row().cells[0].value.atom.signed, .receipt = receipt.position.next_lsn, .history = history.count, .current = current, .next_segment = owner.root.next_segment });
    }
    access.calls = 0;
    Fault.arm(point);
    if (std.mem.eql(u8, operation, "compact")) {
        const result = try owner.compact(3, .{}, access.guard());
        Fault.acknowledged();
        return emit(init, .{ .next_segment = owner.root.next_segment, .rows = result.rows });
    } else if (std.mem.eql(u8, operation, "archive")) {
        _ = try owner.archive(.{ .partition = 17, .next_lsn = 3 }, .{ .frames = 1 }, access.guard());
    } else if (std.mem.eql(u8, operation, "archive-all")) {
        while (!(try owner.archive(.{ .partition = 17, .next_lsn = 3 }, .{ .frames = 1 }, access.guard())).complete) {}
    } else if (std.mem.eql(u8, operation, "trim")) {
        _ = try owner.trimArchived(access.guard());
    } else return error.InvalidArguments;
    Fault.acknowledged();
    return emit(init, .{ .archived = owner.root.archive.through });
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
    if (std.mem.eql(u8, kind, "table")) return table(init, io, args[1], operation, args[3]);
    return error.InvalidArguments;
}

//! Parent-controlled SIGKILL boundaries in real local native collection.
const std = @import("std");
const core = @import("transit_core");
const local = @import("transit_backend_local");
const catalog = @import("transit_catalog");
const storage = catalog.storage;
const g = core.protocol.Growth;
const Engine = core.growing.Engine(local.Store, local.PageStore);
const Fault = struct {
    var real: std.Io = undefined;
    var point: []const u8 = "none";
    var syncs: usize = 0;
    var deletes: usize = 0;
    fn stop() noreturn {
        std.Io.File.stdout().writeStreamingAll(real, "{\"stopped\":true}\n") catch std.process.exit(91);
        var bytes: [1]u8 = undefined;
        var reader = std.Io.File.stdin().reader(real, &bytes);
        _ = reader.interface.takeByte() catch std.process.exit(92);
        std.process.exit(93);
    }
    fn selected(prefix: []const u8, n: usize) bool {
        var bytes: [32]u8 = undefined;
        return std.mem.eql(u8, point, std.fmt.bufPrint(&bytes, "{s}-{d}", .{ prefix, n }) catch unreachable);
    }
    fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        try real.vtable.fileSync(context, file);
        syncs += 1;
        if (selected("sync", syncs)) stop();
    }
    fn delete(context: ?*anyopaque, dir: std.Io.Dir, name: []const u8) std.Io.Dir.DeleteFileError!void {
        try real.vtable.dirDeleteFile(context, dir, name);
        const basename = std.fs.path.basename(name);
        if (basename.len == 64 or basename.len == 83 or std.mem.endsWith(u8, name, ".data") or std.mem.endsWith(u8, name, ".tseg") or std.mem.endsWith(u8, name, ".checks")) {
            deletes += 1;
            if (selected("delete", deletes)) stop();
        }
    }
    fn rename(context: ?*anyopaque, old: std.Io.Dir, from: []const u8, new: std.Io.Dir, to: []const u8) std.Io.Dir.RenameError!void {
        try real.vtable.dirRename(context, old, from, new, to);
        if (std.mem.eql(u8, point, "publish")) stop();
        if (std.mem.eql(u8, point, "state") and (std.mem.eql(u8, to, ".native-collection") or std.mem.eql(u8, to, ".data-collection"))) stop();
    }
};
fn key() !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(17));
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try key()));
}
fn clock(raw: *anyopaque) anyerror!core.Time.Sample {
    return .{ .unix_ms = @as(*u64, @ptrCast(@alignCast(raw))).* };
}
fn emit(init: std.process.Init, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 4) return run(init, args, false);
    if (args.len == 5 and std.mem.eql(u8, args[4], "direct")) return run(init, args, true);
    return error.InvalidArguments;
}
fn run(init: std.process.Init, args: []const []const u8, comptime direct: bool) !void {
    Fault.real = init.io;
    var vtable = init.io.vtable.*;
    vtable.fileSync = Fault.sync;
    vtable.dirDeleteFile = Fault.delete;
    vtable.dirRename = Fault.rename;
    var io = init.io;
    io.vtable = &vtable;
    var owner = try local.Backend.open(init.gpa, io, .cwd(), args[1], .{});
    defer owner.deinit();
    var pages = try local.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: local.Store = .{ .backend = &owner };
    const initialize = std.mem.eql(u8, args[2], "init");
    const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = (try key()).public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true };
    var engine = if (initialize) try Engine.bootstrap(&journal, &pages, genesis) else try Engine.open(&journal, &pages, genesis);
    var now: u64 = @max(100, engine.head.time_floor_ms);
    engine.clock = .{ .context = &now, .read = clock };
    var collector: if (direct) local.DataCollection.Collector(catalog.DirectStorageGraph) else local.StorageCollection = .{ .backend = &owner };
    var data: local.DataStore = .{ .backend = &owner };
    var table = if (direct) try storage.TablePartition.init(init.gpa, 17, .{
        .object = .{ .scope = .{ .realm = 42, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 },
        .revision = 1,
        .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} },
        .properties = "",
    }, data.log(), data.objects(), .{ .resident_pages = 1 }) else {};
    defer if (direct) table.deinit();
    const Access = struct {
        fn acquire(raw: *anyopaque) !storage.TablePartition.Guard.Fence {
            const native: *Engine = @ptrCast(@alignCast(raw));
            return .{ .writer_epoch = native.head.storage_epoch, .policy_epoch = native.head.authorization.revision + 1 };
        }
        fn release(_: *anyopaque) void {}
    };
    const guard: storage.TablePartition.Guard = .{ .context = &engine, .acquire = Access.acquire, .release = Access.release };
    const binding: core.protocol.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = .{ .realm = 42, .resource = 2, .catalog = 3 }, .principal = 4, .operation = 1 }, .target = .{ .scope = .{ .realm = 42, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(7) };
    if (direct) try table.recover();
    if (initialize) {
        if (try submit(&engine, .{ .spawn = .{} }) != 1) return error.WrongProcess;
        try owner.put("table/untouched.data", "independent owner bytes", false);
        const orphan = if (direct) blk: {
            _ = try table.apply(binding, &.{}, .point, guard);
            try owner.put("table-segments/unaccepted.tseg", "unaccepted bytes", false);
            break :blk "table-segments/unaccepted.tseg";
        } else blk: {
            try pages.begin(engine.head.storage_epoch, false);
            const staged = try pages.stageBlock(try core.protocol.Blocks.Spec.of("unaccepted bytes"), "unaccepted bytes");
            try pages.finish();
            break :blk staged;
        };
        const activity = if (direct) (try owner.data_allocations.current()).source_activity else (try owner.allocations.current()).source_activity;
        const fence = try submit(&engine, .{ .storage_fence = {} });
        try collector.startAtActivity(&engine, fence, activity);
        for (0..2000) |_| {
            if ((try collector.current()).?.phase == .wait) break;
            if (!try collector.step(&engine, .{ .unix_ms = now })) return error.UnexpectedWait;
        } else return error.FixtureBudget;
        now = (try collector.current()).?.grace_until_ms + 1;
        _ = try submit(&engine, .{ .storage_fence = {} });
        for (0..2000) |_| {
            const state = (try collector.current()).?;
            if (state.pending) |pending| {
                const matches = if (direct) std.mem.eql(u8, pending.allocation.object_key.slice(), orphan) else std.mem.eql(u8, &pending.allocation.address, &orphan.location);
                if (matches) break;
            }
            if (!try collector.step(&engine, .{ .unix_ms = now })) return error.UnexpectedWait;
        } else return error.FixtureBudget;
        const pending = (try collector.current()).?.pending.?.allocation;
        if (direct) {
            if (!std.mem.eql(u8, pending.object_key.slice(), orphan)) return error.WrongCandidate;
        } else if (!std.mem.eql(u8, &pending.address, &orphan.location)) return error.WrongCandidate;
        var name: [96]u8 = undefined;
        const hash = std.fmt.bytesToHex(pending.meta.sha256, .lower);
        const allocation_name = pending.name();
        return emit(init, .{ .key = if (direct) pending.object_key.slice() else try pending.key(&name), .digest = @as([]const u8, &hash), .allocation = @as([]const u8, &allocation_name), .position = engine.head.position, .previous_reclaimed = (try collector.current()).?.reclaimed_objects, .source_activity = activity });
    }
    if (std.mem.eql(u8, args[2], "delete")) {
        if ((try collector.current()).?.phase != .deleting) return error.MissingIntent;
        Fault.point = args[3];
        Fault.syncs = 0;
        Fault.deletes = 0;
        if (!try collector.step(&engine, .{ .unix_ms = now })) return error.UnexpectedWait;
        if (std.mem.eql(u8, Fault.point, "ack")) Fault.stop();
        if (!std.mem.eql(u8, Fault.point, "none")) return error.BoundaryNotReached;
        return emit(init, .{ .syncs = Fault.syncs, .deletes = Fault.deletes });
    }
    if (!std.mem.eql(u8, args[2], "recover")) return error.InvalidArguments;
    for (0..2000) |_| {
        if (!try collector.step(&engine, .{ .unix_ms = now })) break;
    } else return error.FixtureBudget;
    const state = (try collector.current()).?;
    if (state.phase != .complete or state.aborted or (try engine.process(1)).pid != 1) return error.IncompleteRecovery;
    var bytes: [64]u8 = undefined;
    if (!std.mem.eql(u8, try owner.read("table/untouched.data", &bytes), "independent owner bytes")) return error.UnrelatedOwnerChanged;
    if (direct) {
        try table.recover();
        const outcome = try table.observe(binding, guard) orelse return error.MissingOriginalReceipt;
        if (outcome.position.partition != 17 or outcome.position.next_lsn != 1 or outcome.affected != 0) return error.WrongOriginalReceipt;
        const repeated = try table.apply(binding, &.{}, .point, guard);
        if (!std.meta.eql(outcome, repeated)) return error.ChangedOriginalReceipt;
        if (try owner.objects.objectStore().head("table-segments/unaccepted.tseg") != null) return error.OrphanNotCollected;
    }
    try emit(init, .{ .position = engine.head.position, .phase = state.phase, .reclaimed = state.reclaimed_objects, .source_activity = state.source_activity });
}

//! Separate-process test host. Real Exchange turns are journaled in TransitLog;
//! the configured fixture supplies authority. This executable has no transport
//! dispatch and is never included in a runtime installation.
const std = @import("std");
const root = @import("root.zig");
const c = root.data.catalog;
const p = c.protocol;
const f = @import("catalog_fixture.zig");
const ex = @import("exchange_fixture.zig");
const proof = @import("import_test.zig");
const runtime = @import("fixture_runtime.zig");
const Boundary = struct {
    directory: std.Io.Dir,
    selected: []const u8,
    fn hit(raw: *anyopaque, name: []const u8) !void {
        const self: *Boundary = @ptrCast(@alignCast(raw));
        if (!std.mem.eql(u8, self.selected, name)) return;
        try self.directory.writeFile(runtime.io(), .{ .sub_path = "boundary", .data = name });
        // The driver kills this live process after observing the marker. It
        // retains stdin so EOF cannot masquerade as a crash/recovery boundary.
        var buffer: [1]u8 = undefined;
        var input = std.Io.File.stdin().reader(runtime.io(), &buffer);
        _ = try input.interface.takeByte();
        return error.UnexpectedContinuation;
    }
};
pub fn main(init: std.process.Init) !void {
    runtime.supplied = .{ .allocator = init.gpa, .io = init.io };
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 4) return error.InvalidArgument;
    const directory = try std.Io.Dir.cwd().openDir(init.io, args[1], .{});
    defer directory.close(init.io);
    var boundary: Boundary = .{ .directory = directory, .selected = args[3] };
    runtime.boundary = .{ .context = &boundary, .run = Boundary.hit };
    defer runtime.boundary = null;
    // Source-fixture materialization is measured separately from the bounded
    // destination owner and adapter workspaces.
    var data_memory: c.fuze.MemoryBudget = .{ .parent = init.gpa, .limit = 7 * 1024 * 1024 };
    const data_allocator = data_memory.allocator();
    var wal = try c.storage.LocalWal.LocalWal.openDiskWithOptions(data_allocator, init.io, directory, "catalog-wal", .{});
    defer wal.deinit();
    var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(data_allocator, init.io, directory, "objects");
    defer objects.deinit();
    var catalog = try f.ownerWith(data_allocator, &wal, &objects);
    defer catalog.deinit();
    var access: f.Access = .{ .exclusive = true };
    var exchange_wal = try c.storage.LocalWal.LocalWal.openDiskWithOptions(init.gpa, init.io, directory, "exchange-wal", .{});
    defer exchange_wal.deinit();
    var store = try ex.Store.reopen(&exchange_wal);
    defer store.deinit();
    if (std.mem.eql(u8, args[2], "prepare")) {
        try catalog.initialize(access.policy());
        const source = try f.captureSetup(&catalog, &access);
        const input = proof.savedInput(source, try proof.original(&store, 4 * 1024 * 1024, 200, false));
        try directory.writeFile(init.io, .{ .sub_path = "input.json", .data = try input.encode(allocator) });
        return;
    }
    const encoded = try directory.readFileAlloc(init.io, "input.json", allocator, .limited(root.Saved.max_bytes));
    const parsed = try root.Saved.load(allocator, encoded);
    const input = parsed.value;
    var origin: proof.Origin = .{ .store = &store, .access = &access, .expected = input };
    var admission: c.DirectSourceCapture.Admission = .{};
    var importer: root.Importer(proof.Origin) = undefined;
    try importer.init(init.gpa, input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
    defer importer.deinit();
    for (0..4096) |_| {
        const state = try importer.step();
        if (try catalog.store.clientTokenState(input.candidate.key)) |candidate| {
            const capture = candidate.capture.?;
            if (capture.phase == .uploading and capture.ready_bytes != 0) try runtime.hit("readiness");
        }
        if (state.phase == .sealed) try runtime.hit("seal");
        if (state.phase == .settled and state.outcome != null) try runtime.hit("decision");
        if (state.phase == .released) {
            if (!std.mem.eql(u8, args[3], "finish")) return error.MissingProcessBoundary;
            origin.denied = true;
            try proof.readPublished(&catalog, &access, input, state);
            origin.denied = false;
            var current = origin.source();
            const control = try (root.http.exchange.Exchange{ .resource = 7, .id = 1 }).control(&current);
            if (control.dependents != 0 or control.caller != .held or state.evidence.?.body.bytes != 4 * 1024 * 1024) return error.TestUnexpectedResult;
            const report = .{ .definition = p.Growth.current_definition, .phase = state.phase, .evidence = state.evidence.?, .outcome = state.outcome.?, .upstream = control, .data_peak_bytes = data_memory.peak, .adapter_peak_bytes = importer.memory.peak, .charged_replay_bytes = state.work_bytes, .charged_replay_parts = state.work_parts };
            try directory.writeFile(init.io, .{ .sub_path = "result.json", .data = try p.Json.valueAlloc(allocator, report) });
            return;
        }
    }
    return error.SourceHandoffWorkLimit;
}

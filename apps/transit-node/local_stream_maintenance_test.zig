//! Native disk scheduling over complete catalog declarations, with a history
//! longer than one bounded replay and no retained caller proof in workspaces.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Service = @import("LocalTableService.zig");
const Host = @import("LocalTableHost.zig");
const Work = @import("LocalTableMaintenance.zig");

pub fn exercise(service: *Service, declaration: c.DirectLog.Definition, policy: c.DirectCatalog.Policy) !void {
    const native = service.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    const target: c.protocol.StreamQueue.Partition = .{ .definition = c.protocol.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    {
        var cached: ?c.DirectStream.Cached = null;
        defer if (cached) |*value| value.deinit();
        var scratch: std.heap.ArenaAllocator = .init(t.allocator);
        defer scratch.deinit();
        var output: std.heap.ArenaAllocator = .init(t.allocator);
        defer output.deinit();
        const environment: c.DirectStream.Environment = .{ .authority = try c.storage.LogRead.Authority.init(@splat(7)), .clock = null };
        // Real accepted and closed reads leave a durable recovery backlog,
        // without leaving an unbounded population of active read pins.
        for (0..130) |i| {
            _ = scratch.reset(.retain_capacity);
            _ = output.reset(.retain_capacity);
            const consume: c.protocol.StreamRead.Request = .{
                .target = target,
                .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 10000 + 2 * i },
                .group = null,
                .from = 0,
                .until = 0,
                .timestamp = null,
            };
            const accepted = try c.DirectStream.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = .{ .consume = consume }, .payload = null } }, policy);
            try t.expect(accepted.operation.?.consume.until == 0);
            var release_operation = consume.operation;
            release_operation.operation += 1;
            _ = scratch.reset(.retain_capacity);
            _ = try c.DirectStream.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = .{ .release = .{ .operation = release_operation, .target = target, .read = accepted.operation.?.consume.handle() } }, .payload = null } }, policy);
        }
        try t.expect(cached.?.owner.root.next_lsn > 256 and cached.?.owner.root.recovery == null);
    }
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState() };
    defer host.deinit();
    var allocations: c.fuze.memory.AllocationProbe = .{ .parent = t.allocator };
    var work: Work = .{ .host = &host, .allocator = allocations.allocator() };
    defer work.deinit();
    const settings: c.protocol.Storage.Maintenance = .{
        .resident_bytes = 32 * 1024 * 1024,
        .flush = .{ .enabled = true },
        .archive = .{ .enabled = true, .work_frames = 8 },
        .compact = true,
    };
    const request: c.protocol.Growth.Request = .{ .realm = 42, .principal = 0, .sequence = (try service.engine.principal(0)).sequence + 1, .command = .checkpoint };
    const signed = try c.protocol.Growth.sign(request, service.registrar.key);
    var idle: usize = 0;
    var units: usize = 0;
    var retained = false;
    var peak: usize = 0;
    while (idle < 16) : (units += 1) {
        if (units == 1024) return error.FixtureBudget;
        if (units == 3) {
            // Losing process-local recovery hints releases every retained byte.
            // The next executor reconstructs accepted maintenance targets.
            work.deinit();
            try t.expectEqual(@as(usize, 0), allocations.live_bytes);
            work = .{ .host = &host, .allocator = allocations.allocator() };
        }
        const progressed = try Work.step(&work, service.engine, settings, signed);
        retained = retained or work.memory.used != 0;
        peak = @max(peak, work.last_peak_bytes);
        try t.expect(work.last_peak_bytes <= settings.resident_bytes);
        idle = if (progressed) 0 else idle + 1;
    }
    try t.expect(retained);
    try t.expectEqual(work.memory.used, allocations.live_bytes);
    try t.expect(allocations.live_bytes <= settings.resident_bytes);
    var authority: @import("LocalMaintenanceAuthority.zig") = .{ .engine = service.engine, .signed = signed, .resource = service.configuration.scope.resource };
    for (0..declaration.count()) |ordinal| {
        const initial = try declaration.genesis(@intCast(ordinal));
        var stream = try c.storage.StreamPartition.open(t.allocator, data.log(), data.objects(), initial, authority.guard(), .{});
        defer stream.deinit() catch unreachable;
        while (!(try stream.recoverStep(authority.guard(), 256)).complete) {}
        try t.expect(stream.root.sealed_through == 2 and stream.root.next_offset == 2);
        try t.expectEqual(@as(u64, 0), stream.root.retained_from); // Unlimited retention.
        try t.expectEqual(@as(u64, 1), stream.root.hidden.cardinality);
        try t.expect(stream.root.compaction == null and stream.root.maintenance.archive_target == null);
        try t.expect(stream.root.archive.through > 1 and stream.root.recovery != null);
        try t.expectError(error.WalHistoryTrimmed, data.log().read(t.allocator, initial.partition, 0, 1));
    }
    std.debug.print("Native Stream maintenance: {d} units, {d} peak bytes, bounded replay resumed and finite work settled.\n", .{ units, peak });
}

pub fn expire(service: *Service, declaration: c.DirectLog.Definition) !void {
    const native = service.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState() };
    defer host.deinit();
    var work: Work = .{ .host = &host, .allocator = t.allocator };
    defer work.deinit();
    const request: c.protocol.Growth.Request = .{ .realm = 42, .principal = 0, .sequence = (try service.engine.principal(0)).sequence + 1, .command = .checkpoint };
    const signed = try c.protocol.Growth.sign(request, service.registrar.key);
    const original_clock = service.engine.clock;
    defer service.engine.clock = original_clock;
    service.engine.clock = null;
    const position = try data.log().tail(declaration.first_partition);
    try t.expectError(error.LogTimeUnavailable, Work.step(&work, service.engine, .{}, signed));
    try t.expectEqual(position, try data.log().tail(declaration.first_partition));
    const Clock = struct {
        now: u64,
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now, .error_ms = 5 };
        }
    };
    var clock: Clock = .{ .now = @max(1000, service.engine.head.time_floor_ms) };
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    const limits = native.limits;
    defer native.limits = limits;
    native.limits.bytes = native.allocated; // Closure uses reserved capacity.
    var progressed = false;
    for (0..8) |_| progressed = try Work.step(&work, service.engine, .{}, signed) or progressed;
    try t.expect(progressed);
    var authority: @import("LocalMaintenanceAuthority.zig") = .{ .engine = service.engine, .signed = signed, .resource = service.configuration.scope.resource };
    for (0..declaration.count()) |ordinal| {
        const initial = try declaration.genesis(@intCast(ordinal));
        var stream = try c.storage.StreamPartition.open(t.allocator, data.log(), data.objects(), initial, authority.guard(), .{});
        defer stream.deinit() catch unreachable;
        while (!(try stream.recoverStep(authority.guard(), 256)).complete) {}
        // Partition one was appended without a clock before the policy changed;
        // a later retention age cannot invent its timestamp and expire it.
        try t.expectEqual(@as(u64, if (ordinal == 0) 2 else 0), stream.root.retained_from);
        try t.expectEqual(@as(u64, 2), stream.root.next_offset);
    }
}

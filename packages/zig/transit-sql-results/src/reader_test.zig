const std = @import("std");
const r = @import("root.zig");
const t = std.testing;
const fields = [_]r.Types.Field{.{ .name = "n", .type = .uint64 }};
const schema: r.Types.Type = .{ .structure = &fields };
const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
const Script = struct {
    maximum: usize = 1,
    length: usize = 7,
    position: usize = 0,
    terminal_empty: bool = false,
    fail_after: ?usize = null,
    cells: [8][1]r.Types.Values.Cell = undefined,
    rows: [8]r.Row = undefined,
    closes: usize = 0,
    releases: usize = 0,
    fn next(context: *anyopaque) !r.ResultSet.Chunk {
        const self: *Script = @ptrCast(@alignCast(context));
        if (self.fail_after) |limit| if (self.position >= limit) return error.TestConnectionLost;
        const count = @min(self.maximum, self.length - self.position);
        for (0..count) |i| {
            // Reuse the same storage on every call; the expected relation is
            // deliberately not unique, so deduplication by value is incorrect.
            self.cells[i][0] = .{ .value = .{ .atom = .{ .unsigned = (self.position + i) % 3 } } };
            self.rows[i] = &self.cells[i];
        }
        self.position += count;
        return .{ .values = .fromRows(self.rows[0..count]), .completion = if (self.position == self.length and (!self.terminal_empty or count == 0)) .{ .rows = self.length } else null };
    }
    fn close(context: *anyopaque) !void {
        const self: *Script = @ptrCast(@alignCast(context));
        self.closes += 1;
    }
    fn deinit(context: *anyopaque) void {
        const self: *Script = @ptrCast(@alignCast(context));
        self.releases += 1;
    }
    fn open(self: *Script) !r.ResultSet {
        return r.ResultSet.init(schema, observation, .{ .result = @splat(1), .schema = try schema.fingerprint(), .observation = try r.Observation.fingerprint(t.allocator, observation) }, .{ .context = self, .next = next, .close = close, .deinit = deinit });
    }
};

test "one semantic consumer handles all chunkings and terminal shapes" {
    for (0..8) |length| for (1..9) |maximum| for ([_]bool{ false, true }) |terminal_empty| {
        var script: Script = .{ .length = length, .maximum = maximum, .terminal_empty = terminal_empty };
        var result = try script.open();
        var count: usize = 0;
        while (try result.nextRow()) |row| {
            try t.expectEqual(count % 3, row[0].value.atom.unsigned);
            count += 1;
        }
        try t.expectEqual(length, count);
        try t.expectEqual(length, result.completion().?.rows);
        try t.expectEqual(1, script.closes);
        try t.expectEqual(null, try result.nextRow());
        try result.close();
        try t.expectEqual(length, result.completion().?.rows);
        result.deinit();
        try t.expectEqual(1, script.closes);
        try t.expectEqual(1, script.releases);
    };
}
test "bounded windows preserve owned rows and leave the non-fitting row unread" {
    var script: Script = .{ .maximum = 2 };
    var result = try script.open();
    defer result.deinit();
    const window = try r.Window.read(t.allocator, &result, .{ .rows = 3, .bytes = 4096 });
    defer window.deinit();
    try t.expectEqual(3, window.rows.len);
    try t.expectEqual(.row_limit, window.stop);
    try t.expect(window.completion == null);
    try t.expectEqual(0, (try result.nextRow()).?[0].value.atom.unsigned);
    try t.expectEqual(0, window.rows[0][0].value.atom.unsigned);
    try t.expectEqual(1, window.rows[1][0].value.atom.unsigned);
    const tiny = try r.Window.read(t.allocator, &result, .{ .rows = 10, .bytes = 1 });
    defer tiny.deinit();
    try t.expectEqual(.byte_limit, tiny.stop);
    try t.expectEqual(0, tiny.rows.len);
    try t.expectEqual(1, (try result.nextRow()).?[0].value.atom.unsigned);
}
test "reused window leases preserve model progress completion and independent copies" {
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var retained_storage = try memory.Workspace.init(probe.allocator(), 4096);
    defer retained_storage.deinit();
    var storage = try memory.Workspace.init(probe.allocator(), 4096);
    defer storage.deinit();
    var original: Script = .{ .maximum = 8, .length = 3 };
    var result = try original.open();
    defer result.deinit();
    probe.begin(true);
    const retained = try r.Window.readInto(&retained_storage, &result, 1);
    defer retained.deinit();
    // StatementResult: known completion is independent of delivered coverage.
    try t.expectEqual(3, retained.completion.?.rows);
    try t.expectEqual(.row_limit, retained.stop);
    try t.expectEqual(1, result.progress.delivered);
    try t.expectError(error.WorkspaceBusy, r.Window.readInto(&retained_storage, &result, 1));
    try result.close();
    try t.expectEqual(3, result.completion().?.rows);
    for (0..1000) |iteration| {
        var script: Script = .{ .length = ([_]usize{ 0, 1, 31, 32, 33, 70 })[iteration % 6], .maximum = 1 + iteration % 8, .terminal_empty = iteration % 2 == 0 };
        var next = try script.open();
        defer next.deinit();
        var count: usize = 0;
        while (true) {
            const window = try r.Window.readInto(&storage, &next, 1 + iteration % 8);
            for (window.rows) |row| {
                try t.expectEqual(count % 3, row[0].value.atom.unsigned);
                count += 1;
            }
            const exhausted = window.stop == .exhausted;
            window.deinit();
            try t.expectError(error.StaleMemoryLease, window.validate());
            if (exhausted) break;
        }
        try t.expectEqual(script.length, count);
        try t.expectEqual(script.length, next.completion().?.rows);
        try retained.validate();
        try t.expectEqual(0, retained.rows[0][0].value.atom.unsigned);
    }
    try probe.verify();
    try t.expectEqual(8192, probe.live_bytes);
}
test "a refused window row rolls back scratch without consuming or completing" {
    const memory = @import("transit_memory");
    // The row directory fits; the copied cell does not. Both must roll back.
    var storage = try memory.Workspace.init(t.allocator, 128);
    defer storage.deinit();
    var script: Script = .{ .maximum = 2 };
    var result = try script.open();
    defer result.deinit();
    const window = try r.Window.readInto(&storage, &result, 3);
    defer window.deinit();
    try t.expectEqual(.byte_limit, window.stop);
    try t.expectEqual(0, window.rows.len);
    try t.expectEqual(0, storage.fixed.end_index);
    try t.expectEqual(2, result.progress.received);
    try t.expectEqual(0, result.progress.delivered);
    try t.expect(result.completion() == null);
    try t.expectEqual(0, (try result.nextRow()).?[0].value.atom.unsigned);
}
fn windowFailures(allocator: std.mem.Allocator) !void {
    var script: Script = .{};
    var result = try script.open();
    defer result.deinit();
    const window = try r.Window.read(allocator, &result, .{ .rows = 3, .bytes = 4096 });
    defer window.deinit();
}
test "owned window admission releases every failed backing allocation" {
    try t.checkAllAllocationFailures(t.allocator, windowFailures, .{});
}
test "failure and early closure never produce a successful terminal" {
    var script: Script = .{ .fail_after = 2 };
    var result = try script.open();
    defer result.deinit();
    _ = try result.nextRow();
    _ = try result.nextRow();
    try t.expectError(error.TestConnectionLost, result.nextRow());
    try t.expectEqual(1, script.closes);
    try t.expect(result.completion() == null);
    try t.expectEqual(2, result.progress.delivered);
    try result.close();
    try t.expect(result.completion() == null);
    try t.expectError(error.ResultClosed, result.nextRow());
}

test "early close releases once without advancing unread rows" {
    var script: Script = .{ .maximum = 2 };
    var result = try script.open();
    _ = try result.nextRow();
    try result.close();
    try result.close();
    try t.expectEqual(2, result.progress.received);
    try t.expectEqual(1, result.progress.delivered);
    try t.expect(result.completion() == null);
    result.deinit();
    try t.expectEqual(1, script.closes);
    try t.expectEqual(1, script.releases);
}

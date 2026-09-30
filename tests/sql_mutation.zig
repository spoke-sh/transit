//! Public private-turn mutation consumer. Python independently supplies storage
//! bytes and verifies proposed changes; this fixture is not a native authority.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const Entry = struct { key: []const u8, value: []const u8 };
const Case = struct { sql: []const u8, kind: s.fuze.model.Type, entries: []const Entry };
const Store = struct {
    entries: []const Entry,
    reads: usize = 0,
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        for (self.entries) |entry| if ((try value(entry.key)).eql(key)) return try value(entry.value);
        return null;
    }
};
fn value(hex: []const u8) !p.Value {
    var buffer: [256]u8 = undefined;
    return p.Value.init(try std.fmt.hexToBytes(&buffer, hex));
}
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    const cases = try std.json.parseFromSlice([]const Case, a, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], a, .limited(1024 * 1024)), .{});
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |case, index| {
        const table: s.Table = .{ .id = 1, .resource = 7, .schema = .{ .names = .{ try s.fuze.model.Name.init("id"), try s.fuze.model.Name.init("value") }, .value_type = case.kind } };
        var store: Store = .{ .entries = case.entries };
        var turn = try s.Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .ordinal = 1, .value = .{}, .origin = .{ .external = .{ .principal = 9, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, .{ .context = &store, .read = Store.read });
        const before = turn.decision;
        const result = s.TableMutation.applySql(&turn, table, try s.fuze.model.Name.init("items"), case.sql) catch |err| {
            if (!std.meta.eql(before, turn.decision)) return error.PartialMutation;
            try std.json.Stringify.value(.{ .index = index, .err = @errorName(err), .reads = store.reads }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        try std.json.Stringify.value(.{ .index = index, .affected = result.affected_rows, .mutations = turn.decision.mutations, .reads = store.reads }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}

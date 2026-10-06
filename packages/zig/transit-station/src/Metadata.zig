//! Bounded framework interpretation only. Business KV values and Table rows are
//! deliberately not decoded. Unknown/malformed versions have no lens.
const std = @import("std");
const p = @import("transit_client").protocol;
const TableHead = @import("TableHead.zig");
const Registry = @import("Registry.zig");
const Supervisor = @import("Supervisor.zig");
const Turn = @import("Turn.zig");
pub const Detail = union(enum) {
    behavior: enum { genserver },
    table: struct { object: p.Value, revision: p.Value, rows: p.Value, retired: bool, pending: ?p.Value, schema: struct { record: p.Value, bytes: u32, digest: [32]u8 } },
    registry_scope: struct { id: u32 },
    registry_binding: struct { scope: u32, name: p.Value, revision: u64, destination: ?u64 },
    child: struct { pid: u64, generation: u64, phase: Supervisor.Phase, attempts: u8, limit: u8, retry_at_ms: u64, successor: ?u64 },
    wait: struct { correlation: p.Value, target: u64, phase: @FieldType(Turn.Wait, "phase"), deadline_ms: ?u64, observer: ?u64, resolution_input: u64 },
};
fn integer(value: u64) !p.Value {
    var buffer: [20]u8 = undefined;
    return p.Value.init(try std.fmt.bufPrint(&buffer, "{d}", .{value}));
}
pub fn decode(writer: u64, resource: u64, entry: p.Growth.Entry) ?Detail {
    return decodeChecked(writer, resource, entry) catch null;
}
fn decodeChecked(writer: u64, resource: u64, entry: p.Growth.Entry) !?Detail {
    try p.State.key(entry.key);
    try entry.value.validate();
    if (entry.key.eql(try p.Value.init("\x00station"))) return if (entry.value.eql(try p.Value.init("station.genserver.v1"))) .{ .behavior = .genserver } else null;
    const key = entry.key;
    if (key.len < 2 or key.data[0] != 0) return null;
    switch (key.data[1]) {
        'P' => {
            const head = try TableHead.decode(entry.value);
            if (!key.eql(TableHead.key(head.object)) or head.resource != resource) return null;
            return .{ .table = .{
                .object = try integer(head.object),
                .revision = try integer(head.revision),
                .rows = try integer(head.rows),
                .retired = head.retired,
                .pending = if (head.pending == 0) null else try integer(head.pending),
                .schema = .{ .record = try integer(head.schema.id), .bytes = head.schema.spec.length, .digest = head.schema.spec.digest },
            } };
        },
        's' => {
            if (key.len != 6 or entry.value.len != 20 or !std.mem.eql(u8, entry.value.data[0..4], "RGS1") or std.mem.readInt(u64, entry.value.data[4..12], .little) != writer or std.mem.readInt(u64, entry.value.data[12..20], .little) != resource) return null;
            return .{ .registry_scope = .{ .id = std.mem.readInt(u32, key.data[2..6], .little) } };
        },
        'n' => {
            if (key.len < 7 or key.len > 30) return null;
            const binding = try Registry.Binding.decode(entry.value);
            if (binding.scope != std.mem.readInt(u32, key.data[2..6], .little) or binding.revision > p.max_counter) return null;
            _ = try Registry.Name.init(key.slice()[6..]);
            return .{ .registry_binding = .{ .scope = binding.scope, .name = try p.Value.init(key.slice()[6..]), .revision = binding.revision, .destination = binding.destination } };
        },
        'c' => {
            if (key.len != 11 or key.data[10] != 0) return null;
            const child = try Supervisor.Child.decode(entry.value);
            if (child.pid != std.mem.readInt(u64, key.data[2..10], .little) or child.generation > p.max_counter or child.retry_at_ms > p.max_counter or (child.successor != null and child.successor.? > p.max_counter)) return null;
            return .{ .child = .{ .pid = child.pid, .generation = child.generation, .phase = child.phase, .attempts = child.attempts, .limit = child.limit, .retry_at_ms = child.retry_at_ms, .successor = child.successor } };
        },
        'w' => {
            if (key.len != 10) return null;
            const wait = try Turn.Wait.decode(entry.value);
            if (wait.target > p.max_counter or wait.resolution_input > p.max_counter or (wait.deadline_ms != null and wait.deadline_ms.? > p.max_counter)) return null;
            return .{ .wait = .{ .correlation = try integer(std.mem.readInt(u64, key.data[2..10], .little)), .target = wait.target, .phase = wait.phase, .deadline_ms = wait.deadline_ms, .observer = wait.observer, .resolution_input = wait.resolution_input } };
        },
        else => return null,
    }
}

test "metadata never guesses application values or unknown descriptor versions" {
    const entry: p.Growth.Entry = .{ .key = try p.Value.init("\x00station"), .value = try p.Value.init("station.genserver.v2"), .revision = 1 };
    try std.testing.expect(decode(2, 7, entry) == null);
    var known = entry;
    known.value = try p.Value.init("station.genserver.v1");
    try std.testing.expect(decode(2, 7, known).? == .behavior);
    known.key = try p.Value.init("application");
    try std.testing.expect(decode(2, 7, known) == null);
    const wait: p.Growth.Entry = .{ .key = Turn.waitKey(std.math.maxInt(u64)), .value = (Turn.Wait{ .target = 8 }).encode(), .revision = 2 };
    try std.testing.expectEqualStrings("18446744073709551615", decode(2, 7, wait).?.wait.correlation.slice());
}

test "Table metadata requires the exact current head key and resource without guessing schema columns" {
    const t = std.testing;
    const head: TableHead = .{ .resource = 7, .object = std.math.maxInt(u64), .revision = std.math.maxInt(u64), .schema = .{ .id = 1, .spec = .{ .format = @import("TablePages.zig").schema_format, .length = 500, .digest = @splat(9) } }, .next_record = 2, .pending = std.math.maxInt(u64) };
    var entry: p.Growth.Entry = .{ .key = TableHead.key(head.object), .value = try head.encode(), .revision = 12 };
    const detail = decode(2, 7, entry).?.table;
    try t.expectEqualStrings("18446744073709551615", detail.object.slice());
    try t.expectEqualStrings("18446744073709551615", detail.revision.slice());
    try t.expectEqualStrings("18446744073709551615", detail.pending.?.slice());
    try t.expectEqualStrings("0", detail.rows.slice());
    try t.expectEqual(@as(u32, 500), detail.schema.bytes);
    try t.expectEqual(head.schema.spec.digest, detail.schema.digest);
    try t.expect(decode(2, 8, entry) == null);
    entry.key = TableHead.key(1);
    try t.expect(decode(2, 7, entry) == null);
    entry.key = TableHead.key(head.object);
    entry.value.data[4] ^= 1;
    try t.expect(decode(2, 7, entry) == null);
    entry = .{ .key = try p.Value.init("\x00t\x01\x00\x00\x00"), .value = try p.Value.init("TBL1\x01\x02id\x06amount"), .revision = 12 };
    try t.expect(decode(2, 7, entry) == null);
}

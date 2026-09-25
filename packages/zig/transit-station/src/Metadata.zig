//! Bounded framework interpretation only. Business KV values and Table rows are
//! deliberately not decoded. Unknown/malformed versions have no lens.
const std = @import("std");
const p = @import("transit_client").protocol;
const Table = @import("Table.zig");
const Query = @import("Query.zig");
const Registry = @import("Registry.zig");
const Supervisor = @import("Supervisor.zig");
const Turn = @import("Turn.zig").Legacy;
pub const Detail = union(enum) {
    behavior: enum { genserver },
    table: struct { id: u32, schema_version: u8, columns: [2]Column, fingerprint: [32]u8 },
    registry_scope: struct { id: u32 },
    registry_binding: struct { scope: u32, name: p.Value, revision: u64, destination: ?u64 },
    child: struct { pid: u64, generation: u64, phase: Supervisor.Phase, attempts: u8, limit: u8, retry_at_ms: u64, successor: ?u64 },
    query: struct { id: u64, correlation: p.Value, destination: u64, table: u32, source_resource: u64, source_revision: u64, schema: [32]u8, bytes: u16, rows: u8, phase: Query.Phase, direction: enum { outgoing, incoming } },
    wait: struct { correlation: p.Value, target: u64, phase: @FieldType(Turn.Wait, "phase"), deadline_ms: ?u64, observer: ?u8, resolution_input: u64 },
};
pub const Column = struct { name: p.Value, data_type: @import("transit_fuze").model.Type, nullable: bool };
fn integer(value: u64) !p.Value {
    var buffer: [20]u8 = undefined;
    return p.Value.init(try std.fmt.bufPrint(&buffer, "{d}", .{value}));
}
pub fn decode(writer: u64, resource: u64, entry: p.State.Entry) ?Detail {
    return decodeChecked(writer, resource, entry) catch null;
}
fn decodeChecked(writer: u64, resource: u64, entry: p.State.Entry) !?Detail {
    try p.State.key(entry.key);
    try entry.value.validate();
    if (entry.key.eql(try p.Value.init("\x00station"))) return if (entry.value.eql(try p.Value.init("station.genserver.v1"))) .{ .behavior = .genserver } else null;
    const key = entry.key;
    if (key.len < 2 or key.data[0] != 0) return null;
    switch (key.data[1]) {
        't' => {
            if (key.len != 6) return null;
            const schema = try Table.decodeSchema(entry.value);
            return .{ .table = .{ .id = std.mem.readInt(u32, key.data[2..6], .little), .schema_version = schema.version, .fingerprint = try schema.fingerprint(), .columns = .{ .{ .name = try p.Value.init(schema.names[0].slice()), .data_type = .int64, .nullable = false }, .{ .name = try p.Value.init(schema.names[1].slice()), .data_type = schema.value_type, .nullable = true } } } };
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
        'q', 'i' => {
            if (key.len != 11 or key.data[10] != (if (key.data[1] == 'q') @as(u8, 0) else @as(u8, 3))) return null;
            const manifest = try Query.Manifest.decode(entry.value);
            const identity = std.mem.readInt(u64, key.data[2..10], .little);
            if (identity != (if (key.data[1] == 'q') manifest.result else manifest.correlation)) return null;
            if (manifest.result > p.max_counter or manifest.destination > p.max_counter or manifest.basis.resource > p.max_counter or manifest.basis.revision > p.max_counter) return null;
            return .{ .query = .{ .id = manifest.result, .correlation = try integer(manifest.correlation), .destination = manifest.destination, .table = manifest.table, .source_resource = manifest.basis.resource, .source_revision = manifest.basis.revision, .schema = manifest.basis.schema, .bytes = manifest.bytes, .rows = manifest.rows, .phase = manifest.phase, .direction = if (key.data[1] == 'q') .outgoing else .incoming } };
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
    const entry: p.State.Entry = .{ .key = try p.Value.init("\x00station"), .value = try p.Value.init("station.genserver.v2"), .revision = 1 };
    try std.testing.expect(decode(2, 7, entry) == null);
    var known = entry;
    known.value = try p.Value.init("station.genserver.v1");
    try std.testing.expect(decode(2, 7, known).? == .behavior);
    known.key = try p.Value.init("application");
    try std.testing.expect(decode(2, 7, known) == null);
    const wait: p.State.Entry = .{ .key = Turn.waitKey(std.math.maxInt(u64)), .value = (Turn.Wait{ .target = 8 }).encode(), .revision = 2 };
    try std.testing.expectEqualStrings("18446744073709551615", decode(2, 7, wait).?.wait.correlation.slice());
}

//! Explicit typed lifecycle calls over the shared signed catalog connection.
//! The caller persists original work and chooses every execution/recovery step.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const L = c.DirectLog;
const wire = c.DirectLogProtocol;
const w = c.DirectTableProtocol;
pub const Action = union(enum) {
    preview: L.Request,
    admit: L.Request,
    operation: wire.Operation,
    lookup: struct { namespace: u64, name: []const u8 },
    list: struct { namespace: u64, after: ?u64 },
    pending: struct { namespace: u64, after: ?u64 },
};
pub const Metadata = struct { declaration: L.Definition, schema: c.fuze.TableSchema.Schema };
/// Recheck disclosure against the current native grant and exact named object.
/// A cached definition cannot follow a replacement, rename or policy revision.
pub fn requireCurrent(client: c.DirectTableClient, expected: L.Definition) !void {
    try expected.validate();
    try client.connection.object(expected.stored.declaration.interpretation.object);
    const response = try client.call(.{ .log_lookup = .{ .namespace = expected.properties.namespace, .name = expected.properties.name.slice() } });
    defer response.deinit();
    const actual = response.value.result.log_lookup orelse return error.CatalogDefinitionChanged;
    if (actual.declaration.kind() != expected.kind() or !std.meta.eql(actual.declaration.stored.declaration.interpretation, expected.stored.declaration.interpretation)) return error.CatalogDefinitionChanged;
}
pub const Result = union(enum) { preview: L.Preview, admitted: L.Operation, operation: L.Observation, lookup: ?Metadata, list: wire.Page, pending: wire.PendingPage };
pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    work: wire.Ddl,
    pub fn validate(self: Saved, scratch: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.work.validate(scratch, self.connection);
    }
};

pub fn save(allocator: std.mem.Allocator, connection: w.Connection, request: L.Request) ![]u8 {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .work = try wire.Ddl.encode(scratch.allocator(), request) };
    try value.validate(scratch.allocator());
    return p.Json.valueAllocBounded(allocator, value, w.max_request_bytes);
}
pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Saved) {
    if (bytes.len == 0 or bytes.len > w.max_request_bytes) return error.InvalidLogCatalogIntent;
    const parsed = try p.Json.parseFromSliceOwned(Saved, allocator, bytes);
    errdefer parsed.deinit();
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    try parsed.value.validate(scratch.allocator());
    return parsed;
}

/// All returned schemas belong to output. A later request or client close does
/// not invalidate them. No transport retry, admission or execution is implicit.
pub fn apply(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, action: Action) !Result {
    var scratch: std.heap.ArenaAllocator = .init(client.allocator);
    defer scratch.deinit();
    const request: w.Action = switch (action) {
        .preview => |value| .{ .log_preview = try wire.Ddl.encode(scratch.allocator(), value) },
        .admit => |value| .{ .log_admit = try wire.Ddl.encode(scratch.allocator(), value) },
        .operation => |value| .{ .log_operation = value },
        .lookup => |value| .{ .log_lookup = .{ .namespace = value.namespace, .name = value.name } },
        .list => |value| .{ .log_list = .{ .namespace = value.namespace, .after = value.after } },
        .pending => |value| .{ .log_pending = .{ .namespace = value.namespace, .after = value.after } },
    };
    const response = try client.call(request);
    defer response.deinit();
    return switch (response.value.result) {
        .log_preview => |value| .{ .preview = value },
        .log_admitted => |value| .{ .admitted = value },
        .log_operation => |value| .{ .operation = value },
        .log_list => |value| .{ .list = value },
        .log_pending => |value| .{ .pending = value },
        .log_lookup => |maybe| .{ .lookup = if (maybe) |value| .{ .declaration = value.declaration, .schema = (try c.fuze.TableSchema.decode(output.allocator(), try value.schema.decode(scratch.allocator(), c.fuze.TableSchema.max_bytes))).schema } else null },
        else => error.InvalidTableResponse,
    };
}

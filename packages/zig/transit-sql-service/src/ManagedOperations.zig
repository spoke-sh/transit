//! Durable SQL admission of the exact typed computation declaration/control.
//! SQL recovery never reparses a command or selects a replacement identity.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const api = g.session_protocol;
const ops = g.SessionOperations;
const M = g.direct.ManagedTable;
pub const Prepared = g.database.ManagedSql.Prepared;
const format: u32 = 0x44465331; // DFS1
pub const Request = struct {
    definition: p.Growth.Definition,
    action: union(enum) { publish: M.Declaration, control: struct { declaration: M.Declaration, saved: c.DirectTableProtocol.Binary } },
    fn declaration(self: Request) M.Declaration {
        return switch (self.action) {
            .publish => |value| value,
            .control => |value| value.declaration,
        };
    }
};
fn manager(host: *g.Session) M {
    return .{ .client = host.table };
}
pub fn validate(host: *g.Session, prepared: *const Prepared) !void {
    if (!host.native_profile or host.source != null or host.transaction.handle != null) return error.UnsupportedManagedTable;
    if (host.wire.local == null or host.wire.local.?.changes == null) return error.ManagedTableRequiresCohostedService;
    const m = manager(host);
    switch (prepared.statement) {
        .create => |value| {
            _ = try m.prepare(host.namespace, value.name.slice(), 0, 1, value.output.slice(), value.sql, host.readOptions());
        },
        .control => |value| {
            const declared = try m.find(host.namespace, value.name) orelse return error.CatalogNameNotFound;
            defer declared.deinit();
            _ = try m.inspect(declared.value);
        },
    }
}
fn read(host: *g.Session, id: u64) !std.json.Parsed(Request) {
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    if (item.kind != .dataflow or !std.meta.eql(item.binding(), try host.account.database(host.database))) return error.SqlOperationBindingChanged;
    const initial = try ops.readInitial(&reader, try reader.operation(id));
    const value = try manager(host).load(Request, initial.body orelse return error.InvalidManagedTableRecord, format);
    errdefer value.deinit();
    if (value.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try value.value.declaration().validate();
    return value;
}
pub fn admit(host: *g.Session, prepared: *const Prepared, token: api.Token, fingerprint: [32]u8) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    if (try host.fresh(g.ConfigurationOperations.find, .{ host, token, @as(?[32]u8, fingerprint) })) |ref| return status(host, ref.id);
    try validate(host, prepared);
    var original: [16]u8 = undefined;
    try host.io.randomSecure(&original);
    const object = (std.mem.readInt(u64, original[0..8], .big) % p.max_counter) + 1;
    const operation = (std.mem.readInt(u64, original[8..16], .big) % p.max_counter) + 1;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    defer arena.deinit();
    const m = manager(host);
    const action: @FieldType(Request, "action") = switch (prepared.statement) {
        .create => |value| .{ .publish = try m.prepare(host.namespace, value.name.slice(), object, operation, value.output.slice(), value.sql, host.readOptions()) },
        .control => |value| blk: {
            const declared = try m.find(host.namespace, value.name) orelse return error.CatalogNameNotFound;
            // Parsed strings must outlive request serialization below.
            const copy = try p.Json.valueAlloc(arena.allocator(), declared.value);
            declared.deinit();
            const parsed = try p.Json.parseFromSlice(M.Declaration, arena.allocator(), copy);
            const observation = try m.inspect(parsed.value);
            const saved = try m.prepareControl(parsed.value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = host.table.connection.scope, .principal = host.table.connection.principal, .operation = operation }, .target = try parsed.value.interpretation(host.allocator), .expected = observation.head.control, .command = value.command });
            defer host.allocator.free(saved);
            break :blk .{ .control = .{ .declaration = parsed.value, .saved = try c.DirectTableProtocol.Binary.encode(arena.allocator(), saved) } };
        },
    };
    const request: Request = .{ .definition = p.Growth.current_definition, .action = action };
    const bytes = try p.Json.valueAllocBounded(arena.allocator(), request, c.DirectRecord.max_bytes);
    const body = try c.DirectRecord.stage(host.table, host.account.execution.account, format, bytes);
    var reader = try host.observer.source();
    defer host.runtime.notifyExternal();
    const ref = try ops.begin(&reader, .{ .nonce = token, .fingerprint = fingerprint, .kind = .dataflow, .binding = try host.account.database(host.database), .original = original, .source = body.content.sha256, .expected_generation = 1, .reservation = @intCast(bytes.len + 8192) }, body);
    return status(host, ref.id);
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const saved = try read(host, id);
    defer saved.deinit();
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    return .{ .command = if (saved.value.action == .publish) .create_dataflow else .control_dataflow, .identity = .{ .account = host.account.execution.account, .id = id, .kind = .dataflow }, .token = item.nonce, .phase = if (item.phase == .terminal) .terminal else .ready, .outcome = switch (item.summary) {
        .none => null,
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .partial => return error.InvalidManagedTableRecord,
    }, .owner_operation = item.original };
}
pub fn resumeOperation(host: *g.Session, id: u64) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    if (item.phase == .terminal) return status(host, id);
    const saved = try read(host, id);
    defer saved.deinit();
    const m = manager(host);
    apply(m, saved.value) catch |err| switch (err) {
        error.DataflowSourceChanged, error.ManagedTableNameConflict, error.ManagedTableConflict => {
            try ops.complete(&reader, id, .rejected);
            return status(host, id);
        },
        else => return err,
    };
    try ops.complete(&reader, id, .applied);
    host.runtime.notify();
    return status(host, id);
}
fn apply(m: M, saved: Request) !void {
    switch (saved.action) {
        .publish => |value| _ = try m.publish(value),
        .control => |value| {
            const bytes = try value.saved.decode(m.client.allocator, c.DirectRecord.max_bytes);
            defer m.client.allocator.free(bytes);
            _ = try m.applyControl(bytes);
        },
    }
}

test {
    std.testing.refAllDecls(@This());
}

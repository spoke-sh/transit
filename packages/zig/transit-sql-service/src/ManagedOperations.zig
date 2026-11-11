//! Durable SQL admission of the exact typed computation declaration/control.
//! SQL recovery never reparses a command or selects a replacement identity.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const api = g.session_protocol;
const ops = g.SessionOperations;
const M = g.direct.ManagedTable;
const A = g.direct.ManagedApplication;
pub const Prepared = g.database.ManagedSql.Prepared;
const format: u32 = 0x44465331; // DFS1
pub const Request = struct {
    definition: p.Growth.Definition,
    action: union(enum) {
        publish: M.Declaration,
        control: struct { declaration: M.Declaration, saved: c.DirectTableProtocol.Binary },
        publish_program: A.Declaration,
        control_program: struct { declaration: A.Declaration, saved: c.DirectTableProtocol.Binary },
    },
    fn validate(self: Request, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        switch (self.action) {
            .publish => |value| try value.validate(),
            .control => |value| try value.declaration.validate(),
            .publish_program => |value| try value.validate(allocator),
            .control_program => |value| try value.declaration.validate(allocator),
        }
    }
    fn interpretation(self: Request, allocator: std.mem.Allocator) !p.DataLifecycle.Definition {
        return switch (self.action) {
            .publish => |value| value.interpretation(allocator),
            .control => |value| value.declaration.interpretation(allocator),
            .publish_program => |value| value.interpretation(allocator),
            .control_program => |value| value.declaration.interpretation(allocator),
        };
    }
};
fn manager(host: *g.Session) M {
    return .{ .client = host.table };
}
/// Native name acceptance selects the control object. Publisher token accounts
/// only recover its declaration; their lookup order cannot choose its kind.
pub fn program(host: *g.Session, name: c.TableAuthority.Name) !?std.json.Parsed(A.Declaration) {
    const named = try namedObject(host, name) orelse return null;
    const application: A = .{ .client = host.table };
    const found = try application.find(host.namespace, name) orelse return null;
    if (!std.meta.eql(named, found.value.object)) {
        found.deinit();
        return null;
    }
    return found;
}
fn namedObject(host: *g.Session, name: c.TableAuthority.Name) !?p.DataLifecycle.Object {
    const response = try host.table.call(.{ .kv_lookup = .{ .namespace = host.namespace, .name = name.slice() } });
    defer response.deinit();
    return if (response.value.result.kv_lookup) |value| value.interpretation.interpretation.object else null;
}
fn requireNamed(host: *g.Session, value: M.Declaration) !void {
    const named = try namedObject(host, value.name) orelse return error.CatalogNameNotFound;
    if (!std.meta.eql(named, value.object)) return error.DataflowIdentityConflict;
}
pub fn requireProfile(host: *g.Session) !void {
    if (!host.native_profile or host.source != null or host.transaction.handle != null) return error.UnsupportedManagedTable;
    if (host.wire.local == null or host.wire.local.?.changes == null) return error.ManagedTableRequiresCohostedService;
}
pub fn validate(host: *g.Session, prepared: *const Prepared) !void {
    try requireProfile(host);
    const m = manager(host);
    switch (prepared.statement) {
        .create => |value| {
            _ = try m.prepare(host.namespace, value.name.slice(), 0, 1, value.output.slice(), value.sql, host.readOptions());
        },
        .program => |value| {
            _ = try host.table.require(.{ .namespace = host.namespace, .target = null, .access = .create_table });
            const declared = try g.direct.ApplicationSql.prepare(host.table, host.namespace, 0, 1, value.sql);
            declared.deinit();
        },
        .control => |value| {
            const application: A = .{ .client = host.table };
            if (try program(host, value.name)) |declared| {
                defer declared.deinit();
                if ((value.command == .authorize) != (value.role != null) or value.command == .refresh) return error.InvalidDataflowTransition;
                _ = try application.inspect(declared.value);
                return;
            }
            if (value.role != null) return error.InvalidDataflowTransition;
            const declared = try m.find(host.namespace, value.name) orelse return error.CatalogNameNotFound;
            defer declared.deinit();
            try requireNamed(host, declared.value);
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
    try value.value.validate(host.allocator);
    return value;
}
pub const Guard = struct {
    source: p.DataLifecycle.Definition,
    output: p.DataLifecycle.Definition,
    definition: ?p.DataLifecycle.Definition,
    control: ?p.Dataflow.Control,
    sql_sha256: [32]u8,
    fn require(self: Guard, value: M.Declaration, control: ?p.Dataflow.Control, allocator: std.mem.Allocator) !void {
        if (!std.meta.eql(self.source, value.source.interpretation.interpretation) or !std.meta.eql(self.output, value.output.interpretation.interpretation)) return error.DataflowSourceChanged;
        if (self.definition) |expected| if (!std.meta.eql(expected, try value.interpretation(allocator))) return error.DataflowSourceChanged;
        if (!std.meta.eql(self.control, control)) return error.DataflowControlChanged;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(value.sql, &digest, .{});
        if (!std.mem.eql(u8, &digest, &self.sql_sha256)) return error.DataflowSourceChanged;
    }
};
pub fn admit(host: *g.Session, prepared: *const Prepared, token: api.Token, fingerprint: [32]u8) !api.Operation {
    var acceptance_possible = false;
    return admitReviewed(host, prepared, token, fingerprint, &acceptance_possible, null);
}
pub fn admitReviewed(host: *g.Session, prepared: *const Prepared, token: api.Token, fingerprint: [32]u8, acceptance_possible: *bool, guard: ?Guard) !api.Operation {
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
        .create => |value| blk: {
            if (try namedObject(host, value.name) != null) return error.ManagedTableNameConflict;
            const declared = try m.prepare(host.namespace, value.name.slice(), object, operation, value.output.slice(), value.sql, host.readOptions());
            if (guard) |expected| try expected.require(declared, null, host.allocator);
            break :blk .{ .publish = declared };
        },
        .program => |value| blk: {
            if (guard != null) return error.UnsupportedProgramMigration;
            if (try namedObject(host, value.name) != null) return error.ManagedTableNameConflict;
            const declared = try g.direct.ApplicationSql.prepare(host.table, host.namespace, object, operation, value.sql);
            defer declared.deinit();
            const copy = try p.Json.valueAlloc(arena.allocator(), declared.value);
            const parsed = try p.Json.parseFromSlice(A.Declaration, arena.allocator(), copy);
            break :blk .{ .publish_program = parsed.value };
        },
        .control => |value| blk: {
            const application: A = .{ .client = host.table };
            if (try program(host, value.name)) |declared| {
                defer declared.deinit();
                if (guard != null) return error.UnsupportedProgramMigration;
                const copy = try p.Json.valueAlloc(arena.allocator(), declared.value);
                const parsed = try p.Json.parseFromSlice(A.Declaration, arena.allocator(), copy);
                const observation = try application.inspect(parsed.value);
                const role = if (value.role) |selected| try c.DirectAuthorizationSql.resolveRole(host.table, host.namespace, selected, .{}) else null;
                const saved = try application.prepareControl(parsed.value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = host.table.connection.scope, .principal = host.table.connection.principal, .operation = operation }, .target = try parsed.value.interpretation(host.allocator), .expected = observation.head.control, .command = value.command }, role);
                defer host.allocator.free(saved);
                break :blk .{ .control_program = .{ .declaration = parsed.value, .saved = try c.DirectTableProtocol.Binary.encode(arena.allocator(), saved) } };
            }
            const declared = try m.find(host.namespace, value.name) orelse return error.CatalogNameNotFound;
            // Parsed strings must outlive request serialization below.
            const copy = try p.Json.valueAlloc(arena.allocator(), declared.value);
            declared.deinit();
            const parsed = try p.Json.parseFromSlice(M.Declaration, arena.allocator(), copy);
            try requireNamed(host, parsed.value);
            const observation = try m.inspect(parsed.value);
            if (guard) |expected| try expected.require(parsed.value, observation.head.control, host.allocator);
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
    acceptance_possible.* = true;
    const ref = try ops.begin(&reader, .{ .nonce = token, .fingerprint = fingerprint, .kind = .dataflow, .binding = try host.account.database(host.database), .original = original, .source = body.content.sha256, .expected_generation = 1, .reservation = @intCast(bytes.len + 8192) }, body);
    return status(host, ref.id);
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const saved = try read(host, id);
    defer saved.deinit();
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    return .{ .command = if (saved.value.action == .publish or saved.value.action == .publish_program) .create_dataflow else .control_dataflow, .identity = .{ .account = host.account.execution.account, .id = id, .kind = .dataflow }, .token = item.nonce, .phase = if (item.phase == .terminal) .terminal else .ready, .outcome = switch (item.summary) {
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
        error.DataflowSourceChanged, error.ManagedTableNameConflict, error.ManagedTableConflict, error.DataflowIdentityConflict => {
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
        .publish_program => |value| {
            const application: A = .{ .client = m.client };
            _ = try application.publish(value);
        },
        .control_program => |value| {
            const application: A = .{ .client = m.client };
            const bytes = try value.saved.decode(m.client.allocator, c.DirectRecord.max_bytes);
            defer m.client.allocator.free(bytes);
            _ = try application.applyControl(bytes);
        },
    }
}

test {
    std.testing.refAllDecls(@This());
}

/// Original accepted definition, independent of current name lookup.
pub fn definition(host: *g.Session, id: u64) !p.DataLifecycle.Definition {
    const saved = try read(host, id);
    defer saved.deinit();
    return saved.value.interpretation(host.allocator);
}

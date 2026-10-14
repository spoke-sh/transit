//! Authenticated classic-command engine over a host's shared SQL owner.
const std = @import("std");
const m = @import("root.zig");
const g = m.gateway;
pub fn Engine(comptime Host: type, comptime Transport: type) type {
    return struct {
        const Self = @This();
        const Statement = struct { id: u32, prepared: *Host.Prepared, parameters: m.Command.Parameters = .{} };
        allocator: std.mem.Allocator,
        host: *Host,
        transport: *Transport,
        limits: g.Limits,
        flags: u32,
        backend: m.Backend,
        statements: [64]?Statement = @splat(null),
        next_id: u32 = 1,
        transport_failed: bool = false,
        pub fn init(allocator: std.mem.Allocator, host: *Host, transport: *Transport, limits: g.Limits, flags: u32) !Self {
            try limits.validate();
            if (flags & ~m.Handshake.capabilities != 0 or flags & m.Handshake.required != m.Handshake.required) return error.UnsupportedWireCapabilities;
            return .{ .allocator = allocator, .host = host, .transport = transport, .limits = limits, .flags = flags, .backend = .{ .allocator = allocator, .maximum = limits.frame_bytes } };
        }
        pub fn deinit(self: *Self) void {
            self.clear();
            self.backend.deinit();
            self.* = undefined;
        }
        fn clear(self: *Self) void {
            for (&self.statements) |*slot| if (slot.*) |value| {
                self.host.destroy(value.prepared);
                slot.* = null;
            };
        }
        fn index(self: *Self, id: u32) ?usize {
            for (self.statements, 0..) |slot, i| if (slot) |value| if (value.id == id) return i;
            return null;
        }
        fn send(self: *Self, bytes: []const u8) !void {
            errdefer self.transport_failed = true;
            try self.transport.writeAll(bytes);
        }
        fn metadataEnd(self: *Self) !void {
            if (self.flags & m.Handshake.deprecate_eof == 0) try self.send(try self.backend.eof());
        }
        fn resultEnd(self: *Self) !void {
            try self.send(if (self.flags & m.Handshake.deprecate_eof != 0) try self.backend.ok(0, true) else try self.backend.eof());
        }
        fn columns(prepared: *Host.Prepared, buffer: []m.Backend.Column) ![]const m.Backend.Column {
            const fields = prepared.fields();
            if (fields.len > buffer.len) return error.InvalidWireColumns;
            for (fields, buffer[0..fields.len]) |field, *column| column.* = .{ .name = field.name, .type = try g.Type.from(field) };
            return buffer[0..fields.len];
        }
        fn prepare(self: *Self, sql: []const u8) !void {
            const free = for (self.statements[0..self.limits.prepared_statements], 0..) |slot, i| {
                if (slot == null) break i;
            } else return error.TooManyWireStatements;
            if (self.next_id == std.math.maxInt(u32)) return error.WireSessionExhausted;
            const prepared = try self.host.prepare(sql);
            errdefer self.host.destroy(prepared);
            if (prepared.empty()) return error.EmptyWireQuery;
            try self.host.validate(prepared);
            const parameters = prepared.parameters();
            if (parameters.len > g.Limits.max_parameters) return error.TooManyWireParameters;
            var buffer: [g.Limits.max_parameters]m.Backend.Column = undefined;
            const fields = try columns(prepared, &buffer);
            const id = self.next_id;
            self.next_id += 1;
            try self.send(try self.backend.prepared(id, fields.len, parameters.len));
            for (parameters) |logical| try self.send(try self.backend.describe(.{ .name = "?", .type = try g.Type.from(.{ .name = "?", .type = logical, .nullable = true }) }));
            if (parameters.len != 0) try self.metadataEnd();
            for (fields) |column| try self.send(try self.backend.describe(column));
            if (fields.len != 0) try self.metadataEnd();
            self.statements[free] = .{ .id = id, .prepared = prepared };
        }
        fn execute(self: *Self, prepared: *Host.Prepared, values: []const ?g.fuze.Types.Values.Atom, binary: bool) !void {
            if (prepared.empty()) return error.EmptyWireQuery;
            try self.host.bind(prepared, values);
            try self.host.validate(prepared);
            if (prepared.mutation()) {
                const result = try self.host.write(prepared, values);
                const affected = if (result.kind == .update and self.flags & m.Handshake.found_rows == 0) result.changed else result.count;
                try self.send(try self.backend.ok(affected, false));
                return;
            }
            const read = try self.host.openRead(prepared, values);
            defer self.host.closeRead(read);
            var buffer: [g.Limits.max_parameters]m.Backend.Column = undefined;
            const fields = try columns(prepared, &buffer);
            try self.send(try self.backend.columns(fields.len));
            for (fields) |column| try self.send(try self.backend.describe(column));
            try self.metadataEnd();
            while (try read.next()) |cells| {
                const bytes = try self.backend.row(fields, cells, binary);
                try self.host.validate(prepared);
                try self.send(bytes);
            }
            try self.host.validate(prepared);
            try self.resultEnd();
        }
        pub fn handle(self: *Self, payload: []const u8) !bool {
            self.backend.sequence = 1;
            defer self.host.end();
            return self.process(payload) catch |err| {
                // CLOSE has no reply. An invalid no-response command closes the
                // connection instead of leaving an unexpected ERR for the next SQL.
                if (self.transport_failed or (payload.len > 0 and (payload[0] == 0x19 or payload[0] == 0x18))) return err;
                const diagnostic = self.host.diagnostic(err);
                const Mapping = struct { source: [5]u8, code: u16, state: [5]u8 };
                const mappings = [_]Mapping{
                    .{ .source = "42501".*, .code = 1142, .state = "42000".* },
                    .{ .source = "57014".*, .code = 1317, .state = "70100".* },
                    .{ .source = "0A000".*, .code = 1235, .state = "42000".* },
                    .{ .source = "22003".*, .code = 1264, .state = "22003".* },
                    .{ .source = "22001".*, .code = 1406, .state = "22001".* },
                    .{ .source = "23505".*, .code = 1062, .state = "23000".* },
                    .{ .source = "23502".*, .code = 1048, .state = "23000".* },
                    .{ .source = "42P07".*, .code = 1050, .state = "42S01".* },
                    .{ .source = "42P01".*, .code = 1146, .state = "42S02".* },
                    .{ .source = "42601".*, .code = 1064, .state = "42000".* },
                    .{ .source = "26000".*, .code = 1243, .state = "HY000".* },
                    .{ .source = "28000".*, .code = 1045, .state = "28000".* },
                };
                const mapping = for (mappings) |value| {
                    if (std.mem.eql(u8, &diagnostic.state, &value.source)) break value;
                } else Mapping{ .source = diagnostic.state, .code = 1105, .state = "HY000".* };
                var message: [512]u8 = undefined;
                const text = if (diagnostic.detail) |detail| try std.fmt.bufPrint(&message, "{s}; {s}", .{ diagnostic.message, detail }) else diagnostic.message;
                try self.send(try self.backend.failure(mapping.code, mapping.state, text));
                return true;
            };
        }
        fn process(self: *Self, payload: []const u8) !bool {
            const command = try m.Command.decode(payload);
            if (command == .quit) return false;
            try self.host.begin();
            switch (command) {
                .query => |sql| {
                    const prepared = try self.host.prepare(sql);
                    defer self.host.destroy(prepared);
                    try self.execute(prepared, &.{}, false);
                },
                .prepare => |sql| try self.prepare(sql),
                .execute => |body| {
                    const id = try m.Command.statementId(body);
                    const slot = &self.statements[self.index(id) orelse return error.UnknownWireStatement].?;
                    var kinds: [g.Limits.max_parameters]g.Type.Kind = undefined;
                    const types = slot.prepared.parameters();
                    if (types.len > kinds.len) return error.TooManyWireParameters;
                    for (types, kinds[0..types.len]) |logical, *kind| kind.* = (try g.Type.from(.{ .name = "?", .type = logical, .nullable = true })).kind;
                    const bound = try slot.parameters.execute(body, id, kinds[0..types.len]);
                    try self.execute(slot.prepared, bound.values[0..bound.count], true);
                },
                .close => |id| if (self.index(id)) |i| {
                    self.host.destroy(self.statements[i].?.prepared);
                    self.statements[i] = null;
                },
                .reset => |id| {
                    const prepared = self.statements[self.index(id) orelse return error.UnknownWireStatement].?.prepared;
                    try self.host.validate(prepared);
                    // No long data or cursor exists in this profile. Upstream
                    // RESET preserves parameter type bindings for future Execute.
                    try self.send(try self.backend.ok(0, false));
                },
                .database => |name| {
                    try self.host.selectDatabase(name);
                    self.clear();
                    try self.send(try self.backend.ok(0, false));
                },
                .reset_connection => {
                    try self.host.reset();
                    self.clear();
                    try self.send(try self.backend.ok(0, false));
                },
                .ping => try self.send(try self.backend.ok(0, false)),
                .quit => unreachable,
            }
            return true;
        }
    };
}

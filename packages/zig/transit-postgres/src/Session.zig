//! Authenticated command engine. Host owns SQL preparation, current authority,
//! execution, cancellation and credentials; transport owns deadlines/backpressure.
const std = @import("std");
const pg = @import("root.zig");
const g = pg.gateway;
const f = g.fuze;
const Name = struct {
    bytes: [g.Limits.max_name_bytes]u8 = undefined,
    len: u8,
    fn init(value: []const u8) !Name {
        if (value.len > g.Limits.max_name_bytes) return error.InvalidWireName;
        var result: Name = .{ .len = @intCast(value.len) };
        @memcpy(result.bytes[0..value.len], value);
        return result;
    }
    fn matches(self: *const Name, value: []const u8) bool {
        return std.mem.eql(u8, self.bytes[0..self.len], value);
    }
};
/// Host.Prepared supplies parameters/fields/mutation/empty. Host methods prepare,
/// destroy, validate, bind, openRead, closeRead, write, begin/end and diagnostic
/// keep database/probe policy out of the protocol. Read.nextBatch owns at most
/// the requested rows until its next call/close. No batch crosses Execute.
/// write returns the shared, owner-attributed CommandCompletion.
pub fn Engine(comptime Host: type, comptime Transport: type) type {
    return struct {
        const Self = @This();
        const Prepared = struct { name: Name, value: *Host.Prepared, oids: [g.Limits.max_parameters]u32 = undefined, count: u16 };
        const Portal = struct {
            name: Name,
            id: u64,
            statement: usize,
            arena: std.heap.ArenaAllocator,
            values: []const ?f.Types.Values.Atom,
            formats: pg.Frontend.Formats,
            read: ?*Host.Read = null,
            rows: u64 = 0,
            complete: bool = false,
        };
        allocator: std.mem.Allocator,
        host: *Host,
        transport: *Transport,
        backend: pg.Backend,
        cycle: pg.Cycle,
        statements: [64]?Prepared = @splat(null),
        portals: [8]?Portal = @splat(null),
        next_portal: u64 = 1,
        deferred: ?usize = null,
        transport_failed: bool = false,
        valid_sync: bool = false,
        pub fn init(allocator: std.mem.Allocator, host: *Host, transport: *Transport, limits: g.Limits) !Self {
            return .{ .allocator = allocator, .host = host, .transport = transport, .backend = .{ .allocator = allocator, .maximum = limits.frame_bytes }, .cycle = try pg.Cycle.init(limits) };
        }
        pub fn deinit(self: *Self) void {
            self.clearPortals();
            for (&self.statements) |*slot| if (slot.*) |item| self.host.destroy(item.value);
            self.backend.deinit();
            self.* = undefined;
        }
        fn send(self: *Self, bytes: []const u8) !void {
            errdefer self.transport_failed = true;
            try self.transport.writeAll(bytes);
        }
        fn statementIndex(self: *Self, name: []const u8) ?usize {
            for (&self.statements, 0..) |*slot, i| if (slot.*) |*value| if (value.name.matches(name)) return i;
            return null;
        }
        fn portalIndex(self: *Self, name: []const u8) ?usize {
            for (&self.portals, 0..) |*slot, i| if (slot.*) |*value| if (value.name.matches(name)) return i;
            return null;
        }
        fn closePortal(self: *Self, i: usize) void {
            if (self.portals[i]) |*value| {
                if (value.read) |read| self.host.closeRead(read);
                value.arena.deinit();
                self.portals[i] = null;
            }
            if (self.deferred == i) self.deferred = null;
        }
        fn clearPortals(self: *Self) void {
            for (0..self.portals.len) |i| self.closePortal(i);
        }
        fn closeStatement(self: *Self, i: usize) void {
            // PostgreSQL Close(statement) also closes its dependent portals.
            for (self.portals, 0..) |slot, j| if (slot) |value| if (value.statement == i) self.closePortal(j);
            if (self.statements[i]) |value| self.host.destroy(value.value);
            self.statements[i] = null;
        }
        fn parse(self: *Self, input: pg.Frontend.Parse) !void {
            if (self.statementIndex(input.name)) |i| {
                if (input.name.len != 0) return error.DuplicateWireStatement;
                self.closeStatement(i);
            }
            const index = for (self.statements[0..self.cycle.limits.prepared_statements], 0..) |slot, i| {
                if (slot == null) break i;
            } else return error.TooManyWireStatements;
            const value = try self.host.prepare(input.sql);
            errdefer self.host.destroy(value);
            const types = value.parameters();
            if (types.len > g.Limits.max_parameters or input.count > types.len) return error.WireParameterCountMismatch;
            var prepared: Prepared = .{ .name = try Name.init(input.name), .value = value, .count = @intCast(types.len) };
            for (types, 0..) |logical, i| {
                const kind = (try g.Type.from(.{ .name = "", .type = logical, .nullable = true })).kind;
                prepared.oids[i] = try pg.Scalar.resolve(kind, if (i < input.count) input.oids[i] else 0);
            }
            self.statements[index] = prepared;
        }
        fn bind(self: *Self, input: pg.Frontend.Bind) !usize {
            return self.bindInner(input, false);
        }
        fn bindInner(self: *Self, input: pg.Frontend.Bind, validated: bool) !usize {
            if (self.portalIndex(input.portal)) |i| {
                if (input.portal.len != 0) return error.DuplicateWirePortal;
                self.closePortal(i);
            }
            const index = for (self.portals[0..self.cycle.limits.portals], 0..) |slot, i| {
                if (slot == null) break i;
            } else return error.TooManyWirePortals;
            const statement = self.statementIndex(input.statement) orelse return error.UnknownWireStatement;
            const prepared = &self.statements[statement].?;
            const types = prepared.value.parameters();
            if (input.count != types.len) return error.WireParameterCountMismatch;
            try input.results.validate(prepared.value.fields().len);
            if (!validated) try self.host.validate(prepared.value);
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            errdefer arena.deinit();
            const allocator = arena.allocator();
            const values = try allocator.alloc(?f.Types.Values.Atom, types.len);
            for (types, values, 0..) |logical, *value, i| {
                const kind = (try g.Type.from(.{ .name = "", .type = logical, .nullable = true })).kind;
                const bytes = if (input.values[i]) |raw| try allocator.dupe(u8, raw) else null;
                value.* = try pg.Scalar.decode(allocator, kind, prepared.oids[i], input.formats.at(i), bytes);
            }
            try self.host.bind(prepared.value, values);
            if (self.next_portal == std.math.maxInt(u64)) return error.WireSessionExhausted;
            self.portals[index] = .{ .name = try Name.init(input.portal), .id = self.next_portal, .statement = statement, .arena = arena, .values = values, .formats = input.results };
            self.next_portal += 1;
            return index;
        }
        fn columns(self: *Self, value: *Host.Prepared, buffer: []pg.Backend.Column) ![]const pg.Backend.Column {
            _ = self;
            const fields = value.fields();
            if (fields.len > buffer.len) return error.InvalidWireColumns;
            for (fields, buffer[0..fields.len]) |field, *column| column.* = .{ .name = field.name, .type = try g.Type.from(field) };
            return buffer[0..fields.len];
        }
        fn describe(self: *Self, target: pg.Frontend.Target) !void {
            return self.describeInner(target, false);
        }
        fn describeInner(self: *Self, target: pg.Frontend.Target, validated: bool) !void {
            var formats: pg.Frontend.Formats = .{};
            const index = switch (target.kind) {
                .statement => self.statementIndex(target.name) orelse return error.UnknownWireStatement,
                .portal => blk: {
                    const portal = &self.portals[self.portalIndex(target.name) orelse return error.UnknownWirePortal].?;
                    formats = portal.formats;
                    break :blk portal.statement;
                },
            };
            const prepared = &self.statements[index].?;
            if (!validated) try self.host.validate(prepared.value);
            if (target.kind == .statement) try self.send(try self.backend.parameters(prepared.oids[0..prepared.count]));
            var buffer: [g.Limits.max_parameters]pg.Backend.Column = undefined;
            const fields = try self.columns(prepared.value, &buffer);
            if (fields.len == 0) try self.send(try self.backend.empty(.no_data)) else try self.send(try self.backend.describe(fields, &formats));
        }
        fn execute(self: *Self, index: usize, maximum: u32) !void {
            return self.executeInner(index, maximum, false);
        }
        fn executeInner(self: *Self, index: usize, maximum: u32, validated: bool) !void {
            const portal = &self.portals[index].?;
            if (portal.complete) return error.CompletedWirePortal;
            const prepared = self.statements[portal.statement].?.value;
            if (!validated) try self.host.validate(prepared);
            if (prepared.empty()) {
                portal.complete = true;
                try self.send(try self.backend.empty(.empty_query));
                return;
            }
            if (prepared.mutation()) {
                const result = try self.host.write(prepared, portal.values);
                try result.validate();
                if (result.outcome != .applied and result.outcome != .unchanged and result.outcome != .provisional) return error.InvalidWireCompletion;
                portal.complete = true;
                try self.send(try self.backend.complete(result.kind, if (result.counts) |counts| counts.matched else 0));
                return;
            }
            if (portal.read == null) portal.read = try self.host.openRead(prepared, portal.values);
            var buffer: [g.Limits.max_parameters]pg.Backend.Column = undefined;
            const fields = try self.columns(prepared, &buffer);
            var emitted: u32 = 0;
            while (maximum == 0 or emitted < maximum) {
                const requested: u8 = @intCast(if (maximum == 0) g.ReadBatch.max_rows else @min(g.ReadBatch.max_rows, maximum - emitted));
                const batch = try portal.read.?.nextBatch(requested);
                try batch.validate(requested);
                // Check the current account/statement after materialization and
                // before any row in this bounded batch enters the transport.
                try portal.read.?.validateDisclosure();
                for (batch.rows[0..batch.len]) |cells| {
                    try self.send(try self.backend.row(fields, &portal.formats, cells.?));
                    portal.rows += 1;
                }
                if (batch.complete) {
                    portal.complete = true;
                    self.host.closeRead(portal.read.?);
                    portal.read = null;
                    try self.send(try self.backend.complete(.select, portal.rows));
                    return;
                }
                // Zero means unlimited-by-protocol, still bounded by query work.
                if (maximum != 0) emitted += batch.len;
            }
            try self.cycle.suspendRead();
            try self.send(try self.backend.empty(.suspended));
        }
        fn simple(self: *Self, sql: []const u8) !void {
            if (self.statementIndex("")) |i| self.closeStatement(i);
            if (self.portalIndex("")) |i| self.closePortal(i);
            if (std.mem.trim(u8, sql, " \t\r\n;").len == 0) {
                try self.send(try self.backend.empty(.empty_query));
                return;
            }
            try self.parse(.{ .name = "", .sql = sql, .count = 0 });
            const index = try self.bindInner(.{ .portal = "", .statement = "", .count = 0, .formats = .{}, .results = .{} }, true);
            defer self.closePortal(index);
            const prepared = self.statements[self.portals[index].?.statement].?.value;
            if (prepared.fields().len != 0) try self.describeInner(.{ .kind = .portal, .name = "" }, true);
            try self.executeInner(index, 0, true);
        }
        /// Process one complete frame. Framing errors belong to the caller and
        /// close the transport; command errors drain until Sync. Return false on X.
        pub fn handle(self: *Self, tag: u8, payload: []const u8) !bool {
            self.valid_sync = false;
            return self.process(tag, payload) catch |err| {
                if (self.transport_failed) return err;
                self.clearPortals();
                const diagnostic = self.host.diagnostic(err);
                try self.send(try self.backend.failure(false, diagnostic.state, diagnostic.message, diagnostic.detail));
                if (tag == 'Q' and self.cycle.state == .idle or self.valid_sync) {
                    self.host.end();
                    try self.send(try self.backend.ready(self.host.transactionStatus()));
                } else self.cycle.fail();
                return true;
            };
        }
        fn process(self: *Self, tag: u8, payload: []const u8) !bool {
            // Failed cycles retain only frame boundaries; Sync/X still require
            // exact bodies before they can reset state or close the session.
            if (self.cycle.state == .failed and tag != 'S' and tag != 'X') return true;
            const message = try pg.Frontend.decode(tag, payload);
            self.valid_sync = message == .sync;
            if (self.cycle.state == .idle and tag != 'S' and tag != 'X') try self.host.begin();
            const action = try self.cycle.accept(tag, payload.len + 5);
            switch (action) {
                .terminate => return false,
                .ignore, .flush => return true,
                .sync_empty, .sync_write => {
                    if (action == .sync_write) try self.execute(self.deferred orelse return error.UnknownWirePortal, 0);
                    self.clearPortals();
                    self.host.end();
                    try self.send(try self.backend.ready(self.host.transactionStatus()));
                    return true;
                },
                .handle => {},
            }
            switch (message) {
                .query => |sql| {
                    try self.simple(sql);
                    self.host.end();
                    try self.send(try self.backend.ready(self.host.transactionStatus()));
                },
                .parse => |input| {
                    try self.parse(input);
                    try self.send(try self.backend.empty(.parse_complete));
                },
                .bind => |input| {
                    _ = try self.bind(input);
                    try self.send(try self.backend.empty(.bind_complete));
                },
                .describe => |target| try self.describe(target),
                .close => |target| {
                    switch (target.kind) {
                        .statement => if (self.statementIndex(target.name)) |i| self.closeStatement(i),
                        .portal => if (self.portalIndex(target.name)) |i| self.closePortal(i),
                    }
                    try self.send(try self.backend.empty(.close_complete));
                },
                .execute => |input| {
                    const index = self.portalIndex(input.portal) orelse return error.UnknownWirePortal;
                    const portal = &self.portals[index].?;
                    const mutation = self.statements[portal.statement].?.value.mutation();
                    try self.cycle.execute(portal.id, mutation, input.rows);
                    if (mutation) self.deferred = index else try self.execute(index, input.rows);
                },
                else => unreachable,
            }
            return true;
        }
    };
}

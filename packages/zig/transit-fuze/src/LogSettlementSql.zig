//! Pure Queue lease settlement preparation. Decoding a receipt supplies no
//! current authority or evidence that a lease remains live.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Atom = f.Types.Values.Atom;
pub const Kind = enum { ack, extend };
pub const Target = struct { kind: Kind, source: Reference };

fn header(parser: *Parser) !Target {
    const kind: Kind = if (try parser.takeWord("ACK")) .ack else if (try parser.takeWord("EXTEND")) blk: {
        try parser.requireWord("LEASE");
        break :blk .extend;
    } else return error.UnsupportedStatement;
    try parser.requireWord("ON");
    try parser.requireWord("QUEUE");
    return .{ .kind = kind, .source = try Reference.unqualified(parser, .source) };
}
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Target {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return header(&parser);
}

const Operand = struct {
    kind: f.Types.Type,
    value: union(enum) { literal: struct { bytes: []const u8, offset: usize }, parameter: f.Sql.Parameter },
    fn parse(parser: *Parser, kind: f.Types.Type) !Operand {
        if (try parser.parameter()) |site| return .{ .kind = kind, .value = .{ .parameter = site } };
        const literal = try parser.literal(kind);
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, kind, &failure) catch |err| {
            if (parser.location) |where| where.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidLogSettlementOperand;
        return .{ .kind = kind, .value = .{ .literal = .{ .bytes = cell.value.atom.bytes, .offset = literal.span.start } } };
    }
    fn at(self: Operand, diagnostic: ?*f.Sql.Binding) void {
        const detail = diagnostic orelse return;
        detail.expected = @tagName(self.kind);
        switch (self.value) {
            .literal => |value| detail.location = .{ .offset = value.offset },
            .parameter => |site| {
                detail.location = .{ .offset = site.offset };
                detail.parameter = site.index;
                detail.parameter_sites[0] = site.offset;
            },
        }
    }
    fn bind(self: Operand, values: []const ?Atom, diagnostic: ?*f.Sql.Binding) ![]const u8 {
        errdefer self.at(diagnostic);
        return switch (self.value) {
            .literal => |value| value.bytes,
            .parameter => |site| blk: {
                const value = values[site.index - 1] orelse return error.NullWorkloadParameter;
                f.LogicalPrepared.validate(value, self.kind) catch |err| {
                    if (diagnostic) |detail| detail.actual = @tagName(value);
                    return err;
                };
                break :blk value.bytes;
            },
        };
    }
};

pub const Bound = struct { lease: p.StreamQueue.Lease, action: @FieldType(p.StreamQueue.Settlement, "action") };
pub const Prepared = struct {
    arena: std.heap.ArenaAllocator,
    target: Target,
    receipt: Operand,
    extension: ?Operand,
    // Exactly two syntax sites: receipt and optional extension. This is a
    // statement-shape bound, independent of durable Queue cardinality.
    types: [2]f.Types.Type = undefined,
    count: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, diagnostic: ?*f.Sql.Binding) !Prepared {
        if (diagnostic) |detail| detail.* = .{};
        try f.Sql.validateText(text);
        var arena: std.heap.ArenaAllocator = .init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        var location: f.Sql.Location = .{};
        errdefer if (diagnostic) |detail| if (detail.location == null) {
            detail.location = location;
        };
        var parser = try Parser.initDialect(a, try a.dupe(u8, text), &location, true, dialect);
        const selected = try header(&parser);
        try parser.requireWord("RECEIPT");
        const receipt = try Operand.parse(&parser, .binary);
        const extension: ?Operand = if (selected.kind == .extend) blk: {
            try parser.requireWord("BY");
            break :blk try Operand.parse(&parser, .utf8);
        } else null;
        try parser.finish();
        var result: Prepared = .{ .arena = undefined, .target = selected, .receipt = receipt, .extension = extension };
        var sites: [2]?f.Sql.Parameter = @splat(null);
        for ([_]?Operand{ receipt, extension }) |optional| if (optional) |operand| {
            if (operand.value != .parameter) continue;
            const site = operand.value.parameter;
            operand.at(diagnostic);
            if (site.index == 0) return error.InvalidParameterIndex;
            if (site.index > sites.len) return error.ParameterGap;
            const index = site.index - 1;
            if (sites[index] != null and !try result.types[index].eql(operand.kind)) return error.ParameterTypeConflict;
            sites[index] = site;
            result.types[index] = operand.kind;
            result.count = @max(result.count, @as(u8, @intCast(site.index)));
        };
        for (sites[0..result.count], 0..) |site, i| if (site == null) {
            if (diagnostic) |detail| detail.missing_parameter = @intCast(i + 1);
            return error.ParameterGap;
        };
        result.arena = arena;
        if (diagnostic) |detail| detail.* = .{};
        return result;
    }
    pub fn deinit(self: *Prepared) void {
        self.arena.deinit();
        self.* = undefined;
    }
    pub fn parameterTypes(self: *const Prepared) []const f.Types.Type {
        return self.types[0..self.count];
    }
    /// The result owns all bytes by value. It neither reads a clock nor changes
    /// an operation identity; the Catalog/native owner supplies those boundaries.
    pub fn bind(self: *const Prepared, values: []const ?Atom, diagnostic: ?*f.Sql.Binding) !Bound {
        if (diagnostic) |detail| detail.* = .{};
        if (values.len != self.count) {
            if (diagnostic) |detail| {
                detail.expected_count = self.count;
                detail.actual_count = values.len;
            }
            return error.ParameterCountMismatch;
        }
        const lease = p.QueueLeaseHandle.decode(try self.receipt.bind(values, diagnostic)) catch |err| {
            self.receipt.at(diagnostic);
            return if (err == error.IncompatibleDefinition) err else error.InvalidQueueLeaseHandle;
        };
        const action: @FieldType(p.StreamQueue.Settlement, "action") = if (self.extension) |operand| blk: {
            errdefer operand.at(diagnostic);
            const duration = try @import("LogReadSql.zig").leaseDuration(try operand.bind(values, diagnostic));
            break :blk .{ .extend = .{ .expires_ms = std.math.add(u64, lease.expires_ms, duration) catch return error.InvalidLogLeaseDuration } };
        } else .ack;
        return .{ .lease = lease, .action = action };
    }
};

const test_lease: p.StreamQueue.Lease = .{
    .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 }, .revision = 4, .digest = @splat(5) }, .partition = 2 },
    .claim = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 9, .operation = 10 },
    .offset = 11,
    .epoch = 12,
    .attempt = 13,
    .expires_ms = 1000,
};
fn testOwned(allocator: std.mem.Allocator) !void {
    var sql = "EXTEND LEASE ON QUEUE jobs RECEIPT $2 BY $1".*;
    var prepared = try Prepared.init(allocator, &sql, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    @memset(&sql, 0);
    try std.testing.expectEqualSlices(f.Types.Type, &.{ .utf8, .binary }, prepared.parameterTypes());
    var handle: [p.QueueLeaseHandle.encoded_bytes]u8 = undefined;
    try p.QueueLeaseHandle.encode(test_lease, &handle);
    var duration = "2s".*;
    const bound = try prepared.bind(&.{ .{ .bytes = &duration }, .{ .bytes = &handle } }, null);
    prepared.deinit();
    live = false;
    @memset(&handle, 0);
    @memset(&duration, 0);
    try std.testing.expectEqualDeep(test_lease, bound.lease);
    try std.testing.expectEqual(@as(u64, 3000), bound.action.extend.expires_ms);
}
test "log settlement SQL owns exact receipt and extends its recorded deadline" {
    try testOwned(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, testOwned, .{});
}
test "log settlement SQL enforces typed complete operands without acquiring authority" {
    const t = std.testing;
    var handle: [p.QueueLeaseHandle.encoded_bytes]u8 = undefined;
    try p.QueueLeaseHandle.encode(test_lease, &handle);
    const hex = std.fmt.bytesToHex(handle, .lower);
    const text = try std.fmt.allocPrint(t.allocator, "ACK ON QUEUE jobs RECEIPT X'{s}';", .{hex});
    defer t.allocator.free(text);
    var literal = try Prepared.init(t.allocator, text, .transit, null);
    defer literal.deinit();
    const acknowledged = try literal.bind(&.{}, null);
    try t.expect(acknowledged.action == .ack);
    try t.expectEqualDeep(test_lease, acknowledged.lease);
    var mysql = try Prepared.init(t.allocator, "EXTEND LEASE ON QUEUE `jobs` RECEIPT ? BY ?", .mysql, null);
    defer mysql.deinit();
    try t.expectEqualSlices(f.Types.Type, &.{ .binary, .utf8 }, mysql.parameterTypes());
    try t.expectError(error.ParameterCountMismatch, mysql.bind(&.{}, null));
    try t.expectError(error.NullWorkloadParameter, mysql.bind(&.{ null, .{ .bytes = "1s" } }, null));
    try t.expectError(error.InvalidLogLeaseDuration, mysql.bind(&.{ .{ .bytes = &handle }, .{ .bytes = "0ms" } }, null));
    for ([_][]const u8{ "ACK ON QUEUE jobs RECEIPT $2", "EXTEND LEASE ON QUEUE jobs RECEIPT $1 BY $1", "ACK ON QUEUE jobs RECEIPT $1 RETURNING *", "ACK ON QUEUE jobs RECEIPT $1; ACK ON QUEUE jobs RECEIPT $1" }) |invalid| {
        if (Prepared.init(t.allocator, invalid, .transit, null)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.TestUnexpectedResult;
        } else |_| {}
    }
    var diagnostic: f.Sql.Binding = .{};
    try t.expectError(error.InvalidQueueLeaseHandle, mysql.bind(&.{ .{ .bytes = "truncated" }, .{ .bytes = "1s" } }, &diagnostic));
    try t.expectEqual(@as(?u32, 1), diagnostic.parameter);
    var maximal = test_lease;
    maximal.expires_ms = std.math.maxInt(u64);
    try p.QueueLeaseHandle.encode(maximal, &handle);
    try t.expectError(error.InvalidLogLeaseDuration, mysql.bind(&.{ .{ .bytes = &handle }, .{ .bytes = "1ms" } }, null));
}

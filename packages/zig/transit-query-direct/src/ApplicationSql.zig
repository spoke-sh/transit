//! Prepare lowered Queue SQL from exact native metadata. No publication,
//! acquisition or effect occurs while resolving a program's dependencies.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const a = q.fuze.ApplicationProgram;
const Self = @This();
client: c.DirectTableClient,
namespace: u64,
arena: *std.heap.ArenaAllocator,
resources: std.ArrayList(q.ApplicationBinding) = .empty,

pub const limits: q.ApplicationDeclaration.Limits = .{
    .requests = 10000,
    .scan_rows = 10000,
    .result_bytes = 1024 * 1024,
    .continuation_bytes = 1024 * 1024,
    .retained_bytes = 16 * 1024 * 1024,
    .transaction = c.DirectTransaction.default_limits,
};

pub fn prepare(client: c.DirectTableClient, namespace: u64, object: u64, operation: u64, sql: []const u8) !std.json.Parsed(q.ApplicationDeclaration) {
    var parsed = try a.parse(client.allocator, sql, null);
    defer parsed.deinit();
    const decl_namespace = try client.resolveSchema(parsed.program.schema, namespace);
    var arena: std.heap.ArenaAllocator = .init(client.allocator);
    defer arena.deinit();
    var self: Self = .{ .client = client, .namespace = decl_namespace, .arena = &arena };
    try self.resource(parsed.program.queue_schema, parsed.program.queue, .log);
    if (parsed.program.predicate) |value| try self.expression(value);
    switch (parsed.program.body) {
        .instructions => |body| try self.block(body),
        .page => return error.ApplicationHostUnavailable,
    }
    if (parsed.program.failure) |failure| try self.block(failure.instructions);
    // A read-only preview needs a valid, non-colliding placeholder identity.
    // Publication supplies the separately accepted operation's real identity.
    var selected_object = object;
    if (selected_object == 0) {
        selected_object = 1;
        for (self.resources.items) |_| {
            var collision = false;
            for (self.resources.items) |binding| if (binding.interpretation().object.object == selected_object) {
                selected_object += 1;
                collision = true;
                break;
            };
            if (!collision) break;
        }
    }
    const result = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .namespace = decl_namespace,
        .object = selected_object,
        .operation = operation,
        .source = sql,
        .resources = self.resources.items,
        .limits = limits,
    });
    errdefer result.deinit();
    var bound = try result.value.bind(client.allocator);
    defer bound.deinit();
    try bound.requirements.requireAvailable(q.ApplicationHost.available());
    const input = result.value.resources[0];
    if (input.value != .log or input.value.log.declaration.count() != 1)
        return error.UnsupportedProgramPartitioning;
    return result;
}

const Kind = enum { table, kv, log, document };
fn resource(self: *Self, schema_name: ?[]const u8, name: []const u8, kind: Kind) !void {
    for (self.resources.items) |known| if (a.Types.sameResource(known.schemaSlice(), known.name().slice(), schema_name, name)) return;
    if (self.resources.items.len == q.ApplicationDeclaration.max_resources) return error.ProgramTooComplex;
    const res_ns = try self.client.resolveSchema(schema_name, self.namespace);
    const response = try self.client.call(switch (kind) {
        .table => .{ .lookup = .{ .namespace = res_ns, .name = name } },
        .document => .{ .document_lookup = .{ .namespace = res_ns, .name = name } },
        .kv => .{ .kv_lookup = .{ .namespace = res_ns, .name = name } },
        .log => .{ .log_lookup = .{ .namespace = res_ns, .name = name } },
    });
    defer response.deinit();
    var value: q.ApplicationBinding = switch (response.value.result) {
        .lookup => |v| .table(v orelse return error.CatalogNameNotFound),
        .document_lookup => |v| .table((v orelse return error.CatalogNameNotFound).definition),
        .kv_lookup => |v| .kv(v orelse return error.CatalogNameNotFound),
        .log_lookup => |v| .{ .value = .{ .log = v orelse return error.CatalogNameNotFound } },
        else => return error.InvalidTableResponse,
    };
    value.schema = if (schema_name) |s| try .init(s) else null;
    // The RPC response owns schema/record bytes. Detach before its next call.
    const bytes = try c.protocol.Json.valueAlloc(self.arena.allocator(), value);
    const owned = try c.protocol.Json.parseFromSliceOwned(q.ApplicationBinding, self.arena.allocator(), bytes);
    try self.resources.append(self.arena.allocator(), owned.value);
}
fn expression(self: *Self, value: *const a.Expression) anyerror!void {
    switch (value.value) {
        .call => |call| {
            if (call.function == .current_revision) {
                if (call.arguments.len != 2) return error.ProgramArgumentMismatch;
                switch (call.arguments[0].value) {
                    .name => |doc_name| try self.resource(null, doc_name, .document),
                    .field => |field| {
                        if (field.base.value != .name) return error.ProgramArgumentMismatch;
                        try self.resource(field.base.value.name, field.name, .document);
                    },
                    else => return error.ProgramArgumentMismatch,
                }
                try self.expression(call.arguments[1]);
                return;
            }
            for (call.arguments) |argument| try self.expression(argument);
        },
        .field => |field| try self.expression(field.base),
        .unary => |unary| try self.expression(unary.operand),
        .binary => |binary| {
            try self.expression(binary.left);
            try self.expression(binary.right);
        },
        .case => |case| {
            try self.expression(case.condition);
            try self.expression(case.yes);
            try self.expression(case.no);
        },
        .text_cast => |operand| try self.expression(operand),
        .row => |items| for (items) |item| try self.expression(item),
        .null, .boolean, .integer, .text, .name => {},
    }
}
fn block(self: *Self, body: []const a.Instruction) anyerror!void {
    for (body) |instruction| switch (instruction.value) {
        .let => |binding| switch (binding.value) {
            .expression => |value| try self.expression(value),
            .get => |read| {
                try self.resource(read.schema, read.target, .kv);
                try self.expression(read.key);
            },
            .select => |read| {
                try self.resource(read.schema, read.target, .table);
                if (read.predicate) |value| try self.expression(value);
            },
            .effect => return error.ApplicationHostUnavailable,
        },
        .require => |value| try self.expression(value.condition),
        .atomic => |nested| try self.block(nested),
        .conditional => |branch| {
            try self.expression(branch.condition);
            try self.block(branch.yes);
            try self.block(branch.no);
        },
        .put => |put| {
            try self.resource(put.target_schema, put.target, .kv);
            try self.expression(put.key);
            try self.expression(put.value);
            for (put.fields) |field| try self.expression(field.value);
            if (put.expected == .revision) try self.expression(put.expected.revision);
        },
        .insert => |insert| {
            try self.resource(insert.target_schema, insert.target, .table);
            for (insert.values) |value| try self.expression(value);
        },
        .append => |append| {
            try self.resource(append.target_schema, append.target, .log);
            for (append.values) |value| try self.expression(value);
        },
        .handoff, .respond, .respond_error => return error.ApplicationHostUnavailable,
    };
}

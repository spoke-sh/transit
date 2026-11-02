//! Failed direct caller attempts remain distinct from authoritative outcomes.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.Diagnostic;
const b = c.DirectTableBridge;
const common = @import("CallerCodes.zig");
pub const entries = @import("DirectCallerCodes.zig").entries;
pub fn detail(cause: anyerror) common.Entry {
    for (entries) |entry| if (entry.cause == cause) return entry;
    if (common.fromError(cause)) |entry| return entry;
    if (c.fuze.SqlDiagnostic.category(cause)) |category| return .{ .cause = cause, .code = "table.invalid_typed_input", .category = category, .message = "The typed request violates its schema or operation bounds. Check stable identities, logical values and constraints." };
    return .{ .cause = cause, .code = "catalog.internal_failure", .category = .internal, .message = "The caller could not complete this attempt. Preserve saved work; this failure does not establish its durable outcome." };
}
fn identity(action: b.Action) ?p.DataLifecycle.Operation {
    const recovery: ?b.Recovery = switch (action) {
        .admit => |value| value,
        .operation => |value| value.reference,
        else => null,
    };
    if (recovery) |value| return switch (value) {
        .table => |reference| (reference.native() catch return null).binding.identity,
        .name_assertion => |binding| (binding.native() catch return null).identity(),
    };
    return switch (action) {
        .history => |value| value.identity() catch null,
        .retention => |value| (switch (value) {
            .acquire => |acquisition| acquisition.owner,
            .status => |owner| owner,
            .metadata, .release => |snapshot| snapshot.owner,
        }).identity() catch null,
        .dependencies => |value| switch (value) {
            .operation => |operation| (operation.binding.native() catch return null).identity(),
            else => null,
        },
        .resources => |value| switch (value) {
            .preview => |binding| (binding.native() catch return null).identity(),
            .operation => |operation| (operation.binding.native() catch return null).identity(),
            else => null,
        },
        .administration => |value| switch (value) {
            .preview_namespace => |binding| (binding.native() catch return null).identity(),
            .namespace_operation => |operation| (operation.binding.native() catch return null).identity(),
            else => null,
        },
        else => null,
    };
}
fn stage(action: b.Action) d.Stage {
    return switch (action) {
        .catalog, .lookup, .projection, .definitions => .read,
        .history => |value| if (value.isRead()) .read else .prepare,
        .retention => |value| if (value == .status or value == .metadata) .read else .prepare,
        .compile => .compile,
        .operation => |value| if (value.command == .inspect) .read else .prepare,
        .dependencies => |value| if (value != .operation or value.operation.command == .inspect) .read else .prepare,
        .resources => |value| switch (value) {
            .lookup, .list => .read,
            .operation => |operation| if (operation.command == .inspect) .read else .prepare,
            .preview => .prepare,
        },
        .administration => |value| switch (value) {
            .compile_namespace, .compile_policy => .compile,
            .namespace_operation => |operation| if (operation.command == .inspect) .read else .prepare,
            else => .prepare,
        },
        else => .prepare,
    };
}
pub fn failure(action: b.Action, cause: anyerror, location: c.fuze.Sql.Location, attempt: c.DirectTableClient.Attempt, native: ?p.ErrorCode) !d {
    if (try attempt.failure(cause, native)) |uncertain| return uncertain;
    if (action == .compile) {
        const text = action.compile.sql;
        var lexer: c.fuze.Sql.Lexer = .{ .text = text };
        const first = lexer.next() catch null;
        const ddl = if (first) |token| std.ascii.eqlIgnoreCase(token.text, "CREATE") or std.ascii.eqlIgnoreCase(token.text, "ALTER") or std.ascii.eqlIgnoreCase(token.text, "DROP") else false;
        const sql = if (ddl) c.fuze.SqlDiagnostic.tableDdl(text, cause, location) else c.fuze.SqlDiagnostic.tableDml(text, cause, location);
        if (sql) |value| return value.structured();
    }
    if (action == .administration and action.administration == .compile_policy) if (c.fuze.SqlDiagnostic.authorization(action.administration.compile_policy.sql, cause, location)) |value| return value.structured();
    const info = detail(cause);
    const at = stage(action);
    var result = try d.init(info.code, info.category, at, if (at == .read) .not_applicable else .not_submitted, if (at == .read) .none else .local_before_dispatch, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    if (identity(action)) |selected| result.identity = .{ .domain = .catalog, .id = .init(selected.operation), .realm = .init(selected.scope.realm), .resource = .init(selected.scope.resource) };
    try result.text(.operation, .caller, @tagName(action));
    if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
    try result.action(switch (info.category) {
        .access, .conflict => .inspect_scope,
        .lifecycle => .inspect_status,
        .unavailable => if (at == .read) .retry_read else .inspect_status,
        .internal, .integrity => .contact_operator,
        else => .correct_input,
    });
    try result.validate();
    return result;
}
pub fn invalidEnvelope(cause: anyerror) !d {
    var result = try d.init("catalog.invalid_envelope", if (cause == error.OutOfMemory) .unavailable else .syntax, .input, .not_submitted, .local_before_dispatch, "The caller could not read a valid bounded action. No direct operation was dispatched by this attempt.");
    result.cause = try d.Code.init(@errorName(cause));
    try result.validate();
    return result;
}

test "direct caller diagnostics preserve read evidence and actual mutation uncertainty" {
    const t = std.testing;
    for (entries) |entry| {
        const read = try failure(.{ .lookup = .{ .namespace = 1, .name = "items" } }, entry.cause, .{}, .{}, null);
        try t.expectEqualStrings(entry.code, read.code.slice());
        try t.expectEqual(entry.category, read.category);
        const local = try failure(.{ .forget = .{ .definition = p.Growth.current_definition, .digest = "invalid" } }, entry.cause, .{}, .{}, null);
        try t.expectEqual(.not_submitted, local.outcome);
        try t.expectEqual(.local_before_dispatch, local.evidence);
        try t.expectEqual(.not_applicable, read.outcome);
        try t.expectEqual(.none, read.evidence);
        const attempted: c.DirectTableClient.Attempt = .{ .mutation = .{ .action = .namespace_operation, .identity = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 2 }, .principal = 17, .operation = std.math.maxInt(u64) } } };
        const unknown = try failure(.{ .lookup = .{ .namespace = 1, .name = "items" } }, entry.cause, .{}, attempted, null);
        try t.expectEqual(.unknown, unknown.outcome);
        try t.expectEqual(std.math.maxInt(u64), try unknown.identity.?.id.value());
    }
}

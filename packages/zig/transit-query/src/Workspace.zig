//! Scoped explicit-submit SQL ingress shared by the shell and Board. A local
//! declaration is configuration, never a grant; results use current authority.
const std = @import("std");
const q = @import("root.zig");
const v = q.Values;
const b = q.Bridge;
const a = q.document.JsonValues;
const m = q.fuze.Unified;
pub const Config = struct { name: []const u8, source: v.Source, limits: v.Limits };
pub const SqlCapabilities = struct {
    version: u8 = 2,
    statement_bytes: u32 = q.fuze.Sql.max_statement_bytes,
    named_columns: u8 = 2,
    star_columns: u8 = m.max_columns,
    uint64_limits: bool = true,
    uint64_literals: bool = false,
    float64_literals: bool = false,
    null_comparison: bool = false,
    explicit_null_test: bool = true,
    writes: bool = false,
    continuous: bool = false,
};
pub const Description = struct { name: []const u8, source: b.Description, sql: SqlCapabilities = .{}, budgets: v.Limits, columns: []const v.Column };
pub const Frozen = struct { token: []const u8 };
pub const Compiled = struct { bundle: []const u8, source: v.Source, plan: v.Plan, limits: v.Limits, contract: [32]u8, schema: [32]u8 };
pub const Request = union(enum) {
    describe,
    compile: struct { sql: []const u8 },
    next: struct { namespace: []const u8, bundle: []const u8 },
    submit: Frozen,
    observe: u64,
    status: []const u8,
    page: struct { namespace: []const u8, cursor: ?[]const u8 = null },
    prepare_control: struct { namespace: []const u8, operation: enum { cancel, collect, retire } },
};
pub const Page = struct { evidence: b.Page, cells: []const []const v.Cell };
pub const Response = union(enum) {
    description: Description,
    compiled: Compiled,
    prepared: ?Frozen,
    receipt: q.protocol.Receipt,
    observation: q.UnifiedClient.Observation,
    status: ?b.Status,
    page: Page,
};
pub fn apply(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config, request: Request) !Response {
    const definition = try config.source.native(allocator);
    if (definition.resource != client.connection.resource) return error.QueryIdentityMismatch;
    const limits = try config.limits.native();
    const name = try m.Name.init(config.name);
    switch (request) {
        .describe => {
            const description = (try b.apply(allocator, client, .{ .describe = config.source })).description;
            var columns: [m.max_columns]m.Column = undefined;
            return .{ .description = .{ .name = config.name, .source = description, .budgets = config.limits, .columns = try v.foreignColumns(allocator, try definition.schema(&columns)) } };
        },
        .compile => |input| {
            const bundle = try client.compileSql(allocator, definition, name, input.sql, limits);
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            var columns: [m.max_columns]m.Column = undefined;
            return .{ .compiled = .{ .bundle = try a.hex(allocator, try bundle.encode(&buffer)), .source = config.source, .plan = try v.Plan.fromNative(allocator, bundle.plan), .limits = config.limits, .contract = try definition.fingerprint(), .schema = try (try definition.schema(&columns)).fingerprint() } };
        },
        .next => |input| {
            const bundle = try q.Bundle.decode(allocator, try v.unhex(allocator, input.bundle, q.Bundle.max_bytes));
            if (!std.mem.eql(u8, &try bundle.source.fingerprint(), &try definition.fingerprint())) return error.QueryIdentityMismatch;
            if (!limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
            const result = (try b.apply(allocator, client, .{ .next = .{ .namespace = input.namespace, .bundle = input.bundle } })).prepared;
            return .{ .prepared = if (result) |token| .{ .token = token } else null };
        },
        .submit => |input| return .{ .receipt = (try b.apply(allocator, client, .{ .submit = input.token })).receipt },
        .observe => |input| return .{ .observation = (try b.apply(allocator, client, .{ .observe = input })).observation },
        .status => |input| return .{ .status = (try b.apply(allocator, client, .{ .status = input })).status },
        .prepare_control => |input| {
            const command: b.Command = switch (input.operation) {
                .cancel => .{ .cancel = input.namespace },
                .collect => .{ .collect = input.namespace },
                .retire => .{ .retire = input.namespace },
            };
            const token = (try b.apply(allocator, client, .{ .prepare = command })).prepared.?;
            return .{ .prepared = .{ .token = token } };
        },
        .page => |input| {
            const page = (try b.apply(allocator, client, .{ .page = .{ .namespace = input.namespace, .cursor = input.cursor } })).page;
            if (!std.mem.eql(u8, &page.manifest.basis.contract, &try definition.fingerprint())) return error.QueryIdentityMismatch;
            // Decode the already verified complete-result page through the same
            // shared reader exposed to SDKs. No app-specific value decoder runs.
            const cells = (try v.apply(allocator, .{ .inspect_arrow = .{ .columns = page.columns, .rows = page.rows, .ipc = page.ipc } })).rows;
            return .{ .page = .{ .evidence = page, .cells = cells } };
        },
    }
}

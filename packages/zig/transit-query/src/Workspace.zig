//! Scoped explicit-submit SQL ingress shared by the shell and Board. A local
//! declaration is configuration, never a grant; results use current authority.
const std = @import("std");
const q = @import("root.zig");
const v = q.Values;
const b = q.Bridge;
const a = q.document.JsonValues;
const m = q.fuze.Unified;
pub const schema_options: q.protocol.Schema.Options = .{ .output = true, .safe_integers = true, .sequence_max_length = 8, .text_max_length = 131072 };
pub const request_schema_options: q.protocol.Schema.Options = .{ .safe_integers = true, .sequence_max_length = 8, .text_max_length = 131072 };
pub const Config = struct { name: []const u8, source: v.Source, limits: v.Limits };
pub const SqlCapabilities = struct {
    version: u8 = 1,
    statement_bytes: u32 = q.fuze.Sql.max_statement_bytes,
    named_columns: u8 = m.max_columns,
    star_columns: u8 = m.max_columns,
    uint64_limits: bool = true,
    uint64_literals: bool = true,
    float64_literals: bool = true,
    null_comparison: bool = false,
    explicit_null_test: bool = true,
    writes: bool = false,
    continuous: bool = false,
};
pub const Description = struct { connection: q.UnifiedClient.Connection, name: []const u8, source: b.Description, sql: SqlCapabilities = .{}, budgets: v.Limits, columns: []const v.Column };
pub const Frozen = struct { token: []const u8 };
pub const Draft = struct {
    generation: []const u8,
    limit: u8,
    starts: u8,
    enabled: bool,
    contract: [32]u8,
    budgets: v.Limits,
    namespaces: [q.Draft.max_starts][]const u8,
    pub fn fromNative(allocator: std.mem.Allocator, value: q.Draft.Record) !Draft {
        var result: Draft = .{ .generation = try a.decimal(allocator, value.generation), .limit = value.open.limit, .starts = value.starts, .enabled = value.enabled, .contract = value.open.contract, .budgets = try v.Limits.fromNative(allocator, value.open.limits), .namespaces = undefined };
        for (&result.namespaces, value.namespaces) |*to, from| to.* = try a.decimal(allocator, from);
        return result;
    }
};
pub const Compiled = q.SqlCompilation.Result;
pub const Request = union(enum) {
    describe,
    sql_capabilities,
    suggest: struct { search: []const u8 },
    assist: q.Assistance.Request,
    compile: struct { sql: []const u8, parameters: ?[]const v.Scalar = null },
    inspect: struct { sql: []const u8 },
    next: struct { namespace: []const u8, bundle: []const u8 },
    next_draft: struct { namespace: []const u8, bundle: []const u8, generation: []const u8 },
    draft_open: struct { expected: []const u8, limit: u8 },
    draft_close: []const u8,
    draft_status: ?[]const u8,
    submit: Frozen,
    observe: u64,
    status: []const u8,
    page: struct { namespace: []const u8, cursor: ?[]const u8 = null },
    prepare_control: struct { namespace: []const u8, operation: enum { cancel, collect, retire } },
};
pub const Page = struct { evidence: b.Page, cells: []const []const v.Cell };
pub const Response = union(enum) {
    description: Description,
    sql_capabilities: q.SqlCompilation.Capabilities,
    suggestions: struct { resource: u64, contract: [32]u8, items: []const q.Editor.Item },
    assistance: q.Assistance.Response,
    compiled: Compiled,
    inspection: q.SqlInspection.Result,
    prepared: ?Frozen,
    receipt: q.protocol.Receipt,
    observation: q.UnifiedClient.Observation,
    status: ?b.Status,
    page: Page,
    draft: ?Draft,
};
pub fn apply(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config, request: Request) !Response {
    const definition = try config.source.native(allocator);
    if (definition.resource != client.connection.resource) return error.QueryIdentityMismatch;
    const limits = try config.limits.native();
    const name = try m.Name.init(config.name);
    switch (request) {
        .sql_capabilities => return .{ .sql_capabilities = .{} },
        .inspect => |value| return .{ .inspection = try client.inspectSql(allocator, .{ .scope = .{ .name = config.name, .source = config.source, .limits = config.limits }, .sql = value.sql }) },
        .assist => |value| {
            _ = try client.describe(definition);
            var columns: [m.max_columns]m.Column = undefined;
            const result = try q.Assistance.complete(allocator, name, try definition.schema(&columns), value);
            errdefer result.deinit(allocator);
            const current = try client.describe(definition);
            return .{ .assistance = .{ .generation = value.generation, .resource = definition.resource, .contract = try definition.fingerprint(), .resource_revision = current.resource_revision, .policy_revision = try a.decimal(allocator, current.policy_revision), .range = result.range, .items = result.items } };
        },
        .suggest => |input| {
            _ = try client.describe(definition);
            var columns: [m.max_columns]m.Column = undefined;
            return .{ .suggestions = .{ .resource = definition.resource, .contract = try definition.fingerprint(), .items = try q.Editor.candidates(allocator, name, try definition.schema(&columns), input.search) } };
        },
        .describe => {
            const description = (try b.apply(allocator, client, .{ .describe = config.source })).description;
            var columns: [m.max_columns]m.Column = undefined;
            return .{ .description = .{ .connection = client.connection, .name = config.name, .source = description, .budgets = config.limits, .columns = try v.foreignColumns(allocator, try definition.schema(&columns)) } };
        },
        .compile => |input| return .{ .compiled = try q.SqlCompilation.apply(allocator, client, .{
            .scope = .{ .name = config.name, .source = config.source, .limits = config.limits },
            .sql = input.sql,
            .parameters = input.parameters,
        }) },
        inline .next, .next_draft => |input, tag| {
            const bundle = try q.Bundle.decode(allocator, try v.unhex(allocator, input.bundle, q.Bundle.max_bytes));
            if (!std.mem.eql(u8, &try bundle.source.fingerprint(), &try definition.fingerprint())) return error.QueryIdentityMismatch;
            if (!limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
            const result = try client.prepareNextWithDraft(try v.unsigned(input.namespace), bundle, if (tag == .next_draft) try v.unsigned(input.generation) else null);
            return .{ .prepared = if (result) |prepared| .{ .token = try std.json.Stringify.valueAlloc(allocator, prepared, .{}) } else null };
        },
        .draft_status => |input| return .{ .draft = if (try client.draft(if (input) |generation| try v.unsigned(generation) else null)) |record| try Draft.fromNative(allocator, record) else null },
        .draft_open => |input| {
            const current = try client.describe(definition);
            if (!current.limits.permits(limits)) return error.QueryBudgetExceeded;
            const prepared = try client.prepare(.{ .draft_open = .{ .expected = try v.unsigned(input.expected), .limit = input.limit, .contract = try definition.fingerprint(), .limits = limits } });
            return .{ .prepared = .{ .token = try std.json.Stringify.valueAlloc(allocator, prepared, .{}) } };
        },
        .draft_close => |input| return .{ .prepared = .{ .token = try std.json.Stringify.valueAlloc(allocator, try client.prepare(.{ .draft_close = try v.unsigned(input) }), .{}) } },
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

//! Scoped explicit-submit SQL ingress shared by the shell and Board. A local
//! declaration is configuration, never a grant; results use current authority.
const std = @import("std");
const q = @import("root.zig");
const v = q.Values;
const b = q.Bridge;
const a = q.document.JsonValues;
const m = q.fuze.Unified;
pub const schema_options: q.protocol.Schema.Options = .{ .output = true, .safe_integers = true, .sequence_max_length = q.SourceDefinition.max_columns, .text_max_length = 131072 };
pub const request_schema_options: q.protocol.Schema.Options = .{ .safe_integers = true, .sequence_max_length = q.SourceDefinition.max_columns, .text_max_length = 131072 };
pub const Config = struct { name: []const u8, source: v.Source, limits: v.Limits };
pub const SqlCapabilities = struct {
    version: u8 = 1,
    statement_bytes: u32 = q.fuze.Sql.max_statement_bytes,
    named_columns: u8 = q.SourceDefinition.max_columns,
    star_columns: u8 = q.SourceDefinition.max_columns,
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
pub const Diagnostic = q.protocol.Diagnostic;
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
    return applyDiagnostic(allocator, client, config, request, null);
}
/// An owned envelope across compilation and the actual validated dispatch
/// boundary. Hosts do not need to reconstruct submission evidence themselves.
pub fn applyStructured(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config, request: Request, out: *?Diagnostic) !Response {
    out.* = null;
    client.wire.last_rejection = null;
    var binding: q.fuze.Sql.Binding = .{};
    if (request == .submit) {
        const prepared = prepareSubmission(allocator, client, config, request.submit.token) catch |err| {
            out.* = diagnostic(request, err, binding, false, null) catch null;
            return err;
        };
        const identity: Diagnostic.Identity = .{ .domain = .transport, .id = .init(prepared.signed.request.sequence), .sequence = .init(prepared.signed.request.sequence), .realm = .init(prepared.signed.request.realm) };
        const receipt = client.submit(prepared) catch |err| {
            out.* = diagnostic(request, err, binding, true, identity) catch null;
            nativeCause(out, client.wire.last_rejection);
            return err;
        };
        return .{ .receipt = receipt };
    }
    return applyDiagnostic(allocator, client, config, request, &binding) catch |err| {
        out.* = diagnostic(request, err, binding, false, null) catch null;
        q.ApiDiagnostic.qualify(out, client.connection);
        nativeCause(out, client.wire.last_rejection);
        return err;
    };
}
fn nativeCause(out: *?Diagnostic, cause: ?q.protocol.ErrorCode) void {
    if (out.*) |*detail| if (cause) |value| {
        detail.text(.native_cause, .authority, @tagName(value)) catch {};
    };
}
pub fn applyDiagnostic(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config, request: Request, detail: ?*q.fuze.Sql.Binding) !Response {
    if (detail) |value| value.* = .{};
    const scope = try checkedConfig(allocator, client, config);
    const definition = scope.definition;
    const limits = scope.limits;
    const name = scope.name;
    switch (request) {
        .sql_capabilities => return .{ .sql_capabilities = .{} },
        .inspect => |value| return .{ .inspection = try q.SqlInspection.applyDiagnostic(allocator, client, .{ .scope = .{ .name = config.name, .source = config.source, .limits = config.limits }, .sql = value.sql }, detail) },
        .assist => |value| {
            _ = try client.describe(definition);
            var columns: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
            const result = try q.Assistance.complete(allocator, name, try definition.schema(&columns), value);
            errdefer result.deinit(allocator);
            const current = try client.describe(definition);
            return .{ .assistance = .{ .generation = value.generation, .resource = definition.resource, .contract = try definition.fingerprint(), .resource_revision = current.resource_revision, .policy_revision = try a.decimal(allocator, current.policy_revision), .range = result.range, .items = result.items } };
        },
        .suggest => |input| {
            _ = try client.describe(definition);
            var columns: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
            return .{ .suggestions = .{ .resource = definition.resource, .contract = try definition.fingerprint(), .items = try q.Editor.candidates(allocator, name, try definition.schema(&columns), input.search) } };
        },
        .describe => {
            const description = (try b.apply(allocator, client, .{ .describe = config.source })).description;
            var columns: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
            return .{ .description = .{ .connection = client.connection, .name = config.name, .source = description, .budgets = config.limits, .columns = try v.foreignColumns(allocator, try definition.schema(&columns)) } };
        },
        .compile => |input| return .{ .compiled = try q.SqlCompilation.applyDiagnostic(allocator, client, .{
            .scope = .{ .name = config.name, .source = config.source, .limits = config.limits },
            .sql = input.sql,
            .parameters = input.parameters,
        }, detail) },
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

/// Read/prepare failures carry only evidence from this attempt. A dispatch
/// witness is established by the host only after validating the frozen token.
pub fn diagnostic(request: Request, cause: anyerror, binding: q.fuze.Sql.Binding, dispatched: bool, identity: ?Diagnostic.Identity) !Diagnostic {
    const stage: Diagnostic.Stage = switch (request) {
        .compile => .compile,
        .next, .next_draft, .draft_open, .draft_close, .prepare_control => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    var result = try q.ApiDiagnostic.attempt(@tagName(request), stage, switch (request) {
        .compile => |value| value.sql,
        .inspect => |value| value.sql,
        else => null,
    }, cause, binding, dispatched, identity orelse switch (request) {
        .status => |value| q.ApiDiagnostic.namespace(value),
        inline .next, .next_draft, .page, .prepare_control => |value| q.ApiDiagnostic.namespace(value.namespace),
        else => null,
    });
    const generation: ?[]const u8 = switch (request) {
        .next_draft => |value| value.generation,
        .draft_close => |value| value,
        .draft_status => |value| value,
        else => null,
    };
    if (generation) |text| if (v.unsigned(text)) |value| {
        try result.fact(.generation, .caller, .{ .unsigned = .init(value) });
    } else |_| {};
    return result;
}

const Scope = struct { definition: q.SourceDefinition, limits: q.Bundle.Limits, name: []const u8 };
fn checkedConfig(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config) !Scope {
    const definition = try config.source.native(allocator);
    if (definition.resource != client.connection.resource) return error.QueryIdentityMismatch;
    return .{ .definition = definition, .limits = try config.limits.native(), .name = try allocator.dupe(u8, (try q.catalog.TableMetadata.Name.init(config.name)).slice()) };
}
/// Preserve the workspace's local scope checks before recording a dispatch
/// boundary. No native request or replacement command is prepared here.
pub fn prepareSubmission(allocator: std.mem.Allocator, client: *q.UnifiedClient, config: Config, token: []const u8) !q.UnifiedClient.Prepared {
    _ = try checkedConfig(allocator, client, config);
    const prepared = try b.prepared(allocator, token);
    try client.validate(prepared);
    return prepared;
}

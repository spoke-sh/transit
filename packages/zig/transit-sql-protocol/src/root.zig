//! Native SQL session API. Pure contracts and codecs; no runtime or storage dependency.
pub const Json = @import("transit_protocol").Json;
const std = @import("std");
pub const fuze = @import("transit_fuze");
pub const native = @import("transit_protocol").Growth;
pub const Authentication = @import("Authentication.zig");
pub const Codec = @import("Codec.zig");
pub const Completion = enum { select, insert, update, delete, create_table, alter_table, drop_table, set, show, discard_all };
pub const Id = [32]u8;
pub const Instance = [16]u8;
pub const Token = [16]u8;
pub const Account = [32]u8;
pub const max_message_bytes = 4 * 1024 * 1024;
pub const max_batch_bytes = 1024 * 1024;
pub const max_sql_bytes = 65536;
pub const max_rows = 32;
pub const max_parameters = 65;
pub const max_prepared = 32;
pub const data_path = "/v1/sql/session";
pub const control_path = "/v1/sql/control";
pub const encoding = "transit.logical.v1.hex";
/// Every externally parsed envelope supplies both fields. No compatibility defaults.
pub const Request = struct {
    version: u8,
    definition: native.Definition,
    instance: ?Instance = null,
    session: ?Id = null,
    action: Action,
    pub fn validate(self: Request) !void {
        if (self.version != 1 or self.definition != native.current_definition) return error.IncompatibleSqlDefinition;
        if (self.action != .hello and self.instance == null) return error.SqlInstanceRequired;
        if (self.action != .hello and self.action != .open and self.action != .authenticate and self.session == null) return error.SqlSessionRequired;
        switch (self.action) {
            .open => |value| {
                try name(value.account);
                try name(value.database);
                if (value.source) |source| try name(source);
                if (value.first.len > 512) return error.InvalidScramMessage;
                if ((value.authentication == .scram) != (value.first.len != 0)) return error.InvalidAuthentication;
            },
            .authenticate => |value| if (value.final.len > 512) return error.InvalidScramMessage,
            .prepare => |value| try sql(value.sql),
            .execute => |value| {
                if ((value.sql == null) == (value.statement == null)) return error.InvalidSqlExecution;
                if (value.sql) |text| try sql(text);
                if (value.parameters.len > max_parameters) return error.TooManySqlParameters;
                for (value.parameters) |parameter| if (parameter.len > max_batch_bytes * 2) return error.SqlMessageTooLarge;
            },
            else => {},
        }
    }
    pub fn control(self: Request) bool {
        return switch (self.action) {
            .cancel, .status, .operations, .@"resume", .close, .close_result => true,
            else => false,
        };
    }
};
pub const Action = union(enum) {
    hello,
    open: struct { account: []const u8, database: []const u8, source: ?[]const u8 = null, authentication: enum { peer, trust, scram }, first: []const u8 = "" },
    authenticate: struct { challenge: Id, final: []const u8 },
    close,
    touch,
    reset,
    context,
    prepare: struct { sql: []const u8 },
    describe: Id,
    release: Id,
    execute: struct { sql: ?[]const u8 = null, statement: ?Id = null, parameters: []const []const u8 = &.{}, token: ?Token = null, captured: bool = false },
    fetch: struct { cursor: Id, batch: u64 },
    result: OperationId,
    close_result: Id,
    cancel: Target,
    status: Target,
    @"resume": OperationId,
    operations: struct { after: u64 = 0 },
    assist: struct { text: []const u8, cursor: u32 },
};
pub const OperationId = struct { account: Account, id: u64, kind: enum { table, configuration, captured } = .table };
pub const Target = union(enum) { query: Id, operation: OperationId, token: Token };
pub const Error = struct { code: []const u8, sqlstate: [5]u8, message: []const u8, retry: enum { never, control, same_token, same_batch }, operation: ?Operation = null, diagnostic: ?@import("transit_protocol").Diagnostic = null };
pub const Operation = struct {
    identity: OperationId,
    token: Token,
    phase: enum { reserved, uploading, ready, active, terminal, abandoned },
    blocked: bool = false,
    cancellation_requested: bool = false,
    outcome: ?enum { applied, unchanged, rejected, cancelled, partial } = null,
    matched: u64 = 0,
    changed: u64 = 0,
    owner_operation: ?[16]u8 = null,
    configuration_phase: ?enum { applying, applied, pending_restart, rejected, partial } = null,
    diagnostic: ?@import("transit_protocol").Diagnostic = null,
};
pub const Description = struct { statement: Id, schema: []const u8, parameters: []const []const u8, mutation: bool };
pub const Basis = union(enum) {
    source: struct { kind: fuze.Unified.SourceKind, resource: u64, revision: u64, head: [32]u8, contract: [32]u8, schema: [32]u8 },
    table: struct { realm: u64, resource: u64, catalog: u64, owner: u64, object: u64, revision: u64, commitment: [32]u8, schema: [32]u8 },
    per_resource_snapshot_vector: []const fuze.Relational.Cut,
};
pub const Batch = struct { cursor: Id, batch: u64, schema: []const u8, rows: []const []const []const u8, complete: bool, basis: ?Basis = null };
pub const Response = struct {
    version: u8,
    definition: native.Definition,
    instance: Instance,
    result: union(enum) {
        hello: struct { encoding: []const u8, session_lease_ms: u32, maximum_message: u32, maximum_batch: u32, maximum_rows: u8, capabilities: []const []const u8 },
        challenge: struct { id: Id, message: []const u8 },
        opened: struct { session: Id, account: Account, database: []const u8, proof: []const u8 = "" },
        context: struct { account: Account, database: []const u8, source: ?[]const u8, sources: []const struct { name: []const u8, sql_name: []const u8, kind: enum { kv, table, document }, resource: u64, revision: u64, contract: [32]u8 } },
        described: Description,
        batch: Batch,
        operation: Operation,
        operations: struct { entries: []const Operation, next: ?u64 },
        completion: struct { kind: Completion, matched: u64 = 0, changed: u64 = 0 },
        assistance: struct { coverage: enum { complete, limited }, status: enum { ready, inside_text, unsupported }, profile: enum { unified_v1, catalog_v1, configuration_v1 }, resource: u64, contract: [32]u8, resource_revision: u64, policy_revision: []const u8, range: ?fuze.SqlInput.Range, items: []const struct { text: []const u8, kind: enum { keyword, source, column, symbol, literal, meta }, detail: []const u8 } },
        closed,
        err: Error,
    },
};
fn name(value: []const u8) !void {
    if (value.len == 0 or value.len > 63 or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidSqlName;
}
fn sql(value: []const u8) !void {
    if (value.len == 0 or value.len > max_sql_bytes) return error.InvalidSqlText;
    try fuze.Sql.validateText(value);
}
/// Fingerprint exact request meaning before compilation. Token equality never
/// depends on JSON whitespace, current catalog contents or a later SQL parse.
pub fn fingerprint(allocator: std.mem.Allocator, instance: Instance, account: Account, database: []const u8, source: ?[]const u8, execute: @FieldType(Action, "execute")) ![32]u8 {
    if (execute.sql == null or execute.statement != null) return error.SqlTokenRequiresText;
    const bytes = try Json.valueAlloc(allocator, .{ instance, account, database, source, execute.sql.?, execute.parameters, execute.captured });
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
test "SQL requests reject missing definitions, missing sessions and ambiguous execution" {
    const t = std.testing;
    try t.expectError(error.MissingField, std.json.parseFromSlice(Request, t.allocator, "{\"version\":1,\"action\":{\"hello\":{}}}", .{}));
    const request: Request = .{ .version = 1, .definition = native.current_definition, .instance = @splat(1), .action = .{ .execute = .{ .sql = "SELECT 1" } } };
    try t.expectError(error.SqlSessionRequired, request.validate());
    var ambiguous = request;
    ambiguous.session = @splat(1);
    ambiguous.action.execute.statement = @splat(2);
    try t.expectError(error.InvalidSqlExecution, ambiguous.validate());
    const a = try fingerprint(t.allocator, @splat(1), @splat(2), "transit", null, .{ .sql = "INSERT INTO t VALUES (1)" });
    const b = try fingerprint(t.allocator, @splat(1), @splat(2), "transit", null, .{ .sql = "INSERT INTO t VALUES (2)" });
    try t.expect(!std.mem.eql(u8, &a, &b));
}
test {
    std.testing.refAllDecls(@This());
}
pub fn authenticationBinding(allocator: std.mem.Allocator, instance: Instance, account: []const u8, database: []const u8, source: ?[]const u8) ![32]u8 {
    const bytes = try Json.valueAlloc(allocator, .{ native.current_definition, instance, account, database, source });
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
pub fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(T) {
    try fuze.Types.Json.preflight(bytes, .{ .bytes = max_message_bytes, .depth = 16, .tokens = 65536, .fields = 256 });
    const parsed = try Json.parseFromSliceOwned(T, allocator, bytes);
    errdefer parsed.deinit();
    if (parsed.value.version != 1 or parsed.value.definition != native.current_definition) return error.IncompatibleSqlDefinition;
    if (T == Request) try parsed.value.validate();
    return parsed;
}
test "session JSON round trips fixed identities and void actions canonically" {
    const a = std.testing.allocator;
    const request: Request = .{ .version = 1, .definition = native.current_definition, .instance = @splat('A'), .session = @splat('B'), .action = .touch };
    const bytes = try Json.valueAlloc(a, request);
    defer a.free(bytes);
    const restored = try parse(Request, a, bytes);
    defer restored.deinit();
    try std.testing.expectEqualDeep(request, restored.value);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "\"touch\":{}") != null);
}

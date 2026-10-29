//! Native SQL session API. Pure contracts and codecs; no runtime or storage dependency.
pub const Json = @import("transit_protocol").Json;
const std = @import("std");
pub const fuze = @import("transit_fuze");
pub const native = @import("transit_protocol").Growth;
pub const Authentication = @import("Authentication.zig");
pub const Codec = @import("Codec.zig");
pub const ResultFrame = @import("ResultFrame.zig");
pub const ResultColumns = @import("ResultColumns.zig");
pub const results = @import("transit_sql_results");
test {
    _ = @import("allocation_test.zig");
}
pub const Completion = results.Command;
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
pub const encoding = "transit.sql.result.v1.binary-columns";
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
            .attach_transaction => |value| try value.validate(),
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
    attach_transaction: results.protocol.Transaction.Handle,
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
pub const OperationId = results.Operation;
pub const Target = union(enum) { query: Id, operation: OperationId, token: Token };
pub const Error = struct { code: []const u8, sqlstate: [5]u8, message: []const u8, retry: enum { never, control, same_token, same_batch }, operation: ?Operation = null, diagnostic: ?@import("transit_protocol").Diagnostic = null };
pub const Operation = struct {
    identity: OperationId,
    command: ?results.Command,
    token: Token,
    phase: enum { reserved, uploading, ready, active, terminal, abandoned },
    blocked: bool = false,
    cancellation_requested: bool = false,
    outcome: ?results.Outcome = null,
    matched: u64 = 0,
    changed: u64 = 0,
    owner_operation: ?[16]u8 = null,
    transaction: ?results.Transaction = null,
    configuration_phase: ?enum { applying, applied, pending_restart, rejected, partial } = null,
    diagnostic: ?@import("transit_protocol").Diagnostic = null,
    pub fn validate(self: Operation) !void {
        if (self.identity.id == 0 or ((self.phase == .terminal) != (self.outcome != null))) return error.InvalidSqlOperation;
        if (self.phase == .terminal) {
            _ = try self.completion();
        } else if (self.matched != 0 or self.changed != 0 or self.transaction != null) return error.InvalidSqlOperation;
        if ((self.phase == .ready or self.phase == .active) and self.command == null) return error.InvalidSqlOperation;
    }
    pub fn completion(self: Operation) !results.CommandCompletion {
        if (self.phase != .terminal or self.outcome == null or self.command == null) return error.SqlOutcomeUnknown;
        const value: results.CommandCompletion = .{
            .kind = self.command.?,
            .outcome = self.outcome.?,
            .counts = switch (self.command.?) {
                .insert, .update, .delete, .create_table, .alter_table, .drop_table, .create_schema, .alter_schema, .drop_schema => .{ .matched = self.matched, .changed = self.changed },
                else => null,
            },
            .operation = self.identity,
            .pending_restart = self.configuration_phase == .pending_restart,
            .diagnostic = self.diagnostic,
            .transaction = self.transaction,
        };
        try value.validate();
        return value;
    }
};
/// A command without returned rows has no result schema. The field is required;
/// null is distinct from a row-returning statement with an empty result.
pub const Description = struct { statement: Id, schema: ?[]const u8, parameters: []const []const u8, mutation: bool };
pub const Batch = ResultFrame;
pub const Response = struct {
    version: u8,
    definition: native.Definition,
    instance: Instance,
    result: union(enum) {
        hello: struct { encoding: []const u8, session_lease_ms: u32, maximum_message: u32, maximum_batch: u32, maximum_rows: u8, capabilities: []const []const u8 },
        challenge: struct { id: Id, message: []const u8 },
        opened: struct { session: Id, account: Account, database: []const u8, proof: []const u8 = "" },
        context: struct { account: Account, database: []const u8, source: ?[]const u8, transaction: ?results.protocol.Transaction.Handle, sources: []const struct { name: []const u8, sql_name: []const u8, kind: enum { kv, table, document }, resource: u64, revision: u64, contract: [32]u8 } },
        attached: results.protocol.Transaction.Handle,
        described: Description,
        batch: Batch,
        operation: Operation,
        operations: struct { entries: []const Operation, next: ?u64 },
        completion: results.CommandCompletion,
        assistance: struct { coverage: enum { complete, limited }, status: enum { ready, inside_text, unsupported }, profile: enum { unified_v1, catalog_v1, configuration_v1, direct_table_v1 }, resource: u64, contract: [32]u8, resource_revision: ?u64, policy_revision: []const u8, range: ?fuze.SqlInput.Range, items: []const struct { text: []const u8, kind: enum { keyword, source, column, symbol, literal, meta }, detail: []const u8 } },
        closed,
        err: Error,
    },
};
/// JSON is the small control plane. Binary result frames never have a JSON
/// realization; this reflected union deliberately excludes the batch tag.
pub const JsonResponse = struct {
    const R = @FieldType(Response, "result");
    version: u8,
    definition: native.Definition,
    instance: Instance,
    result: union(enum) {
        hello: @FieldType(R, "hello"),
        challenge: @FieldType(R, "challenge"),
        opened: @FieldType(R, "opened"),
        context: @FieldType(R, "context"),
        attached: @FieldType(R, "attached"),
        described: @FieldType(R, "described"),
        operation: @FieldType(R, "operation"),
        operations: @FieldType(R, "operations"),
        completion: @FieldType(R, "completion"),
        assistance: @FieldType(R, "assistance"),
        closed,
        err: Error,
    },
};
pub fn encodeResponse(allocator: std.mem.Allocator, response: Response) ![]align(ResultFrame.alignment) u8 {
    if (response.result == .batch) return ResultFrame.encode(allocator, response.result.batch);
    const value: JsonResponse = .{ .version = response.version, .definition = response.definition, .instance = response.instance, .result = switch (response.result) {
        .batch => unreachable,
        inline else => |item, tag| @unionInit(@FieldType(JsonResponse, "result"), @tagName(tag), item),
    } };
    const json = try Json.valueAlloc(allocator, value);
    defer allocator.free(json);
    const bytes = try allocator.alignedAlloc(u8, .fromByteUnits(ResultFrame.alignment), json.len);
    @memcpy(bytes, json);
    return bytes;
}
pub fn validateResponse(response: Response) !void {
    if (response.version != 1 or response.definition != native.current_definition) return error.IncompatibleSqlDefinition;
    switch (response.result) {
        .operation => |value| try value.validate(),
        .operations => |page| for (page.entries) |value| try value.validate(),
        .completion => |value| try value.validate(),
        .attached => |value| try value.validate(),
        .context => |value| if (value.transaction) |handle| try handle.validate(),
        .batch => |value| {
            if (!std.mem.eql(u8, &value.instance, &response.instance) or value.rows > max_rows or
                (value.rows == 0 and value.completion == null)) return error.InvalidResultChunk;
        },
        .err => |value| if (value.operation) |operation| try operation.validate(),
        else => {},
    }
}
/// Input/arena are the caller's response owner. Column payloads borrow input.
pub fn decodeResponse(arena: std.mem.Allocator, bytes: []align(ResultFrame.alignment) const u8, binary: bool) !Response {
    return decodeWithDirectory(arena, null, bytes, binary);
}
/// The caller owns directory storage as well as frame and metadata storage.
pub fn decodeResponseInto(arena: std.mem.Allocator, directory: [][]const u8, bytes: []align(ResultFrame.alignment) const u8, binary: bool) !Response {
    return decodeWithDirectory(arena, directory, bytes, binary);
}
fn decodeWithDirectory(arena: std.mem.Allocator, directory: ?[][]const u8, bytes: []align(ResultFrame.alignment) const u8, binary: bool) !Response {
    if (binary) {
        const batch = if (directory) |storage| try ResultFrame.parseInto(arena, storage, bytes) else try ResultFrame.parseBorrowed(arena, bytes);
        const response: Response = .{ .version = 1, .definition = native.current_definition, .instance = batch.instance, .result = .{ .batch = batch } };
        try validateResponse(response);
        return response;
    }
    try fuze.Types.Json.preflight(bytes, .{ .bytes = max_message_bytes, .depth = 16, .tokens = 65536, .fields = 256 });
    const tree = try std.json.parseFromSlice(std.json.Value, arena, bytes, .{});
    defer tree.deinit();
    try Json.validateShape(JsonResponse, tree.value);
    const decoded = try std.json.parseFromSliceLeaky(JsonResponse, arena, bytes, .{ .allocate = .alloc_always });
    const response: Response = .{ .version = decoded.version, .definition = decoded.definition, .instance = decoded.instance, .result = switch (decoded.result) {
        inline else => |item, tag| @unionInit(@FieldType(Response, "result"), @tagName(tag), item),
    } };
    try validateResponse(response);
    return response;
}
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
    if (T == Response) {
        const parsed = try Json.parseFromSliceOwned(JsonResponse, allocator, bytes);
        errdefer parsed.deinit();
        const response: Response = .{ .version = parsed.value.version, .definition = parsed.value.definition, .instance = parsed.value.instance, .result = switch (parsed.value.result) {
            inline else => |item, tag| @unionInit(@FieldType(Response, "result"), @tagName(tag), item),
        } };
        try validateResponse(response);
        return .{ .arena = parsed.arena, .value = response };
    }
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

test "result cutover rejects JSON rows foreign definitions and old command shapes" {
    const t = std.testing;
    const a = t.allocator;
    const obsolete = try Json.valueAlloc(a, .{ .version = 1, .definition = native.current_definition, .instance = @as(Instance, @splat(2)), .result = .{ .batch = .{ .cursor = @as(Id, @splat(6)), .batch = 0, .schema = "", .rows = .{}, .complete = true, .completion = .{ .rows = 0 } } } });
    defer a.free(obsolete);
    if (parse(Response, a, obsolete)) |accepted| {
        accepted.deinit();
        return error.AcceptedJsonResult;
    } else |_| {}
    const bytes = try Json.valueAlloc(a, JsonResponse{ .version = 1, .definition = native.current_definition, .instance = @splat(2), .result = .closed });
    defer a.free(bytes);
    const foreign_value = try std.json.parseFromSlice(std.json.Value, a, bytes, .{});
    defer foreign_value.deinit();
    foreign_value.value.object.getPtr("definition").?.* = .{ .string = "47c035195248bf570ed52323112b2a32622ee69714ffb7719124218e034b1b2b" };
    const foreign = try std.json.Stringify.valueAlloc(a, foreign_value.value, .{});
    defer a.free(foreign);
    try t.expectError(error.InvalidJsonShape, parse(Response, a, foreign));
    const invalid = try Json.valueAlloc(a, .{ .version = 1, .definition = native.current_definition, .instance = @as(Instance, @splat(2)), .result = .{ .completion = .{ .kind = "insert", .matched = 1, .changed = 1 } } });
    defer a.free(invalid);
    if (parse(Response, a, invalid)) |accepted| {
        accepted.deinit();
        return error.AcceptedObsoleteCompletion;
    } else |_| {}
}

test "transaction attachment requests and replies require valid original recovery material" {
    const t = std.testing;
    const handle: results.protocol.Transaction.Handle = .{
        .definition = native.current_definition,
        .identity = .{ .begin = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 4, .operation = 5 }, .branch = 1 },
        .account = @splat(1),
        .token = @splat(2),
        .audience = 6,
        .role = null,
    };
    const request: Request = .{ .version = 1, .definition = native.current_definition, .instance = @splat(3), .session = @splat(4), .action = .{ .attach_transaction = handle } };
    try request.validate();
    const bytes = try Json.valueAlloc(t.allocator, request);
    defer t.allocator.free(bytes);
    const parsed = try parse(Request, t.allocator, bytes);
    defer parsed.deinit();
    try t.expectEqualDeep(request, parsed.value);
    var response: Response = .{ .version = 1, .definition = native.current_definition, .instance = @splat(3), .result = .{ .attached = handle } };
    try validateResponse(response);
    response.result.attached.identity.branch = 2;
    try t.expectError(error.UnsupportedTransactionDomain, validateResponse(response));
    var invalid = request;
    invalid.action.attach_transaction.account = @splat(0);
    try t.expectError(error.InvalidTransactionHandle, invalid.validate());
}

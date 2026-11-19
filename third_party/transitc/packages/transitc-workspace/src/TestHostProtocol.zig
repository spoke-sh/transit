//! Compiled-case boundary. A runtime receives SQL and typed expectations, never source.
const std = @import("std");
const c = @import("transit_compiler");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
pub const definition = "transit.test-host.v1.2026-11-19.compiled-cases";
pub const argument = "__transit_test_case_v1";
pub const max_request_bytes = 64 * 1024 * 1024;
pub const max_response_bytes = 65536;
pub const case_ms = 30000;
pub const cleanup_ms = 5000;
pub const Resources = struct { memory_peak_bytes: usize = 0, storage_reserved_bytes: u64 = 0 };
pub const Observation = struct { actions: usize = 0, rows: usize = 0, bytes: usize = 0, operation: ?u64 = null, failure: ?c.Test.Failure = null, resources: Resources = .{} };
pub const Runtime = struct { revision: []const u8, executable_digest: [32]u8 };
pub const Expectation = union(enum) {
    complete,
    rows: struct { schema: []const u8, values: []const []const u8 },
    command: @FieldType(c.Test.Expectation, "command"),
    refusal: @FieldType(c.Test.Expectation, "refusal"),
    workflow: @FieldType(c.Test.Expectation, "workflow"),
    pub fn jsonParse(a: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Expectation {
        return p.Json.parseTaggedUnion(Expectation, a, source, options);
    }
};
pub const Action = struct { step: ?usize, expectation: Expectation };
pub const Request = struct {
    definition: []const u8,
    source_definition: []const u8,
    identity: [32]u8,
    sql_digest: [32]u8,
    steps: []const []const u8,
    actions: []const Action,
    milliseconds: u32,
};
pub const Response = struct {
    definition: []const u8,
    source_definition: []const u8,
    request_digest: [32]u8,
    identity: [32]u8,
    sql_digest: [32]u8,
    runtime: Runtime,
    complete: bool,
    passed: bool,
    error_code: ?[]const u8,
    observation: Observation,
    detail: c.Test.Detail,
};
pub const Executable = struct {
    steps: []const struct { sql: []const u8 },
    actions: []const c.Test.Action,
};
fn hex(a: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try a.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[i * 2] = alphabet[byte >> 4];
        result[i * 2 + 1] = alphabet[byte & 15];
    }
    return result;
}
fn unhex(a: std.mem.Allocator, text: []const u8, limit: usize) ![]const u8 {
    if (text.len % 2 != 0 or text.len / 2 > limit) return error.TestHostEncodingLimit;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidTestHostEncoding;
    const result = try a.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(result, text);
}
pub fn capture(a: std.mem.Allocator, case: c.Test.Case, milliseconds: u32) !Request {
    const steps = try a.alloc([]const u8, case.steps.len);
    for (case.steps, steps) |step, *out| out.* = step.sql;
    const actions = try a.alloc(Action, case.actions.len);
    var schema_buffer: [f.Types.max_encoding_bytes]u8 = undefined;
    for (case.actions, actions) |action, *out| {
        out.* = .{ .step = action.step, .expectation = switch (action.expectation) {
            .rows => |rows| blk: {
                const values = try a.alloc([]const u8, rows.values.len);
                for (rows.values, values) |value, *encoded| encoded.* = try hex(a, value);
                break :blk .{ .rows = .{ .schema = try hex(a, try rows.schema.encode(&schema_buffer)), .values = values } };
            },
            .complete => .complete,
            inline else => |value, tag| @unionInit(Expectation, @tagName(tag), value),
        } };
    }
    return .{ .definition = definition, .source_definition = @import("BuildSources.zig").definition, .identity = case.identity, .sql_digest = case.sql_digest, .steps = steps, .actions = actions, .milliseconds = milliseconds };
}
/// The caller owns the request arena. No pointers escape its lifetime.
pub fn executable(a: std.mem.Allocator, request: Request) !Executable {
    if (!std.mem.eql(u8, request.definition, definition) or !std.mem.eql(u8, request.source_definition, @import("BuildSources.zig").definition)) return error.IncompatibleTestHostDefinition;
    if (request.milliseconds == 0 or request.milliseconds > case_ms) return error.InvalidTestHostBudget;
    if (request.steps.len == 0 or request.steps.len > c.Test.max_actions or request.actions.len == 0 or request.actions.len > c.Test.max_actions) return error.TestActionLimit;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var sql_bytes: usize = 0;
    const steps = try a.alloc(@typeInfo(@FieldType(Executable, "steps")).pointer.child, request.steps.len);
    for (request.steps, steps) |sql, *step| {
        if (sql.len == 0 or sql.len > f.Sql.max_statement_bytes or sql.len + 2 > (c.Compiler.Limits{}).output_bytes -| sql_bytes) return error.TestHostSqlLimit;
        sql_bytes += sql.len + 2;
        hash.update(sql);
        hash.update(";\n");
        step.* = .{ .sql = sql };
    }
    if (!std.mem.eql(u8, &hash.finalResult(), &request.sql_digest)) return error.TestHostSqlDigestMismatch;
    const actions = try a.alloc(c.Test.Action, request.actions.len);
    var row_count: usize = 0;
    var row_bytes: usize = 0;
    var next_step: usize = 0;
    var scratch: std.heap.ArenaAllocator = .init(a);
    defer scratch.deinit();
    for (request.actions, actions) |action, *out| {
        if (action.expectation == .workflow) {
            const workflow = action.expectation.workflow;
            if (action.step != null or workflow.name.len == 0 or workflow.name.len > 127 or workflow.observations == 0 or workflow.observations > c.Test.max_observations) return error.TestInvalidExpectation;
        } else {
            if (action.step == null or action.step.? != next_step or next_step >= steps.len) return error.TestInvalidExpectation;
            next_step += 1;
        }
        out.* = .{ .step = action.step, .location = .{ .offset = .init(0), .length = .init(0), .line = .init(1), .byte_column = .init(1) }, .expectation = switch (action.expectation) {
            .rows => |rows| blk: {
                if (rows.values.len > c.Test.max_rows -| row_count) return error.TestRowLimit;
                row_count += rows.values.len;
                const schema = try f.Types.decodeInto(a, try unhex(a, rows.schema, f.Types.max_encoding_bytes));
                if (schema != .structure or schema.structure.len > f.TableSchema.max_columns) return error.InvalidTestSchema;
                const values = try a.alloc([]const u8, rows.values.len);
                for (rows.values, values) |value, *decoded| {
                    decoded.* = try unhex(a, value, c.Test.max_result_bytes -| row_bytes);
                    row_bytes += decoded.len;
                    if (!scratch.reset(.retain_capacity)) return error.OutOfMemory;
                    _ = try f.Types.Codec.decodeBoundInto(scratch.allocator(), .{ .name = "row", .type = schema }, decoded.*);
                }
                break :blk .{ .rows = .{ .schema = schema, .values = values } };
            },
            .complete => .complete,
            inline else => |value, tag| @unionInit(c.Test.Expectation, @tagName(tag), value),
        } };
    }
    if (next_step != steps.len) return error.TestInvalidExpectation;
    return .{ .steps = steps, .actions = actions };
}
pub fn validateResponse(response: Response, request: Request, digest: [32]u8) !void {
    if (!std.mem.eql(u8, response.definition, definition) or !std.mem.eql(u8, response.source_definition, request.source_definition)) return error.IncompatibleTestHostDefinition;
    if (!std.mem.eql(u8, &response.request_digest, &digest) or !std.mem.eql(u8, &response.identity, &request.identity) or !std.mem.eql(u8, &response.sql_digest, &request.sql_digest)) return error.TestHostResponseMismatch;
    const observed = response.observation;
    if (observed.actions > request.actions.len or observed.rows > c.Test.max_rows or observed.bytes > c.Test.max_result_bytes or observed.resources.memory_peak_bytes > 256 * 1024 * 1024 or observed.resources.storage_reserved_bytes > 256 * 1024 * 1024) return error.InvalidTestHostResponse;
    if (response.detail.expected_reason_len > 32 or response.detail.observed_reason_len > 32) return error.InvalidTestHostResponse;
    if (response.complete != (response.error_code == null) or response.passed and (!response.complete or observed.failure != null or observed.actions != request.actions.len)) return error.InvalidTestHostResponse;
    if (response.complete and !response.passed and observed.failure == null) return error.InvalidTestHostResponse;
    if (response.complete and (observed.actions == 0 or observed.resources.memory_peak_bytes == 0 or observed.resources.storage_reserved_bytes == 0)) return error.InvalidTestHostResponse;
    if (response.runtime.revision.len == 0 or response.runtime.revision.len > 128) return error.InvalidTestHostResponse;
}

test "compiled cases roundtrip without source and reject foreign identity, corrupt SQL and invalid actions" {
    var diagnostic: ?p.Diagnostic = null;
    const product = try c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = "CREATE TEST TARGET tests AS BEGIN TEST 'rows' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items(id BIGINT); INSERT INTO items VALUES (7); ASSERT ROWS (SELECT * FROM items) EQUAL ((7)); END; END;" }}, .{ .compiler_revision = "wire-proof", .target = "tests", .mode = .test_suite }, &diagnostic);
    defer product.deinit();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const request = try capture(a, product.cases[0], case_ms);
    const bytes = try p.Json.valueAllocBounded(a, request, max_request_bytes);
    const decoded = try p.Json.parseFromSlice(Request, a, bytes);
    const result = try executable(a, decoded.value);
    try std.testing.expectEqual(product.cases[0].actions.len, result.actions.len);
    try std.testing.expectEqualSlices(u8, product.cases[0].actions[2].expectation.rows.values[0], result.actions[2].expectation.rows.values[0]);
    var invalid = request;
    invalid.definition = "foreign";
    try std.testing.expectError(error.IncompatibleTestHostDefinition, executable(a, invalid));
    invalid = request;
    invalid.source_definition = "foreign";
    try std.testing.expectError(error.IncompatibleTestHostDefinition, executable(a, invalid));
    invalid = request;
    invalid.sql_digest[0] ^= 1;
    try std.testing.expectError(error.TestHostSqlDigestMismatch, executable(a, invalid));
    invalid = request;
    invalid.milliseconds = case_ms + 1;
    try std.testing.expectError(error.InvalidTestHostBudget, executable(a, invalid));
    const actions = try a.dupe(Action, request.actions);
    actions[0].step = request.steps.len;
    invalid = request;
    invalid.actions = actions;
    try std.testing.expectError(error.TestInvalidExpectation, executable(a, invalid));
    actions[0] = request.actions[0];
    actions[2].expectation.rows.schema = "00";
    try std.testing.expectError(error.EndOfStream, executable(a, invalid));
    try std.testing.expectError(error.MissingField, p.Json.parseFromSlice(Request, a, "{}"));
    var response: Response = .{ .definition = definition, .source_definition = request.source_definition, .request_digest = @splat(1), .identity = request.identity, .sql_digest = request.sql_digest, .runtime = .{ .revision = "runtime-proof", .executable_digest = @splat(2) }, .complete = true, .passed = true, .error_code = null, .observation = .{ .actions = request.actions.len, .resources = .{ .memory_peak_bytes = 1, .storage_reserved_bytes = 1 } }, .detail = .{} };
    try validateResponse(response, request, @splat(1));
    try std.testing.expectError(error.TestHostResponseMismatch, validateResponse(response, request, @splat(3)));
    response.observation.actions -= 1;
    try std.testing.expectError(error.InvalidTestHostResponse, validateResponse(response, request, @splat(1)));
}

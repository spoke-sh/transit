//! Bounded, allocator-owned syntax for an ordered Queue program. Parsing does
//! not bind catalog objects, authorize instructions or activate a computation.
//! Expressions and instructions have stable identities within a frozen
//! definition; execution must never reinterpret an accepted definition.
const std = @import("std");
pub const Parser = @import("ApplicationProgramParser.zig");
pub const Types = @import("ApplicationProgramTypes.zig");
pub const Codec = @import("ApplicationProgramCodec.zig");
pub const Values = @import("ApplicationValue.zig");
pub const Evaluation = @import("ApplicationExpression.zig");
pub const Json = @import("ApplicationJson.zig");
pub const Cursor = @import("ApplicationCursor.zig");
pub const Environment = @import("ApplicationEnvironment.zig");
pub const Step = @import("ApplicationStep.zig");
pub const Predicate = @import("ApplicationPredicate.zig");
pub const max_source_bytes = @import("SqlInput.zig").max_source_bytes;
pub const max_nodes = 4096;
pub const max_depth = 32;
pub const max_arguments = 64;
pub const Span = struct { start: u32, end: u32 };
pub const Id = u16;

pub const Function = enum {
    secret,
    random_token,
    random_secret,
    derive_secret,
    digest,
    commitment,
    now,
    seconds,
    current_revision,
    secret_current,
    url,
    json_object,
    s256,
    http_query,
    http_query_unique,
    http_secret_query_unique,
    http_secret_cookie_unique,
    length,
    secure_equal,
    operation_id,
    json_value,
    secret_json_value,
    bearer,
    json_integer,
    identity_digest,
    native_identity_allowed,
    native_session_current,
    native_binding_active,
};
pub const Binary = enum { equal, not_equal, less, less_equal, greater, greater_equal, and_, or_, add, subtract, concatenate };
pub const Unary = enum { not_, negate, is_null, is_not_null };
pub const Expression = struct {
    id: Id,
    span: Span,
    value: union(enum) {
        null,
        boolean: bool,
        integer: i64,
        text: []const u8,
        name: []const u8,
        field: struct { base: *Expression, name: []const u8 },
        call: struct { function: Function, arguments: []const *Expression },
        unary: struct { operator: Unary, operand: *Expression },
        binary: struct { operator: Binary, left: *Expression, right: *Expression },
        case: struct { condition: *Expression, yes: *Expression, no: *Expression },
        text_cast: *Expression,
        row: []const *Expression,
    },
};
pub const Field = struct { name: []const u8, value: *Expression };
pub const Read = struct { target: []const u8, key: *Expression };
pub const Select = struct {
    target: []const u8,
    columns: ?[]const []const u8,
    predicate: ?*Expression,
};
pub const Effect = struct {
    sink: []const u8,
    identity: *Expression,
    guard: *Expression,
    request: union(enum) { form: []const Field, headers: []const Field },
};
pub const Binding = struct {
    name: []const u8,
    value: union(enum) { expression: *Expression, get: Read, select: Select, effect: Effect },
};
pub const Cookie = struct {
    name: []const u8,
    value: ?*Expression,
    max_age: ?*Expression,
};
pub const Response = struct {
    request: *Expression,
    status: u16,
    guard: ?*Expression,
    body: union(enum) { empty, json: *Expression, location: *Expression },
    cookies: []const Cookie,
};
pub const Instruction = struct {
    id: Id,
    span: Span,
    value: union(enum) {
        let: Binding,
        require: struct { condition: *Expression, refusal: []const u8 },
        atomic: []const Instruction,
        conditional: struct { condition: *Expression, yes: []const Instruction, no: []const Instruction },
        put: struct {
            target: []const u8,
            key: *Expression,
            value: *Expression,
            fields: []const Field,
            expected: union(enum) { absent, revision: *Expression },
        },
        insert: struct { target: []const u8, values: []const *Expression, conflict_columns: []const []const u8 },
        append: struct { kind: enum { stream, queue }, target: []const u8, values: []const *Expression },
        handoff: struct { request: *Expression, queue: []const u8, effect: *Expression },
        respond: Response,
        respond_error: struct { request: *Expression, failure: []const u8, profile: []const u8 },
    },
};
pub const Program = struct {
    name: []const u8,
    queue: []const u8,
    input: []const u8,
    predicate: ?*Expression,
    deadline: ?[]const u8,
    body: union(enum) {
        instructions: []const Instruction,
        page: struct { select: Select, request: *Expression, profile: []const u8, size: u16 },
    },
    failure: ?struct { name: []const u8, instructions: []const Instruction },
    nodes: u16,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    source: []const u8,
    program: Program,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const parse = Parser.parse;

/// Deadline literals use the same closed units as connector timeouts. Keep
/// this validation shared by parsed programs, decoded plans and execution.
pub fn deadlineMilliseconds(text: []const u8) !u64 {
    var end: usize = 0;
    while (end < text.len and std.ascii.isDigit(text[end])) : (end += 1) {}
    const multiplier = @import("PerfectHash.zig").ComptimeMap(u64, true, .{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "m", 60000 }, .{ "h", 3600000 }, .{ "d", 86400000 } }).get(text[end..]) orelse return error.InvalidApplicationDeadline;
    const count = std.fmt.parseInt(u64, text[0..end], 10) catch return error.InvalidApplicationDeadline;
    if (count == 0) return error.InvalidApplicationDeadline;
    return std.math.mul(u64, count, multiplier) catch error.InvalidApplicationDeadline;
}

test "application program deadlines reject malformed zero and overflowing durations" {
    const t = std.testing;
    try t.expectEqual(@as(u64, 5000), try deadlineMilliseconds("5s"));
    try t.expectEqual(@as(u64, 1), try deadlineMilliseconds("1MS"));
    try t.expectEqual(@as(u64, 86400000), try deadlineMilliseconds("1d"));
    for ([_][]const u8{ "", "s", "0s", "-1s", "+1s", "1.5s", " 5s", "5s ", "5", "1us", "18446744073709551616ms", "18446744073709551615s" }) |invalid| {
        try t.expectError(error.InvalidApplicationDeadline, deadlineMilliseconds(invalid));
        const source = try std.fmt.allocPrint(t.allocator, "CREATE DATAFLOW x FROM QUEUE q AS request WITH (DEADLINE = '{s}') AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", .{invalid});
        defer t.allocator.free(source);
        try t.expectError(error.InvalidApplicationDeadline, parse(t.allocator, source, null));
    }
    var parsed = try parse(t.allocator, "CREATE DATAFLOW x FROM QUEUE q AS request WITH (DEADLINE = '5s') AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", null);
    defer parsed.deinit();
    try Codec.validate(parsed.program);
    parsed.program.deadline = "0s";
    try t.expectError(error.InvalidApplicationDeadline, Codec.validate(parsed.program));
}

test {
    _ = Types;
    _ = Codec;
    _ = Values;
    _ = Evaluation;
    _ = Cursor;
    _ = Environment;
    _ = Step;
    _ = Predicate;
}

test "application program preserves guarded effects and atomic control flow" {
    const t = std.testing;
    const source =
        \\CREATE DATAFLOW action FROM QUEUE requests AS request WHERE route = 'login' AS BEGIN
        \\  LET secret = SECRET('client');
        \\  LET reply = EXECUTE SINK token EFFECT OPERATION_ID(request.id, 'token')
        \\    GUARD SECRET_CURRENT(secret) FORM (client_secret = secret) ON REPLAY OBSERVE ONLY;
        \\  BEGIN ATOMIC
        \\    IF reply.status = 200 THEN
        \\      PUT INTO challenges KEY DIGEST('state') VALUE ROW('claimed', NULL) IF ABSENT;
        \\    ELSE
        \\      REQUIRE FALSE ELSE 'Refused';
        \\    END IF;
        \\  END;
        \\  RESPOND TO request.ref STATUS 200 GUARD SECRET_CURRENT(secret) JSON JSON_OBJECT('ok', TRUE);
        \\ON FAILURE failure
        \\  BEGIN ATOMIC
        \\    RESPOND ERROR TO request.ref USING failure PUBLIC PROFILE 'browser_v1';
        \\  END;
        \\END;
    ;
    var owned = try parse(t.allocator, source, null);
    defer owned.deinit();
    try t.expectEqualStrings("action", owned.program.name);
    try t.expectEqual(4, owned.program.body.instructions.len);
    try t.expectEqual(.secret, owned.program.body.instructions[0].value.let.value.expression.value.call.function);
    try t.expectEqualStrings("token", owned.program.body.instructions[1].value.let.value.effect.sink);
    try t.expectEqual(1, owned.program.body.instructions[2].value.atomic[0].value.conditional.yes.len);
    try t.expectEqualStrings("failure", owned.program.failure.?.name);
}

test "application program rejects unsafe boundaries and incomplete effects" {
    const t = std.testing;
    const cases = .{
        .{ "PUT INTO kv KEY 'k' VALUE 1 IF ABSENT;", error.MutationOutsideAtomic },
        .{ "BEGIN ATOMIC LET reply = EXECUTE SINK token; END;", error.EffectInsideAtomic },
        .{ "BEGIN ATOMIC BEGIN ATOMIC END; END;", error.NestedAtomicProgram },
        .{ "LET x = UNKNOWN_FUNCTION();", error.UnknownProgramFunction },
        .{ "LET x = EXECUTE SINK token EFFECT 1 GUARD TRUE FORM (a = 1, a = 2) ON REPLAY OBSERVE ONLY;", error.DuplicateProgramField },
        .{ "LET x = EXECUTE SINK token EFFECT 1 GUARD TRUE FORM (a = 1);", error.InvalidSqlSyntax },
        .{ "RESPOND TO request.ref STATUS 100;", error.InvalidProgramStatus },
        .{ "LET x = 'unfinished;", error.UnterminatedSqlToken },
    };
    inline for (cases) |entry| {
        const source = "CREATE DATAFLOW x FROM QUEUE q AS request AS BEGIN " ++ entry[0] ++ " END;";
        var location: @import("Sql.zig").Location = .{};
        try t.expectError(entry[1], parse(t.allocator, source, &location));
        try t.expect(location.offset > 0);
    }
}

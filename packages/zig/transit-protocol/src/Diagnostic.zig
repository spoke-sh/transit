//! Bounded diagnostic values. A diagnostic projects execution evidence; it is
//! never a receipt, authorization proof or permission to repeat an operation.
const std = @import("std");
const p = @import("root.zig");
const Self = @This();
pub const max_json_bytes = 32768;
pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
pub const Category = enum { syntax, binding, unsupported, constraint, access, conflict, limit, lifecycle, integrity, unavailable, internal };
pub const Stage = enum { input, parse, compile, bind, prepare, submit, admission, execute, read, decode, output, reconcile, cleanup, control };
pub const Outcome = enum { not_applicable, not_submitted, prepared, unknown, pending, input_rejected, rejected, applied, cancelled, retired, closed_unknown };
pub const Evidence = enum { none, local_before_dispatch, saved_intent, native_receipt, domain_status };
pub const Domain = enum { sql, query, mutation, catalog, application, publication, migration, reactive, effect, transport, internal };
pub const Availability = enum { provided, truncated, unrecorded, unavailable, withheld, inapplicable };
pub const Origin = enum { caller, execution, schema, authority, owner };
pub const ActionKind = enum { correct_input, inspect_status, resume_exact, cancel_wait, cancel_mutation, refresh, recompile, retry_read, inspect_scope, reconcile_effect, contact_operator };
pub const Field = enum {
    object,
    name,
    table,
    native_input,
    affected_rows,
    argument,
    option,
    permissions,
    scope,
    column,
    qualifier,
    constraint,
    key,
    input_row,
    first_occurrence,
    parameter,
    parameter_use,
    expected_count,
    actual_count,
    expected_type,
    actual_type,
    supplied_value,
    expression,
    source_kind,
    source_basis,
    source_key,
    source_row,
    field_path,
    byte_offset,
    expected_resource,
    actual_resource,
    expected_source,
    actual_source,
    expected_revision,
    actual_revision,
    expected_schema,
    actual_schema,
    expected_policy,
    actual_policy,
    budget,
    limit,
    required,
    unit,
    completed_statements,
    emitted_rows,
    emitted_segments,
    completion,
    proposal,
    step,
    generation,
    attachment,
    lease,
    schema_origin,
    sampling_records,
    operation,
    native_cause,
};
pub const Text = BoundedText(256);
pub const Code = BoundedText(96);
pub const Message = BoundedText(384);
pub const Path = BoundedText(512);
pub const Unsigned = Decimal(u64);
pub const Signed = Decimal(i64);
pub const Identity = struct {
    domain: Domain,
    id: Unsigned,
    realm: ?Unsigned = null,
    resource: ?Unsigned = null,
    sequence: ?Unsigned = null,
};
pub const Location = struct {
    source: ?Path = null,
    source_encoding: enum { utf8, escaped_bytes } = .utf8,
    source_truncated: bool = false,
    statement: ?Unsigned = null,
    offset: Unsigned,
    length: Unsigned,
    line: Unsigned,
    byte_column: Unsigned,
};
/// Owned filesystem names preserve POSIX bytes without inventing a Unicode
/// filename. Truncation never splits UTF-8 or a four-byte escape.
pub const SourcePath = struct {
    path: Path,
    truncated: bool,
    encoding: @FieldType(Location, "source_encoding"),
    pub fn init(source: []const u8) !SourcePath {
        if (std.unicode.utf8ValidateSlice(source)) {
            const path = try Path.truncate(source);
            return .{ .path = path, .truncated = path.slice().len != source.len, .encoding = .utf8 };
        }
        var buffer: [512]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        var copied: usize = 0;
        for (source) |byte| {
            const printable = byte >= 0x20 and byte <= 0x7e and byte != '\\' and byte != '"';
            const needed: usize = if (printable) 1 else 4;
            if (out.buffer.len - out.end < needed) break;
            if (printable) try out.writeByte(byte) else try out.print("\\x{x:0>2}", .{byte});
            copied += 1;
        }
        return .{ .path = try Path.init(out.buffered()), .truncated = copied != source.len, .encoding = .escaped_bytes };
    }
    pub fn apply(self: SourcePath, location: *Location) void {
        location.source = self.path;
        location.source_truncated = self.truncated;
        location.source_encoding = self.encoding;
    }
};
pub const Value = union(enum) { text: Text, signed: Signed, unsigned: Unsigned, boolean: bool, digest: [32]u8, location: Location };
pub const Fact = struct { field: Field, origin: Origin, availability: Availability, value: ?Value };
pub const Action = struct { kind: ActionKind, target: ?Identity = null };

version: u8,
definition: p.Growth.Definition,
code: Code,
category: Category,
stage: Stage,
outcome: Outcome,
evidence: Evidence,
message: Message,
cause: ?Code = null,
identity: ?Identity = null,
location: ?Location = null,
facts: [16]?Fact = @splat(null),
actions: [4]?Action = @splat(null),

pub fn init(code: []const u8, category: Category, stage: Stage, outcome: Outcome, evidence: Evidence, message: []const u8) !Self {
    return .{ .version = 1, .definition = p.Growth.current_definition, .code = try Code.init(code), .category = category, .stage = stage, .outcome = outcome, .evidence = evidence, .message = try Message.init(message) };
}
pub fn fact(self: *Self, field: Field, origin: Origin, value: Value) !void {
    return self.add(.{ .field = field, .origin = origin, .availability = .provided, .value = value });
}
pub fn text(self: *Self, field: Field, origin: Origin, bytes: []const u8) !void {
    const value = try Text.truncate(bytes);
    return self.add(.{ .field = field, .origin = origin, .availability = if (value.slice().len < bytes.len) .truncated else .provided, .value = .{ .text = value } });
}
pub fn absent(self: *Self, field: Field, origin: Origin, reason: Availability) !void {
    if (reason == .provided or reason == .truncated) return error.InvalidDiagnostic;
    return self.add(.{ .field = field, .origin = origin, .availability = reason, .value = null });
}
pub fn add(self: *Self, value: Fact) !void {
    for (&self.facts) |*slot| if (slot.* == null) {
        slot.* = value;
        return;
    };
    return error.DiagnosticCapacity;
}
pub fn action(self: *Self, kind: ActionKind) !void {
    for (&self.actions) |*slot| if (slot.* == null) {
        const value: Action = .{ .kind = kind, .target = self.identity };
        try self.validateAction(value);
        slot.* = value;
        return;
    };
    return error.DiagnosticCapacity;
}
pub fn validate(self: Self) !void {
    if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDiagnostic;
    try self.code.validate();
    const code = self.code.slice();
    if (code.len == 0 or code[0] == '.' or code[code.len - 1] == '.' or std.mem.indexOf(u8, code, "..") != null) return error.InvalidDiagnostic;
    for (code) |byte| if (!(byte >= 'a' and byte <= 'z') and !std.ascii.isDigit(byte) and byte != '_' and byte != '.') return error.InvalidDiagnostic;
    try self.message.validate();
    if (self.cause) |cause| try cause.validate();
    switch (self.outcome) {
        .not_submitted => if (self.evidence != .local_before_dispatch) return error.InvalidDiagnostic,
        .prepared => if (self.evidence != .saved_intent) return error.InvalidDiagnostic,
        .rejected, .applied, .cancelled, .retired, .input_rejected, .closed_unknown => if (self.evidence != .domain_status) return error.InvalidDiagnostic,
        .pending => if (self.evidence != .domain_status and self.evidence != .native_receipt) return error.InvalidDiagnostic,
        .unknown => if (self.evidence == .domain_status or self.evidence == .native_receipt) return error.InvalidDiagnostic,
        .not_applicable => {},
    }
    if (self.identity) |identity| try validateIdentity(identity);
    if (self.location) |location| try validateLocation(location);
    var end = false;
    for (self.facts) |slot| {
        if (slot) |item| {
            if (end) return error.InvalidDiagnostic;
            if ((item.availability == .provided or item.availability == .truncated) != (item.value != null)) return error.InvalidDiagnostic;
            if (item.value) |value| switch (value) {
                .text => |v| try v.validate(),
                .signed => |v| _ = try v.value(),
                .unsigned => |v| _ = try v.value(),
                .location => |v| try validateLocation(v),
                else => {},
            };
        } else end = true;
    }
    end = false;
    for (self.actions, 0..) |slot, i| {
        if (slot) |item| {
            if (end) return error.InvalidDiagnostic;
            try self.validateAction(item);
            for (self.actions[0..i]) |previous| if (previous.?.kind == item.kind) return error.InvalidDiagnostic;
        } else end = true;
    }
    // Field byte limits alone do not bound JSON escaping (notably locations
    // containing control bytes). Check the largest supported escaped form.
    var bytes: [max_json_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var out: std.json.Stringify = .{ .writer = &writer, .options = .{ .escape_unicode = true } };
    self.writeFields(&out) catch return error.DiagnosticCapacity;
}
fn validateIdentity(identity: Identity) !void {
    if (try identity.id.value() == 0) return error.InvalidDiagnostic;
    inline for (.{ "realm", "resource", "sequence" }) |field| if (@field(identity, field)) |number| {
        const value = try number.value();
        if (value == 0 or value > p.max_counter) return error.InvalidDiagnostic;
    };
}
fn validateLocation(location: Location) !void {
    if (location.source) |source| {
        try source.validate();
        if (location.source_encoding == .escaped_bytes) {
            const bytes = source.slice();
            var at: usize = 0;
            while (at < bytes.len) {
                if (bytes[at] == '\\') {
                    if (bytes.len - at < 4 or bytes[at + 1] != 'x') return error.InvalidDiagnostic;
                    for (bytes[at + 2 .. at + 4]) |digit| if (!std.ascii.isDigit(digit) and !(digit >= 'a' and digit <= 'f')) return error.InvalidDiagnostic;
                    at += 4;
                } else {
                    if (bytes[at] < 0x20 or bytes[at] > 0x7e or bytes[at] == '"') return error.InvalidDiagnostic;
                    at += 1;
                }
            }
        }
    } else if (location.source_truncated or location.source_encoding != .utf8) return error.InvalidDiagnostic;
    if (try location.line.value() == 0 or try location.byte_column.value() == 0) return error.InvalidDiagnostic;
    if (location.statement) |statement| if (try statement.value() == 0) return error.InvalidDiagnostic;
    _ = try std.math.add(u64, try location.offset.value(), try location.length.value());
}
fn validateAction(self: Self, item: Action) !void {
    if (item.target) |target| try validateIdentity(target);
    switch (item.kind) {
        .resume_exact, .cancel_wait, .cancel_mutation, .reconcile_effect => {
            if (self.identity == null or item.target == null or !std.meta.eql(self.identity.?, item.target.?)) return error.InvalidDiagnostic;
            if (self.outcome != .unknown and self.outcome != .prepared and self.outcome != .pending and self.outcome != .input_rejected and !(self.outcome == .closed_unknown and item.kind == .reconcile_effect)) return error.InvalidDiagnostic;
            if (item.kind == .cancel_mutation and item.target.?.domain != .mutation) return error.InvalidDiagnostic;
            if (item.kind == .reconcile_effect and item.target.?.domain != .effect) return error.InvalidDiagnostic;
            if (item.target.?.domain == .effect and item.kind != .reconcile_effect) return error.InvalidDiagnostic;
        },
        .correct_input, .recompile => if (self.outcome == .unknown or self.outcome == .pending or self.outcome == .prepared or self.outcome == .input_rejected or self.outcome == .closed_unknown) return error.InvalidDiagnostic,
        .retry_read, .refresh, .inspect_scope, .inspect_status, .contact_operator => {},
    }
}
pub fn jsonStringify(self: Self, out: *std.json.Stringify) !void {
    self.validate() catch return error.WriteFailed;
    return self.writeFields(out);
}
fn writeFields(self: Self, out: *std.json.Stringify) !void {
    try out.beginObject();
    inline for (@typeInfo(Self).@"struct".field_names) |name| {
        try out.objectField(name);
        try p.Json.write(@field(self, name), out);
    }
    try out.endObject();
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_json_bytes)]);
    try std.json.Stringify.value(self, .{}, &writer);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_json_bytes) return error.DiagnosticCapacity;
    const parsed = try p.Json.parseFromSlice(Self, allocator, bytes);
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}
pub fn BoundedText(comptime capacity: usize) type {
    return struct {
        bytes: [capacity]u8 = @splat(0),
        len: u16 = 0,
        const T = @This();
        pub fn init(bytes: []const u8) !T {
            if (bytes.len > capacity or !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidDiagnosticText;
            var value: T = .{ .len = @intCast(bytes.len) };
            @memcpy(value.bytes[0..bytes.len], bytes);
            return value;
        }
        pub fn truncate(bytes: []const u8) !T {
            if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidDiagnosticText;
            var end = @min(bytes.len, capacity);
            while (!std.unicode.utf8ValidateSlice(bytes[0..end])) end -= 1;
            return T.init(bytes[0..end]);
        }
        pub fn slice(self: *const T) []const u8 {
            return self.bytes[0..self.len];
        }
        pub fn validate(self: T) !void {
            if (self.len > capacity or !std.mem.allEqual(u8, self.bytes[self.len..], 0) or !std.unicode.utf8ValidateSlice(self.slice())) return error.InvalidDiagnosticText;
        }
        pub fn jsonStringify(self: T, out: anytype) !void {
            self.validate() catch return error.WriteFailed;
            try out.write(self.slice());
        }
        pub fn jsonParse(allocator: std.mem.Allocator, input: anytype, options: std.json.ParseOptions) !T {
            const token = try input.peekNextTokenType();
            if (token != .string) return error.UnexpectedToken;
            return T.init(try std.json.innerParse([]const u8, allocator, input, options)) catch return error.InvalidCharacter;
        }
        pub fn jsonSchema(out: anytype) !void {
            try out.beginObject();
            try p.Schema.field(out, "type", "string");
            try p.Schema.field(out, "maxLength", capacity);
            try p.Schema.field(out, "x-transit-max-utf8-bytes", capacity);
            try out.endObject();
        }
    };
}
pub fn Decimal(comptime N: type) type {
    return struct {
        text: BoundedText(20),
        const T = @This();
        pub fn init(number: N) T {
            var buffer: [20]u8 = undefined;
            return .{ .text = BoundedText(20).init(std.fmt.bufPrint(&buffer, "{d}", .{number}) catch unreachable) catch unreachable };
        }
        pub fn value(self: T) !N {
            try self.text.validate();
            const number = std.fmt.parseInt(N, self.text.slice(), 10) catch return error.InvalidDiagnosticNumber;
            const canonical = T.init(number);
            if (!std.mem.eql(u8, canonical.text.slice(), self.text.slice())) return error.InvalidDiagnosticNumber;
            return number;
        }
        pub fn jsonStringify(self: T, out: anytype) !void {
            _ = self.value() catch return error.WriteFailed;
            try out.write(self.text.slice());
        }
        pub fn jsonParse(allocator: std.mem.Allocator, input: anytype, options: std.json.ParseOptions) !T {
            const result: T = .{ .text = try BoundedText(20).jsonParse(allocator, input, options) };
            _ = result.value() catch return error.InvalidNumber;
            return result;
        }
        pub fn jsonSchema(out: anytype) !void {
            try out.beginObject();
            try p.Schema.field(out, "type", "string");
            try p.Schema.field(out, "maxLength", 20);
            try p.Schema.field(out, "pattern", if (N == i64) "^(0|-?[1-9][0-9]*)$" else "^(0|[1-9][0-9]*)$");
            try out.endObject();
        }
    };
}

test "diagnostics retain full-width owned evidence and reject invented recovery" {
    const t = std.testing;
    var value = try init("mutation.primary_key_conflict", .constraint, .execute, .rejected, .domain_status, "Duplicate primary key; no rows were inserted.");
    value.identity = .{ .domain = .mutation, .id = .init(std.math.maxInt(u64)) };
    try value.fact(.key, .caller, .{ .signed = .init(std.math.minInt(i64)) });
    try value.absent(.constraint, .schema, .unrecorded);
    try value.action(.correct_input);
    try t.expectError(error.InvalidDiagnostic, value.action(.resume_exact));
    try t.expectError(error.InvalidDiagnostic, value.action(.cancel_mutation));
    var bytes: [max_json_bytes]u8 = undefined;
    const encoded = try value.encode(&bytes);
    const restored = try decode(t.allocator, encoded);
    try t.expectEqualDeep(value, restored);
    @memset(&bytes, 0);
    try t.expectEqual(std.math.maxInt(u64), try restored.identity.?.id.value());
    try t.expectEqual(std.math.minInt(i64), try restored.facts[0].?.value.?.signed.value());
    var unknown = try init("transport.unconfirmed", .unavailable, .submit, .unknown, .saved_intent, "Submission is unconfirmed; retain exact operation identity.");
    unknown.identity = value.identity;
    try unknown.action(.resume_exact);
    try t.expectError(error.InvalidDiagnostic, unknown.action(.correct_input));
    unknown.identity.?.domain = .effect;
    try t.expectError(error.InvalidDiagnostic, unknown.validate());
    unknown.actions = @splat(null);
    try unknown.action(.reconcile_effect);
    try unknown.validate();
}

test "diagnostic decoding is strict and absent detail is explicit" {
    const t = std.testing;
    inline for (.{ "1", "\"01\"", "\"-0\"", "\"+1\"", "\"18446744073709551616\"" }) |invalid| {
        if (std.json.parseFromSlice(Unsigned, t.allocator, invalid, .{})) |parsed| {
            parsed.deinit();
            return error.AcceptedInvalidDiagnostic;
        } else |_| {}
    }
    var value = try init("sql.binding", .binding, .bind, .not_submitted, .local_before_dispatch, "Invalid binding.");
    try value.text(.supplied_value, .caller, &(@as([300]u8, @splat('a'))));
    try t.expectEqual(Availability.truncated, value.facts[0].?.availability);
    value.facts[0].?.availability = .withheld;
    try t.expectError(error.InvalidDiagnostic, value.validate());
    value.facts[0].?.value = null;
    try value.validate();
    value.outcome = .applied;
    try t.expectError(error.InvalidDiagnostic, value.validate());
    const Text4 = BoundedText(4);
    try t.expectEqualStrings("東", (try Text4.truncate("東京")).slice());
}

test "independent diagnostic fixture survives ownership and allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            const value = try decode(allocator, @embedFile("fixtures/diagnostic-v1.json"));
            try std.testing.expectEqual(std.math.minInt(i64), try value.facts[0].?.value.?.signed.value());
            try std.testing.expectEqual(std.math.maxInt(u64), try value.identity.?.id.value());
        }
    }.run, .{});
}

test "diagnostic shape rejects foreign definitions, omitted definitions and string digests" {
    const t = std.testing;
    const fixture = @embedFile("fixtures/diagnostic-v1.json");
    inline for (.{ "definition", "version" }) |field| {
        const tree = try std.json.parseFromSlice(std.json.Value, t.allocator, fixture, .{});
        defer tree.deinit();
        var value = tree.value;
        try t.expect(value.object.swapRemove(field));
        const bytes = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
        defer t.allocator.free(bytes);
        try t.expectError(error.MissingField, decode(t.allocator, bytes));
    }
    var value = try decode(t.allocator, fixture);
    value.version = 2;
    try t.expectError(error.IncompatibleDiagnostic, value.validate());
    value.version = 1;
    value.facts[2] = .{ .field = .source_basis, .origin = .execution, .availability = .provided, .value = .{ .digest = @splat('a') } };
    var buffer: [max_json_bytes]u8 = undefined;
    const bytes = try value.encode(&buffer);
    try t.expect(std.mem.indexOf(u8, bytes, "\"digest\":[97,97") != null);
    try t.expectEqualDeep(value, try decode(t.allocator, bytes));
    value.actions[0] = .{ .kind = .resume_exact, .target = value.identity };
    try t.expectError(error.InvalidDiagnostic, value.validate());
}

test "escaped byte paths reject ambiguous or partial escape sequences" {
    var value = try init("sql.syntax", .syntax, .parse, .not_submitted, .local_before_dispatch, "Invalid SQL.");
    value.location = .{ .source = try Path.init("a\\xff"), .source_encoding = .escaped_bytes, .offset = .init(0), .length = .init(0), .line = .init(1), .byte_column = .init(1) };
    try value.validate();
    for ([_][]const u8{ "a\\x", "a\\xff\\", "a\\xFF", "a\n", "a\"", "東京" }) |path| {
        value.location.?.source = try Path.init(path);
        try std.testing.expectError(error.InvalidDiagnostic, value.validate());
    }
}

test "encoded diagnostic bounds include escaping inside fact locations" {
    const t = std.testing;
    var value = try init("sql.location_failure", .syntax, .parse, .not_submitted, .local_before_dispatch, "Input contains invalid locations.");
    const location: Location = .{ .source = try Path.init(&@as([512]u8, @splat(1))), .offset = .init(0), .length = .init(0), .line = .init(1), .byte_column = .init(1) };
    for (0..8) |_| try value.fact(.parameter_use, .caller, .{ .location = location });
    try value.validate();
    for (0..8) |_| try value.fact(.parameter_use, .caller, .{ .location = location });
    try t.expectError(error.DiagnosticCapacity, value.validate());
}

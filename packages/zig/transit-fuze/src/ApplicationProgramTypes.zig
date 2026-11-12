//! Static value and resource binding for ordered programs. Protected bytes never
//! acquire an ordinary SQL scalar type. Queue capability fields carry only a
//! non-authorizing handle; redemption remains a checked native operation.
const std = @import("std");
const ast = @import("ApplicationProgram.zig");
const sql = @import("Sql.zig");
pub const NativeDependencies = std.EnumSet(@import("NativeBinding.zig").Kind);
pub const Kind = enum { null, boolean, integer, text, binary, uuid, timestamp, duration, json, record, secret, protected_json, capability, failure };
pub const Value = struct {
    kind: Kind,
    nullable: bool = false,
    protected: bool = false,
    fields: []const Field = &.{},
    pub fn public(kind: Kind) Value {
        return .{ .kind = kind };
    }
};
pub const Field = struct { name: []const u8, value: Value };
// These nested descriptors outlive bind() and every recursive block call.
// Keep their storage static instead of borrowing a runtime array literal.
const failure_value: Value = .{ .kind = .failure, .fields = &.{.{ .name = "effect_outcome", .value = Value.public(.text) }} };
const effect_value: Value = .{ .kind = .record, .fields = &.{
    .{ .name = "status", .value = Value.public(.integer) },
    .{ .name = "body", .value = .{ .kind = .protected_json, .protected = true } },
} };
pub const Resource = struct {
    name: []const u8,
    kind: enum { table, document, kv, stream, queue, sink },
    fields: []const Field,
    key: []const []const u8 = &.{},
};
pub const Use = struct {
    resource: u16,
    read: bool = false,
    write: bool = false,
    consume: bool = false,
    observe_time: bool = false,
    dispatch: bool = false,
    guard: bool = false,
};
/// Required execution facilities, derived from the complete typed program,
/// including branches and failure handlers. These describe host support, never
/// authority, readiness of a catalog dependency, or permission to dispatch.
pub const Requirements = struct {
    pub const Feature = enum { protected_values, effects, handoff, responses, pages, deadline };
    functions: std.EnumSet(ast.Function) = .empty,
    features: std.EnumSet(Feature) = .empty,

    /// Facilities implemented by the installed public-data host. Source target
    /// checking and host readiness use this same declaration; it grants no rights.
    pub fn publicData() Requirements {
        return .{ .functions = .initMany(&.{ .random_token, .digest, .commitment, .now, .seconds, .current_revision, .url, .json_object, .s256, .length, .secure_equal, .operation_id, .json_value, .json_integer, .identity_digest }) };
    }

    pub fn requireAvailable(self: Requirements, available: Requirements) !void {
        if (self.functions.differenceWith(available.functions).count() != 0 or
            self.features.differenceWith(available.features).count() != 0) return error.ApplicationHostUnavailable;
    }
    fn value(self: *Requirements, selected: Value) void {
        if (selected.protected or selected.kind == .secret or selected.kind == .protected_json or selected.kind == .capability)
            self.features.insert(.protected_values);
        for (selected.fields) |entry| self.value(entry.value);
    }
};
pub const Bound = struct {
    arena: std.heap.ArenaAllocator,
    input: Value,
    values: []const ?Value,
    uses: []const Use,
    /// Canonical native owners required by helpers without a SQL resource
    /// operand. Executable declarations must resolve these before publication.
    native: NativeDependencies,
    requirements: Requirements,
    pub fn deinit(self: *Bound) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
const Symbol = struct { name: []const u8, value: Value };
const Self = @This();
allocator: std.mem.Allocator,
resources: []const Resource,
values: []?Value,
uses: std.ArrayList(Use) = .empty,
native: NativeDependencies = .empty,
requirements: Requirements = .{},
symbols: std.ArrayList(Symbol) = .empty,
location: ?*sql.Location,
columns: []const Field = &.{},
expression_depth: usize = 0,

pub fn bind(allocator: std.mem.Allocator, program: ast.Program, resources: []const Resource, location: ?*sql.Location) !Bound {
    try ast.Codec.validate(program);
    if (resources.len > 256 or program.nodes > ast.max_nodes) return error.ProgramTooComplex;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const values = try arena.allocator().alloc(?Value, @as(usize, program.nodes) + 1);
    @memset(values, null);
    const owned_resources = try arena.allocator().alloc(Resource, resources.len);
    for (resources, owned_resources) |source, *target| {
        target.* = source;
        target.name = try arena.allocator().dupe(u8, source.name);
        target.fields = try cloneFields(arena.allocator(), source.fields, 0);
    }
    var self: Self = .{ .allocator = arena.allocator(), .resources = owned_resources, .values = values, .location = location };
    for (resources, 0..) |candidate, index| for (resources[0..index]) |prior| {
        if (std.mem.eql(u8, candidate.name, prior.name)) return error.DuplicateProgramResource;
    };
    const queue = try self.resource(program.queue, .queue, .{ .resource = 0, .read = true, .consume = true });
    try self.define(program.input, .{ .kind = .record, .fields = queue.fields });
    self.requirements.value(.{ .kind = .record, .fields = queue.fields });
    if (program.deadline != null) self.requirements.features.insert(.deadline);
    if (program.predicate) |predicate| {
        self.columns = queue.fields;
        try requireKind(try self.expression(predicate), .boolean);
        self.columns = &.{};
    }
    switch (program.body) {
        .instructions => |instructions| try self.block(instructions),
        .page => |page| {
            self.requirements.features.insert(.pages);
            _ = try self.select(page.select);
            try requireKind(try self.expression(page.request), .capability);
            if (!std.mem.eql(u8, page.profile, "browser_provider_page_v1") or page.size != 8) return error.UnsupportedProgramProfile;
        },
    }
    if (program.failure) |failure| {
        // A failure continuation may run after loss/restart. Its environment is
        // the original input and typed failure, never a partially executed LET.
        self.symbols.shrinkRetainingCapacity(1);
        try self.define(failure.name, failure_value);
        try self.block(failure.instructions);
    }
    if (self.requirements.features.contains(.effects) or self.requirements.features.contains(.deadline))
        _ = try self.resource(program.queue, .queue, .{ .resource = 0, .observe_time = true });
    for (values) |selected| if (selected) |value_| self.requirements.value(value_);
    return .{ .arena = arena, .input = .{ .kind = .record, .fields = queue.fields }, .values = values, .uses = try self.uses.toOwnedSlice(self.allocator), .native = self.native, .requirements = self.requirements };
}
fn cloneFields(allocator: std.mem.Allocator, fields: []const Field, depth: usize) ![]const Field {
    if (depth == ast.max_depth or fields.len > ast.max_arguments) return error.ProgramTooComplex;
    const result = try allocator.alloc(Field, fields.len);
    for (fields, result, 0..) |source, *target, index| {
        if (source.name.len == 0 or source.name.len > 255) return error.InvalidColumnName;
        for (fields[0..index]) |prior| if (std.mem.eql(u8, source.name, prior.name)) return error.DuplicateProgramField;
        target.* = source;
        target.name = try allocator.dupe(u8, source.name);
        target.value.fields = if (source.value.fields.len == 0) &.{} else try cloneFields(allocator, source.value.fields, depth + 1);
    }
    return result;
}
fn resource(self: *Self, name: []const u8, kind: ?@FieldType(Resource, "kind"), usage: Use) !Resource {
    for (self.resources, 0..) |candidate, index| if (std.mem.eql(u8, name, candidate.name)) {
        if (kind) |expected| if (candidate.kind != expected) return error.ProgramResourceKindMismatch;
        for (self.uses.items) |*prior| if (prior.resource == index) {
            prior.read = prior.read or usage.read;
            prior.write = prior.write or usage.write;
            prior.consume = prior.consume or usage.consume;
            prior.observe_time = prior.observe_time or usage.observe_time;
            prior.dispatch = prior.dispatch or usage.dispatch;
            prior.guard = prior.guard or usage.guard;
            return candidate;
        };
        var owned = usage;
        owned.resource = @intCast(index);
        try self.uses.append(self.allocator, owned);
        return candidate;
    };
    return error.UnknownProgramResource;
}
fn define(self: *Self, name: []const u8, value: Value) !void {
    for (self.symbols.items) |prior| if (std.mem.eql(u8, name, prior.name)) return error.DuplicateProgramVariable;
    try self.symbols.append(self.allocator, .{ .name = name, .value = value });
}
fn field(value: Value, name: []const u8) !Value {
    if (value.kind == .secret and std.mem.eql(u8, name, "revision")) return .{ .kind = .binary, .nullable = value.nullable };
    if (value.kind != .record and value.kind != .failure) return error.ProgramTypeMismatch;
    for (value.fields) |entry| if (std.mem.eql(u8, name, entry.name)) {
        var result = entry.value;
        result.nullable = result.nullable or value.nullable;
        result.protected = result.protected or value.protected;
        return result;
    };
    return error.UnknownProgramField;
}
fn requireKind(value: Value, kind: Kind) !void {
    if (value.kind != kind and value.kind != .null) return error.ProgramTypeMismatch;
}
fn public(value: Value) !void {
    if (value.protected or value.kind == .secret or value.kind == .protected_json or value.kind == .capability or value.kind == .failure) return error.ProtectedProgramValue;
    for (value.fields) |entry| try public(entry.value);
}
fn compatible(target: Value, value: Value) anyerror!void {
    if (value.kind == .null) {
        if (!target.nullable) return error.ProgramNullabilityMismatch;
        return;
    }
    if (target.kind != value.kind) return error.ProgramTypeMismatch;
    // Nullable inputs are checked at the statement boundary. A SQL REQUIRE or
    // conditional can narrow them at runtime; null never becomes a default.
    if (target.kind == .record) {
        if (target.fields.len != value.fields.len) return error.ProgramTypeMismatch;
        for (target.fields, value.fields) |expected, actual| try compatible(expected.value, actual.value);
    }
}
fn stored(target: Value, value: Value, queue: bool) !void {
    try compatible(target, value);
    if (queue and target.kind == .capability and value.kind == .capability and !value.protected) return;
    try public(value);
}
fn record(self: *Self, resource_: Resource, nullable: bool) !Value {
    const fields = try self.allocator.alloc(Field, resource_.fields.len + 1);
    @memcpy(fields[0..resource_.fields.len], resource_.fields);
    fields[fields.len - 1] = .{ .name = "_revision", .value = Value.public(.binary) };
    return .{ .kind = .record, .fields = fields, .nullable = nullable };
}
fn select(self: *Self, query: ast.Select) !Value {
    const source = try self.resource(query.target, null, .{ .resource = 0, .read = true });
    if (source.kind != .table and source.kind != .document) return error.ProgramResourceKindMismatch;
    const previous = self.columns;
    self.columns = source.fields;
    defer self.columns = previous;
    if (query.predicate) |predicate| try requireKind(try self.expression(predicate), .boolean);
    if (query.columns) |names| {
        const fields = try self.allocator.alloc(Field, names.len);
        for (names, fields) |name, *entry| entry.* = .{ .name = try self.allocator.dupe(u8, name), .value = try field(.{ .kind = .record, .fields = source.fields }, name) };
        return .{ .kind = .record, .fields = fields, .nullable = true };
    }
    return self.record(source, true);
}
fn expression(self: *Self, node: *const ast.Expression) anyerror!Value {
    if (self.expression_depth == ast.max_depth) return error.ProgramTooDeep;
    self.expression_depth += 1;
    defer self.expression_depth -= 1;
    if (self.location) |location| location.offset = node.span.start;
    const result: Value = switch (node.value) {
        .null => .{ .kind = .null, .nullable = true },
        .boolean => Value.public(.boolean),
        .integer => Value.public(.integer),
        .text => Value.public(.text),
        .name => |name| blk: {
            for (self.symbols.items) |symbol| if (std.mem.eql(u8, symbol.name, name)) break :blk symbol.value;
            for (self.columns) |column| if (std.mem.eql(u8, column.name, name)) break :blk column.value;
            return error.UnknownProgramVariable;
        },
        .field => |entry| try field(try self.expression(entry.base), entry.name),
        .call => |invocation| try self.call(invocation.function, invocation.arguments),
        .unary => |unary| blk: {
            const operand = try self.expression(unary.operand);
            switch (unary.operator) {
                .not_ => try requireKind(operand, .boolean),
                .negate => try requireKind(operand, .integer),
                .is_null, .is_not_null => {},
            }
            break :blk .{ .kind = if (unary.operator == .negate) .integer else .boolean, .protected = operand.protected, .nullable = unary.operator != .is_null and unary.operator != .is_not_null and operand.nullable };
        },
        .binary => |binary| blk: {
            const left = try self.expression(binary.left);
            const right = try self.expression(binary.right);
            var kind: Kind = .boolean;
            switch (binary.operator) {
                .and_, .or_ => {
                    try requireKind(left, .boolean);
                    try requireKind(right, .boolean);
                },
                .concatenate => {
                    try requireKind(left, .text);
                    try requireKind(right, .text);
                    kind = .text;
                },
                .add, .subtract => {
                    if (left.kind == .timestamp and right.kind == .duration) kind = .timestamp else {
                        try requireKind(left, .integer);
                        try requireKind(right, .integer);
                        kind = .integer;
                    }
                },
                else => {
                    if (left.kind != .null and right.kind != .null and left.kind != right.kind) return error.ProgramTypeMismatch;
                    if (left.kind == .secret or right.kind == .secret or left.kind == .capability or right.kind == .capability or left.kind == .record) return error.ProtectedProgramValue;
                    for ([_]Kind{ left.kind, right.kind }) |operand| if (operand == .json or operand == .protected_json or operand == .failure) return error.ProgramTypeMismatch;
                },
            }
            break :blk .{ .kind = kind, .protected = left.protected or right.protected, .nullable = left.nullable or right.nullable };
        },
        .case => |choice| blk: {
            const condition = try self.expression(choice.condition);
            try requireKind(condition, .boolean);
            var yes = try self.expression(choice.yes);
            const no = try self.expression(choice.no);
            const nullable = yes.kind == .null or no.kind == .null or yes.nullable or no.nullable;
            if (yes.kind == .null) yes = no else if (no.kind != .null and yes.kind != no.kind) return error.ProgramTypeMismatch;
            yes.nullable = nullable;
            yes.protected = yes.protected or no.protected or condition.protected;
            break :blk yes;
        },
        .text_cast => |operand| blk: {
            const value = try self.expression(operand);
            try public(value);
            if (value.kind != .integer and value.kind != .text and value.kind != .uuid) return error.ProgramTypeMismatch;
            break :blk .{ .kind = .text, .nullable = value.nullable };
        },
        .row => |items| blk: {
            const fields = try self.allocator.alloc(Field, items.len);
            for (items, fields) |item, *entry| entry.* = .{ .name = "", .value = try self.expression(item) };
            break :blk .{ .kind = .record, .fields = fields };
        },
    };
    if (node.id == 0 or node.id >= self.values.len) return error.InvalidProgramNode;
    self.values[node.id] = result;
    return result;
}
fn call(self: *Self, function: ast.Function, arguments: []const *ast.Expression) !Value {
    self.requirements.functions.insert(function);
    if (function == .current_revision) {
        if (arguments.len != 2 or arguments[0].value != .name) return error.ProgramArgumentMismatch;
        _ = try self.resource(arguments[0].value.name, .document, .{ .resource = 0, .read = true, .guard = true });
        try public(try self.expression(arguments[1]));
        return .{ .kind = .binary, .nullable = true };
    }
    var values: [ast.max_arguments]Value = undefined;
    if (arguments.len > values.len) return error.ProgramArgumentMismatch;
    for (arguments, values[0..arguments.len]) |argument, *value| value.* = try self.expression(argument);
    const args = values[0..arguments.len];
    const arity: ?usize = switch (function) {
        .now => 0,
        .secret, .random_token, .random_secret, .digest, .commitment, .seconds, .secret_current, .s256, .length, .bearer, .native_identity_allowed, .native_session_current, .native_binding_active => 1,
        .url, .http_query, .http_query_unique, .http_secret_query_unique, .http_secret_cookie_unique, .secure_equal, .operation_id, .json_value, .secret_json_value, .json_integer => 2,
        .derive_secret, .identity_digest => 3,
        .json_object => null,
        .current_revision => unreachable,
    };
    if (arity) |expected| if (args.len != expected) return error.ProgramArgumentMismatch;
    switch (function) {
        .now => return Value.public(.timestamp),
        .secret => {
            try requireKind(args[0], .text);
            try public(args[0]);
            self.native.insert(.secret_references);
            return .{ .kind = .secret, .protected = true };
        },
        .random_token, .random_secret => {
            if (arguments[0].value != .integer or arguments[0].value.integer < 16 or arguments[0].value.integer > 64) return error.ProgramArgumentMismatch;
            return if (function == .random_token) Value.public(.text) else .{ .kind = .secret, .protected = true };
        },
        .derive_secret => {
            try requireKind(args[0], .secret);
            try requireKind(args[1], .text);
            try requireKind(args[2], .text);
            try public(args[1]);
            try public(args[2]);
            return .{ .kind = .secret, .protected = true };
        },
        .digest, .commitment, .s256 => {
            if (args[0].kind != .text and args[0].kind != .binary and args[0].kind != .secret) return error.ProgramTypeMismatch;
            if (function == .digest) try public(args[0]);
            return .{ .kind = if (function == .s256) .text else .binary, .nullable = args[0].nullable };
        },
        .secret_current => {
            try requireKind(args[0], .secret);
            self.native.insert(.secret_references);
            return Value.public(.boolean);
        },
        .seconds => {
            try requireKind(args[0], .integer);
            return Value.public(.duration);
        },
        .length => {
            try requireKind(args[0], .text);
            return .{ .kind = .integer, .nullable = args[0].nullable, .protected = args[0].protected };
        },
        .http_query, .http_query_unique, .http_secret_query_unique, .http_secret_cookie_unique => {
            try requireKind(args[0], .capability);
            if (arguments[1].value != .text) return error.ProgramArgumentMismatch;
            // The public query operations cannot redeem OAuth credentials or
            // cookies. Native redemption independently repeats this restriction.
            const name = arguments[1].value.text;
            const ordinary = function == .http_query or function == .http_query_unique;
            if (ordinary and !std.mem.eql(u8, name, "state") and !std.mem.eql(u8, name, "error")) return error.ProtectedProgramValue;
            return .{ .kind = if (ordinary) .text else .secret, .nullable = true, .protected = !ordinary };
        },
        .secure_equal => {
            for (args) |arg| if (arg.kind != .binary and arg.kind != .secret and arg.kind != .text) return error.ProgramTypeMismatch;
            return Value.public(.boolean);
        },
        .operation_id => {
            try requireKind(args[0], .uuid);
            try requireKind(args[1], .text);
            try public(args[1]);
            return Value.public(.uuid);
        },
        .identity_digest => {
            for (args) |arg| {
                try requireKind(arg, .text);
                try public(arg);
            }
            return Value.public(.text);
        },
        .native_identity_allowed, .native_binding_active => {
            try requireKind(args[0], .text);
            try public(args[0]);
            return Value.public(.boolean);
        },
        .native_session_current => {
            try requireKind(args[0], .binary);
            try public(args[0]);
            return Value.public(.boolean);
        },
        .json_value, .secret_json_value, .json_integer => {
            if (args[0].kind != .protected_json and args[0].kind != .json) return error.ProgramTypeMismatch;
            if (arguments[1].value != .text) return error.ProgramArgumentMismatch;
            const path = arguments[1].value.text;
            try ast.Json.validatePath(path);
            if (args[0].kind == .protected_json and function == .json_integer and !std.mem.eql(u8, path, "$.id")) return error.ProtectedProgramValue;
            return .{ .kind = if (function == .secret_json_value) .secret else if (function == .json_integer) .integer else .text, .nullable = true, .protected = function == .secret_json_value or (function == .json_value and args[0].kind == .protected_json) };
        },
        .bearer => {
            try requireKind(args[0], .secret);
            return .{ .kind = .secret, .protected = true };
        },
        .json_object => {
            if (args.len % 2 != 0) return error.ProgramArgumentMismatch;
            for (args, 0..) |arg, index| {
                if (index % 2 == 0) try requireKind(arg, .text);
                try public(arg);
                if (index % 2 != 0) switch (arg.kind) {
                    .null, .boolean, .integer, .text, .json => {},
                    else => return error.ProgramTypeMismatch,
                };
            }
            return Value.public(.json);
        },
        .url => {
            try requireKind(args[0], .text);
            try requireKind(args[1], .json);
            for (args) |arg| try public(arg);
            return Value.public(.text);
        },
        .current_revision => unreachable,
    }
}
fn block(self: *Self, instructions: []const ast.Instruction) anyerror!void {
    for (instructions) |instruction| {
        if (self.location) |location| location.offset = instruction.span.start;
        switch (instruction.value) {
            .let => |binding| {
                const value = switch (binding.value) {
                    .expression => |node| try self.expression(node),
                    .get => |get| blk: {
                        const target = try self.resource(get.target, .kv, .{ .resource = 0, .read = true });
                        try requireKind(try self.expression(get.key), .binary);
                        break :blk try self.record(target, true);
                    },
                    .select => |query| try self.select(query),
                    .effect => |effect| blk: {
                        self.requirements.features.insert(.effects);
                        _ = try self.resource(effect.sink, .sink, .{ .resource = 0, .dispatch = true });
                        try requireKind(try self.expression(effect.identity), .uuid);
                        try requireKind(try self.expression(effect.guard), .boolean);
                        const fields = switch (effect.request) {
                            .form, .headers => |fields| fields,
                        };
                        for (fields) |entry| {
                            const value_ = try self.expression(entry.value);
                            if (value_.kind != .text and value_.kind != .secret) return error.ProgramTypeMismatch;
                        }
                        break :blk effect_value;
                    },
                };
                self.values[instruction.id] = value;
                try self.define(binding.name, value);
            },
            .require => |check| try requireKind(try self.expression(check.condition), .boolean),
            .atomic => |body| {
                const count = self.symbols.items.len;
                try self.block(body);
                self.symbols.shrinkRetainingCapacity(count);
            },
            .conditional => |conditional| {
                try requireKind(try self.expression(conditional.condition), .boolean);
                const count = self.symbols.items.len;
                try self.block(conditional.yes);
                self.symbols.shrinkRetainingCapacity(count);
                try self.block(conditional.no);
                self.symbols.shrinkRetainingCapacity(count);
            },
            .put => |put| {
                const target = try self.resource(put.target, .kv, .{ .resource = 0, .write = true });
                try requireKind(try self.expression(put.key), .binary);
                const value = try self.expression(put.value);
                if (value.kind != .record) return error.ProgramTypeMismatch;
                if (put.fields.len == 0) {
                    if (value.fields.len != target.fields.len) return error.ProgramTypeMismatch;
                    for (target.fields, value.fields) |expected, actual| try stored(expected.value, actual.value, false);
                } else {
                    const record_ = try self.record(target, true);
                    try compatible(record_, value);
                    for (put.fields) |entry| {
                        if (std.mem.eql(u8, entry.name, "_revision")) return error.UnknownProgramField;
                        try stored(try field(record_, entry.name), try self.expression(entry.value), false);
                    }
                }
                if (put.expected == .revision) try requireKind(try self.expression(put.expected.revision), .binary);
            },
            .insert => |insert| {
                const target = try self.resource(insert.target, .table, .{ .resource = 0, .read = true, .write = true });
                if (insert.values.len != target.fields.len or insert.conflict_columns.len != target.key.len) return error.ProgramTypeMismatch;
                for (target.key, insert.conflict_columns) |expected, actual| if (!std.mem.eql(u8, expected, actual)) return error.ProgramTypeMismatch;
                for (target.fields, insert.values) |expected, actual| try stored(expected.value, try self.expression(actual), false);
            },
            .append => |append| {
                const target = try self.resource(append.target, if (append.kind == .queue) .queue else .stream, .{ .resource = 0, .write = true });
                if (append.values.len != target.fields.len) return error.ProgramTypeMismatch;
                for (target.fields, append.values) |expected, actual| try stored(expected.value, try self.expression(actual), append.kind == .queue);
            },
            .handoff => |handoff| {
                self.requirements.features.insert(.handoff);
                _ = try self.resource(handoff.queue, .queue, .{ .resource = 0, .write = true });
                try requireKind(try self.expression(handoff.request), .capability);
                try requireKind(try self.expression(handoff.effect), .uuid);
            },
            .respond => |response| {
                self.requirements.features.insert(.responses);
                try requireKind(try self.expression(response.request), .capability);
                if (response.guard) |guard| try requireKind(try self.expression(guard), .boolean);
                switch (response.body) {
                    .empty => {},
                    .json, .location => |body| {
                        const value = try self.expression(body);
                        try requireKind(value, if (response.body == .json) .json else .text);
                        try public(value);
                    },
                }
                for (response.cookies) |cookie| {
                    if (cookie.value) |node| try requireKind(try self.expression(node), .secret);
                    if (cookie.max_age) |node| try requireKind(try self.expression(node), .integer);
                }
            },
            .respond_error => |response| {
                self.requirements.features.insert(.responses);
                try requireKind(try self.expression(response.request), .capability);
                if (!std.mem.eql(u8, response.profile, "browser_v1")) return error.UnsupportedProgramProfile;
                var found = false;
                for (self.symbols.items) |symbol| if (std.mem.eql(u8, symbol.name, response.failure) and symbol.value.kind == .failure) {
                    found = true;
                };
                if (!found) return error.UnknownProgramVariable;
            },
        }
    }
}

const test_resources = [_]Resource{
    .{ .name = "requests", .kind = .queue, .fields = &.{ .{ .name = "id", .value = Value.public(.uuid) }, .{ .name = "ref", .value = Value.public(.capability) } } },
    .{ .name = "outcomes", .kind = .stream, .fields = &.{.{ .name = "value", .value = Value.public(.text) }} },
    .{ .name = "state", .kind = .kv, .fields = &.{.{ .name = "value", .value = Value.public(.text) }} },
    .{ .name = "sink", .kind = .sink, .fields = &.{} },
};

test "application program types reject protected disclosure and invalid bindings" {
    const t = std.testing;
    const cases = .{
        .{ "LET x = absent;", error.UnknownProgramVariable },
        .{ "LET x = request.absent;", error.UnknownProgramField },
        .{ "LET x = 1; LET x = 2;", error.DuplicateProgramVariable },
        .{ "IF TRUE THEN LET local = 'x'; END IF; LET x = local;", error.UnknownProgramVariable },
        .{ "LET x = SECRET('key'); RESPOND TO request.ref STATUS 200 JSON JSON_OBJECT('leak', x);", error.ProtectedProgramValue },
        .{ "LET x = SECRET('key'); BEGIN ATOMIC PRODUCE INTO outcomes VALUES (x); END;", error.ProgramTypeMismatch },
        .{ "LET x = HTTP_QUERY(request.ref, 'code');", error.ProtectedProgramValue },
        .{ "LET x = CAST(SECRET('key') AS TEXT);", error.ProtectedProgramValue },
        .{ "LET x = DIGEST(SECRET('key'));", error.ProtectedProgramValue },
        .{ "LET x = GET FROM outcomes KEY DIGEST('key');", error.ProgramResourceKindMismatch },
        .{ "REQUIRE 'true' ELSE 'WrongType';", error.ProgramTypeMismatch },
        .{ "LET x = RANDOM_SECRET(100);", error.ProgramArgumentMismatch },
        .{ "RESPOND ERROR TO request.ref USING request PUBLIC PROFILE 'browser_v1';", error.UnknownProgramVariable },
    };
    inline for (cases) |entry| {
        const text = "CREATE DATAFLOW x FROM QUEUE requests AS request AS BEGIN " ++ entry[0] ++ " END;";
        var parsed = try ast.parse(t.allocator, text, null);
        defer parsed.deinit();
        try t.expectError(entry[1], bind(t.allocator, parsed.program, &test_resources, null));
    }
}

test "application program types keep commits and approved secret uses explicit" {
    const t = std.testing;
    var parsed = try ast.parse(t.allocator,
        \\CREATE DATAFLOW x FROM QUEUE requests AS request AS BEGIN
        \\  LET secret = SECRET('key');
        \\  LET result = EXECUTE SINK sink EFFECT OPERATION_ID(request.id, 'exchange')
        \\    GUARD SECRET_CURRENT(secret) FORM (client_secret = secret) ON REPLAY OBSERVE ONLY;
        \\  REQUIRE JSON_VALUE(result.body, '$.error') IS NULL ELSE 'ExchangeRefused';
        \\  LET token = SECRET_JSON_VALUE(result.body, '$.access_token');
        \\  BEGIN ATOMIC
        \\    PUT INTO state KEY COMMITMENT(token) VALUE ROW('committed') IF ABSENT;
        \\  END;
        \\  RESPOND TO request.ref STATUS 200 JSON JSON_OBJECT('ok', TRUE)
        \\    SET COOKIE '__Host-session' VALUE token SECURE HTTPONLY SAMESITE LAX PATH '/' MAX AGE 30;
        \\END;
    , null);
    defer parsed.deinit();
    var bound = try bind(t.allocator, parsed.program, &test_resources, null);
    defer bound.deinit();
    try t.expectEqual(3, bound.uses.len);
    try t.expect(bound.native.contains(.secret_references));
    try t.expect(bound.uses[0].read and bound.uses[0].consume and !bound.uses[0].write);
    try t.expect(bound.uses[0].observe_time);
    try t.expect(bound.uses[1].dispatch);
    try t.expect(bound.uses[2].write);
    const token_expression = parsed.program.body.instructions[3].value.let.value.expression;
    try t.expectEqual(.secret, bound.values[token_expression.id].?.kind);
    try t.expect(bound.values[token_expression.id].?.protected);
    try t.expect(bound.requirements.features.contains(.effects));
    try t.expect(bound.requirements.features.contains(.responses));
    try t.expect(bound.requirements.features.contains(.protected_values));
    try t.expect(bound.requirements.functions.contains(.secret_json_value));
}

test "application host requirements include unreachable branches and failure continuations" {
    const t = std.testing;
    var parsed = try ast.parse(t.allocator,
        \\CREATE DATAFLOW x FROM QUEUE requests AS request AS BEGIN
        \\  IF FALSE THEN LET material = RANDOM_SECRET(32); END IF;
        \\ON FAILURE failure
        \\  RESPOND ERROR TO request.ref USING failure PUBLIC PROFILE 'browser_v1';
        \\END;
    , null);
    defer parsed.deinit();
    var bound = try bind(t.allocator, parsed.program, &test_resources, null);
    defer bound.deinit();
    try t.expect(!bound.uses[0].observe_time);
    try t.expect(bound.requirements.functions.contains(.random_secret));
    try t.expect(bound.requirements.features.contains(.protected_values));
    try t.expect(bound.requirements.features.contains(.responses));
    try t.expectError(error.ApplicationHostUnavailable, bound.requirements.requireAvailable(.{}));
    var available = bound.requirements;
    available.features.remove(.responses);
    try t.expectError(error.ApplicationHostUnavailable, bound.requirements.requireAvailable(available));
    try bound.requirements.requireAvailable(.{ .functions = .full, .features = .full });
}

test "application program types bound left-associated expression depth" {
    const t = std.testing;
    var source: std.Io.Writer.Allocating = .init(t.allocator);
    defer source.deinit();
    try source.writer.writeAll("CREATE DATAFLOW x FROM QUEUE requests AS request AS BEGIN LET x = 1");
    for (0..64) |_| try source.writer.writeAll(" + 1");
    try source.writer.writeAll("; END;");
    var parsed = try ast.parse(t.allocator, source.written(), null);
    defer parsed.deinit();
    try t.expectError(error.ProgramTooDeep, bind(t.allocator, parsed.program, &test_resources, null));
}

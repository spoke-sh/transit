//! Bounded higher-order evaluation into ordinary, independently checked SQL.
const std = @import("std");
const f = @import("transit_fuze");
const p = @import("transit_protocol");
const memory = @import("transit_memory");
const s = @import("Syntax.zig");
const Graph = @import("Graph.zig");
const Catalog = @import("WorkingCatalog.zig");
pub const format = "transit_source_v1";
pub const Limits = struct { files: usize = 256, source_bytes: usize = 16 * 1024 * 1024, depth: usize = 64, work: usize = 100000, memory_bytes: usize = 64 * 1024 * 1024, output_bytes: usize = 8 * 1024 * 1024 };
pub const Options = struct { entry: []const u8 = "build.transit", target: []const u8 = "default", compiler_revision: []const u8, resolution_digest: [32]u8 = @splat(0), limits: Limits = .{} };
pub const Step = struct { sql: []const u8, plan_digest: [32]u8, definition: p.Diagnostic.Location, call: ?p.Diagnostic.Location, instance: []const u8, bindings_digest: [32]u8 };
pub const Product = struct {
    budget: memory.Budget,
    arena: std.heap.ArenaAllocator,
    sql: []const u8 = "",
    steps: []const Step = &.{},
    input_digest: [32]u8 = undefined,
    sql_digest: [32]u8 = undefined,
    work: usize = 0,
    pub fn deinit(self: *Product) void {
        const parent = self.budget.parent;
        self.arena.deinit();
        parent.destroy(self);
    }
};
const Value = union(enum) { integer: i64, text: []const u8, boolean: bool, identifier: []const u8, type: s.ScalarType, module: Graph.Ref };
const Binding = struct { name: []const u8, value: Value };
const Self = @This();
a: std.mem.Allocator,
graph: Graph,
catalog: Catalog,
scratch: *std.heap.ArenaAllocator,
limits: Limits,
steps: std.ArrayList(Step) = .empty,
work: usize = 0,
output_bytes: usize = 0,
file: usize = 0,
offset: usize = 0,
call_site: ?p.Diagnostic.Location = null,
instance: []const u8 = "target",

pub fn compile(parent: std.mem.Allocator, sources: []const Graph.Source, options: Options, diagnostic: *?p.Diagnostic) !*Product {
    diagnostic.* = null;
    const result = parent.create(Product) catch |err| {
        diagnostic.* = project(err, if (sources.len > 0) location(sources[0], 0) else null, null, null);
        return err;
    };
    result.* = .{ .budget = .{ .parent = parent, .limit = options.limits.memory_bytes }, .arena = undefined };
    result.arena = .init(result.budget.allocator());
    errdefer result.deinit();
    return compileInner(result, sources, options, diagnostic) catch |err| {
        const cause = if (err == error.OutOfMemory and result.budget.exhausted) error.BuildMemoryLimit else err;
        if (diagnostic.* == null) diagnostic.* = project(cause, if (sources.len > 0) location(sources[0], 0) else null, null, null);
        return cause;
    };
}
fn compileInner(result: *Product, sources: []const Graph.Source, options: Options, diagnostic: *?p.Diagnostic) !*Product {
    const defaults: Limits = .{};
    inline for (@typeInfo(Limits).@"struct".field_names) |field_name| if (@field(options.limits, field_name) == 0 or @field(options.limits, field_name) > @field(defaults, field_name)) return error.InvalidBuildBudget;
    if (options.compiler_revision.len == 0 or options.compiler_revision.len > 128) return error.InvalidCompilerIdentity;
    if (sources.len > options.limits.files) return error.SourceFileLimit;
    var source_bytes: usize = 0;
    for (sources) |source| {
        source_bytes = std.math.add(usize, source_bytes, source.text.len) catch return error.SourceBytesLimit;
        if (source_bytes > options.limits.source_bytes) return error.SourceBytesLimit;
    }
    const a = result.arena.allocator();
    var file: usize = 0;
    var offset: usize = 0;
    const graph = Graph.init(a, sources, &file, &offset, options.limits.depth) catch |err| {
        diagnostic.* = project(err, if (file < sources.len) location(sources[file], offset) else null, null, null);
        return err;
    };
    var scratch: std.heap.ArenaAllocator = .init(result.budget.allocator());
    defer scratch.deinit();
    var self: Self = .{ .a = a, .graph = graph, .catalog = .{ .output = a, .scratch = scratch.allocator() }, .scratch = &scratch, .limits = options.limits };
    return self.run(result, options) catch |err| {
        diagnostic.* = project(if (err == error.OutOfMemory and result.budget.exhausted) error.BuildMemoryLimit else err, location(sources[self.file], self.offset), self.call_site, self.instance);
        return err;
    };
}
fn run(self: *Self, result: *Product, options: Options) !*Product {
    const a = self.a;
    const graph = self.graph;
    const sources = graph.sources;
    const scratch = self.scratch;
    const entry = for (sources, 0..) |source, i| {
        if (std.mem.eql(u8, source.package, "root") and std.mem.eql(u8, source.path, options.entry)) break i;
    } else return error.MissingBuildEntry;
    self.file = entry;
    const target_name = try std.ascii.allocLowerString(a, options.target);
    const target = try graph.resolve(entry, .{ .member = target_name });
    const definition = graph.getDefinition(target);
    if (definition.kind != .target) return error.NotBuildTarget;
    try self.validateInterfaces();
    try self.body(target.file, definition.body, &.{}, 0);
    if (self.steps.items.len == 0) return error.EmptyBuildTarget;
    // A second working catalog prepares only the emitted SQL, with no source
    // symbols or evaluator. Compare ordered plans, not merely parser acceptance.
    var verified: Catalog = .{ .output = a, .scratch = scratch.allocator() };
    var sql: std.ArrayList(u8) = .empty;
    for (self.steps.items) |step| {
        _ = scratch.reset(.retain_capacity);
        var at: f.Sql.Location = .{};
        const actual = try verified.check(step.sql, &at);
        if (!std.mem.eql(u8, &actual, &step.plan_digest)) return error.BuildEmissionMismatch;
        try sql.appendSlice(a, step.sql);
        try sql.appendSlice(a, ";\n");
    }
    result.sql = try sql.toOwnedSlice(a);
    result.steps = try self.steps.toOwnedSlice(a);
    result.work = self.work;
    std.crypto.hash.sha2.Sha256.hash(result.sql, &result.sql_digest, .{});
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.build.v1\x00");
    Graph.hashPart(&hash, format);
    Graph.hashPart(&hash, @tagName(p.Growth.current_definition));
    Graph.hashPart(&hash, options.compiler_revision);
    hash.update(&options.resolution_digest);
    Graph.hashPart(&hash, options.entry);
    Graph.hashPart(&hash, target_name);
    inline for (@typeInfo(Limits).@"struct".field_names) |field_name| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, @field(options.limits, field_name), .little);
        hash.update(&bytes);
    }
    const ordered = try a.dupe(Graph.Source, sources);
    std.mem.sort(Graph.Source, ordered, {}, struct {
        fn less(_: void, l: Graph.Source, r: Graph.Source) bool {
            const order = std.mem.order(u8, l.package, r.package);
            return order == .lt or order == .eq and std.mem.lessThan(u8, l.path, r.path);
        }
    }.less);
    for (ordered) |source| {
        Graph.hashPart(&hash, source.package);
        Graph.hashPart(&hash, source.path);
        Graph.hashPart(&hash, source.text);
    }
    result.input_digest = hash.finalResult();
    return result;
}
fn tick(self: *Self) !void {
    if (self.work == self.limits.work) return error.BuildWorkLimit;
    self.work += 1;
}
fn validateInterfaces(self: *Self) !void {
    for (self.graph.files, 0..) |file, i| for (file.definitions) |definition| {
        self.file = i;
        self.offset = definition.span.start;
        for (definition.parameters) |parameter| if (parameter.kind == .module) {
            const interface = try self.graph.resolve(i, parameter.kind.module);
            if (self.graph.getDefinition(interface).kind != .interface) return error.InvalidModuleInterface;
        };
    };
}
fn resolve(self: *Self, file: usize, name: s.Name, bindings: []const Binding) !Graph.Ref {
    if (name.qualifier == null) for (bindings) |binding| if (std.mem.eql(u8, binding.name, name.member)) {
        if (binding.value != .module) return error.NotModuleConstructor;
        return binding.value.module;
    };
    const ref = try self.graph.resolve(file, name);
    if (self.graph.getDefinition(ref).kind != .module) return error.NotModuleConstructor;
    return ref;
}
fn signature(self: *Self, expected: Graph.Ref, actual: Graph.Ref, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    const want = self.graph.getDefinition(expected);
    const got = self.graph.getDefinition(actual);
    if (want.parameters.len != got.parameters.len) return error.ModuleInterfaceMismatch;
    for (want.parameters, got.parameters) |left, right| {
        if (std.meta.activeTag(left.kind) != std.meta.activeTag(right.kind)) return error.ModuleInterfaceMismatch;
        if (left.kind == .module) try self.signature(try self.graph.resolve(expected.file, left.kind.module), try self.graph.resolve(actual.file, right.kind.module), depth + 1);
    }
}
fn body(self: *Self, file: usize, statements: []const s.Statement, bindings: []const Binding, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    for (statements) |statement| {
        self.file = file;
        self.offset = statement.span.start;
        try self.tick();
        switch (statement.value) {
            .conditional => |condition| {
                const value = try self.expression(file, condition.condition, bindings, 0);
                if (value != .boolean) return error.SourceTypeMismatch;
                try self.body(file, if (value.boolean) condition.yes else condition.no, bindings, depth + 1);
            },
            .use => |call| {
                const ref = try self.resolve(file, call.name, bindings);
                const definition = self.graph.getDefinition(ref);
                if (call.arguments.len != definition.parameters.len) return error.SourceArgumentCount;
                var values: [64]Binding = undefined;
                for (call.arguments, definition.parameters, 0..) |argument, parameter, i| {
                    const value = try self.expression(file, argument, bindings, 0);
                    if (!std.mem.eql(u8, @tagName(parameter.kind), @tagName(value))) return error.SourceTypeMismatch;
                    if (value == .module) try self.signature(try self.graph.resolve(ref.file, parameter.kind.module), value.module, 0);
                    values[i] = .{ .name = parameter.name, .value = value };
                }
                const before_site = self.call_site;
                const before_instance = self.instance;
                self.call_site = location(self.graph.sources[file], statement.span.start);
                self.instance = definition.name;
                try self.body(ref.file, definition.body, values[0..call.arguments.len], depth + 1);
                self.call_site = before_site;
                self.instance = before_instance;
            },
            .sql => |tokens| try self.emit(file, statement.span, tokens, bindings),
        }
    }
}
fn expression(self: *Self, file: usize, expr: *const s.Expr, bindings: []const Binding, depth: usize) anyerror!Value {
    self.file = file;
    self.offset = expr.span.start;
    try self.tick();
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    return switch (expr.value) {
        .integer => |value| .{ .integer = value },
        .text => |value| .{ .text = value },
        .boolean => |value| .{ .boolean = value },
        .type => |value| .{ .type = value },
        .identifier => |value| blk: {
            if (value.len == 0 or value.len > 63 or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidInstanceName;
            break :blk .{ .identifier = value };
        },
        .reference => |name| blk: {
            if (name.qualifier == null) for (bindings) |binding| if (std.mem.eql(u8, binding.name, name.member)) break :blk binding.value;
            break :blk .{ .module = try self.resolve(file, name, bindings) };
        },
        .unary => |value| blk: {
            const operand = try self.expression(file, value.operand, bindings, depth + 1);
            if (value.negative) {
                if (operand != .integer) return error.SourceTypeMismatch;
                break :blk .{ .integer = try std.math.sub(i64, 0, operand.integer) };
            }
            if (operand != .boolean) return error.SourceTypeMismatch;
            break :blk .{ .boolean = !operand.boolean };
        },
        .binary => |value| blk: {
            const left = try self.expression(file, value.left, bindings, depth + 1);
            const right = try self.expression(file, value.right, bindings, depth + 1);
            if (std.meta.activeTag(left) != std.meta.activeTag(right)) return error.SourceTypeMismatch;
            if (value.op == .and_ or value.op == .or_) {
                if (left != .boolean) return error.SourceTypeMismatch;
                break :blk .{ .boolean = if (value.op == .and_) left.boolean and right.boolean else left.boolean or right.boolean };
            }
            switch (value.op) {
                .add, .subtract, .multiply => {
                    if (left != .integer) return error.SourceTypeMismatch;
                    break :blk .{ .integer = switch (value.op) {
                        .add => try std.math.add(i64, left.integer, right.integer),
                        .subtract => try std.math.sub(i64, left.integer, right.integer),
                        .multiply => try std.math.mul(i64, left.integer, right.integer),
                        else => unreachable,
                    } };
                },
                else => {},
            }
            const order: std.math.Order = switch (left) {
                .integer => std.math.order(left.integer, right.integer),
                .text => std.mem.order(u8, left.text, right.text),
                .boolean => std.math.order(@intFromBool(left.boolean), @intFromBool(right.boolean)),
                else => return error.SourceTypeMismatch,
            };
            break :blk .{ .boolean = switch (value.op) {
                .equal => order == .eq,
                .not_equal => order != .eq,
                .less => order == .lt,
                .less_equal => order != .gt,
                .greater => order == .gt,
                .greater_equal => order != .lt,
                else => unreachable,
            } };
        },
    };
}
fn emit(self: *Self, file: usize, span: s.Span, tokens: []const s.Token, bindings: []const Binding) !void {
    self.file = file;
    self.offset = span.start;
    var raw_buf: [f.Sql.max_statement_bytes]u8 = undefined;
    var canonical_buf: [f.Sql.max_statement_bytes]u8 = undefined;
    const raw = try expand(self.graph.sources[file].text, tokens, bindings, &raw_buf, false);
    const canonical = try expand(self.graph.sources[file].text, tokens, bindings, &canonical_buf, true);
    if (canonical.len + 2 > self.limits.output_bytes - self.output_bytes) return error.BuildOutputLimit;
    _ = self.scratch.reset(.retain_capacity);
    var at: f.Sql.Location = .{};
    const digest = try self.catalog.check(raw, &at);
    self.output_bytes += canonical.len + 2;
    var binding_hash = std.crypto.hash.sha2.Sha256.init(.{});
    binding_hash.update("transit.source.bindings.v1\x00");
    for (bindings) |binding| {
        Graph.hashPart(&binding_hash, binding.name);
        Graph.hashPart(&binding_hash, @tagName(binding.value));
        switch (binding.value) {
            .module => |ref| {
                Graph.hashPart(&binding_hash, self.graph.sources[ref.file].package);
                Graph.hashPart(&binding_hash, self.graph.sources[ref.file].path);
                Graph.hashPart(&binding_hash, self.graph.getDefinition(ref).name);
            },
            .text, .identifier => |value| Graph.hashPart(&binding_hash, value),
            .type => |value| Graph.hashPart(&binding_hash, @tagName(value)),
            .boolean => |value| binding_hash.update(&.{@intFromBool(value)}),
            .integer => |value| {
                var bytes: [8]u8 = undefined;
                std.mem.writeInt(i64, &bytes, value, .little);
                binding_hash.update(&bytes);
            },
        }
    }
    try self.steps.append(self.a, .{ .sql = try self.a.dupe(u8, canonical), .plan_digest = digest, .definition = location(self.graph.sources[file], span.start), .call = self.call_site, .instance = try self.a.dupe(u8, self.instance), .bindings_digest = binding_hash.finalResult() });
}
fn expand(text: []const u8, tokens: []const s.Token, bindings: []const Binding, output: []u8, canonical: bool) ![]const u8 {
    if (tokens.len == 0) return error.InvalidSourceSyntax;
    var writer: std.Io.Writer = .fixed(output);
    var i: usize = 0;
    if (tokenIs(text, tokens[0], "CREATE")) {
        if (tokens.len < 4 or !tokenIs(text, tokens[1], "PUBLIC") or !tokenIs(text, tokens[2], "TABLE")) return error.RuntimePrivateOrUnsupportedDeclaration;
    }
    while (i < tokens.len) : (i += 1) {
        if (i == 1 and tokenIs(text, tokens[0], "CREATE")) continue;
        const token = tokens[i];
        const raw = text[token.start..token.end];
        const joined = i > 0 and token.kind == .symbol and tokens[i - 1].kind == .symbol and tokens[i - 1].end == token.start and
            ((std.mem.indexOfAny(u8, text[tokens[i - 1].start..tokens[i - 1].end], "<>") != null and std.mem.indexOfAny(u8, raw, "=>") != null) or (std.mem.eql(u8, raw, "|") and std.mem.eql(u8, text[tokens[i - 1].start..tokens[i - 1].end], "|")));
        if (writer.end != 0 and !joined) writer.writeByte(' ') catch return error.BuildStatementLimit;
        if (token.kind == .symbol and std.mem.eql(u8, raw, "$")) {
            i += 1;
            if (i == tokens.len or tokens[i].kind != .word) return error.InvalidSourceOperand;
            const name = text[tokens[i].start..tokens[i].end];
            const value = for (bindings) |binding| {
                if (std.ascii.eqlIgnoreCase(name, binding.name)) break binding.value;
            } else return error.UnknownSourceOperand;
            writeValue(&writer, value) catch |err| return if (err == error.WriteFailed) error.BuildStatementLimit else err;
        } else if (canonical and token.kind == .word) {
            for (raw) |byte| writer.writeByte(std.ascii.toUpper(byte)) catch return error.BuildStatementLimit;
        } else writer.writeAll(raw) catch return error.BuildStatementLimit;
    }
    return writer.buffered();
}
fn tokenIs(text: []const u8, token: s.Token, word: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(text[token.start..token.end], word);
}
fn quoted(writer: *std.Io.Writer, text: []const u8, quote: u8) !void {
    try writer.writeByte(quote);
    for (text) |byte| {
        try writer.writeByte(byte);
        if (byte == quote) try writer.writeByte(quote);
    }
    try writer.writeByte(quote);
}
fn writeValue(writer: *std.Io.Writer, value: Value) !void {
    switch (value) {
        .integer => |number| try writer.print("{d}", .{number}),
        .boolean => |boolean| try writer.writeAll(if (boolean) "TRUE" else "FALSE"),
        .text => |text| try quoted(writer, text, '\''),
        .identifier => |name| try quoted(writer, name, '"'),
        .type => |kind| try writer.writeAll(switch (kind) {
            .bigint => "BIGINT",
            .text => "TEXT",
            .boolean => "BOOLEAN",
        }),
        .module => return error.ModuleIsNotSqlOperand,
    }
}
pub fn location(source: Graph.Source, offset: usize) p.Diagnostic.Location {
    const position = @min(offset, source.text.len);
    var line: u64 = 1;
    var start: usize = 0;
    for (source.text[0..position], 0..) |byte, i| if (byte == '\n') {
        line += 1;
        start = i + 1;
    };
    var path: [600]u8 = undefined;
    const name = std.fmt.bufPrint(&path, "{s}/{s}", .{ source.package, source.path }) catch source.path;
    var result: p.Diagnostic.Location = .{ .offset = .init(position), .length = .init(0), .line = .init(line), .byte_column = .init(position - start + 1) };
    const source_path = p.Diagnostic.SourcePath.init(name) catch unreachable;
    source_path.apply(&result);
    return result;
}
pub fn project(err: anyerror, at: ?p.Diagnostic.Location, call: ?p.Diagnostic.Location, instance: ?[]const u8) p.Diagnostic {
    const name = @errorName(err);
    const category: p.Diagnostic.Category = if (std.mem.indexOf(u8, name, "Limit") != null or err == error.OutOfMemory) .limit else if (std.mem.indexOf(u8, name, "Unsupported") != null) .unsupported else .binding;
    var result = p.Diagnostic.init("application.source_build", category, .compile, .not_submitted, .local_before_dispatch, "Application source build failed; no SQL was submitted.") catch unreachable;
    result.location = at;
    result.text(.native_cause, .owner, name) catch unreachable;
    if (call) |value| result.fact(.first_occurrence, .caller, .{ .location = value }) catch unreachable;
    if (instance) |value| result.text(.scope, .caller, value) catch unreachable;
    result.action(.correct_input) catch unreachable;
    return result;
}

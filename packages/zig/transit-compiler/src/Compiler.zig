//! Bounded higher-order evaluation into ordinary, independently checked SQL.
const std = @import("std");
const f = @import("transit_fuze");
const p = @import("transit_protocol");
const memory = @import("transit_memory");
const s = @import("Syntax.zig");
const Graph = @import("Graph.zig");
const Catalog = @import("WorkingCatalog.zig");
const Test = @import("Test.zig");
const types = @import("SourceTypes.zig");
const Operands = @import("TypedOperands.zig");
pub const format = "transit_source_v1";
pub const Limits = struct { files: usize = 256, source_bytes: usize = 16 * 1024 * 1024, depth: usize = 64, work: usize = 100000, memory_bytes: usize = 64 * 1024 * 1024, output_bytes: usize = 8 * 1024 * 1024 };
pub const Options = struct { entry: []const u8 = "build.transit", target: []const u8 = "default", mode: enum { build, test_suite } = .build, compiler_revision: []const u8, resolution_digest: [32]u8 = @splat(0), limits: Limits = .{} };
pub const Step = struct {
    sql: []const u8,
    plan_digest: [32]u8,
    definition: p.Diagnostic.Location,
    call: ?p.Diagnostic.Location,
    instance: []const u8,
    bindings_digest: [32]u8,
    checked: Operands.Checked,
    /// Keep checked-core evidence in memory; the current provenance format is
    /// deliberately independent of the compiler's internal typed representation.
    pub fn jsonStringify(self: Step, out: *std.json.Stringify) std.Io.Writer.Error!void {
        try p.Json.write(.{ .sql = self.sql, .plan_digest = self.plan_digest, .definition = self.definition, .call = self.call, .instance = self.instance, .bindings_digest = self.bindings_digest }, out);
    }
};
pub const Product = struct {
    budget: memory.Budget,
    arena: std.heap.ArenaAllocator,
    sql: []const u8 = "",
    steps: []const Step = &.{},
    cases: []const Test.Case = &.{},
    input_digest: [32]u8 = undefined,
    sql_digest: [32]u8 = undefined,
    work: usize = 0,
    pub fn deinit(self: *Product) void {
        const parent = self.budget.parent;
        self.arena.deinit();
        parent.destroy(self);
    }
};
const Value = types.Value;
const Binding = types.Binding;
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
test_mode: bool = false,
in_case: bool = false,
expansion: [32]u8 = @splat(0),
cases: std.ArrayList(Test.Case) = .empty,
actions: std.ArrayList(Test.Action) = .empty,
expected_rows: usize = 0,
expected_bytes: usize = 0,
owner: usize = 0,
next_owner: usize = 0,
exports: ?*std.ArrayList(types.Export) = null,
symbolic: bool = false,
checked_statements: usize = 0,
checking: [64]struct { definition: Graph.Ref, arguments: []const Binding } = undefined,
checking_count: usize = 0,

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
    const entry = for (sources, 0..) |source, i| {
        if (std.mem.eql(u8, source.package, "root") and std.mem.eql(u8, source.path, options.entry)) break i;
    } else return error.MissingBuildEntry;
    self.file = entry;
    const target_name = try std.ascii.allocLowerString(a, options.target);
    const target = try graph.resolve(entry, .{ .member = target_name });
    const definition = graph.getDefinition(target);
    self.test_mode = options.mode == .test_suite;
    const target_kind: @FieldType(s.Definition, "kind") = if (self.test_mode) .test_target else .target;
    if (definition.kind != target_kind) return error.WrongSourceTargetKind;
    std.crypto.hash.sha2.Sha256.hash(target_name, &self.expansion, .{});
    try types.validate(graph, self.a, &self.file, &self.offset, &self.work, self.limits.work);
    try self.validateInterfaces();
    try self.body(target.file, definition.body, &.{}, 0);
    if (self.test_mode) {
        if (self.cases.items.len == 0) return error.EmptyTestTarget;
        result.cases = try self.cases.toOwnedSlice(a);
        var combined = std.crypto.hash.sha2.Sha256.init(.{});
        combined.update("transit.source.tests.sql.v1\x00");
        for (result.cases) |case| combined.update(&case.sql_digest);
        result.sql_digest = combined.finalResult();
    } else {
        if (self.steps.items.len == 0) return error.EmptyBuildTarget;
        result.sql = try self.verify();
        result.steps = try self.steps.toOwnedSlice(a);
        std.crypto.hash.sha2.Sha256.hash(result.sql, &result.sql_digest, .{});
    }
    result.work = self.work;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.build.v1\x00");
    Graph.hashPart(&hash, format);
    Graph.hashPart(&hash, @tagName(p.Growth.current_definition));
    Graph.hashPart(&hash, options.compiler_revision);
    hash.update(&options.resolution_digest);
    Graph.hashPart(&hash, options.entry);
    Graph.hashPart(&hash, target_name);
    if (self.test_mode) Graph.hashPart(&hash, "test_suite");
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
fn verify(self: *Self) ![]const u8 {
    // Independent ordinary preparation receives SQL, never source or controls.
    var verified: Catalog = .{ .output = self.a, .scratch = self.scratch.allocator() };
    var sql: std.ArrayList(u8) = .empty;
    for (self.steps.items) |step| {
        _ = self.scratch.reset(.retain_capacity);
        var at: f.Sql.Location = .{};
        const actual = try verified.check(step.sql, &at);
        if (!std.mem.eql(u8, &actual, &step.plan_digest)) return error.BuildEmissionMismatch;
        try sql.appendSlice(self.a, step.sql);
        try sql.appendSlice(self.a, ";\n");
    }
    return sql.toOwnedSlice(self.a);
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
    try self.tick();
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    const want = self.graph.getDefinition(expected);
    const got = self.graph.getDefinition(actual);
    if (want.parameters.len != got.parameters.len) return error.ModuleInterfaceMismatch;
    for (want.parameters, got.parameters) |left, right| {
        if (std.meta.activeTag(left.kind) != std.meta.activeTag(right.kind)) return error.ModuleInterfaceMismatch;
        if (left.kind == .module) try self.signature(try self.graph.resolve(expected.file, left.kind.module), try self.graph.resolve(actual.file, right.kind.module), depth + 1);
        if (left.kind == .named and !std.meta.eql(try self.graph.resolve(expected.file, left.kind.named), try self.graph.resolve(actual.file, right.kind.named))) return error.ModuleInterfaceMismatch;
        switch (left.kind) {
            inline .table, .stream, .queue => |columns, tag| {
                const other = @field(right.kind, @tagName(tag));
                if (columns.len != other.len) return error.ModuleInterfaceMismatch;
                for (columns, other) |l, r| {
                    if (!std.mem.eql(u8, l.name, r.name) or l.nullable != r.nullable or l.primary != r.primary or !std.mem.eql(u8, l.collation, r.collation) or
                        !types.Scalar.eql(try types.resolve(self.graph, expected.file, l.type), try types.resolve(self.graph, actual.file, r.type))) return error.ModuleInterfaceMismatch;
                }
            },
            else => {},
        }
    }
}
fn argument(self: *Self, file: usize, kind: s.Kind, value: Value) !void {
    switch (kind) {
        .named => |name| {
            const ref = try self.graph.resolve(file, name);
            const definition = self.graph.getDefinition(ref);
            if (definition.kind == .domain) {
                if (!types.Scalar.eql(try types.domain(self.graph, ref), value.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
            } else if (definition.kind == .variant) {
                if (value != .variant or !std.meta.eql(value.variant.definition, ref)) return error.SourceTypeMismatch;
            } else return error.InvalidParameterType;
        },
        inline .table, .stream, .queue => |columns, tag| {
            if (std.meta.activeTag(value) != @field(std.meta.Tag(Value), @tagName(tag))) return error.SourceTypeMismatch;
            try types.signature(self.graph, file, columns, @field(value, @tagName(tag)));
        },
        .integer, .text, .boolean => {
            if (!types.Scalar.eql(try types.field(self.graph, file, kind), value.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
        },
        .module => |name| {
            if (value != .module) return error.SourceTypeMismatch;
            try self.signature(try self.graph.resolve(file, name), value.module, 0);
        },
        else => if (!std.mem.eql(u8, @tagName(kind), @tagName(value))) return error.SourceTypeMismatch,
    }
}
fn freshBinding(self: *Self, file: usize, name: []const u8, bindings: []const Binding) !void {
    for (bindings) |binding| if (std.mem.eql(u8, name, binding.name)) return error.DuplicateSourceName;
    for (self.graph.files[file].imports) |import| if (std.mem.eql(u8, name, import.alias)) return error.DuplicateSourceName;
    for (self.graph.files[file].definitions) |definition| if (std.mem.eql(u8, name, definition.name)) return error.DuplicateSourceName;
}
fn invoke(self: *Self, file: usize, span: s.Span, call: s.Call, bindings: []const Binding, depth: usize) anyerror!Value {
    const ref = try self.resolve(file, call.name, bindings);
    const definition = self.graph.getDefinition(ref);
    if (call.arguments.len != definition.parameters.len) return error.SourceArgumentCount;
    var values: [64]Binding = undefined;
    for (call.arguments, definition.parameters, 0..) |arg, parameter, i| {
        const value = try self.expression(file, arg, bindings, 0);
        try self.argument(ref.file, parameter.kind, value);
        // Reached symbolic callees are checked for their declared scalar types.
        // This also checks both paths of recursive IF bodies before a recursive
        // edge is discharged by its signature, without guessing payload values.
        values[i] = .{ .name = parameter.name, .value = if (self.symbolic and value.scalar() != null) .{ .symbolic = value.scalar().? } else value };
    }
    // A recursive symbolic call checks its signature. The active body is already
    // being checked without inventing payload values or traversing forever.
    if (self.symbolic) for (self.checking[0..self.checking_count]) |prior| if (std.meta.eql(prior.definition, ref) and types.sameSpecialization(prior.arguments, values[0..call.arguments.len])) {
        if (call.result != null) return error.UnsupportedRecursiveExports;
        return .{ .instance = &.{} };
    };
    if (self.checking_count == self.checking.len) return error.SourceDepthLimit;
    self.checking[self.checking_count] = .{ .definition = ref, .arguments = values[0..call.arguments.len] };
    self.checking_count += 1;
    defer self.checking_count -= 1;
    const before_site = self.call_site;
    const before_instance = self.instance;
    const before_expansion = self.expansion;
    const before_owner = self.owner;
    const before_exports = self.exports;
    var completed = false;
    defer {
        if (completed) {
            self.call_site = before_site;
            self.instance = before_instance;
        }
        self.expansion = before_expansion;
        self.owner = before_owner;
        self.exports = before_exports;
    }
    var expansion = std.crypto.hash.sha2.Sha256.init(.{});
    expansion.update(&before_expansion);
    Graph.hashPart(&expansion, self.graph.sources[file].package);
    Graph.hashPart(&expansion, self.graph.sources[file].path);
    var at: [8]u8 = undefined;
    std.mem.writeInt(u64, &at, span.start, .little);
    expansion.update(&at);
    self.expansion = expansion.finalResult();
    self.call_site = location(self.graph.sources[file], span.start);
    self.instance = definition.name;
    self.next_owner += 1;
    self.owner = self.next_owner;
    var exports: std.ArrayList(types.Export) = .empty;
    self.exports = &exports;
    try self.body(ref.file, definition.body, values[0..call.arguments.len], depth + 1);
    const result = try exports.toOwnedSlice(self.a);
    completed = true;
    return .{ .instance = result };
}
fn fork(self: *Self) !Self {
    var result = self.*;
    result.symbolic = true;
    if (!self.symbolic) result.checking_count = 0;
    result.catalog.entries = try self.catalog.entries.clone(self.a);
    result.catalog.programs = try self.catalog.programs.clone(self.a);
    result.steps = .empty;
    result.actions = .empty;
    result.cases = .empty;
    // Exports made only by a checking branch never escape into its caller.
    if (self.exports) |exports| {
        result.exports = try self.a.create(std.ArrayList(types.Export));
        result.exports.?.* = try exports.clone(self.a);
    }
    return result;
}
fn checkBody(self: *Self, file: usize, statements: []const s.Statement, bindings: []const Binding, depth: usize, stable_catalog: bool) !void {
    var checker = try self.fork();
    defer {
        self.work = checker.work;
        self.next_owner = checker.next_owner;
    }
    checker.body(file, statements, bindings, depth) catch |err| {
        self.file = checker.file;
        self.offset = checker.offset;
        self.call_site = checker.call_site;
        self.instance = checker.instance;
        return err;
    };
    if (stable_catalog and (checker.catalog.entries.items.len != self.catalog.entries.items.len or
        (if (checker.exports) |v| v.items.len else 0) != (if (self.exports) |v| v.items.len else 0))) return error.UnsupportedSymbolicSchema;
}
fn match(self: *Self, file: usize, input: @FieldType(@FieldType(s.Statement, "value"), "match"), bindings: []const Binding, depth: usize) !void {
    const value = try self.expression(file, input.value, bindings, 0);
    if (value != .variant) return error.SourceTypeMismatch;
    const variant = value.variant;
    const definition = self.graph.getDefinition(variant.definition);
    if (input.arms.len != definition.constructors.len) return error.NonExhaustiveSourceMatch;
    var seen: [64]bool = @splat(false);
    var selected: usize = 0;
    for (input.arms, 0..) |arm, i| {
        self.offset = arm.span.start;
        const resolved = try types.constructor(self.graph, file, arm.constructor);
        if (!std.meta.eql(resolved.definition, variant.definition)) return error.SourceTypeMismatch;
        if (seen[resolved.index]) return error.DuplicateSourceMatchArm;
        seen[resolved.index] = true;
        if (resolved.index == variant.constructor) selected = i;
        const fields = definition.constructors[resolved.index].fields;
        if (arm.names.len != fields.len) return error.SourceArgumentCount;
        const arm_bindings = try self.a.alloc(Binding, bindings.len + fields.len);
        @memcpy(arm_bindings[0..bindings.len], bindings);
        for (arm.names, fields, 0..) |name, field, n| {
            try self.freshBinding(file, name, bindings);
            arm_bindings[bindings.len + n] = .{ .name = name, .value = .{ .symbolic = try types.field(self.graph, variant.definition.file, field.kind) } };
        }
        try self.checkBody(file, arm.body, arm_bindings, depth + 1, false);
    }
    const arm = input.arms[selected];
    const selected_bindings = try self.a.alloc(Binding, bindings.len + variant.fields.len);
    @memcpy(selected_bindings[0..bindings.len], bindings);
    for (arm.names, variant.fields, 0..) |name, item, i| selected_bindings[bindings.len + i] = .{ .name = name, .value = item };
    try self.body(file, arm.body, selected_bindings, depth + 1);
}
fn body(self: *Self, file: usize, statements: []const s.Statement, incoming: []const Binding, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    var scope: std.ArrayList(Binding) = .empty;
    try scope.appendSlice(self.a, incoming);
    for (statements) |statement| {
        self.file = file;
        self.offset = statement.span.start;
        try self.tick();
        const bindings = scope.items;
        switch (statement.value) {
            .conditional => |condition| {
                const value = try self.expression(file, condition.condition, bindings, 0);
                if (value == .symbolic and value.symbolic.base == .boolean and value.symbolic.domain == null) {
                    try self.checkBody(file, condition.yes, bindings, depth + 1, true);
                    try self.checkBody(file, condition.no, bindings, depth + 1, true);
                } else {
                    if (value != .boolean) return error.SourceTypeMismatch;
                    try self.body(file, if (value.boolean) condition.yes else condition.no, bindings, depth + 1);
                }
            },
            .use => |call| {
                if (call.result) |name| try self.freshBinding(file, name, bindings);
                const result = try self.invoke(file, statement.span, call, bindings, depth);
                if (call.result) |name| try scope.append(self.a, .{ .name = name, .value = result });
            },
            .table_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                const value = try self.reference(file, exported.source, bindings);
                const table = if (exported.operand) blk: {
                    if (value != .identifier) return error.SourceTypeMismatch;
                    const entry = try self.catalog.find(value.identifier);
                    if (entry.owner != self.owner) return error.ForeignTableExport;
                    break :blk entry;
                } else if (value == .table) value.table else return error.SourceTypeMismatch;
                try exports.append(self.a, .{ .name = exported.alias, .value = .{ .table = table } });
            },
            .log_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                const value = try self.reference(file, exported.source, bindings);
                const entry = if (exported.operand) blk: {
                    if (value != .identifier) return error.SourceTypeMismatch;
                    const resource = try self.catalog.findResource(value.identifier);
                    if (resource.owner != self.owner) return error.ForeignTableExport;
                    break :blk resource;
                } else switch (value) {
                    .stream, .queue => |resource| resource,
                    else => return error.SourceTypeMismatch,
                };
                if (!std.mem.eql(u8, @tagName(entry.kind), @tagName(exported.kind))) return error.SourceTypeMismatch;
                try exports.append(self.a, .{ .name = exported.alias, .value = entry.value() });
            },
            .match => |input| try self.match(file, input, bindings, depth),
            .sql => |template| {
                if (self.test_mode and !self.in_case) return error.TestStatementOutsideCase;
                try self.emit(file, statement.span, template, bindings);
            },
            .test_case => |case| try self.testCase(file, statement.span, case, bindings, depth),
            .assertion => |check| try self.assertion(file, statement.span, check, bindings),
            .workflow => |check| try self.workflow(file, statement.span, check, bindings),
        }
    }
}
fn reference(self: *Self, file: usize, name: s.Name, bindings: []const Binding) !Value {
    for (bindings) |binding| {
        if (name.qualifier == null and std.mem.eql(u8, binding.name, name.member)) return binding.value;
        if (name.qualifier) |qualifier| if (std.mem.eql(u8, binding.name, qualifier)) {
            if (name.constructor != null or binding.value != .instance) return error.SourceTypeMismatch;
            for (binding.value.instance) |exported| if (std.mem.eql(u8, name.member, exported.name)) return exported.value;
            return error.UnknownSourceExport;
        };
    }
    return .{ .module = try self.resolve(file, name, bindings) };
}
fn construct(self: *Self, file: usize, call: s.Call, bindings: []const Binding, depth: usize) !Value {
    // An imported domain has two components; a local variant constructor also
    // has two. Resolve the import namespace before interpreting the latter.
    var is_domain = call.name.qualifier == null;
    if (call.name.qualifier) |qualifier| for (self.graph.files[file].imports) |import| if (std.mem.eql(u8, import.alias, qualifier)) {
        is_domain = call.name.constructor == null;
        break;
    };
    if (is_domain) {
        const kind = try types.domain(self.graph, try self.graph.resolve(file, call.name));
        if (call.arguments.len != 1) return error.SourceArgumentCount;
        const value = try self.expression(file, call.arguments[0], bindings, depth + 1);
        if (!types.Scalar.eql(.{ .base = kind.base }, value.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
        if (value == .symbolic) return .{ .symbolic = kind };
        return .{ .nominal = .{ .type = kind, .value = try value.primitive() } };
    }
    const resolved = try types.constructor(self.graph, file, call.name);
    const fields = self.graph.getDefinition(resolved.definition).constructors[resolved.index].fields;
    if (fields.len != call.arguments.len) return error.SourceArgumentCount;
    const values = try self.a.alloc(Value, fields.len);
    for (fields, call.arguments, values) |field, arg, *value| {
        value.* = try self.expression(file, arg, bindings, depth + 1);
        try self.argument(resolved.definition.file, field.kind, value.*);
    }
    return .{ .variant = .{ .definition = resolved.definition, .constructor = resolved.index, .fields = values } };
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
        .type => |value| .{ .type = .{ .base = value } },
        .named_type => |name| .{ .type = try types.resolve(self.graph, file, .{ .named = name }) },
        .construct => |call| try self.construct(file, call, bindings, depth),
        .identifier => |value| blk: {
            if (value.len == 0 or value.len > 63 or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidInstanceName;
            break :blk .{ .identifier = value };
        },
        .reference => |name| try self.reference(file, name, bindings),
        .unary => |value| blk: {
            const operand = try self.expression(file, value.operand, bindings, depth + 1);
            if (operand == .symbolic) {
                if (operand.symbolic.domain != null or operand.symbolic.base != (if (value.negative) s.ScalarType.bigint else .boolean)) return error.SourceTypeMismatch;
                break :blk operand;
            }
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
            const left_type = left.scalar() orelse return error.SourceTypeMismatch;
            if (!types.Scalar.eql(left_type, right.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
            if (left_type.domain != null) {
                if (value.op != .equal and value.op != .not_equal) return error.SourceTypeMismatch;
                if (left == .symbolic or right == .symbolic) break :blk .{ .symbolic = .{ .base = .boolean } };
                const l = try left.primitive();
                const r = try right.primitive();
                const equal = switch (l) {
                    .integer => |v| v == r.integer,
                    .boolean => |v| v == r.boolean,
                    .text => |v| std.mem.eql(u8, v, r.text),
                };
                break :blk .{ .boolean = if (value.op == .equal) equal else !equal };
            }
            if (left == .symbolic or right == .symbolic) {
                const arithmetic = value.op == .add or value.op == .subtract or value.op == .multiply;
                const boolean = value.op == .and_ or value.op == .or_;
                if (arithmetic and left_type.base != .bigint or boolean and left_type.base != .boolean) return error.SourceTypeMismatch;
                break :blk .{ .symbolic = .{ .base = if (arithmetic) .bigint else .boolean } };
            }
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
fn emit(self: *Self, file: usize, span: s.Span, template: s.Template.Syntax, bindings: []const Binding) !void {
    const tokens = template.tokens;
    if (self.symbolic and (template.kind == .program or template.kind == .control)) return error.UnsupportedSymbolicProgram;
    if (self.in_case and self.actions.items.len == Test.max_actions) return error.TestActionLimit;
    self.file = file;
    self.offset = span.start;
    var raw_buf: [f.Sql.max_statement_bytes]u8 = undefined;
    var canonical_buf: [f.Sql.max_statement_bytes]u8 = undefined;
    var type_sites: [f.Sql.max_statement_bytes]bool = @splat(false);
    var sites: std.ArrayList(Operands.Site) = .empty;
    const raw = try expand(self.graph.sources[file].text, tokens, bindings, &raw_buf, false, &type_sites, self.a, &sites);
    _ = self.scratch.reset(.retain_capacity);
    var at: f.Sql.Location = .{};
    self.catalog.owner = self.owner;
    const is_create = tokenIs(self.graph.sources[file].text, tokens[0], "CREATE");
    // DDL creates the proposed shape; other statements check source annotations
    // before the ordinary binder can erase nominal identity into scalar values.
    var digest: [32]u8 = undefined;
    if (is_create) digest = try self.catalog.check(raw, &at);
    const log_statement = switch (template.kind) {
        .create_stream, .create_queue, .produce, .enqueue, .consume, .program, .control => true,
        else => false,
    };
    const checked = if (log_statement) try @import("ResourceOperands.zig").check(template, bindings) else try Operands.check(self.scratch.allocator(), self.a, self.graph, &self.catalog, raw, sites.items, self.symbolic);
    if (log_statement and self.symbolic and !is_create) _ = try self.catalog.check(raw, &at);
    if (!log_statement) try Catalog.verifyTypeOperands(self.scratch.allocator(), raw, type_sites[0..raw.len], &at);
    self.checked_statements += 1;
    if (self.symbolic) return;
    const canonical = try expand(self.graph.sources[file].text, tokens, bindings, &canonical_buf, true, null, self.a, null);
    if (!is_create) digest = try self.catalog.check(canonical, &at);
    if (canonical.len + 2 > self.limits.output_bytes - self.output_bytes) return error.BuildOutputLimit;
    self.output_bytes += canonical.len + 2;
    var binding_hash = std.crypto.hash.sha2.Sha256.init(.{});
    binding_hash.update("transit.source.bindings.v1\x00");
    for (bindings) |binding| {
        Graph.hashPart(&binding_hash, binding.name);
        try types.hashValue(binding.value, self.graph, &binding_hash, 0);
    }
    try self.steps.append(self.a, .{ .sql = try self.a.dupe(u8, canonical), .plan_digest = digest, .definition = location(self.graph.sources[file], span.start), .call = self.call_site, .instance = try self.a.dupe(u8, self.instance), .bindings_digest = binding_hash.finalResult(), .checked = checked });
    if (self.in_case) try self.actions.append(self.a, .{ .step = self.steps.items.len - 1, .expectation = .complete, .location = location(self.graph.sources[file], span.start) });
}
fn testCase(self: *Self, file: usize, span: s.Span, case: s.Case, bindings: []const Binding, depth: usize) !void {
    if (!self.test_mode) return error.TestInBuildTarget;
    if (self.in_case) return error.NestedTestCase;
    if (self.cases.items.len == Test.max_cases) return error.TestCaseLimit;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(&self.expansion);
    Graph.hashPart(&hash, self.graph.sources[file].package);
    Graph.hashPart(&hash, self.graph.sources[file].path);
    Graph.hashPart(&hash, case.name);
    const identity = hash.finalResult();
    for (self.cases.items) |prior| if (std.mem.eql(u8, &prior.identity, &identity)) return error.DuplicateTestCase;
    self.in_case = true;
    defer self.in_case = false;
    self.catalog = .{ .output = self.a, .scratch = self.scratch.allocator() };
    self.steps = .empty;
    self.actions = .empty;
    self.checked_statements = 0;
    self.expected_rows = 0;
    self.expected_bytes = 0;
    for (case.setup) |call| try self.body(file, &.{.{ .span = span, .value = .{ .use = call } }}, bindings, depth + 1);
    try self.body(file, case.body, bindings, depth + 1);
    if (self.checked_statements == 0) return error.EmptyTestCase;
    if (self.symbolic) return;
    const sql = try self.verify();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql, &digest, .{});
    try self.cases.append(self.a, .{ .name = try self.a.dupe(u8, case.name), .identity = identity, .location = location(self.graph.sources[file], span.start), .sql = sql, .sql_digest = digest, .steps = try self.steps.toOwnedSlice(self.a), .actions = try self.actions.toOwnedSlice(self.a) });
}
fn assertion(self: *Self, file: usize, span: s.Span, value: s.Assertion, bindings: []const Binding) !void {
    if (!self.in_case) return error.TestAssertionOutsideCase;
    try self.emit(file, span, value.sql, bindings);
    var query_buffer: [f.Sql.max_statement_bytes]u8 = undefined;
    const sql = if (self.symbolic) try expand(self.graph.sources[file].text, value.sql.tokens, bindings, &query_buffer, false, null, self.a, null) else self.steps.items[self.steps.items.len - 1].sql;
    const is_select = value.sql.kind == .select or value.sql.kind == .consume;
    const expected: Test.Expectation = switch (value.expected) {
        .rows => |template| blk: {
            const tokens = template.tokens;
            if (!is_select) return error.TestRowsRequired;
            const schema = try self.catalog.querySchema(sql);
            var buffer: [f.Sql.max_statement_bytes]u8 = undefined;
            const text = if (tokens.len == 0) "" else try expand(self.graph.sources[file].text, tokens, bindings, &buffer, false, null, self.a, null);
            const rows = try Test.bindRows(self.a, self.scratch.allocator(), text, schema);
            if (rows.values.len > Test.max_rows - self.expected_rows) return error.TestRowsLimit;
            self.expected_rows += rows.values.len;
            for (rows.values) |bytes| {
                if (bytes.len > Test.max_result_bytes - self.expected_bytes) return error.TestResultBytesLimit;
                self.expected_bytes += bytes.len;
            }
            break :blk .{ .rows = rows };
        },
        .command => |counts| blk: {
            if (is_select or value.sql.kind == .control) return error.TestCommandRequired;
            break :blk .{ .command = .{ .matched = counts.matched, .changed = counts.changed } };
        },
        .refusal => |reason| blk: {
            if (value.sql.kind != .insert and value.sql.kind != .update and value.sql.kind != .delete) return error.TestMutationRequired;
            break :blk .{ .refusal = if (reason == .duplicate_key) .duplicate_key else .check_violation };
        },
    };
    if (!self.symbolic) self.actions.items[self.actions.items.len - 1].expectation = expected;
}
fn workflow(self: *Self, file: usize, span: s.Span, value: s.Workflow, bindings: []const Binding) !void {
    if (!self.in_case) return error.TestAssertionOutsideCase;
    if (self.symbolic) return error.UnsupportedSymbolicProgram;
    if (self.actions.items.len == Test.max_actions) return error.TestActionLimit;
    if (value.observations == 0 or value.observations > Test.max_observations) return error.TestObservationLimit;
    const name = try self.expression(file, value.name, bindings, 0);
    if (name != .identifier) return error.SourceTypeMismatch;
    const program = for (self.catalog.programs.items) |program| {
        if (std.mem.eql(u8, program.name, name.identifier)) break program;
    } else return error.UnknownBuildProgram;
    if (program.control.state != .active and program.control.state != .suspended and program.control.state != .retired) return error.InvalidDataflowTransition;
    try self.actions.append(self.a, .{ .expectation = .{ .workflow = .{ .name = name.identifier, .completed = value.completed, .refused = value.refused, .observations = value.observations } }, .location = location(self.graph.sources[file], span.start) });
}
fn expand(text: []const u8, tokens: []const s.Token, bindings: []const Binding, output: []u8, canonical: bool, type_sites: ?[]bool, allocator: std.mem.Allocator, sites: ?*std.ArrayList(Operands.Site)) ![]const u8 {
    if (tokens.len == 0) return error.InvalidSourceSyntax;
    var writer: std.Io.Writer = .fixed(output);
    var i: usize = 0;
    var parameter: usize = 0;
    if (tokenIs(text, tokens[0], "CREATE")) {
        if (tokens.len < 4 or !tokenIs(text, tokens[1], "PUBLIC")) return error.RuntimePrivateOrUnsupportedDeclaration;
    }
    while (i < tokens.len) : (i += 1) {
        if (i == 1 and tokenIs(text, tokens[0], "CREATE")) continue;
        const token = tokens[i];
        const raw = text[token.start..token.end];
        const joined = s.Template.joinsLexeme(text, tokens, i);
        if (writer.end != 0 and !joined) writer.writeByte(' ') catch return error.BuildStatementLimit;
        if (token.kind == .symbol and std.mem.eql(u8, raw, "$")) {
            i += 1;
            if (i == tokens.len or tokens[i].kind != .word) return error.InvalidSourceOperand;
            const name = text[tokens[i].start..tokens[i].end];
            const value = for (bindings) |binding| {
                if (std.ascii.eqlIgnoreCase(name, binding.name)) break binding.value;
            } else return error.UnknownSourceOperand;
            if (value == .type) if (type_sites) |type_positions| {
                if (writer.end >= type_positions.len) return error.BuildStatementLimit;
                type_positions[writer.end] = true;
            };
            const start = writer.end;
            if (value == .symbolic or (!canonical and value == .nominal)) {
                parameter += 1;
                writer.print("${d}", .{parameter}) catch return error.BuildStatementLimit;
            } else writeValue(&writer, value) catch |err| return if (err == error.WriteFailed) error.BuildStatementLimit else err;
            if (sites) |record| try record.append(allocator, .{ .start = start, .end = writer.end, .value = value });
        } else if (canonical and token.kind == .word and !s.Template.numericWord(text, token)) {
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
        .type => |kind| try writer.writeAll(switch (kind.base) {
            .bigint => "BIGINT",
            .text => "TEXT",
            .boolean => "BOOLEAN",
        }),
        .nominal => |v| switch (v.value) {
            inline else => |payload, tag| try writeValue(writer, @unionInit(Value, @tagName(tag), payload)),
        },
        .table, .stream, .queue => |table| try quoted(writer, table.name, '"'),
        .symbolic => return error.UnsupportedSymbolicSchema,
        .variant, .instance => return error.InvalidSourceOperand,
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

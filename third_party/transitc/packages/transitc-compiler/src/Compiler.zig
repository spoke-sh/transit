//! Bounded higher-order evaluation into ordinary, independently checked SQL.
const std = @import("std");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
const memory = @import("transit_memory");
const s = @import("Syntax.zig");
const Graph = @import("Graph.zig");
const Catalog = @import("WorkingCatalog.zig");
const Test = @import("Test.zig");
const types = @import("SourceTypes.zig");
const Operands = @import("TypedOperands.zig");
const SourceDiagnostic = @import("SourceDiagnostic.zig");
const Context = SourceDiagnostic.Context;
const Origin = Operands.Origin;
pub const format = "transit_source_v1";
pub const Limits = struct { files: usize = 256, source_bytes: usize = 16 * 1024 * 1024, depth: usize = 64, work: usize = 100000, memory_bytes: usize = 64 * 1024 * 1024, output_bytes: usize = 8 * 1024 * 1024 };
pub const Options = struct { entry: []const u8 = "build.transit", target: []const u8 = "default", target_explicit: bool = true, mode: enum { build, test_suite } = .build, compiler_revision: []const u8, resolution_digest: [32]u8 = @splat(0), limits: Limits = .{}, report: ?*SourceDiagnostic.Report = null };
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
    selected_target: []const u8 = "",
    sql: []const u8 = "",
    steps: []const Step = &.{},
    cases: []const Test.Case = &.{},
    migration: ?s.Migration = null,
    migration_basis_path: ?[]const u8 = null,
    declared_output_path: ?[]const u8 = null,
    input_digest: [32]u8 = undefined,
    sql_digest: [32]u8 = undefined,
    work: usize = 0,
    pub fn deinit(self: *Product) void {
        const parent = self.budget.parent;
        self.arena.deinit();
        parent.destroy(self);
    }
};
/// Arena backing wrapper that disables address-dependent in-place resizes so
/// arena slab growth is strictly deterministic across allocator layouts.
fn arenaBacking(budget: *memory.Budget) std.mem.Allocator {
    return .{
        .ptr = budget,
        .vtable = &.{
            .alloc = struct {
                fn call(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
                    const b: *memory.Budget = @ptrCast(@alignCast(ctx));
                    return b.allocator().rawAlloc(len, alignment, ra);
                }
            }.call,
            .resize = std.mem.Allocator.noResize,
            .remap = std.mem.Allocator.noRemap,
            .free = struct {
                fn call(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
                    const b: *memory.Budget = @ptrCast(@alignCast(ctx));
                    b.allocator().rawFree(bytes, alignment, ra);
                }
            }.call,
        },
    };
}
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
span_end: usize = 0,
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
bound_schemas: ?*std.ArrayList(types.SchemaBinding) = null,
target_composition: ?struct { file: usize, instance: []const u8 } = null,
declaring: [64]usize = undefined,
declaring_len: usize = 0,
symbolic: bool = false,
checked_statements: usize = 0,
checking: [64]struct { definition: Graph.Ref, arguments: []const Binding } = undefined,
checking_count: usize = 0,
context: Context = .{},
report: ?*SourceDiagnostic.Report = null,
frames: [64]SourceDiagnostic.CallFrame = undefined,
frames_len: u8 = 0,

pub fn compile(parent: std.mem.Allocator, sources: []const Graph.Source, options: Options, diagnostic: *?p.Diagnostic) !*Product {
    diagnostic.* = null;
    if (options.report) |r| r.reset();
    const result = parent.create(Product) catch |err| {
        if (options.report) |r| r.finalize(err, .{});
        diagnostic.* = project(err, if (sources.len > 0) location(sources[0], 0) else null, null, null);
        return err;
    };
    result.* = .{ .budget = .{ .parent = parent, .limit = options.limits.memory_bytes }, .arena = undefined };
    result.arena = .init(arenaBacking(&result.budget));
    errdefer result.deinit();
    return compileInner(result, sources, options, diagnostic) catch |err| {
        const cause = if (err == error.OutOfMemory and result.budget.exhausted) error.BuildMemoryLimit else err;
        if (options.report) |r| r.finalize(cause, .{});
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
    const graph = Graph.initReported(a, sources, &file, &offset, options.limits.depth, options.report) catch |err| {
        var span: SourceDiagnostic.Span = .{ .start = @intCast(@min(offset, std.math.maxInt(u32))), .end = @intCast(@min(offset, std.math.maxInt(u32))) };
        if (options.report) |r| {
            if (r.has_span) {
                if (r.file) |rf| file = rf else if (file < sources.len) r.file = file;
                span = r.span;
            } else if (file < sources.len) r.setSpan(file, offset, offset);
            r.finalize(err, .{});
        }
        diagnostic.* = project(err, if (file < sources.len) locationSpan(sources[file], span) else null, null, null);
        return err;
    };
    var scratch: std.heap.ArenaAllocator = .init(arenaBacking(&result.budget));
    defer scratch.deinit();
    var self: Self = .{ .a = a, .graph = graph, .catalog = .{ .output = a, .scratch = scratch.allocator() }, .scratch = &scratch, .limits = options.limits, .report = options.report };
    return self.run(result, options) catch |err| {
        const cause = if (err == error.OutOfMemory and result.budget.exhausted) error.BuildMemoryLimit else err;
        const limit_context: Context = switch (err) {
            error.BuildWorkLimit => .{ .budget = "compiler work", .limit = self.limits.work, .required = self.work + 1 },
            error.SourceDepthLimit => .{ .budget = "source expansion depth", .limit = self.limits.depth },
            error.BuildOutputLimit => .{ .budget = "SQL output bytes", .limit = self.limits.output_bytes },
            error.BuildMemoryLimit, error.OutOfMemory => if (result.budget.exhausted) .{ .budget = "compiler memory bytes", .limit = self.limits.memory_bytes } else .{},
            error.BuildStatementLimit => .{ .budget = "SQL statement bytes", .limit = f.Sql.max_statement_bytes },
            else => .{},
        };
        var end_at = @max(self.offset, self.span_end);
        if (end_at == self.offset and self.file < sources.len) end_at = tokenEndAt(sources[self.file].text, self.offset);
        var span: SourceDiagnostic.Span = .{
            .start = @intCast(@min(self.offset, std.math.maxInt(u32))),
            .end = @intCast(@min(end_at, std.math.maxInt(u32))),
        };
        if (options.report) |r| {
            if (r.has_span) {
                if (r.file) |rf| self.file = rf else r.file = self.file;
                span = r.span;
            } else {
                r.setSpan(self.file, span.start, span.end);
            }
            @memcpy(r.frames[0..self.frames_len], self.frames[0..self.frames_len]);
            r.frames_len = self.frames_len;
            var merged = self.context;
            if (limit_context.budget != null) merged.budget = limit_context.budget;
            if (limit_context.limit != null) merged.limit = limit_context.limit;
            if (limit_context.required != null) merged.required = limit_context.required;
            r.finalize(cause, merged);
        }
        diagnostic.* = project(cause, locationSpan(sources[self.file], span), self.call_site, self.instance);
        self.context.apply(&diagnostic.*.?);
        limit_context.apply(&diagnostic.*.?);
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
    for (graph.files[entry].statements) |stmt| if (stmt.value != .use or !stmt.value.use.let_binding) {
        self.offset = stmt.span.start;
        self.span_end = stmt.span.end;
        if (self.report) |r| {
            r.setSpan(entry, stmt.span.start, stmt.span.end);
            r.setHeadline("loose top-level statement is not allowed in build entry '{s}'", .{options.entry});
            r.addNote(null, null, "place SQL and assertions inside 'MODULE', 'TARGET' or 'TEST' blocks", .{});
        }
        return error.UnsupportedSourceDeclaration;
    };
    try self.validateDefaults();
    self.file = entry;
    self.test_mode = options.mode == .test_suite;
    const target_name = try self.selectTargetName(entry, options);
    result.selected_target = target_name;
    if (self.report) |r| r.setTarget(target_name);
    self.context = .{ .name = target_name };
    const target = self.resolveTarget(entry, target_name) catch |err| {
        if (err == error.UnknownSourceSymbol) {
            if (self.report) |r| {
                r.setSpan(entry, 0, 0);
                r.setHeadline("target '{s}' is not declared in '{s}'", .{ target_name, options.entry });
                for (graph.files[entry].definitions) |cand| {
                    if (cand.kind == .target or cand.kind == .migration_target or cand.kind == .test_target or cand.kind == .target_alias) {
                        r.addNote(entry, .{ .start = cand.span.start, .end = cand.span.end }, "available target '{s}' declared here", .{cand.name});
                        break;
                    }
                }
            }
            return error.MissingSourceTarget;
        }
        return err;
    };
    const definition = graph.getDefinition(target);
    self.file = target.file;
    self.offset = definition.span.start;
    self.span_end = definition.span.end;
    const target_kind: @FieldType(s.Definition, "kind") = if (self.test_mode) .test_target else .target;
    if (definition.kind != target_kind and !(options.mode == .build and definition.kind == .migration_target)) {
        if (self.report) |r| {
            r.setSpan(target.file, definition.span.start, definition.span.end);
            if (self.test_mode) {
                r.setHeadline("target '{s}' is a build target, expected a test target", .{target_name});
                r.addNote(null, null, "run 'transit build --target {s}' or select a test target", .{target_name});
            } else {
                r.setHeadline("target '{s}' is a test target, expected a build or migration target", .{target_name});
                r.addNote(null, null, "run 'transit test --target {s}' or select a build target", .{target_name});
            }
        }
        return error.WrongSourceTargetKind;
    }
    if (definition.output_path) |raw_out| {
        result.declared_output_path = Graph.resolveWorkspaceSubpath(a, sources[target.file].path, raw_out) catch |err| {
            if (self.report) |r| {
                r.setSpan(target.file, definition.span.start, definition.span.end);
                r.setHeadline("target output path '{s}' must stay confined within the workspace root", .{raw_out});
            }
            return err;
        };
    }
    if (definition.migration) |mig| {
        result.migration = mig;
        if (mig.basis) |raw_basis| {
            result.migration_basis_path = Graph.resolveWorkspaceSubpath(a, sources[target.file].path, raw_basis) catch |err| {
                if (err == error.OutOfMemory) return err;
                if (self.report) |r| {
                    r.setSpan(target.file, definition.span.start, definition.span.end);
                    r.setHeadline("migration basis path '{s}' must stay confined within the workspace root", .{raw_basis});
                }
                return error.InvalidMigrationBasisPath;
            };
        }
    }
    self.context = .{};
    std.crypto.hash.sha2.Sha256.hash(target_name, &self.expansion, .{});
    try types.validate(graph, self.a, &self.file, &self.offset, &self.work, self.limits.work);
    try self.validateInterfaces();
    try @import("ProgramLowering.zig").validateAll(self);
    self.call_site = null;
    self.context = .{};
    if (definition.target_of) |instance_name| {
        if (!self.test_mode) {
            _ = try self.evaluateTargetComposition(target.file, definition.span, instance_name, 0);
        } else {
            if (definition.target_options.len != 0) {
                for (definition.target_options) |opt| _ = try self.expression(target.file, opt.value, &.{}, 0);
                const first_opt = definition.target_options[0];
                self.file = target.file;
                self.offset = definition.span.start;
                self.span_end = definition.span.end;
                self.context = .{ .name = first_opt.name };
                if (self.report) |r| {
                    r.setSpan(target.file, definition.span.start, definition.span.end);
                    r.setHeadline("test target option '{s}' is not yet supported by the test runner", .{first_opt.name});
                    r.addNote(null, null, "omit 'WITH (...)' options until synthetic setup, replay and flow-coverage gates land", .{});
                }
                return error.UnsupportedTestOption;
            }
            try self.checkTargetComposition(target.file, definition.span, instance_name);
            self.target_composition = .{ .file = target.file, .instance = instance_name };
            defer self.target_composition = null;
            for (definition.suites) |suite| {
                self.file = target.file;
                self.offset = definition.span.start;
                self.span_end = definition.span.end;
                const suite_file = switch (suite) {
                    .path => |raw_path| try graph.localFile(target.file, raw_path),
                    .symbol => |sym| blk: {
                        const s_ref = try graph.resolveReported(target.file, sym, self.report);
                        const s_def = graph.getDefinition(s_ref);
                        if (s_def.kind != .test_suite) {
                            self.file = s_ref.file;
                            self.offset = s_def.span.start;
                            self.span_end = s_def.span.end;
                            self.context = .{ .name = s_def.name };
                            if (self.report) |r| {
                                r.setSpan(s_ref.file, s_def.span.start, s_def.span.end);
                                r.setHeadline("'{s}' is not an 'EXPORT TEST SUITE'", .{s_def.name});
                            }
                            return error.WrongSourceTargetKind;
                        }
                        break :blk try graph.localFile(s_ref.file, s_def.suite_path.?);
                    },
                };
                try self.body(suite_file, graph.files[suite_file].statements, &.{}, 0);
            }
        }
    } else {
        try self.body(target.file, definition.body, &.{}, 0);
    }
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
        if (!self.scratch.reset(.retain_capacity)) return error.OutOfMemory;
        var at: f.Sql.Location = .{};
        const actual = try verified.check(step.sql, &at);
        if (!std.mem.eql(u8, &actual, &step.plan_digest)) return error.BuildEmissionMismatch;
        try sql.appendSlice(self.a, step.sql);
        try sql.appendSlice(self.a, ";\n");
    }
    return sql.toOwnedSlice(self.a);
}
pub fn tick(self: *Self) !void {
    if (self.work == self.limits.work) return error.BuildWorkLimit;
    self.work += 1;
}
fn validateDefaults(self: *Self) !void {
    for (self.graph.files, 0..) |file_item, fi| {
        if (file_item.defaults.len == 0) continue;
        const def_target = file_item.defaults[0];
        self.file = fi;
        self.offset = def_target.span.start;
        self.span_end = def_target.span.end;
        self.context = .{ .name = def_target.name };
        const resolved = self.resolveTarget(fi, def_target.name) catch |err| {
            if (err == error.UnknownSourceSymbol) {
                if (self.report) |r| {
                    r.setSpan(fi, def_target.span.start, def_target.span.end);
                    r.setHeadline("default target '{s}' is not declared in this file", .{def_target.name});
                }
                return error.MissingSourceTarget;
            }
            return err;
        };
        const resolved_def = self.graph.getDefinition(resolved);
        if (resolved_def.kind != .target and resolved_def.kind != .migration_target) {
            if (self.report) |r| {
                r.setSpan(fi, def_target.span.start, def_target.span.end);
                r.setHeadline("'EXPORT DEFAULT TARGET {s}' must reference a build or migration target", .{def_target.name});
            }
            return error.WrongSourceTargetKind;
        }
    }
    self.context = .{};
}
fn selectTargetName(self: *Self, entry: usize, options: Options) ![]const u8 {
    if (options.target_explicit) return std.ascii.allocLowerString(self.a, options.target);
    const entry_file = self.graph.files[entry];
    if (options.mode == .build) {
        if (entry_file.defaults.len != 0) return entry_file.defaults[0].name;
        return "default";
    }
    for (entry_file.definitions) |def| {
        if (std.mem.eql(u8, def.name, "tests")) return "tests";
    }
    var unique: ?[]const u8 = null;
    for (entry_file.definitions) |def| {
        if (def.kind != .test_target and def.kind != .target_alias) continue;
        const resolved = try self.resolveTarget(entry, def.name);
        if (self.graph.getDefinition(resolved).kind == .test_target) {
            if (unique != null) {
                if (self.report) |r| {
                    r.setSpan(entry, def.span.start, def.span.end);
                    r.setHeadline("multiple test targets declared in '{s}'; select one with '--target <name>'", .{options.entry});
                }
                return error.MissingSourceTarget;
            }
            unique = def.name;
        }
    }
    return unique orelse "tests";
}
fn resolveTarget(self: *Self, file: usize, name: []const u8) !Graph.Ref {
    var cur = try self.graph.resolve(file, .{ .member = name });
    var seen: [256]Graph.Ref = undefined;
    var hops: usize = 0;
    while (self.graph.getDefinition(cur).kind == .target_alias) {
        const def = self.graph.getDefinition(cur);
        self.file = cur.file;
        self.offset = def.span.start;
        self.span_end = def.span.end;
        for (seen[0..hops]) |prior| if (std.meta.eql(prior, cur)) {
            if (self.report) |r| {
                r.setSpan(cur.file, def.span.start, def.span.end);
                r.setHeadline("cycle detected in 'EXPORT TARGET' forwarding", .{});
            }
            return error.SourceImportCycle;
        };
        if (hops >= self.limits.depth or hops >= seen.len) return error.SourceDepthLimit;
        seen[hops] = cur;
        hops += 1;
        cur = try self.graph.resolveReported(cur.file, def.target_ref.?, self.report);
    }
    return cur;
}
fn markReferencedLets(expr: *const s.Expr, stmts: []const s.Statement, needed: []bool) void {
    switch (expr.value) {
        .reference => |name| {
            const root_ident = name.qualifier orelse name.member;
            for (stmts, 0..) |stmt, idx| {
                if (stmt.value == .use and stmt.value.use.let_binding and std.mem.eql(u8, stmt.value.use.result.?, root_ident)) {
                    needed[idx] = true;
                }
            }
        },
        .construct => |call| {
            const root_ident = call.name.qualifier orelse call.name.member;
            for (stmts, 0..) |stmt, idx| {
                if (stmt.value == .use and stmt.value.use.let_binding and std.mem.eql(u8, stmt.value.use.result.?, root_ident)) {
                    needed[idx] = true;
                }
            }
            for (call.arguments) |arg| markReferencedLets(arg, stmts, needed);
        },
        .row => |fields| for (fields) |f_item| markReferencedLets(f_item.value, stmts, needed),
        .unary => |u| markReferencedLets(u.operand, stmts, needed),
        .binary => |b| {
            markReferencedLets(b.left, stmts, needed);
            markReferencedLets(b.right, stmts, needed);
        },
        else => {},
    }
}
fn evaluateTargetComposition(self: *Self, target_file: usize, err_span: s.Span, instance_name: []const u8, depth: usize) !Value {
    const stmts = self.graph.files[target_file].statements;
    const target_idx = for (stmts, 0..) |stmt, idx| {
        if (stmt.value == .use and stmt.value.use.let_binding and std.mem.eql(u8, stmt.value.use.result.?, instance_name)) break idx;
    } else {
        self.file = target_file;
        self.offset = err_span.start;
        self.span_end = err_span.end;
        self.context = .{ .name = instance_name };
        if (self.report) |r| {
            r.setSpan(target_file, err_span.start, err_span.end);
            r.setHeadline("unknown module instance '{s}' in target declaration", .{instance_name});
        }
        return error.UnknownSourceSymbol;
    };
    const needed = try self.a.alloc(bool, target_idx + 1);
    @memset(needed, false);
    needed[target_idx] = true;
    var rev = target_idx + 1;
    while (rev > 0) {
        rev -= 1;
        if (!needed[rev]) continue;
        for (stmts[rev].value.use.arguments) |arg| markReferencedLets(arg, stmts[0..rev], needed[0..rev]);
    }
    var let_scope: std.ArrayList(Binding) = .empty;
    for (stmts[0 .. target_idx + 1], 0..) |stmt, idx| {
        if (!needed[idx]) continue;
        self.file = target_file;
        self.offset = stmt.span.start;
        self.span_end = stmt.span.end;
        const val = try self.invoke(target_file, stmt.span, stmt.value.use, let_scope.items, depth);
        try let_scope.append(self.a, .{ .name = stmt.value.use.result.?, .value = val });
    }
    return let_scope.items[let_scope.items.len - 1].value;
}
fn checkTargetComposition(self: *Self, target_file: usize, err_span: s.Span, instance_name: []const u8) !void {
    var checker = try self.fork();
    checker.symbolic = false;
    checker.test_mode = false;
    checker.catalog = .{ .output = self.a, .scratch = self.scratch.allocator() };
    defer {
        self.work = checker.work;
        self.next_owner = checker.next_owner;
    }
    _ = checker.evaluateTargetComposition(target_file, err_span, instance_name, 0) catch |err| {
        self.file = checker.file;
        self.offset = checker.offset;
        self.span_end = checker.span_end;
        self.call_site = checker.call_site;
        self.instance = checker.instance;
        self.context = checker.context;
        self.frames = checker.frames;
        self.frames_len = checker.frames_len;
        return err;
    };
}
fn validateParameterKind(self: *Self, file: usize, kind: s.Kind, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    switch (kind) {
        .module => |m_name| {
            const interface = try self.graph.resolve(file, m_name);
            if (self.graph.getDefinition(interface).kind != .interface) return error.InvalidModuleInterface;
        },
        .module_of => |m_name| {
            const ctor = try self.graph.resolveReported(file, m_name, self.report);
            if (self.graph.getDefinition(ctor).kind != .module) return error.NotModuleConstructor;
        },
        .row => |fields| for (fields) |f_item| try self.validateParameterKind(file, f_item.kind, depth + 1),
        else => {},
    }
}
fn validateInterfaces(self: *Self) !void {
    for (self.graph.files, 0..) |file, i| for (file.definitions) |definition| {
        self.file = i;
        self.offset = definition.span.start;
        for (definition.parameters) |parameter| try self.validateParameterKind(i, parameter.kind, 0);
    };
}
fn resolve(self: *Self, file: usize, name: s.Name, bindings: []const Binding) !Graph.Ref {
    if (name.qualifier == null) for (bindings) |binding| if (std.mem.eql(u8, binding.name, name.member)) {
        if (binding.value != .module) return error.NotModuleConstructor;
        return binding.value.module;
    };
    const ref = try self.graph.resolveReported(file, name, self.report);
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
        try self.sameParameterKind(expected.file, left.kind, actual.file, right.kind, depth + 1);
    }
}
fn sameParameterKind(self: *Self, left_file: usize, left: s.Kind, right_file: usize, right: s.Kind, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) return error.ModuleInterfaceMismatch;
    switch (left) {
        .module => |m| try self.signature(try self.graph.resolve(left_file, m), try self.graph.resolve(right_file, right.module), depth),
        .module_of => |m| if (!std.meta.eql(try self.graph.resolve(left_file, m), try self.graph.resolve(right_file, right.module_of))) return error.ModuleInterfaceMismatch,
        .named => |n| if (!std.meta.eql(try self.graph.resolve(left_file, n), try self.graph.resolve(right_file, right.named))) return error.ModuleInterfaceMismatch,
        .row => |fields| {
            if (fields.len != right.row.len) return error.ModuleInterfaceMismatch;
            for (fields, right.row) |lf, rf| {
                if (!std.mem.eql(u8, lf.name, rf.name)) return error.ModuleInterfaceMismatch;
                try self.sameParameterKind(left_file, lf.kind, right_file, rf.kind, depth + 1);
            }
        },
        inline .table, .stream, .queue => |columns, tag| {
            const other = @field(right, @tagName(tag));
            if (columns.len != other.len) return error.ModuleInterfaceMismatch;
            for (columns, other) |l, r| {
                if (!std.mem.eql(u8, l.name, r.name) or l.nullable != r.nullable or l.primary != r.primary or !std.mem.eql(u8, l.collation, r.collation) or
                    !types.Scalar.eql(try types.resolve(self.graph, left_file, l.type), try types.resolve(self.graph, right_file, r.type))) return error.ModuleInterfaceMismatch;
            }
        },
        else => {},
    }
}
fn argument(self: *Self, file: usize, kind: s.Kind, value: Value) !void {
    return self.argumentDepth(file, kind, value, 0);
}
fn argumentDepth(self: *Self, file: usize, kind: s.Kind, value: Value, depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    self.context.expected = @tagName(kind);
    self.context.actual = if (value.scalar()) |ty| ty.label(self.graph) else @tagName(value);
    switch (kind) {
        .named => |name| {
            const ref = try self.graph.resolve(file, name);
            const definition = self.graph.getDefinition(ref);
            self.context.expected = if (definition.domain) |domain_| domain_.identity else definition.name;
            if (definition.kind == .domain) {
                if (!types.Scalar.eql(try types.domain(self.graph, ref), value.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
            } else if (definition.kind == .variant) {
                if (value != .variant or !std.meta.eql(value.variant.definition, ref)) return error.SourceTypeMismatch;
            } else return error.InvalidParameterType;
        },
        inline .table, .stream, .queue => |columns, tag| {
            if (value == .reference_table) return error.ReferenceOnlyTableAccess;
            if (std.meta.activeTag(value) != @field(std.meta.Tag(Value), @tagName(tag))) return error.SourceTypeMismatch;
            try types.signature(self.graph, file, columns, @field(value, @tagName(tag)), &self.context);
        },
        .integer, .text, .boolean, .uuid, .timestamptz, .binary => {
            if (!types.Scalar.eql(try types.field(self.graph, file, kind), value.scalar() orelse return error.SourceTypeMismatch)) return error.SourceTypeMismatch;
        },
        .module => |name| {
            if (value != .module) return error.SourceTypeMismatch;
            try self.signature(try self.graph.resolve(file, name), value.module, 0);
        },
        .module_of => |name| {
            const expected_ctor = try self.graph.resolve(file, name);
            if (self.graph.getDefinition(expected_ctor).kind != .module) return error.NotModuleConstructor;
            self.context.expected = self.graph.getDefinition(expected_ctor).name;
            self.context.actual = if (value == .instance and value.instance.constructor != null) self.graph.getDefinition(value.instance.constructor.?).name else @tagName(value);
            if (value != .instance or value.instance.constructor == null or !std.meta.eql(value.instance.constructor.?, expected_ctor)) return error.SourceTypeMismatch;
        },
        .row => |fields| {
            if (value != .row or value.row.len != fields.len) return error.SourceTypeMismatch;
            for (fields) |expected_field| {
                const actual_val = for (value.row) |actual_field| {
                    if (std.mem.eql(u8, actual_field.name, expected_field.name)) break actual_field.value;
                } else {
                    self.context = .{ .name = expected_field.name, .expected = @tagName(expected_field.kind), .actual = "missing" };
                    return error.SourceTypeMismatch;
                };
                self.context.name = expected_field.name;
                try self.argumentDepth(file, expected_field.kind, actual_val, depth + 1);
            }
        },
        else => if (!std.mem.eql(u8, @tagName(kind), @tagName(value))) return error.SourceTypeMismatch,
    }
}
fn freshBinding(self: *Self, file: usize, name: []const u8, bindings: []const Binding) !void {
    for (bindings) |binding| if (std.mem.eql(u8, name, binding.name)) return error.DuplicateSourceName;
    for (self.graph.files[file].imports) |import| if (std.mem.eql(u8, name, import.alias)) return error.DuplicateSourceName;
    for (self.graph.files[file].definitions) |definition| if (definition.schema == null and std.mem.eql(u8, name, definition.name)) return error.DuplicateSourceName;
}
pub fn activeSchemas(self: *const Self) []const types.SchemaBinding {
    return if (self.bound_schemas) |list| list.items else &.{};
}
pub fn resolveSchemaName(schemas: []const types.SchemaBinding, raw: []const u8) []const u8 {
    for (schemas) |sb| if (std.ascii.eqlIgnoreCase(sb.logical, raw)) return sb.concrete;
    return raw;
}
pub fn hasSchemaBinding(schemas: []const types.SchemaBinding, raw: []const u8) bool {
    for (schemas) |sb| if (std.ascii.eqlIgnoreCase(sb.logical, raw)) return true;
    return false;
}
fn invoke(self: *Self, file: usize, span: s.Span, call: s.Call, bindings: []const Binding, depth: usize) anyerror!Value {
    self.span_end = span.end;
    const ref = try self.resolve(file, call.name, bindings);
    const definition = self.graph.getDefinition(ref);
    if (call.arguments.len != definition.parameters.len) {
        self.context = .{ .name = definition.name };
        if (self.report) |r| {
            r.setSpan(file, span.start, span.end);
            r.setHeadline("wrong number of arguments to module '{s}': expected {d}, found {d}", .{ definition.name, definition.parameters.len, call.arguments.len });
            r.addNote(ref.file, .{ .start = definition.span.start, .end = definition.span.end }, "module '{s}' declared here", .{definition.name});
        }
        return error.SourceArgumentCount;
    }
    var values: [64]Binding = undefined;
    var evaluated_args: [64]Value = undefined;
    for (call.arguments, 0..) |arg, idx| {
        evaluated_args[idx] = try self.expression(file, arg, bindings, 0);
    }
    if (call.names.len != 0) {
        for (call.names) |arg_name| {
            const exists = for (definition.parameters) |param| {
                if (std.mem.eql(u8, param.name, arg_name)) break true;
            } else false;
            if (!exists) {
                self.file = file;
                self.offset = span.start;
                self.span_end = span.end;
                self.context = .{ .name = arg_name };
                if (self.report) |r| {
                    r.setSpan(file, span.start, span.end);
                    r.setHeadline("unknown named argument '{s}' in call to module '{s}'", .{ arg_name, definition.name });
                    r.addNote(ref.file, .{ .start = definition.span.start, .end = definition.span.end }, "module '{s}' declared here", .{definition.name});
                }
                return error.UnknownSourceOperand;
            }
        }
    }
    for (definition.parameters, 0..) |parameter, i| {
        const arg_idx = if (call.names.len != 0) blk: {
            for (call.names, 0..) |arg_name, n_idx| {
                if (std.mem.eql(u8, arg_name, parameter.name)) break :blk n_idx;
            }
            unreachable;
        } else i;
        const arg = call.arguments[arg_idx];
        const value = evaluated_args[arg_idx];
        self.file = file;
        self.offset = arg.span.start;
        self.span_end = arg.span.end;
        self.context = .{ .name = parameter.name };
        self.argument(ref.file, parameter.kind, value) catch |err| {
            if (self.report) |r| {
                r.setSpan(file, arg.span.start, arg.span.end);
                if (parameter.kind == .identifier and value != .identifier) {
                    r.addNote(null, null, "pass identifier arguments using 'NAME <string>', e.g. NAME 'items'", .{});
                }
                r.addNote(ref.file, .{ .start = definition.span.start, .end = definition.span.end }, "parameter '{s}' of module '{s}' declared here", .{ parameter.name, definition.name });
            }
            return err;
        };
        self.context = .{};
        // Reached symbolic callees are checked for their declared scalar types.
        // This also checks both paths of recursive IF bodies before a recursive
        // edge is discharged by its signature, without guessing payload values.
        values[i] = .{ .name = parameter.name, .value = if (self.symbolic and value.scalar() != null) .{ .symbolic = value.scalar().? } else value };
    }
    // A recursive symbolic call checks its signature. The active body is already
    // being checked without inventing payload values or traversing forever.
    if (self.symbolic) for (self.checking[0..self.checking_count]) |prior| if (std.meta.eql(prior.definition, ref) and types.sameSpecialization(prior.arguments, values[0..call.arguments.len])) {
        if (call.result != null) return error.UnsupportedRecursiveExports;
        return .{ .instance = .{ .constructor = ref, .exports = &.{} } };
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
    const before_schemas = self.bound_schemas;
    const before_frames = self.frames_len;
    if (self.frames_len < self.frames.len) {
        var frame: SourceDiagnostic.CallFrame = .{ .file = file, .span = .{ .start = span.start, .end = span.end } };
        const n: u8 = @intCast(@min(definition.name.len, frame.callee.len));
        @memcpy(frame.callee[0..n], definition.name[0..n]);
        frame.callee_len = n;
        self.frames[self.frames_len] = frame;
        self.frames_len += 1;
    }
    var completed = false;
    defer {
        if (completed) {
            self.call_site = before_site;
            self.instance = before_instance;
            self.frames_len = before_frames;
        }
        self.expansion = before_expansion;
        self.owner = before_owner;
        self.exports = before_exports;
        self.bound_schemas = before_schemas;
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
    var schemas: std.ArrayList(types.SchemaBinding) = .empty;
    self.exports = &exports;
    self.bound_schemas = &schemas;
    try self.body(ref.file, definition.body, values[0..call.arguments.len], depth + 1);
    const result = try exports.toOwnedSlice(self.a);
    const owned_schemas = try schemas.toOwnedSlice(self.a);
    completed = true;
    return .{ .instance = .{ .constructor = ref, .exports = result, .schemas = owned_schemas } };
}
fn fork(self: *Self) !Self {
    var result = self.*;
    result.symbolic = true;
    if (!self.symbolic) result.checking_count = 0;
    result.catalog.schemas = try self.catalog.schemas.clone(self.a);
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
    if (self.bound_schemas) |schemas| {
        result.bound_schemas = try self.a.create(std.ArrayList(types.SchemaBinding));
        result.bound_schemas.?.* = try schemas.clone(self.a);
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
        self.span_end = checker.span_end;
        self.call_site = checker.call_site;
        self.instance = checker.instance;
        self.context = checker.context;
        self.frames = checker.frames;
        self.frames_len = checker.frames_len;
        return err;
    };
    if (stable_catalog and (checker.catalog.schemas.items.len != self.catalog.schemas.items.len or
        checker.catalog.entries.items.len != self.catalog.entries.items.len or
        (if (checker.exports) |v| v.items.len else 0) != (if (self.exports) |v| v.items.len else 0))) return error.UnsupportedSymbolicSchema;
}
fn match(self: *Self, file: usize, input: @FieldType(@FieldType(s.Statement, "value"), "match"), bindings: []const Binding, depth: usize) !void {
    const value = try self.expression(file, input.value, bindings, 0);
    if (value != .variant) return error.SourceTypeMismatch;
    const variant = value.variant;
    const definition = self.graph.getDefinition(variant.definition);
    if (input.arms.len != definition.constructors.len) {
        if (self.report) |r| {
            r.setSpan(file, input.value.span.start, input.value.span.end);
            for (definition.constructors) |ctor| {
                const covered = for (input.arms) |arm| {
                    const name = arm.constructor.constructor orelse arm.constructor.member;
                    if (std.mem.eql(u8, name, ctor.name)) break true;
                } else false;
                if (!covered) {
                    r.setHeadline("non-exhaustive 'MATCH' on variant '{s}': missing '{s}'", .{ definition.name, ctor.name });
                    break;
                }
            }
            r.addNote(variant.definition.file, .{ .start = definition.span.start, .end = definition.span.end }, "variant '{s}' declared here", .{definition.name});
        }
        return error.NonExhaustiveSourceMatch;
    }
    var seen: [64]bool = @splat(false);
    var selected: usize = 0;
    for (input.arms, 0..) |arm, i| {
        self.offset = arm.span.start;
        self.span_end = arm.span.end;
        const resolved = try types.constructor(self.graph, file, arm.constructor);
        if (!std.meta.eql(resolved.definition, variant.definition)) return error.SourceTypeMismatch;
        if (seen[resolved.index]) {
            if (self.report) |r| {
                r.setSpan(file, arm.span.start, arm.span.end);
                r.setHeadline("duplicate 'WHEN' arm for constructor '{s}'", .{definition.constructors[resolved.index].name});
            }
            return error.DuplicateSourceMatchArm;
        }
        seen[resolved.index] = true;
        if (resolved.index == variant.constructor) selected = i;
        const fields = definition.constructors[resolved.index].fields;
        if (arm.names.len != fields.len) {
            if (self.report) |r| {
                r.setSpan(file, arm.span.start, arm.span.end);
                r.setHeadline("constructor '{s}' expects {d} binding(s), found {d}", .{ definition.constructors[resolved.index].name, fields.len, arm.names.len });
            }
            return error.SourceArgumentCount;
        }
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
    try self.bodyInline(file, statements, &scope, depth);
}
fn mergeModuleExport(self: *Self, file: usize, scope: *std.ArrayList(Binding), exported: types.Export) !void {
    for (scope.items) |prior| if (std.mem.eql(u8, prior.name, exported.name)) {
        if (types.sameSpecialization(&.{.{ .name = prior.name, .value = prior.value }}, &.{.{ .name = exported.name, .value = exported.value }})) return;
        self.context = .{ .name = exported.name };
        return error.DuplicateSourceName;
    };
    for (self.graph.files[file].imports) |import| if (std.mem.eql(u8, exported.name, import.alias)) return error.DuplicateSourceName;
    for (self.graph.files[file].definitions) |definition| if (definition.schema == null and std.mem.eql(u8, exported.name, definition.name)) return error.DuplicateSourceName;
    try scope.append(self.a, .{ .name = exported.name, .value = exported.value });
}
fn mergeInstanceSchemas(self: *Self, schemas: []const types.SchemaBinding) !void {
    const active = self.bound_schemas orelse return;
    for (schemas) |sb| {
        var found = false;
        for (active.items) |prior| if (std.mem.eql(u8, prior.logical, sb.logical)) {
            if (!std.mem.eql(u8, prior.concrete, sb.concrete)) {
                self.context = .{ .name = sb.logical };
                return error.DuplicateSourceName;
            }
            found = true;
            break;
        };
        if (!found) try active.append(self.a, sb);
    }
}
fn useModule(self: *Self, file: usize, mod_name: s.Name, scope: *std.ArrayList(Binding)) !void {
    if (self.exports == null) return error.UnsupportedSourceDeclaration;
    if (mod_name.constructor != null) return error.InvalidSourceName;
    for (scope.items) |b| {
        if (mod_name.qualifier == null and std.mem.eql(u8, b.name, mod_name.member)) {
            if (b.value != .instance) {
                self.context = .{ .name = mod_name.member, .expected = "module instance", .actual = @tagName(b.value) };
                return error.SourceTypeMismatch;
            }
            try self.mergeInstanceSchemas(b.value.instance.schemas);
            for (b.value.instance.exports) |exported| try self.mergeModuleExport(file, scope, exported);
            return;
        }
        if (mod_name.qualifier) |qualifier| if (std.mem.eql(u8, b.name, qualifier)) {
            const inner = try self.projectField(b.value, mod_name.member);
            if (inner != .instance) return error.SourceTypeMismatch;
            try self.mergeInstanceSchemas(inner.instance.schemas);
            for (inner.instance.exports) |exported| try self.mergeModuleExport(file, scope, exported);
            return;
        };
    }
    if (mod_name.qualifier == null) {
        for (self.graph.files[file].imports) |imp| if (std.mem.eql(u8, imp.alias, mod_name.member)) {
            const imp_file = try self.graph.imported(file, imp);
            for (self.graph.files[imp_file].definitions, 0..) |def, def_idx| {
                if (!def.public) continue;
                const val: Value = switch (def.kind) {
                    .function => .{ .helper = .{ .kind = .function, .ref = .{ .file = imp_file, .definition = def_idx } } },
                    .guard => .{ .helper = .{ .kind = .guard, .ref = .{ .file = imp_file, .definition = def_idx } } },
                    .procedure => .{ .helper = .{ .kind = .procedure, .ref = .{ .file = imp_file, .definition = def_idx } } },
                    .module => .{ .module = .{ .file = imp_file, .definition = def_idx } },
                    else => continue,
                };
                try self.mergeModuleExport(file, scope, .{ .name = def.name, .value = val });
            }
            return;
        };
    }
    self.context = .{ .name = mod_name.qualifier orelse mod_name.member };
    return error.UnknownSourceSymbol;
}
fn declareFrom(self: *Self, file: usize, span: s.Span, raw_path: []const u8, scope: *std.ArrayList(Binding), depth: usize) anyerror!void {
    if (self.exports == null) return error.UnsupportedSourceDeclaration;
    const frag_file = try self.graph.localFile(file, raw_path);
    for (self.declaring[0..self.declaring_len]) |active| if (active == frag_file) return error.SourceImportCycle;
    if (self.declaring_len >= self.declaring.len or depth >= self.limits.depth) return error.SourceDepthLimit;
    self.declaring[self.declaring_len] = frag_file;
    self.declaring_len += 1;
    defer self.declaring_len -= 1;

    const before_frames = self.frames_len;
    if (self.frames_len < self.frames.len) {
        var frame: SourceDiagnostic.CallFrame = .{ .file = file, .span = .{ .start = span.start, .end = span.end } };
        const n: u8 = @intCast(@min(raw_path.len, frame.callee.len));
        @memcpy(frame.callee[0..n], raw_path[0..n]);
        frame.callee_len = n;
        self.frames[self.frames_len] = frame;
        self.frames_len += 1;
    }
    var completed = false;
    defer if (completed) {
        self.frames_len = before_frames;
    };

    const frag = self.graph.files[frag_file];
    const active_schemas = try self.a.dupe(types.SchemaBinding, self.activeSchemas());
    for (frag.definitions, 0..) |def, def_idx| {
        self.file = frag_file;
        self.offset = def.span.start;
        self.span_end = def.span.end;
        switch (def.kind) {
            .function, .guard, .procedure => {
                for (scope.items) |prior| if (std.mem.eql(u8, prior.name, def.name)) {
                    self.context = .{ .name = def.name };
                    return error.DuplicateSourceName;
                };
                const h_kind: types.HelperKind = switch (def.kind) {
                    .function => .function,
                    .guard => .guard,
                    .procedure => .procedure,
                    else => unreachable,
                };
                const captured = try self.a.dupe(Binding, scope.items);
                try scope.append(self.a, .{ .name = def.name, .value = .{ .helper = .{ .kind = h_kind, .ref = .{ .file = frag_file, .definition = def_idx }, .bindings = captured, .owner = self.owner, .schemas = active_schemas } } });
            },
            .domain, .variant => {},
            else => return error.UnsupportedSourceDeclaration,
        }
    }
    try @import("ProgramLowering.zig").validateFragmentCallGraph(self, frag_file, scope.items);
    try self.bodyInline(frag_file, frag.statements, scope, depth + 1);
    try @import("ProgramLowering.zig").validateFragmentBodies(self, frag_file, scope.items);
    completed = true;
}
fn resolveExportedHelper(self: *Self, file: usize, source: s.Name, expected: types.HelperKind, bindings: []const Binding) !types.Helper {
    if (source.qualifier) |qualifier| {
        for (bindings) |b| if (std.mem.eql(u8, b.name, qualifier)) {
            if (b.value != .instance) return error.SourceTypeMismatch;
            for (b.value.instance.exports) |exported| if (std.mem.eql(u8, exported.name, source.member)) {
                if (exported.value != .helper or exported.value.helper.kind != expected) return error.SourceTypeMismatch;
                return exported.value.helper;
            };
            self.context = .{ .name = source.member };
            return error.UnknownSourceExport;
        };
        if (hasSchemaBinding(self.activeSchemas(), qualifier)) {
            var idx = bindings.len;
            while (idx > 0) {
                idx -= 1;
                const b = bindings[idx];
                if (!std.mem.eql(u8, b.name, source.member)) continue;
                if (b.value != .helper or b.value.helper.kind != expected) return error.SourceTypeMismatch;
                return b.value.helper;
            }
        }
        const ref = try self.graph.resolveReported(file, source, self.report);
        const def = self.graph.getDefinition(ref);
        if (!std.mem.eql(u8, @tagName(def.kind), @tagName(expected))) return error.SourceTypeMismatch;
        return .{ .kind = expected, .ref = ref, .owner = self.owner, .schemas = try self.a.dupe(types.SchemaBinding, self.activeSchemas()) };
    }
    var idx = bindings.len;
    while (idx > 0) {
        idx -= 1;
        const b = bindings[idx];
        if (!std.mem.eql(u8, b.name, source.member)) continue;
        if (b.value != .helper or b.value.helper.kind != expected) return error.SourceTypeMismatch;
        return b.value.helper;
    }
    const ref = try self.graph.resolveReported(file, source, self.report);
    const def = self.graph.getDefinition(ref);
    if (!std.mem.eql(u8, @tagName(def.kind), @tagName(expected))) return error.SourceTypeMismatch;
    return .{ .kind = expected, .ref = ref, .owner = self.owner, .schemas = try self.a.dupe(types.SchemaBinding, self.activeSchemas()) };
}
fn bodyInline(self: *Self, file: usize, statements: []const s.Statement, scope: *std.ArrayList(Binding), depth: usize) anyerror!void {
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    for (statements) |statement| {
        self.file = file;
        self.offset = statement.span.start;
        self.span_end = statement.span.end;
        self.context = .{};
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
            .use_module => |mod_name| try self.useModule(file, mod_name, scope),
            .declare_from => |raw_path| try self.declareFrom(file, statement.span, raw_path, scope, depth),
            .bind_schema => |bind_stmt| {
                const schemas = self.bound_schemas orelse return error.UnsupportedSourceDeclaration;
                const val = try self.expression(file, bind_stmt.target, bindings, 0);
                self.file = file;
                self.offset = statement.span.start;
                self.span_end = statement.span.end;
                if (val != .schema_binding) {
                    self.context = .{ .name = bind_stmt.name, .expected = "schema_binding", .actual = @tagName(val) };
                    return error.SourceTypeMismatch;
                }
                for (schemas.items) |prior| if (std.mem.eql(u8, prior.logical, bind_stmt.name)) {
                    self.context = .{ .name = bind_stmt.name };
                    if (self.report) |r| {
                        r.setSpan(file, statement.span.start, statement.span.end);
                        r.setHeadline("schema '{s}' is already bound in this module", .{bind_stmt.name});
                    }
                    return error.DuplicateSourceName;
                };
                try schemas.append(self.a, .{ .logical = bind_stmt.name, .concrete = val.schema_binding });
            },
            .table_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                const table = if (exported.operand) blk: {
                    const value = try self.reference(file, exported.source, bindings);
                    if (value != .identifier) return error.SourceTypeMismatch;
                    const entry = try self.catalog.find(value.identifier);
                    if (entry.owner != self.owner) return error.ForeignTableExport;
                    break :blk entry;
                } else blk: {
                    if (exported.source.qualifier == null) {
                        var found_binding: ?Value = null;
                        for (bindings) |b| if (std.mem.eql(u8, b.name, exported.source.member)) {
                            found_binding = b.value;
                            break;
                        };
                        if (found_binding) |val| {
                            if (val == .reference_table) return error.ReferenceOnlyTableAccess;
                            if (val != .table) return error.SourceTypeMismatch;
                            break :blk val.table;
                        }
                        const entry = try self.catalog.find(exported.source.member);
                        if (entry.owner != self.owner) return error.ForeignTableExport;
                        break :blk entry;
                    }
                    const q = exported.source.qualifier.?;
                    var has_binding_qual = false;
                    for (bindings) |b| if (std.mem.eql(u8, b.name, q)) {
                        has_binding_qual = true;
                        break;
                    };
                    if (!has_binding_qual and hasSchemaBinding(self.activeSchemas(), q)) {
                        const entry = try self.catalog.findQualified(resolveSchemaName(self.activeSchemas(), q), exported.source.member);
                        if (entry.owner != self.owner) return error.ForeignTableExport;
                        break :blk entry;
                    }
                    const value = try self.reference(file, exported.source, bindings);
                    if (value == .reference_table) return error.ReferenceOnlyTableAccess;
                    if (value != .table) return error.SourceTypeMismatch;
                    break :blk value.table;
                };
                try exports.append(self.a, .{ .name = exported.alias, .value = .{ .table = table } });
            },
            .log_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                const entry = if (exported.operand) blk: {
                    const value = try self.reference(file, exported.source, bindings);
                    if (value != .identifier) return error.SourceTypeMismatch;
                    const resource = try self.catalog.findResource(value.identifier);
                    if (resource.owner != self.owner) return error.ForeignTableExport;
                    break :blk resource;
                } else blk: {
                    if (exported.source.qualifier == null) {
                        var found_binding: ?Value = null;
                        for (bindings) |b| if (std.mem.eql(u8, b.name, exported.source.member)) {
                            found_binding = b.value;
                            break;
                        };
                        if (found_binding) |val| {
                            break :blk switch (val) {
                                .stream, .queue => |res| res,
                                .reference_table => return error.ReferenceOnlyTableAccess,
                                else => return error.SourceTypeMismatch,
                            };
                        }
                        const resource = try self.catalog.findResource(exported.source.member);
                        if (resource.owner != self.owner) return error.ForeignTableExport;
                        break :blk resource;
                    }
                    const q = exported.source.qualifier.?;
                    var has_binding_qual = false;
                    for (bindings) |b| if (std.mem.eql(u8, b.name, q)) {
                        has_binding_qual = true;
                        break;
                    };
                    if (!has_binding_qual and hasSchemaBinding(self.activeSchemas(), q)) {
                        const resource = try self.catalog.findResourceQualified(resolveSchemaName(self.activeSchemas(), q), exported.source.member);
                        if (resource.owner != self.owner) return error.ForeignTableExport;
                        break :blk resource;
                    }
                    const value = try self.reference(file, exported.source, bindings);
                    break :blk switch (value) {
                        .stream, .queue => |resource| resource,
                        .reference_table => return error.ReferenceOnlyTableAccess,
                        else => return error.SourceTypeMismatch,
                    };
                };
                if (!std.mem.eql(u8, @tagName(entry.kind), @tagName(exported.kind))) return error.SourceTypeMismatch;
                try exports.append(self.a, .{ .name = exported.alias, .value = entry.value() });
            },
            .symbol_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                const h_kind: types.HelperKind = switch (exported.kind) {
                    .function => .function,
                    .guard => .guard,
                    .procedure => .procedure,
                    .view, .dataflow, .profile => {
                        if (self.report) |r| {
                            r.setSpan(file, statement.span.start, statement.span.end);
                            r.setHeadline("'EXPORT {s}' is not yet supported in this compiler profile", .{switch (exported.kind) {
                                .view => "VIEW",
                                .dataflow => "DATAFLOW",
                                .profile => "PROFILE",
                                else => unreachable,
                            }});
                        }
                        return error.UnsupportedSourceDeclaration;
                    },
                };
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                const helper_val = try self.resolveExportedHelper(file, exported.source, h_kind, bindings);
                try exports.append(self.a, .{ .name = exported.alias, .value = .{ .helper = helper_val } });
            },
            .reference_export => |exported| {
                const exports = self.exports orelse return error.ExportOutsideModule;
                if (exports.items.len == 64) return error.SourceExportLimit;
                for (exports.items) |prior| if (std.mem.eql(u8, prior.name, exported.alias)) return error.DuplicateSourceName;
                var allowed_cols: ?[]const []const u8 = null;
                var table: *const types.Table = blk: {
                    if (exported.source.qualifier == null) {
                        for (bindings) |b| if (std.mem.eql(u8, b.name, exported.source.member)) {
                            switch (b.value) {
                                .table => |tbl| break :blk tbl,
                                .reference_table => |ref_tbl| {
                                    allowed_cols = ref_tbl.columns;
                                    break :blk ref_tbl.table;
                                },
                                else => return error.SourceTypeMismatch,
                            }
                        };
                        const entry = try self.catalog.find(exported.source.member);
                        if (entry.owner != self.owner) return error.ForeignTableExport;
                        break :blk entry;
                    }
                    const q = exported.source.qualifier.?;
                    var has_binding_qual = false;
                    for (bindings) |b| if (std.mem.eql(u8, b.name, q)) {
                        has_binding_qual = true;
                        break;
                    };
                    if (!has_binding_qual and hasSchemaBinding(self.activeSchemas(), q)) {
                        const entry = try self.catalog.findQualified(resolveSchemaName(self.activeSchemas(), q), exported.source.member);
                        if (entry.owner != self.owner) return error.ForeignTableExport;
                        break :blk entry;
                    }
                    const value = try self.reference(file, exported.source, bindings);
                    switch (value) {
                        .table => |tbl| break :blk tbl,
                        .reference_table => |ref_tbl| {
                            allowed_cols = ref_tbl.columns;
                            break :blk ref_tbl.table;
                        },
                        else => return error.SourceTypeMismatch,
                    }
                };
                for (exported.columns) |col_name| {
                    const exists = for (table.schema.columns) |col| {
                        if (std.mem.eql(u8, col.name, col_name)) break true;
                    } else false;
                    if (!exists) {
                        self.context = .{ .name = table.name, .column = col_name };
                        return error.UnknownColumn;
                    }
                    if (allowed_cols) |allowed| {
                        const permitted = for (allowed) |prior_col| {
                            if (std.mem.eql(u8, prior_col, col_name)) break true;
                        } else false;
                        if (!permitted) {
                            self.context = .{ .name = table.name, .column = col_name };
                            return error.ReferenceOnlyTableAccess;
                        }
                    }
                }
                if (!table.encapsulated) {
                    const updated = try self.a.create(types.Table);
                    updated.* = table.*;
                    updated.encapsulated = true;
                    for (self.catalog.entries.items) |*slot| if (slot.* == table) {
                        slot.* = updated;
                    };
                    table = updated;
                }
                try exports.append(self.a, .{ .name = exported.alias, .value = .{ .reference_table = .{ .table = table, .columns = exported.columns } } });
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
fn projectField(self: *Self, container: Value, field: []const u8) !Value {
    switch (container) {
        .instance => |inst| {
            for (inst.exports) |exported| if (std.mem.eql(u8, exported.name, field)) return exported.value;
            self.context = .{ .name = field };
            return error.UnknownSourceExport;
        },
        .row => |fields| {
            for (fields) |item| if (std.mem.eql(u8, item.name, field)) return item.value;
            self.context = .{ .name = field };
            return error.UnknownSourceExport;
        },
        else => return error.SourceTypeMismatch,
    }
}
fn reference(self: *Self, file: usize, name: s.Name, bindings: []const Binding) !Value {
    for (bindings) |binding| {
        if (name.qualifier == null and std.mem.eql(u8, binding.name, name.member)) return binding.value;
        if (name.qualifier) |qualifier| if (std.mem.eql(u8, binding.name, qualifier)) {
            const first = try self.projectField(binding.value, name.member);
            if (name.constructor) |second_field| return self.projectField(first, second_field);
            return first;
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
    var evaluated: [64]Value = undefined;
    for (call.arguments, 0..) |arg, idx| {
        evaluated[idx] = try self.expression(file, arg, bindings, depth + 1);
    }
    if (call.names.len != 0) {
        for (call.names) |arg_name| {
            const exists = for (fields) |f_item| {
                if (std.mem.eql(u8, f_item.name, arg_name)) break true;
            } else false;
            if (!exists) return error.UnknownSourceOperand;
        }
    }
    const values = try self.a.alloc(Value, fields.len);
    for (fields, values, 0..) |field, *value, idx| {
        const arg_idx = if (call.names.len != 0) blk: {
            for (call.names, 0..) |arg_name, n_idx| {
                if (std.mem.eql(u8, arg_name, field.name)) break :blk n_idx;
            }
            unreachable;
        } else idx;
        value.* = evaluated[arg_idx];
        try self.argument(resolved.definition.file, field.kind, value.*);
    }
    return .{ .variant = .{ .definition = resolved.definition, .constructor = resolved.index, .fields = values } };
}
fn expression(self: *Self, file: usize, expr: *const s.Expr, bindings: []const Binding, depth: usize) anyerror!Value {
    self.file = file;
    self.offset = expr.span.start;
    self.span_end = expr.span.end;
    try self.tick();
    if (depth >= self.limits.depth) return error.SourceDepthLimit;
    return switch (expr.value) {
        .integer => |value| .{ .integer = value },
        .text => |value| .{ .text = value },
        .boolean => |value| .{ .boolean = value },
        .uuid => |value| blk: {
            _ = f.Types.Semantics.bind(value, .uuid) catch {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid UUID literal '{s}'", .{value});
                }
                return error.InvalidSourceOperand;
            };
            break :blk .{ .uuid = value };
        },
        .timestamptz => |value| blk: {
            _ = f.Types.Semantics.bind(value, .{ .timestamp = .utc }) catch {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid TIMESTAMPTZ literal '{s}'", .{value});
                }
                return error.InvalidSourceOperand;
            };
            break :blk .{ .timestamptz = value };
        },
        .bytes => |value| blk: {
            if (value.len % 2 != 0) {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid hexadecimal BINARY literal (odd nibble count)", .{});
                }
                return error.InvalidSourceOperand;
            }
            for (value) |ch| if (!std.ascii.isHex(ch)) {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid hexadecimal BINARY literal", .{});
                }
                return error.InvalidSourceOperand;
            };
            break :blk .{ .binary = try std.ascii.allocLowerString(self.a, value) };
        },
        .type => |value| .{ .type = .{ .base = value } },
        .named_type => |name| .{ .type = try types.resolve(self.graph, file, .{ .named = name }) },
        .construct => |call| try self.construct(file, call, bindings, depth),
        .schema_binding => |value| blk: {
            if (value.len == 0 or value.len > 63 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_')) {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid schema binding identifier '{s}'", .{value});
                }
                return error.InvalidCatalogName;
            }
            for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_')) {
                if (self.report) |r| {
                    r.setSpan(file, expr.span.start, expr.span.end);
                    r.setHeadline("invalid schema binding identifier '{s}'", .{value});
                }
                return error.InvalidCatalogName;
            };
            break :blk .{ .schema_binding = try std.ascii.allocLowerString(self.a, value) };
        },
        .row => |fields| blk: {
            const out = try self.a.alloc(types.Export, fields.len);
            for (fields, out) |field, *slot| {
                slot.* = .{ .name = field.name, .value = try self.expression(file, field.value, bindings, depth + 1) };
            }
            break :blk .{ .row = out };
        },
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
                    .uuid => |v| std.mem.eql(u8, &(f.Types.Semantics.bind(v, .uuid) catch unreachable).uuid, &(f.Types.Semantics.bind(r.uuid, .uuid) catch unreachable).uuid),
                    .timestamptz => |v| (f.Types.Semantics.bind(v, .{ .timestamp = .utc }) catch unreachable).timestamp == (f.Types.Semantics.bind(r.timestamptz, .{ .timestamp = .utc }) catch unreachable).timestamp,
                    .binary => |v| std.ascii.eqlIgnoreCase(v, r.binary),
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
                .uuid => std.mem.order(u8, &(f.Types.Semantics.bind(left.uuid, .uuid) catch unreachable).uuid, &(f.Types.Semantics.bind(right.uuid, .uuid) catch unreachable).uuid),
                .timestamptz => std.math.order((f.Types.Semantics.bind(left.timestamptz, .{ .timestamp = .utc }) catch unreachable).timestamp, (f.Types.Semantics.bind(right.timestamptz, .{ .timestamp = .utc }) catch unreachable).timestamp),
                .binary => std.mem.order(u8, left.binary, right.binary),
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
    var origins: std.ArrayList(Origin) = .empty;
    defer origins.deinit(self.a);
    const before_call_site = self.call_site;
    var at: f.Sql.Location = .{ .offset = std.math.maxInt(usize) };
    self.emitStatement(file, span, template, bindings, &origins, &at) catch |err| {
        const offset = self.context.offset orelse at.offset;
        for (origins.items) |origin| if (offset >= origin.start and offset < origin.end) {
            if (origin.file) |origin_file| self.file = origin_file;
            self.offset = origin.source;
            self.span_end = origin.source;
            if (origin.call) |call| self.call_site = location(self.graph.sources[call.file], call.offset);
            break;
        };
        return err;
    };
    self.call_site = before_call_site;
}
fn emitStatement(self: *Self, file: usize, span: s.Span, template: s.Template.Syntax, bindings: []const Binding, origins: *std.ArrayList(Origin), at: *f.Sql.Location) !void {
    const tokens = template.tokens;
    if (self.symbolic and (template.kind == .program or template.kind == .control)) return error.UnsupportedSymbolicProgram;
    if (self.in_case and self.actions.items.len == Test.max_actions) return error.TestActionLimit;
    self.file = file;
    self.offset = span.start;
    if (!self.scratch.reset(.retain_capacity)) return error.OutOfMemory;
    const scratch = self.scratch.allocator();
    const log_statement = switch (template.kind) {
        .create_schema, .create_stream, .create_queue, .produce, .enqueue, .consume, .program, .control => true,
        else => false,
    };
    var type_sites: std.ArrayList(usize) = .empty;
    var sites: std.ArrayList(Operands.Site) = .empty;
    defer sites.deinit(self.a);
    var obligations: std.ArrayList(@import("ProgramAnnotations.zig").Obligation) = .empty;
    defer obligations.deinit(self.a);
    self.catalog.owner = self.owner;
    self.catalog.encapsulate = self.activeSchemas().len != 0;
    self.catalog.bindings = bindings;
    self.catalog.context = &self.context;
    const is_create = tokenIs(self.graph.sources[file].text, tokens[0], "CREATE");
    const raw = if (template.kind == .program)
        try @import("ProgramLowering.zig").lowerProgram(self, file, tokens, bindings, scratch, f.Sql.max_statement_bytes, &sites, origins, &obligations)
    else
        try expand(self.graph.sources[file].text, tokens, bindings, self.activeSchemas(), scratch, f.Sql.max_statement_bytes, false, if (log_statement) null else &type_sites, self.a, &sites, origins);
    // DDL creates the proposed shape; other statements check source annotations
    // before the ordinary binder can erase nominal identity into scalar values.
    var digest: [32]u8 = undefined;
    if (is_create and template.kind != .program) digest = try self.catalog.check(raw, at);
    const resource_checked = if (log_statement) try @import("ResourceOperands.zig").check(template, bindings) else null;
    const checked = if (template.kind == .program) blk: {
        var analysis = try @import("ProgramCheck.zig").analyze(&self.catalog, raw, at);
        defer analysis.deinit();
        var result = resource_checked.?;
        result.program = try @import("ProgramAnnotations.zig").check(scratch, self.a, self.graph, &self.catalog, analysis.parsed.program, &analysis.bound, raw, sites.items, origins.items, obligations.items, &self.context, &self.work, self.limits.work);
        break :blk result;
    } else if (template.kind == .control or template.kind == .create_schema) resource_checked.? else try Operands.check(scratch, self.a, self.graph, &self.catalog, self.owner, bindings, raw, sites.items, self.symbolic, &self.context);
    self.context = .{};
    if (log_statement and self.symbolic and !is_create) _ = try self.catalog.check(raw, at);
    if (!log_statement) try Catalog.verifyTypeOperands(scratch, raw, type_sites.items, at);
    self.checked_statements += 1;
    if (self.symbolic) return;
    const canonical = if (template.kind == .program) raw else blk: {
        origins.clearRetainingCapacity();
        break :blk try expand(self.graph.sources[file].text, tokens, bindings, self.activeSchemas(), scratch, f.Sql.max_statement_bytes, true, null, self.a, null, origins);
    };
    if (!is_create or template.kind == .program) digest = try self.catalog.check(canonical, at);
    if (canonical.len + 2 > self.limits.output_bytes - self.output_bytes) return error.BuildOutputLimit;
    self.output_bytes += canonical.len + 2;
    var binding_hash = std.crypto.hash.sha2.Sha256.init(.{});
    binding_hash.update("transit.source.bindings.v1\x00");
    for (bindings) |binding| {
        Graph.hashPart(&binding_hash, binding.name);
        try types.hashValue(binding.value, self.graph, &binding_hash, 0);
    }
    try self.steps.append(self.a, .{ .sql = try self.a.dupe(u8, canonical), .plan_digest = digest, .definition = location(self.graph.sources[file], span.start), .call = self.call_site, .instance = try self.a.dupe(u8, self.instance), .bindings_digest = binding_hash.finalResult(), .checked = checked });
    if (self.in_case) try self.actions.append(self.a, .{ .step = self.steps.items.len - 1, .expectation = .complete, .location = locationSpan(self.graph.sources[file], .{ .start = span.start, .end = span.end }) });
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
    var needs_case_scope = false;
    for (case.setup) |setup| switch (setup) {
        .call => |call| if (call.result != null) {
            needs_case_scope = true;
        },
        .reference => needs_case_scope = true,
    };
    const before_case_schemas = self.bound_schemas;
    var case_schemas: std.ArrayList(types.SchemaBinding) = .empty;
    if (before_case_schemas) |prior_s| try case_schemas.appendSlice(self.a, prior_s.items);
    self.bound_schemas = &case_schemas;
    defer self.bound_schemas = before_case_schemas;
    if (!needs_case_scope) {
        for (case.setup) |setup| {
            const val = try self.invoke(file, span, setup.call, bindings, depth + 1);
            if (val == .instance) try self.mergeInstanceSchemas(val.instance.schemas);
        }
        try self.body(file, case.body, bindings, depth + 1);
    } else {
        var case_scope: std.ArrayList(Binding) = .empty;
        try case_scope.appendSlice(self.a, bindings);
        var used_composition = false;
        for (case.setup) |setup| switch (setup) {
            .call => |call| {
                if (call.result) |res_name| try self.freshBinding(file, res_name, case_scope.items);
                const val = try self.invoke(file, span, call, case_scope.items, depth + 1);
                if (call.result) |res_name| try case_scope.append(self.a, .{ .name = res_name, .value = val });
                if (val == .instance) try self.mergeInstanceSchemas(val.instance.schemas);
            },
            .reference => |ref_name| {
                if (ref_name.qualifier != null or ref_name.constructor != null) return error.NotModuleConstructor;
                const comp = self.target_composition orelse return error.NotModuleConstructor;
                if (used_composition) return error.ConflictingModuleInstance;
                used_composition = true;
                try self.freshBinding(file, ref_name.member, case_scope.items);
                const comp_val = try self.evaluateTargetComposition(comp.file, span, comp.instance, depth + 1);
                try case_scope.append(self.a, .{ .name = ref_name.member, .value = comp_val });
                try self.mergeInstanceSchemas(comp_val.instance.schemas);
                for (comp_val.instance.exports) |exported| {
                    if (std.mem.eql(u8, exported.name, ref_name.member)) continue;
                    try self.mergeModuleExport(file, &case_scope, exported);
                }
            },
        };
        try self.body(file, case.body, case_scope.items, depth + 1);
    }
    if (self.checked_statements == 0) return error.EmptyTestCase;
    if (self.symbolic) return;
    const sql = try self.verify();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql, &digest, .{});
    try self.cases.append(self.a, .{ .name = try self.a.dupe(u8, case.name), .identity = identity, .location = locationSpan(self.graph.sources[file], .{ .start = span.start, .end = span.end }), .sql = sql, .sql_digest = digest, .steps = try self.steps.toOwnedSlice(self.a), .actions = try self.actions.toOwnedSlice(self.a) });
}
fn assertion(self: *Self, file: usize, span: s.Span, value: s.Assertion, bindings: []const Binding) !void {
    if (!self.in_case) return error.TestAssertionOutsideCase;
    try self.emit(file, span, value.sql, bindings);
    const scratch = self.scratch.allocator();
    const sql = if (self.symbolic) try expand(self.graph.sources[file].text, value.sql.tokens, bindings, self.activeSchemas(), scratch, f.Sql.max_statement_bytes, false, null, self.a, null, null) else self.steps.items[self.steps.items.len - 1].sql;
    const is_select = value.sql.kind == .select or value.sql.kind == .consume;
    const expected: Test.Expectation = switch (value.expected) {
        .rows => |template| blk: {
            const tokens = template.tokens;
            if (!is_select) return error.TestRowsRequired;
            const schema = try self.catalog.querySchema(sql);
            const text = if (tokens.len == 0) "" else try expand(self.graph.sources[file].text, tokens, bindings, self.activeSchemas(), scratch, f.Sql.max_statement_bytes, false, null, self.a, null, null);
            const rows = try Test.bindRows(self.a, scratch, text, schema);
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
    const dot = std.mem.indexOfScalar(u8, name.identifier, '.');
    const want_schema = if (dot) |d| resolveSchemaName(self.activeSchemas(), name.identifier[0..d]) else "public";
    const want_name = if (dot) |d| name.identifier[d + 1 ..] else name.identifier;
    const program = for (self.catalog.programs.items) |program| {
        if (std.mem.eql(u8, program.schema_name, want_schema) and std.mem.eql(u8, program.name, want_name)) break program;
    } else return error.UnknownBuildProgram;
    const action_name = if (std.mem.eql(u8, want_schema, "public")) want_name else try std.fmt.allocPrint(self.a, "{s}.{s}", .{ want_schema, want_name });
    if (program.control.state != .active and program.control.state != .suspended and program.control.state != .retired) return error.InvalidDataflowTransition;
    try self.actions.append(self.a, .{ .expectation = .{ .workflow = .{ .name = action_name, .completed = value.completed, .refused = value.refused, .observations = value.observations } }, .location = locationSpan(self.graph.sources[file], .{ .start = span.start, .end = span.end }) });
}
pub const BoundedBuffer = struct {
    allocator: std.mem.Allocator,
    limit: usize,
    bytes: std.ArrayList(u8) = .empty,
    pub fn len(self: BoundedBuffer) usize {
        return self.bytes.items.len;
    }
    pub fn writeByte(self: *BoundedBuffer, byte: u8) !void {
        if (self.bytes.items.len == self.limit) return error.BuildStatementLimit;
        try self.bytes.append(self.allocator, byte);
    }
    pub fn writeAll(self: *BoundedBuffer, slice: []const u8) !void {
        if (slice.len > self.limit - self.bytes.items.len) return error.BuildStatementLimit;
        try self.bytes.appendSlice(self.allocator, slice);
    }
    pub fn print(self: BoundedBuffer_Ptr, comptime fmt: []const u8, args: anytype) !void {
        var buf: [64]u8 = undefined;
        try self.writeAll(std.fmt.bufPrint(&buf, fmt, args) catch unreachable);
    }
    const BoundedBuffer_Ptr = *BoundedBuffer;
};
fn isResourcePosition(text: []const u8, tokens: []const s.Token, i: usize) bool {
    if (i == 3 and tokenIs(text, tokens[0], "CREATE") and tokenIs(text, tokens[1], "PUBLIC") and
        (tokenIs(text, tokens[2], "TABLE") or tokenIs(text, tokens[2], "STREAM") or tokenIs(text, tokens[2], "QUEUE")))
        return true;
    if (i == 1 and tokenIs(text, tokens[0], "UPDATE")) return true;
    if (i >= 1 and (tokenIs(text, tokens[i - 1], "REFERENCES") or tokenIs(text, tokens[i - 1], "INTO") or
        tokenIs(text, tokens[i - 1], "FROM") or tokenIs(text, tokens[i - 1], "DATAFLOW")))
        return true;
    return false;
}
fn expand(text: []const u8, tokens: []const s.Token, bindings: []const Binding, schemas: []const types.SchemaBinding, buffer_allocator: std.mem.Allocator, limit: usize, canonical: bool, type_sites: ?*std.ArrayList(usize), allocator: std.mem.Allocator, sites: ?*std.ArrayList(Operands.Site), origins: ?*std.ArrayList(Origin)) ![]const u8 {
    if (tokens.len == 0) return error.InvalidSourceSyntax;
    var writer: BoundedBuffer = .{ .allocator = buffer_allocator, .limit = limit };
    var i: usize = 0;
    var parameter: usize = 0;
    const create_schema = tokens.len >= 2 and tokenIs(text, tokens[0], "CREATE") and tokenIs(text, tokens[1], "SCHEMA");
    if (tokenIs(text, tokens[0], "CREATE") and !create_schema) {
        if (tokens.len < 4 or !tokenIs(text, tokens[1], "PUBLIC")) return error.RuntimePrivateOrUnsupportedDeclaration;
    }
    while (i < tokens.len) : (i += 1) {
        if (i == 1 and tokenIs(text, tokens[0], "CREATE") and !create_schema) continue;
        const token = tokens[i];
        const raw = text[token.start..token.end];
        const joined = s.Template.joinsLexeme(text, tokens, i);
        if (writer.len() != 0 and !joined) try writer.writeByte(' ');
        const origin_start = writer.len();
        if (token.kind == .symbol and std.mem.eql(u8, raw, "$")) {
            i += 1;
            if (i == tokens.len or tokens[i].kind != .word) return error.InvalidSourceOperand;
            const name = text[tokens[i].start..tokens[i].end];
            const value = for (bindings) |binding| {
                if (std.ascii.eqlIgnoreCase(name, binding.name)) break binding.value;
            } else return error.UnknownSourceOperand;
            if (value == .type) if (type_sites) |type_positions| {
                try type_positions.append(buffer_allocator, writer.len());
            };
            const start = writer.len();
            if (value == .symbolic or (!canonical and value == .nominal)) {
                parameter += 1;
                try writer.print("${d}", .{parameter});
            } else try writeValue(&writer, value);
            if (sites) |record| try record.append(allocator, .{ .start = start, .end = writer.len(), .value = value });
        } else if (create_schema and i == 2 and token.kind == .word and hasSchemaBinding(schemas, raw)) {
            try quoted(&writer, resolveSchemaName(schemas, raw), '"');
        } else if (isResourcePosition(text, tokens, i) and i + 2 < tokens.len and tokens[i + 1].kind == .symbol and std.mem.eql(u8, text[tokens[i + 1].start..tokens[i + 1].end], ".") and token.kind == .word and hasSchemaBinding(schemas, raw)) {
            try quoted(&writer, resolveSchemaName(schemas, raw), '"');
        } else if (isResourcePosition(text, tokens, i) and !(i + 1 < tokens.len and tokens[i + 1].kind == .symbol and std.mem.eql(u8, text[tokens[i + 1].start..tokens[i + 1].end], ".")) and token.kind == .word and !tokenIs(text, tokens[0], "CREATE")) {
            var rewritten = false;
            for (bindings) |b| if (std.ascii.eqlIgnoreCase(raw, b.name)) {
                switch (b.value) {
                    .table, .stream, .queue => |tbl| if (!std.mem.eql(u8, tbl.schema_name, "public")) {
                        try writeValue(&writer, b.value);
                        rewritten = true;
                        break;
                    },
                    .reference_table => |ref_tbl| if (i >= 1 and tokenIs(text, tokens[i - 1], "REFERENCES")) {
                        if (!std.mem.eql(u8, ref_tbl.table.schema_name, "public")) {
                            try quoted(&writer, ref_tbl.table.schema_name, '"');
                            try writer.writeByte('.');
                        }
                        try quoted(&writer, ref_tbl.table.name, '"');
                        rewritten = true;
                        break;
                    },
                    else => {},
                }
            };
            if (!rewritten) {
                if (canonical and !s.Template.numericWord(text, token)) {
                    for (raw) |byte| try writer.writeByte(std.ascii.toUpper(byte));
                } else try writer.writeAll(raw);
            }
        } else if (canonical and token.kind == .word and !s.Template.numericWord(text, token)) {
            for (raw) |byte| try writer.writeByte(std.ascii.toUpper(byte));
        } else try writer.writeAll(raw);
        if (origins) |map| try map.append(allocator, .{ .start = origin_start, .end = writer.len(), .source = token.start });
    }
    return writer.bytes.items;
}
fn tokenEndAt(text: []const u8, offset: usize) usize {
    if (offset >= text.len) return offset;
    var scan = f.SqlInput.CompilerScan.init(text[offset..]) catch return offset;
    const first = (scan.next() catch null) orelse return offset;
    if (first.start != 0) return offset;
    if (first.kind == .symbol and first.end == 1 and text[offset] == '$') {
        if (scan.next() catch null) |second| {
            if (second.start == 1 and second.kind == .word) return offset + second.end;
        }
    }
    return offset + first.end;
}
fn tokenIs(text: []const u8, token: s.Token, word: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(text[token.start..token.end], word);
}
pub fn quoted(writer: *BoundedBuffer, text: []const u8, quote: u8) !void {
    try writer.writeByte(quote);
    for (text) |byte| {
        try writer.writeByte(byte);
        if (byte == quote) try writer.writeByte(quote);
    }
    try writer.writeByte(quote);
}
pub fn writeValue(writer: *BoundedBuffer, value: Value) !void {
    switch (value) {
        .integer => |number| try writer.print("{d}", .{number}),
        .boolean => |boolean| try writer.writeAll(if (boolean) "TRUE" else "FALSE"),
        .text => |text| try quoted(writer, text, '\''),
        .uuid => |v| {
            try writer.writeAll("UUID ");
            try quoted(writer, v, '\'');
        },
        .timestamptz => |v| {
            try writer.writeAll("TIMESTAMP ");
            try quoted(writer, v, '\'');
        },
        .binary => |v| {
            try writer.writeAll("X");
            try quoted(writer, v, '\'');
        },
        .identifier => |name| try quoted(writer, name, '"'),
        .type => |kind| try writer.writeAll(switch (kind.base) {
            .bigint => "BIGINT",
            .text => "TEXT",
            .boolean => "BOOLEAN",
            .uuid => "UUID",
            .timestamptz => "TIMESTAMPTZ",
            .binary => "BINARY",
        }),
        .nominal => |v| switch (v.value) {
            inline else => |payload, tag| try writeValue(writer, @unionInit(Value, @tagName(tag), payload)),
        },
        .table, .stream, .queue => |table| {
            if (!std.mem.eql(u8, table.schema_name, "public")) {
                try quoted(writer, table.schema_name, '"');
                try writer.writeByte('.');
            }
            try quoted(writer, table.name, '"');
        },
        .reference_table => return error.ReferenceOnlyTableAccess,
        .symbolic => return error.UnsupportedSymbolicSchema,
        .variant, .instance, .row, .schema_binding, .helper => return error.InvalidSourceOperand,
        .module => return error.ModuleIsNotSqlOperand,
    }
}
pub fn location(source: Graph.Source, offset: usize) p.Diagnostic.Location {
    return locationSpan(source, .{ .start = @intCast(@min(offset, std.math.maxInt(u32))), .end = @intCast(@min(offset, std.math.maxInt(u32))) });
}
pub fn locationSpan(source: Graph.Source, span: SourceDiagnostic.Span) p.Diagnostic.Location {
    const position = @min(@as(usize, span.start), source.text.len);
    const end_pos = @min(@max(position, @as(usize, span.end)), source.text.len);
    var line: u64 = 1;
    var start: usize = 0;
    for (source.text[0..position], 0..) |byte, i| if (byte == '\n') {
        line += 1;
        start = i + 1;
    };
    var path: [600]u8 = undefined;
    const name = std.fmt.bufPrint(&path, "{s}/{s}", .{ source.package, source.path }) catch source.path;
    var result: p.Diagnostic.Location = .{ .offset = .init(position), .length = .init(end_pos - position), .line = .init(line), .byte_column = .init(position - start + 1) };
    const source_path = p.Diagnostic.SourcePath.init(name) catch unreachable;
    source_path.apply(&result);
    return result;
}
pub fn project(err: anyerror, at: ?p.Diagnostic.Location, call: ?p.Diagnostic.Location, instance: ?[]const u8) p.Diagnostic {
    return @import("SourceDiagnostic.zig").project(err, at, call, instance);
}

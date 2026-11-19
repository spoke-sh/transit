//! Lower pure functions, ordered guards and inline atomic procedures into
//! canonical public-data Queue program SQL before Fuze binding and erasure.
const std = @import("std");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
const s = @import("Syntax.zig");
const Graph = @import("Graph.zig");
const Catalog = @import("WorkingCatalog.zig");
const Compiler = @import("Compiler.zig");
const types = @import("SourceTypes.zig");
const Operands = @import("TypedOperands.zig");
const Annotations = @import("ProgramAnnotations.zig");
const ProgramCheck = @import("ProgramCheck.zig");

const CallOrigin = Operands.CallOrigin;
const Symbol = struct { original: []const u8, emitted: []const u8 };
const ResourceBinding = struct { name: []const u8, table: *const types.Table };
const ResolvedCallee = struct {
    ref: Graph.Ref,
    bindings: []const types.Binding = &.{},
    owner: usize = 0,
    schemas: []const types.SchemaBinding = &.{},
};

const ArgClosure = struct {
    file: usize,
    tokens: []const s.Token,
    env: *const Env,
    call: ?CallOrigin,
};

const FnParam = struct {
    name: []const u8,
    expected: Annotations.Expected,
    closure: ArgClosure,
    hoisted: ?[]const u8 = null,
};

const RowFieldVar = struct { name: []const u8, emitted: []const u8 };
const RowVar = struct { original: []const u8, fields: []const RowFieldVar };

const Env = struct {
    file: usize,
    helper: ?Graph.Ref = null,
    mode: enum { dataflow, function, guard, procedure } = .dataflow,
    rename_locals: bool = false,
    return_binding: ?[]const u8 = null,
    owner: usize = 0,
    schemas: []const types.SchemaBinding = &.{},
    bindings: []const types.Binding = &.{},
    symbols: std.ArrayList(Symbol) = .empty,
    row_vars: []const RowVar = &.{},
    resources: []const ResourceBinding = &.{},
    fn_params: []const FnParam = &.{},
    call: ?CallOrigin = null,
};

const Hoisted = struct {
    writer: Compiler.BoundedBuffer,
    sites: std.ArrayList(Operands.Site) = .empty,
    origins: std.ArrayList(Operands.Origin) = .empty,
    obligations: std.ArrayList(Annotations.Obligation) = .empty,
};

const Self = @This();
compiler: *Compiler,
catalog: *Catalog,
scratch: std.mem.Allocator,
output: std.mem.Allocator,
writer: Compiler.BoundedBuffer,
sites: *std.ArrayList(Operands.Site),
origins: *std.ArrayList(Operands.Origin),
obligations: *std.ArrayList(Annotations.Obligation),
next_id: usize = 0,
in_queue_predicate: bool = false,
queue_name: []const u8 = "",
input_emitted: []const u8 = "",
hoist: ?*Hoisted = null,

pub fn validateAll(compiler: *Compiler) !void {
    const graph = compiler.graph;
    for (graph.files, 0..) |file, file_idx| for (file.definitions) |def| {
        if (def.kind != .function and def.kind != .guard and def.kind != .procedure) continue;
        try compiler.tick();
        compiler.file = file_idx;
        compiler.offset = def.span.start;
        compiler.context = .{ .name = def.name };
        for (def.parameters) |param| {
            compiler.context = .{ .name = param.name };
            switch (param.kind) {
                .integer, .text, .boolean, .uuid, .timestamptz, .binary => {},
                .named => |name| {
                    const ref = try graph.resolve(file_idx, name);
                    if (graph.getDefinition(ref).kind != .domain) return error.InvalidParameterType;
                },
                .row => |fields| try validateHelperRowFields(graph, file_idx, fields, 0),
                .table => |cols| {
                    if (def.kind == .function) return error.InvalidParameterType;
                    try validateSignatureColumns(graph, file_idx, cols, .table);
                },
                .stream => |cols| {
                    if (def.kind != .procedure) return error.InvalidParameterType;
                    try validateSignatureColumns(graph, file_idx, cols, .stream);
                },
                .queue => |cols| {
                    if (def.kind != .procedure) return error.InvalidParameterType;
                    try validateSignatureColumns(graph, file_idx, cols, .queue);
                },
                .identifier, .type, .schema_binding, .module, .module_of => return error.InvalidParameterType,
            }
        }
        if (def.return_type) |return_type| {
            compiler.context = .{ .name = def.name };
            _ = try types.resolve(graph, file_idx, return_type);
        }
        compiler.context = .{};
    };

    var total_defs: usize = 0;
    const base_offsets = try compiler.a.alloc(usize, graph.files.len);
    for (graph.files, 0..) |file, i| {
        base_offsets[i] = total_defs;
        total_defs += file.definitions.len;
    }
    const visited = try compiler.a.alloc(u8, total_defs);
    const heights = try compiler.a.alloc(usize, total_defs);
    @memset(visited, 0);
    @memset(heights, 0);
    for (graph.files, 0..) |file, file_idx| {
        if (file_idx < graph.is_fragment.len and graph.is_fragment[file_idx]) continue;
        for (file.definitions, 0..) |def, def_idx| {
            if (def.kind != .function and def.kind != .guard and def.kind != .procedure) continue;
            _ = try visitCallGraph(compiler, base_offsets, visited, heights, .{ .ref = .{ .file = file_idx, .definition = def_idx } }, 0);
        }
    }

    for (graph.files, 0..) |file, file_idx| {
        if (file_idx < graph.is_fragment.len and graph.is_fragment[file_idx]) continue;
        for (file.definitions, 0..) |def, def_idx| {
            if (def.kind != .function and def.kind != .guard and def.kind != .procedure) continue;
            try validateHelperBody(compiler, .{ .file = file_idx, .definition = def_idx }, &.{});
        }
    }
    compiler.context = .{};
}

pub fn validateFragmentCallGraph(compiler: *Compiler, frag_file: usize, bindings: []const types.Binding) !void {
    const graph = compiler.graph;
    const defs = graph.files[frag_file].definitions;
    var has_helper = false;
    for (defs) |def| if (def.kind == .function or def.kind == .guard or def.kind == .procedure) {
        has_helper = true;
        break;
    };
    if (!has_helper) return;

    var total_defs: usize = 0;
    const base_offsets = try compiler.a.alloc(usize, graph.files.len);
    for (graph.files, 0..) |file, i| {
        base_offsets[i] = total_defs;
        total_defs += file.definitions.len;
    }
    const visited = try compiler.a.alloc(u8, total_defs);
    const heights = try compiler.a.alloc(usize, total_defs);
    @memset(visited, 0);
    @memset(heights, 0);
    for (defs, 0..) |def, def_idx| {
        if (def.kind != .function and def.kind != .guard and def.kind != .procedure) continue;
        _ = try visitCallGraph(compiler, base_offsets, visited, heights, .{ .ref = .{ .file = frag_file, .definition = def_idx }, .bindings = bindings, .owner = compiler.owner, .schemas = compiler.activeSchemas() }, 0);
    }
    compiler.context = .{};
}

pub fn validateFragmentBodies(compiler: *Compiler, frag_file: usize, bindings: []const types.Binding) !void {
    const defs = compiler.graph.files[frag_file].definitions;
    for (defs, 0..) |def, def_idx| {
        if (def.kind != .function and def.kind != .guard and def.kind != .procedure) continue;
        try validateHelperBody(compiler, .{ .file = frag_file, .definition = def_idx }, bindings);
    }
    compiler.context = .{};
}

fn validateHelperRowFields(graph: Graph, file: usize, fields: []const s.Parameter, depth: usize) anyerror!void {
    if (depth >= 16) return error.SourceDepthLimit;
    for (fields) |field| {
        switch (field.kind) {
            .integer, .text, .boolean, .uuid, .timestamptz, .binary => {},
            .named => |name| {
                const ref = try graph.resolve(file, name);
                if (graph.getDefinition(ref).kind != .domain) return error.InvalidParameterType;
            },
            .row => |nested| try validateHelperRowFields(graph, file, nested, depth + 1),
            else => return error.InvalidParameterType,
        }
    }
}

const HelperRowParam = struct {
    typ: f.Types.Type,
    domains: []const types.FieldDomain,
    expected: Annotations.Expected,
};

fn buildHelperRowParam(scratch: std.mem.Allocator, out_alloc: std.mem.Allocator, graph: Graph, file: usize, fields: []const s.Parameter, depth: usize) anyerror!HelperRowParam {
    if (depth >= 16) return error.SourceDepthLimit;
    const struct_fields = try scratch.alloc(f.Types.Field, fields.len);
    const domain_fields = try scratch.alloc(types.FieldDomain, fields.len);
    const expected_fields = try out_alloc.alloc(Annotations.RowField, fields.len);
    for (fields, 0..) |field, idx| {
        switch (field.kind) {
            .integer, .text, .boolean, .uuid, .timestamptz, .binary, .named => {
                const scalar_ty = try parameterScalar(graph, file, field.kind);
                struct_fields[idx] = .{ .name = field.name, .type = scalar_ty.physical(), .nullable = false };
                domain_fields[idx] = .{ .name = field.name, .domain = scalar_ty.domain };
                expected_fields[idx] = .{ .name = field.name, .expected = .{ .scalar = scalar_ty } };
            },
            .row => |nested| {
                const sub = try buildHelperRowParam(scratch, out_alloc, graph, file, nested, depth + 1);
                struct_fields[idx] = .{ .name = field.name, .type = sub.typ, .nullable = true };
                domain_fields[idx] = .{ .name = field.name, .fields = sub.domains };
                expected_fields[idx] = .{ .name = field.name, .expected = sub.expected };
            },
            else => return error.InvalidParameterType,
        }
    }
    return .{
        .typ = .{ .structure = struct_fields },
        .domains = domain_fields,
        .expected = .{ .row = expected_fields },
    };
}

fn validateSignatureColumns(graph: Graph, file: usize, cols: []const s.Column, kind: types.ResourceKind) !void {
    for (cols) |col| {
        const ty = try types.resolve(graph, file, col.type);
        if (ty.domain != null and col.nullable) return error.UnsupportedNominalColumn;
        if (kind != .table and col.primary) return error.InvalidParameterType;
        const collation = std.meta.stringToEnum(f.TableSchema.Collation, col.collation) orelse return error.InvalidParameterType;
        const schema_col: f.TableSchema.Column = .{ .id = 1, .name = col.name, .type = ty.physical(), .nullable = col.nullable, .collation = collation };
        schema_col.validateEncodingAndCollation() catch return error.InvalidParameterType;
    }
}

fn buildSyntheticTable(scratch: std.mem.Allocator, graph: Graph, file: usize, object_id: u64, name: []const u8, cols: []const s.Column, kind: types.ResourceKind) !*const types.Table {
    const schema_cols = try scratch.alloc(f.TableSchema.Column, cols.len);
    const domains = try scratch.alloc(?Graph.Ref, cols.len);
    var pks: std.ArrayList(f.TableSchema.ColumnId) = .empty;
    for (cols, 0..) |col, idx| {
        const ty = try types.resolve(graph, file, col.type);
        const collation = std.meta.stringToEnum(f.TableSchema.Collation, col.collation) orelse return error.InvalidParameterType;
        schema_cols[idx] = .{
            .id = idx + 1,
            .name = col.name,
            .type = ty.physical(),
            .nullable = col.nullable,
            .collation = collation,
        };
        domains[idx] = ty.domain;
        if (col.primary) try pks.append(scratch, idx + 1);
    }
    const schema: f.TableSchema.Schema = .{
        .object = object_id,
        .revision = 1,
        .next_column = cols.len + 1,
        .columns = schema_cols,
        .primary_key = try pks.toOwnedSlice(scratch),
    };
    try schema.validate();
    const log_cfg: ?f.LogDdl.Configured = switch (kind) {
        .table => null,
        .stream => .{ .configuration = f.LogDdl.defaults(.stream), .limits = f.LogDdl.default_limits },
        .queue => .{ .configuration = f.LogDdl.defaults(.queue), .limits = f.LogDdl.default_limits },
    };
    const entry = try scratch.create(types.Table);
    entry.* = .{
        .name = name,
        .schema = schema,
        .domains = domains,
        .owner = 0,
        .kind = kind,
        .log = log_cfg,
    };
    return entry;
}

fn visitCallGraph(compiler: *Compiler, base_offsets: []const usize, visited: []u8, heights: []usize, current: ResolvedCallee, depth: usize) anyerror!usize {
    try compiler.tick();
    const ref = current.ref;
    const node = base_offsets[ref.file] + ref.definition;
    const def = compiler.graph.getDefinition(ref);
    if (visited[node] == 1) return error.RecursiveSourceCall;
    if (visited[node] == 2) {
        if (depth + heights[node] > compiler.limits.depth) {
            compiler.file = ref.file;
            compiler.offset = def.span.start;
            return error.SourceDepthLimit;
        }
        return heights[node];
    }
    if (depth >= compiler.limits.depth) {
        compiler.file = ref.file;
        compiler.offset = def.span.start;
        return error.SourceDepthLimit;
    }
    visited[node] = 1;
    var height: usize = 1;
    const text = compiler.graph.sources[ref.file].text;
    const tokens = def.program.?.tokens;
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        if (def.kind != .function and tokenWord(text, tokens[i], "CHECK") and i + 1 < tokens.len and tokenWord(text, tokens[i + 1], "GUARD")) {
            const call_offset = tokens[i].start;
            i += 2;
            const target = try parseCalleeRef(compiler, ref.file, current.bindings, current.schemas, text, tokens, &i, .guard, call_offset);
            height = @max(height, 1 + (visitCallGraph(compiler, base_offsets, visited, heights, target, depth + 1) catch |err| {
                if (err == error.RecursiveSourceCall) {
                    compiler.file = ref.file;
                    compiler.offset = call_offset;
                }
                return err;
            }));
            continue;
        }
        if (def.kind == .procedure and tokenWord(text, tokens[i], "CALL") and i + 1 < tokens.len and tokens[i + 1].kind == .word) {
            const next_after_name = if (i + 3 < tokens.len and tokenSymbol(text, tokens[i + 2], '.')) i + 4 else i + 2;
            if (next_after_name < tokens.len and tokenSymbol(text, tokens[next_after_name], '(')) {
                const call_offset = tokens[i].start;
                i += 1;
                const target = try parseCalleeRef(compiler, ref.file, current.bindings, current.schemas, text, tokens, &i, .procedure, call_offset);
                height = @max(height, 1 + (visitCallGraph(compiler, base_offsets, visited, heights, target, depth + 1) catch |err| {
                    if (err == error.RecursiveSourceCall) {
                        compiler.file = ref.file;
                        compiler.offset = call_offset;
                    }
                    return err;
                }));
                continue;
            }
        }
        const preceded_by_dot = i > 0 and tokenSymbol(text, tokens[i - 1], '.');
        if (!preceded_by_dot and i + 3 < tokens.len and (tokens[i].kind == .word or tokens[i].kind == .quoted) and
            tokenSymbol(text, tokens[i + 1], '.') and (tokens[i + 2].kind == .word or tokens[i + 2].kind == .quoted) and tokenSymbol(text, tokens[i + 3], '('))
        {
            const call_offset = tokens[i].start;
            var cursor = i;
            const target = try resolveQualifiedFunction(compiler, ref.file, current.bindings, current.schemas, text, tokens, &cursor, call_offset);
            i = cursor - 1;
            height = @max(height, 1 + (visitCallGraph(compiler, base_offsets, visited, heights, target, depth + 1) catch |err| {
                if (err == error.RecursiveSourceCall) {
                    compiler.file = ref.file;
                    compiler.offset = call_offset;
                }
                return err;
            }));
            continue;
        }
        if (!preceded_by_dot and i + 1 < tokens.len and tokens[i].kind == .word and tokenSymbol(text, tokens[i + 1], '(')) {
            const raw = text[tokens[i].start..tokens[i].end];
            if (!std.ascii.eqlIgnoreCase(raw, "ROW") and !std.ascii.eqlIgnoreCase(raw, "CAST")) {
                if (try resolveLocalFunction(compiler, ref.file, current.bindings, raw, tokens[i].start)) |target| {
                    const call_offset = tokens[i].start;
                    height = @max(height, 1 + (visitCallGraph(compiler, base_offsets, visited, heights, target, depth + 1) catch |err| {
                        if (err == error.RecursiveSourceCall) {
                            compiler.file = ref.file;
                            compiler.offset = call_offset;
                        }
                        return err;
                    }));
                }
            }
        }
    }
    visited[node] = 2;
    heights[node] = height;
    return height;
}

fn validateHelperBody(compiler: *Compiler, ref: Graph.Ref, bindings: []const types.Binding) !void {
    if (!compiler.scratch.reset(.retain_capacity)) return error.OutOfMemory;
    const scratch = compiler.scratch.allocator();
    const graph = compiler.graph;
    const def = graph.getDefinition(ref);
    compiler.file = ref.file;
    compiler.offset = def.span.start;
    compiler.call_site = null;
    compiler.context = .{};

    var temp_catalog: Catalog = .{ .output = scratch, .scratch = scratch };
    try temp_catalog.schemas.appendSlice(scratch, compiler.catalog.schemas.items);
    try temp_catalog.entries.appendSlice(scratch, compiler.catalog.entries.items);
    var in_cols: std.ArrayList(f.TableSchema.Column) = .empty;
    var in_domains: std.ArrayList(?Graph.Ref) = .empty;
    var in_nested: std.ArrayList([]const types.FieldDomain) = .empty;
    var res_bindings: std.ArrayList(ResourceBinding) = .empty;
    var object_id: u64 = compiler.catalog.entries.items.len + 2;

    for (def.parameters) |param| {
        switch (param.kind) {
            .integer, .text, .boolean, .uuid, .timestamptz, .binary, .named => {
                const scalar_ty = try parameterScalar(graph, ref.file, param.kind);
                try in_cols.append(scratch, .{
                    .id = in_cols.items.len + 1,
                    .name = param.name,
                    .type = scalar_ty.physical(),
                    .nullable = false,
                });
                try in_domains.append(scratch, scalar_ty.domain);
                try in_nested.append(scratch, &.{});
            },
            .row => |fields| {
                const row_param = try buildHelperRowParam(scratch, scratch, graph, ref.file, fields, 0);
                try in_cols.append(scratch, .{
                    .id = in_cols.items.len + 1,
                    .name = param.name,
                    .type = row_param.typ,
                    .nullable = true,
                });
                try in_domains.append(scratch, null);
                try in_nested.append(scratch, row_param.domains);
            },
            inline .table, .stream, .queue => |cols, tag| {
                const synth_name = try std.fmt.allocPrint(scratch, "__transit$tbl_{s}", .{param.name});
                const table = try buildSyntheticTable(scratch, graph, ref.file, object_id, synth_name, cols, switch (tag) {
                    .table => .table,
                    .stream => .stream,
                    .queue => .queue,
                    else => unreachable,
                });
                object_id += 1;
                try temp_catalog.entries.append(scratch, table);
                try res_bindings.append(scratch, .{ .name = param.name, .table = table });
            },
            else => unreachable,
        }
    }
    if (in_cols.items.len == 0) {
        try in_cols.append(scratch, .{ .id = 1, .name = "__unused", .type = .int64, .nullable = false });
        try in_domains.append(scratch, null);
        try in_nested.append(scratch, &.{});
    }
    const queue_schema: f.TableSchema.Schema = .{
        .object = 1,
        .revision = 1,
        .next_column = in_cols.items.len + 1,
        .columns = try in_cols.toOwnedSlice(scratch),
    };
    try queue_schema.validate();
    const queue_entry = try scratch.create(types.Table);
    queue_entry.* = .{
        .name = "__transit$in",
        .schema = queue_schema,
        .domains = try in_domains.toOwnedSlice(scratch),
        .nested_domains = try in_nested.toOwnedSlice(scratch),
        .owner = 0,
        .kind = .queue,
        .log = .{ .configuration = f.LogDdl.defaults(.queue), .limits = f.LogDdl.default_limits },
    };
    try temp_catalog.entries.append(scratch, queue_entry);

    var sites: std.ArrayList(Operands.Site) = .empty;
    var origins: std.ArrayList(Operands.Origin) = .empty;
    var obligations: std.ArrayList(Annotations.Obligation) = .empty;

    var lowerer: Self = .{
        .compiler = compiler,
        .catalog = &temp_catalog,
        .scratch = scratch,
        .output = scratch,
        .writer = .{ .allocator = scratch, .limit = f.ApplicationProgram.max_source_bytes },
        .sites = &sites,
        .origins = &origins,
        .obligations = &obligations,
        .queue_name = "__transit$in",
        .input_emitted = "\"__transit$req\"",
    };

    const origin_base: Operands.Origin = .{ .start = 0, .end = 0, .source = def.span.start, .file = ref.file };
    try lowerer.emitFixed("CREATE DATAFLOW \"__transit$check\" FROM QUEUE \"__transit$in\" AS \"__transit$req\" AS BEGIN", origin_base);

    var env: Env = .{
        .file = ref.file,
        .helper = ref,
        .mode = switch (def.kind) {
            .function => .function,
            .guard => .guard,
            .procedure => .procedure,
            else => unreachable,
        },
        .rename_locals = true,
        .owner = compiler.owner,
        .schemas = compiler.activeSchemas(),
        .bindings = bindings,
        .resources = res_bindings.items,
    };
    for (def.parameters) |param| {
        switch (param.kind) {
            .integer, .text, .boolean, .uuid, .timestamptz, .binary, .named, .row => {
                const hygienic = try lowerer.freshHygienic(param.name);
                try env.symbols.append(scratch, .{ .original = param.name, .emitted = hygienic });
                try lowerer.emitFixed("LET", origin_base);
                try lowerer.emitQuotedRaw(hygienic, origin_base);
                try lowerer.emitFixed("= \"__transit$req\" .", origin_base);
                try lowerer.emitQuotedIdentifier(param.name, origin_base);
                try lowerer.emitFixed(";", origin_base);
            },
            else => {},
        }
    }

    const body_tokens = def.program.?.tokens;
    switch (def.kind) {
        .function => {
            const ret_scalar = try types.resolve(graph, ref.file, def.return_type.?);
            const ret_var = try lowerer.freshHygienic("ret");
            try lowerer.emitFixed("LET", origin_base);
            try lowerer.emitQuotedRaw(ret_var, origin_base);
            try lowerer.emitFixed("=", origin_base);
            var idx: usize = 1;
            const expr_tokens = body_tokens[0 .. body_tokens.len - 1];
            try lowerer.lowerExpression(&env, expr_tokens, &idx, 0, false, 0);
            try lowerer.emitFixed(";", origin_base);
            try obligations.append(scratch, .{
                .target = .{ .binding = ret_var },
                .expected = .{ .scalar = ret_scalar },
                .name = def.name,
            });
        },
        .guard => {
            try lowerer.lowerGuardProgram(&env, def.program.?, 0);
        },
        .procedure => {
            if (def.return_type != null) env.return_binding = try lowerer.freshHygienic("ret");
            try lowerer.emitFixed("BEGIN ATOMIC", origin_base);
            var idx: usize = 0;
            try lowerer.lowerBlock(&env, body_tokens, &idx, true, 0);
            try lowerer.emitFixed("END ;", origin_base);
        },
        else => unreachable,
    }
    try lowerer.emitFixed("END", origin_base);

    const sql = lowerer.writer.bytes.items;
    var at: f.Sql.Location = .{ .offset = std.math.maxInt(usize) };
    const check_fn = struct {
        fn run(comp: *Compiler, cat: *Catalog, raw_sql: []const u8, loc: *f.Sql.Location, sc: std.mem.Allocator, st: []const Operands.Site, org: []const Operands.Origin, obs: []const Annotations.Obligation) !void {
            var analysis = try ProgramCheck.analyze(cat, raw_sql, loc);
            defer analysis.deinit();
            _ = try Annotations.check(sc, sc, comp.graph, cat, analysis.parsed.program, &analysis.bound, raw_sql, st, org, obs, &comp.context, &comp.work, comp.limits.work);
        }
    }.run;
    check_fn(compiler, &temp_catalog, sql, &at, scratch, sites.items, origins.items, obligations.items) catch |err| {
        const err_offset = compiler.context.offset orelse at.offset;
        for (origins.items) |origin| if (err_offset >= origin.start and err_offset < origin.end) {
            if (origin.file) |origin_file| compiler.file = origin_file;
            compiler.offset = origin.source;
            if (origin.call) |call| compiler.call_site = Compiler.location(graph.sources[call.file], call.offset);
            break;
        };
        return err;
    };
}

pub fn lowerProgram(
    compiler: *Compiler,
    file: usize,
    tokens: []const s.Token,
    bindings: []const types.Binding,
    scratch: std.mem.Allocator,
    max_statement: usize,
    sites: *std.ArrayList(Operands.Site),
    origins: *std.ArrayList(Operands.Origin),
    obligations: *std.ArrayList(Annotations.Obligation),
) ![]const u8 {
    errdefer origins.clearRetainingCapacity();
    if (tokens.len < 4) return error.InvalidSourceSyntax;
    const text = compiler.graph.sources[file].text;
    if (!tokenWord(text, tokens[0], "CREATE") or !tokenWord(text, tokens[1], "PUBLIC") or !tokenWord(text, tokens[2], "DATAFLOW"))
        return error.RuntimePrivateOrUnsupportedDeclaration;

    const rename_locals = hasHelperCalls(compiler.graph, file, bindings, text, tokens);
    var self: Self = .{
        .compiler = compiler,
        .catalog = &compiler.catalog,
        .scratch = scratch,
        .output = compiler.a,
        .writer = .{ .allocator = scratch, .limit = max_statement },
        .sites = sites,
        .origins = origins,
        .obligations = obligations,
    };
    var env: Env = .{
        .file = file,
        .mode = .dataflow,
        .rename_locals = rename_locals,
        .owner = compiler.owner,
        .schemas = compiler.activeSchemas(),
        .bindings = bindings,
    };

    try self.emitWordToken(&env, tokens[0], "CREATE");
    try self.emitWordToken(&env, tokens[2], "DATAFLOW");
    var i: usize = 3;
    _ = try self.emitResourceOperand(&env, tokens, &i, .identifier);
    try self.requireEmitWord(&env, tokens, &i, "FROM");
    try self.requireEmitWord(&env, tokens, &i, "QUEUE");
    self.queue_name = try self.emitResourceOperand(&env, tokens, &i, .queue);
    try self.requireEmitWord(&env, tokens, &i, "AS");

    const input_tok = tokens[i];
    i += 1;
    const input_decoded = try self.decodeProgramName(text, input_tok);
    if (rename_locals) {
        const hygienic = try self.freshHygienic(input_decoded);
        try env.symbols.append(scratch, .{ .original = input_decoded, .emitted = hygienic });
        try self.emitQuotedRaw(hygienic, self.makeOrigin(&env, input_tok.start));
        self.input_emitted = try std.fmt.allocPrint(scratch, "\"{s}\"", .{hygienic});
    } else {
        try self.emitOriginalToken(&env, text, tokens, i - 1);
        self.input_emitted = text[input_tok.start..input_tok.end];
    }

    if (i < tokens.len and tokenWord(text, tokens[i], "WHERE")) {
        try self.requireEmitWord(&env, tokens, &i, "WHERE");
        self.in_queue_predicate = true;
        defer self.in_queue_predicate = false;
        try self.lowerExpression(&env, tokens, &i, 0, false, 0);
    }

    try self.requireEmitWord(&env, tokens, &i, "AS");
    try self.requireEmitWord(&env, tokens, &i, "BEGIN");
    try self.lowerBlock(&env, tokens, &i, false, 0);
    if (i < tokens.len and tokenWord(text, tokens[i], "ON")) {
        try self.requireEmitWord(&env, tokens, &i, "ON");
        try self.requireEmitWord(&env, tokens, &i, "FAILURE");
        const fail_tok = tokens[i];
        i += 1;
        const fail_decoded = try self.decodeProgramName(text, fail_tok);
        if (rename_locals) {
            env.symbols.shrinkRetainingCapacity(1);
            if (std.mem.eql(u8, env.symbols.items[0].original, fail_decoded)) {
                self.setError(&env, fail_tok.start);
                return error.DuplicateProgramVariable;
            }
            const hygienic = try self.freshHygienic(fail_decoded);
            try env.symbols.append(scratch, .{ .original = fail_decoded, .emitted = hygienic });
            try self.emitQuotedRaw(hygienic, self.makeOrigin(&env, fail_tok.start));
        } else {
            try self.emitOriginalToken(&env, text, tokens, i - 1);
        }
        try self.lowerBlock(&env, tokens, &i, false, 0);
    }
    try self.requireEmitWord(&env, tokens, &i, "END");
    return self.writer.bytes.items;
}

fn hasHelperCalls(graph: Graph, file: usize, bindings: []const types.Binding, text: []const u8, tokens: []const s.Token) bool {
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        if (tokenWord(text, tokens[i], "CHECK") and i + 1 < tokens.len and tokenWord(text, tokens[i + 1], "GUARD")) return true;
        if (tokenWord(text, tokens[i], "CALL") and i + 1 < tokens.len and tokens[i + 1].kind == .word) {
            const after = if (i + 3 < tokens.len and tokenSymbol(text, tokens[i + 2], '.')) i + 4 else i + 2;
            if (after < tokens.len and tokenSymbol(text, tokens[after], '(')) return true;
        }
        const preceded_by_dot = i > 0 and tokenSymbol(text, tokens[i - 1], '.');
        if (!preceded_by_dot and i + 3 < tokens.len and (tokens[i].kind == .word or tokens[i].kind == .quoted) and
            tokenSymbol(text, tokens[i + 1], '.') and (tokens[i + 2].kind == .word or tokens[i + 2].kind == .quoted) and tokenSymbol(text, tokens[i + 3], '('))
            return true;
        if (!preceded_by_dot and i + 1 < tokens.len and tokens[i].kind == .word and tokenSymbol(text, tokens[i + 1], '(')) {
            const raw = text[tokens[i].start..tokens[i].end];
            for (bindings) |b| {
                if (b.value == .helper and std.ascii.eqlIgnoreCase(raw, b.name)) return true;
            }
            for (graph.files[file].definitions) |def| {
                if (std.ascii.eqlIgnoreCase(raw, def.name) and
                    (def.kind == .function or std.meta.stringToEnum(f.ApplicationProgram.Function, def.name) == null))
                    return true;
            }
        }
    }
    return false;
}

fn parameterScalar(graph: Graph, file: usize, kind: s.Kind) !types.Scalar {
    return switch (kind) {
        .integer => .{ .base = .bigint },
        .text => .{ .base = .text },
        .boolean => .{ .base = .boolean },
        .uuid => .{ .base = .uuid },
        .timestamptz => .{ .base = .timestamptz },
        .binary => .{ .base = .binary },
        .named => |name| try types.domain(graph, try graph.resolve(file, name)),
        else => error.InvalidParameterType,
    };
}

fn parameterExpected(scratch: std.mem.Allocator, out_alloc: std.mem.Allocator, graph: Graph, file: usize, kind: s.Kind) !Annotations.Expected {
    return switch (kind) {
        .row => |fields| (try buildHelperRowParam(scratch, out_alloc, graph, file, fields, 0)).expected,
        else => .{ .scalar = try parameterScalar(graph, file, kind) },
    };
}

fn makeOrigin(self: Self, env: *const Env, source_offset: usize) Operands.Origin {
    _ = self;
    return .{ .start = 0, .end = 0, .source = source_offset, .file = env.file, .call = env.call };
}

fn setError(self: *Self, env: *const Env, source_offset: usize) void {
    self.compiler.file = env.file;
    self.compiler.offset = source_offset;
    if (env.call) |call| self.compiler.call_site = Compiler.location(self.compiler.graph.sources[call.file], call.offset);
}

fn freshHygienic(self: *Self, base: []const u8) ![]const u8 {
    self.next_id += 1;
    const capped = if (base.len > 63) base[0..63] else base;
    return std.fmt.allocPrint(self.scratch, "__t${d}_{s}", .{ self.next_id, capped });
}

fn emitFixed(self: *Self, text: []const u8, origin: Operands.Origin) !void {
    if (self.writer.len() != 0) try self.writer.writeByte(' ');
    const start = self.writer.len();
    try self.writer.writeAll(text);
    var rec = origin;
    rec.start = start;
    rec.end = self.writer.len();
    try self.origins.append(self.output, rec);
}

fn emitQuotedRaw(self: *Self, raw_ident: []const u8, origin: Operands.Origin) !void {
    if (self.writer.len() != 0) try self.writer.writeByte(' ');
    const start = self.writer.len();
    try Compiler.quoted(&self.writer, raw_ident, '"');
    var rec = origin;
    rec.start = start;
    rec.end = self.writer.len();
    try self.origins.append(self.output, rec);
}

fn emitQuotedIdentifier(self: *Self, ident: []const u8, origin: Operands.Origin) !void {
    return self.emitQuotedRaw(ident, origin);
}

fn emitWordToken(self: *Self, env: *const Env, tok: s.Token, word: []const u8) !void {
    try self.emitFixed(word, self.makeOrigin(env, tok.start));
}

fn requireEmitWord(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, word: []const u8) !void {
    const text = self.compiler.graph.sources[env.file].text;
    if (i.* >= tokens.len or !tokenWord(text, tokens[i.*], word)) {
        self.setError(env, if (i.* < tokens.len) tokens[i.*].start else text.len);
        return error.InvalidSourceSyntax;
    }
    try self.emitWordToken(env, tokens[i.*], word);
    i.* += 1;
}

fn emitOriginalToken(self: *Self, env: *const Env, text: []const u8, tokens: []const s.Token, index: usize) !void {
    const tok = tokens[index];
    const raw = text[tok.start..tok.end];
    const joined = s.Template.joinsLexeme(text, tokens, index);
    if (self.writer.len() != 0 and !joined) try self.writer.writeByte(' ');
    const start = self.writer.len();
    if (tok.kind == .word and !s.Template.numericWord(text, tok)) {
        for (raw) |b| try self.writer.writeByte(std.ascii.toUpper(b));
    } else {
        try self.writer.writeAll(raw);
    }
    var rec = self.makeOrigin(env, tok.start);
    rec.start = start;
    rec.end = self.writer.len();
    try self.origins.append(self.output, rec);
}

fn decodeProgramName(self: *Self, text: []const u8, tok: s.Token) ![]const u8 {
    const raw = text[tok.start..tok.end];
    if (tok.kind == .quoted) {
        var out: std.ArrayList(u8) = .empty;
        var pos: usize = 1;
        while (pos + 1 < raw.len) : (pos += 1) {
            try out.append(self.scratch, raw[pos]);
            if (raw[pos] == '"') pos += 1;
        }
        return out.toOwnedSlice(self.scratch);
    }
    return std.ascii.allocLowerString(self.scratch, raw);
}

const ResourceOperandRole = enum { identifier, table, stream, queue };

fn emitResourceOperand(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, role: ResourceOperandRole) ![]const u8 {
    const text = self.compiler.graph.sources[env.file].text;
    const tok = tokens[i.*];
    if (tokenSymbol(text, tok, '$')) {
        if (i.* + 1 >= tokens.len or tokens[i.* + 1].kind != .word) {
            self.setError(env, tok.start);
            return error.InvalidSourceOperand;
        }
        const name = text[tokens[i.* + 1].start..tokens[i.* + 1].end];
        const value = for (env.bindings) |b| {
            if (std.ascii.eqlIgnoreCase(name, b.name)) break b.value;
        } else {
            self.setError(env, tok.start);
            return error.UnknownSourceOperand;
        };
        i.* += 2;
        if (self.writer.len() != 0) try self.writer.writeByte(' ');
        const start = self.writer.len();
        const resolved_name: []const u8 = switch (value) {
            .identifier => |ident| ident,
            .reference_table => {
                self.setError(env, tok.start);
                return error.ReferenceOnlyTableAccess;
            },
            .table => |tbl| if (role == .table) tbl.name else {
                self.setError(env, tok.start);
                return error.SourceTypeMismatch;
            },
            .stream => |tbl| if (role == .stream) tbl.name else {
                self.setError(env, tok.start);
                return error.SourceTypeMismatch;
            },
            .queue => |tbl| if (role == .queue) tbl.name else {
                self.setError(env, tok.start);
                return error.SourceTypeMismatch;
            },
            else => {
                self.setError(env, tok.start);
                return error.SourceTypeMismatch;
            },
        };
        try Compiler.writeValue(&self.writer, value);
        try self.sites.append(self.output, .{ .start = start, .end = self.writer.len(), .value = value });
        var rec = self.makeOrigin(env, tok.start);
        rec.start = start;
        rec.end = self.writer.len();
        try self.origins.append(self.output, rec);
        return resolved_name;
    }
    const decoded = try self.decodeProgramName(text, tok);
    i.* += 1;
    if (i.* + 1 < tokens.len and tokenSymbol(text, tokens[i.*], '.') and (tokens[i.* + 1].kind == .word or tokens[i.* + 1].kind == .quoted)) {
        const member_tok = tokens[i.* + 1];
        const member_decoded = try self.decodeProgramName(text, member_tok);
        i.* += 2;
        if (role != .identifier) {
            for (env.bindings) |b| if (std.mem.eql(u8, b.name, decoded) and b.value == .instance) {
                for (b.value.instance.exports) |exported| if (std.mem.eql(u8, exported.name, member_decoded)) {
                    const tbl = switch (exported.value) {
                        .reference_table => {
                            self.setError(env, tok.start);
                            return error.ReferenceOnlyTableAccess;
                        },
                        .table => |t_val| if (role == .table) t_val else {
                            self.setError(env, tok.start);
                            return error.SourceTypeMismatch;
                        },
                        .stream => |t_val| if (role == .stream) t_val else {
                            self.setError(env, tok.start);
                            return error.SourceTypeMismatch;
                        },
                        .queue => |t_val| if (role == .queue) t_val else {
                            self.setError(env, tok.start);
                            return error.SourceTypeMismatch;
                        },
                        else => {
                            self.setError(env, tok.start);
                            return error.SourceTypeMismatch;
                        },
                    };
                    try self.emitTableRef(tbl, self.makeOrigin(env, tok.start));
                    return if (std.mem.eql(u8, tbl.schema_name, "public")) tbl.name else try std.fmt.allocPrint(self.scratch, "{s}.{s}", .{ tbl.schema_name, tbl.name });
                };
                self.setError(env, member_tok.start);
                self.compiler.context = .{ .name = member_decoded };
                return error.UnknownSourceExport;
            };
            const concrete = Compiler.resolveSchemaName(env.schemas, decoded);
            const expected_kind: types.ResourceKind = switch (role) {
                .table => .table,
                .stream => .stream,
                .queue => .queue,
                .identifier => unreachable,
            };
            const entry = self.catalog.findResourceQualified(concrete, member_decoded) catch |err| {
                self.setError(env, tok.start);
                return err;
            };
            if (entry.kind != expected_kind) {
                self.setError(env, tok.start);
                return error.SourceTypeMismatch;
            }
            Operands.checkResourceAccess(env.owner, env.bindings, entry, &self.compiler.context) catch |err| {
                self.setError(env, tok.start);
                return err;
            };
            try self.emitTableRef(entry, self.makeOrigin(env, tok.start));
            return if (std.mem.eql(u8, entry.schema_name, "public")) entry.name else try std.fmt.allocPrint(self.scratch, "{s}.{s}", .{ entry.schema_name, entry.name });
        }
        const concrete = Compiler.resolveSchemaName(env.schemas, decoded);
        if (std.mem.eql(u8, concrete, "public")) {
            try self.emitQuotedIdentifier(member_decoded, self.makeOrigin(env, member_tok.start));
            return member_decoded;
        }
        try self.emitQualifiedName(concrete, member_decoded, self.makeOrigin(env, tok.start));
        return try std.fmt.allocPrint(self.scratch, "{s}.{s}", .{ concrete, member_decoded });
    }
    if (env.helper != null and role != .identifier) {
        for (env.resources) |res| if (std.mem.eql(u8, res.name, decoded)) {
            try self.emitTableRef(res.table, self.makeOrigin(env, tok.start));
            return res.table.name;
        };
        for (env.bindings) |b| if (std.mem.eql(u8, b.name, decoded)) {
            switch (b.value) {
                .reference_table => {
                    self.setError(env, tok.start);
                    return error.ReferenceOnlyTableAccess;
                },
                .table => |tbl| if (role == .table) {
                    try self.emitTableRef(tbl, self.makeOrigin(env, tok.start));
                    return tbl.name;
                } else {
                    self.setError(env, tok.start);
                    return error.SourceTypeMismatch;
                },
                .stream => |tbl| if (role == .stream) {
                    try self.emitTableRef(tbl, self.makeOrigin(env, tok.start));
                    return tbl.name;
                } else {
                    self.setError(env, tok.start);
                    return error.SourceTypeMismatch;
                },
                .queue => |tbl| if (role == .queue) {
                    try self.emitTableRef(tbl, self.makeOrigin(env, tok.start));
                    return tbl.name;
                } else {
                    self.setError(env, tok.start);
                    return error.SourceTypeMismatch;
                },
                else => {},
            }
        };
        if (env.owner != 0) {
            if (self.catalog.findResourceQualified("public", decoded) catch null) |entry| {
                const expected_kind: types.ResourceKind = switch (role) {
                    .table => .table,
                    .stream => .stream,
                    .queue => .queue,
                    .identifier => unreachable,
                };
                if (entry.owner == env.owner and entry.kind == expected_kind) {
                    try self.emitTableRef(entry, self.makeOrigin(env, tok.start));
                    return entry.name;
                }
            }
        }
        self.setError(env, tok.start);
        return error.UnknownProgramResource;
    }
    if (role != .identifier) {
        for (env.bindings) |b| if (std.mem.eql(u8, b.name, decoded)) {
            switch (b.value) {
                .reference_table => if ((self.catalog.findResourceQualified("public", decoded) catch null) == null) {
                    self.setError(env, tok.start);
                    return error.ReferenceOnlyTableAccess;
                },
                .table, .stream, .queue => |tbl| if (!std.mem.eql(u8, tbl.schema_name, "public")) {
                    const expected_kind: types.ResourceKind = switch (role) {
                        .table => .table,
                        .stream => .stream,
                        .queue => .queue,
                        .identifier => unreachable,
                    };
                    if (tbl.kind != expected_kind) {
                        self.setError(env, tok.start);
                        return error.SourceTypeMismatch;
                    }
                    try self.emitTableRef(tbl, self.makeOrigin(env, tok.start));
                    return try std.fmt.allocPrint(self.scratch, "{s}.{s}", .{ tbl.schema_name, tbl.name });
                },
                else => {},
            }
        };
        if (self.catalog.findResourceQualified("public", decoded) catch null) |entry| {
            Operands.checkResourceAccess(env.owner, env.bindings, entry, &self.compiler.context) catch |err| {
                self.setError(env, tok.start);
                return err;
            };
        }
    }
    try self.emitOriginalToken(env, text, tokens, i.* - 1);
    return decoded;
}

fn emitQualifiedName(self: *Self, schema_name: []const u8, member: []const u8, origin: Operands.Origin) !void {
    if (self.writer.len() != 0) try self.writer.writeByte(' ');
    const start = self.writer.len();
    try Compiler.quoted(&self.writer, schema_name, '"');
    try self.writer.writeByte('.');
    try Compiler.quoted(&self.writer, member, '"');
    var rec = origin;
    rec.start = start;
    rec.end = self.writer.len();
    try self.origins.append(self.output, rec);
}

fn emitTableRef(self: *Self, table: *const types.Table, origin: Operands.Origin) !void {
    if (!std.mem.eql(u8, table.schema_name, "public")) {
        return self.emitQualifiedName(table.schema_name, table.name, origin);
    }
    return self.emitQuotedIdentifier(table.name, origin);
}

fn lowerGuardProgram(self: *Self, env: *Env, prog: s.Template.Syntax, depth: usize) anyerror!void {
    if (prog.kind == .guard_body) {
        var cursor: usize = 0;
        return self.lowerBlock(env, prog.tokens, &cursor, false, depth);
    }
    const text = self.compiler.graph.sources[env.file].text;
    const tokens = prog.tokens;
    var i: usize = 0;
    while (i < tokens.len) {
        try self.compiler.tick();
        const mark = self.beginHoistScope();
        var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
        self.hoist = &hoisted;
        defer self.hoist = null;
        try self.requireEmitWord(env, tokens, &i, "REQUIRE");
        try self.lowerExpression(env, tokens, &i, 0, true, depth + 1);
        try self.requireEmitWord(env, tokens, &i, "ELSE");
        try self.emitOriginalToken(env, text, tokens, i);
        i += 1;
        try self.emitFixed(";", self.makeOrigin(env, tokens[i - 1].start));
        self.hoist = null;
        try self.applyHoist(mark, &hoisted);
        if (i < tokens.len and tokenSymbol(text, tokens[i], ',')) {
            i += 1;
        } else break;
    }
}

fn lowerBlock(self: *Self, env: *Env, tokens: []const s.Token, i: *usize, atomic: bool, depth: usize) anyerror!void {
    if (depth > self.compiler.limits.depth) return error.SourceDepthLimit;
    const text = self.compiler.graph.sources[env.file].text;
    while (i.* < tokens.len and !tokenWord(text, tokens[i.*], "END") and !tokenWord(text, tokens[i.*], "ELSE") and !tokenWord(text, tokens[i.*], "ON")) {
        try self.compiler.tick();
        const start_tok = tokens[i.*];
        if (tokenWord(text, start_tok, "CHECK")) {
            i.* += 2; // CHECK GUARD
            try self.inlineHelperCall(env, tokens, i, .guard, atomic, start_tok.start, depth + 1, null);
            try self.consumeSemicolon(env, tokens, i);
            continue;
        }
        if (tokenWord(text, start_tok, "CALL")) {
            i.* += 1; // CALL
            try self.inlineHelperCall(env, tokens, i, .procedure, atomic, start_tok.start, depth + 1, null);
            try self.consumeSemicolon(env, tokens, i);
            continue;
        }
        if (tokenWord(text, start_tok, "RETURN")) {
            const binding = env.return_binding orelse return error.UnexpectedProcedureReturn;
            const helper = self.compiler.graph.getDefinition(env.helper orelse return error.UnexpectedProcedureReturn);
            const origin = self.makeOrigin(env, start_tok.start);
            const mark = self.beginHoistScope();
            var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
            self.hoist = &hoisted;
            i.* += 1;
            try self.emitFixed("LET", origin);
            try self.emitQuotedRaw(binding, origin);
            try self.emitFixed("=", origin);
            try self.lowerExpression(env, tokens, i, 0, true, depth + 1);
            try self.requireEmitSymbol(env, tokens, i, ";");
            self.hoist = null;
            try self.applyHoist(mark, &hoisted);
            if (i.* != tokens.len) return error.UnexpectedProcedureReturn;
            try self.obligations.append(self.output, .{
                .target = .{ .binding = binding },
                .expected = .{ .scalar = try types.resolve(self.compiler.graph, env.file, helper.return_type.?) },
                .name = helper.name,
            });
            continue;
        }
        if (tokenWord(text, start_tok, "LET") and i.* + 3 < tokens.len and tokenWord(text, tokens[i.* + 3], "CALL")) {
            const var_tok = tokens[i.* + 1];
            const decoded = try self.decodeProgramName(text, var_tok);
            for (env.symbols.items) |sym| if (std.mem.eql(u8, sym.original, decoded)) {
                self.setError(env, var_tok.start);
                return error.DuplicateProgramVariable;
            };
            const returned = try self.freshHygienic("ret");
            i.* += 4;
            try self.inlineHelperCall(env, tokens, i, .procedure, atomic, start_tok.start, depth + 1, returned);
            try self.consumeSemicolon(env, tokens, i);
            const origin = self.makeOrigin(env, var_tok.start);
            try self.emitFixed("LET", origin);
            const local = if (env.rename_locals) try self.freshHygienic(decoded) else decoded;
            try self.emitQuotedRaw(local, origin);
            try self.emitFixed("=", origin);
            try self.emitQuotedRaw(returned, origin);
            try self.emitFixed(";", origin);
            if (env.rename_locals) try env.symbols.append(self.scratch, .{ .original = decoded, .emitted = local });
            continue;
        }
        if (tokenWord(text, start_tok, "BEGIN")) {
            try self.requireEmitWord(env, tokens, i, "BEGIN");
            try self.requireEmitWord(env, tokens, i, "ATOMIC");
            const saved = env.symbols.items.len;
            try self.lowerBlock(env, tokens, i, true, depth + 1);
            env.symbols.shrinkRetainingCapacity(saved);
            try self.requireEmitWord(env, tokens, i, "END");
            try self.requireEmitSymbol(env, tokens, i, ";");
            continue;
        }
        if (tokenWord(text, start_tok, "IF")) {
            const mark = self.beginHoistScope();
            var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
            self.hoist = &hoisted;
            try self.requireEmitWord(env, tokens, i, "IF");
            try self.lowerExpression(env, tokens, i, 0, true, depth + 1);
            self.hoist = null;
            try self.applyHoist(mark, &hoisted);
            try self.requireEmitWord(env, tokens, i, "THEN");
            const saved = env.symbols.items.len;
            try self.lowerBlock(env, tokens, i, atomic, depth + 1);
            env.symbols.shrinkRetainingCapacity(saved);
            if (i.* < tokens.len and tokenWord(text, tokens[i.*], "ELSE")) {
                try self.requireEmitWord(env, tokens, i, "ELSE");
                try self.lowerBlock(env, tokens, i, atomic, depth + 1);
                env.symbols.shrinkRetainingCapacity(saved);
            }
            try self.requireEmitWord(env, tokens, i, "END");
            try self.requireEmitWord(env, tokens, i, "IF");
            try self.requireEmitSymbol(env, tokens, i, ";");
            continue;
        }

        const mark = self.beginHoistScope();
        var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
        self.hoist = &hoisted;
        defer self.hoist = null;

        if (tokenWord(text, start_tok, "LET")) {
            try self.requireEmitWord(env, tokens, i, "LET");
            const var_tok = tokens[i.*];
            i.* += 1;
            const decoded = try self.decodeProgramName(text, var_tok);
            var new_hygienic: ?[]const u8 = null;
            if (env.rename_locals) {
                for (env.symbols.items) |sym| if (std.mem.eql(u8, sym.original, decoded)) {
                    self.setError(env, var_tok.start);
                    return error.DuplicateProgramVariable;
                };
                const h = try self.freshHygienic(decoded);
                new_hygienic = h;
                try self.emitQuotedRaw(h, self.makeOrigin(env, var_tok.start));
            } else {
                try self.emitOriginalToken(env, text, tokens, i.* - 1);
            }
            try self.requireEmitSymbol(env, tokens, i, "=");
            if (i.* < tokens.len and tokenWord(text, tokens[i.*], "SELECT")) {
                try self.requireEmitWord(env, tokens, i, "SELECT");
                if (tokenSymbol(text, tokens[i.*], '*')) {
                    try self.requireEmitSymbol(env, tokens, i, "*");
                } else {
                    while (true) {
                        try self.emitOriginalToken(env, text, tokens, i.*);
                        i.* += 1;
                        if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], ',')) {
                            try self.requireEmitSymbol(env, tokens, i, ",");
                        } else break;
                    }
                }
                try self.requireEmitWord(env, tokens, i, "FROM");
                _ = try self.emitResourceOperand(env, tokens, i, .table);
                if (i.* < tokens.len and tokenWord(text, tokens[i.*], "WHERE")) {
                    try self.requireEmitWord(env, tokens, i, "WHERE");
                    try self.lowerExpression(env, tokens, i, 0, false, depth + 1);
                }
            } else {
                try self.lowerExpression(env, tokens, i, 0, true, depth + 1);
            }
            try self.requireEmitSymbol(env, tokens, i, ";");
            if (new_hygienic) |h| try env.symbols.append(self.scratch, .{ .original = decoded, .emitted = h });
        } else if (tokenWord(text, start_tok, "REQUIRE")) {
            try self.requireEmitWord(env, tokens, i, "REQUIRE");
            try self.lowerExpression(env, tokens, i, 0, true, depth + 1);
            try self.requireEmitWord(env, tokens, i, "ELSE");
            if (tokenSymbol(text, tokens[i.*], '$')) {
                try self.emitValueHole(env, tokens, i);
            } else {
                try self.emitOriginalToken(env, text, tokens, i.*);
                i.* += 1;
            }
            try self.requireEmitSymbol(env, tokens, i, ";");
        } else if (tokenWord(text, start_tok, "INSERT")) {
            try self.requireEmitWord(env, tokens, i, "INSERT");
            try self.requireEmitWord(env, tokens, i, "INTO");
            _ = try self.emitResourceOperand(env, tokens, i, .table);
            try self.requireEmitWord(env, tokens, i, "VALUES");
            try self.lowerArguments(env, tokens, i, true, depth + 1);
            try self.requireEmitWord(env, tokens, i, "ON");
            try self.requireEmitWord(env, tokens, i, "CONFLICT");
            try self.requireEmitSymbol(env, tokens, i, "(");
            while (true) {
                try self.emitOriginalToken(env, text, tokens, i.*);
                i.* += 1;
                if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], ',')) {
                    try self.requireEmitSymbol(env, tokens, i, ",");
                } else break;
            }
            try self.requireEmitSymbol(env, tokens, i, ")");
            try self.requireEmitWord(env, tokens, i, "DO");
            try self.requireEmitWord(env, tokens, i, "ASSERT");
            try self.requireEmitWord(env, tokens, i, "SAME");
            try self.requireEmitWord(env, tokens, i, "ROW");
            try self.requireEmitSymbol(env, tokens, i, ";");
        } else if (tokenWord(text, start_tok, "PRODUCE") or tokenWord(text, start_tok, "ENQUEUE")) {
            const is_stream = tokenWord(text, start_tok, "PRODUCE");
            try self.requireEmitWord(env, tokens, i, if (is_stream) "PRODUCE" else "ENQUEUE");
            try self.requireEmitWord(env, tokens, i, "INTO");
            _ = try self.emitResourceOperand(env, tokens, i, if (is_stream) .stream else .queue);
            try self.requireEmitWord(env, tokens, i, "VALUES");
            try self.lowerArguments(env, tokens, i, true, depth + 1);
            try self.requireEmitSymbol(env, tokens, i, ";");
        } else {
            self.setError(env, start_tok.start);
            return error.UnsupportedProgramInstruction;
        }
        self.hoist = null;
        try self.applyHoist(mark, &hoisted);
    }
}

const HoistMark = struct { writer: usize, sites: usize, origins: usize, obligations: usize };

fn beginHoistScope(self: *Self) HoistMark {
    return .{
        .writer = self.writer.len(),
        .sites = self.sites.items.len,
        .origins = self.origins.items.len,
        .obligations = self.obligations.items.len,
    };
}

fn applyHoist(self: *Self, mark: HoistMark, hoisted: *const Hoisted) !void {
    if (hoisted.writer.len() == 0) return;
    const prefix = hoisted.writer.bytes.items;
    const need_space: usize = if (mark.writer != 0) 1 else 0;
    const delta = need_space + prefix.len;
    if (delta > self.writer.limit - self.writer.len()) return error.BuildStatementLimit;

    const tail_len = self.writer.len() - mark.writer;
    try self.writer.bytes.resize(self.writer.allocator, self.writer.len() + delta);
    std.mem.copyBackwards(u8, self.writer.bytes.items[mark.writer + delta ..], self.writer.bytes.items[mark.writer .. mark.writer + tail_len]);
    if (need_space == 1) self.writer.bytes.items[mark.writer] = ' ';
    @memcpy(self.writer.bytes.items[mark.writer + need_space .. mark.writer + delta], prefix);

    const base_shift = mark.writer + need_space;
    for (self.sites.items[mark.sites..]) |*site| {
        site.start += delta;
        site.end += delta;
    }
    for (hoisted.sites.items) |site| {
        try self.sites.append(self.output, .{ .start = site.start + base_shift, .end = site.end + base_shift, .value = site.value });
    }

    for (self.origins.items[mark.origins..]) |*origin| {
        origin.start += delta;
        origin.end += delta;
    }
    const tail_origins = try self.scratch.dupe(Operands.Origin, self.origins.items[mark.origins..]);
    self.origins.shrinkRetainingCapacity(mark.origins);
    for (hoisted.origins.items) |origin| {
        var shifted = origin;
        shifted.start += base_shift;
        shifted.end += base_shift;
        try self.origins.append(self.output, shifted);
    }
    try self.origins.appendSlice(self.output, tail_origins);

    for (self.obligations.items[mark.obligations..]) |*ob| {
        if (ob.target == .span) {
            ob.target.span.start += delta;
            ob.target.span.end += delta;
        }
    }
    for (hoisted.obligations.items) |ob| {
        var shifted = ob;
        if (shifted.target == .span) {
            shifted.target.span.start += base_shift;
            shifted.target.span.end += base_shift;
        }
        try self.obligations.append(self.output, shifted);
    }
}

fn consumeSemicolon(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize) !void {
    const text = self.compiler.graph.sources[env.file].text;
    if (i.* >= tokens.len or !tokenSymbol(text, tokens[i.*], ';')) {
        self.setError(env, if (i.* < tokens.len) tokens[i.*].start else text.len);
        return error.InvalidSourceSyntax;
    }
    i.* += 1;
}

fn requireEmitSymbol(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, sym: []const u8) !void {
    const text = self.compiler.graph.sources[env.file].text;
    if (i.* >= tokens.len or !std.mem.eql(u8, text[tokens[i.*].start..tokens[i.*].end], sym)) {
        self.setError(env, if (i.* < tokens.len) tokens[i.*].start else text.len);
        return error.InvalidSourceSyntax;
    }
    try self.emitFixed(sym, self.makeOrigin(env, tokens[i.*].start));
    i.* += 1;
}

fn helperKindMatches(actual: types.HelperKind, expected: s.Template.HelperKind) bool {
    return switch (expected) {
        .function => actual == .function,
        .guard => actual == .guard,
        .procedure => actual == .procedure,
    };
}

fn resolveBoundHelper(compiler: *Compiler, file: usize, bindings: []const types.Binding, schemas: []const types.SchemaBinding, name: s.Name, expected_kind: s.Template.HelperKind, call_offset: usize) !?ResolvedCallee {
    if (name.qualifier) |qualifier| {
        for (bindings) |b| if (std.mem.eql(u8, b.name, qualifier)) {
            if (b.value != .instance) {
                compiler.file = file;
                compiler.offset = call_offset;
                return error.SourceTypeMismatch;
            }
            for (b.value.instance.exports) |exported| if (std.mem.eql(u8, exported.name, name.member)) {
                if (exported.value != .helper or !helperKindMatches(exported.value.helper.kind, expected_kind)) {
                    compiler.file = file;
                    compiler.offset = call_offset;
                    compiler.context = .{ .name = name.member, .expected = @tagName(expected_kind), .actual = if (exported.value == .helper) @tagName(exported.value.helper.kind) else @tagName(exported.value) };
                    return error.SourceTypeMismatch;
                }
                const h = exported.value.helper;
                return .{ .ref = h.ref, .bindings = h.bindings, .owner = h.owner, .schemas = h.schemas };
            };
            compiler.file = file;
            compiler.offset = call_offset;
            compiler.context = .{ .name = name.member };
            return error.UnknownSourceExport;
        };
        if (Compiler.hasSchemaBinding(schemas, qualifier)) {
            var idx = bindings.len;
            while (idx > 0) {
                idx -= 1;
                const b = bindings[idx];
                if (!std.mem.eql(u8, b.name, name.member)) continue;
                if (b.value == .helper) {
                    if (!helperKindMatches(b.value.helper.kind, expected_kind)) {
                        compiler.file = file;
                        compiler.offset = call_offset;
                        compiler.context = .{ .name = b.name, .expected = @tagName(expected_kind), .actual = @tagName(b.value.helper.kind) };
                        return error.SourceTypeMismatch;
                    }
                    const h = b.value.helper;
                    return .{ .ref = h.ref, .bindings = h.bindings, .owner = h.owner, .schemas = h.schemas };
                }
            }
        }
        return null;
    }
    var idx = bindings.len;
    while (idx > 0) {
        idx -= 1;
        const b = bindings[idx];
        if (!std.mem.eql(u8, b.name, name.member)) continue;
        if (b.value == .helper) {
            if (!helperKindMatches(b.value.helper.kind, expected_kind)) {
                if (expected_kind == .function and std.meta.stringToEnum(f.ApplicationProgram.Function, name.member) != null) return null;
                compiler.file = file;
                compiler.offset = call_offset;
                compiler.context = .{ .name = b.name, .expected = @tagName(expected_kind), .actual = @tagName(b.value.helper.kind) };
                return error.SourceTypeMismatch;
            }
            const h = b.value.helper;
            return .{ .ref = h.ref, .bindings = h.bindings, .owner = h.owner, .schemas = h.schemas };
        }
    }
    return null;
}

fn parseCalleeRef(compiler: *Compiler, file: usize, bindings: []const types.Binding, schemas: []const types.SchemaBinding, text: []const u8, tokens: []const s.Token, i: *usize, expected_kind: s.Template.HelperKind, call_offset: usize) !ResolvedCallee {
    const first = try std.ascii.allocLowerString(compiler.scratch.allocator(), text[tokens[i.*].start..tokens[i.*].end]);
    i.* += 1;
    var name: s.Name = .{ .member = first };
    if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], '.')) {
        i.* += 1;
        const second = try std.ascii.allocLowerString(compiler.scratch.allocator(), text[tokens[i.*].start..tokens[i.*].end]);
        i.* += 1;
        name = .{ .qualifier = first, .member = second };
    }
    if (try resolveBoundHelper(compiler, file, bindings, schemas, name, expected_kind, call_offset)) |bound| return bound;
    const ref = compiler.graph.resolve(file, name) catch |err| {
        compiler.file = file;
        compiler.offset = call_offset;
        return err;
    };
    const def = compiler.graph.getDefinition(ref);
    const matches = switch (expected_kind) {
        .function => def.kind == .function,
        .guard => def.kind == .guard,
        .procedure => def.kind == .procedure,
    };
    if (!matches) {
        compiler.file = file;
        compiler.offset = call_offset;
        compiler.context = .{ .name = def.name, .expected = @tagName(expected_kind), .actual = @tagName(def.kind) };
        return error.SourceTypeMismatch;
    }
    return .{ .ref = ref, .owner = compiler.owner, .schemas = schemas };
}

fn resolveQualifiedFunction(compiler: *Compiler, file: usize, bindings: []const types.Binding, schemas: []const types.SchemaBinding, text: []const u8, tokens: []const s.Token, i: *usize, call_offset: usize) !ResolvedCallee {
    if (tokens[i.*].kind != .word or tokens[i.* + 2].kind != .word) {
        compiler.file = file;
        compiler.offset = call_offset;
        return error.InvalidSourceName;
    }
    const qualifier = try std.ascii.allocLowerString(compiler.scratch.allocator(), text[tokens[i.*].start..tokens[i.*].end]);
    const member = try std.ascii.allocLowerString(compiler.scratch.allocator(), text[tokens[i.* + 2].start..tokens[i.* + 2].end]);
    i.* += 3;
    if (try resolveBoundHelper(compiler, file, bindings, schemas, .{ .qualifier = qualifier, .member = member }, .function, call_offset)) |bound| return bound;
    const ref = compiler.graph.resolve(file, .{ .qualifier = qualifier, .member = member }) catch |err| {
        compiler.file = file;
        compiler.offset = call_offset;
        return err;
    };
    const def = compiler.graph.getDefinition(ref);
    if (def.kind != .function) {
        compiler.file = file;
        compiler.offset = call_offset;
        compiler.context = .{ .name = def.name, .expected = "function", .actual = @tagName(def.kind) };
        return error.SourceTypeMismatch;
    }
    return .{ .ref = ref, .owner = compiler.owner, .schemas = schemas };
}

fn resolveLocalFunction(compiler: *Compiler, file: usize, bindings: []const types.Binding, raw: []const u8, call_offset: usize) !?ResolvedCallee {
    const lower = try std.ascii.allocLowerString(compiler.scratch.allocator(), raw);
    if (try resolveBoundHelper(compiler, file, bindings, &.{}, .{ .member = lower }, .function, call_offset)) |bound| return bound;
    for (compiler.graph.files[file].definitions, 0..) |def, idx| {
        if (def.schema == null and std.mem.eql(u8, def.name, lower)) {
            if (def.kind == .function) return .{ .ref = .{ .file = file, .definition = idx }, .owner = compiler.owner, .schemas = compiler.activeSchemas() };
            if (std.meta.stringToEnum(f.ApplicationProgram.Function, lower) == null) {
                compiler.file = file;
                compiler.offset = call_offset;
                compiler.context = .{ .name = def.name, .expected = "function", .actual = @tagName(def.kind) };
                return error.SourceTypeMismatch;
            }
            return null;
        }
    }
    return null;
}

fn sliceCallArguments(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize) ![]const []const s.Token {
    const text = self.compiler.graph.sources[env.file].text;
    if (i.* >= tokens.len or !tokenSymbol(text, tokens[i.*], '(')) {
        self.setError(env, if (i.* < tokens.len) tokens[i.*].start else text.len);
        return error.InvalidSourceSyntax;
    }
    i.* += 1;
    var args: std.ArrayList([]const s.Token) = .empty;
    if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], ')')) {
        i.* += 1;
        return &.{};
    }
    var arg_start = i.*;
    var paren_depth: usize = 0;
    while (i.* < tokens.len) : (i.* += 1) {
        const tok = tokens[i.*];
        if (tokenSymbol(text, tok, '(')) {
            paren_depth += 1;
        } else if (tokenSymbol(text, tok, ')')) {
            if (paren_depth == 0) {
                try args.append(self.scratch, tokens[arg_start..i.*]);
                i.* += 1;
                return args.toOwnedSlice(self.scratch);
            }
            paren_depth -= 1;
        } else if (paren_depth == 0 and tokenSymbol(text, tok, ',')) {
            if (args.items.len == 64) return error.SourceParameterLimit;
            try args.append(self.scratch, tokens[arg_start..i.*]);
            arg_start = i.* + 1;
        }
    }
    self.setError(env, text.len);
    return error.InvalidSourceSyntax;
}

fn inlineHelperCall(self: *Self, caller_env: *Env, tokens: []const s.Token, i: *usize, kind: s.Template.HelperKind, atomic: bool, call_offset: usize, depth: usize, result_binding: ?[]const u8) anyerror!void {
    try self.compiler.tick();
    if (depth > self.compiler.limits.depth) {
        self.setError(caller_env, call_offset);
        return error.SourceDepthLimit;
    }
    if (kind == .procedure and !atomic) {
        self.setError(caller_env, call_offset);
        return error.MutationOutsideAtomic;
    }
    const text = self.compiler.graph.sources[caller_env.file].text;
    const resolved_callee = parseCalleeRef(self.compiler, caller_env.file, caller_env.bindings, caller_env.schemas, text, tokens, i, kind, call_offset) catch |err| {
        if (caller_env.call) |prior| self.compiler.call_site = Compiler.location(self.compiler.graph.sources[prior.file], prior.offset);
        return err;
    };
    const callee_ref = resolved_callee.ref;
    const callee = self.compiler.graph.getDefinition(callee_ref);
    if (result_binding != null and callee.return_type == null) {
        self.setError(caller_env, call_offset);
        return error.ProcedureHasNoResult;
    }
    const arg_slices = try self.sliceCallArguments(caller_env, tokens, i);
    if (arg_slices.len != callee.parameters.len) {
        self.setError(caller_env, call_offset);
        self.compiler.context = .{ .name = callee.name };
        return error.SourceArgumentCount;
    }

    const outer_call: CallOrigin = caller_env.call orelse .{ .file = caller_env.file, .offset = call_offset };
    var res_bindings: std.ArrayList(ResourceBinding) = .empty;
    var row_vars: std.ArrayList(RowVar) = .empty;
    var callee_env: Env = .{
        .file = callee_ref.file,
        .helper = callee_ref,
        .mode = if (kind == .guard) .guard else .procedure,
        .rename_locals = true,
        .owner = resolved_callee.owner,
        .schemas = resolved_callee.schemas,
        .bindings = resolved_callee.bindings,
        .call = outer_call,
        .return_binding = if (callee.return_type != null) result_binding orelse try self.freshHygienic("ret") else null,
    };

    for (callee.parameters, arg_slices) |param, arg_tokens| {
        const arg_offset = if (arg_tokens.len > 0) arg_tokens[0].start else call_offset;
        switch (param.kind) {
            inline .table, .stream, .queue => |cols, tag| {
                const expected_kind: types.ResourceKind = switch (tag) {
                    .table => .table,
                    .stream => .stream,
                    .queue => .queue,
                    else => unreachable,
                };
                const bound_table = try self.resolveResourceArgument(caller_env, arg_tokens, expected_kind, arg_offset);
                self.compiler.context = .{ .name = param.name };
                types.signature(self.compiler.graph, callee_ref.file, cols, bound_table, &self.compiler.context) catch |err| {
                    self.setError(caller_env, arg_offset);
                    return err;
                };
                self.compiler.context = .{};
                try res_bindings.append(self.scratch, .{ .name = param.name, .table = bound_table });
            },
            .row => |fields| {
                const caller_text = self.compiler.graph.sources[caller_env.file].text;
                if (arg_tokens.len >= 3 and tokenWord(caller_text, arg_tokens[0], "ROW") and tokenSymbol(caller_text, arg_tokens[1], '(')) {
                    var row_cursor: usize = 1;
                    const row_args = try self.sliceCallArguments(caller_env, arg_tokens, &row_cursor);
                    if (row_cursor != arg_tokens.len or row_args.len != fields.len) {
                        self.setError(caller_env, arg_offset);
                        self.compiler.context = .{ .name = param.name };
                        return error.ProgramTypeMismatch;
                    }
                    const field_vars = try self.scratch.alloc(RowFieldVar, fields.len);
                    for (fields, row_args, 0..) |f_param, f_tokens, f_idx| {
                        const f_offset = if (f_tokens.len > 0) f_tokens[0].start else arg_offset;
                        const expected_f = try parameterExpected(self.scratch, self.output, self.compiler.graph, callee_ref.file, f_param.kind);
                        const f_hygienic = try self.freshHygienic(f_param.name);
                        const mark = self.beginHoistScope();
                        var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
                        self.hoist = &hoisted;
                        const f_origin = self.makeOrigin(caller_env, f_offset);
                        try self.emitFixed("LET", f_origin);
                        try self.emitQuotedRaw(f_hygienic, f_origin);
                        try self.emitFixed("=", f_origin);
                        var cursor: usize = 0;
                        try self.lowerExpression(caller_env, f_tokens, &cursor, 0, true, depth + 1);
                        try self.emitFixed(";", f_origin);
                        self.hoist = null;
                        try self.applyHoist(mark, &hoisted);
                        try self.obligations.append(self.output, .{
                            .target = .{ .binding = f_hygienic },
                            .expected = expected_f,
                            .name = f_param.name,
                        });
                        field_vars[f_idx] = .{ .name = f_param.name, .emitted = f_hygienic };
                    }
                    try row_vars.append(self.scratch, .{ .original = param.name, .fields = field_vars });
                } else if (arg_tokens.len == 1 and arg_tokens[0].kind == .word and blk: {
                    const arg_ident = caller_text[arg_tokens[0].start..arg_tokens[0].end];
                    for (caller_env.row_vars) |rv| if (std.ascii.eqlIgnoreCase(arg_ident, rv.original)) break :blk true;
                    break :blk false;
                }) {
                    const arg_ident = caller_text[arg_tokens[0].start..arg_tokens[0].end];
                    const caller_rv = for (caller_env.row_vars) |rv| {
                        if (std.ascii.eqlIgnoreCase(arg_ident, rv.original)) break rv;
                    } else unreachable;
                    if (caller_rv.fields.len != fields.len) {
                        self.setError(caller_env, arg_offset);
                        self.compiler.context = .{ .name = param.name };
                        return error.ProgramTypeMismatch;
                    }
                    const field_vars = try self.scratch.alloc(RowFieldVar, fields.len);
                    for (fields, caller_rv.fields, 0..) |f_param, c_field, f_idx| {
                        if (!std.mem.eql(u8, f_param.name, c_field.name)) {
                            self.setError(caller_env, arg_offset);
                            self.compiler.context = .{ .name = param.name };
                            return error.ProgramTypeMismatch;
                        }
                        const expected_f = try parameterExpected(self.scratch, self.output, self.compiler.graph, callee_ref.file, f_param.kind);
                        try self.obligations.append(self.output, .{
                            .target = .{ .binding = c_field.emitted },
                            .expected = expected_f,
                            .name = f_param.name,
                        });
                        field_vars[f_idx] = .{ .name = f_param.name, .emitted = c_field.emitted };
                    }
                    try row_vars.append(self.scratch, .{ .original = param.name, .fields = field_vars });
                } else {
                    const expected_row = try parameterExpected(self.scratch, self.output, self.compiler.graph, callee_ref.file, param.kind);
                    const hygienic = try self.freshHygienic(param.name);
                    const mark = self.beginHoistScope();
                    var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
                    self.hoist = &hoisted;
                    const arg_origin = self.makeOrigin(caller_env, arg_offset);
                    try self.emitFixed("LET", arg_origin);
                    try self.emitQuotedRaw(hygienic, arg_origin);
                    try self.emitFixed("=", arg_origin);
                    var cursor: usize = 0;
                    try self.lowerExpression(caller_env, arg_tokens, &cursor, 0, true, depth + 1);
                    try self.emitFixed(";", arg_origin);
                    self.hoist = null;
                    try self.applyHoist(mark, &hoisted);
                    try self.obligations.append(self.output, .{
                        .target = .{ .binding = hygienic },
                        .expected = expected_row,
                        .name = param.name,
                    });
                    try callee_env.symbols.append(self.scratch, .{ .original = param.name, .emitted = hygienic });
                }
            },
            .integer, .text, .boolean, .uuid, .timestamptz, .binary, .named => {
                const expected_scalar = try parameterScalar(self.compiler.graph, callee_ref.file, param.kind);
                const hygienic = try self.freshHygienic(param.name);
                const mark = self.beginHoistScope();
                var hoisted: Hoisted = .{ .writer = .{ .allocator = self.scratch, .limit = self.writer.limit } };
                self.hoist = &hoisted;
                const arg_origin = self.makeOrigin(caller_env, arg_offset);
                try self.emitFixed("LET", arg_origin);
                try self.emitQuotedRaw(hygienic, arg_origin);
                try self.emitFixed("=", arg_origin);
                var cursor: usize = 0;
                try self.lowerExpression(caller_env, arg_tokens, &cursor, 0, true, depth + 1);
                try self.emitFixed(";", arg_origin);
                self.hoist = null;
                try self.applyHoist(mark, &hoisted);
                try self.obligations.append(self.output, .{
                    .target = .{ .binding = hygienic },
                    .expected = .{ .scalar = expected_scalar },
                    .name = param.name,
                });
                try callee_env.symbols.append(self.scratch, .{ .original = param.name, .emitted = hygienic });
            },
            else => unreachable,
        }
    }
    callee_env.resources = res_bindings.items;
    callee_env.row_vars = row_vars.items;
    if (kind == .guard) {
        try self.lowerGuardProgram(&callee_env, callee.program.?, depth + 1);
    } else {
        var body_cursor: usize = 0;
        try self.lowerBlock(&callee_env, callee.program.?.tokens, &body_cursor, atomic, depth + 1);
    }
}

fn resolveResourceArgument(self: *Self, caller_env: *const Env, arg_tokens: []const s.Token, expected_kind: types.ResourceKind, arg_offset: usize) !*const types.Table {
    const text = self.compiler.graph.sources[caller_env.file].text;
    if (arg_tokens.len == 2 and tokenSymbol(text, arg_tokens[0], '$') and arg_tokens[1].kind == .word) {
        const hole_name = text[arg_tokens[1].start..arg_tokens[1].end];
        const val = for (caller_env.bindings) |b| {
            if (std.ascii.eqlIgnoreCase(hole_name, b.name)) break b.value;
        } else {
            self.setError(caller_env, arg_offset);
            return error.UnknownSourceOperand;
        };
        switch (val) {
            .reference_table => {
                self.setError(caller_env, arg_offset);
                return error.ReferenceOnlyTableAccess;
            },
            .table => |tbl| {
                if (expected_kind != .table) {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                }
                return tbl;
            },
            .stream => |tbl| {
                if (expected_kind != .stream) {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                }
                return tbl;
            },
            .queue => |tbl| {
                if (expected_kind != .queue) {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                }
                return tbl;
            },
            .identifier => |ident| {
                const entry = self.catalog.findResource(ident) catch |err| {
                    self.setError(caller_env, arg_offset);
                    return err;
                };
                if (entry.kind != expected_kind) {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                }
                Operands.checkResourceAccess(caller_env.owner, caller_env.bindings, entry, &self.compiler.context) catch |err| {
                    self.setError(caller_env, arg_offset);
                    return err;
                };
                return entry;
            },
            else => {
                self.setError(caller_env, arg_offset);
                return error.SourceTypeMismatch;
            },
        }
    }
    if (arg_tokens.len == 3 and arg_tokens[0].kind == .word and tokenSymbol(text, arg_tokens[1], '.') and arg_tokens[2].kind == .word) {
        const qual = try self.decodeProgramName(text, arg_tokens[0]);
        const mem = try self.decodeProgramName(text, arg_tokens[2]);
        for (caller_env.bindings) |b| if (std.mem.eql(u8, b.name, qual)) {
            if (b.value != .instance) {
                self.setError(caller_env, arg_offset);
                return error.SourceTypeMismatch;
            }
            for (b.value.instance.exports) |exported| if (std.mem.eql(u8, exported.name, mem)) {
                return switch (exported.value) {
                    .reference_table => {
                        self.setError(caller_env, arg_offset);
                        return error.ReferenceOnlyTableAccess;
                    },
                    .table => |tbl| if (expected_kind == .table) tbl else blk: {
                        self.setError(caller_env, arg_offset);
                        break :blk error.SourceTypeMismatch;
                    },
                    .stream => |tbl| if (expected_kind == .stream) tbl else blk: {
                        self.setError(caller_env, arg_offset);
                        break :blk error.SourceTypeMismatch;
                    },
                    .queue => |tbl| if (expected_kind == .queue) tbl else blk: {
                        self.setError(caller_env, arg_offset);
                        break :blk error.SourceTypeMismatch;
                    },
                    else => blk: {
                        self.setError(caller_env, arg_offset);
                        break :blk error.SourceTypeMismatch;
                    },
                };
            };
            self.setError(caller_env, arg_offset);
            self.compiler.context = .{ .name = mem };
            return error.UnknownSourceExport;
        };
        const concrete = Compiler.resolveSchemaName(caller_env.schemas, qual);
        const entry = self.catalog.findResourceQualified(concrete, mem) catch |err| {
            self.setError(caller_env, arg_offset);
            return err;
        };
        if (entry.kind != expected_kind) {
            self.setError(caller_env, arg_offset);
            return error.SourceTypeMismatch;
        }
        Operands.checkResourceAccess(caller_env.owner, caller_env.bindings, entry, &self.compiler.context) catch |err| {
            self.setError(caller_env, arg_offset);
            return err;
        };
        return entry;
    }
    if (arg_tokens.len == 1 and (arg_tokens[0].kind == .word or arg_tokens[0].kind == .quoted)) {
        const decoded = try self.decodeProgramName(text, arg_tokens[0]);
        if (caller_env.helper != null) {
            for (caller_env.resources) |res| if (std.mem.eql(u8, res.name, decoded)) {
                if (res.table.kind != expected_kind) {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                }
                return res.table;
            };
        }
        for (caller_env.bindings) |b| if (std.mem.eql(u8, b.name, decoded)) {
            switch (b.value) {
                .reference_table => {
                    self.setError(caller_env, arg_offset);
                    return error.ReferenceOnlyTableAccess;
                },
                .table => |tbl| return if (expected_kind == .table) tbl else {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                },
                .stream => |tbl| return if (expected_kind == .stream) tbl else {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                },
                .queue => |tbl| return if (expected_kind == .queue) tbl else {
                    self.setError(caller_env, arg_offset);
                    return error.SourceTypeMismatch;
                },
                else => {},
            }
        };
        if (caller_env.helper != null) {
            if (caller_env.owner != 0) {
                if (self.catalog.findResourceQualified("public", decoded) catch null) |entry| {
                    if (entry.owner == caller_env.owner and entry.kind == expected_kind) return entry;
                }
            }
            self.setError(caller_env, arg_offset);
            return error.UnknownProgramResource;
        }
        const entry = self.catalog.findResource(decoded) catch |err| {
            self.setError(caller_env, arg_offset);
            return err;
        };
        if (entry.kind != expected_kind) {
            self.setError(caller_env, arg_offset);
            return error.SourceTypeMismatch;
        }
        Operands.checkResourceAccess(caller_env.owner, caller_env.bindings, entry, &self.compiler.context) catch |err| {
            self.setError(caller_env, arg_offset);
            return err;
        };
        return entry;
    }
    self.setError(caller_env, arg_offset);
    return error.SourceTypeMismatch;
}

fn lowerArguments(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, hoistable: bool, depth: usize) anyerror!void {
    const text = self.compiler.graph.sources[env.file].text;
    try self.requireEmitSymbol(env, tokens, i, "(");
    if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], ')')) {
        try self.requireEmitSymbol(env, tokens, i, ")");
        return;
    }
    while (true) {
        try self.lowerExpression(env, tokens, i, 0, hoistable, depth + 1);
        if (i.* < tokens.len and tokenSymbol(text, tokens[i.*], ',')) {
            try self.requireEmitSymbol(env, tokens, i, ",");
        } else break;
    }
    try self.requireEmitSymbol(env, tokens, i, ")");
}

fn emitValueHole(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize) !void {
    const text = self.compiler.graph.sources[env.file].text;
    const dollar_tok = tokens[i.*];
    if (i.* + 1 >= tokens.len or tokens[i.* + 1].kind != .word) {
        self.setError(env, dollar_tok.start);
        return error.InvalidSourceOperand;
    }
    const name = text[tokens[i.* + 1].start..tokens[i.* + 1].end];
    const value = for (env.bindings) |b| {
        if (std.ascii.eqlIgnoreCase(name, b.name)) break b.value;
    } else {
        self.setError(env, dollar_tok.start);
        return error.UnknownSourceOperand;
    };
    switch (value) {
        .integer, .text, .boolean, .uuid, .timestamptz, .binary, .nominal => {},
        .table, .stream, .queue, .identifier => {
            self.setError(env, dollar_tok.start);
            return error.UnsupportedLogOperand;
        },
        else => {
            self.setError(env, dollar_tok.start);
            return error.InvalidSourceOperand;
        },
    }
    i.* += 2;
    if (self.writer.len() != 0) try self.writer.writeByte(' ');
    const start = self.writer.len();
    try Compiler.writeValue(&self.writer, value);
    try self.sites.append(self.output, .{ .start = start, .end = self.writer.len(), .value = value });
    var rec = self.makeOrigin(env, dollar_tok.start);
    rec.start = start;
    rec.end = self.writer.len();
    try self.origins.append(self.output, rec);
}

fn builtinPurity(lower_name: []const u8) enum { pure, impure, unknown } {
    const map = std.StaticStringMap(enum { pure, impure }).initComptime(.{
        .{ "digest", .pure },
        .{ "commitment", .pure },
        .{ "seconds", .pure },
        .{ "url", .pure },
        .{ "json_object", .pure },
        .{ "s256", .pure },
        .{ "length", .pure },
        .{ "secure_equal", .pure },
        .{ "operation_id", .pure },
        .{ "json_value", .pure },
        .{ "json_integer", .pure },
        .{ "identity_digest", .pure },
        .{ "now", .impure },
        .{ "random_token", .impure },
        .{ "random_secret", .impure },
        .{ "secret", .impure },
        .{ "derive_secret", .impure },
        .{ "current_revision", .impure },
        .{ "secret_current", .impure },
        .{ "http_query", .impure },
        .{ "http_query_unique", .impure },
        .{ "http_secret_query_unique", .impure },
        .{ "http_secret_cookie_unique", .impure },
        .{ "secret_json_value", .impure },
        .{ "bearer", .impure },
        .{ "native_identity_allowed", .impure },
        .{ "native_session_current", .impure },
        .{ "native_binding_active", .impure },
        .{ "current_timestamp", .impure },
        .{ "current_date", .impure },
        .{ "current_time", .impure },
        .{ "localtime", .impure },
        .{ "localtimestamp", .impure },
        .{ "clock_timestamp", .impure },
        .{ "statement_timestamp", .impure },
        .{ "transaction_timestamp", .impure },
        .{ "random", .impure },
        .{ "gen_random_uuid", .impure },
    });
    return if (map.get(lower_name)) |v| switch (v) {
        .pure => .pure,
        .impure => .impure,
    } else .unknown;
}

fn bareWordImpure(lower_name: []const u8) bool {
    const map = std.StaticStringMap(void).initComptime(.{
        .{ "current_timestamp", {} },
        .{ "current_date", {} },
        .{ "current_time", {} },
        .{ "localtime", {} },
        .{ "localtimestamp", {} },
        .{ "current_user", {} },
        .{ "current_role", {} },
        .{ "session_user", {} },
    });
    return map.has(lower_name);
}

fn countParamUses(text: []const u8, tokens: []const s.Token, param_name: []const u8) usize {
    var count: usize = 0;
    for (tokens, 0..) |tok, k| {
        if (tok.kind != .word) continue;
        if (!std.ascii.eqlIgnoreCase(text[tok.start..tok.end], param_name)) continue;
        if (k > 0 and tokenSymbol(text, tokens[k - 1], '.')) continue;
        if (k + 1 < tokens.len and tokenSymbol(text, tokens[k + 1], '(')) continue;
        if (k + 3 < tokens.len and tokenSymbol(text, tokens[k + 1], '.') and tokenSymbol(text, tokens[k + 3], '(')) continue;
        count += 1;
    }
    return count;
}

fn closureIsImpure(graph: Graph, closure: ArgClosure, depth: usize) bool {
    if (depth > 64) return false;
    const text = graph.sources[closure.file].text;
    for (closure.tokens, 0..) |tok, k| {
        if (tok.kind != .word) continue;
        if (k > 0 and tokenSymbol(text, closure.tokens[k - 1], '.')) continue;
        const raw = text[tok.start..tok.end];
        var buf: [64]u8 = undefined;
        if (raw.len <= buf.len) {
            const lower = std.ascii.lowerString(buf[0..raw.len], raw);
            if (k + 1 < closure.tokens.len and tokenSymbol(text, closure.tokens[k + 1], '(')) {
                if (builtinPurity(lower) == .impure) return true;
                continue;
            }
            if (bareWordImpure(lower)) return true;
            for (closure.env.fn_params) |fp| if (std.mem.eql(u8, fp.name, lower)) {
                if (fp.hoisted == null and closureIsImpure(graph, fp.closure, depth + 1)) return true;
            };
        }
    }
    return false;
}

fn expandFunctionCall(self: *Self, caller_env: *const Env, resolved_callee: ResolvedCallee, tokens: []const s.Token, i: *usize, call_offset: usize, hoistable: bool, depth: usize) anyerror!void {
    try self.compiler.tick();
    if (depth > self.compiler.limits.depth) {
        self.setError(caller_env, call_offset);
        return error.SourceDepthLimit;
    }
    const callee_ref = resolved_callee.ref;
    const callee = self.compiler.graph.getDefinition(callee_ref);
    const arg_slices = try self.sliceCallArguments(caller_env, tokens, i);
    if (arg_slices.len != callee.parameters.len) {
        self.setError(caller_env, call_offset);
        self.compiler.context = .{ .name = callee.name };
        return error.SourceArgumentCount;
    }

    const outer_call: CallOrigin = caller_env.call orelse .{ .file = caller_env.file, .offset = call_offset };
    const callee_text = self.compiler.graph.sources[callee_ref.file].text;
    const full_tokens = callee.program.?.tokens;
    const expr_tokens = full_tokens[1 .. full_tokens.len - 1];

    const ret_scalar = try types.resolve(self.compiler.graph, callee_ref.file, callee.return_type.?);
    const has_unused = blk: {
        for (callee.parameters) |p_chk| {
            if (countParamUses(callee_text, expr_tokens, p_chk.name) == 0) break :blk true;
        }
        break :blk false;
    };
    const fn_params = try self.scratch.alloc(FnParam, callee.parameters.len);
    var unused_indices: std.ArrayList(usize) = .empty;

    var fn_row_vars: std.ArrayList(RowVar) = .empty;
    for (callee.parameters, arg_slices, 0..) |param, arg_tokens, p_idx| {
        const arg_offset = if (arg_tokens.len > 0) arg_tokens[0].start else call_offset;
        const expected = try parameterExpected(self.scratch, self.output, self.compiler.graph, callee_ref.file, param.kind);
        const closure: ArgClosure = .{
            .file = caller_env.file,
            .tokens = arg_tokens,
            .env = caller_env,
            .call = caller_env.call,
        };
        const uses = countParamUses(callee_text, expr_tokens, param.name);
        const duplicate_branch = ret_scalar.domain != null or ret_scalar.base == .uuid or ret_scalar.base == .timestamptz or ret_scalar.base == .binary;
        const effective_uses = if (has_unused and duplicate_branch and !self.in_queue_predicate) uses * 2 else uses;
        const caller_text = self.compiler.graph.sources[caller_env.file].text;
        if (param.kind == .row and arg_tokens.len >= 3 and tokenWord(caller_text, arg_tokens[0], "ROW") and tokenSymbol(caller_text, arg_tokens[1], '(')) {
            if (!hoistable or self.hoist == null) {
                self.setError(caller_env, arg_offset);
                return error.InvalidQueuePredicate;
            }
            var row_cursor: usize = 1;
            const row_args = try self.sliceCallArguments(caller_env, arg_tokens, &row_cursor);
            if (row_cursor != arg_tokens.len or row_args.len != param.kind.row.len) {
                self.setError(caller_env, arg_offset);
                return error.ProgramTypeMismatch;
            }
            const field_vars = try self.scratch.alloc(RowFieldVar, param.kind.row.len);
            for (param.kind.row, row_args, 0..) |f_param, f_tokens, f_idx| {
                const f_offset = if (f_tokens.len > 0) f_tokens[0].start else arg_offset;
                const expected_f = try parameterExpected(self.scratch, self.scratch, self.compiler.graph, callee_ref.file, f_param.kind);
                const f_hygienic = try self.freshHygienic(f_param.name);
                try self.emitHoistedLet(caller_env, f_hygienic, expected_f, f_param.name, f_tokens, f_offset, depth + 1);
                field_vars[f_idx] = .{ .name = f_param.name, .emitted = f_hygienic };
            }
            try fn_row_vars.append(self.scratch, .{ .original = param.name, .fields = field_vars });
            fn_params[p_idx] = .{ .name = "", .expected = expected, .closure = closure, .hoisted = null };
            continue;
        }
        if (param.kind == .row and arg_tokens.len == 1 and arg_tokens[0].kind == .word) {
            const arg_ident = caller_text[arg_tokens[0].start..arg_tokens[0].end];
            for (caller_env.row_vars) |caller_rv| if (std.ascii.eqlIgnoreCase(arg_ident, caller_rv.original)) {
                if (caller_rv.fields.len != param.kind.row.len) {
                    self.setError(caller_env, arg_offset);
                    return error.ProgramTypeMismatch;
                }
                const field_vars = try self.scratch.alloc(RowFieldVar, param.kind.row.len);
                for (param.kind.row, caller_rv.fields, 0..) |f_param, c_field, f_idx| {
                    if (!std.mem.eql(u8, f_param.name, c_field.name)) {
                        self.setError(caller_env, arg_offset);
                        return error.ProgramTypeMismatch;
                    }
                    const expected_f = try parameterExpected(self.scratch, self.output, self.compiler.graph, callee_ref.file, f_param.kind);
                    try self.obligations.append(self.output, .{
                        .target = .{ .binding = c_field.emitted },
                        .expected = expected_f,
                        .name = f_param.name,
                    });
                    field_vars[f_idx] = .{ .name = f_param.name, .emitted = c_field.emitted };
                }
                try fn_row_vars.append(self.scratch, .{ .original = param.name, .fields = field_vars });
                fn_params[p_idx] = .{ .name = "", .expected = expected, .closure = closure, .hoisted = null };
                break;
            };
            if (fn_row_vars.items.len > 0 and std.mem.eql(u8, fn_row_vars.items[fn_row_vars.items.len - 1].original, param.name)) continue;
        }
        var hoisted_name: ?[]const u8 = null;
        if (effective_uses > 1 and closureIsImpure(self.compiler.graph, closure, 0)) {
            if (!hoistable or self.hoist == null) {
                self.setError(caller_env, arg_offset);
                return error.ImpureSourceFunction;
            }
            const h_name = try self.freshHygienic(param.name);
            try self.emitHoistedLet(caller_env, h_name, expected, param.name, arg_tokens, arg_offset, depth + 1);
            hoisted_name = h_name;
        }
        if (uses == 0) try unused_indices.append(self.scratch, p_idx);
        fn_params[p_idx] = .{
            .name = param.name,
            .expected = expected,
            .closure = closure,
            .hoisted = hoisted_name,
        };
    }

    var fn_env: Env = .{
        .file = callee_ref.file,
        .helper = callee_ref,
        .mode = .function,
        .rename_locals = true,
        .owner = resolved_callee.owner,
        .schemas = resolved_callee.schemas,
        .bindings = resolved_callee.bindings,
        .row_vars = fn_row_vars.items,
        .fn_params = fn_params,
        .call = outer_call,
    };

    const call_origin: Operands.Origin = .{ .start = 0, .end = 0, .source = callee.span.start, .file = callee_ref.file, .call = outer_call };
    if (unused_indices.items.len > 0 and self.in_queue_predicate) {
        for (unused_indices.items) |u_idx| {
            try self.validateUnusedQueueArg(fn_params[u_idx], call_offset, depth + 1);
        }
        unused_indices.clearRetainingCapacity();
    }

    try self.emitFixed("(", call_origin);
    if (unused_indices.items.len > 0) {
        try self.emitFixed("CASE WHEN", call_origin);
        for (unused_indices.items) |u_idx| {
            try self.emitParamClosure(fn_params[u_idx], call_origin, false, depth + 1);
            try self.emitFixed("IS NULL AND", call_origin);
        }
        try self.emitFixed("FALSE THEN", call_origin);
        if (ret_scalar.domain != null or ret_scalar.base == .uuid or ret_scalar.base == .timestamptz or ret_scalar.base == .binary) {
            try self.emitFixed("(", call_origin);
            var dup_cursor: usize = 0;
            try self.lowerExpression(&fn_env, expr_tokens, &dup_cursor, 0, false, depth + 1);
            try self.emitFixed(")", call_origin);
        } else {
            try self.emitFixed(switch (ret_scalar.base) {
                .bigint => "0",
                .text => "''",
                .boolean => "FALSE",
                .uuid, .timestamptz, .binary => unreachable,
            }, call_origin);
        }
        try self.emitFixed("ELSE (", call_origin);
        var body_cursor: usize = 0;
        try self.lowerExpression(&fn_env, expr_tokens, &body_cursor, 0, false, depth + 1);
        try self.emitFixed(") END", call_origin);
    } else {
        var body_cursor: usize = 0;
        try self.lowerExpression(&fn_env, expr_tokens, &body_cursor, 0, hoistable, depth + 1);
    }
    try self.emitFixed(")", call_origin);
}

fn emitHoistedLet(self: *Self, caller_env: *const Env, h_name: []const u8, expected: Annotations.Expected, param_name: []const u8, arg_tokens: []const s.Token, arg_offset: usize, depth: usize) !void {
    const hoist = self.hoist.?;
    var sub: Self = .{
        .compiler = self.compiler,
        .catalog = self.catalog,
        .scratch = self.scratch,
        .output = self.scratch,
        .writer = hoist.writer,
        .sites = &hoist.sites,
        .origins = &hoist.origins,
        .obligations = &hoist.obligations,
        .next_id = self.next_id,
    };
    const origin = sub.makeOrigin(caller_env, arg_offset);
    try sub.emitFixed("LET", origin);
    try sub.emitQuotedRaw(h_name, origin);
    try sub.emitFixed("=", origin);
    var cursor: usize = 0;
    try sub.lowerExpression(caller_env, arg_tokens, &cursor, 0, false, depth);
    try sub.emitFixed(";", origin);
    try hoist.obligations.append(self.scratch, .{
        .target = .{ .binding = h_name },
        .expected = expected,
        .name = param_name,
    });
    hoist.writer = sub.writer;
    self.next_id = sub.next_id;
}

fn validateUnusedQueueArg(self: *Self, fp: FnParam, call_offset: usize, depth: usize) !void {
    var sub_sites: std.ArrayList(Operands.Site) = .empty;
    var sub_origins: std.ArrayList(Operands.Origin) = .empty;
    var sub_obs: std.ArrayList(Annotations.Obligation) = .empty;
    var sub: Self = .{
        .compiler = self.compiler,
        .catalog = self.catalog,
        .scratch = self.scratch,
        .output = self.scratch,
        .writer = .{ .allocator = self.scratch, .limit = f.ApplicationProgram.max_source_bytes },
        .sites = &sub_sites,
        .origins = &sub_origins,
        .obligations = &sub_obs,
        .next_id = self.next_id,
        .in_queue_predicate = true,
        .queue_name = self.queue_name,
        .input_emitted = self.input_emitted,
    };
    const origin: Operands.Origin = .{ .start = 0, .end = 0, .source = call_offset, .file = fp.closure.file, .call = fp.closure.call };
    try sub.emitFixed("CREATE DATAFLOW \"__transit$qchk\" FROM QUEUE", origin);
    try sub.emitQuotedIdentifier(self.queue_name, origin);
    try sub.emitFixed("AS", origin);
    try sub.emitFixed(self.input_emitted, origin);
    try sub.emitFixed("WHERE", origin);
    try sub.emitParamClosure(fp, origin, false, depth);
    try sub.emitFixed("IS NOT NULL AS BEGIN END", origin);
    self.next_id = sub.next_id;

    const sql = sub.writer.bytes.items;
    var at: f.Sql.Location = .{ .offset = std.math.maxInt(usize) };
    const run_check = struct {
        fn run(comp: *Compiler, cat: *Catalog, raw_sql: []const u8, loc: *f.Sql.Location, sc: std.mem.Allocator, st: []const Operands.Site, org: []const Operands.Origin, obs: []const Annotations.Obligation) !void {
            var analysis = try ProgramCheck.analyze(cat, raw_sql, loc);
            defer analysis.deinit();
            _ = try Annotations.check(sc, sc, comp.graph, cat, analysis.parsed.program, &analysis.bound, raw_sql, st, org, obs, &comp.context, &comp.work, comp.limits.work);
        }
    }.run;
    run_check(self.compiler, self.catalog, sql, &at, self.scratch, sub_sites.items, sub_origins.items, sub_obs.items) catch |err| {
        const err_offset = self.compiler.context.offset orelse at.offset;
        for (sub_origins.items) |o| if (err_offset >= o.start and err_offset < o.end) {
            if (o.file) |of| self.compiler.file = of;
            self.compiler.offset = o.source;
            if (o.call) |c| self.compiler.call_site = Compiler.location(self.compiler.graph.sources[c.file], c.offset);
            break;
        };
        self.compiler.context.offset = null;
        return err;
    };
    for (sub_sites.items) |s_item| {
        if (s_item.value == .nominal) {
            // Mirror consumption into parent sites if needed; parent never emitted it, so no unconsumed parent site exists.
        }
    }
}

fn emitParamClosure(self: *Self, fp: FnParam, ref_origin: Operands.Origin, hoistable: bool, depth: usize) !void {
    if (fp.hoisted) |h_name| {
        try self.emitQuotedRaw(h_name, ref_origin);
        return;
    }
    if (self.writer.len() != 0) try self.writer.writeByte(' ');
    const outer_start = self.writer.len();
    try self.writer.writeByte('(');
    var open_rec = ref_origin;
    open_rec.start = outer_start;
    open_rec.end = self.writer.len();
    try self.origins.append(self.output, open_rec);

    var sub_env = fp.closure.env.*;
    sub_env.call = fp.closure.call;
    var cursor: usize = 0;
    try self.lowerExpression(&sub_env, fp.closure.tokens, &cursor, 0, hoistable, depth + 1);

    try self.emitFixed(")", ref_origin);
    const outer_end = self.writer.len();
    const core = try unwrapCore(self.scratch, self.writer.bytes.items, outer_start, outer_end);
    try self.obligations.append(self.output, .{
        .target = .{ .span = .{ .start = core.start, .end = core.end } },
        .expected = fp.expected,
        .name = fp.name,
    });
}

fn unwrapCore(scratch: std.mem.Allocator, sql: []const u8, outer_start: usize, outer_end: usize) !struct { start: usize, end: usize } {
    const SpanItem = struct { start: usize, end: usize, kind: f.SqlInput.Kind };
    var list: std.ArrayList(SpanItem) = .empty;
    var scan = try f.SqlInput.SourceScan.init(sql[outer_start..outer_end]);
    while (try scan.next()) |tok| {
        if (tok.kind == .space or tok.kind == .comment) continue;
        try list.append(scratch, .{ .start = outer_start + tok.start, .end = outer_start + tok.end, .kind = tok.kind });
    }
    var toks = list.items;
    var end_pos = outer_end;
    while (toks.len >= 2 and toks[0].kind == .symbol and sql[toks[0].start] == '(' and
        toks[toks.len - 1].kind == .symbol and sql[toks[toks.len - 1].start] == ')')
    {
        var depth: usize = 0;
        var wraps_all = true;
        for (toks[0 .. toks.len - 1]) |tok| {
            if (tok.kind == .symbol and sql[tok.start] == '(') {
                depth += 1;
            } else if (tok.kind == .symbol and sql[tok.start] == ')') {
                depth -= 1;
                if (depth == 0) {
                    wraps_all = false;
                    break;
                }
            }
        }
        if (!wraps_all or depth != 1) break;
        end_pos = toks[toks.len - 1].start;
        toks = toks[1 .. toks.len - 1];
    }
    if (toks.len == 0) return error.InvalidSourceSyntax;
    return .{ .start = toks[0].start, .end = end_pos };
}

fn lowerPrimary(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, hoistable: bool, depth: usize) anyerror!void {
    const text = self.compiler.graph.sources[env.file].text;
    const tok = tokens[i.*];
    if (tokenWord(text, tok, "NOT")) {
        try self.requireEmitWord(env, tokens, i, "NOT");
        return self.lowerExpression(env, tokens, i, 3, hoistable, depth + 1);
    }
    if (tokenSymbol(text, tok, '-')) {
        try self.requireEmitSymbol(env, tokens, i, "-");
        return self.lowerExpression(env, tokens, i, 6, hoistable, depth + 1);
    }
    if (tokenSymbol(text, tok, '(')) {
        try self.requireEmitSymbol(env, tokens, i, "(");
        try self.lowerExpression(env, tokens, i, 0, hoistable, depth + 1);
        try self.requireEmitSymbol(env, tokens, i, ")");
    } else if (tokenSymbol(text, tok, '$')) {
        try self.emitValueHole(env, tokens, i);
    } else if (tokenWord(text, tok, "NULL") or tokenWord(text, tok, "TRUE") or tokenWord(text, tok, "FALSE")) {
        try self.emitOriginalToken(env, text, tokens, i.*);
        i.* += 1;
    } else if (tokenWord(text, tok, "CASE")) {
        try self.requireEmitWord(env, tokens, i, "CASE");
        try self.requireEmitWord(env, tokens, i, "WHEN");
        try self.lowerExpression(env, tokens, i, 0, hoistable, depth + 1);
        try self.requireEmitWord(env, tokens, i, "THEN");
        try self.lowerExpression(env, tokens, i, 0, false, depth + 1);
        try self.requireEmitWord(env, tokens, i, "ELSE");
        try self.lowerExpression(env, tokens, i, 0, false, depth + 1);
        try self.requireEmitWord(env, tokens, i, "END");
    } else if (tokenWord(text, tok, "CAST")) {
        try self.requireEmitWord(env, tokens, i, "CAST");
        try self.requireEmitSymbol(env, tokens, i, "(");
        try self.lowerExpression(env, tokens, i, 0, hoistable, depth + 1);
        try self.requireEmitWord(env, tokens, i, "AS");
        try self.requireEmitWord(env, tokens, i, "TEXT");
        try self.requireEmitSymbol(env, tokens, i, ")");
    } else if (i.* + 1 < tokens.len and tokens[i.* + 1].kind == .string and (tokenWord(text, tok, "UUID") or tokenWord(text, tok, "TIMESTAMP") or tokenWord(text, tok, "TIMESTAMPTZ") or tokenWord(text, tok, "X"))) {
        try self.emitOriginalToken(env, text, tokens, i.*);
        i.* += 1;
        try self.emitOriginalToken(env, text, tokens, i.*);
        i.* += 1;
    } else if (tok.kind == .number or tok.kind == .string) {
        try self.emitOriginalToken(env, text, tokens, i.*);
        i.* += 1;
    } else {
        const raw = text[tok.start..tok.end];
        if (i.* + 3 < tokens.len and tokenSymbol(text, tokens[i.* + 1], '.') and tokenSymbol(text, tokens[i.* + 3], '(')) {
            const callee_ref = resolveQualifiedFunction(self.compiler, env.file, env.bindings, env.schemas, text, tokens, i, tok.start) catch |err| {
                if (env.call) |prior| self.compiler.call_site = Compiler.location(self.compiler.graph.sources[prior.file], prior.offset);
                return err;
            };
            try self.expandFunctionCall(env, callee_ref, tokens, i, tok.start, hoistable, depth + 1);
        } else if (i.* + 1 < tokens.len and tokenSymbol(text, tokens[i.* + 1], '(')) {
            if (tok.kind == .word and std.ascii.eqlIgnoreCase(raw, "ROW")) {
                try self.requireEmitWord(env, tokens, i, "ROW");
                try self.lowerArguments(env, tokens, i, hoistable, depth + 1);
            } else if (tok.kind == .word) {
                const local_callee = resolveLocalFunction(self.compiler, env.file, env.bindings, raw, tok.start) catch |err| {
                    if (env.call) |prior| self.compiler.call_site = Compiler.location(self.compiler.graph.sources[prior.file], prior.offset);
                    return err;
                };
                if (local_callee) |callee_ref| {
                    i.* += 1;
                    try self.expandFunctionCall(env, callee_ref, tokens, i, tok.start, hoistable, depth + 1);
                } else {
                    if (env.mode == .function) {
                        const lower = try std.ascii.allocLowerString(self.scratch, raw);
                        if (builtinPurity(lower) == .impure) {
                            self.setError(env, tok.start);
                            return error.ImpureSourceFunction;
                        }
                    }
                    try self.emitOriginalToken(env, text, tokens, i.*);
                    i.* += 1;
                    try self.lowerArguments(env, tokens, i, hoistable, depth + 1);
                }
            } else {
                if (env.mode == .function) {
                    const decoded = try self.decodeProgramName(text, tok);
                    if (builtinPurity(decoded) == .impure) {
                        self.setError(env, tok.start);
                        return error.ImpureSourceFunction;
                    }
                }
                try self.emitOriginalToken(env, text, tokens, i.*);
                i.* += 1;
                try self.lowerArguments(env, tokens, i, hoistable, depth + 1);
            }
        } else {
            const decoded = try self.decodeProgramName(text, tok);
            if (tok.kind == .word and env.mode == .function and bareWordImpure(decoded)) {
                self.setError(env, tok.start);
                return error.ImpureSourceFunction;
            }
            i.* += 1;
            if (tok.kind == .word) {
                for (env.row_vars) |rv| if (std.mem.eql(u8, rv.original, decoded)) {
                    if (i.* + 1 < tokens.len and tokenSymbol(text, tokens[i.*], '.')) {
                        i.* += 1;
                        const field_tok = tokens[i.*];
                        const field_name = try self.decodeProgramName(text, field_tok);
                        i.* += 1;
                        for (rv.fields) |fv| if (std.mem.eql(u8, fv.name, field_name)) {
                            try self.emitQuotedRaw(fv.emitted, self.makeOrigin(env, tok.start));
                            while (i.* < tokens.len and tokenSymbol(text, tokens[i.*], '.')) {
                                try self.requireEmitSymbol(env, tokens, i, ".");
                                try self.emitOriginalToken(env, text, tokens, i.*);
                                i.* += 1;
                            }
                            return;
                        };
                        self.setError(env, field_tok.start);
                        return error.UnknownProgramField;
                    }
                    if (i.* < tokens.len and tokenWord(text, tokens[i.*], "IS")) {
                        i.* += 1;
                        const not_null = i.* < tokens.len and tokenWord(text, tokens[i.*], "NOT");
                        if (not_null) i.* += 1;
                        if (i.* >= tokens.len or !tokenWord(text, tokens[i.*], "NULL")) {
                            self.setError(env, tok.start);
                            return error.InvalidSourceSyntax;
                        }
                        i.* += 1;
                        try self.emitFixed(if (not_null) "TRUE" else "FALSE", self.makeOrigin(env, tok.start));
                        return;
                    }
                    self.setError(env, tok.start);
                    return error.ProgramTypeMismatch;
                };
                for (env.fn_params) |fp| if (fp.name.len != 0 and std.mem.eql(u8, fp.name, decoded)) {
                    try self.emitParamClosure(fp, self.makeOrigin(env, tok.start), hoistable, depth + 1);
                    while (i.* < tokens.len and tokenSymbol(text, tokens[i.*], '.')) {
                        try self.requireEmitSymbol(env, tokens, i, ".");
                        try self.emitOriginalToken(env, text, tokens, i.*);
                        i.* += 1;
                    }
                    return;
                };
            }
            var emitted_sym = false;
            if (env.rename_locals) {
                for (env.symbols.items) |sym| if (std.mem.eql(u8, sym.original, decoded)) {
                    try self.emitQuotedRaw(sym.emitted, self.makeOrigin(env, tok.start));
                    emitted_sym = true;
                    break;
                };
            }
            if (!emitted_sym) {
                if (std.mem.startsWith(u8, decoded, "__t$")) {
                    self.setError(env, tok.start);
                    return error.UnknownProgramVariable;
                }
                try self.emitOriginalToken(env, text, tokens, i.* - 1);
            }
        }
    }
    while (i.* < tokens.len and tokenSymbol(text, tokens[i.*], '.')) {
        try self.requireEmitSymbol(env, tokens, i, ".");
        try self.emitOriginalToken(env, text, tokens, i.*);
        i.* += 1;
    }
}

fn lowerExpression(self: *Self, env: *const Env, tokens: []const s.Token, i: *usize, minimum: u8, hoistable: bool, depth: usize) anyerror!void {
    try self.compiler.tick();
    if (depth > self.compiler.limits.depth) {
        self.setError(env, if (i.* < tokens.len) tokens[i.*].start else 0);
        return error.SourceDepthLimit;
    }
    const text = self.compiler.graph.sources[env.file].text;
    try self.lowerPrimary(env, tokens, i, hoistable, depth + 1);
    while (i.* < tokens.len) {
        if (minimum <= 3 and tokenWord(text, tokens[i.*], "IS")) {
            try self.requireEmitWord(env, tokens, i, "IS");
            if (i.* < tokens.len and tokenWord(text, tokens[i.*], "NOT")) try self.requireEmitWord(env, tokens, i, "NOT");
            try self.requireEmitWord(env, tokens, i, "NULL");
            continue;
        }
        const cur = tokens[i.*];
        const prec: u8 = if (tokenWord(text, cur, "OR")) 1 else if (tokenWord(text, cur, "AND")) 2 else if (tokenSymbol(text, cur, '=') or tokenSymbol(text, cur, '<') or tokenSymbol(text, cur, '>')) 3 else if (tokenSymbol(text, cur, '|')) 4 else if (tokenSymbol(text, cur, '+') or tokenSymbol(text, cur, '-')) 5 else break;
        if (prec < minimum) break;
        const origin = self.makeOrigin(env, cur.start);
        if (prec == 1) {
            i.* += 1;
            try self.emitFixed("OR", origin);
            try self.lowerExpression(env, tokens, i, prec + 1, false, depth + 1);
        } else if (prec == 2) {
            i.* += 1;
            try self.emitFixed("AND", origin);
            try self.lowerExpression(env, tokens, i, prec + 1, false, depth + 1);
        } else if (prec == 4) {
            i.* += 2;
            try self.emitFixed("||", origin);
            try self.lowerExpression(env, tokens, i, prec + 1, hoistable, depth + 1);
        } else if (prec == 3) {
            const is_lt = tokenSymbol(text, cur, '<');
            const is_gt = tokenSymbol(text, cur, '>');
            i.* += 1;
            if ((is_lt or is_gt) and i.* < tokens.len and tokens[i.* - 1].end == tokens[i.*].start) {
                if (tokenSymbol(text, tokens[i.*], '=')) {
                    i.* += 1;
                    try self.emitFixed(if (is_lt) "<=" else ">=", origin);
                } else if (is_lt and tokenSymbol(text, tokens[i.*], '>')) {
                    i.* += 1;
                    try self.emitFixed("<>", origin);
                } else {
                    try self.emitFixed(if (is_lt) "<" else ">", origin);
                }
            } else {
                try self.emitFixed(if (is_lt) "<" else if (is_gt) ">" else "=", origin);
            }
            try self.lowerExpression(env, tokens, i, prec + 1, hoistable, depth + 1);
        } else {
            const plus = tokenSymbol(text, cur, '+');
            i.* += 1;
            try self.emitFixed(if (plus) "+" else "-", origin);
            try self.lowerExpression(env, tokens, i, prec + 1, hoistable, depth + 1);
        }
    }
}

fn tokenWord(text: []const u8, tok: s.Token, expected: []const u8) bool {
    return tok.kind == .word and std.ascii.eqlIgnoreCase(text[tok.start..tok.end], expected);
}

fn tokenSymbol(text: []const u8, tok: s.Token, expected: u8) bool {
    return tok.kind == .symbol and tok.end - tok.start == 1 and text[tok.start] == expected;
}

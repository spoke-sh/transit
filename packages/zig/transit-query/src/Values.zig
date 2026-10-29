//! Versioned foreign values around the shared v1 source/plan/Arrow model.
//! Integers wider than the protocol counter and float bits never pass as JSON
//! numbers. All returned byte strings belong to the supplied result allocator.
const std = @import("std");
pub const query = @import("root.zig");
const q = query;
const m = q.fuze.Unified;
const f = q.fuze;
const types = f.Types;
const d = q.document.JsonValues;
const a = f.QueryValues;
const Allocator = std.mem.Allocator;
pub const maximum_json_bytes = a.maximum_json_bytes;
pub const json_limits = a.json_limits;
pub const preflight = a.preflight;
pub const parse = a.parse;
pub const unsigned = a.unsigned;
pub const unhex = a.unhex;
/// Direct Table routing uses the service audience, independently of a query
/// worker PID. Unrestricted data identities cross JSON as decimal strings.
pub const DirectConnection = struct {
    scope: q.catalog.TableValues.Scope,
    branch: []const u8,
    audience: u64,
    principal: u64,
    role: ?u64 = null,
    pub fn native(self: DirectConnection) !q.catalog.DirectTableProtocol.Connection {
        const result: q.catalog.DirectTableProtocol.Connection = .{ .scope = try self.scope.native(), .branch = try unsigned(self.branch), .audience = self.audience, .principal = self.principal, .role = self.role };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: q.catalog.DirectTableProtocol.Connection) !DirectConnection {
        try value.validate();
        return .{ .scope = try q.catalog.TableValues.Scope.foreign(allocator, value.scope), .branch = try a.decimal(allocator, value.branch), .audience = value.audience, .principal = value.principal, .role = value.role };
    }
};
pub const Capture = struct {
    executor: u64,
    operation: []const u8,
    expected: struct { partition: []const u8, next_lsn: []const u8 },
    selection: q.catalog.DirectTableProtocol.CaptureSelection = .exact,
    pub fn native(self: Capture) !q.Bundle.Capture {
        try q.UnifiedRecords.identity(self.executor);
        const result: q.Bundle.Capture = .{ .executor = self.executor, .operation = try unsigned(self.operation), .expected = .{ .partition = try unsigned(self.expected.partition), .next_lsn = try unsigned(self.expected.next_lsn) }, .selection = self.selection };
        if (result.operation == 0) return error.InvalidQueryAuthorization;
        try result.expected.validate();
        return result;
    }
};

test "neutral capture preserves full-width cuts and rejects rounded JSON numbers" {
    const t = std.testing;
    const encoded = "{\"executor\":7,\"operation\":\"18446744073709551615\",\"expected\":{\"partition\":\"18446744073709551615\",\"next_lsn\":\"18446744073709551615\"}}";
    const parsed = try parse(Capture, t.allocator, encoded);
    defer parsed.deinit();
    const value = try parsed.value.native();
    try t.expectEqual(std.math.maxInt(u64), value.operation);
    try t.expectEqual(std.math.maxInt(u64), value.expected.partition);
    try t.expectEqual(std.math.maxInt(u64), value.expected.next_lsn);
    const rounded = "{\"executor\":7,\"operation\":18446744073709551615,\"expected\":{\"partition\":\"1\",\"next_lsn\":\"1\"}}";
    try t.expectError(error.UnexpectedToken, parse(Capture, t.allocator, rounded));
    var bad = parsed.value;
    bad.operation = "01";
    try t.expectError(error.InvalidDocumentInteger, bad.native());
}
pub const Column = a.Column;
pub const columns = a.columns;
pub const foreignColumns = a.foreignColumns;
pub const Scalar = a.Scalar;
pub const scalar = a.scalar;
pub const foreignScalar = a.foreignScalar;
/// KV/Document decoding remains explicitly limited to its six scalar decoders.
pub const DecoderColumn = struct {
    name: []const u8,
    type: m.Type,
    pub fn native(self: DecoderColumn) !m.Column {
        return .{ .name = try m.Name.init(self.name), .type = self.type };
    }
    pub fn fromNative(alloc: Allocator, value: m.Column) !DecoderColumn {
        return .{ .name = try alloc.dupe(u8, value.name.slice()), .type = value.type };
    }
};
pub const Projection = struct {
    pub const json_schema_sequence_bounds = .{ .path = 8 };
    column: DecoderColumn,
    path: []const []const u8,
    relative: bool = false,
    mode: @FieldType(q.SourceDefinition.Projection, "mode") = .scalar,
    text_bytes: u16 = m.max_cell_bytes,
    text_steps: u16 = 4096,
};
fn path(alloc: Allocator, names: []const []const u8) ![]const q.document.Model.Name {
    if (names.len > 8) return error.InvalidQueryPath;
    const result = try alloc.alloc(q.document.Model.Name, names.len);
    for (result, names) |*out, in| out.* = try q.document.Model.Name.init(in);
    return result;
}
fn foreignPath(alloc: Allocator, names: []const q.document.Model.Name) ![]const []const u8 {
    const result = try alloc.alloc([]const u8, names.len);
    for (result, names) |*out, in| out.* = try alloc.dupe(u8, in.slice());
    return result;
}
pub const Source = struct {
    version: u8 = 1,
    resource: u64,
    source: union(enum) {
        kv: struct { prefix: []const u8, key: q.SourceDefinition.Decoder, value: q.SourceDefinition.Decoder },
        table: struct {
            pub const json_schema_sequence_bounds = .{ .collations = q.SourceDefinition.max_columns };
            scope: q.catalog.TableValues.Scope,
            owner: u64,
            branch: []const u8,
            namespace: u64,
            object: []const u8,
            interpretation: struct { revision: []const u8, digest: [32]u8, bytes: []const u8, schema: [32]u8 },
            row_type: types.Type,
            collations: []const f.TableSchema.Collation,
        },
        document: struct {
            pub const json_schema_sequence_bounds = .{ .expand = 8, .projections = m.max_columns };
            reference: d.Reference,
            change_format: u32 = 1,
            expand: ?[]const []const u8 = null,
            projections: []const Projection,
        },
    },
    pub fn native(self: Source, alloc: Allocator) !q.SourceDefinition {
        const source: @FieldType(q.SourceDefinition, "source") = switch (self.source) {
            .kv => |v| .{ .kv = .{ .prefix = try q.protocol.Value.init(try unhex(alloc, v.prefix, q.protocol.Growth.key_bytes)), .key = v.key, .value = v.value } },
            .table => |v| table: {
                const scope = try v.scope.native();
                const branch = try unsigned(v.branch);
                const object = try unsigned(v.object);
                break :table .{ .table = .{ .scope = scope, .owner = v.owner, .branch = branch, .namespace = v.namespace, .object = object, .interpretation = .{ .interpretation = .{ .object = .{ .scope = scope, .branch = branch, .object = object }, .revision = try unsigned(v.interpretation.revision), .digest = v.interpretation.digest }, .content = .{ .bytes = try unsigned(v.interpretation.bytes), .sha256 = v.interpretation.digest }, .schema_fingerprint = v.interpretation.schema, .retired = false }, .row_type = try v.row_type.cloneInto(alloc), .collations = try f.QueryCollations.fromSlice(v.row_type, v.collations) } };
            },
            .document => |v| blk: {
                if (v.projections.len == 0 or v.projections.len > m.max_columns) return error.InvalidProjection;
                const projections = try alloc.alloc(q.SourceDefinition.Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try in.column.native(), .path = try path(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try v.reference.native(), .change_format = v.change_format, .expand = if (v.expand) |names| try path(alloc, names) else null, .projections = projections } };
            },
        };
        const result: q.SourceDefinition = .{ .version = self.version, .resource = self.resource, .source = source };
        var storage: [q.SourceDefinition.max_columns]types.Field = undefined;
        _ = try result.schema(&storage);
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.SourceDefinition) !Source {
        return .{ .version = value.version, .resource = value.resource, .source = switch (value.source) {
            .kv => |v| .{ .kv = .{ .prefix = try a.hex(alloc, v.prefix.slice()), .key = v.key, .value = v.value } },
            .table => |v| .{ .table = .{ .scope = try q.catalog.TableValues.Scope.foreign(alloc, v.scope), .owner = v.owner, .branch = try a.decimal(alloc, v.branch), .namespace = v.namespace, .object = try a.decimal(alloc, v.object), .interpretation = .{ .revision = try a.decimal(alloc, v.interpretation.interpretation.revision), .digest = v.interpretation.interpretation.digest, .bytes = try a.decimal(alloc, v.interpretation.content.bytes), .schema = v.interpretation.schema_fingerprint }, .row_type = try v.row_type.cloneInto(alloc), .collations = try alloc.dupe(f.TableSchema.Collation, v.collations.columns[0..v.row_type.structure.len]) } },
            .document => |v| blk: {
                const projections = try alloc.alloc(Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try DecoderColumn.fromNative(alloc, in.column), .path = try foreignPath(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try d.Reference.fromNative(alloc, v.reference), .change_format = v.change_format, .expand = if (v.expand) |names| try foreignPath(alloc, names) else null, .projections = projections } };
            },
        } };
    }
};
pub const PredicateAtom = a.PredicateAtom;
pub const PredicateInstruction = a.PredicateInstruction;
pub const Predicate = a.Predicate;
pub const Plan = a.Plan;
pub const Limits = struct {
    pages: []const u8,
    segments: []const u8,
    result_bytes: []const u8,
    pub fn native(self: Limits) !q.Bundle.Limits {
        const result: q.Bundle.Limits = .{ .pages = try unsigned(self.pages), .segments = try unsigned(self.segments), .result_bytes = try unsigned(self.result_bytes) };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle.Limits) !Limits {
        return .{ .pages = try a.decimal(alloc, value.pages), .segments = try a.decimal(alloc, value.segments), .result_bytes = try a.decimal(alloc, value.result_bytes) };
    }
};
pub const Bundle = struct {
    source: Source,
    plan: Plan,
    limits: Limits,
    authorization: ?q.QueryAuthorization = null,
    pub fn native(self: Bundle, alloc: Allocator) !q.Bundle {
        const source = try self.source.native(alloc);
        var fields: [q.SourceDefinition.max_columns]types.Field = undefined;
        const schema = try (try source.schema(&fields)).cloneInto(alloc);
        const result: q.Bundle = .{ .source = source, .plan = try self.plan.native(alloc, schema, try source.fingerprint()), .limits = try self.limits.native(), .authorization = self.authorization };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle) !Bundle {
        return .{ .source = try Source.fromNative(alloc, value.source), .plan = try Plan.fromNative(alloc, value.plan), .limits = try Limits.fromNative(alloc, value.limits), .authorization = value.authorization };
    }
};
pub const Alternative = a.Alternative;
pub const Cell = a.Cell;
pub const foreignCell = a.foreignCell;
pub const rows = a.rows;
pub const Action = union(enum) {
    prepare: Bundle,
    decode: []const u8,
    source: Source,
    inspect_arrow: struct { columns: []const Column, rows: u8, ipc: []const u8 },
};
pub const Result = union(enum) {
    pub const json_schema_sequence_bounds = .{ .rows = q.SourceDefinition.max_columns };
    pub const json_schema_outer_sequence_bounds = .{ .rows = f.LogicalArrow.max_rows };
    prepared: struct { bytes: []const u8, spec: q.station.Publication.Spec },
    bundle: Bundle,
    source: struct { bytes: []const u8, digest: [32]u8, declaration: [32]u8, columns: []const Column },
    rows: []const []const Cell,
};
pub fn apply(alloc: Allocator, action: Action) !Result {
    switch (action) {
        .prepare => |v| {
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            const bytes = try (try v.native(alloc)).encode(&buffer);
            return .{ .prepared = .{ .bytes = try a.hex(alloc, bytes), .spec = try q.station.Publication.Digest.of(q.Bundle.format, bytes) } };
        },
        .decode => |v| return .{ .bundle = try Bundle.fromNative(alloc, try q.Bundle.decode(alloc, try unhex(alloc, v, q.Bundle.max_bytes))) },
        .source => |v| {
            const native = try v.native(alloc);
            var storage: [q.SourceDefinition.max_columns]types.Field = undefined;
            var buffer: [q.SourceDefinition.max_bytes]u8 = undefined;
            return .{ .source = .{ .bytes = try a.hex(alloc, try native.encode(&buffer)), .digest = try native.fingerprint(), .declaration = try q.Bundle.declaration(native), .columns = try foreignColumns(alloc, try native.schema(&storage)) } };
        },
        .inspect_arrow => |v| {
            const workspace = try alloc.alloc(u8, m.Arrow.working_bytes);
            var decoded = try f.LogicalInspect.decode(alloc, try columns(alloc, v.columns), try unhex(alloc, v.ipc, f.LogicalArrow.segment_bytes), v.rows, workspace);
            defer decoded.deinit();
            return .{ .rows = try rows(alloc, &decoded) };
        },
    }
}

test "neutral programs retain owned literals and exact bundle publication identity" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var literal = [_]u8{ 'o', 'k' };
    const bundle: Bundle = .{
        .source = .{ .resource = 7, .source = .{ .kv = .{ .prefix = "", .key = .{ .type = .binary }, .value = .{ .type = .utf8 } } } },
        .plan = .{ .projection = &.{1}, .output_names = &.{"label"}, .predicate = .{ .program = &.{
            .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .utf8 = &literal } } } },
            .negate,
            .{ .atom = .{ .state = .{ .column = 1, .value = .null } } },
            .disjunction,
        } } },
        .limits = .{ .pages = "100", .segments = "100", .result_bytes = "1048576" },
    };
    const prepared = (try apply(alloc, .{ .prepare = bundle })).prepared;
    var restored = (try apply(alloc, .{ .decode = prepared.bytes })).bundle;
    literal[0] = 'n';
    try t.expectEqualStrings("ok", restored.plan.predicate.program[0].atom.compare.value.utf8);
    const repeated = (try apply(alloc, .{ .prepare = restored })).prepared;
    try t.expectEqualStrings(prepared.bytes, repeated.bytes);
    try t.expectEqualDeep(prepared.spec, repeated.spec);
    restored.plan.predicate = .{ .program = &.{.conjunction} };
    try t.expectError(error.InvalidPredicateProgram, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &@as([65]PredicateInstruction, @splat(.negate)) };
    try t.expectError(error.PredicateTooLarge, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &.{ .{ .atom = .all }, .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .unsigned = "1" } } } }, .disjunction } };
    try t.expectError(error.TypeMismatch, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &.{ .{ .atom = .all }, .{ .atom = .{ .state = .{ .column = 2, .value = .null } } }, .disjunction } };
    try t.expectError(error.UnknownColumn, apply(alloc, .{ .prepare = restored }));
}

test "neutral JSON rejects recursive input before allocating and retains typed validation" {
    const t = std.testing;
    var no_memory = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var bytes: [512]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try out.writeAll("{\"unknown\":");
    for (0..json_limits.depth) |_| try out.writeByte('[');
    for (0..json_limits.depth) |_| try out.writeByte(']');
    try out.writeByte('}');
    try t.expectError(error.JsonDepthExceeded, parse(q.Workspace.Request, no_memory.allocator(), out.buffered()));
    try t.expectError(error.InvalidUtf8, parse(q.Workspace.Request, no_memory.allocator(), "{\"compile\":{\"sql\":\"\xff\"}}"));
    try t.expectError(error.OutOfMemory, parse(q.Workspace.Request, no_memory.allocator(), "{\"compile\":{\"sql\":\"SELECT * FROM items\"}}"));
    try t.expectError(error.UnknownField, parse(q.Workspace.Request, t.allocator, "{\"compile\":{\"sql\":\"SELECT * FROM items\",\"extra\":[]}}"));
    try t.expectError(error.DuplicateField, parse(q.Workspace.Request, t.allocator, "{\"compile\":{\"sql\":\"SELECT * FROM items\",\"sql\":\"SELECT 1\"}}"));
    const oversized = try t.allocator.alloc(u8, maximum_json_bytes + 1);
    defer t.allocator.free(oversized);
    try t.expectError(error.JsonByteBudgetExceeded, parse(q.Workspace.Request, no_memory.allocator(), oversized));
}

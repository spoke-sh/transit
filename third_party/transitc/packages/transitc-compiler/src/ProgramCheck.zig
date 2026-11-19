//! Bind a public-data program against proposed resources using the runtime's
//! pure types. No native identity, permission or activation is established.
const std = @import("std");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
const a = f.ApplicationProgram;
const Catalog = @import("WorkingCatalog.zig");
const types = @import("SourceTypes.zig");
const Self = @This();
catalog: *Catalog,
resources: std.ArrayList(a.Types.Resource) = .empty,
entries: std.ArrayList(*const types.Table) = .empty,

pub const Checked = struct { schema_name: []const u8, name: []const u8, digest: [32]u8 };
/// All borrowed resource descriptions live in the caller's statement scratch.
pub const Analysis = struct {
    parsed: a.Owned,
    bound: a.Types.Bound,
    entries: []const *const types.Table,
    pub fn deinit(self: *Analysis) void {
        self.bound.deinit();
        self.parsed.deinit();
    }
};
pub fn analyze(catalog: *Catalog, sql: []const u8, location: *f.Sql.Location) !Analysis {
    var parsed = try a.parse(catalog.scratch, sql, location);
    errdefer parsed.deinit();
    if (parsed.program.name.len == 0 or parsed.program.name.len > p.Authorization.max_name_bytes or std.mem.indexOfScalar(u8, parsed.program.name, 0) != null) return error.InvalidCatalogName;
    if (parsed.program.schema) |s_name| {
        if (s_name.len == 0 or s_name.len > p.Authorization.max_name_bytes or std.mem.indexOfScalar(u8, s_name, 0) != null) return error.InvalidCatalogName;
    }
    var self: Self = .{ .catalog = catalog };
    try self.resource(parsed.program.queue_schema, parsed.program.queue, .queue);
    switch (parsed.program.body) {
        .instructions => |body| try self.block(body),
        .page => return error.ApplicationHostUnavailable,
    }
    if (parsed.program.failure) |failure| try self.block(failure.instructions);
    var bound = try a.Types.bind(catalog.scratch, parsed.program, self.resources.items, location);
    errdefer bound.deinit();
    try bound.requirements.requireAvailable(a.Types.Requirements.publicData());
    if (bound.native.count() != 0) return error.UnsupportedBuildProgramDependency;
    return .{ .parsed = parsed, .bound = bound, .entries = self.entries.items };
}
pub fn check(catalog: *Catalog, sql: []const u8, location: *f.Sql.Location) !Checked {
    var analysis = try analyze(catalog, sql, location);
    defer analysis.deinit();
    const parsed = analysis.parsed;
    if (parsed.program.predicate) |predicate| location.offset = predicate.span.start;
    try a.Predicate.validate(parsed.program, analysis.entries[0].schema);
    // Programs use canonical expansion in both passes. Preserve instruction
    // identities, atomic structure, scalar values and exact physical bindings.
    const encoded = try p.Json.valueAllocBounded(catalog.scratch, parsed.program, a.Codec.max_bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.program.v1\x00");
    hash.update(encoded);
    for (analysis.entries) |entry| {
        if (!std.mem.eql(u8, entry.schema_name, "public")) @import("Graph.zig").hashPart(&hash, entry.schema_name);
        @import("Graph.zig").hashPart(&hash, entry.name);
        @import("Graph.zig").hashPart(&hash, @tagName(entry.kind));
        hash.update(&try entry.schema.fingerprint());
    }
    return .{
        .schema_name = try catalog.output.dupe(u8, parsed.program.schema orelse "public"),
        .name = try catalog.output.dupe(u8, parsed.program.name),
        .digest = hash.finalResult(),
    };
}
fn resource(self: *Self, schema: ?[]const u8, name: []const u8, kind: types.ResourceKind) !void {
    const entry = try self.catalog.findResourceQualified(schema, name);
    if (entry.kind != kind) return error.SourceTypeMismatch;
    for (self.entries.items, self.resources.items) |prior, prior_res| {
        if (prior == entry and a.Types.sameResource(prior_res.schema, prior_res.name, schema, entry.name)) return;
        if (prior == entry) return error.DuplicateProgramResource;
    }
    // The installed ApplicationDeclaration can freeze thirteen dependencies.
    if (self.entries.items.len == 13) return error.ProgramTooComplex;
    if (entry.log) |log| if (log.configuration.partitioning.count != 1) return error.UnsupportedProgramPartitioning;
    const allocator = self.catalog.scratch;
    const fields = try allocator.alloc(a.Types.Field, entry.schema.columns.len);
    for (entry.schema.columns, fields) |column, *field| field.* = .{ .name = column.name, .value = try a.Schema.bindField(allocator, .{ .name = column.name, .type = column.type, .nullable = column.nullable }) };
    const keys = try allocator.alloc([]const u8, entry.schema.primary_key.len);
    for (entry.schema.primary_key, keys) |id, *key| key.* = entry.schema.columns[try entry.schema.index(id)].name;
    try self.resources.append(allocator, .{ .schema = schema, .name = entry.name, .kind = switch (kind) {
        .table => .table,
        .stream => .stream,
        .queue => .queue,
    }, .fields = fields, .key = keys });
    try self.entries.append(allocator, entry);
}
fn block(self: *Self, body: []const a.Instruction) anyerror!void {
    for (body) |instruction| switch (instruction.value) {
        .let => |binding| switch (binding.value) {
            .expression => {},
            .select => |read| try self.resource(read.schema, read.target, .table),
            .get, .effect => return error.ApplicationHostUnavailable,
        },
        .require => {},
        .atomic => |instructions| try self.block(instructions),
        .conditional => |condition| {
            try self.block(condition.yes);
            try self.block(condition.no);
        },
        .insert => |insert| try self.resource(insert.target_schema, insert.target, .table),
        .append => |append| try self.resource(append.target_schema, append.target, if (append.kind == .stream) .stream else .queue),
        .put, .handoff, .respond, .respond_error => return error.ApplicationHostUnavailable,
    };
}

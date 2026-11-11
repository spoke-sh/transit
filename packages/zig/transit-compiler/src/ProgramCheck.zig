//! Bind a public-data program against proposed resources using the runtime's
//! pure types. No native identity, permission or activation is established.
const std = @import("std");
const f = @import("transit_fuze");
const p = @import("transit_protocol");
const a = f.ApplicationProgram;
const Catalog = @import("WorkingCatalog.zig");
const types = @import("SourceTypes.zig");
const Self = @This();
catalog: *Catalog,
resources: std.ArrayList(a.Types.Resource) = .empty,
entries: std.ArrayList(*const types.Table) = .empty,

pub const Checked = struct { name: []const u8, digest: [32]u8 };
pub fn check(catalog: *Catalog, sql: []const u8, location: *f.Sql.Location) !Checked {
    var parsed = try a.parse(catalog.scratch, sql, location);
    defer parsed.deinit();
    if (parsed.program.name.len == 0 or parsed.program.name.len > p.Authorization.max_name_bytes or std.mem.indexOfScalar(u8, parsed.program.name, 0) != null) return error.InvalidCatalogName;
    var self: Self = .{ .catalog = catalog };
    try self.resource(parsed.program.queue, .queue);
    switch (parsed.program.body) {
        .instructions => |body| try self.block(body),
        .page => return error.ApplicationHostUnavailable,
    }
    if (parsed.program.failure) |failure| try self.block(failure.instructions);
    var bound = try a.Types.bind(catalog.scratch, parsed.program, self.resources.items, location);
    defer bound.deinit();
    try bound.requirements.requireAvailable(a.Types.Requirements.publicData());
    if (bound.native.count() != 0) return error.UnsupportedBuildProgramDependency;
    // Expanded raw/canonical SQL has identical token widths. Both parses must
    // preserve instruction identities, atomic structure, values and bindings.
    const encoded = try p.Json.valueAllocBounded(catalog.scratch, parsed.program, a.Codec.max_bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.program.v1\x00");
    hash.update(encoded);
    for (self.entries.items) |entry| {
        @import("Graph.zig").hashPart(&hash, entry.name);
        @import("Graph.zig").hashPart(&hash, @tagName(entry.kind));
        hash.update(&try entry.schema.fingerprint());
    }
    return .{ .name = try catalog.output.dupe(u8, parsed.program.name), .digest = hash.finalResult() };
}
fn resource(self: *Self, name: []const u8, kind: types.ResourceKind) !void {
    const entry = try self.catalog.findResource(name);
    if (entry.kind != kind) return error.SourceTypeMismatch;
    for (self.entries.items) |prior| if (prior == entry) return;
    // The installed ApplicationDeclaration can freeze thirteen dependencies.
    if (self.entries.items.len == 13) return error.ProgramTooComplex;
    for (entry.domains) |domain| if (domain != null) return error.UnsupportedNominalProgram;
    if (entry.log) |log| if (log.configuration.partitioning.count != 1) return error.UnsupportedProgramPartitioning;
    const allocator = self.catalog.scratch;
    const fields = try allocator.alloc(a.Types.Field, entry.schema.columns.len);
    for (entry.schema.columns, fields) |column, *field| field.* = .{ .name = column.name, .value = try a.Schema.bindField(allocator, .{ .name = column.name, .type = column.type, .nullable = column.nullable }) };
    const keys = try allocator.alloc([]const u8, entry.schema.primary_key.len);
    for (entry.schema.primary_key, keys) |id, *key| key.* = entry.schema.columns[try entry.schema.index(id)].name;
    try self.resources.append(allocator, .{ .name = entry.name, .kind = switch (kind) {
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
            .select => |read| try self.resource(read.target, .table),
            .get, .effect => return error.ApplicationHostUnavailable,
        },
        .require => {},
        .atomic => |instructions| try self.block(instructions),
        .conditional => |condition| {
            try self.block(condition.yes);
            try self.block(condition.no);
        },
        .insert => |insert| try self.resource(insert.target, .table),
        .append => |append| try self.resource(append.target, if (append.kind == .stream) .stream else .queue),
        .put, .handoff, .respond, .respond_error => return error.ApplicationHostUnavailable,
    };
}

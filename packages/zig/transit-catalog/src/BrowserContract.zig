//! Browser JSON schemas shared with the runtime renderer and consumers.
const std = @import("std");
const c = @import("root.zig");
pub const subprotocol = "transit.published.v1";
pub const ProviderDiscovery = struct { providers: []const []const u8, next: ?[]const u8 };
pub const Session = struct { authenticated: bool, provider: ?[]const u8, identity: ?[]const u8, bound: bool };
pub const LoggedOut = struct { authenticated: bool };
pub const Failure = struct { err: []const u8 };
pub const Cell = struct {
    pub fn jsonSchema(out: *std.json.Stringify) !void {
        try out.beginObject();
        try c.protocol.Schema.field(out, "type", &[_][]const u8{ "string", "number", "boolean", "null" });
        try c.protocol.Schema.field(out, "description", "Integers and decimal coefficients are canonical strings; decimal scale comes from the column type. Missing, conflict and type-error cells refuse the whole snapshot.");
        try out.endObject();
    }
};
pub const Attribution = struct {
    resource_object: []const u8,
    publication_revision: []const u8,
    source_object: []const u8,
    source_revision: []const u8,
    source_partition: []const u8,
    source_next_lsn: []const u8,
    watermark_lsn: []const u8,
    row_count: []const u8,
    retention: enum { current_cut_unpinned },
    complete: bool,
};
pub const Column = struct { name: []const u8, type: c.fuze.Types.Type, nullable: bool };
pub const Snapshot = struct {
    pub const json_schema_sequence_bounds = .{ .columns = 128, .rows = 128 };
    pub const json_schema_outer_sequence_bounds = .{ .rows = 10000 };
    type: enum { snapshot },
    view: []const u8,
    columns: []const Column,
    rows: []const []const Cell,
    attribution: Attribution,
};

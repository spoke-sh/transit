//! Pure computation-control syntax. Catalog resolution and current authorization
//! remain with the service; this parser neither publishes nor activates work.
const p = @import("transit_protocol");
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const Reference = @import("SqlReference.zig");
const Authorization = @import("AuthorizationSql.zig");
pub const Statement = struct { schema: ?[]const u8 = null, name: []const u8, command: p.Dataflow.Command, role: ?Authorization.Role = null };

fn validateCatalogPart(name: []const u8) !void {
    if (name.len == 0 or name.len > p.Authorization.max_name_bytes or !std.unicode.utf8ValidateSlice(name) or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidCatalogName;
}

pub fn parse(parser: *Parser) !?Statement {
    const commands = .{ .{ "AUTHORIZE", .authorize }, .{ "ACTIVATE", .activate }, .{ "SUSPEND", .suspend_computation }, .{ "RESUME", .resume_computation }, .{ "REFRESH", .refresh }, .{ "RETIRE", .retire } };
    inline for (commands) |entry| {
        if (try parser.takeWord(entry[0])) {
            try parser.requireWord("DATAFLOW");
            const ref = try Reference.source(parser, .source);
            if (ref.qualifier) |schema| try validateCatalogPart(schema);
            try validateCatalogPart(ref.name);
            const role = if (try parser.takeWord("AS")) selected: {
                if (entry[1] != .authorize) return error.InvalidDataflowTransition;
                try parser.requireWord("ROLE");
                break :selected try Authorization.role(parser, false);
            } else null;
            try parser.finish();
            return .{ .schema = ref.qualifier, .name = ref.name, .command = entry[1], .role = role };
        }
    }
    return null;
}

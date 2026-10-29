//! Composition only: public catalog reads and the shared SQL read workspace.
const std = @import("std");
const sql = @import("transit_sql_client");
const q = @import("transit_query");
pub const Config = struct {
    sql: ?sql.Client.Config = null,
    catalog: ?struct { seed_file: []const u8, connection: q.Values.DirectConnection } = null,
};
pub const Runtime = struct {
    sql: ?sql.ReadWorkspace,
    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) Runtime {
        return .{ .sql = if (config.sql) |selected| .{ .allocator = allocator, .io = io, .config = selected } else null };
    }
    pub fn deinit(self: *Runtime) void {
        if (self.sql) |*reader| reader.deinit();
    }
};
pub fn catalog(arena: *std.heap.ArenaAllocator, wire: *q.wire.Client, config: Config, request: q.catalog.DirectCatalogRead.Request) !q.catalog.DirectCatalogRead.Response {
    const selected = config.catalog orelse return error.QueryDisabled;
    var key = try q.wire.readKey(arena.allocator(), wire.http.io, selected.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const caller: q.catalog.DirectTableClient = .{ .allocator = arena.allocator(), .authority = wire, .service = wire, .connection = try selected.connection.native(), .key = key };
    return q.catalog.DirectCatalogRead.apply(arena, caller, request);
}

//! Private executable roles, separate from the two public CLI commands.
const std = @import("std");
pub const Role = enum { node, query_host, sql_gateway, board, browser };
pub const argument = "__transit_role_v1";

/// The resulting vector borrows the executable and arguments. The installation
/// owner retains them through spawn; this does not start a process or gain rights.
pub fn arguments(allocator: std.mem.Allocator, executable: []const u8, external: ?[]const u8, role: Role, rest: []const []const u8) ![]const []const u8 {
    const prefix: usize = if (external != null) 1 else 3;
    const result = try allocator.alloc([]const u8, prefix + rest.len);
    result[0] = external orelse executable;
    if (external == null) {
        result[1] = argument;
        result[2] = @tagName(role);
    }
    @memcpy(result[prefix..], rest);
    return result;
}

pub fn run(init: std.process.Init, role: Role) !void {
    // The local supervisor already requires Linux process groups/PDEATHSIG.
    // Give the reused role entry point its ordinary argv, with the role name in
    // argv[0]. No role implementation or executable blob is copied or extracted.
    if (@import("builtin").os.tag != .linux) return error.UnsupportedLocalPlatform;
    var selected = init;
    selected.minimal.args.vector = init.minimal.args.vector[2..];
    return switch (role) {
        .node => @import("transit_node_role").main(selected),
        .query_host => @import("transit_query_host_role").main(selected),
        .sql_gateway => @import("transit_sql_gateway_role").main(selected),
        .browser => @import("transit_browser_role").main(selected),
        .board => @import("transit_board_role").main(selected),
    };
}

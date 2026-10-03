//! Application-owned process mechanics, independent of native protocol tests.
const std = @import("std");
test {
    _ = @import("Options.zig");
    _ = @import("SqlInput.zig");
    _ = @import("Settings.zig");
    _ = @import("Show.zig");
    _ = @import("Results.zig");
    _ = @import("ConsoleWrites.zig");
    _ = @import("server/Gateway.zig");
    _ = @import("server/Process.zig");
    _ = @import("server/Applications.zig");
    _ = @import("server/Hosts.zig");
}

test "confirmed query failure advice names the original budget without proposing reconciliation" {
    const QueryDiagnostic = @import("QueryDiagnostic.zig");
    const detail: QueryDiagnostic = .{ .namespace = 55001, .phase = .rejected, .failure = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .result_bytes, .limit = 1, .observed = 2048 } };
    var bytes: [1024]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try detail.render(&out);
    const text = out.buffered();
    try std.testing.expect(std.mem.indexOf(u8, text, "query.budget_exceeded") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "limit: 1; required: 2048") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Query 55001: rejected") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, ".resume") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, ".cancel") == null);
}

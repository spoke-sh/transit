//! Application-owned process mechanics, independent of native protocol tests.
const std = @import("std");
test {
    _ = @import("Options.zig");
    _ = @import("SqlInput.zig");
    _ = @import("Settings.zig");
    _ = @import("Show.zig");
    _ = @import("Results.zig");
    _ = @import("Style.zig");
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

test "structured rendering fallback preserves the owner's rejected outcome and cause" {
    const Cli = @import("Diagnostic.zig");
    const q = @import("transit_query");
    const d = q.protocol.Diagnostic;
    var detail = try d.init("query.budget_exceeded", .limit, .execute, .rejected, .domain_status, "The recorded query exceeded its budget.");
    detail.cause = try d.Code.init("QueryBudgetExceeded");
    detail.identity = .{ .domain = .query, .id = .init(41) };
    for (0..16) |_| try detail.fact(.limit, .owner, .{ .unsigned = .init(1) });
    const cli: Cli = .{ .envelope = detail, .input = try .init("input.sql"), .format = .json };
    // A full optional fact array cannot accept the script annotation. The
    // fallback must retain the primary code and durable decision, not Unknown.
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try cli.render(&out.writer, error.QueryRejected);
    const decoded = try d.decode(std.testing.allocator, std.mem.trim(u8, out.written(), "\n"));
    try std.testing.expectEqualStrings("query.budget_exceeded", decoded.code.slice());
    try std.testing.expectEqual(.rejected, decoded.outcome);
    try std.testing.expectEqual(.domain_status, decoded.evidence);
    try std.testing.expectEqualStrings("QueryBudgetExceeded", decoded.cause.?.slice());
    try std.testing.expectEqual(@as(u64, 41), try decoded.identity.?.id.value());
}

test "saved query receipt and uncertain command evidence never become a domain result" {
    const u = @import("Unified.zig");
    var session: u.Session = .{ .namespace = 41, .input = 9 };
    const admitted = try u.savedDiagnostic(session, error.AccessDenied);
    try std.testing.expectEqual(.pending, admitted.outcome);
    try std.testing.expectEqual(.native_receipt, admitted.evidence);
    try std.testing.expectEqual(.resume_exact, admitted.actions[1].?.kind);
    session.input = null;
    const saved = try u.savedDiagnostic(session, error.ConsoleInterrupted);
    try std.testing.expectEqual(.unknown, saved.outcome);
    try std.testing.expectEqual(.none, saved.evidence);
    session.length = 1;
    const retained = try u.savedDiagnostic(session, error.ConsoleInterrupted);
    try std.testing.expectEqual(.saved_intent, retained.evidence);
    try std.testing.expectEqual(@as(u64, 41), try saved.identity.?.id.value());
}

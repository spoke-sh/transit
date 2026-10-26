const std = @import("std");
test "saved query receipt and uncertain command evidence never become a domain result" {
    const u = @import("fixture_operations_unified");
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

test "structured rendering fallback preserves the owner's rejected outcome and cause" {
    const Cli = @import("cli_support").Diagnostic;
    const q = @import("transit_query");
    const d = q.protocol.Diagnostic;
    var detail = try d.init("query.budget_exceeded", .limit, .execute, .rejected, .domain_status, "The recorded query exceeded its budget.");
    detail.cause = try d.Code.init("QueryBudgetExceeded");
    detail.identity = .{ .domain = .query, .id = .init(41) };
    for (0..16) |_| try detail.fact(.limit, .owner, .{ .unsigned = .init(1) });
    const cli: Cli = .{ .envelope = detail, .input = try .init("input.sql") };
    // A full optional fact array cannot accept the script annotation. The
    // fallback must retain the primary code and durable decision, not Unknown.
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try @import("fixture_operations_diagnostic").render(cli, &out.writer, error.QueryRejected, true, null);
    const decoded = try d.decode(std.testing.allocator, std.mem.trim(u8, out.written(), "\n"));
    try std.testing.expectEqualStrings("query.budget_exceeded", decoded.code.slice());
    try std.testing.expectEqual(.rejected, decoded.outcome);
    try std.testing.expectEqual(.domain_status, decoded.evidence);
    try std.testing.expectEqualStrings("QueryBudgetExceeded", decoded.cause.?.slice());
    try std.testing.expectEqual(@as(u64, 41), try decoded.identity.?.id.value());
}

//! A currently authorized saved query outcome, independent of transport errors.
const std = @import("std");
const q = @import("transit_query");
const Self = @This();
namespace: u64,
phase: q.UnifiedRequest.Phase,
failure: ?q.QueryFailure,
pub fn render(self: Self, out: *std.Io.Writer) !void {
    if (self.failure) |failure| if (failure.runtime != null) return @import("EnvelopeDiagnostic.zig").render(try failure.diagnostic(self.namespace, self.phase), out);
    try out.writeAll("Query Error:\n");
    if (self.failure) |failure| {
        try out.print("{s}\nCode: query.{s}; stage: {s}.\n", .{ failure.message(), @tagName(failure.code), @tagName(failure.stage) });
        if (failure.dimension != .none) try out.print("Budget: {s}; limit: {d}; required: {d}.\n", .{ @tagName(failure.dimension), failure.limit, failure.observed });
    } else try out.writeAll(switch (self.phase) {
        .cancelled => "The saved query wait was cancelled. Cancellation does not retract previously disclosed results.\n",
        .retired => "The saved query was retired; its result is no longer available through this request.\n",
        else => return error.InvalidQueryDiagnostic,
    });
    try out.print("Query {d}: {s}. No complete result is available from this request.\n", .{ self.namespace, @tagName(self.phase) });
    try out.writeAll("Use .status to inspect this recorded outcome. ");
    if (self.failure) |failure| {
        if (failure.denied()) try out.writeAll("Resolve the current access or source-lifecycle failure before submitting a new query.\n") else if (failure.dimension != .none) try out.writeAll("Reduce the query's work or explicitly configure a sufficient authorized budget, then submit a new query.\n") else try out.writeAll("Correct the reported query or source problem before submitting a new query.\n");
    } else try out.writeAll("Submit a new query if you need a new result.\n");
}

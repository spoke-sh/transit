//! HTTP presentation of an already owned semantic diagnostic. Specific native
//! inspection dispositions remain with the route that observed them.
const std = @import("std");
const root = @import("root.zig");
const d = root.protocol.Diagnostic;
pub const Response = struct { status: std.http.Status, code: @FieldType(root.Error, "err") };
pub fn project(detail: d) Response {
    if (detail.outcome == .unknown) return .{ .status = .service_unavailable, .code = .Unavailable };
    const sql = std.mem.startsWith(u8, detail.code.slice(), "sql.");
    return switch (detail.category) {
        .syntax, .binding, .limit, .unsupported => .{ .status = .bad_request, .code = if (sql or detail.category == .unsupported) .UnsupportedQuery else .InvalidQuery },
        .constraint, .conflict, .lifecycle => .{ .status = .conflict, .code = .QueryConflict },
        .access => .{ .status = .forbidden, .code = .Forbidden },
        .unavailable => .{ .status = .service_unavailable, .code = .Unavailable },
        .integrity => if (detail.outcome == .not_submitted) .{ .status = .bad_request, .code = .InvalidQuery } else .{ .status = .bad_gateway, .code = .Unavailable },
        .internal => .{ .status = .internal_server_error, .code = .Unavailable },
    };
}

test "Board status follows semantic categories and preserves uncertain sends" {
    const t = std.testing;
    inline for (comptime std.meta.tags(d.Category)) |category| {
        var detail = try d.init("query.fixture", category, .read, .not_applicable, .none, "Fixture.");
        const response = project(detail);
        const expected: u10 = switch (category) {
            .syntax, .binding, .limit, .unsupported => 400,
            .constraint, .conflict, .lifecycle => 409,
            .access => 403,
            .unavailable => 503,
            .integrity => 502,
            .internal => 500,
        };
        try t.expectEqual(expected, @backingInt(response.status));
        detail.outcome = .unknown;
        try t.expectEqual(.service_unavailable, project(detail).status);
    }
    const q = @import("transit_query");
    const placeholder = q.fuze.SqlDiagnostic.query("SELECT * FROM items LIMIT $1", error.UnboundParameters, true).?;
    const response = project(try placeholder.structured());
    try t.expectEqual(.bad_request, response.status);
    try t.expectEqual(.UnsupportedQuery, response.code);
}

//! Administration attempt classifications; retained native outcomes are separate.
const d = @import("root.zig").protocol.Diagnostic;
pub const Entry = struct { cause: anyerror, code: []const u8, category: d.Category };
pub const entries = [_]Entry{
    .{ .cause = error.AccessDenied, .code = "authorization.operation_failed", .category = .access },
    .{ .cause = error.Rejected, .code = "authorization.operation_failed", .category = .constraint },
    .{ .cause = error.Conflict, .code = "authorization.operation_failed", .category = .conflict },
    .{ .cause = error.StaleAuthorizationRevision, .code = "authorization.operation_failed", .category = .conflict },
    .{ .cause = error.IncompatibleDefinition, .code = "authorization.operation_failed", .category = .unsupported },
    .{ .cause = error.InvalidAuthorityResponse, .code = "authorization.operation_failed", .category = .integrity },
    .{ .cause = error.InvalidAuthorizationChange, .code = "authorization.operation_failed", .category = .binding },
    .{ .cause = error.InvalidAuthorizationInput, .code = "authorization.operation_failed", .category = .binding },
    .{ .cause = error.InvalidAuthorizationObject, .code = "authorization.operation_failed", .category = .binding },
    .{ .cause = error.AuthorizationChangeNotPending, .code = "authorization.operation_failed", .category = .lifecycle },
    .{ .cause = error.AuthorizationChangeNotAdmitted, .code = "authorization.operation_failed", .category = .lifecycle },
    .{ .cause = error.AuthorizationChangePending, .code = "authorization.operation_failed", .category = .lifecycle },
    .{ .cause = error.SignatureVerificationFailed, .code = "authorization.operation_failed", .category = .integrity },
    .{ .cause = error.OutOfMemory, .code = "authorization.operation_failed", .category = .unavailable },
};
pub fn category(cause: anyerror) d.Category {
    for (entries) |entry| if (entry.cause == cause) return entry.category;
    return if (@import("root.zig").Client.unavailable(cause)) .unavailable else .internal;
}

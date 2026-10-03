//! Pure first-field evidence after an owner's canonical policy comparison fails.
//! This does not decide acceptance. Caller buffers are copied into the rejection;
//! private routing, credential, target and metadata values are withheld.
const std = @import("std");
const Scalar = @import("AdmissionRejection.zig").Scalar;
pub fn first(comptime Rejection: type, before: anytype, after: @TypeOf(before), cause: anyerror) ?Rejection {
    return walk(Rejection, before, after, "policy", false, cause);
}
fn detail(comptime Rejection: type, path: []const u8, before: Scalar, after: Scalar, hidden: bool, cause: anyerror) Rejection {
    return Rejection.detail(.denied, .equal, path, if (hidden) .redacted else before, if (hidden) .redacted else after, cause);
}
fn walk(comptime Rejection: type, before: anytype, after: @TypeOf(before), path: []const u8, hidden: bool, cause: anyerror) ?Rejection {
    const T = @TypeOf(before);
    var buffer: [512]u8 = undefined;
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            inline for (info.field_names) |field| {
                const next = std.fmt.bufPrint(&buffer, "{s}.{s}", .{ path, field }) catch return detail(Rejection, path, .redacted, .redacted, true, cause);
                const private = hidden or (comptime std.mem.eql(u8, field, "headers") or std.mem.eql(u8, field, "credentials") or std.mem.eql(u8, field, "target") or std.mem.eql(u8, field, "metadata") or std.mem.eql(u8, field, "host") or std.mem.eql(u8, field, "address") or std.mem.eql(u8, field, "port") or std.mem.eql(u8, field, "response_headers") or std.mem.eql(u8, field, "response_metadata") or std.mem.eql(u8, field, "key_header") or std.mem.eql(u8, field, "key_metadata"));
                if (walk(Rejection, @field(before, field), @field(after, field), next, private, cause)) |found| return found;
            }
        },
        .optional => {
            if (before) |value| {
                if (after) |other| return walk(Rejection, value, other, path, hidden, cause);
                return detail(Rejection, path, .{ .text = "present" }, .inapplicable, hidden, cause);
            } else if (after != null) return detail(Rejection, path, .inapplicable, .{ .text = "present" }, hidden, cause);
        },
        .pointer => |info| {
            if (info.size != .slice) @compileError("Policy evidence requires owned scalar/slice data");
            if (info.child == u8) {
                if (!std.mem.eql(u8, before, after)) return detail(Rejection, path, .{ .text = before }, .{ .text = after }, hidden, cause);
            } else {
                if (before.len != after.len) {
                    const next = std.fmt.bufPrint(&buffer, "{s}.length", .{path}) catch return detail(Rejection, path, .redacted, .redacted, true, cause);
                    return detail(Rejection, next, .{ .unsigned = before.len }, .{ .unsigned = after.len }, hidden, cause);
                }
                for (before, after, 0..) |left, right, index| {
                    const next = std.fmt.bufPrint(&buffer, "{s}[{d}]", .{ path, index }) catch return detail(Rejection, path, .redacted, .redacted, true, cause);
                    if (walk(Rejection, left, right, next, hidden, cause)) |found| return found;
                }
            }
        },
        .@"union" => {
            if (std.meta.activeTag(before) != std.meta.activeTag(after)) return detail(Rejection, path, .{ .text = @tagName(before) }, .{ .text = @tagName(after) }, hidden, cause);
            switch (before) {
                inline else => |value, tag| {
                    const next = std.fmt.bufPrint(&buffer, "{s}.{s}", .{ path, @tagName(tag) }) catch return detail(Rejection, path, .redacted, .redacted, true, cause);
                    return walk(Rejection, value, @field(after, @tagName(tag)), next, hidden, cause);
                },
            }
        },
        .array => {
            if (T != [32]u8) @compileError("Policy evidence array must be a digest");
            if (!std.mem.eql(u8, &before, &after)) return detail(Rejection, path, .{ .digest = before }, .{ .digest = after }, hidden, cause);
        },
        .int => if (before != after) return detail(Rejection, path, .{ .unsigned = before }, .{ .unsigned = after }, hidden, cause),
        .bool => if (before != after) return detail(Rejection, path, .{ .text = if (before) "true" else "false" }, .{ .text = if (after) "true" else "false" }, hidden, cause),
        .@"enum" => if (before != after) return detail(Rejection, path, .{ .text = @tagName(before) }, .{ .text = @tagName(after) }, hidden, cause),
        .void => {},
        else => @compileError("Unsupported frozen policy field"),
    }
    return null;
}

test "policy evidence compares slice contents and owns the first nested difference without credential payloads" {
    const t = std.testing;
    const Rejection = @import("AdmissionRejection.zig").For("HTF1", .http);
    const Policy = struct { limits: struct { bytes: u64 }, credentials: []const struct { value: []const u8 } };
    var changed_bytes = [_]u8{'b'};
    const before: Policy = .{ .limits = .{ .bytes = 8 }, .credentials = &.{.{ .value = "a" }} };
    var after = before;
    after.limits.bytes = 9;
    const limit = first(Rejection, before, after, error.PolicyChanged).?;
    try t.expectEqualStrings("policy.limits.bytes", limit.field[0..limit.field_len]);
    try t.expectEqual(@as(u64, 8), limit.expected_number);
    try t.expectEqual(@as(u64, 9), limit.actual_number);
    after = before;
    after.credentials = &.{.{ .value = &changed_bytes }};
    const secret = first(Rejection, before, after, error.PolicyChanged).?;
    try t.expectEqualStrings("policy.credentials[0].value", secret.field[0..secret.field_len]);
    try t.expectEqual(.redacted, secret.actual_kind);
    try t.expectEqual(.redacted, secret.expected_kind);
    try t.expect(std.mem.allEqual(u8, &secret.actual_text, 0));
    changed_bytes[0] = 'a';
    try t.expectEqual(null, first(Rejection, before, after, error.PolicyChanged));
    try secret.validate();
}

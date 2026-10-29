//! Read-only presentation of one authorized native storage observation.
const std = @import("std");
const p = @import("root.zig").protocol;
const s = p.Storage;

pub const Response = struct {
    realm: u64,
    position: u64,
    backend: @FieldType(s.Observation, "backend"),
    root: ?[]const u8,
    allocated_bytes: ?u64,
    limits: ?s.Limits,
    data_requests: ?s.Memory,
    control_requests: ?s.Memory,
    request_limit_bytes: ?u64,
    maintenance: ?s.Activity,
    settings: ?s.Maintenance,
};

pub fn project(allocator: std.mem.Allocator, response: p.Growth.Response) !Response {
    if (response.definition != p.Growth.current_definition or response.body != .storage or response.realm == 0 or response.position == 0) return error.InvalidStorageObservation;
    const observed = response.body.storage;
    try observed.validate();
    return .{
        .realm = response.realm,
        .position = response.position,
        .backend = observed.backend,
        .root = if (observed.root) |path| try allocator.dupe(u8, path.slice()) else null,
        .allocated_bytes = observed.allocated_bytes,
        .limits = observed.limits,
        .data_requests = observed.data_requests,
        .control_requests = observed.control_requests,
        .request_limit_bytes = observed.request_limit_bytes,
        .maintenance = observed.maintenance,
        .settings = observed.settings,
    };
}

test "storage projection owns paths and preserves unavailable observations" {
    const t = std.testing;
    var response: p.Growth.Response = .{ .definition = p.Growth.current_definition, .realm = 42, .position = 7, .principal_sequence = 0, .body = .{ .storage = s.Observation.unavailable } };
    try t.expectEqual(null, (try project(t.allocator, response)).root);
    response.body.storage.backend = .local;
    response.body.storage.root = try s.Path.init("/var/lib/transit");
    const observed = try project(t.allocator, response);
    defer t.allocator.free(observed.root.?);
    response.body.storage.root.?.bytes[1] = 'x';
    try t.expectEqualStrings("/var/lib/transit", observed.root.?);
    try t.expectEqual(null, observed.allocated_bytes);
}

//! Test-only reviewed workload. A separate node image/realm, not a code upgrade.
const std = @import("std");
const transit = @import("transit");
pub fn reduce(state: i64, input: i64) !transit.Decision {
    return .{ .state = try std.math.add(i64, state, input), .effect = input };
}

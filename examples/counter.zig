//! M1's reviewed, version-one workload. No I/O, allocation, ambient time, or
//! dynamic/native plugin loading. Overflow leaves the input pending.
const std = @import("std");
pub const Decision = struct { state: i64 };
pub fn reduce(state: i64, input: i64) !Decision {
    return .{ .state = try std.math.add(i64, state, input) };
}

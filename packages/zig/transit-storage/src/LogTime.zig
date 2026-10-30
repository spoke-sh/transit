//! Trusted time is an adapter capability, never request data or a WAL header's
//! incidental clock field. Accepted floors survive replacement; observation
//! and original-outcome lookup do not require a currently available clock.
const q = @import("transit_protocol").StreamQueue;
pub const Source = struct {
    context: *anyopaque,
    /// May run under the publication guard. It must not recursively acquire
    /// that guard or publish policy; its result is an authoritative UTC time.
    read: *const fn (*anyopaque) anyerror!?u64,
};
pub fn observe(source: ?Source, floor_ms: ?u64, required: bool) !?u64 {
    if (source) |clock| {
        const now = clock.read(clock.context) catch return error.LogTimeUnavailable;
        return try (q.LogClock{ .floor_ms = floor_ms orelse 0 }).observe(now);
    }
    if (required or floor_ms != null) return error.LogTimeUnavailable;
    return null;
}
pub fn advance(floor_ms: ?u64, observed_ms: ?u64) !?u64 {
    if (observed_ms) |now| return try (q.LogClock{ .floor_ms = floor_ms orelse 0 }).observe(now);
    if (floor_ms != null) return error.LogTimeUnavailable;
    return null;
}

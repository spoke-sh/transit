//! Trusted time is an adapter capability, never request data or a WAL header's
//! incidental clock field. Accepted floors survive replacement; observation
//! and original-outcome lookup do not require a currently available clock.
const q = @import("transit_protocol").StreamQueue;
/// The trusted adapter asserts that UTC lies inside this closed interval.
pub const Sample = @import("transit_protocol").QueueRead.TimeBounds;
pub const Source = struct {
    context: *anyopaque,
    /// May run under the publication guard. It must not recursively acquire
    /// that guard or publish policy; its result bounds authoritative UTC.
    read: *const fn (*anyopaque) anyerror!?Sample,
};
pub fn bounds(source: ?Source, floor_ms: ?u64, required: bool) !?Sample {
    if (source) |clock| {
        const now = (clock.read(clock.context) catch return error.LogTimeUnavailable) orelse return error.LogTimeUnavailable;
        try now.validate();
        _ = try (q.LogClock{ .floor_ms = floor_ms orelse 0 }).observe(now.latest_ms);
        return now;
    }
    if (required or floor_ms != null) return error.LogTimeUnavailable;
    return null;
}
/// New age-bearing work uses the upper bound so uncertainty cannot shorten its
/// lifetime. Eligibility uses bounds().earliest_ms instead. The persisted floor
/// tracks upper observations independently of the lower eligibility proof.
pub fn observe(source: ?Source, floor_ms: ?u64, required: bool) !?u64 {
    return if (try bounds(source, floor_ms, required)) |now| now.latest_ms else null;
}
pub fn advance(floor_ms: ?u64, observed_ms: ?u64) !?u64 {
    if (observed_ms) |now| return try (q.LogClock{ .floor_ms = floor_ms orelse 0 }).observe(now);
    if (floor_ms != null) return error.LogTimeUnavailable;
    return null;
}

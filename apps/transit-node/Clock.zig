//! Linux's synchronized kernel clock is the deployment's trusted time source.
//! The operator must supply an honest synchronization service; this reads its
//! reported error bound, not a proof of UTC accuracy on a compromised host.
const builtin = @import("builtin");
const transit = @import("transit");
const c = if (builtin.os.tag == .linux) @import("clock_c") else struct {};
pub fn read(_: *anyopaque) !transit.Time.Sample {
    if (builtin.os.tag != .linux) return error.ClockUnavailable;
    var buffer: [c.rey_timex_size]u8 align(c.rey_timex_align) = @splat(0);
    const status = c.adjtimex(@ptrCast(&buffer)); // modes=0: read only
    const flags = field(c_int, &buffer, c.rey_timex_status);
    const time = field(c.struct_timeval, &buffer, c.rey_timex_time);
    const maxerror = field(c_long, &buffer, c.rey_timex_maxerror);
    if (status < 0 or status == c.TIME_ERROR or flags & (c.STA_UNSYNC | c.STA_CLOCKERR) != 0 or
        time.tv_sec < 0 or maxerror < 0) return error.ClockUnavailable;
    const nanos = flags & c.STA_NANO != 0;
    const sub_ms: u64 = @intCast(@divTrunc(time.tv_usec, if (nanos) @as(c_long, 1_000_000) else 1000));
    const error_ms = @divTrunc(maxerror, 1000) + 2;
    if (error_ms > @import("std").math.maxInt(u32)) return error.ClockUnavailable;
    return .{ .unix_ms = @as(u64, @intCast(time.tv_sec)) * 1000 + sub_ms, .error_ms = @intCast(error_ms) };
}
fn field(comptime T: type, buffer: []const u8, offset: usize) T {
    return @import("std").mem.bytesToValue(T, buffer[offset..][0..@sizeOf(T)]);
}

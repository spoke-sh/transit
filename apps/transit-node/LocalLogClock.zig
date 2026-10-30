//! A temporary authoritative interval; never retained with a partition cache.
const c = @import("transit_catalog");
const Engine = @import("transit_backend_local").DataAuthority.Engine;

pub fn source(engine: *Engine) c.storage.LogTime.Source {
    return .{ .context = engine, .read = read };
}
fn read(raw: *anyopaque) !?c.storage.LogTime.Sample {
    const engine: *Engine = @ptrCast(@alignCast(raw));
    const clock = engine.clock orelse return null;
    const sample = try clock.sample();
    const allowed = engine.genesis.max_clock_error_ms orelse return error.LogTimeUnavailable;
    if (sample.error_ms > allowed or sample.upper() > c.protocol.max_counter) return error.LogTimeUnavailable;
    if (sample.unix_ms < engine.head.time_floor_ms) return error.LogTimeRegression;
    return .{ .earliest_ms = sample.lower(), .latest_ms = sample.upper() };
}

//! A temporary authoritative interval; never retained with a partition cache.
const c = @import("transit_catalog");
const core = @import("transit_core");
const Engine = @import("transit_backend_local").DataAuthority.Engine;

pub fn source(engine: *Engine) c.storage.LogTime.Source {
    return .{ .context = engine, .read = read };
}
fn read(raw: *anyopaque) !?c.storage.LogTime.Sample {
    const engine: *Engine = @ptrCast(@alignCast(raw));
    const clock = engine.clock orelse return null;
    const sample = try clock.sample();
    return try interval(sample, engine.genesis.max_clock_error_ms, engine.head.time_floor_ms);
}

/// The deployment's fixed uncertainty envelope contains every admissible
/// kernel interval. A synchronization update can narrow the reported error;
/// that must not make an otherwise advancing clock's upper bound regress.
/// Fixed width keeps both endpoints ordered by UTC while preserving the
/// native floor and each partition's separate persisted upper-floor check.
fn interval(sample: core.Time.Sample, maximum_error_ms: ?u32, native_floor_ms: u64) !c.storage.LogTime.Sample {
    const allowed = maximum_error_ms orelse return error.LogTimeUnavailable;
    const bounded: core.Time.Sample = .{ .unix_ms = sample.unix_ms, .error_ms = allowed };
    if (sample.error_ms > allowed or bounded.upper() > c.protocol.max_counter) return error.LogTimeUnavailable;
    if (sample.unix_ms < native_floor_ms) return error.LogTimeRegression;
    return .{ .earliest_ms = bounded.lower(), .latest_ms = bounded.upper() };
}

test "local log clock uses a fixed admissible envelope through uncertainty contraction" {
    const t = @import("std").testing;
    const first: core.Time.Sample = .{ .unix_ms = 1000, .error_ms = 50 };
    const next: core.Time.Sample = .{ .unix_ms = 1001, .error_ms = 1 };
    try t.expect(next.upper() < first.upper());
    const before = try interval(first, 50, 1000);
    const after = try interval(next, 50, 1000);
    try t.expectEqualDeep(c.storage.LogTime.Sample{ .earliest_ms = 950, .latest_ms = 1050 }, before);
    try t.expectEqualDeep(c.storage.LogTime.Sample{ .earliest_ms = 951, .latest_ms = 1051 }, after);
    try t.expect(after.earliest_ms <= next.lower() and after.latest_ms >= next.upper());
    _ = try (c.protocol.StreamQueue.LogClock{ .floor_ms = before.latest_ms }).observe(after.latest_ms);
    // Widening kernel uncertainty within the configured envelope also leaves
    // both endpoints ordered; no accepted deadline or floor is rewritten.
    const widened = try interval(.{ .unix_ms = 1002, .error_ms = 50 }, 50, 1000);
    try t.expect(widened.earliest_ms >= after.earliest_ms and widened.latest_ms >= after.latest_ms);
}

test "local log clock preserves rollback unavailable and counter-bound refusals" {
    const t = @import("std").testing;
    try t.expectError(error.LogTimeUnavailable, interval(.{ .unix_ms = 1000 }, null, 0));
    try t.expectError(error.LogTimeUnavailable, interval(.{ .unix_ms = 1000, .error_ms = 51 }, 50, 0));
    try t.expectError(error.LogTimeUnavailable, interval(.{ .unix_ms = c.protocol.max_counter - 49 }, 50, 0));
    try t.expectError(error.LogTimeRegression, interval(.{ .unix_ms = 999 }, 50, 1000));
    const rolled_back = try interval(.{ .unix_ms = 999 }, 50, 0);
    try t.expectError(error.LogTimeRegression, (c.protocol.StreamQueue.LogClock{ .floor_ms = 1050 }).observe(rolled_back.latest_ms));
    try t.expectEqual(@as(u64, 0), (try interval(.{ .unix_ms = 1 }, 50, 0)).earliest_ms);
    try t.expectEqualDeep(c.storage.LogTime.Sample.exact(1000), try interval(.{ .unix_ms = 1000 }, 0, 0));
}

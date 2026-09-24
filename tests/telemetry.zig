//! Real I/O proof: stderr may be stalled or closed; stdout remains machine data.
const std = @import("std");
const t = @import("telemetry");
pub fn main(init: std.process.Init) !void {
    var runtime = t.Runtime.init(init.io, "telemetry-proof", try t.Config.environment(init.environ_map));
    runtime.start();
    const started = std.Io.Clock.awake.now(init.io);
    for (0..10000) |_| {
        var span = runtime.begin(.server, null);
        span.finish(.{ .name = "http.request", .route = "/fixed", .method = "GET", .status = 200, .response_written = true });
    }
    const emitted_ns = started.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    try init.io.sleep(.fromMilliseconds(100), .awake);
    runtime.stop();
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{
        .snapshot = runtime.snapshot(.server),
        .emitted_ns = emitted_ns,
        .dropped = runtime.dropped.load(.monotonic),
        .suppressed = runtime.suppressed.load(.monotonic),
        .sink_errors = runtime.sink_errors.load(.monotonic),
    }, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}

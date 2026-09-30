const std = @import("std");
const telemetry = @import("transit_observability").telemetry;
const wire = @import("transit_client");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const config = try telemetry.Config.environment(init.environ_map);
    var diagnostics = if (args.len == 3 and std.mem.eql(u8, args[2], "--maintain")) telemetry.Runtime.init(init.io, "transit-maintenance", config) else telemetry.Runtime.init(init.io, "transit-node", config);
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped" });
    diagnostics.event(.{ .name = "service.starting" });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const initialize = args.len == 3 and std.mem.eql(u8, args[2], "--initialize");
    const maintain = args.len == 3 and std.mem.eql(u8, args[2], "--maintain");
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[2], "--bootstrap");
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !initialize and !maintain and !bootstrap)) return error.ExpectedConfigAndMode;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    return @import("Native.zig").run(init, bytes, .{ .initialize = initialize, .bootstrap = bootstrap, .maintain = maintain }, diagnostics);
}

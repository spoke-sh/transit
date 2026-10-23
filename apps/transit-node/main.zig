const std = @import("std");
const telemetry = @import("transit_observability").telemetry;
const wire = @import("transit_client");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const status = if (args.len == 3 and std.mem.eql(u8, args[2], "--maintain")) telemetry.runService(init, "transit-maintenance", .info, run) else telemetry.runService(init, "transit-node", .info, run);
    if (status != 0) std.process.exit(status);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const initialize = args.len == 3 and std.mem.eql(u8, args[2], "--initialize");
    const maintain = args.len == 3 and std.mem.eql(u8, args[2], "--maintain");
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[2], "--bootstrap");
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !initialize and !maintain and !bootstrap)) return error.ExpectedConfigAndMode;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    const selector = try std.json.parseFromSlice(struct { local_directory: ?[]const u8 = null }, init.gpa, bytes, .{ .ignore_unknown_fields = true });
    defer selector.deinit();
    if (selector.value.local_directory != null) return @import("Local.zig").run(init, bytes, .{ .initialize = initialize, .bootstrap = bootstrap, .maintain = maintain }, diagnostics);
    return @import("Native.zig").run(init, bytes, .{ .initialize = initialize, .bootstrap = bootstrap, .maintain = maintain }, diagnostics);
}

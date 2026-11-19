//! Compose the extracted suite command with the native isolated database host.
const std = @import("std");
const workspace = @import("transit_workspace");
const c = @import("transit_compiler");
const Native = @import("TestHost.zig");
const Wire = workspace.TestHostProtocol;
const Adapter = struct {
    pub const embedded = true;
    pub const cleanup_ms = Native.cleanup_ms;
    pub const Deadline = @import("transit_test").service.wire.Deadline;
    identity: ?Wire.Runtime = null,
    pub fn errorName(_: *const Adapter, err: anyerror) []const u8 {
        return @errorName(err);
    }
    pub fn delete(_: *Adapter, io: std.Io, parent: std.Io.Dir, name: []const u8) !void {
        return Native.delete(io, parent, name);
    }
    pub fn runDetailed(_: *Adapter, init: std.process.Init, directory: std.Io.Dir, path: []const u8, case: c.Test.Case, deadline: Deadline, observed: *Wire.Observation, detail: *c.Test.Detail) !bool {
        var native: Native.Observation = .{};
        defer observed.* = .{ .actions = native.actions, .rows = native.rows, .bytes = native.bytes, .operation = native.operation, .failure = native.failure, .resources = .{ .memory_peak_bytes = native.resources.memory_peak_bytes, .storage_reserved_bytes = native.resources.storage_reserved_bytes } };
        return Native.runDetailed(init, directory, path, case, deadline, &native, detail);
    }
};
pub fn run(original: std.process.Init, options: workspace.Options, diagnostic: *@import("Diagnostic.zig")) !void {
    const gpa = if (@import("builtin").mode == .debug) original.gpa else std.heap.c_allocator;
    const runtime = try @import("transit_io").Threaded.create(gpa, .{ .workers = 16, .task_bytes = 1024 * 1024, .environ = original.minimal.environ, .argv0 = .init(original.minimal.args) });
    defer runtime.destroy();
    var init = original;
    init.gpa = gpa;
    init.io = runtime.io();
    var host: Adapter = .{};
    return workspace.Test.run(init, options, diagnostic, @import("build_version").revision, &host);
}

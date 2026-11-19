//! Private compiled-case entry point used by transitc. No source is evaluated here.
const std = @import("std");
const contract = @import("transit_test_protocol");
const Wire = contract.Wire;
const Files = @import("TestFiles.zig");
const Native = @import("TestHost.zig");
const p = @import("transit_test").service.catalog.protocol;

pub fn run(original: std.process.Init, path: []const u8) !void {
    const gpa = if (@import("builtin").mode == .debug) original.gpa else std.heap.c_allocator;
    const runtime = try @import("transit_io").Threaded.create(gpa, .{ .workers = 16, .task_bytes = 1024 * 1024, .environ = original.minimal.environ, .argv0 = .init(original.minimal.args) });
    defer runtime.destroy();
    var init = original;
    init.gpa = gpa;
    init.io = runtime.io();
    var budget: @import("transit_memory").Budget = .{ .parent = gpa, .limit = 256 * 1024 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(budget.allocator());
    defer arena.deinit();
    const a = arena.allocator();
    const directory = try std.Io.Dir.cwd().openDir(init.io, path, .{ .iterate = true, .follow_symlinks = false });
    defer directory.close(init.io);
    const bytes = try Files.read(a, init.io, directory, "case.json", Wire.max_request_bytes);
    const request = try p.Json.parseFromSlice(Wire.Request, a, bytes);
    const case = try Wire.executable(a, request.value);
    // Reject the full request before constructing a native owner or credentials.
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var observed: Native.Observation = .{};
    var detail: contract.Assertions.Detail = .{};
    var cause: ?[]const u8 = null;
    const deadline = @import("transit_test").service.wire.Deadline.init(init.io, request.value.milliseconds, null);
    const passed = Native.runDetailed(init, directory, path, case, deadline, &observed, &detail) catch |err| failed: {
        cause = @errorName(err);
        break :failed false;
    };
    const response: Wire.Response = .{
        .definition = Wire.definition,
        .source_definition = Wire.source_definition,
        .request_digest = digest,
        .identity = request.value.identity,
        .sql_digest = request.value.sql_digest,
        .runtime = .{ .revision = @import("build_version").revision, .executable_digest = try Files.executableDigest(init.io, a) },
        .complete = cause == null,
        .passed = passed,
        .error_code = cause,
        .observation = .{ .actions = observed.actions, .rows = observed.rows, .bytes = observed.bytes, .operation = observed.operation, .failure = observed.failure, .resources = .{ .memory_peak_bytes = observed.resources.memory_peak_bytes, .storage_reserved_bytes = observed.resources.storage_reserved_bytes } },
        .detail = detail,
    };
    const output = try p.Json.valueAllocBounded(a, response, Wire.max_response_bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, output);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

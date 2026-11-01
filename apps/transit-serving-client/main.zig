//! One bounded caller request per invocation. There is no hidden journal/retry.
const std = @import("std");
const serving = @import("transit_serving");
const caller = serving.Caller;
pub const std_options: std.Options = .{ .log_level = .err };
pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    const memory = try alloc.alloc(u8, caller.max_request_bytes);
    var input = std.Io.File.stdin().reader(init.io, memory);
    const line = try input.interface.takeDelimiter('\n') orelse return error.MissingRequest;
    const parsed = try serving.protocol.Json.parseFromSlice(caller.Request, alloc, line);
    const result = caller.process(alloc, init.io, parsed.value) catch |err| caller.Result{ .status = if (parsed.value.action == .dispatch) .unknown else .unavailable, .err = @errorName(err) };
    var scratch: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &scratch);
    var json: std.json.Stringify = .{ .writer = &output.interface };
    try serving.protocol.Json.write(result, &json);
    try output.interface.writeByte('\n');
    try output.interface.flush();
}

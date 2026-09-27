//! Offline helper generation. Input is a bounded local FileDescriptorSet;
//! output constructs RPC requests without transport, reflection or credentials.
const std = @import("std");
const rpc = @import("transit_station_grpc");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedLocalDescriptorSet;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(rpc.transport.Descriptor.maximum_bytes));
    defer init.gpa.free(bytes);
    var descriptor = try rpc.transport.Descriptor.parse(init.gpa, bytes);
    defer descriptor.deinit();
    // Validate every method before emitting any source, including cross-file
    // ambiguities and missing imported message types.
    for (0..descriptor.methods) |index| {
        var path: [512]u8 = undefined;
        _ = try descriptor.at(@intCast(index), &path);
    }
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    const out = &output.interface;
    try out.writeAll("// Generated from a pinned FileDescriptorSet by transit-grpc-bindings.\n// Message codecs remain application-owned; no network operations are generated.\nconst rpc = @import(\"transit_station_grpc\");\n");
    try out.writeAll("pub const descriptor_digest: [32]u8 = .{");
    for (descriptor.digest, 0..) |byte, index| {
        if (index != 0) try out.writeAll(",");
        try out.print("{d}", .{byte});
    }
    try out.writeAll("};\n");
    for (0..descriptor.methods) |index| {
        var path_buffer: [512]u8 = undefined;
        const method = try descriptor.at(@intCast(index), &path_buffer);
        // Descriptor validation admits only protobuf identifiers and path
        // separators: quotes, newlines and Zig source injection are forbidden.
        try out.print("pub fn @\"{s}\"(metadata: []const rpc.Request.Entry) rpc.Request {{\n    return .{{ .method = \"{s}\", .shape = .{s}, .descriptor_digest = descriptor_digest, .metadata = metadata }};\n}}\n", .{ method.path, method.path, @tagName(method.shape) });
    }
    try out.flush();
}

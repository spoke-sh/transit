//! Shared bounded port operations. No Station or host-language protocol engine.
const std = @import("std");
const abi = @import("Abi.zig");
const p = @import("transit_client").protocol;
pub const version = 1;
pub const max_line_bytes = p.max_body * 2 + 16384;
pub const max_config_bytes = 8192;
pub const Config = struct { url: []const u8, timeout_ms: u32 = 5000 };
pub const Prepare = struct { kind: u32, seed_file: []const u8, document: []const u8 };
pub const Request = union(enum) { hello: void, capabilities: void, prepare: Prepare, metadata: []const u8, call: []const u8 };
pub const Capabilities = struct {
    version: u32 = 1,
    operation_metadata: bool = true,
    opaque_retry: bool = true,
    growing_v3: bool = true,
    minimum_stack_bytes: u32 = abi.minimum_stack_bytes,
    max_line_bytes: u32 = max_line_bytes,
    value_bytes: u32 = p.Value.max_bytes,
    max_counter: u64 = p.max_counter,
};

pub fn readSeed(init: std.process.Init, path: []const u8) ![32]u8 {
    const text = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128));
    defer {
        std.crypto.secureZero(u8, text);
        init.gpa.free(text);
    }
    const trimmed = std.mem.trim(u8, text, " \r\n\t");
    if (trimmed.len != 64) return error.InvalidSeed;
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, trimmed);
    return seed;
}
pub fn respond(out: *std.Io.Writer, status: u32, value: []const u8) !void {
    try out.print("{{\"status\":{d},\"value\":", .{status});
    try out.writeAll(value);
    try out.writeAll("}\n");
    try out.flush();
}
pub fn process(init: std.process.Init, client: *abi.Client, request: Request, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    var operation: ?*abi.Operation = null;
    defer abi.Api.transit_operation_destroy(operation);
    var buffer: ?*abi.Buffer = null;
    defer abi.Api.transit_buffer_destroy(buffer);
    var status: abi.Status = .ok;
    switch (request) {
        .hello => return respond(out, 0, "{\"host_version\":1,\"transit_version\":1}"),
        .capabilities => return respond(out, 0, try std.json.Stringify.valueAlloc(allocator, Capabilities{}, .{})),
        .prepare => |prepare| {
            var seed = try readSeed(init, prepare.seed_file);
            defer std.crypto.secureZero(u8, &seed);
            status = abi.Api.transit_operation_prepare(prepare.kind, &seed, prepare.document.ptr, prepare.document.len, &operation);
            if (status == .ok) status = abi.Api.transit_operation_export(operation.?, &buffer);
            return respond(out, @backingInt(status), if (buffer) |ptr| try std.json.Stringify.valueAlloc(allocator, abi.Api.transit_buffer_data(ptr)[0..abi.Api.transit_buffer_size(ptr)], .{}) else "null");
        },
        .call, .metadata => |frozen| {
            status = abi.Api.transit_operation_import(frozen.ptr, frozen.len, &operation);
            if (status == .ok) status = if (request == .call) abi.Api.transit_client_call(client, operation.?, &buffer) else abi.Api.transit_operation_metadata(operation.?, &buffer);
        },
    }
    try respond(out, @backingInt(status), if (buffer) |ptr| abi.Api.transit_buffer_data(ptr)[0..abi.Api.transit_buffer_size(ptr)] else "null");
}

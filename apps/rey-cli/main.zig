//! Explicit one-shot operations. Uncertain mutation outcomes require retrying
//! the exact saved request; the CLI never invents a new sequence automatically.
const std = @import("std");
const transit = @import("transit");
const wire = @import("transit_client");
fn print(io: std.Io, value: anytype) !void {
    var buffer: [wire.max_body]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try std.json.Stringify.value(value, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 3 and std.mem.eql(u8, args[1], "public-key")) {
        const key = try wire.readKey(init.gpa, init.io, args[2]);
        return print(init.io, key.public_key.toBytes());
    }
    if (args.len < 4) return error.ExpectedSignSubmitOrViewWithKeyAndRequestFile;
    const command = args[1];
    const key = try wire.readKey(init.gpa, init.io, args[2]);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var request = try std.json.parseFromSlice(transit.Request, init.gpa, bytes, .{});
    defer request.deinit();
    const signed = try transit.sign(request.value, key);
    if (std.mem.eql(u8, command, "sign") and args.len == 4) return print(init.io, signed);
    if (args.len != 5) return error.ExpectedAuthorityUrl;
    var client = wire.Client.init(init.gpa, init.io, args[4]);
    defer client.deinit();
    if (std.mem.eql(u8, command, "submit")) return print(init.io, try client.submit(signed));
    if (std.mem.eql(u8, command, "view")) return print(init.io, try client.view(request.value, key));
    return error.UnknownCommand;
}

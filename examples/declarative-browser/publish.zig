//! Example-owned declaration publication through the public catalog client.
//! The request and response files belong to configure.py's recovery journal.
const std = @import("std");
const catalog = @import("transit_catalog");
const client = catalog.client;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.ExpectedSeedRequestAndAuthority;
    var key = try client.readKey(init.gpa, init.io, args[1]);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(client.max_body));
    defer init.gpa.free(bytes);
    const allocator = init.arena.allocator();
    const request = try std.json.parseFromSlice(catalog.BrowserAdministration.Request, allocator, bytes, .{ .duplicate_field_behavior = .@"error" });
    var authority = client.Client.init(allocator, init.io, args[3]);
    defer authority.deinit();
    const store: catalog.BrowserRecordStore = .{ .client = .{ .allocator = allocator, .authority = &authority, .service = &authority, .connection = request.value.connection, .key = key }, .namespace = request.value.namespace };
    const result = try catalog.BrowserAdministration.execute(store, request.value);
    var buffer: [client.max_body]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var encoder = std.json.Stringify{ .writer = &writer.interface };
    try client.protocol.Json.write(result, &encoder);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}

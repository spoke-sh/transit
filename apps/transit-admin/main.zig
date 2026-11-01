//! Explicit one-shot operations. Uncertain mutation outcomes require retrying
//! the exact saved request; the CLI never invents a new sequence automatically.
const std = @import("std");
const transit = wire.protocol;
const wire = @import("transit_client");
const observations = wire.observability;
const telemetry = observations.telemetry;
fn print(io: std.Io, value: anytype) !void {
    var buffer: [wire.max_body]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer.interface };
    try transit.Json.write(value, &encoder);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-admin", .debug, runMain);
    if (status != 0) std.process.exit(status);
}
fn runMain(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
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
    if (std.mem.eql(u8, command, "browser")) {
        if (args.len != 5) return error.ExpectedAuthorityUrl;
        const catalog = @import("transit_catalog");
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const allocator = arena.allocator();
        const request = try std.json.parseFromSlice(catalog.BrowserAdministration.Request, allocator, bytes, .{ .duplicate_field_behavior = .@"error" });
        var client = wire.Client.init(allocator, init.io, args[4]);
        defer client.deinit();
        client.observer = diagnostics;
        const store: catalog.BrowserRecordStore = .{ .client = .{ .allocator = allocator, .authority = &client, .service = &client, .connection = request.value.connection, .key = key }, .namespace = request.value.namespace };
        return print(init.io, try catalog.BrowserAdministration.execute(store, request.value));
    }
    if (std.mem.eql(u8, command, "query") or std.mem.eql(u8, command, "sign-query")) {
        const query = try std.json.parseFromSlice(transit.Growth.Query, init.gpa, bytes, .{});
        defer query.deinit();
        if (std.mem.eql(u8, command, "sign-query")) {
            if (args.len != 4) return error.ExpectedKeyAndRequestFile;
            return print(init.io, try transit.Growth.signQuery(query.value, key));
        }
        if (args.len != 5) return error.ExpectedAuthorityUrl;
        var client = wire.Client.init(init.gpa, init.io, args[4]);
        defer client.deinit();
        client.observer = diagnostics;
        return print(init.io, try client.query(query.value, key));
    }
    if (!std.mem.eql(u8, command, "submit") and !std.mem.eql(u8, command, "sign")) return error.UnknownCommand;
    const request = try std.json.parseFromSlice(transit.Growth.Request, init.gpa, bytes, .{});
    defer request.deinit();
    const signed = try transit.Growth.sign(request.value, key);
    if (std.mem.eql(u8, command, "sign")) {
        if (args.len != 4) return error.ExpectedKeyAndRequestFile;
        return print(init.io, signed);
    }
    if (args.len != 5) return error.ExpectedAuthorityUrl;
    var client = wire.Client.init(init.gpa, init.io, args[4]);
    defer client.deinit();
    client.observer = diagnostics;
    return print(init.io, try client.submit(signed));
}

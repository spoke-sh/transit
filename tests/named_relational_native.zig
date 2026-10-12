//! Real administrative casts and publishing-peer calls; all record semantics
//! belong to transit-station-app. This host uses no raw provider access.
const std = @import("std");
const app = @import("transit_station_app");
const q = app.query;
const s = app.station;
const p = app.protocol;
const r = app.NamedRelationalRecords;
const captured = @import("relational_captured_native.zig");
pub fn owner(resource: u64, pid: u64) app.NamedRelational {
    return .{ .configuration = .{ .scope = .{ .realm = 46, .resource = resource, .owner = pid, .namespace = 55 }, .administrator = 0, .records = 4096, .bytes = 32 * 1024 * 1024 } };
}
pub fn handle(turn: *s.Turn, frame: s.Frame, workspace: []u8) !bool {
    const text = frame.payload.slice();
    const naming = owner(turn.view.resource, turn.delivery.pid);
    if (frame.kind == .call and std.mem.startsWith(u8, text, "NRA1")) {
        _ = try naming.activate(turn, try r.Activation.decode(frame.payload), workspace);
        return true;
    }
    if (frame.kind != .cast) return false;
    if (std.mem.startsWith(u8, text, "NRI1") or std.mem.startsWith(u8, text, "NRU1") or std.mem.startsWith(u8, text, "NRG1")) {
        try naming.control(turn, workspace);
        return true;
    }
    if (std.mem.startsWith(u8, text, "named-call:")) {
        const who = switch (turn.delivery.input.origin) {
            .external => |origin| origin.principal,
            else => return error.AccessDenied,
        };
        if (who != 0) return error.AccessDenied;
        const activation = try r.Activation.decode(try p.Value.init(text[11..]));
        const correlation = try turn.call(turn.delivery.pid, try activation.encode(), null);
        try turn.write(captured.correlation_key, q.UnifiedRecords.identityValue(correlation));
        return true;
    }
    return false;
}
pub fn run(comptime Test: type, init: std.process.Init, wire: *s.client.Client, admin: anytype, directory: []const u8, config: Test.Config, request: s.PublicationReference, maintained: bool, mode: []const u8, args: anytype) !void {
    const naming = owner(config.writer.resource, config.writer.pid);
    var source = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 1234, .key = try Test.key(10) }).open(config.writer.resource);
    if (std.mem.eql(u8, mode, "status")) {
        const ref = try naming.lookup(&source, try r.Name.init(args[4]));
        const definition = if (ref) |value| try naming.definition(&source, value) else null;
        return Test.print(init, .{ .reference = ref, .definition = definition, .budget = try naming.budget(&source), .policy = try q.RelationalCapture.policy(&source, config.writer.pid) });
    }
    if (std.mem.eql(u8, mode, "save")) {
        const ref = (try naming.lookup(&source, try r.Name.init(args[4]))) orelse return error.NamedQueryNotFound;
        try Test.save(init, directory, args[5], ref);
        return Test.print(init, ref);
    }
    if (std.mem.eql(u8, mode, "attribution")) {
        const correlation = try q.UnifiedRecords.readIdentity((try source.read(captured.correlation_key)).?);
        const revision = if (maintained) (try q.RelationalMaintenance.head(&source, .{ .peer = config.writer.pid, .correlation = correlation })).policy_revision else (try q.RelationalCapture.job(&source, try q.UnifiedRecords.readIdentity((try source.read(q.RelationalRecords.key('i', config.writer.pid, correlation))).?))).policy_revision;
        return Test.print(init, try naming.attribution(&source, config.writer.pid, revision));
    }
    const payload: p.Value = if (std.mem.eql(u8, mode, "initialize")) try (@as(r.Control, .initialize)).encode() else if (std.mem.eql(u8, mode, "publish")) try (r.Control{ .publish = .{ .name = try r.Name.init(args[4]), .object = try std.fmt.parseInt(u64, args[5], 10), .expected = try std.fmt.parseInt(u64, args[6], 10), .peer = config.writer.pid, .request = request } }).encode() else if (std.mem.eql(u8, mode, "authorize")) try (r.Control{ .authorize = .{ .reference = try Test.load(r.Reference, init, directory, args[4]), .expected = try std.fmt.parseInt(u64, args[5], 10), .principal = 1234, .allow = std.mem.eql(u8, args[6], "allow") } }).encode() else if (std.mem.eql(u8, mode, "activate")) blk: {
        const activation: r.Activation = .{ .reference = try Test.load(r.Reference, init, directory, args[4]), .policy_revision = try std.fmt.parseInt(u64, args[5], 10) };
        const encoded = try activation.encode();
        var bytes: [256]u8 = undefined;
        @memcpy(bytes[0..11], "named-call:");
        @memcpy(bytes[11..][0..encoded.len], encoded.slice());
        break :blk try p.Value.init(bytes[0 .. 11 + encoded.len]);
    } else return error.InvalidProofCommand;
    _ = try admin.submit(.{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } });
    try Test.print(init, .{ .state = "queued" });
}

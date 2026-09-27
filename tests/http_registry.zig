//! Independent naming authority for the HTTP caller-retirement/rebind schedule.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(47);
pub const Saved = struct { pid: u64, resource: u64, generation: u64 = 2 };
const Handler = struct {
    initialize: bool,
    binding: ?s.Registry.Binding = null,
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
        const self: *Handler = @ptrCast(@alignCast(raw.?));
        if (self.initialize) {
            try s.Registry.create(turn, 1);
            try s.Registry.grant(turn, 1, .{ .principal = 0 }, .{ .lookup = true, .mutate = true });
        }
        self.binding = try s.Registry.apply(turn, try s.Registry.Request.decode(frame.payload));
    }
};
pub fn apply(init: std.process.Init, admin: *Admin, saved: *?Saved, operation: @FieldType(s.Registry.Request, "operation"), destination: u64, revision: u64) !s.Registry.Binding {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(75));
    const initialize = saved.* == null;
    if (initialize) {
        const process = try admin.provision(65538, key);
        saved.* = .{ .pid = process.pid, .resource = process.resource };
    } else {
        _ = try admin.submit(.{ .own = .{ .pid = saved.*.?.pid, .expected_generation = saved.*.?.generation, .worker = 65538 } });
        saved.*.?.generation += 1;
    }
    const request: s.Registry.Request = .{ .scope = 1, .name = try s.Registry.Name.init("http-caller"), .operation = operation, .destination = destination, .expected_revision = revision };
    _ = try admin.submit(.{ .send = .{ .pid = saved.*.?.pid, .value = try (s.Frame{ .kind = .cast, .payload = try request.encode() }).encode() } });
    var server = try s.GrowingGenServer.init(.{ .client = admin.wire, .realm = 47, .principal = 65538, .pid = saved.*.?.pid, .generation = saved.*.?.generation, .key = key }, "state");
    var handler: Handler = .{ .initialize = initialize };
    for (0..32) |_| switch (try server.step(.{ .context = &handler, .handle = Handler.handle }, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000)) {
        .committed => return handler.binding orelse error.MissingRegistryResult,
        .blocked => return server.handler_error orelse error.RegistryBlocked,
        .idle => return error.MissingRegistryInput,
        .progress => {},
    };
    return error.RegistryStepBudgetExceeded;
}

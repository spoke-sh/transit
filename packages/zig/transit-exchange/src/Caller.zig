//! Finite caller publication and authenticated reply storage over the public
//! Station client. The adapter supplies only its request/outcome codecs.
const std = @import("std");
const x = @import("root.zig");
const s = x.station;
const p = x.p;
pub const Options = struct { call_key: p.Value, outcome_key: p.Value, tick: []const u8 };
pub fn For(comptime Adapter: type, comptime options: Options) type {
    return struct {
        const Driver = @This();
        server: s.GrowingGenServer,
        reader: x.Client,
        peer: u64,
        io: std.Io,
        prepared: Adapter.RequestRecord.Prepared,
        content: []const u8,
        fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
            const self: *Driver = @ptrCast(@alignCast(raw.?));
            if (frame.kind == .reply) {
                const saved = (try turn.read(options.call_key)) orelse return error.MissingCall;
                if (saved.len != 16 or try s.Frame.source(turn.delivery.input) != std.mem.readInt(u64, saved.data[0..8], .little) or frame.correlation != std.mem.readInt(u64, saved.data[8..16], .little)) return error.WrongReply;
                _ = try Adapter.Service.Outcome.decode(frame.payload);
                try turn.put(options.outcome_key, frame.payload);
                return;
            }
            switch (turn.delivery.input.origin) {
                .external => |origin| if (origin.principal != self.reader.principal) return error.UnexpectedInput,
                else => return error.UnexpectedInput,
            }
            if (frame.kind != .cast or !std.mem.eql(u8, frame.payload.slice(), "example.Adapter.tick.v1")) return error.UnexpectedInput;
            if (try turn.read(options.call_key) != null) return;
            if (try Adapter.RequestRecord.stage(turn, self.prepared.reference, self.prepared.metadata, self.content)) {
                const correlation = try turn.call(self.peer, try self.prepared.reference.encode(), null);
                var saved: [16]u8 = undefined;
                std.mem.writeInt(u64, saved[0..8], self.peer, .little);
                std.mem.writeInt(u64, saved[8..16], correlation, .little);
                try turn.put(options.call_key, try p.Value.init(&saved));
            }
        }
        pub fn drive(self: *Driver) !void {
            for (0..32) |_| {
                const result = self.server.step(.{ .context = self, .handle = handle }, @as(u64, @intCast(std.Io.Clock.real.now(self.io).toMilliseconds())) + 30000) catch |err| {
                    // A pending submission retains exactly the signed operation.
                    if (self.server.pending == null or err == error.AccessDenied or err == error.Rejected or err == error.Conflict) return err;
                    continue;
                };
                switch (result) {
                    .committed => return,
                    .idle => return error.InputNotDelivered,
                    .blocked => return self.server.handler_error orelse error.CallerBlocked,
                    .progress => {},
                }
            }
            return error.AuthorityOutcomeUnknown;
        }
        pub fn tick(self: *Driver) !void {
            const sequence = (try self.reader.query(.{ .capabilities = {} })).principal_sequence + 1;
            const signed = try p.Growth.sign(.{ .realm = self.reader.realm, .principal = self.reader.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.server.session.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("example.Adapter.tick.v1") }).encode() } } }, self.reader.key);
            for (0..3) |_| {
                _ = self.reader.wire.submitGrowing(signed) catch |err| {
                    if (err == error.AccessDenied or err == error.Conflict or err == error.Rejected) return err;
                    continue;
                };
                return self.drive();
            }
            return error.AuthorityOutcomeUnknown;
        }
        pub fn read(self: *Driver, name: p.Value) !?p.Value {
            var source = try self.reader.reader(self.prepared.reference.resource);
            return source.read(name);
        }
    };
}

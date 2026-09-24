//! The application owns its computation; Station owns the behavior protocol.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;

pub const Application = struct {
    role: enum { ledger, requester } = .ledger,
    destination: ?u64 = null,

    pub fn behavior(self: *Application) station.GenServer.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn initialize(_: ?*anyopaque, turn: *station.Turn) !void {
        try turn.put(try p.Value.init("total"), p.Value.integer(0));
    }
    fn handle(context: ?*anyopaque, turn: *station.Turn, frame: station.Frame) !void {
        const self: *Application = @ptrCast(@alignCast(context.?));
        if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "init")) return;
        switch (self.role) {
            .ledger => {
                if (frame.kind != .call and frame.kind != .cast) return error.UnexpectedLedgerMessage;
                const key = try p.Value.init("total");
                const previous = try (turn.get(key) orelse return error.UninitializedLedger).asInteger();
                const delta = try frame.payload.asInteger();
                const total = p.Value.integer(try std.math.add(i64, previous, delta));
                try turn.put(key, total);
                if (frame.kind == .call) try turn.reply(total);
            },
            .requester => switch (frame.kind) {
                .cast => _ = try turn.call(self.destination orelse return error.MissingDestination, frame.payload, null),
                .reply => try turn.put(try p.Value.init("answer"), frame.payload),
                .call => return error.UnexpectedRequesterCall,
            },
        }
    }
};

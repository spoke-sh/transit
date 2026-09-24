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
        const schema: station.fuze.model.Schema = .{ .names = .{ try station.fuze.model.Name.init("id"), try station.fuze.model.Name.init("amount") }, .value_type = .int64 };
        _ = try station.Table.create(turn, 1, schema);
        _ = try station.Table.create(turn, 2, schema);
    }
    fn handle(context: ?*anyopaque, turn: *station.Turn, frame: station.Frame) !void {
        const self: *Application = @ptrCast(@alignCast(context.?));
        if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "init")) return;
        switch (self.role) {
            .ledger => {
                if (frame.kind != .call and frame.kind != .cast) return error.UnexpectedLedgerMessage;
                const table = try station.Table.open(turn, 1);
                if (std.mem.eql(u8, frame.payload.slice(), "query")) {
                    var workspace: [station.fuze.execution.working_bytes]u8 = undefined;
                    const cancel = station.fuze.execution.Cancellation.init(false);
                    _ = station.Query.capture(turn, table, .{}, &workspace, &cancel) catch |err| {
                        var buffer: [128]u8 = undefined;
                        try turn.reply(try p.Value.init(try std.fmt.bufPrint(&buffer, "station.query.error.{s}", .{@errorName(err)})));
                    };
                    return;
                }
                // A synthetic owner command demonstrates ordered policy updates.
                // Only the configured root principal may change this demo policy.
                if (std.mem.eql(u8, frame.payload.slice(), "allow-query") or std.mem.eql(u8, frame.payload.slice(), "deny-query")) {
                    switch (turn.delivery.input.origin.source) {
                        .external => |origin| if (origin.principal != 0) return error.AccessDenied,
                        else => return error.AccessDenied,
                    }
                    const peer = self.destination orelse return error.MissingDestination;
                    const old = try station.Query.policy(turn, peer);
                    try station.Query.setPolicy(turn, peer, 1, if (old) |grant| grant.revision else 0, std.mem.eql(u8, frame.payload.slice(), "allow-query"));
                    return;
                }
                const previous = if (try table.get(turn, 1)) |row| row.value.int64 else 0;
                const delta = try frame.payload.asInteger();
                const total = try std.math.add(i64, previous, delta);
                const audit = try station.Table.open(turn, 2);
                try station.Table.atomic(turn, &.{
                    .{ .table = table, .operation = .{ .upsert = .{ .key = 1, .value = .{ .int64 = total } } } },
                    .{ .table = audit, .operation = .{ .insert = .{ .key = @intCast(turn.delivery.input.position), .value = .{ .int64 = delta } } } },
                });
                if (frame.kind == .call) try turn.reply(p.Value.integer(total));
            },
            .requester => switch (frame.kind) {
                .cast => _ = try turn.call(self.destination orelse return error.MissingDestination, frame.payload, null),
                .reply => try turn.put(try p.Value.init("answer"), frame.payload),
                .result_complete => {
                    const result = try station.Query.completed(turn, frame.correlation);
                    try turn.put(try p.Value.init("last-query"), p.Value.integer(@intCast(result.manifest.result)));
                },
                else => return error.UnexpectedRequesterMessage,
            },
        }
    }
};

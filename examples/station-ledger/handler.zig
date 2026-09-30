//! The application owns its computation; Station owns the behavior protocol.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;

pub const Application = struct {
    role: enum { ledger, requester, coordinator } = .ledger,
    destination: ?u64 = null,
    observer: ?u64 = null,
    registry: ?u64 = null,

    pub fn behavior(self: *Application) station.GenServer.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn initialize(context: ?*anyopaque, turn: *station.Turn) !void {
        const self: *Application = @ptrCast(@alignCast(context.?));
        if (self.role == .coordinator) {
            try station.Registry.create(turn, 1);
            try station.Registry.grant(turn, 1, .{ .principal = 0 }, .{ .lookup = true, .mutate = true });
            try turn.cast(turn.delivery.pid, try p.Value.init("initialize-supervisor"));
            return;
        }
        const schema: station.fuze.model.Schema = .{ .names = .{ try station.fuze.model.Name.init("id"), try station.fuze.model.Name.init("amount") }, .value_type = .int64 };
        _ = try station.Table.create(turn, 1, schema);
        _ = try station.Table.create(turn, 2, schema);
    }
    fn handle(context: ?*anyopaque, turn: *station.Turn, frame: station.Frame) !void {
        const self: *Application = @ptrCast(@alignCast(context.?));
        if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "init")) return;
        switch (self.role) {
            .coordinator => {
                if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "initialize-supervisor")) {
                    if (try station.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
                    try station.Supervisor.register(turn, .{ .pid = self.destination orelse return error.MissingDestination, .observer = self.observer orelse return error.MissingObserver, .limit = 1, .backoff_ms = 0 });
                    return;
                }
                if (frame.kind == .call) return station.Registry.handle(turn, frame);
                if (frame.kind != .cast) return error.UnexpectedCoordinatorMessage;
                if (std.mem.startsWith(u8, frame.payload.slice(), "SUP1")) return station.Supervisor.observe(turn, try station.Supervisor.Observation.decode(frame));
                switch (turn.delivery.input.origin) {
                    .external => |origin| if (origin.principal != 0) return error.AccessDenied,
                    else => return error.AccessDenied,
                }
                if (std.mem.startsWith(u8, frame.payload.slice(), "lookup-peer:")) {
                    const peer = try std.fmt.parseInt(u64, frame.payload.slice()[12..], 10);
                    try station.Registry.grant(turn, 1, .{ .process = peer }, .{ .lookup = true });
                    return;
                }
                if (std.mem.startsWith(u8, frame.payload.slice(), "watch:")) {
                    const pid = try std.fmt.parseInt(u64, frame.payload.slice()[6..], 10);
                    try station.Supervisor.register(turn, .{ .pid = pid, .observer = self.observer orelse return error.MissingObserver, .limit = 1, .backoff_ms = 0 });
                    return;
                }
                const request = try station.Registry.Request.decode(frame.payload);
                _ = try station.Registry.apply(turn, request);
            },
            .ledger => {
                if (frame.kind != .call and frame.kind != .cast) return error.UnexpectedLedgerMessage;
                const table = try station.Table.open(turn, 1);
                if (std.mem.eql(u8, frame.payload.slice(), "query")) {
                    _ = station.Query.start(turn, table, .{}) catch |err| {
                        var buffer: [128]u8 = undefined;
                        try turn.reply(try p.Value.init(try std.fmt.bufPrint(&buffer, "station.query.error.{s}", .{@errorName(err)})));
                    };
                    return;
                }
                // A synthetic owner command demonstrates ordered policy updates.
                // Only the configured root principal may change this demo policy.
                if (std.mem.eql(u8, frame.payload.slice(), "allow-query") or std.mem.eql(u8, frame.payload.slice(), "deny-query")) {
                    switch (turn.delivery.input.origin) {
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
                .cast => {
                    if (std.mem.eql(u8, frame.payload.slice(), "lookup")) {
                        _ = try turn.call(self.registry orelse return error.MissingRegistry, try (station.Registry.Request{ .scope = 1, .name = try station.Registry.Name.init("ledger"), .operation = .lookup }).encode(), null);
                    } else if (std.mem.startsWith(u8, frame.payload.slice(), "wait:")) {
                        const split = std.mem.indexOfScalarPos(u8, frame.payload.slice(), 5, ':') orelse return error.InvalidTimedCall;
                        const deadline = try std.fmt.parseInt(u64, frame.payload.slice()[5..split], 10);
                        _ = try turn.callWithTimer(self.destination orelse return error.MissingDestination, try p.Value.init(frame.payload.slice()[split + 1 ..]), deadline, self.observer orelse return error.MissingObserver);
                    } else _ = try turn.call(self.destination orelse return error.MissingDestination, frame.payload, null);
                },
                .reply => {
                    if (std.mem.startsWith(u8, frame.payload.slice(), "RGR1")) {
                        _ = try station.Registry.route(turn, self.registry orelse return error.MissingRegistry, frame, try p.Value.init("0"));
                    } else try turn.put(try p.Value.init("answer"), frame.payload);
                },
                .timeout => try turn.put(try p.Value.init("answer"), try p.Value.init("timeout")),
                .result_complete => {
                    const result = try station.Query.completed(turn, frame.correlation);
                    try turn.put(try p.Value.init("last-query"), p.Value.integer(@intCast(result.result)));
                },
                else => return error.UnexpectedRequesterMessage,
            },
        }
    }
};

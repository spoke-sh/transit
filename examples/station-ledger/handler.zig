//! The application owns its computation; Station owns the behavior protocol.
const std = @import("std");
const query = @import("transit_query");
const station = query.station;
const Ledger = @import("Ledger.zig");
const Query = @import("Query.zig");
const Authorization = @import("Authorization.zig");
const p = station.protocol;

pub const Application = struct {
    allocator: std.mem.Allocator,
    resources: station.client.ResourceReader,
    authority: ?Authorization = null,
    peer_principal: ?u64 = null,
    source_resource: ?u64 = null,
    peer_resource: ?u64 = null,
    capture: ?struct { adapter: []u8, workspace: []u8, cancellation: *const query.fuze.execution.Cancellation } = null,
    role: enum { ledger, requester, coordinator } = .ledger,
    destination: ?u64 = null,
    observer: ?u64 = null,
    registry: ?u64 = null,

    fn authorization(self: *Application) !Authorization {
        return self.authority orelse error.MissingApplicationAuthorization;
    }

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
        try (try self.authorization()).data.bind(turn, true);
        if (self.role == .ledger and self.destination != null) {
            const capture = self.capture orelse return error.MissingQueryPeer;
            var source: query.UnifiedBehavior.Source = .{ .peer = self.destination.?, .initializer = turn.delivery.principal, .resources = self.resources, .adapter = capture.adapter, .workspace = capture.workspace, .cancellation = capture.cancellation };
            const source_handler = source.interface();
            try source_handler.initialize.?(source_handler.context, turn);
        }
    }
    fn handle(context: ?*anyopaque, turn: *station.Turn, frame: station.Frame) !void {
        const self: *Application = @ptrCast(@alignCast(context.?));
        return self.dispatch(turn, frame) catch |err| {
            // Native reads and direct operations cannot fabricate a failed
            // application turn when their observation is unavailable or contended.
            // Direct dispatch reopens its committed intent on the next turn.
            const rejection = self.resources.wire.last_rejection;
            if (err == error.InvalidLedgerDataBinding or err == error.LedgerDataBindingChanged or err == error.MissingLedgerDataBinding or err == error.IncompatibleDefinition or station.client.Client.unavailable(err) or self.resources.wire.contended(err) or ((err == error.Rejected or err == error.Conflict) and (rejection == .StaleStateResource or rejection == .QueryExpired or rejection == .StateViewExpired))) turn.read_error = err;
            return err;
        };
    }
    fn dispatch(self: *Application, turn: *station.Turn, frame: station.Frame) !void {
        if (self.role != .coordinator) try (try self.authorization()).data.bind(turn, false);
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
                const authority = try self.authorization();
                if (frame.kind == .cast and frame.payload.eql(Ledger.continuation)) return Ledger.drive(self.allocator, turn, authority, authority.data);
                if (frame.kind == .cast and frame.payload.eql(Ledger.create_continuation)) return Ledger.create(self.allocator, turn, true, authority, authority.data);
                if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "prepare-table")) return Ledger.create(self.allocator, turn, false, authority, authority.data);
                if (frame.kind == .cast and (std.mem.eql(u8, frame.payload.slice(), "allow-query") or std.mem.eql(u8, frame.payload.slice(), "deny-query"))) {
                    switch (turn.delivery.input.origin) {
                        .external => |origin| if (origin.principal != 0) return error.AccessDenied,
                        else => return error.AccessDenied,
                    }
                    const peer = self.destination orelse return error.MissingDestination;
                    const old = try query.UnifiedCapture.policy(turn, peer);
                    try query.UnifiedCapture.setPolicy(turn, .{ .peer = peer, .requests = self.peer_resource orelse return error.MissingQueryResource, .revision = if (old) |grant| grant.revision + 1 else 1, .target = .{ .catalog = .{ .scope = authority.data.scope, .owner = authority.data.audience, .principal = self.peer_principal orelse return error.MissingQueryPrincipal } }, .allow = std.mem.eql(u8, frame.payload.slice(), "allow-query"), .limits = Query.limits });
                    return;
                }
                if (frame.kind == .cancel) {
                    const peer = try station.Frame.source(turn.delivery.input);
                    // Cancellation of an application delta is advisory. Only a
                    // recorded query correlation enters query cleanup.
                    if (try turn.read(query.UnifiedRecords.key('i', peer, frame.correlation)) == null) return;
                }
                if (frame.kind == .cancel or (frame.kind == .call and std.mem.startsWith(u8, frame.payload.slice(), "SPF1")) or (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "UQN1"))) {
                    const capture = self.capture orelse return error.MissingQueryPeer;
                    // The executor authenticates its own login. The saved
                    // requester grant supplies the independently selected role.
                    var executor = authority.client;
                    executor.role = null;
                    return query.UnifiedBehavior.dispatchSource(turn, frame, self.destination orelse return error.MissingDestination, turn.delivery.principal, query.UnifiedBehavior.Resources{ .native = self.resources, .tables = try authority.data.client(self.allocator, executor) }, capture.adapter, capture.workspace, capture.cancellation);
                }
                if (frame.kind != .call and frame.kind != .cast) return error.UnexpectedLedgerMessage;
                try Ledger.enqueue(self.allocator, turn, frame, authority);
            },
            .requester => switch (frame.kind) {
                .cast => {
                    if (frame.payload.eql(Query.continuation)) return Query.drive(self.allocator, turn, self.destination orelse return error.MissingDestination, self.observer);
                    if (std.mem.eql(u8, frame.payload.slice(), "query")) return Query.enqueue(self.allocator, turn, self.source_resource orelse return error.MissingQueryResource, self.destination orelse return error.MissingDestination, try self.authorization(), (try self.authorization()).data);
                    if (std.mem.eql(u8, frame.payload.slice(), "lookup")) {
                        _ = try turn.call(self.registry orelse return error.MissingRegistry, try (station.Registry.Request{ .scope = 1, .name = try station.Registry.Name.init("ledger"), .operation = .lookup }).encode(), null);
                    } else if (std.mem.startsWith(u8, frame.payload.slice(), "wait:")) {
                        const split = std.mem.indexOfScalarPos(u8, frame.payload.slice(), 5, ':') orelse return error.InvalidTimedCall;
                        const deadline = try std.fmt.parseInt(u64, frame.payload.slice()[5..split], 10);
                        _ = try turn.callWithTimer(self.destination orelse return error.MissingDestination, try p.Value.init(frame.payload.slice()[split + 1 ..]), deadline, self.observer orelse return error.MissingObserver);
                    } else _ = try turn.call(self.destination orelse return error.MissingDestination, frame.payload, null);
                },
                .reply => {
                    if (try Query.reply(turn, frame, self.destination orelse return error.MissingDestination)) return;
                    if (std.mem.startsWith(u8, frame.payload.slice(), "RGR1")) {
                        _ = try station.Registry.route(turn, self.registry orelse return error.MissingRegistry, frame, try p.Value.init("0"));
                    } else try turn.put(try p.Value.init("answer"), frame.payload);
                },
                .timeout => try turn.put(try p.Value.init("answer"), try p.Value.init("timeout")),
                else => return error.UnexpectedRequesterMessage,
            },
        }
    }
};

//! Application-owned encoding over the public state API. No core/store imports.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const handler = @import("handler.zig");

pub fn submit(client: *wire.Client, pending: wire.Session.Pending, io: std.Io) !p.Receipt {
    while (true) return pending.submit(client) catch |err| switch (err) {
        error.AccessDenied, error.Rejected => return err,
        else => {
            // An uncertain append is retried without changing its signed bytes.
            try io.sleep(.fromMilliseconds(200), .awake);
            continue;
        },
    };
}

pub fn prepare(session: *wire.Session, delivery: wire.Session.Delivery, name: []const u8, destination: ?u64, io: std.Io) !wire.Session.Pending {
    const wanted = try p.Value.init(name);
    var associations = try session.associations();
    const resource_id = find: while (true) {
        for (associations.associations) |slot| if (slot) |association| {
            if (association.name.eql(wanted)) break :find association.resource;
        };
        const next = associations.next orelse return error.MissingStateAssociation;
        associations = try session.client.state(.{ .realm = session.realm, .principal = session.principal, .kind = .associations, .pid = session.pid, .after = next, .cut = associations.cut }, session.key);
    };
    const page = try session.client.state(.{ .realm = session.realm, .principal = session.principal, .kind = .resources, .resource = resource_id }, session.key);
    const resource = page.resources[0] orelse return error.InvalidAuthorityResponse;
    // Local time proposes a bounded read lease, never execution authority.
    // The authority validates it against its own trusted clock and lifetimes.
    var deadline: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds() + 30_000);
    if (resource.deadline_ms) |limit| deadline = @min(deadline, limit);
    const opened = try submit(session.client, try session.prepareStateView(delivery, resource, deadline), io);
    const key = try p.Value.init("value");
    const snapshot = try session.readStateView(opened.position, key);
    const view = snapshot.view orelse return error.InvalidAuthorityResponse;
    const current = if (snapshot.entries[0]) |entry| entry.value else p.Value.integer(0);
    const result = handler.apply(current, delivery.input.value) catch null;
    const fresh = (try session.receive()) orelse return error.InvalidAuthorityResponse;
    if (fresh.input.position != delivery.input.position or fresh.revision != delivery.revision) return error.InvalidAuthorityResponse;
    var decision: wire.Session.StateDecision = .{ .views = .{ view, null, null, null }, .failed = result == null };
    if (result) |value| {
        decision.write_view = view.id;
        decision.mutations[0] = .{ .key = key, .value = value };
        if (destination) |pid| decision.outputs[0] = .{ .pid = pid, .value = value };
    }
    return session.prepareStateCommit(fresh, decision);
}

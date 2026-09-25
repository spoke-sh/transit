//! Signed, bounded reads. Current permission is independent of the captured
//! resource version; a retained root is never a bearer capability.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growth = @import("growing.zig");
const state = @import("growing_state.zig");
const c = @import("catalog.zig");
const address = growth.address;
fn scope(principal: growth.Principal, pid: u64) !void {
    if (principal.grant.pid) |allowed| if (allowed != pid) return error.Forbidden;
}
fn resourceScope(engine: anytype, principal: growth.Principal, id: u64) !void {
    if (principal.grant.pid) |pid| if (!try state.associated(engine, pid, id)) return error.Forbidden;
}
fn at(position: ?u64, current: u64) !void {
    if (position) |expected| if (expected != current) return error.QueryExpired;
}
fn sample(engine: anytype) !?core.Time.Sample {
    const clock = engine.clock orelse return null;
    const value = try clock.sample();
    const bound = engine.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
    if (value.error_ms > bound or value.unix_ms > p.max_counter) return error.UntrustedTime;
    if (value.unix_ms < engine.head.time_floor_ms) return error.ClockRollback;
    return value;
}
pub fn read(engine: anytype, signed: g.SignedQuery) anyerror!g.Response {
    try g.validateQuery(signed.query);
    if (signed.query.realm != engine.genesis.realm) return error.WrongProtocolRealm;
    try engine.refresh();
    const query = signed.query;
    const principal = try engine.principal(query.principal);
    const public = p.Ed25519.PublicKey.fromBytes(principal.grant.public_key) catch return error.Unauthorized;
    p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.queryDigest(query), public) catch return error.Unauthorized;
    if (principal.grant.permissions & p.permission(.inspect) == 0) return error.Forbidden;
    const position = engine.head.position;
    var current = try engine.state();
    const body: @FieldType(g.Response, "body") = switch (query.kind) {
        .capabilities => .{ .capabilities = .{ .required_resources_per_process = engine.genesis.required_dependencies, .dependency_validation_vertices = engine.genesis.dependency_vertices, .association_lookup = true, .history_reclamation = true, .retained_history = if (engine.genesis.allow_history_trim) .checkpointed else .unlimited } },
        .process => |pid| blk: {
            try scope(principal, pid);
            const process = try engine.process(pid);
            var input: ?g.Input = null;
            if (process.lifecycle == .running) {
                try engine.executable(process, try sample(engine), true);
                if (process.consumed < process.admitted) input = (try current.get(g.Input, try c.key(.mailbox, pid, process.consumed + 1, ""))) orelse return error.IncompleteHistory;
            }
            break :blk .{ .process = .{ .process = process, .input = input } };
        },
        .resource => |id| blk: {
            try resourceScope(engine, principal, id);
            try state.allowed(engine, id, query.principal, p.State.permission(.inspect));
            break :blk .{ .resource = try state.resource(engine, id) };
        },
        .view => |id| blk: {
            const value = try state.view(engine, id);
            try scope(principal, value.meta.pid);
            try state.allowed(engine, value.meta.resource, query.principal, p.State.permission(.inspect));
            break :blk .{ .view = value.meta };
        },
        .association => |q| blk: {
            try scope(principal, q.pid);
            _ = try engine.process(q.pid);
            const value = (try current.get(g.Association, try c.key(.association, q.pid, 0, q.name.slice()))) orelse break :blk .{ .association = null };
            state.allowed(engine, value.resource, query.principal, p.State.permission(.inspect)) catch |err| {
                // Match filtered discovery: absence and a hidden target reveal
                // neither the association's existence nor its resource identity.
                if (err == error.Forbidden) break :blk .{ .association = null };
                return err;
            };
            break :blk .{ .association = value };
        },
        .entries => |q| blk: {
            const now = try sample(engine);
            var captured: ?g.View = null;
            var basis = current;
            var resource: g.Resource = undefined;
            if (q.view) |id| {
                const stored = try state.view(engine, id);
                try scope(principal, stored.meta.pid);
                const process = try engine.process(stored.meta.pid);
                try engine.executable(process, now, true);
                if (process.owner != query.principal) return error.StaleGeneration;
                const checked = try state.captured(engine, query.principal, process, id, stored.meta.input, now);
                basis = try @TypeOf(current).open(engine.page_store, checked.snapshot);
                resource = (try basis.get(g.Resource, address(.resource, checked.meta.resource))) orelse return error.InvalidHistory;
                if (resource.revision != checked.meta.revision) return error.InvalidHistory;
                captured = checked.meta;
            } else {
                const id = q.resource.?;
                try resourceScope(engine, principal, id);
                try state.allowed(engine, id, query.principal, p.State.permission(.inspect) | p.State.permission(.read));
                resource = try state.resource(engine, id);
                try state.usable(engine, resource, now);
                if (q.revision != resource.revision) return error.StaleStateResource;
            }
            var result: g.Batch(g.Entry, p.Value) = .{};
            if (q.key) |key| {
                result.entries[0] = try basis.get(g.Entry, try c.key(.entry, resource.id, 0, key.slice()));
                if (result.entries[0]) |entry| if (!entry.key.eql(key)) return error.InvalidHistory;
            } else {
                const after = if (q.after) |key| try c.key(.entry, resource.id, 0, key.slice()) else null;
                const batch = try basis.scan(g.Entry, .{ .namespace = .entry, .major = resource.id }, after);
                for (batch.records, 0..) |slot, i| if (slot) |record| {
                    if (!std.mem.allEqual(u8, record.key.data[9..17], 0) or !std.mem.eql(u8, record.key.slice()[17..], record.value.key.slice())) return error.InvalidHistory;
                    result.entries[i] = record.value;
                };
                if (batch.next) |cursor| result.next = try p.Value.init(cursor.slice()[17..]);
            }
            // A slow materialization cannot authorize a fresh disclosure after
            // a known deadline. Transport arrival can still occur later.
            if (captured) |view| _ = try state.captured(engine, query.principal, try engine.process(view.pid), view.id, view.input, try sample(engine)) else try state.usable(engine, resource, try sample(engine));
            break :blk .{ .entries = .{ .view = captured, .resource = resource, .page = result } };
        },
        .processes => |q| blk: {
            if (principal.grant.pid != null) return error.Forbidden;
            try at(q.position, position);
            const batch = try current.scan(g.Process, .{ .namespace = .process }, if (q.after) |id| address(.process, id) else null);
            var result: g.Batch(g.Process, u64) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                result.entries[i] = record.value;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[1..9], .big);
            break :blk .{ .processes = result };
        },
        .resources => |q| blk: {
            if (principal.grant.pid != null) return error.Forbidden;
            try at(q.position, position);
            const batch = try current.scan(g.Resource, .{ .namespace = .resource }, if (q.after) |id| address(.resource, id) else null);
            var result: g.Batch(g.Resource, u64) = .{};
            var count: usize = 0;
            for (batch.records) |slot| if (slot) |record| {
                state.allowed(engine, record.value.id, query.principal, p.State.permission(.inspect)) catch |err| {
                    if (err == error.Forbidden) continue;
                    return err;
                };
                result.entries[count] = record.value;
                count += 1;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[1..9], .big);
            break :blk .{ .resources = result };
        },
        .associations => |q| blk: {
            try scope(principal, q.pid);
            _ = try engine.process(q.pid);
            try at(q.position, position);
            // Advance through bounded filtered pages without disclosing a
            // hidden association's name in the continuation cursor.
            const batch = try current.scan(g.Association, .{ .namespace = .association_order, .major = q.pid }, if (q.after) |id| try c.key(.association_order, q.pid, id, "") else null);
            var result: g.Batch(g.Association, u64) = .{};
            var count: usize = 0;
            for (batch.records) |slot| if (slot) |record| {
                state.allowed(engine, record.value.resource, query.principal, p.State.permission(.inspect)) catch |err| {
                    if (err == error.Forbidden) continue;
                    return err;
                };
                result.entries[count] = record.value;
                count += 1;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[9..17], .big);
            break :blk .{ .associations = result };
        },
        .outputs => |q| blk: {
            if (principal.grant.pid != null) return error.Forbidden;
            try at(q.position, position);
            const batch = try current.scan(g.Outbox, .{ .namespace = .output }, if (q.after) |id| address(.output, id) else null);
            var result: g.Batch(g.Outbox, u64) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                result.entries[i] = record.value;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[1..9], .big);
            break :blk .{ .outputs = result };
        },
        .effects => |q| blk: {
            try scope(principal, q.pid);
            _ = try engine.process(q.pid);
            try at(q.position, position);
            const batch = try current.scan(u64, .{ .namespace = .effects_by_pid, .major = q.pid }, if (q.after) |id| try c.key(.effects_by_pid, q.pid, id, "") else null);
            var result: g.Batch(g.Effect, u64) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                const value = try @import("growing_work.zig").effect(engine, record.value);
                if (value.pid != q.pid) return error.InvalidHistory;
                result.entries[i] = value;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[9..17], .big);
            break :blk .{ .effects = result };
        },
    };
    // Linearize permission/cut validation against the same authority tail. A
    // concurrent revocation or publication never yields a success-shaped mixed cut.
    if (try engine.journal.tail() != position) return error.Conflict;
    return .{ .realm = query.realm, .position = position, .principal_sequence = principal.sequence, .body = body };
}

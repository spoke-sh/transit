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
fn viewPid(engine: anytype, id: u64) !u64 {
    const stored = state.view(engine, id) catch |err| switch (err) {
        error.StateViewExpired => return error.Forbidden,
        else => return err,
    };
    return stored.meta.pid;
}
fn sample(engine: anytype) !?core.Time.Sample {
    const clock = engine.clock orelse return null;
    const value = try clock.sample();
    const bound = engine.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
    if (value.error_ms > bound or value.unix_ms > p.max_counter) return error.UntrustedTime;
    if (value.unix_ms < engine.head.time_floor_ms) return error.ClockRollback;
    return value;
}
pub fn snapshotTime(engine: anytype) !core.Time.Sample {
    if (engine.snapshot_epoch == null) return error.InvalidRead;
    const now = (try sample(engine)) orelse return error.ClockUnavailable;
    if (now.unix_ms < engine.snapshot_time_floor_ms) return error.ClockRollback;
    engine.snapshot_time_floor_ms = now.unix_ms;
    return now;
}
pub fn snapshotAccess(engine: anytype, principal: growth.Principal, resource: u64, now: core.Time.Sample) !void {
    try resourceScope(engine, principal, resource);
    try state.allowed(engine, resource, principal.grant.subject, p.State.permission(.inspect) | p.State.permission(.read));
    try state.usable(engine, try state.resource(engine, resource), now);
}
fn snapshotRecheck(engine: anytype, principal: growth.Principal, resource: u64) !core.Time.Sample {
    try engine.refresh();
    const current = try engine.principal(principal.grant.subject);
    if (current.epoch != principal.epoch or current.grant.permissions & p.permission(.inspect) == 0 or
        !std.mem.eql(u8, &current.grant.public_key, &principal.grant.public_key)) return error.Forbidden;
    const now = try snapshotTime(engine);
    try snapshotAccess(engine, current, resource, now);
    return now;
}
pub fn sweepSnapshots(engine: anytype, now: core.Time.Sample) void {
    for (engine.snapshotSlots()) |*slot| if (slot.*) |stored| {
        if (now.lower() >= stored.meta.deadline_ms) slot.* = null;
    };
}
pub fn snapshotSlot(engine: anytype, id: g.SnapshotId, principal: growth.Principal, now: core.Time.Sample) !?*?growth.StoredSnapshot {
    if (!std.mem.eql(u8, &id.epoch, &engine.snapshot_epoch.?)) return null;
    sweepSnapshots(engine, now);
    for (engine.snapshotSlots()) |*slot| if (slot.*) |stored| {
        if (stored.meta.id.serial != id.serial) continue;
        if (stored.principal != principal.grant.subject or stored.principal_epoch != principal.epoch) return error.Forbidden;
        try now.before(stored.meta.deadline_ms);
        return slot;
    };
    return null;
}
pub fn read(engine: anytype, signed: g.SignedQuery) anyerror!g.Response {
    return withSnapshots(engine, signed, {});
}
/// Hooks reserve only volatile bookkeeping, after signed current admission.
/// Every disclosure still executes the ordinary current-root checks below.
pub fn withSnapshots(engine: anytype, signed: g.SignedQuery, hooks: anytype) anyerror!g.Response {
    try g.validateQuery(signed.query);
    if (signed.query.realm != engine.genesis.realm) return error.WrongProtocolRealm;
    try engine.refresh();
    const query = signed.query;
    var principal = try engine.principal(query.principal);
    const public = p.Ed25519.PublicKey.fromBytes(principal.grant.public_key) catch return error.Unauthorized;
    p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.queryDigest(query), public) catch return error.Unauthorized;
    if (!principal.enabled) return error.Forbidden;
    const needed: p.Permission = if (query.kind == .delivery) .delivery else .inspect;
    if (query.kind != .authorization and principal.grant.permissions & p.permission(needed) == 0) {
        const pid: ?u64 = switch (query.kind) {
            .process => |id| id,
            .inspection => |value| value.pid,
            inline .association, .associations, .effects, .read_versions => |value| value.pid,
            .read_version => |value| value.pid,
            .version_entries => |value| value.id.pid,
            .view => |id| try viewPid(engine, id),
            .entries => |value| if (value.view) |id| try viewPid(engine, id) else null,
            .read_entries => |value| if (value.view) |id| try viewPid(engine, id) else null,
            .block_entries => |value| switch (value.source) {
                .view => |id| try viewPid(engine, id),
                .version => |version| version.id.pid,
                .resource => null,
            },
            else => null,
        };
        if (!try @import("growing_authorization.zig").nativeHas(engine, principal, pid, needed)) return error.Forbidden;
        // This decision authorizes only the queried process, including every
        // subordinate read. It cannot become a realm-wide inspection identity.
        principal.grant.pid = pid;
        principal.grant.permissions |= p.permission(needed);
    }
    if (comptime @TypeOf(hooks) != void) try hooks.begin(engine, principal, query.kind);
    var success = false;
    defer if (comptime @TypeOf(hooks) != void) hooks.end(engine, success);
    const result = try authorized(engine, principal, query, hooks);
    success = true;
    return result;
}
fn authorized(engine: anytype, principal: growth.Principal, query: g.Query, hooks: anytype) anyerror!g.Response {
    if (query.kind == .snapshot_read) return @import("growing_snapshot_read.zig").read(engine, principal, query.realm, query.kind.snapshot_read);
    const position = engine.head.position;
    var current = try engine.state();
    const body: @FieldType(g.Response, "body") = switch (query.kind) {
        .authorization => |q| .{ .authorization = try @import("growing_authorization.zig").read(engine, principal, q) },
        .snapshot_read => unreachable,
        .delivery => blk: {
            const scoped = principal.grant.pid;
            const batch = try current.scan(u64, if (scoped) |pid| .{ .namespace = .pending_destination, .major = pid } else .{ .namespace = .pending_output }, null);
            const next: ?u64 = if (batch.records[0]) |r| if (scoped != null) r.value else std.mem.readInt(u64, r.key.data[1..9], .big) else null;
            break :blk .{ .delivery = .{ .next = next } };
        },
        .inspection => |q| .{ .inspection = try @import("growing_inspection.zig").read(engine, principal, q) },
        .identity => .{ .identity = .{ .principal = query.principal, .permissions = principal.grant.permissions, .pid = principal.grant.pid, .policy_revision = principal.revision } },
        .storage => blk: {
            // Node-wide paths and totals require realm-wide inspection. A
            // process grant must never disclose unrelated storage activity.
            if (principal.grant.pid != null) return error.Forbidden;
            if (comptime @TypeOf(hooks) != void) {
                if (@hasDecl(@typeInfo(@TypeOf(hooks)).pointer.child, "storage")) {
                    break :blk .{ .storage = try hooks.storage(engine) };
                }
            }
            break :blk .{ .storage = p.Storage.Observation.unavailable };
        },
        .capabilities => .{ .capabilities = .{ .required_resources_per_process = engine.genesis.required_dependencies, .dependency_validation_vertices = engine.genesis.dependency_vertices, .association_lookup = true, .scoped_retry = true, .retained_read_versions = true, .resource_read_access = true, .resource_read_batch = true, .immutable_blocks = @hasDecl(@TypeOf(engine.page_store.*), "stageBlock") and @hasDecl(@TypeOf(engine.page_store.*), "loadBlock"), .leased_snapshots = engine.snapshot_epoch != null and engine.clock != null, .snapshot_read = engine.snapshot_epoch != null and engine.clock != null, .worker_rotation = true, .declarative_authorization = true, .runtime_bindings = true, .station = true, .history_reclamation = true, .retained_history = if (engine.genesis.allow_history_trim) .checkpointed else .unlimited, .admission_ceiling = engine.genesis.admission_ceiling, .control_reserve = engine.genesis.control_reserve } },
        .open_snapshot => |q| blk: {
            const now = try snapshotTime(engine);
            try snapshotAccess(engine, principal, q.resource, now);
            sweepSnapshots(engine, now);
            var free: ?*?growth.StoredSnapshot = null;
            var owned: usize = 0;
            for (engine.snapshotSlots()) |*slot| {
                if (slot.*) |stored| {
                    if (stored.principal != query.principal) continue;
                    owned += 1;
                    if (stored.principal_epoch == principal.epoch and stored.meta.resource.id == q.resource and
                        std.mem.eql(u8, &stored.nonce, &q.nonce))
                    {
                        try now.before(stored.meta.deadline_ms);
                        break :blk .{ .open_snapshot = stored.meta };
                    }
                } else if (free == null) free = slot;
            }
            if (free == null or owned >= g.snapshots_per_principal) return error.StateViewCapacity;
            if (engine.snapshot_serial >= p.max_counter) return error.StateViewCapacity;
            const captured = try state.resource(engine, q.resource);
            const basis = engine.head.catalog;
            const after = try snapshotRecheck(engine, principal, q.resource);
            if (after.lower() > p.max_counter - g.snapshot_lifetime_ms) return error.UntrustedTime;
            engine.snapshot_serial += 1;
            const meta: g.Snapshot = .{ .id = .{ .epoch = engine.snapshot_epoch.?, .serial = engine.snapshot_serial }, .resource = captured, .deadline_ms = try std.math.add(u64, after.lower(), g.view_lifetime_ms), .hard_deadline_ms = try std.math.add(u64, after.lower(), g.snapshot_lifetime_ms) };
            try after.before(meta.deadline_ms);
            free.?.* = .{ .meta = meta, .snapshot = basis, .principal = query.principal, .principal_epoch = principal.epoch, .nonce = q.nonce };
            break :blk .{ .open_snapshot = meta };
        },
        .snapshot_entries => |q| blk: {
            const now = try snapshotTime(engine);
            const slot = (try snapshotSlot(engine, q.id, principal, now)) orelse return error.QueryExpired;
            const stored = slot.*.?;
            try snapshotAccess(engine, principal, stored.meta.resource.id, now);
            var basis = try @TypeOf(current).open(engine.page_store, stored.snapshot);
            const result = try entries(&basis, stored.meta.resource.id, q.key, q.after);
            const after = try snapshotRecheck(engine, principal, stored.meta.resource.id);
            try after.before(stored.meta.deadline_ms);
            slot.*.?.meta.deadline_ms = @min(stored.meta.hard_deadline_ms, try std.math.add(u64, after.lower(), g.view_lifetime_ms));
            break :blk .{ .snapshot_entries = .{ .snapshot = slot.*.?.meta, .page = result } };
        },
        .close_snapshot => |id| blk: {
            const now = try snapshotTime(engine);
            if (try snapshotSlot(engine, id, principal, now)) |slot| slot.* = null;
            break :blk .{ .close_snapshot = id };
        },
        .process => |pid| blk: {
            try scope(principal, pid);
            const process = try engine.process(pid);
            var input: ?g.Input = null;
            if (g.processReady(process)) {
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
        .read_access => |id| blk: {
            try resourceScope(engine, principal, id);
            try state.allowed(engine, id, query.principal, p.State.permission(.inspect) | p.State.permission(.read));
            const resource = try state.resource(engine, id);
            try state.usable(engine, resource, try sample(engine));
            break :blk .{ .read_access = resource };
        },
        .read_entries => |q| blk: {
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
                if (checked.meta.resource != q.resource) return error.InvalidStateView;
                basis = try @TypeOf(current).open(engine.page_store, checked.snapshot);
                resource = (try basis.get(g.Resource, address(.resource, q.resource))) orelse return error.InvalidHistory;
                if (resource.revision != checked.meta.revision) return error.InvalidHistory;
                captured = checked.meta;
            } else {
                try resourceScope(engine, principal, q.resource);
                try state.allowed(engine, q.resource, query.principal, p.State.permission(.inspect) | p.State.permission(.read));
                resource = try state.resource(engine, q.resource);
                try state.usable(engine, resource, now);
            }
            if (q.revision) |revision| if (resource.revision != revision) return error.StaleStateResource;
            var addresses: [g.page_size]core.pages.Key = undefined;
            var count: usize = 0;
            for (q.keys, 0..) |slot, i| if (slot) |key| {
                addresses[i] = try c.key(.entry, resource.id, 0, key.slice());
                count += 1;
            };
            const result = try basis.getMany(g.Entry, addresses[0..count]);
            for (q.keys, 0..) |slot, i| if (slot) |key| {
                if (result[i]) |entry| if (!entry.key.eql(key)) return error.InvalidHistory;
            };
            if (captured) |view| _ = try state.captured(engine, query.principal, try engine.process(view.pid), view.id, view.input, try sample(engine)) else try state.usable(engine, resource, try sample(engine));
            break :blk .{ .read_entries = .{ .resource = resource, .view = captured, .entries = result } };
        },
        .block_entries => |q| blk: {
            const now = try sample(engine);
            var basis = current;
            var result: g.BlockRead.Result = .{ .resource = undefined, .entries = undefined };
            const resource_id: u64 = switch (q.source) {
                .resource => |value| captured: {
                    try resourceScope(engine, principal, value.id);
                    try state.allowed(engine, value.id, query.principal, p.State.permission(.inspect) | p.State.permission(.read));
                    const resource = try state.resource(engine, value.id);
                    try state.usable(engine, resource, now);
                    if (resource.revision != value.revision) return error.StaleStateResource;
                    break :captured value.id;
                },
                .view => |id| captured: {
                    const stored = try state.view(engine, id);
                    try scope(principal, stored.meta.pid);
                    const process = try engine.process(stored.meta.pid);
                    try engine.executable(process, now, true);
                    if (process.owner != query.principal) return error.StaleGeneration;
                    const checked = try state.captured(engine, query.principal, process, id, stored.meta.input, now);
                    basis = try @TypeOf(current).open(engine.page_store, checked.snapshot);
                    result.view = checked.meta;
                    break :captured checked.meta.resource;
                },
                .version => |value| captured: {
                    try scope(principal, value.id.pid);
                    const stored = try state.retained(engine, query.principal, value.id, value.generation, now);
                    basis = try @TypeOf(current).open(engine.page_store, stored.snapshot);
                    result.version = stored.meta;
                    break :captured stored.meta.resource;
                },
            };
            result.resource = (try basis.get(g.Resource, address(.resource, resource_id))) orelse return error.InvalidHistory;
            if (q.keys[0] != null) {
                result.entries = try blockEntries(engine, &basis, result.resource, q.keys);
            } else {
                const root = (try basis.get(c.Snapshot, address(.resource_blocks, resource_id))) orelse c.Snapshot{};
                if (root.records != result.resource.block_entries) return error.InvalidHistory;
                const index: core.blocks.Index(@TypeOf(engine.page_store.*)) = .{ .store = engine.page_store };
                const page = try index.scan(root, q.after);
                result.entries = page.entries;
                result.next = page.next;
            }
            const after = try sample(engine);
            switch (q.source) {
                .resource => try state.usable(engine, result.resource, after),
                .view => |id| _ = try state.captured(engine, query.principal, try engine.process(result.view.?.pid), id, result.view.?.input, after),
                .version => |value| _ = try state.retained(engine, query.principal, value.id, value.generation, after),
            }
            break :blk .{ .block_entries = result };
        },
        .view => |id| blk: {
            const value = try state.view(engine, id);
            try scope(principal, value.meta.pid);
            try state.allowed(engine, value.meta.resource, query.principal, p.State.permission(.inspect));
            break :blk .{ .view = value.meta };
        },
        .read_version => |id| blk: {
            try scope(principal, id.pid);
            const value = try state.readVersion(engine, id);
            try state.allowed(engine, value.meta.resource, query.principal, p.State.permission(.inspect));
            break :blk .{ .read_version = value.meta };
        },
        .version_entries => |q| blk: {
            try scope(principal, q.id.pid);
            const stored = try state.retained(engine, query.principal, q.id, q.generation, try sample(engine));
            var basis = try @TypeOf(current).open(engine.page_store, stored.snapshot);
            const resource = (try basis.get(g.Resource, address(.resource, stored.meta.resource))) orelse return error.InvalidHistory;
            if (resource.revision != stored.meta.revision) return error.InvalidHistory;
            const result = try entries(&basis, resource.id, q.key, q.after);
            _ = try state.retained(engine, query.principal, q.id, q.generation, try sample(engine));
            break :blk .{ .version_entries = .{ .version = stored.meta, .generation = q.generation, .resource = resource, .page = result } };
        },
        .read_versions => |q| blk: {
            try scope(principal, q.pid);
            _ = try engine.process(q.pid);
            try at(q.position, position);
            const batch = try current.scan(growth.StoredReadVersion, .{ .namespace = .read_version, .major = q.pid }, if (q.after) |id| try state.versionKey(id) else null);
            var result: g.Batch(g.ReadVersion, g.ReadVersionId) = .{};
            var count: usize = 0;
            for (batch.records) |slot| if (slot) |record| {
                if (!std.meta.eql(try state.versionId(record.key), record.value.meta.id)) return error.InvalidHistory;
                state.allowed(engine, record.value.meta.resource, query.principal, p.State.permission(.inspect)) catch |err| {
                    if (err == error.Forbidden) continue;
                    return err;
                };
                result.entries[count] = record.value.meta;
                count += 1;
            };
            if (batch.next) |key| result.next = try state.versionId(key);
            break :blk .{ .read_versions = result };
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
            const result = try entries(&basis, resource.id, q.key, q.after);
            // A slow materialization cannot authorize a fresh disclosure after
            // a known deadline. Transport arrival can still occur later.
            if (captured) |view| _ = try state.captured(engine, query.principal, try engine.process(view.pid), view.id, view.input, try sample(engine)) else try state.usable(engine, resource, try sample(engine));
            break :blk .{ .entries = .{ .view = captured, .resource = resource, .page = result } };
        },
        .processes => |q| blk: {
            try at(q.position, position);
            if (principal.grant.pid) |pid| {
                var result: g.Batch(g.Process, u64) = .{};
                if (q.after == null or q.after.? < pid) result.entries[0] = try engine.process(pid);
                break :blk .{ .processes = result };
            }
            const batch = try current.scan(g.Process, .{ .namespace = .process }, if (q.after) |id| address(.process, id) else null);
            var result: g.Batch(g.Process, u64) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                result.entries[i] = record.value;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[1..9], .big);
            break :blk .{ .processes = result };
        },
        .resources => |q| blk: {
            try at(q.position, position);
            const batch = try current.scan(g.Resource, .{ .namespace = .resource }, if (q.after) |id| address(.resource, id) else null);
            var result: g.Batch(g.Resource, u64) = .{};
            var count: usize = 0;
            for (batch.records) |slot| if (slot) |record| {
                resourceScope(engine, principal, record.value.id) catch |err| {
                    if (err == error.Forbidden) continue;
                    return err;
                };
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
    return .{ .realm = query.realm, .position = position, .definition = g.current_definition, .principal_sequence = principal.sequence, .body = body };
}

fn entries(basis: anytype, resource: u64, point: ?p.Value, continuation: ?p.Value) !g.Batch(g.Entry, p.Value) {
    var result: g.Batch(g.Entry, p.Value) = .{};
    if (point) |key| {
        result.entries[0] = try basis.get(g.Entry, try c.key(.entry, resource, 0, key.slice()));
        if (result.entries[0]) |entry| if (!entry.key.eql(key)) return error.InvalidHistory;
    } else {
        const after = if (continuation) |key| try c.key(.entry, resource, 0, key.slice()) else null;
        const batch = try basis.scan(g.Entry, .{ .namespace = .entry, .major = resource }, after);
        for (batch.records, 0..) |slot, i| if (slot) |record| {
            if (!std.mem.allEqual(u8, record.key.data[9..17], 0) or !std.mem.eql(u8, record.key.slice()[17..], record.value.key.slice())) return error.InvalidHistory;
            result.entries[i] = record.value;
        };
        if (batch.next) |cursor| result.next = try p.Value.init(cursor.slice()[17..]);
    }
    return result;
}

pub fn blockEntries(engine: anytype, basis: anytype, resource: g.Resource, keys: [g.page_size]?p.Value) ![g.page_size]?p.Blocks.Entry {
    const snapshot = (try basis.get(c.Snapshot, address(.resource_blocks, resource.id))) orelse c.Snapshot{};
    if (snapshot.records != resource.block_entries) return error.InvalidHistory;
    const Store = @TypeOf(engine.page_store.*);
    if (comptime !@hasDecl(Store, "loadBlock")) return error.UnsupportedBlockStorage;
    const index: core.blocks.Index(Store) = .{ .store = engine.page_store };
    return index.read(snapshot, keys, engine.block_output);
}

//! Automatic native/direct collection shares the local maintenance executor.
//! Fixed accepted cuts and current privilege own reclamation; source activity
//! only chooses when another pass is useful. Collection cannot trigger itself.
const core = @import("transit_core");
const backend = @import("transit_backend_local");
const catalog = @import("transit_catalog");
const Maintenance = @import("GrowingMaintenance.zig");
const Engine = backend.DataAuthority.Engine;
const g = core.protocol.Growth;
const Direct = backend.DataCollection.Collector(catalog.DirectStorageGraph);

const Class = enum {
    native,
    direct,
    fn next(self: Class) Class {
        return if (self == .native) .direct else .native;
    }
};
pub const Cursor = struct { next: Class = .native };

pub fn step(cursor: *Cursor, engine: *Engine, config: Maintenance.Config, key: core.Ed25519.KeyPair, request: *g.Request) !bool {
    for (0..2) |_| {
        const selected = cursor.next;
        cursor.next = selected.next();
        const progressed = switch (selected) {
            .native => try unit(.native, backend.StorageCollection, engine, config, key, request),
            .direct => try unit(.direct, Direct, engine, config, key, request),
        };
        if (progressed) return true;
    }
    return false;
}

fn activity(comptime selected: Class, owner: *backend.Backend) !u64 {
    const lock = if (selected == .native) &owner.native_inventory else &owner.data_inventory;
    try lock.lock(owner.io);
    defer lock.unlock(owner.io);
    const queue = if (selected == .native) &owner.allocations else &owner.data_allocations;
    return (try queue.current()).source_activity;
}

fn unit(comptime selected: Class, comptime Collector: type, engine: *Engine, config: Maintenance.Config, key: core.Ed25519.KeyPair, request: *g.Request) !bool {
    const owner = engine.journal.backend;
    var collection: Collector = .{ .backend = owner };
    const Plan = union(enum) { start: u64, time_fence };
    const plan: Plan = blk: {
        // A bounded mark, trim or deletion unit keeps its current maintenance
        // grant through I/O. Fences below use the normal native commit path.
        try owner.authority.lockShared(owner.io);
        defer owner.authority.unlockShared(owner.io);
        try engine.authorizeMaintenance(try g.sign(request.*, key));
        const saved = try collection.current();
        const clock = engine.clock orelse return false;
        const now = try clock.sample();
        if (saved) |state| {
            if (state.phase != .complete) {
                if (state.phase == .wait and now.lower() > state.grace_until_ms and engine.head.time_floor_ms <= state.grace_until_ms)
                    break :blk .time_fence;
                return collection.step(engine, now);
            }
            // Graph completion does not imply its FIFO prefix is physically
            // settled. Drain one bounded unit before admitting another pass.
            if (try collection.step(engine, now)) return true;
        }
        const source = try activity(selected, owner);
        const previous = if (saved) |state| state.source_activity else 0;
        if (source < previous) return error.InvalidStorageCollection;
        if ((saved == null or !saved.?.aborted) and source - previous < config.storage.collection_every_records) return false;
        break :blk .{ .start = source };
    };

    // This engine/page store belongs only to the maintenance task. Suppression
    // affects eligibility accounting, never inventory, epochs or publication.
    const tracked = engine.page_store.track_activity;
    engine.page_store.track_activity = false;
    defer engine.page_store.track_activity = tracked;
    request.command = .{ .storage_fence = {} };
    request.sequence = (try engine.principal(config.principal)).sequence + 1;
    const signed = try g.sign(request.*, key);
    const fence = try engine.submit(signed);
    if (plan == .start) {
        try owner.authority.lockShared(owner.io);
        defer owner.authority.unlockShared(owner.io);
        try engine.authorizeMaintenance(signed);
        try collection.startAtActivity(engine, fence, plan.start);
    }
    return true;
}

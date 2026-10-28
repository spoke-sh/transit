const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const backend = @import("transit_backend_local");
const catalog = @import("transit_catalog");
const Work = @import("LocalCollection.zig");
const Maintenance = @import("GrowingMaintenance.zig");
const g = core.protocol.Growth;
const Direct = backend.DataCollection.Collector(catalog.DirectStorageGraph);

const Fixture = struct {
    owner: backend.Backend = undefined,
    pages: backend.PageStore = undefined,
    journal: backend.Store = undefined,
    engine: backend.DataAuthority.Engine = undefined,
    now: u64 = 100,
    clock_failed: bool = false,

    fn key(seed: u8) !core.Ed25519.KeyPair {
        return core.Ed25519.KeyPair.generateDeterministic(@splat(seed));
    }
    fn clock(raw: *anyopaque) !core.Time.Sample {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        if (self.clock_failed) return error.FixtureClockUnavailable;
        return .{ .unix_ms = self.now };
    }
    fn open(self: *Fixture, directory: std.Io.Dir, fresh: bool) !void {
        self.owner = try backend.Backend.open(t.allocator, t.io, directory, "native", .{});
        self.pages = try backend.PageStore.init(&self.owner, 1);
        self.journal = .{ .backend = &self.owner };
        const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = (try key(17)).public_key.toBytes(), .max_clock_error_ms = 5 };
        self.engine = if (fresh)
            try backend.DataAuthority.Engine.bootstrap(&self.journal, &self.pages, genesis)
        else
            try backend.DataAuthority.Engine.open(&self.journal, &self.pages, genesis);
        self.engine.clock = .{ .context = self, .read = clock };
    }
    fn close(self: *Fixture) void {
        self.pages.deinit();
        self.owner.deinit();
    }
    fn root(self: *Fixture, command: g.Command) !void {
        _ = try self.engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try self.engine.principal(0)).sequence + 1, .command = command }, try key(17)));
    }
    fn step(self: *Fixture, cursor: *Work.Cursor, config: Maintenance.Config) !bool {
        var request: g.Request = .{ .realm = 42, .principal = config.principal, .sequence = (try self.engine.principal(config.principal)).sequence + 1, .command = .checkpoint };
        return Work.step(cursor, &self.engine, config, try key(23), &request);
    }
};

test "automatic local collection resumes both owners, rechecks privilege and clock, and reaches idle" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const grant: g.Grant = .{ .subject = 10, .public_key = (try Fixture.key(23)).public_key.toBytes(), .permissions = core.permission(.admin) | core.permission(.effect) | core.permission(.delivery) };
    try f.root(.{ .create_principal = grant });
    try f.pages.begin(f.engine.head.storage_epoch, false);
    const orphan = try f.pages.stageBlock(try core.protocol.Blocks.Spec.of("unpublished"), "unpublished");
    f.pages.discard();
    var native_key_buffer: [96]u8 = undefined;
    const native_key = try std.fmt.bufPrint(&native_key_buffer, "native/b/{x}", .{&orphan.location});
    const direct_key = "table-segments/unpublished.tseg";
    try f.owner.put(direct_key, "unpublished", false);
    var native: backend.StorageCollection = .{ .backend = &f.owner };
    var direct: Direct = .{ .backend = &f.owner };
    const config: Maintenance.Config = .{ .principal = 10, .seed_file = "unused-by-step", .storage = .{ .collection_every_records = 1 } };
    var cursor: Work.Cursor = .{};
    var restarted = false;
    var units: usize = 0;
    while (true) : (units += 1) {
        try t.expect(units < 4096);
        const worked = try f.step(&cursor, config);
        const n = try native.current();
        const d = try direct.current();
        if (n == null or d == null) continue;
        if (!restarted and n.?.phase == .wait and d.?.phase == .wait) {
            // The same saved targets survive loss of volatile scheduling state.
            // A revoked maintenance principal cannot advance either owner.
            const position = f.engine.head.position;
            // Both classes refuse clock failure before publishing a time fence
            // or deleting anything. A missing clock is likewise not permission
            // to treat the persisted grace interval as elapsed.
            f.clock_failed = true;
            for (0..2) |_| try t.expectError(error.FixtureClockUnavailable, f.step(&cursor, config));
            f.clock_failed = false;
            const trusted = f.engine.clock;
            f.engine.clock = null;
            try t.expect(!try f.step(&cursor, config));
            f.engine.clock = trusted;
            try t.expectEqual(position, f.engine.head.position);
            try t.expectEqualDeep(n.?, (try native.current()).?);
            try t.expectEqualDeep(d.?, (try direct.current()).?);
            try t.expect(try f.owner.objects.objectStore().head(native_key) != null);
            try t.expect(try f.owner.objects.objectStore().head(direct_key) != null);
            try f.root(.{ .revoke = 10 });
            try t.expectError(error.Forbidden, f.step(&cursor, config));
            try t.expectEqualDeep(n.?, (try native.current()).?);
            try t.expectEqualDeep(d.?, (try direct.current()).?);
            try f.root(.{ .grant = grant });
            f.close();
            try f.open(tmp.dir, false);
            cursor = .{};
            try t.expectEqualDeep(n.?, (try native.current()).?);
            try t.expectEqualDeep(d.?, (try direct.current()).?);
            restarted = true;
        }
        if (restarted) {
            if (n.?.phase == .wait) f.now = @max(f.now, n.?.grace_until_ms + 1);
            if (d.?.phase == .wait) f.now = @max(f.now, d.?.grace_until_ms + 1);
        }
        if (restarted and !worked and n.?.phase == .complete and d.?.phase == .complete) break;
    }
    try t.expect(restarted);
    try t.expect(try f.owner.objects.objectStore().head(native_key) == null);
    try t.expect(try f.owner.objects.objectStore().head(direct_key) == null);
    const settled_native = (try native.current()).?;
    const settled_direct = (try direct.current()).?;
    try t.expectEqual((try f.owner.allocations.current()).source_activity, settled_native.source_activity);
    try t.expectEqual((try f.owner.data_allocations.current()).source_activity, settled_direct.source_activity);
    const position = f.engine.head.position;
    for (0..8) |_| try t.expect(!try f.step(&cursor, config));
    try t.expectEqual(position, f.engine.head.position);
    try t.expectEqualDeep(settled_native, (try native.current()).?);
    try t.expectEqualDeep(settled_direct, (try direct.current()).?);
    std.debug.print("Automatic local collection: {d} units, both owners idle after restart and revocation.\n", .{units + 1});
}

//! Public v3 load fixture. Signing, reads and turns use the production client.
const std = @import("std");
const client = @import("transit_client");
const p = client.protocol;
const g = p.Growth;
const t = std.testing;
const realm = 46;
const senders = 48;
const base = 65536;
const Expected = struct { pid: u64, resource: u64, rows: usize, admitted: u64 = 0, digest: [32]u8 = @splat(0) };
const Admin = struct {
    wire: *client.Client,
    key: p.Ed25519.KeyPair,
    sequence: u64 = 0,
    fn query(self: *@This(), kind: @FieldType(g.Query, "kind")) !g.Response {
        return self.wire.query(.{ .realm = realm, .principal = 0, .kind = kind }, self.key);
    }
    fn submit(self: *@This(), command: g.Command) !u64 {
        const receipt = try self.wire.submit(try g.sign(.{ .realm = realm, .principal = 0, .sequence = self.sequence + 1, .command = command }, self.key));
        self.sequence += 1;
        return receipt.position;
    }
    fn turn(self: *@This(), io: std.Io, expected: Expected, mutations: [4]?g.Mutation) !void {
        const process = (try self.query(.{ .process = expected.pid })).body.process;
        const resource = (try self.query(.{ .resource = expected.resource })).body.resource;
        const view = try self.submit(.{ .open_view = .{ .pid = expected.pid, .generation = 2, .input = process.input.?.position, .expected_revision = process.process.revision, .resource = expected.resource, .revision = resource.revision, .deadline_ms = @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000 } });
        _ = try self.submit(.{ .turn = .{ .pid = expected.pid, .generation = 2, .input = process.input.?.position, .expected_revision = process.process.revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = mutations } });
    }
};
fn rowKey(index: usize) p.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, index, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(key.public_key.toBytes(), .{}, &out.interface);
        return out.interface.flush();
    }
    if (args.len != 7) return error.ExpectedUrlPhaseManifestRowsPayloadHotPercent;
    const rows = try std.fmt.parseInt(usize, args[4], 10);
    const payload = try std.fmt.parseInt(usize, args[5], 10);
    const hot = try std.fmt.parseInt(usize, args[6], 10);
    if (rows < 64 or rows > 4096 or rows % 4 != 0 or payload < 16 or payload > 256 or hot > 100) return error.InvalidLoad;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 15000;
    var admin: Admin = .{ .wire = &wire, .key = key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const setup = std.mem.eql(u8, args[2], "setup");
    var expected: Expected = if (setup) blk: {
        const pid = try admin.submit(.{ .spawn = .{} });
        const resource = try admin.submit(.{ .create_resource = .{ .writer = pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = p.State.all_permissions } });
        _ = try admin.submit(.{ .associate = .{ .pid = pid, .resource = resource, .name = try p.Value.init("state") } });
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
        const result: Expected = .{ .pid = pid, .resource = resource, .rows = rows };
        for (0..rows / 4) |batch| {
            _ = try admin.submit(.{ .send = .{ .pid = pid, .value = .{} } });
            var mutations: [4]?g.Mutation = @splat(null);
            for (&mutations, 0..) |*slot, i| slot.* = .{ .key = rowKey(batch * 4 + i), .value = p.Value.integer(-1) };
            try admin.turn(init.io, result, mutations);
        }
        for (0..senders + 1) |i| _ = try admin.submit(.{ .grant = .{ .subject = base + i, .public_key = key.public_key.toBytes(), .permissions = p.permission(.send), .pid = pid } });
        break :blk result;
    } else blk: {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(4096));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        try t.expectEqual(rows, parsed.value.rows);
        break :blk parsed.value;
    };
    if (setup) {
        var requests: [senders]g.SignedRequest = undefined;
        for (&requests, 0..) |*slot, i| {
            var bytes: [256]u8 = @splat(42);
            const index = if ((i * 37) % 100 < hot) 0 else i % rows;
            std.mem.writeInt(u64, bytes[0..8], index, .big);
            std.mem.writeInt(u64, bytes[8..16], i, .big);
            slot.* = try g.sign(.{ .realm = realm, .principal = base + i, .sequence = 1, .command = .{ .send = .{ .pid = expected.pid, .value = try p.Value.init(bytes[0..payload]) } } }, key);
        }
        const revoke = try g.sign(.{ .realm = realm, .principal = 0, .sequence = admin.sequence + 1, .command = .{ .revoke = base + senders } }, key);
        const denied = try g.sign(.{ .realm = realm, .principal = base + senders, .sequence = 1, .command = .{ .send = .{ .pid = expected.pid, .value = .{} } } }, key);
        try std.json.Stringify.value(.{ .requests = requests, .control = revoke, .denied = denied }, .{}, &out.interface);
    } else if (std.mem.eql(u8, args[2], "drain")) {
        // Fixture oracle is bounded by the declared dataset, never used by the
        // service or as the authority's recovery basis.
        const values = try init.gpa.alloc(i64, rows);
        defer init.gpa.free(values);
        @memset(values, -1);
        const before = (try admin.query(.{ .process = expected.pid })).body.process.process;
        try t.expectEqual(@as(u64, rows / 4 + senders), before.admitted);
        try t.expectEqual(@as(u64, rows / 4), before.consumed);
        var seen: [senders]bool = @splat(false);
        for (0..senders) |_| {
            const input = (try admin.query(.{ .process = expected.pid })).body.process.input.?;
            try t.expectEqual(payload, input.value.len);
            const index = std.mem.readInt(u64, input.value.data[0..8], .big);
            const id = std.mem.readInt(u64, input.value.data[8..16], .big);
            try t.expect(index < rows and id < senders and !seen[id]);
            try t.expectEqual(base + id, input.origin.external.principal);
            seen[id] = true;
            values[index] = @intCast(id);
            try admin.turn(init.io, expected, .{ .{ .key = rowKey(index), .value = p.Value.integer(@intCast(id)) }, null, null, null });
        }
        for (seen) |present| try t.expect(present);
        const resource = (try admin.query(.{ .resource = expected.resource })).body.resource;
        var after: ?p.Value = null;
        var count: usize = 0;
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        while (true) {
            const page = (try admin.query(.{ .entries = .{ .resource = expected.resource, .revision = resource.revision, .after = after } })).body.entries.page;
            for (page.entries) |slot| if (slot) |entry| {
                try t.expect(entry.key.eql(rowKey(count)));
                try t.expectEqual(values[count], try entry.value.asInteger());
                digest.update(entry.key.slice());
                digest.update(entry.value.slice());
                count += 1;
            };
            after = page.next;
            if (after == null) break;
        }
        try t.expectEqual(rows, count);
        expected.admitted = before.admitted;
        expected.digest = digest.finalResult();
        try std.json.Stringify.value(.{ .admitted = before.admitted, .consumed = before.admitted, .verified_rows = count }, .{}, &out.interface);
    } else if (std.mem.eql(u8, args[2], "recover")) {
        const process = (try admin.query(.{ .process = expected.pid })).body.process;
        try t.expectEqual(expected.admitted, process.process.admitted);
        try t.expectEqual(expected.admitted, process.process.consumed);
        try t.expectEqual(@as(u64, 0), process.process.cancelled);
        try t.expect(process.input == null);
        const resource = (try admin.query(.{ .resource = expected.resource })).body.resource;
        var after: ?p.Value = null;
        var count: usize = 0;
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        while (true) {
            const page = (try admin.query(.{ .entries = .{ .resource = expected.resource, .revision = resource.revision, .after = after } })).body.entries.page;
            for (page.entries) |slot| if (slot) |entry| {
                try t.expect(entry.key.eql(rowKey(count)));
                digest.update(entry.key.slice());
                digest.update(entry.value.slice());
                count += 1;
            };
            after = page.next;
            if (after == null) break;
        }
        try t.expectEqual(rows, count);
        try t.expectEqualSlices(u8, &expected.digest, &digest.finalResult());
        try std.json.Stringify.value(.{ .admitted = process.process.admitted, .consumed = process.process.consumed }, .{}, &out.interface);
    } else return error.UnknownPhase;
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
    try out.interface.flush();
}

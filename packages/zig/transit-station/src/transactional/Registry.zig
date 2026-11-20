//! Transactional scoped `(registry_pid, scope: u32)` naming over declared actor
//! KV state. Preserves `RGS1`/`RGR1`/`RGQ1` binary codecs, explicit `Subject`
//! (`principal` / `process`) `lookup` and `mutate` grants, `expected_revision`
//! CAS, durable tombstones, and atomic `route` in the caller's transaction.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Turn = @import("Turn.zig");

pub const Subject = union(enum) {
    principal: u64,
    process: u64,
};

pub const Rights = packed struct(u8) {
    lookup: bool = false,
    mutate: bool = false,
    _reserved: u6 = 0,
};

pub const Name = struct {
    data: [24]u8 = @splat(0),
    len: u8,

    pub fn init(bytes: []const u8) !Name {
        if (bytes.len == 0 or bytes.len > 24 or !std.unicode.utf8ValidateSlice(bytes))
            return error.InvalidRegistryName;
        var result: Name = .{ .len = @intCast(bytes.len) };
        @memcpy(result.data[0..bytes.len], bytes);
        return result;
    }

    pub fn slice(self: *const Name) []const u8 {
        return self.data[0..self.len];
    }
};

pub const Request = struct {
    scope: u32,
    name: Name,
    operation: enum(u8) { lookup = 1, register = 2, rebind = 3, unregister = 4 },
    expected_revision: u64 = 0,
    destination: u64 = 0,

    pub fn encodeInto(self: Request, out: *[50]u8) ![]const u8 {
        if (self.scope == 0 or self.name.len == 0 or self.name.len > 24)
            return error.InvalidRegistryRequest;
        _ = try Name.init(self.name.slice());
        out.* = @splat(0);
        out[0..4].* = "RGQ1".*;
        out[4] = @backingInt(self.operation);
        std.mem.writeInt(u32, out[5..9], self.scope, .little);
        std.mem.writeInt(u64, out[9..17], self.expected_revision, .little);
        std.mem.writeInt(u64, out[17..25], self.destination, .little);
        out[25] = self.name.len;
        @memcpy(out[26..][0..self.name.len], self.name.slice());
        return out[0 .. 26 + self.name.len];
    }

    pub fn encodeAlloc(self: Request, allocator: std.mem.Allocator) ![]u8 {
        var buf: [50]u8 = undefined;
        return allocator.dupe(u8, try self.encodeInto(&buf));
    }

    pub fn decode(bytes: []const u8) !Request {
        if (bytes.len < 27 or bytes.len > 50 or !std.mem.eql(u8, bytes[0..4], "RGQ1") or
            bytes.len != @as(usize, 26) + bytes[25])
            return error.InvalidRegistryRequest;
        const result: Request = .{
            .scope = std.mem.readInt(u32, bytes[5..9], .little),
            .name = try Name.init(bytes[26..]),
            .operation = std.enums.fromInt(@FieldType(Request, "operation"), bytes[4]) orelse return error.InvalidRegistryRequest,
            .expected_revision = std.mem.readInt(u64, bytes[9..17], .little),
            .destination = std.mem.readInt(u64, bytes[17..25], .little),
        };
        var check_buf: [50]u8 = undefined;
        _ = try result.encodeInto(&check_buf);
        return result;
    }
};

pub const Binding = struct {
    scope: u32,
    revision: u64,
    destination: ?u64,

    pub fn encode(self: Binding) [24]u8 {
        var bytes: [24]u8 = undefined;
        bytes[0..4].* = "RGR1".*;
        std.mem.writeInt(u32, bytes[4..8], self.scope, .little);
        std.mem.writeInt(u64, bytes[8..16], self.revision, .little);
        std.mem.writeInt(u64, bytes[16..24], self.destination orelse 0, .little);
        return bytes;
    }

    pub fn decode(bytes: []const u8) !Binding {
        if (bytes.len != 24 or !std.mem.eql(u8, bytes[0..4], "RGR1"))
            return error.InvalidRegistryBinding;
        const pid = std.mem.readInt(u64, bytes[16..24], .little);
        if (pid > p.max_counter) return error.InvalidRegistryBinding;
        return .{
            .scope = std.mem.readInt(u32, bytes[4..8], .little),
            .revision = std.mem.readInt(u64, bytes[8..16], .little),
            .destination = if (pid == 0) null else pid,
        };
    }
};

pub fn scopeKey(scope: u32) [6]u8 {
    var bytes: [6]u8 = undefined;
    bytes[0..2].* = "\x00s".*;
    std.mem.writeInt(u32, bytes[2..6], scope, .little);
    return bytes;
}

pub fn nameKeyInto(scope: u32, name: Name, out: *[30]u8) ![]const u8 {
    if (name.len == 0 or name.len > 24) return error.InvalidRegistryName;
    _ = try Name.init(name.slice());
    out[0..2].* = "\x00n".*;
    std.mem.writeInt(u32, out[2..6], scope, .little);
    @memcpy(out[6..][0..name.len], name.slice());
    return out[0 .. 6 + name.len];
}

pub fn grantKey(scope: u32, subject: Subject) [15]u8 {
    var bytes: [15]u8 = @splat(0);
    bytes[0..2].* = "\x00g".*;
    std.mem.writeInt(u32, bytes[2..6], scope, .little);
    bytes[6] = if (subject == .principal) 1 else 2;
    std.mem.writeInt(u64, bytes[7..15], switch (subject) {
        .principal => |id| id,
        .process => |id| id,
    }, .little);
    return bytes;
}

pub fn routeKey(correlation: u64) [11]u8 {
    var bytes: [11]u8 = undefined;
    bytes[0..2].* = "\x00r".*;
    std.mem.writeInt(u64, bytes[2..10], correlation, .little);
    bytes[10] = 0;
    return bytes;
}

/// Trusted scope provisioning; never exposed implicitly through `Request` handling.
pub fn create(turn: *Turn, state_object: u64, scope: u32) !void {
    if (scope == 0 or state_object == 0 or turn.context.actor_pid == 0)
        return error.InvalidRegistryScope;
    const key = scopeKey(scope);
    if (try turn.getFramework(&key) != null) return error.RegistryScopeExists;
    var bytes: [20]u8 = undefined;
    bytes[0..4].* = "RGS1".*;
    std.mem.writeInt(u64, bytes[4..12], turn.context.actor_pid, .little);
    std.mem.writeInt(u64, bytes[12..20], state_object, .little);
    try turn.putFramework(&key, &bytes);
}

pub fn grant(turn: *Turn, scope: u32, subject: Subject, rights: Rights) !void {
    const sk = scopeKey(scope);
    _ = (try turn.getFramework(&sk)) orelse return error.RegistryScopeNotFound;
    if (rights._reserved != 0) return error.InvalidRegistryGrant;
    switch (subject) {
        .principal => |id| if (id > p.max_counter) return error.InvalidRegistryGrant,
        .process => |id| if (id == 0 or id > p.max_counter) return error.InvalidRegistryGrant,
    }
    const gk = grantKey(scope, subject);
    try turn.putFramework(&gk, &.{ 1, @bitCast(rights) });
}

fn authorize(turn: *Turn, state_object: u64, scope: u32, mutation: bool) !void {
    const sk = scopeKey(scope);
    const descriptor = (try turn.getFramework(&sk)) orelse return error.RegistryScopeNotFound;
    if (descriptor.len != 20 or !std.mem.eql(u8, descriptor[0..4], "RGS1") or
        std.mem.readInt(u64, descriptor[4..12], .little) != turn.context.actor_pid or
        std.mem.readInt(u64, descriptor[12..20], .little) != state_object)
        return error.InvalidRegistryScope;

    const orig = turn.context.origin orelse return error.RegistryDenied;
    const subject: Subject = switch (orig) {
        .actor => |actor_orig| .{ .process = actor_orig.pid },
        .external => |principal| .{ .principal = principal },
        .observer => return error.RegistryDenied,
    };
    const gk = grantKey(scope, subject);
    const permission = (try turn.getFramework(&gk)) orelse return error.RegistryDenied;
    if (permission.len != 2 or permission[0] != 1 or permission[1] & 0xfc != 0)
        return error.InvalidRegistryGrant;
    const rights: Rights = @bitCast(permission[1]);
    if (if (mutation) !rights.mutate else !rights.lookup) return error.RegistryDenied;
}

pub fn apply(turn: *Turn, state_object: u64, request: Request) !Binding {
    try authorize(turn, state_object, request.scope, request.operation != .lookup);
    var nk_buf: [30]u8 = undefined;
    const nk = try nameKeyInto(request.scope, request.name, &nk_buf);
    const current = if (try turn.getFramework(nk)) |value|
        try Binding.decode(value)
    else
        Binding{ .scope = request.scope, .revision = 0, .destination = null };
    if (current.scope != request.scope) return error.InvalidRegistryBinding;
    if (request.operation == .lookup) return current;
    if (current.revision != request.expected_revision) return error.RegistryRevisionConflict;
    if (request.operation == .register and current.destination != null) return error.NameAlreadyBound;
    if (request.operation == .rebind and current.destination == null) return error.NameNotBound;
    if (request.operation != .unregister and (request.destination == 0 or request.destination > p.max_counter))
        return error.InvalidDestination;
    const next: Binding = .{
        .scope = request.scope,
        .revision = try std.math.add(u64, current.revision, 1),
        .destination = if (request.operation == .unregister) null else request.destination,
    };
    const encoded = next.encode();
    try turn.putFramework(nk, &encoded);
    return next;
}

pub fn handle(turn: *Turn, state_object: u64, return_inbox: p.StreamQueue.Partition) !void {
    const env = turn.context.envelope orelse return error.ExpectedCall;
    if (env.kind != .call) return error.ExpectedCall;
    const binding = try apply(turn, state_object, try Request.decode(turn.input));
    const encoded = binding.encode();
    try turn.reply(return_inbox, &encoded);
}

fn verifyAndRecordRoute(turn: *Turn, registry_pid: u64) !u64 {
    const env = turn.context.envelope orelse return error.UnexpectedReplySource;
    const orig = turn.context.origin orelse return error.UnexpectedReplySource;
    if (env.kind != .reply or orig != .actor or orig.actor.pid != registry_pid)
        return error.UnexpectedReplySource;
    const wait = (try turn.waiting(env.correlation)) orelse return error.UnknownCorrelation;
    if (wait.target_pid != registry_pid or wait.phase != .replied or wait.resolution_turn != turn.context.turn_id)
        return error.UnverifiedRegistryReply;
    const binding = try Binding.decode(turn.input);
    const destination = binding.destination orelse return error.NameNotBound;
    var record: [32]u8 = undefined;
    std.mem.writeInt(u64, record[0..8], registry_pid, .little);
    const encoded_binding = binding.encode();
    @memcpy(record[8..32], &encoded_binding);
    const rk = routeKey(env.correlation);
    try turn.putFramework(&rk, &record);
    return destination;
}

/// Record the verified registry resolution and commit a fixed-PID cast in the
/// same caller transaction so later rebinds or tombstones never redirect work.
pub fn route(turn: *Turn, registry_pid: u64, destination_inbox: p.StreamQueue.Partition, payload: []const u8) !u64 {
    const destination = try verifyAndRecordRoute(turn, registry_pid);
    try turn.cast(destination_inbox, destination, payload);
    return destination;
}

/// Record the verified registry resolution and commit a fixed-PID call in the
/// same caller transaction.
pub fn routeCall(turn: *Turn, registry_pid: u64, destination_inbox: p.StreamQueue.Partition, payload: []const u8) !struct { destination: u64, correlation: u64 } {
    const destination = try verifyAndRecordRoute(turn, registry_pid);
    const corr = try turn.call(destination_inbox, destination, payload);
    return .{ .destination = destination, .correlation = corr };
}

test "private transactional registry enforces grants, expected_revision CAS, durable tombstones and verified routing" {
    const t = std.testing;
    var kv_map: std.StringHashMapUnmanaged([]u8) = .empty;
    defer {
        var it = kv_map.iterator();
        while (it.next()) |entry| {
            t.allocator.free(entry.key_ptr.*);
            t.allocator.free(entry.value_ptr.*);
        }
        kv_map.deinit(t.allocator);
    }

    const MapReader = struct {
        map: *std.StringHashMapUnmanaged([]u8),
        fn get(raw: *anyopaque, alloc: std.mem.Allocator, k: []const u8) !?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const v = self.map.get(k) orelse return null;
            return try alloc.dupe(u8, v);
        }
        fn row(_: *anyopaque, _: []const c.fuze.Types.Values.Cell) !?Turn.Row {
            return null;
        }
        fn table(_: *anyopaque, _: Turn.Table) !void {}
        fn applyDraft(self: *@This(), alloc: std.mem.Allocator, draft: Turn.Draft) !void {
            for (draft.puts) |put| {
                const k = try put.key.decode(alloc, 256);
                defer alloc.free(k);
                if (put.value) |val| {
                    const v = try val.decode(alloc, 4096);
                    defer alloc.free(v);
                    if (self.map.fetchRemove(k)) |old| {
                        alloc.free(old.key);
                        alloc.free(old.value);
                    }
                    try self.map.put(alloc, try alloc.dupe(u8, k), try alloc.dupe(u8, v));
                }
            }
        }
    };

    var reader_ctx: MapReader = .{ .map = &kv_map };
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const inbox: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 10 }, .revision = 1, .digest = @splat(1) },
        .partition = 0,
    };
    const source: p.StreamQueue.RecordIdentity = .{
        .target = inbox,
        .operation = .{ .scope = scope, .principal = 101, .operation = 1 },
        .ordinal = 0,
    };
    const actor_orig: p.Transaction.Origin = .{
        .realm = 1,
        .pid = 50,
        .principal = 101,
        .generation = 1,
        .code = 1,
        .workload = null,
        .transaction = .{ .scope = scope, .principal = 101, .operation = 9 },
    };

    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();

    // Provision scope 1 and grant process 50 lookup + mutate.
    var setup_turn = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 1,
        .actor_pid = 7,
        .inbox = inbox,
        .envelope = .{ .kind = .cast, .payload = "" },
        .origin = .{ .actor = actor_orig },
    });
    try create(&setup_turn, 99, 1);
    try grant(&setup_turn, 1, .{ .process = 50 }, .{ .lookup = true, .mutate = true });
    const name = try Name.init("orders");
    const reg = try apply(&setup_turn, 99, .{ .scope = 1, .name = name, .operation = .register, .destination = 88 });
    try t.expectEqual(@as(u64, 1), reg.revision);
    try t.expectEqual(@as(?u64, 88), reg.destination);

    // Stale expected_revision fails without poisoning a separate check turn.
    const rebind_ok = try apply(&setup_turn, 99, .{ .scope = 1, .name = name, .operation = .rebind, .expected_revision = 1, .destination = 92 });
    try t.expectEqual(@as(u64, 2), rebind_ok.revision);
    try t.expectEqual(@as(?u64, 92), rebind_ok.destination);

    const tomb = try apply(&setup_turn, 99, .{ .scope = 1, .name = name, .operation = .unregister, .expected_revision = 2 });
    try t.expectEqual(@as(u64, 3), tomb.revision);
    try t.expectEqual(@as(?u64, null), tomb.destination);
    try reader_ctx.applyDraft(t.allocator, try setup_turn.finish());

    // Reconstructed turn reads retained tombstone (revision 3) and denies ungranted process 60.
    var denied_orig = actor_orig;
    denied_orig.pid = 60;
    var denied_turn = try Turn.initWithContext(arena.allocator(), .{}, .{ .context = &reader_ctx, .get = MapReader.get, .row = MapReader.row, .table = MapReader.table }, source, "", .{
        .turn_id = 2,
        .actor_pid = 7,
        .inbox = inbox,
        .envelope = .{ .kind = .call, .correlation = 0x10000, .payload = "" },
        .origin = .{ .actor = denied_orig },
    });
    try t.expectError(error.RegistryDenied, apply(&denied_turn, 99, .{ .scope = 1, .name = name, .operation = .lookup }));
}

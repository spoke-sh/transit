//! A registry scope is (authority PID, scope ID), with the authority resource's
//! lifetime. Binding revisions and tombstones are durable, not worker caches.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Frame = @import("Frame.zig");
pub const Subject = union(enum) { principal: u64, process: u64 };
pub const Rights = packed struct(u8) { lookup: bool = false, mutate: bool = false, _reserved: u6 = 0 };
pub const Name = struct {
    data: [24]u8 = @splat(0),
    len: u8,
    pub fn init(bytes: []const u8) !Name {
        if (bytes.len == 0 or bytes.len > 24 or !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidRegistryName;
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
    pub fn encode(self: Request) !p.Value {
        if (self.scope == 0 or self.name.len == 0 or self.name.len > 24) return error.InvalidRegistryRequest;
        _ = try Name.init(self.name.slice());
        var bytes: [50]u8 = @splat(0);
        bytes[0..4].* = "RGQ1".*;
        bytes[4] = @backingInt(self.operation);
        std.mem.writeInt(u32, bytes[5..9], self.scope, .little);
        std.mem.writeInt(u64, bytes[9..17], self.expected_revision, .little);
        std.mem.writeInt(u64, bytes[17..25], self.destination, .little);
        bytes[25] = self.name.len;
        @memcpy(bytes[26..][0..self.name.len], self.name.slice());
        return p.Value.init(bytes[0 .. 26 + self.name.len]);
    }
    pub fn decode(value: p.Value) !Request {
        try value.validate();
        if (value.len < 27 or !std.mem.eql(u8, value.data[0..4], "RGQ1") or value.len != @as(usize, 26) + value.data[25]) return error.InvalidRegistryRequest;
        const result: Request = .{ .scope = std.mem.readInt(u32, value.data[5..9], .little), .name = try Name.init(value.slice()[26..]), .operation = std.enums.fromInt(@FieldType(Request, "operation"), value.data[4]) orelse return error.InvalidRegistryRequest, .expected_revision = std.mem.readInt(u64, value.data[9..17], .little), .destination = std.mem.readInt(u64, value.data[17..25], .little) };
        _ = try result.encode();
        return result;
    }
};
pub const Binding = struct {
    scope: u32,
    revision: u64,
    destination: ?u64,
    pub fn encode(self: Binding) p.Value {
        var bytes: [24]u8 = undefined;
        bytes[0..4].* = "RGR1".*;
        std.mem.writeInt(u32, bytes[4..8], self.scope, .little);
        std.mem.writeInt(u64, bytes[8..16], self.revision, .little);
        std.mem.writeInt(u64, bytes[16..24], self.destination orelse 0, .little);
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Binding {
        try value.validate();
        if (value.len != 24 or !std.mem.eql(u8, value.data[0..4], "RGR1")) return error.InvalidRegistryBinding;
        const pid = std.mem.readInt(u64, value.data[16..24], .little);
        if (pid > p.max_counter) return error.InvalidRegistryBinding;
        return .{ .scope = std.mem.readInt(u32, value.data[4..8], .little), .revision = std.mem.readInt(u64, value.data[8..16], .little), .destination = if (pid == 0) null else pid };
    }
};
pub fn scopeKey(scope: u32) p.Value {
    var bytes: [6]u8 = undefined;
    bytes[0..2].* = "\x00s".*;
    std.mem.writeInt(u32, bytes[2..6], scope, .little);
    return p.Value.init(&bytes) catch unreachable;
}
fn nameKey(scope: u32, name: Name) !p.Value {
    if (name.len == 0 or name.len > 24) return error.InvalidRegistryName;
    _ = try Name.init(name.slice());
    var bytes: [30]u8 = undefined;
    bytes[0..2].* = "\x00n".*;
    std.mem.writeInt(u32, bytes[2..6], scope, .little);
    @memcpy(bytes[6..][0..name.len], name.slice());
    return p.Value.init(bytes[0 .. 6 + name.len]);
}
fn grantKey(scope: u32, subject: Subject) p.Value {
    var bytes: [15]u8 = @splat(0);
    bytes[0..2].* = "\x00g".*;
    std.mem.writeInt(u32, bytes[2..6], scope, .little);
    bytes[6] = if (subject == .principal) 1 else 2;
    std.mem.writeInt(u64, bytes[7..15], switch (subject) {
        .principal => |id| id,
        .process => |id| id,
    }, .little);
    return p.Value.init(&bytes) catch unreachable;
}
/// Provisioning is a trusted local operation; registry request handling never
/// exposes create/grant implicitly to an authenticated but unprivileged caller.
pub fn create(turn: anytype, scope: u32) !void {
    if (scope == 0) return error.InvalidRegistryScope;
    if (try turn.read(scopeKey(scope)) != null) return error.RegistryScopeExists;
    var bytes: [20]u8 = undefined;
    bytes[0..4].* = "RGS1".*;
    std.mem.writeInt(u64, bytes[4..12], turn.delivery.pid, .little);
    std.mem.writeInt(u64, bytes[12..20], turn.view.resource, .little);
    try turn.write(scopeKey(scope), try p.Value.init(&bytes));
}
pub fn grant(turn: anytype, scope: u32, subject: Subject, rights: Rights) !void {
    _ = (try turn.read(scopeKey(scope))) orelse return error.RegistryScopeNotFound;
    if (rights._reserved != 0) return error.InvalidRegistryGrant;
    switch (subject) {
        .principal => |id| if (id > p.max_counter) return error.InvalidRegistryGrant,
        .process => |id| if (id == 0 or id > p.max_counter) return error.InvalidRegistryGrant,
    }
    try turn.write(grantKey(scope, subject), try p.Value.init(&.{ 1, @bitCast(rights) }));
}
fn authorize(turn: anytype, scope: u32, mutation: bool) !void {
    const descriptor = (try turn.read(scopeKey(scope))) orelse return error.RegistryScopeNotFound;
    if (descriptor.len != 20 or !std.mem.eql(u8, descriptor.data[0..4], "RGS1") or std.mem.readInt(u64, descriptor.data[4..12], .little) != turn.delivery.pid or std.mem.readInt(u64, descriptor.data[12..20], .little) != turn.view.resource) return error.InvalidRegistryScope;
    const source = if (@hasField(@TypeOf(turn.delivery.input.origin), "source")) turn.delivery.input.origin.source else turn.delivery.input.origin;
    const subject: Subject = switch (source) {
        .external => |origin| .{ .principal = origin.principal },
        .process => |origin| .{ .process = origin.pid },
        else => return error.RegistryDenied,
    };
    const permission = (try turn.read(grantKey(scope, subject))) orelse return error.RegistryDenied;
    if (permission.len != 2 or permission.data[0] != 1 or permission.data[1] & 0xfc != 0) return error.InvalidRegistryGrant;
    const rights: Rights = @bitCast(permission.data[1]);
    if (if (mutation) !rights.mutate else !rights.lookup) return error.RegistryDenied;
}
pub fn apply(turn: anytype, request: Request) !Binding {
    try authorize(turn, request.scope, request.operation != .lookup);
    const key = try nameKey(request.scope, request.name);
    const current = if (try turn.read(key)) |value| try Binding.decode(value) else Binding{ .scope = request.scope, .revision = 0, .destination = null };
    if (current.scope != request.scope) return error.InvalidRegistryBinding;
    if (request.operation == .lookup) return current;
    if (current.revision != request.expected_revision) return error.RegistryRevisionConflict;
    if (request.operation == .register and current.destination != null) return error.NameAlreadyBound;
    if (request.operation == .rebind and current.destination == null) return error.NameNotBound;
    if (request.operation != .unregister and (request.destination == 0 or request.destination > p.max_counter)) return error.InvalidDestination;
    const next: Binding = .{ .scope = request.scope, .revision = try std.math.add(u64, current.revision, 1), .destination = if (request.operation == .unregister) null else request.destination };
    try turn.write(key, next.encode());
    return next;
}
pub fn handle(turn: anytype, frame: Frame) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (frame.kind != .call) return error.ExpectedCall;
    const binding = try apply(turn, try Request.decode(frame.payload));
    try turn.reply(binding.encode());
}
/// Record the resolution and send to its fixed PID in the same private turn.
/// A retry never consults a later binding. Requires the GenServer's verified reply.
pub fn route(turn: anytype, registry_pid: u64, frame: Frame, payload: p.Value) !u64 {
    if (frame.kind != .reply or try Frame.source(turn.delivery.input) != registry_pid) return error.UnexpectedReplySource;
    const waiting = (try turn.waiting(frame.correlation)) orelse return error.UnknownCorrelation;
    if (waiting.target != registry_pid or waiting.phase != .replied or waiting.resolution_input != turn.delivery.input.position) return error.UnverifiedRegistryReply;
    const binding = try Binding.decode(frame.payload);
    const destination = binding.destination orelse return error.NameNotBound;
    const before = turn.decision;
    errdefer turn.decision = before;
    var bytes: [32]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], registry_pid, .little);
    @memcpy(bytes[8..32], binding.encode().slice());
    try turn.write(@import("QueryPolicy.zig").key('r', frame.correlation, 0), try p.Value.init(&bytes));
    try turn.cast(destination, payload);
    return destination;
}

test "scoped grants, conditional rebind and retained tombstones survive a reconstructed worker" {
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    try create(&turn, 1);
    try grant(&turn, 1, .{ .principal = 0 }, .{ .lookup = true, .mutate = true });
    const name = try Name.init("ledger");
    const registered = try apply(&turn, .{ .scope = 1, .name = name, .operation = .register, .destination = 8 });
    try std.testing.expectEqual(@as(u64, 1), registered.revision);
    try std.testing.expectError(error.RegistryRevisionConflict, apply(&turn, .{ .scope = 1, .name = name, .operation = .rebind, .destination = 9 }));
    const changed = try apply(&turn, .{ .scope = 1, .name = name, .operation = .rebind, .destination = 9, .expected_revision = 1 });
    try std.testing.expectEqual(@as(?u64, 9), changed.destination);
    try std.testing.expectError(error.RegistryRevisionConflict, apply(&turn, .{ .scope = 1, .name = name, .operation = .unregister, .expected_revision = 1 }));
    _ = try apply(&turn, .{ .scope = 1, .name = name, .operation = .unregister, .expected_revision = 2 });
    var recovered_store: @import("TestStore.zig") = .{};
    var recovered = try recovered_store.turn(.{});
    for (turn.decision.mutations, 0..) |slot, i| if (slot) |mutation| {
        recovered_store.entries[i] = .{ .key = mutation.key, .value = mutation.value.?, .revision = 3 };
    };
    const absent = try apply(&recovered, .{ .scope = 1, .name = name, .operation = .lookup });
    try std.testing.expect(absent.destination == null and absent.revision == 3);
    recovered.delivery.input.origin = .{ .process = .{ .pid = 8, .turn = 5, .output = 0 } };
    try std.testing.expectError(error.RegistryDenied, apply(&recovered, .{ .scope = 1, .name = name, .operation = .lookup }));
}

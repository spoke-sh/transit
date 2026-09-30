//! Explicit empty-Table mutation composition. Initialization and policy changes
//! require the configured native principal; no file or query policy grants writes.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.TableMutationRecords;
const a = q.TableMutationAdmission;
const Self = @This();
configuration: Configuration,
pub const Configuration = struct {
    resource: u64,
    initializer: u64,
    principal: u64,
    table: u32 = 1,
    key_name: []const u8 = "id",
    value_name: []const u8 = "value",
    value_type: q.fuze.model.Type = .int64,
    permissions: u8,
    pub fn target(self: Configuration) !s.Table {
        if (self.resource == 0 or self.resource > p.max_counter or self.initializer > p.max_counter or self.principal == 0 or self.principal > p.max_counter or self.table == 0 or self.permissions & ~@as(u8, 7) != 0) return error.InvalidMutationConfiguration;
        const table: s.Table = .{ .resource = self.resource, .id = self.table, .schema = .{ .names = .{ try .init(self.key_name), try .init(self.value_name) }, .value_type = self.value_type } };
        try table.schema.validate();
        return table;
    }
    pub fn encode(self: Configuration) !p.Value {
        const table = try self.target();
        const schema = try s.Table.encodeSchema(table.schema);
        var buffer: [73]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("TMW1");
        inline for (.{ "resource", "initializer", "principal" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeInt(u32, self.table, .little);
        try writer.writeByte(@intCast(schema.len));
        try writer.writeAll(schema.slice());
        try writer.writeByte(self.permissions);
        return p.Value.init(writer.buffered());
    }
    pub fn initializeCommand(self: Configuration) !p.Value {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.mutation.writer.v1\x00");
        hash.update((try self.encode()).slice());
        var buffer: [44]u8 = undefined;
        buffer[0..4].* = "TMI1".*;
        std.mem.writeInt(u64, buffer[4..12], self.resource, .little);
        buffer[12..44].* = hash.finalResult();
        return p.Value.init(&buffer);
    }
};
pub const PolicyChange = struct {
    resource: u64,
    expected_revision: u64,
    policy: r.Policy,
    pub fn encode(self: PolicyChange) !p.Value {
        if (self.resource == 0 or self.resource > p.max_counter or self.expected_revision > p.max_counter) return error.InvalidMutationCommand;
        var buffer: [77]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("TMG1");
        try writer.writeInt(u64, self.resource, .little);
        try writer.writeInt(u64, self.expected_revision, .little);
        try writer.writeAll((try self.policy.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !PolicyChange {
        try value.validate();
        if (value.len != 77 or !std.mem.eql(u8, value.data[0..4], "TMG1")) return error.InvalidMutationCommand;
        const result: PolicyChange = .{ .resource = std.mem.readInt(u64, value.data[4..12], .little), .expected_revision = std.mem.readInt(u64, value.data[12..20], .little), .policy = try r.Policy.decode(try p.Value.init(value.slice()[20..])) };
        _ = try result.encode();
        return result;
    }
};
pub const Rejection = enum(u8) {
    invalid_command = 1,
    denied = 2,
    identity_conflict = 3,
    busy = 4,
    not_found = 5,
    not_active = 6,
    upload_closed = 7,
    not_sealed = 8,
    invalid_part = 9,
    incomplete_upload = 10,
    source_changed = 11,
    stale_policy = 12,
};
/// A disposition for an admitted input, separate from the request's terminal
/// result. It cannot replace that result or fabricate an affected-row count.
pub const Disposition = struct {
    principal: u64,
    input: u64,
    payload: [32]u8,
    reason: Rejection,
    pub fn fingerprint(value: p.Value) ![32]u8 {
        try value.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.mutation.input.v1\x00");
        hash.update(value.slice());
        return hash.finalResult();
    }
    pub fn encode(self: Disposition) !p.Value {
        if (self.principal > p.max_counter or self.input == 0 or self.input > p.max_counter) return error.InvalidMutationDisposition;
        var buffer: [53]u8 = undefined;
        buffer[0..4].* = "TME1".*;
        std.mem.writeInt(u64, buffer[4..12], self.principal, .little);
        std.mem.writeInt(u64, buffer[12..20], self.input, .little);
        buffer[20..52].* = self.payload;
        buffer[52] = @backingInt(self.reason);
        return p.Value.init(&buffer);
    }
    pub fn decode(value: p.Value) !Disposition {
        try value.validate();
        if (value.len != 53 or !std.mem.eql(u8, value.data[0..4], "TME1")) return error.InvalidMutationDisposition;
        const result: Disposition = .{ .principal = std.mem.readInt(u64, value.data[4..12], .little), .input = std.mem.readInt(u64, value.data[12..20], .little), .payload = value.data[20..52].*, .reason = std.enums.fromInt(Rejection, value.data[52]) orelse return error.InvalidMutationDisposition };
        _ = try result.encode();
        return result;
    }
};
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn external(turn: *s.Turn, principal: u64) bool {
    return turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == principal;
}
fn reject(turn: *s.Turn, reason: Rejection) !bool {
    const disposition: Disposition = .{ .principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0, .input = turn.delivery.input.position, .payload = try Disposition.fingerprint(turn.delivery.input.value), .reason = reason };
    try turn.write(r.key('e', disposition.input, 0), try disposition.encode());
    return true;
}
fn check(self: *Self, turn: *s.Turn) !bool {
    if (turn.view.resource != self.configuration.resource) return error.MutationWriterConfigurationChanged;
    const value = (try turn.read(r.key('w', 0, 0))) orelse return false;
    if (!value.eql(try self.configuration.encode())) return error.MutationWriterConfigurationChanged;
    return true;
}
fn initializer(self: *Self, turn: *s.Turn, frame: s.Frame) !bool {
    return frame.kind == .cast and external(turn, self.configuration.initializer) and frame.payload.eql(try self.configuration.initializeCommand());
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (!try self.initializer(turn, try s.Frame.decode(turn.delivery.input.value))) return error.UninitializedMutationWriter;
    const before = turn.decision;
    errdefer turn.decision = before;
    const target = try self.declare(turn);
    try a.setPolicy(turn, 0, .{ .principal = self.configuration.principal, .table = target.id, .revision = 1, .declaration = try r.declaration(target), .permissions = self.configuration.permissions });
}
/// Two-write declaration for an explicitly authorized composition. The caller
/// owns initialization admission and must install policy before exposing writes.
/// The standalone writer adds its policy in the same initialization turn.
pub fn declare(self: *Self, turn: *s.Turn) !s.Table {
    if (try self.check(turn)) return error.MutationWriterAlreadyInitialized;
    const before = turn.decision;
    errdefer turn.decision = before;
    const target = try self.configuration.target();
    _ = try s.Table.create(turn, target.id, target.schema);
    try turn.write(r.key('w', 0, 0), try self.configuration.encode());
    return target;
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const initialized = try self.check(turn);
    const frame = s.Frame.decode(turn.delivery.input.value) catch return if (initialized) reject(turn, .invalid_command) else error.UninitializedMutationWriter;
    if (!initialized) {
        if (!try self.initializer(turn, frame)) return error.UninitializedMutationWriter;
        return false;
    }
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return reject(turn, .invalid_command);
    if (try self.initializer(turn, frame)) return false;
    if (std.mem.startsWith(u8, frame.payload.slice(), "TMG1")) {
        if (!external(turn, self.configuration.initializer)) return reject(turn, .denied);
        _ = PolicyChange.decode(frame.payload) catch return reject(turn, .invalid_command);
    } else _ = r.Command.decode(&frame.payload) catch return reject(turn, .invalid_command);
    return false;
}
fn classify(err: anyerror) ?Rejection {
    return switch (err) {
        error.InvalidMutationCommand => .invalid_command,
        error.MutationDenied, error.MutationPrincipalMismatch => .denied,
        error.MutationIdentityConflict, error.MutationNamespaceInUse => .identity_conflict,
        error.MutationBusy => .busy,
        error.MutationNotFound => .not_found,
        error.MutationNotActive => .not_active,
        error.MutationUploadClosed => .upload_closed,
        error.MutationNotSealed => .not_sealed,
        error.InvalidPublicationPart, error.InvalidPublicationOrdinal, error.PublicationGap, error.PublicationPartConflict => .invalid_part,
        error.IncompletePublication => .incomplete_upload,
        error.MutationSourceChanged => .source_changed,
        error.StaleMutationPolicy => .stale_policy,
        else => null,
    };
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (!try self.check(turn)) return error.UninitializedMutationWriter;
    if (try self.initializer(turn, frame)) return;
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return error.ExpectedExternalOrigin;
    const before = turn.decision;
    apply(self, turn, frame) catch |err| {
        turn.decision = before;
        if (turn.read_error != null) return err;
        const rejected = classify(err) orelse return err;
        _ = try reject(turn, rejected);
    };
}
fn apply(self: *Self, turn: *s.Turn, frame: s.Frame) !void {
    if (std.mem.startsWith(u8, frame.payload.slice(), "TMG1")) {
        if (!external(turn, self.configuration.initializer)) return error.MutationDenied;
        const change = try PolicyChange.decode(frame.payload);
        if (change.resource != self.configuration.resource or change.policy.table != self.configuration.table) return error.MutationIdentityConflict;
        try a.setPolicy(turn, change.expected_revision, change.policy);
    } else _ = try a.dispatch(turn);
}

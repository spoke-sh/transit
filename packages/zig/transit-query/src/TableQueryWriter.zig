//! One Table owner with separate query and mutation admission. Initialization
//! spans two atomic turns; neither path runs before the durable ready phase.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.TableMutationRecords;
const Writer = q.TableMutationWriter;
const Self = @This();
configuration: Configuration,
source: *q.UnifiedBehavior.Source,
pub const Phase = enum(u8) { staged = 1, ready = 2 };
pub const state_key = r.key('q', 0, 0);
pub const Configuration = struct {
    writer: Writer.Configuration,
    peer: u64,
    requests: u64,
    allow: bool,
    limits: q.Bundle.Limits,
    pub fn definition(self: Configuration) !q.SourceDefinition {
        const table = try self.writer.target();
        try q.UnifiedRecords.identity(self.writer.initializer);
        try q.UnifiedRecords.identity(self.peer);
        try q.UnifiedRecords.identity(self.requests);
        try self.limits.validate();
        return .{ .resource = table.resource, .source = .{ .table = .{ .id = table.id, .schema = table.schema } } };
    }
    pub fn encode(self: Configuration) !p.Value {
        _ = try self.definition();
        const writer = try self.writer.encode();
        var buffer: [119]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        try out.writeAll("TQC1");
        try out.writeByte(@intCast(writer.len));
        try out.writeAll(writer.slice());
        try out.writeInt(u64, self.peer, .little);
        try out.writeInt(u64, self.requests, .little);
        try out.writeByte(@intFromBool(self.allow));
        inline for (.{ "pages", "segments", "result_bytes" }) |field| try out.writeInt(u64, @field(self.limits, field), .little);
        return p.Value.init(out.buffered());
    }
    pub fn initializeCommand(self: Configuration) !p.Value {
        return self.command("TQI1");
    }
    pub fn continuation(self: Configuration) !p.Value {
        return self.command("TQR1");
    }
    fn command(self: Configuration, magic: *const [4]u8) !p.Value {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.query.writer.v1\x00");
        hash.update((try self.encode()).slice());
        var bytes: [44]u8 = undefined;
        bytes[0..4].* = magic.*;
        std.mem.writeInt(u64, bytes[4..12], self.writer.resource, .little);
        bytes[12..44].* = hash.finalResult();
        return p.Value.init(&bytes);
    }
    pub fn state(self: Configuration, current: Phase) !p.Value {
        const config = try self.encode();
        var bytes: [124]u8 = undefined;
        bytes[0..4].* = "TQW1".*;
        bytes[4] = @backingInt(current);
        @memcpy(bytes[5..][0..config.len], config.slice());
        return p.Value.init(bytes[0 .. 5 + config.len]);
    }
};
pub const QueryPolicyChange = struct {
    resource: u64,
    expected_revision: u64,
    policy: q.UnifiedRecords.Policy,
    pub fn encode(self: QueryPolicyChange) !p.Value {
        try q.UnifiedRecords.identity(self.resource);
        if (self.expected_revision > p.max_counter) return error.InvalidQueryPolicyChange;
        var bytes: [105]u8 = undefined;
        bytes[0..4].* = "TQG1".*;
        std.mem.writeInt(u64, bytes[4..12], self.resource, .little);
        std.mem.writeInt(u64, bytes[12..20], self.expected_revision, .little);
        bytes[20..105].* = (try self.policy.encode()).data[0..85].*;
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !QueryPolicyChange {
        try value.validate();
        if (value.len != 105 or !std.mem.eql(u8, value.data[0..4], "TQG1")) return error.InvalidQueryPolicyChange;
        const result: QueryPolicyChange = .{ .resource = std.mem.readInt(u64, value.data[4..12], .little), .expected_revision = std.mem.readInt(u64, value.data[12..20], .little), .policy = try q.UnifiedRecords.Policy.decode(try p.Value.init(value.slice()[20..])) };
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
pub fn phase(self: *Self, reader: anytype) !?Phase {
    if (reader.view.resource != self.configuration.writer.resource or self.source.peer != self.configuration.peer or self.source.initializer != self.configuration.writer.initializer) return error.TableQueryWriterConfigurationChanged;
    const config = try self.configuration.encode();
    const value = (try reader.read(state_key)) orelse return null;
    if (value.len != config.len + 5 or !std.mem.eql(u8, value.data[0..4], "TQW1")) return error.InvalidTableQueryWriterState;
    const result = std.enums.fromInt(Phase, value.data[4]) orelse return error.InvalidTableQueryWriterState;
    if (!std.mem.eql(u8, value.slice()[5..], config.slice())) return error.TableQueryWriterConfigurationChanged;
    const stored_writer = (try reader.read(r.key('w', 0, 0))) orelse return error.InvalidTableQueryWriterState;
    if (!stored_writer.eql(try self.configuration.writer.encode())) return error.TableQueryWriterConfigurationChanged;
    return result;
}
fn external(turn: *s.Turn, principal: u64) bool {
    return turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == principal;
}
fn initializer(self: *Self, turn: *s.Turn, frame: s.Frame) !bool {
    return frame.kind == .cast and external(turn, self.configuration.writer.initializer) and frame.payload.eql(try self.configuration.initializeCommand());
}
fn continuation(self: *Self, turn: *s.Turn, frame: s.Frame) !bool {
    return frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid and frame.payload.eql(try self.configuration.continuation());
}
fn emptyPolicies(self: *Self, turn: *s.Turn) !void {
    if (try turn.read(q.UnifiedRecords.key('v', 0, 0)) != null or try q.UnifiedCapture.policy(turn, self.configuration.peer) != null or try q.TableMutationAdmission.policy(turn, self.configuration.writer.principal, self.configuration.writer.table) != null) return error.TableQueryWriterAlreadyInitialized;
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (!try self.initializer(turn, try s.Frame.decode(turn.delivery.input.value))) return error.UninitializedTableQueryWriter;
    if (try self.phase(turn) != null) return error.TableQueryWriterAlreadyInitialized;
    try self.emptyPolicies(turn);
    const before = turn.decision;
    errdefer turn.decision = before;
    var writer: Writer = .{ .configuration = self.configuration.writer };
    _ = try writer.declare(turn);
    try turn.write(state_key, try self.configuration.state(.staged));
    try turn.cast(turn.delivery.pid, try self.configuration.continuation());
}
fn activate(self: *Self, turn: *s.Turn) !void {
    try self.emptyPolicies(turn);
    const definition = try self.configuration.definition();
    try q.UnifiedSource.checkCurrent(definition, turn);
    const before = turn.decision;
    errdefer turn.decision = before;
    try q.TableMutationAdmission.setPolicy(turn, 0, .{ .principal = self.configuration.writer.principal, .table = self.configuration.writer.table, .revision = 1, .declaration = try q.Bundle.declaration(definition), .permissions = self.configuration.writer.permissions });
    try q.UnifiedCapture.setPolicy(turn, .{ .peer = self.configuration.peer, .requests = self.configuration.requests, .revision = 1, .declaration = try q.Bundle.declaration(definition), .allow = self.configuration.allow, .limits = self.configuration.limits });
    const source = self.source.interface();
    try source.initialize.?(source.context, turn);
    try turn.write(state_key, try self.configuration.state(.ready));
}
fn rejectMutation(turn: *s.Turn, reason: Writer.Rejection) !bool {
    const result: Writer.Disposition = .{ .principal = turn.delivery.input.origin.external.principal, .input = turn.delivery.input.position, .payload = try Writer.Disposition.fingerprint(turn.delivery.input.value), .reason = reason };
    try turn.write(r.key('e', result.input, 0), try result.encode());
    return true;
}
fn rejectQuery(turn: *s.Turn, frame: ?s.Frame, reason: []const u8) !bool {
    if (frame) |value| if (value.kind == .call and turn.delivery.input.origin == .process) {
        try turn.reply(try q.QueryFailure.fromError(error.TableQueryWriterNotReady, .admission).?.encode());
        return true;
    };
    try turn.write(q.UnifiedRecords.key('e', turn.delivery.input.position, 0), try p.Value.init(reason));
    return true;
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const current = try self.phase(turn);
    const frame = s.Frame.decode(turn.delivery.input.value) catch {
        if (current == null) return error.UninitializedTableQueryWriter;
        return if (turn.delivery.input.origin == .external) rejectMutation(turn, .invalid_command) else rejectQuery(turn, null, "InvalidTableQueryFrame");
    };
    if (try self.initializer(turn, frame)) return false;
    if (current == null) return error.UninitializedTableQueryWriter;
    if (try self.continuation(turn, frame)) return false;
    if (current == .staged) return if (turn.delivery.input.origin == .external) rejectMutation(turn, .busy) else rejectQuery(turn, frame, "TableQueryWriterNotReady");
    if (turn.delivery.input.origin == .external) {
        if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "TQG1")) {
            if (!external(turn, self.configuration.writer.initializer)) return rejectMutation(turn, .denied);
            _ = QueryPolicyChange.decode(frame.payload) catch return rejectMutation(turn, .invalid_command);
            return false;
        }
        var writer: Writer = .{ .configuration = self.configuration.writer };
        const admission = writer.guard();
        return admission.reject(admission.context, turn);
    }
    if (turn.delivery.input.origin == .process) {
        if (frame.kind == .call or frame.kind == .cancel) return false;
        if (frame.kind == .cast and (try s.Frame.source(turn.delivery.input)) == turn.delivery.pid) {
            _ = q.UnifiedRecords.Continuation.decode(frame.payload) catch return rejectQuery(turn, frame, "InvalidQueryContinuation");
            return false;
        }
    }
    return rejectQuery(turn, frame, "UnexpectedTableQueryFrame");
}
fn changeQueryPolicy(self: *Self, turn: *s.Turn, payload: p.Value) !void {
    if (!external(turn, self.configuration.writer.initializer)) return error.MutationDenied;
    const change = try QueryPolicyChange.decode(payload);
    if (change.resource != self.configuration.writer.resource or change.policy.peer != self.configuration.peer or change.policy.requests != self.configuration.requests or !std.mem.eql(u8, &change.policy.declaration, &try q.Bundle.declaration(try self.configuration.definition()))) {
        _ = try rejectMutation(turn, .identity_conflict);
        return;
    }
    const current = (try q.UnifiedCapture.policy(turn, self.configuration.peer)) orelse return error.InvalidTableQueryWriterState;
    if (std.meta.eql(current, change.policy)) return;
    if (current.revision != change.expected_revision or change.expected_revision >= p.max_counter or change.policy.revision != change.expected_revision + 1) {
        _ = try rejectMutation(turn, .stale_policy);
        return;
    }
    try q.UnifiedCapture.setPolicy(turn, change.policy);
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const current = (try self.phase(turn)) orelse return error.UninitializedTableQueryWriter;
    if (try self.initializer(turn, frame)) return;
    if (try self.continuation(turn, frame)) {
        if (current == .staged) try self.activate(turn);
        return;
    }
    if (current != .ready) return error.TableQueryWriterNotReady;
    try q.UnifiedSource.checkCurrent(try self.configuration.definition(), turn);
    if (turn.delivery.input.origin == .external) {
        if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "TQG1")) return self.changeQueryPolicy(turn, frame.payload);
        var writer: Writer = .{ .configuration = self.configuration.writer };
        const mutation = writer.interface();
        return mutation.handle(mutation.context, turn, frame);
    }
    const source = self.source.interface();
    return source.handle(source.context, turn, frame);
}

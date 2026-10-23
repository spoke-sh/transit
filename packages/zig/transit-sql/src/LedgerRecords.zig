//! Fixed gateway metadata over growing KV. Explicit definitions precede every
//! record; publication bodies remain separately paged and immutable.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const definition = p.Growth.definition_bytes;
pub const intent_format: u32 = 0x47534901;
pub const Phase = enum(u8) { reserved = 1, uploading = 2, ready = 3, active = 4, terminal = 5, abandoned = 6 };
pub const Summary = enum(u8) { none = 0, applied = 1, rejected = 2, cancelled = 3 };
pub const Nonce = struct {
    pub const magic = "GSN1";
    id: u64,
    nonce: [16]u8,
    fingerprint: [32]u8,
    pub fn validate(self: Nonce) !void {
        if (self.id == 0 or self.id > p.max_counter) return error.InvalidGatewayNonce;
    }
};
/// Capacity is logical retained content, not a physical WAL/filesystem promise.
/// Reserved capacity protects accepted work from later admission pressure.
pub const Head = struct {
    pub const magic = "GSH1";
    configuration: [32]u8,
    operations: u64 = 0,
    unsettled: u64 = 0,
    used_bytes: u64 = 0,
    reserved_bytes: u64 = 0,
    operation_quota: u64,
    byte_quota: u64,
    pending_quota: u32,
    active: u64 = 0,
    pub fn validate(self: Head) !void {
        if (self.operation_quota == 0 or self.byte_quota == 0 or self.pending_quota == 0 or self.pending_quota > 1024 or self.operations > self.operation_quota or self.unsettled > self.operations or self.unsettled > self.pending_quota or self.used_bytes > self.byte_quota or self.reserved_bytes > self.byte_quota - self.used_bytes or self.active > p.max_counter or (self.active != 0 and self.unsettled == 0)) return error.InvalidGatewayHead;
    }
};
pub const Operation = struct {
    pub const magic = "GSO1";
    id: u64,
    nonce: [16]u8,
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64 = 1,
    role_present: u8 = 0,
    role: u64 = 0,
    phase: Phase = .reserved,
    intent_length: u32 = 0,
    intent_digest: [32]u8 = @splat(0),
    // One immutable reference is published at record 1. Dispatch eligibility
    // is permanent: uncertainty never restores the before-dispatch state.
    published: u8 = 0,
    stored_bytes: u64 = 0,
    reservation: u64,
    cancel: u8 = 0,
    reconcile: u8 = 0,
    blocked: u8 = 0,
    summary: Summary = .none,
    matched: u64 = 0,
    changed: u64 = 0,
    pub fn selectedRole(self: Operation) ?u64 {
        return if (self.role_present == 1) self.role else null;
    }
    pub fn validate(self: Operation) !void {
        if (self.namespace == 0 or self.namespace > p.max_counter or self.role_present > 1 or self.role > p.max_counter or (self.role_present == 0 and self.role != 0)) return error.InvalidGatewayOperation;
        if (self.id == 0 or self.id > p.max_counter or self.resource == 0 or self.resource > p.max_counter or self.owner == 0 or self.owner > p.max_counter or self.catalog == 0 or self.cancel > 1 or self.reconcile > 1 or self.blocked > 1 or self.published > 1 or self.changed > self.matched or self.intent_length > g.IntentReference.max_bytes) return error.InvalidGatewayOperation;
        if (self.phase == .reserved and self.intent_length != 0) return error.InvalidGatewayOperation;
        if (self.phase != .reserved and self.phase != .abandoned and self.intent_length <= g.IntentReference.prefix_bytes) return error.InvalidGatewayOperation;
        if (self.published != 0 and self.phase != .active and self.phase != .terminal) return error.InvalidGatewayOperation;
        if (self.phase != .terminal and self.phase != .abandoned and (self.reservation < 512 or self.stored_bytes > self.reservation - 512)) return error.InvalidGatewayReservation;
        if ((self.phase == .terminal or self.phase == .abandoned) and self.reservation != 0) return error.InvalidGatewayOperation;
        if ((self.phase == .terminal) != (self.summary != .none)) return error.InvalidGatewayOperation;
        if (self.summary != .applied and (self.matched != 0 or self.changed != 0)) return error.InvalidGatewayOperation;
        if (self.intent_length == 0 and !std.mem.allEqual(u8, &self.intent_digest, 0)) return error.InvalidGatewayOperation;
    }
    pub fn spec(self: Operation) g.station.Publication.Spec {
        return .{ .format = intent_format, .length = self.intent_length, .digest = self.intent_digest };
    }
};
fn writeField(writer: *std.Io.Writer, value: anytype) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int => try writer.writeInt(T, value, .little),
        .@"enum" => try writer.writeInt(@typeInfo(T).@"enum".tag_type, @backingInt(value), .little),
        .array => |array| {
            if (array.child != u8) @compileError("gateway records contain only fixed bytes and integers");
            try writer.writeAll(&value);
        },
        else => @compileError("gateway records contain only fixed bytes, integers and finite enums"),
    }
}
fn readField(comptime T: type, reader: *std.Io.Reader) !T {
    return switch (@typeInfo(T)) {
        .int => try reader.takeInt(T, .little),
        .@"enum" => |info| std.enums.fromInt(T, try reader.takeInt(info.tag_type, .little)) orelse error.InvalidGatewayRecord,
        .array => |array| (try reader.take(array.len))[0..array.len].*,
        else => @compileError("unsupported gateway record field"),
    };
}
pub fn encode(value: anytype) !p.Value {
    const T = @TypeOf(value);
    try value.validate();
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.writeAll(T.magic);
    try writer.writeAll(&definition);
    inline for (@typeInfo(T).@"struct".field_names) |name| try writeField(&writer, @field(value, name));
    return p.Value.init(writer.buffered());
}
pub fn decode(comptime T: type, value: p.Value) !T {
    try value.validate();
    var reader: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(4), T.magic)) return error.InvalidGatewayRecord;
    if (!std.mem.eql(u8, try reader.take(32), &definition)) return error.IncompatibleDefinition;
    var result: T = undefined;
    inline for (@typeInfo(T).@"struct".field_names) |name| @field(result, name) = try readField(@FieldType(T, name), &reader);
    if (reader.seek != value.len) return error.InvalidGatewayRecord;
    try result.validate();
    return result;
}
pub fn key(tag: u8, id: u64, item: u64) p.Value {
    var bytes: [20]u8 = undefined;
    bytes[0..3].* = "\x00GW".*;
    bytes[3] = tag;
    std.mem.writeInt(u64, bytes[4..12], id, .big);
    std.mem.writeInt(u64, bytes[12..20], item, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn nonceKey(nonce: [16]u8) p.Value {
    var bytes: [20]u8 = undefined;
    bytes[0..4].* = "\x00GWn".*;
    bytes[4..20].* = nonce;
    return p.Value.init(&bytes) catch unreachable;
}
/// The complete direct binding is checked before this compact commitment is
/// stored. Completion must match it; the original reference remains published.
pub const IntentBinding = struct {
    pub const magic = "GSB1";
    id: u64,
    binding: [32]u8,
    pub fn validate(self: IntentBinding) !void {
        if (self.id == 0 or self.id > p.max_counter or std.mem.allEqual(u8, &self.binding, 0)) return error.InvalidGatewayIntent;
    }
    pub fn from(reference: g.IntentReference.Reference) !IntentBinding {
        try reference.validate();
        return .{ .id = reference.binding.identity.operation, .binding = try g.IntentReference.bindingDigest(reference.binding) };
    }
};

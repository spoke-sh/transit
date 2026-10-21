//! Fixed gateway metadata over growing KV. Explicit definitions precede every
//! record; publication bodies remain separately paged and immutable.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const definition = g.SavedStep.definitionBytes;
pub const intent_format: u32 = 0x47534901;
pub const Phase = enum(u8) { reserved = 1, uploading = 2, ready = 3, active = 4, terminal = 5, abandoned = 6 };
pub const Summary = enum(u8) { none = 0, applied = 1, rejected = 2, cancelled = 3, upload_cancelled = 4 };
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
    sequence: u64,
    pub fn validate(self: Head) !void {
        if (self.operation_quota == 0 or self.byte_quota == 0 or self.pending_quota == 0 or self.pending_quota > 1024 or self.operations > self.operation_quota or self.unsettled > self.operations or self.unsettled > self.pending_quota or self.used_bytes > self.byte_quota or self.reserved_bytes > self.byte_quota - self.used_bytes or self.sequence > p.max_counter or self.active > p.max_counter or (self.active != 0 and self.unsettled == 0)) return error.InvalidGatewayHead;
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
    // Publication record 1 is the frozen intent. Further IDs are monotonically
    // allocated attempts; abandoning an unpublished step never reuses its ID.
    records: u64 = 0,
    staging: u64 = 0,
    pending: u64 = 0,
    published: u64 = 0,
    pending_sequence: u64 = 0,
    input: u64 = 0,
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
        if (self.id == 0 or self.id > p.max_counter or self.resource == 0 or self.resource > p.max_counter or self.owner == 0 or self.owner > p.max_counter or self.catalog == 0 or self.cancel > 2 or self.reconcile > 1 or self.blocked > 1 or self.published > self.records or self.changed > self.matched or self.intent_length > g.catalog.TableIntent.max_bytes or self.staging > self.records or self.pending > self.records or self.pending_sequence > p.max_counter or self.input > p.max_counter) return error.InvalidGatewayOperation;
        if ((self.pending == 0) != (self.pending_sequence == 0) or (self.pending == 0 and self.input != 0) or (self.pending != 0 and (self.pending == 1 or self.staging != 0 or self.phase != .active))) return error.InvalidGatewayOperation;
        if (self.phase == .reserved) {
            if (self.intent_length != 0 or self.records != 0 or self.staging != 0) return error.InvalidGatewayOperation;
        } else if (self.phase != .abandoned and (self.intent_length == 0 or self.records == 0)) return error.InvalidGatewayOperation;
        if (self.phase == .uploading and (self.staging != 1 or self.records != 1)) return error.InvalidGatewayOperation;
        if (self.staging == 1 and self.phase != .uploading) return error.InvalidGatewayOperation;
        if (self.phase == .ready and (self.staging != 0 or self.records != 1)) return error.InvalidGatewayOperation;
        if (self.phase != .terminal and self.phase != .abandoned and (self.reservation < 512 or self.stored_bytes > self.reservation - 512)) return error.InvalidGatewayReservation;
        if (self.phase == .terminal or self.phase == .abandoned) {
            if (self.staging != 0 or self.pending != 0 or self.reservation != 0) return error.InvalidGatewayOperation;
        }
        if ((self.phase == .terminal) != (self.summary != .none)) return error.InvalidGatewayOperation;
        if (self.summary != .applied and (self.matched != 0 or self.changed != 0)) return error.InvalidGatewayOperation;
        if (self.intent_length == 0 and !std.mem.eql(u8, &self.intent_digest, &@as([32]u8, @splat(0)))) return error.InvalidGatewayOperation;
    }
    pub fn spec(self: Operation) g.station.Publication.Spec {
        return .{ .format = intent_format, .length = self.intent_length, .digest = self.intent_digest };
    }
};
/// Native receipt and processed-input evidence are separate from SQL completion.
/// The owning coordinator validates observations before recording these fields.
pub const StepObservation = struct {
    pub const magic = "GSE1";
    record: u64,
    sequence: u64,
    input: u64,
    processed: u8 = 0,
    disposition: enum(u8) { absent = 0, recorded = 1 } = .absent,
    // Commitment to exact public disposition bytes; bodies live in private KV.
    evidence: [32]u8 = @splat(0),
    pub fn validate(self: StepObservation) !void {
        if (self.record <= 1 or self.sequence == 0 or self.sequence > p.max_counter or self.input == 0 or self.input > p.max_counter or self.processed > 1 or (self.processed == 0 and self.disposition != .absent)) return error.InvalidGatewayObservation;
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
    try writer.writeAll(&definition());
    inline for (@typeInfo(T).@"struct".field_names) |name| try writeField(&writer, @field(value, name));
    return p.Value.init(writer.buffered());
}
pub fn decode(comptime T: type, value: p.Value) !T {
    try value.validate();
    var reader: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(4), T.magic)) return error.InvalidGatewayRecord;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
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
test "gateway metadata retains full width and rejects foreign definitions and impossible states" {
    const t = std.testing;
    const records = .{ Head{ .configuration = @splat(7), .operation_quota = std.math.maxInt(u64), .byte_quota = std.math.maxInt(u64), .pending_quota = 16, .sequence = p.max_counter }, Operation{ .id = 7, .nonce = @splat(9), .resource = 4, .catalog = std.math.maxInt(u64), .owner = 3, .reservation = 1000 }, StepObservation{ .record = 2, .sequence = 1, .input = 8 } };
    inline for (records) |record| {
        const T = @TypeOf(record);
        var encoded = try encode(record);
        try t.expect(encoded.len <= 256);
        try t.expectEqualDeep(record, try decode(T, encoded));
        encoded.data[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, decode(T, encoded));
        encoded.data[4] ^= 1;
        encoded.len += 1;
        try t.expectError(error.InvalidGatewayRecord, decode(T, encoded));
    }
    var invalid = records[1];
    invalid.pending = 2;
    try t.expectError(error.InvalidGatewayOperation, encode(invalid));
    invalid = records[1];
    invalid.phase = .terminal;
    try t.expectError(error.InvalidGatewayOperation, encode(invalid));
    try t.expect(std.mem.order(u8, key('o', 255, 0).slice(), key('o', 256, 0).slice()) == .lt);
}

/// Admitted once from the complete canonical intent. Header plus two digests
/// lets each signed upload step use a bounded committed range comparison.
pub const IntentBinding = struct {
    pub const magic = "GSB1";
    // The GSB1 envelope carries and validates the shared definition once. The
    // nested TCQ1 magic/definition are omitted, keeping this record within one
    // native value without dropping any command identity or namespace fields.
    header: [g.catalog.TableCommand.header_bytes - 36]u8,
    body_offset: u32,
    body_length: u32,
    command_digest: [32]u8,
    identity_digest: [32]u8,
    route: u8,
    pub fn validate(self: IntentBinding) !void {
        const h = try self.commandHeader();
        if (self.body_offset < g.catalog.TableIntent.prefix_bytes or self.body_length <= g.catalog.TableCommand.header_bytes or self.body_length > g.catalog.TableCommand.max_bytes or @as(u64, self.body_offset) + self.body_length > g.catalog.TableIntent.max_bytes) return error.InvalidGatewayIntent;
        if (h.kind == .create or h.kind == .alter or h.kind == .rename or h.kind == .drop) {
            if (self.route != 0) return error.InvalidGatewayIntent;
        } else if ((h.kind != .insert and h.kind != .update and h.kind != .delete) or (self.route != 1 and self.route != 2)) return error.InvalidGatewayIntent;
    }
    pub fn from(intent: *const g.catalog.TableIntent) !IntentBinding {
        const encoded_header = try intent.header.encode();
        const result: IntentBinding = .{ .header = encoded_header[36..].*, .body_offset = @intCast(intent.bytes.len - intent.body.len), .body_length = @intCast(intent.body.len), .command_digest = intent.spec.digest, .identity_digest = switch (intent.identity) {
            .ddl => |v| v.digest,
            .dml => |v| v.reference.digest,
        }, .route = switch (intent.identity) {
            .ddl => 0,
            .dml => |v| @backingInt(v.route),
        } };
        try result.validate();
        return result;
    }
    pub fn binding(self: IntentBinding, id: u64) !g.catalog.TableIntent.Binding {
        try self.validate();
        const h = try self.commandHeader();
        if (h.operation != id) return error.GatewayIdentityConflict;
        return .{ .header = h, .namespace = id, .spec = .{ .format = g.catalog.TableCommand.format, .length = self.body_length, .digest = self.command_digest }, .identity = if (self.route == 0) .{ .ddl = .{ .scope = h.scope, .principal = h.principal, .operation = id, .digest = self.identity_digest } } else .{ .dml = .{ .route = std.enums.fromInt(g.station.TableWrite.Status.Route, self.route) orelse return error.InvalidGatewayIntent, .reference = .{ .resource = h.scope.resource, .object = h.object, .principal = h.principal, .operation = id, .digest = self.identity_digest } } } };
    }
    fn commandHeader(self: IntentBinding) !g.catalog.TableCommand.Header {
        var bytes: [g.catalog.TableCommand.header_bytes]u8 = undefined;
        bytes[0..4].* = "TCQ1".*;
        bytes[4..36].* = definition();
        bytes[36..].* = self.header;
        return g.catalog.TableCommand.inspect(&bytes);
    }
};

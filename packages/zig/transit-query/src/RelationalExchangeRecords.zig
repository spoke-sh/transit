//! Query-exchange control records. All total-cardinality state is native paged
//! KV; these bounded values contain counters, cursors and immutable references.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const x = q.fuze.RelationalExchange;
const Ref = q.station.PublicationReference;
pub const segment_format: u32 = 0x31535846;
pub const none = std.math.maxInt(u64);

pub fn key(tag: u8, id: u64, source: u8, partition: u64, sequence: u64) !p.Value {
    if (id == 0) return error.InvalidRelationalExchange;
    var bytes: [28]u8 = undefined;
    bytes[0..2].* = "\x00x".*;
    bytes[2] = tag;
    std.mem.writeInt(u64, bytes[3..11], id, .big);
    bytes[11] = source;
    std.mem.writeInt(u64, bytes[12..20], partition, .big);
    std.mem.writeInt(u64, bytes[20..28], sequence, .big);
    return p.Value.init(&bytes);
}
pub fn rowKey(id: u64, source: u8, identity: ?q.fuze.Relational.RowIdentity) !p.Value {
    var bytes: [32]u8 = @splat(0);
    bytes[0..2].* = "\x00x".*;
    bytes[2] = 'r';
    std.mem.writeInt(u64, bytes[3..11], id, .big);
    bytes[11] = source;
    if (identity) |value| {
        try value.validate();
        x.identityBytes(value, bytes[12..32]);
    }
    return p.Value.init(&bytes);
}
fn start(writer: *std.Io.Writer, magic: []const u8) !void {
    try writer.writeAll(magic);
    try writer.writeAll(&x.definition());
}
fn readStart(reader: *std.Io.Reader, magic: []const u8) !void {
    if (!std.mem.eql(u8, try reader.take(4), magic)) return error.InvalidRelationalExchange;
    if (!std.mem.eql(u8, try reader.take(32), &x.definition())) return error.IncompatibleDefinition;
}
fn done(reader: *std.Io.Reader) !void {
    if (reader.bufferedLen() != 0) return error.InvalidRelationalExchange;
}
fn writeInts(writer: *std.Io.Writer, value: anytype, comptime fields: anytype) !void {
    inline for (fields) |name| try writer.writeInt(u64, @field(value, name), .little);
}
fn readInts(reader: *std.Io.Reader, value: anytype, comptime fields: anytype) !void {
    inline for (fields) |name| @field(value, name) = try reader.takeInt(u64, .little);
}
pub const Limits = struct {
    retained_bytes: u64,
    credit_bytes: u64,
    credit_segments: u64,
    pub fn validate(self: Limits) !void {
        if (self.retained_bytes < x.max_bytes or self.credit_bytes < x.max_bytes or self.credit_segments == 0) return error.InvalidRelationalExchange;
    }
};
pub const Head = struct {
    id: u64,
    owner: u64,
    resource: u64,
    binding: [32]u8,
    partitions: u64,
    sources: u8,
    registered: u64 = 0,
    completed: u64 = 0,
    next_record: u64 = 1,
    retained_bytes: u64 = 0,
    inflight_bytes: u64 = 0,
    inflight_segments: u64 = 0,
    limits: Limits,
    pending: bool = false,
    closed: bool = false,
    const fields = .{ "id", "owner", "resource", "partitions", "registered", "completed", "next_record", "retained_bytes", "inflight_bytes", "inflight_segments" };
    pub fn total(self: Head) !u64 {
        return std.math.mul(u64, self.partitions, self.sources) catch error.InvalidRelationalExchange;
    }
    pub fn validate(self: Head) !void {
        try self.limits.validate();
        if (self.id == 0 or self.owner == 0 or self.resource == 0 or self.partitions == 0 or self.sources == 0 or self.sources > 2 or self.next_record == 0 or
            self.completed > self.registered or self.registered > try self.total() or self.retained_bytes > self.limits.retained_bytes or
            self.inflight_bytes > self.limits.credit_bytes or self.inflight_segments > self.limits.credit_segments or
            self.inflight_bytes > self.retained_bytes or ((self.inflight_segments == 0) != (self.inflight_bytes == 0))) return error.InvalidRelationalExchange;
    }
    pub fn publication(self: Head) q.station.Publication {
        return .{ .resource = self.resource, .domain = .query_exchange, .namespace = self.id };
    }
    pub fn address(self: Head) !p.Value {
        return key('h', self.id, 0, 0, 0);
    }
    pub fn encode(self: Head) !p.Value {
        try self.validate();
        var bytes: [256]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXH1");
        try writer.writeAll(&self.binding);
        try writeInts(&writer, self, fields);
        try writeInts(&writer, self.limits, .{ "retained_bytes", "credit_bytes", "credit_segments" });
        try writer.writeByte(self.sources);
        try writer.writeByte(@intFromBool(self.pending));
        try writer.writeByte(@intFromBool(self.closed));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Head {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXH1");
        var result: Head = undefined;
        result.binding = (try reader.takeArray(32)).*;
        try readInts(&reader, &result, fields);
        try readInts(&reader, &result.limits, .{ "retained_bytes", "credit_bytes", "credit_segments" });
        result.sources = try reader.takeByte();
        const pending = try reader.takeByte();
        const closed = try reader.takeByte();
        if (pending > 1 or closed > 1) return error.InvalidRelationalExchange;
        result.pending = pending == 1;
        result.closed = closed == 1;
        try done(&reader);
        try result.validate();
        return result;
    }
};
pub const Channel = struct {
    producer: u64,
    resource: u64,
    consumed: u64 = 0,
    accepted: u64 = 0,
    highest: u64 = 0,
    terminal: u64 = none,
    row: u8 = 0,
    last: ?q.fuze.Relational.RowIdentity = null,
    complete: bool = false,
    const fields = .{ "producer", "resource", "consumed", "accepted", "highest", "terminal" };
    fn validate(self: Channel) !void {
        if (self.producer == 0 or self.resource == 0 or self.consumed > self.accepted or self.accepted != self.highest or self.row >= x.max_rows or
            (self.terminal != none and self.highest > self.terminal + 1) or
            (self.complete and (self.terminal == none or self.consumed != self.terminal + 1 or self.row != 0))) return error.InvalidRelationalExchange;
        if (self.last) |id| try id.validate();
    }
    pub fn encode(self: Channel) !p.Value {
        try self.validate();
        var bytes: [107]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXC1");
        try writeInts(&writer, self, fields);
        try writer.writeByte(self.row);
        try writer.writeByte(@intFromBool(self.complete));
        try writer.writeByte(@intFromBool(self.last != null));
        var id: [20]u8 = @splat(0);
        if (self.last) |value| x.identityBytes(value, &id);
        try writer.writeAll(&id);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Channel {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXC1");
        var result: Channel = undefined;
        try readInts(&reader, &result, fields);
        result.row = try reader.takeByte();
        const complete = try reader.takeByte();
        const present = try reader.takeByte();
        if (complete > 1 or present > 1) return error.InvalidRelationalExchange;
        result.complete = complete == 1;
        const id: q.fuze.Relational.RowIdentity = .{ .origin = try reader.takeInt(u64, .big), .operation = try reader.takeInt(u64, .big), .ordinal = try reader.takeInt(u32, .big) };
        if (present == 0 and (id.origin != 0 or id.operation != 0 or id.ordinal != 0)) return error.InvalidRelationalExchange;
        result.last = if (present == 1) id else null;
        try done(&reader);
        try result.validate();
        return result;
    }
};
pub const Pending = struct {
    source: u8,
    partition: u64,
    sequence: u64,
    remote: Ref,
    pub fn encode(self: Pending) !p.Value {
        if (self.source >= 2 or self.sequence == none or self.remote.domain != .query_exchange or self.remote.spec.format != segment_format or self.remote.spec.length < 111 or self.remote.spec.length > x.max_bytes) return error.InvalidRelationalExchange;
        var bytes: [125]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXP1");
        try writer.writeByte(self.source);
        try writeInts(&writer, self, .{ "partition", "sequence" });
        try writer.writeAll((try self.remote.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Pending {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXP1");
        var result: Pending = undefined;
        result.source = try reader.takeByte();
        try readInts(&reader, &result, .{ "partition", "sequence" });
        result.remote = try Ref.decode(try p.Value.init(try reader.take(72)));
        try done(&reader);
        _ = try result.encode();
        return result;
    }
};
pub const Accepted = struct {
    remote: Ref,
    local: Ref,
    pub fn encode(self: Accepted) !p.Value {
        if (!std.meta.eql(self.remote.spec, self.local.spec) or self.local.spec.format != segment_format) return error.InvalidRelationalExchange;
        var bytes: [180]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXA1");
        try writer.writeAll((try self.remote.encode()).slice());
        try writer.writeAll((try self.local.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Accepted {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXA1");
        const result: Accepted = .{ .remote = try Ref.decode(try p.Value.init(try reader.take(72))), .local = try Ref.decode(try p.Value.init(try reader.take(72))) };
        try done(&reader);
        _ = try result.encode();
        return result;
    }
};
pub const Row = struct {
    segment: Ref,
    ordinal: u8,
    pub fn encode(self: Row) !p.Value {
        if (self.ordinal >= x.max_rows or self.segment.spec.format != segment_format) return error.InvalidRelationalExchange;
        var bytes: [109]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXR1");
        try writer.writeAll((try self.segment.encode()).slice());
        try writer.writeByte(self.ordinal);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Row {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXR1");
        const result: Row = .{ .segment = try Ref.decode(try p.Value.init(try reader.take(72))), .ordinal = try reader.takeByte() };
        try done(&reader);
        _ = try result.encode();
        return result;
    }
};
/// Immutable destination for one exchange, independent of its Table owners.
pub const Receiver = struct {
    owner: u64,
    resource: u64,
    pub fn validate(self: Receiver) !void {
        try q.UnifiedRecords.identity(self.owner);
        try q.UnifiedRecords.identity(self.resource);
    }
};
pub const Producer = struct {
    id: u64,
    owner: u64,
    resource: u64,
    binding: [32]u8,
    receiver: Receiver,
    limit: u64,
    charged: u64,
    last: u64 = 0,
    pending: ?Ref = null,
    pub const base_bytes = 205 + 28 + 32 + 27;
    pub fn charge(spec: q.station.Publication.Spec) u64 {
        return @as(u64, spec.length) + 2 * (125 + 28) + 104 + (@as(u64, spec.chunks()) + 1) * 27;
    }
    const fields = .{ "id", "owner", "resource", "limit", "charged", "last" };
    pub fn encode(self: Producer) !p.Value {
        try self.receiver.validate();
        if (self.receiver.resource == self.resource) return error.InvalidRelationalExchange;
        if (self.id == 0 or self.owner == 0 or self.resource == 0 or self.limit < x.max_bytes or self.charged < base_bytes or self.charged > self.limit) return error.InvalidRelationalExchange;
        if (self.pending) |reference| {
            if (reference.record <= self.last or reference.resource != self.resource or reference.namespace != self.id or reference.domain != .query_exchange or reference.spec.format != segment_format or reference.spec.length < 111 or reference.spec.length > x.max_bytes) return error.InvalidRelationalExchange;
            if (charge(reference.spec) > self.charged - base_bytes) return error.InvalidRelationalExchange;
        }
        var bytes: [205]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RXB1");
        try writer.writeAll(&self.binding);
        try writeInts(&writer, self, fields);
        try writer.writeInt(u64, self.receiver.owner, .little);
        try writer.writeInt(u64, self.receiver.resource, .little);
        try writer.writeByte(@intFromBool(self.pending != null));
        if (self.pending) |reference| try writer.writeAll((try reference.encode()).slice()) else try writer.splatByteAll(0, 72);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Producer {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try readStart(&reader, "RXB1");
        var result: Producer = undefined;
        result.binding = (try reader.takeArray(32)).*;
        try readInts(&reader, &result, fields);
        result.receiver = .{ .owner = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little) };
        const present = try reader.takeByte();
        if (present > 1) return error.InvalidRelationalExchange;
        const encoded = try reader.take(72);
        if (present == 0 and !std.mem.allEqual(u8, encoded, 0)) return error.InvalidRelationalExchange;
        result.pending = if (present == 1) try Ref.decode(try p.Value.init(encoded)) else null;
        try done(&reader);
        _ = try result.encode();
        return result;
    }
};

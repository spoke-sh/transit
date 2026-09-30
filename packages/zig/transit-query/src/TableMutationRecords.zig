//! Bounded mutation policy, durable namespace status and ordinary frame codecs.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Request = q.TableMutationRequest;
const Ref = q.station.PublicationReference;
pub const part_bytes = q.station.PublicationParts.part_bytes;
pub fn key(tag: u8, first: u64, second: u64) p.Value {
    var bytes: [19]u8 = undefined;
    bytes[0..2].* = "\x00M".*;
    bytes[2] = tag;
    std.mem.writeInt(u64, bytes[3..11], first, .big);
    std.mem.writeInt(u64, bytes[11..19], second, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn identity(value: u64) !void {
    if (value == 0 or value > p.max_counter) return error.InvalidMutationRecord;
}
fn magic(reader: *std.Io.Reader, expected: []const u8) !void {
    if (!std.mem.eql(u8, try reader.take(4), expected)) return error.InvalidMutationRecord;
}
fn finish(reader: *std.Io.Reader) !void {
    if (reader.bufferedLen() != 0) return error.InvalidMutationRecord;
}
pub fn declaration(table: q.station.Table) ![32]u8 {
    var bytes: [64]u8 = undefined;
    return q.fuze.Unified.sourceFingerprint(try table.queryDefinition(&bytes));
}
pub const Policy = struct {
    principal: u64,
    table: u32,
    revision: u64,
    declaration: [32]u8,
    /// insert=1, update=2, delete=4; zero revokes without deleting the revision.
    permissions: u8,
    pub fn validate(self: Policy) !void {
        try identity(self.principal);
        try identity(self.revision);
        if (self.table == 0 or self.permissions & ~@as(u8, 7) != 0) return error.InvalidMutationRecord;
    }
    pub fn permits(self: Policy, operation: q.fuze.TableMutation.Operation) bool {
        const bit: u8 = switch (operation) {
            .insert => 1,
            .update => 2,
            .delete => 4,
        };
        return self.permissions & bit != 0;
    }
    pub fn encode(self: Policy) !p.Value {
        try self.validate();
        var bytes: [57]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("TML1");
        try writer.writeInt(u64, self.principal, .little);
        try writer.writeInt(u32, self.table, .little);
        try writer.writeInt(u64, self.revision, .little);
        try writer.writeAll(&self.declaration);
        try writer.writeByte(self.permissions);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Policy {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "TML1");
        const result: Policy = .{ .principal = try reader.takeInt(u64, .little), .table = try reader.takeInt(u32, .little), .revision = try reader.takeInt(u64, .little), .declaration = (try reader.takeArray(32)).*, .permissions = try reader.takeByte() };
        try finish(&reader);
        try result.validate();
        return result;
    }
};
pub const Phase = enum(u8) { uploading = 1, sealed = 2, applied = 3, rejected = 4, cancelled = 5 };
pub const Reason = enum(u8) { none = 0, row_exists = 1, source_changed = 2, invalid_request = 3, denied = 4, budget = 5 };
pub const Status = struct {
    reference: Ref,
    principal: u64,
    table: u32,
    declaration: [32]u8,
    /// Original begin policy; any policy revision change fences this request.
    policy_revision: u64,
    phase: Phase = .uploading,
    affected_rows: u8 = 0,
    reason: Reason = .none,
    input: u64 = 0,
    pub fn terminal(self: Status) bool {
        return self.phase != .uploading and self.phase != .sealed;
    }
    pub fn validate(self: Status) !void {
        try Request.checkReference(self.reference);
        try identity(self.principal);
        try identity(self.policy_revision);
        if (self.table == 0 or self.affected_rows > q.fuze.TableMutation.max_rows) return error.InvalidMutationRecord;
        if (self.terminal()) {
            try identity(self.input);
        } else if (self.input != 0 or self.reason != .none or self.affected_rows != 0) return error.InvalidMutationRecord;
        switch (self.phase) {
            .applied => if (self.reason != .none) return error.InvalidMutationRecord,
            .rejected => if (self.reason == .none or self.affected_rows != 0) return error.InvalidMutationRecord,
            .cancelled => if (self.reason != .none or self.affected_rows != 0) return error.InvalidMutationRecord,
            else => {},
        }
    }
    pub fn encode(self: Status) !p.Value {
        try self.validate();
        var bytes: [139]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("TMS1");
        try writer.writeAll((try self.reference.encode()).slice());
        try writer.writeInt(u64, self.principal, .little);
        try writer.writeInt(u32, self.table, .little);
        try writer.writeAll(&self.declaration);
        try writer.writeInt(u64, self.policy_revision, .little);
        try writer.writeAll(&.{ @backingInt(self.phase), self.affected_rows, @backingInt(self.reason) });
        try writer.writeInt(u64, self.input, .little);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Status {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "TMS1");
        const result: Status = .{
            .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))),
            .principal = try reader.takeInt(u64, .little),
            .table = try reader.takeInt(u32, .little),
            .declaration = (try reader.takeArray(32)).*,
            .policy_revision = try reader.takeInt(u64, .little),
            .phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidMutationRecord,
            .affected_rows = try reader.takeByte(),
            .reason = std.enums.fromInt(Reason, try reader.takeByte()) orelse return error.InvalidMutationRecord,
            .input = try reader.takeInt(u64, .little),
        };
        try finish(&reader);
        try result.validate();
        return result;
    }
};
pub const Begin = struct { reference: Ref, table: u32, policy_revision: u64 };
pub const Command = union(enum) {
    begin: Begin,
    part: struct { reference: Ref, ordinal: u32, second: bool, bytes: []const u8 },
    seal: Ref,
    apply: Ref,
    cancel: Ref,
    pub fn encode(self: Command) !p.Value {
        var bytes: [q.station.Frame.max_payload]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll(switch (self) {
            .begin => "TMB1",
            .part => "TMP1",
            .seal => "TMZ1",
            .apply => "TMX1",
            .cancel => "TMK1",
        });
        switch (self) {
            .begin => |value| {
                try Request.checkReference(value.reference);
                try identity(value.policy_revision);
                if (value.table == 0) return error.InvalidMutationCommand;
                try writer.writeAll((try value.reference.encode()).slice());
                try writer.writeInt(u32, value.table, .little);
                try writer.writeInt(u64, value.policy_revision, .little);
            },
            .part => |value| {
                const chunks = std.math.divCeil(u32, Request.max_bytes, q.station.Publication.chunk_bytes) catch unreachable;
                try Request.checkReference(value.reference);
                if (value.bytes.len == 0 or value.bytes.len > part_bytes or value.ordinal >= chunks) return error.InvalidMutationCommand;
                try writer.writeAll((try value.reference.encode()).slice());
                try writer.writeInt(u32, value.ordinal, .little);
                try writer.writeByte(@intFromBool(value.second));
                try writer.writeAll(value.bytes);
            },
            .seal, .apply, .cancel => |reference| {
                try Request.checkReference(reference);
                try writer.writeAll((try reference.encode()).slice());
            },
        }
        return p.Value.init(writer.buffered());
    }
    /// Part bytes borrow this input. The owning turn copies them before return.
    pub fn decode(value: *const p.Value) !Command {
        try value.validate();
        if (value.len > q.station.Frame.max_payload) return error.InvalidMutationCommand;
        var reader: std.Io.Reader = .fixed(value.slice());
        const tag = try reader.take(4);
        const result: Command = if (std.mem.eql(u8, tag, "TMB1")) .{ .begin = .{ .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))), .table = try reader.takeInt(u32, .little), .policy_revision = try reader.takeInt(u64, .little) } } else if (std.mem.eql(u8, tag, "TMP1")) blk: {
            const reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes)));
            const ordinal = try reader.takeInt(u32, .little);
            const second = try reader.takeByte();
            if (second > 1) return error.InvalidMutationCommand;
            break :blk .{ .part = .{ .reference = reference, .ordinal = ordinal, .second = second == 1, .bytes = try reader.take(reader.bufferedLen()) } };
        } else if (std.mem.eql(u8, tag, "TMZ1")) .{ .seal = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) } else if (std.mem.eql(u8, tag, "TMX1")) .{ .apply = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) } else if (std.mem.eql(u8, tag, "TMK1")) .{ .cancel = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) } else return error.InvalidMutationCommand;
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value.*)) return error.InvalidMutationCommand;
        return result;
    }
};

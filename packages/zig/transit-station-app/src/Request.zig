//! Fixed native commands carried by ordinary signed Station cast frames.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const Pub = root.Publication;
const Wide = root.Model.Wide;
pub const Part = struct {
    pub const json_schema_fields = .{ .bytes = .{ .type = "string", .pattern = "^(?:[0-9a-f]{2})+$", .maxLength = 256, .@"x-transit-encoding" = "lowercase-hex" } };
    operation: Wide,
    ordinal: u32,
    second: bool,
    bytes: p.Value,
};
pub const Command = union(enum(u8)) {
    initialize: void = 0,
    policy: struct { principal: u64, expected: Wide, next: Pub.Policy } = 1,
    begin: Pub.Proposal = 2,
    part: Part = 3,
    publish: Wide = 4,
    abandon: Wide = 5,
    collect: Wide = 6,

    pub fn validate(self: Command) !void {
        switch (self) {
            .initialize => {},
            .policy => |value| if (value.principal == 0 or value.principal > p.max_counter or value.next.revision.value != try std.math.add(u64, value.expected.value, 1)) return error.InvalidApplicationPolicy,
            .begin => |proposal| try Pub.validateProposal(proposal),
            .part => |value| {
                try value.bytes.validate();
                if (value.operation.value == 0 or value.ordinal >= root.Model.max_program_bytes / root.station.Publication.chunk_bytes or value.bytes.len == 0 or value.bytes.len > root.station.PublicationParts.part_bytes) return error.InvalidApplicationPart;
            },
            .publish, .abandon, .collect => |operation| if (operation.value == 0) return error.InvalidApplicationOperation,
        }
    }
    pub fn encode(self: Command) !p.Value {
        try self.validate();
        const value = try root.Records.encode('i', self);
        if (value.len > root.station.Frame.max_payload) return error.MessageTooLarge;
        return value;
    }
    pub fn decode(value: p.Value) !Command {
        const result = try root.Records.decode(Command, 'i', value);
        try result.validate();
        return result;
    }
};

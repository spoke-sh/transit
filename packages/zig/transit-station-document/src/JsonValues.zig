//! Neutral JSON representation of an accepted Document reference and checked
//! full-width values. Conversion validates the owning native contract.
const std = @import("std");
const document = @import("root.zig");
const values = document.station.fuze.NeutralEncoding;
pub const unsigned = values.unsigned;
pub const unhex = values.unhex;
pub const decimal = values.decimal;
pub const hex = values.hex;
pub const Reference = struct {
    resource: u64,
    document: []const u8,
    epoch: []const u8,
    type_revision: u32,
    revision: []const u8,
    pub fn native(self: Reference) !document.Client.Reference {
        const out: document.Client.Reference = .{ .resource = self.resource, .document = try unsigned(self.document), .epoch = try unsigned(self.epoch), .type_revision = self.type_revision, .revision = try unsigned(self.revision) };
        _ = try out.encode();
        return out;
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: document.Client.Reference) !Reference {
        return .{ .resource = value.resource, .document = try decimal(alloc, value.document), .epoch = try decimal(alloc, value.epoch), .type_revision = value.type_revision, .revision = try decimal(alloc, value.revision) };
    }
};

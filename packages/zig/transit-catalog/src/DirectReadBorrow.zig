//! Original-caller authorization to read one already retained cut through a
//! distinct executor. Borrowing grants no acquisition, advancement or cleanup.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Grant = c.DirectReadDelegation;
const Self = @This();

pub const Target = union(enum) {
    snapshot: w.Snapshot,
    history: w.Historical,
    pub fn action(self: Target) w.Action {
        return switch (self) {
            .snapshot => |value| .{ .snapshot = value },
            .history => |value| .{ .history_source = value },
        };
    }
};
pub const Binding = struct {
    executor: u64,
    target: Target,
    purpose: [32]u8,

    pub fn validate(self: Binding, original: Grant) !void {
        if (self.executor > p.max_counter or std.mem.allEqual(u8, &self.purpose, 0)) return error.InvalidTableDelegation;
        try original.allow(self.target.action());
        switch (self.target) {
            .snapshot => |value| {
                if (original.binding.retention != .snapshot) return error.TableDelegationDenied;
                try value.handle.content.validate();
            },
            .history => |value| _ = try value.point.cursorSource(),
        }
    }
    pub fn context(self: Binding, original: Grant, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate(original);
        const saved = try original.encode(allocator);
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.borrowed-read.v1\x00");
        hash.update(&saved);
        hash.update(bytes);
        return hash.finalResult();
    }
};

binding: Binding,
signature: [64]u8,

/// The accepted caller's epoch and role remain fixed. A fresh credential cannot
/// renew this query by signing a replacement borrowed read.
pub fn prepare(client: c.DirectTableClient, original: Grant, binding: Binding) !Self {
    if (client.delegation != null or client.closure != null or client.borrow != null or !std.meta.eql(client.connection, original.binding.connection)) return error.InvalidTableDelegation;
    const native: c.client.AuthorizationClient = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
    const signed = (try native.proof(client.connection.audience, try binding.context(original, client.allocator))).signed;
    if (signed.claim.credential_epoch != original.proof.claim.credential_epoch) return error.InvalidTableDelegation;
    return .{ .binding = binding, .signature = signed.signature };
}

pub fn proof(self: Self, original: Grant, allocator: std.mem.Allocator) !p.Authorization.Proof {
    var claim = original.proof.claim;
    claim.context = try self.binding.context(original, allocator);
    try claim.validate();
    return .{ .claim = claim, .signature = self.signature };
}

pub fn allow(self: Self, action: w.Action) !void {
    const target: Target = switch (action) {
        .snapshot => |value| .{ .snapshot = value },
        inline .scan, .column_scan, .filter_scan, .read_key, .key_range => |value| .{ .snapshot = value.snapshot },
        .history_source => |value| .{ .history = value },
        .history_scan => |value| .{ .history = value.source },
        else => return error.TableDelegationDenied,
    };
    if (!std.meta.eql(target, self.binding.target)) return error.TableDelegationDenied;
}

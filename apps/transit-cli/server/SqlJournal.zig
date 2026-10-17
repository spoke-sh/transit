//! One frozen root request at a time, owned by the local installation supervisor.
//! Fixed receipt slots describe finite setup steps, never retained user cardinality.
const std = @import("std");
const q = @import("transit_query");
const p = q.protocol;
const native = p.Growth;
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Self = @This();
receipts: [24]?u64 = @splat(null),
pending: ?Pending = null,
rejected: ?struct { proposal: Pending, cause: p.ErrorCode } = null,
change: ?u64 = null,
generation: u64 = 0,
const Pending = struct { signed: native.SignedRequest, index: u8 };

pub fn save(installation: *Installation, path: []const u8, record: anytype) !void {
    Files.json(installation.init.io, installation.init.gpa, path, record) catch |err| {
        installation.failed = true;
        return err;
    };
}
pub fn flush(self: *Self, installation: *Installation, path: []const u8, record: anytype) !void {
    const pending = self.pending orelse return;
    try installation.reserveRoot(pending.signed);
    const receipt = installation.wire.submit(pending.signed) catch |err| receipt: {
        const cause = installation.wire.last_rejection orelse return err;
        // A negative attempt may follow an earlier accepted request. Resolve
        // the exact receipt before releasing the shared root sequence.
        const observed = try installation.query(.{ .authorization = .{ .kind = .{ .receipt = pending.signed.request } } });
        if (observed.body.authorization.body.receipt) |accepted| break :receipt accepted;
        self.rejected = .{ .proposal = pending, .cause = cause };
        self.pending = null;
        try save(installation, path, record);
        try installation.releaseRoot(pending.signed);
        return err;
    };
    const command = pending.signed.request.command;
    switch (command) {
        .authorization => |authorization| switch (authorization) {
            .begin => self.change = receipt.position,
            .advance => {},
            .abandon => self.change = null,
            .publish => |id| {
                const observed = try installation.query(.{ .authorization = .{ .kind = .{ .change = id } } });
                const outcome = observed.body.authorization.body.change;
                if (outcome.status != .published) return error.UnresolvedProvisioning;
                self.receipts[pending.index] = outcome.created_id orelse 0;
                self.change = null;
            },
        },
        .own => |value| self.generation = try std.math.add(u64, value.expected_generation, 1),
        else => self.receipts[pending.index] = receipt.position,
    }
    installation.record.position = @max(installation.record.position, receipt.position);
    try installation.save();
    self.pending = null;
    try save(installation, path, record);
    try installation.releaseRoot(pending.signed);
}
pub fn submit(self: *Self, installation: *Installation, path: []const u8, record: anytype, index: u8, command: native.Command) !void {
    if (self.pending != null or installation.record.pending != null or installation.root_pending != null) return error.UnresolvedProvisioning;
    const observation = try installation.query(.{ .capabilities = {} });
    self.pending = .{ .index = index, .signed = try native.sign(.{ .realm = installation.config.realm, .principal = 0, .sequence = try std.math.add(u64, observation.principal_sequence, 1), .command = command }, installation.root) };
    try save(installation, path, record);
    try self.flush(installation, path, record);
}
pub fn authorize(self: *Self, installation: *Installation, path: []const u8, record: anytype, index: u8, action: p.Authorization.Action) !void {
    while (self.receipts[index] == null) {
        if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
        const policy = (try installation.query(.{ .authorization = .{ .kind = .identity } })).body.authorization;
        const command: p.Authorization.Command = if (self.change) |id| blk: {
            const outcome = (try installation.query(.{ .authorization = .{ .kind = .{ .change = id } } })).body.authorization.body.change;
            if (outcome.basis != policy.revision) break :blk .{ .abandon = id };
            break :blk if (outcome.status == .ready) .{ .publish = id } else .{ .advance = id };
        } else .{ .begin = .{ .expected_revision = policy.revision, .action = action } };
        try self.submit(installation, path, record, index, .{ .authorization = command });
    }
}
pub fn activate(self: *Self, installation: *Installation, path: []const u8, record: anytype, pid: u64, worker: u64) !void {
    const process = (try installation.query(.{ .process = pid })).body.process.process;
    if (process.lifecycle != .running or process.failure != null) return error.ProcessUnavailable;
    // Ownership changes never recreate the worker's credential or its grants.
    try self.submit(installation, path, record, 0, .{ .own = .{ .pid = pid, .expected_generation = process.generation, .worker = worker } });
}

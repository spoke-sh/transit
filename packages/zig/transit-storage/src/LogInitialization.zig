//! Fenced initial WAL acceptance with exact declaration readback. Catalog uses
//! this before publishing a name; absence or failed observation is not success.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Declaration = @import("LogDeclaration.zig");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Guard = @import("PublicationGuard.zig");
pub const max_bytes = 8192;
const header_bytes = 40;

pub const Request = struct {
    definition: p.Growth.Definition,
    declared: Declaration.Stored,
    operation: d.Operation,
    ordinal: u32,
    partition: u64,

    pub fn validate(self: Request) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.declared.validate();
        try self.target().requireOperation(self.operation);
        if (self.partition == 0 or self.ordinal >= self.declared.declaration.configuration.partitioning.count or
            self.declared.retired or self.declared.declaration.interpretation.revision != 1) return error.InvalidLogInitialization;
    }

    pub fn target(self: Request) p.StreamQueue.Partition {
        return .{ .definition = self.definition, .interpretation = self.declared.declaration.interpretation, .partition = self.ordinal };
    }

    pub fn requireSame(self: Request, other: Request) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.LogInitializationConflict;
    }
};

pub const Evidence = struct { request: Request, accepted: d.Position, record: d.Content };

pub fn encode(request: Request, output: *[max_bytes]u8) ![]const u8 {
    try request.validate();
    output[0..8].* = "LINIT001".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(request, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn decode(allocator: std.mem.Allocator, frame: Log.Frame) !Evidence {
    const bytes = frame.payload;
    if (bytes.len <= header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], "LINIT001")) return error.InvalidLogInitialization;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Request, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidLogInitialization;
    if (frame.header.kind != .genesis or frame.header.lsn != 0 or frame.header.partition_id != parsed.value.partition or frame.header.writer_epoch == 0 or frame.header.policy_epoch == 0) return error.InvalidLogInitialization;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .request = parsed.value, .accepted = .{ .partition = parsed.value.partition, .next_lsn = 1 }, .record = .{ .bytes = bytes.len, .sha256 = digest } };
}

fn read(allocator: std.mem.Allocator, log: Log.Log, request: Request) !Evidence {
    var batch = try log.read(allocator, request.partition, 0, 1);
    defer batch.deinit();
    if (batch.frames.len != 1) return error.LogInitializationMissing;
    const evidence = try decode(allocator, batch.frames[0]);
    try request.requireSame(evidence.request);
    return evidence;
}

/// Verify the exact original initialization under current read authority. The
/// first WAL record must remain reachable until a qualified recovery owner
/// supplies equivalent retained evidence; a trimmed/missing frame rejects.
pub fn observe(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request, guard: Guard) !Evidence {
    try request.validate();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var declaration = try Declaration.load(allocator, objects, request.declared);
    defer declaration.deinit();
    const evidence = try read(allocator, log, request);
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return evidence;
}

/// Only an empty physical partition can accept this genesis. An uncertain
/// append retains this original Request and is resolved by observing/retrying
/// it, never by declaring a replacement identity or resetting existing data.
pub fn initialize(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request, guard: Guard) !Evidence {
    try request.validate();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    // Read the staged dependency, verifying its schema, policy and full digest
    // before making the partition visible to catalog publication.
    var declaration = try Declaration.load(allocator, objects, request.declared);
    defer declaration.deinit();
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(request, &buffer);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidWalEpoch;
    if (try log.tail(request.partition) != 0) return read(allocator, log, request);
    // The publication guard owns fencing. Native data adapters reject direct
    // fence installation because only native authority may advance those epochs.
    // Append checks the guarded epochs and the exact empty-partition expectation.
    const receipt = log.append(request.partition, 0, fence.writer_epoch, fence.policy_epoch, .genesis, bytes) catch |err| switch (err) {
        error.StaleWriterEpoch, error.StalePolicyEpoch => return err,
        error.WalLsnConflict => return read(allocator, log, request),
        else => return error.LogInitializationUncertain,
    };
    if (receipt.partition_id != request.partition or receipt.lsn != 0 or receipt.next_lsn != 1 or receipt.writer_epoch != fence.writer_epoch or receipt.policy_epoch != fence.policy_epoch) return error.LogInitializationUncertain;
    return read(allocator, log, request) catch return error.LogInitializationUncertain;
}

//! Fenced initial WAL acceptance with exact Document declaration readback (`DINIT001`).
//! Catalog uses this before publishing a name; absence or failed observation is not success.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Declaration = @import("DocumentDeclaration.zig");
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
        if (self.partition == 0 or
            self.ordinal >= self.declared.declaration.configuration.partitioning.count or
            self.declared.retired or
            self.declared.declaration.interpretation.revision != 1)
        {
            return error.InvalidDocumentInitialization;
        }
    }

    pub fn target(self: Request) p.DocumentOperation.Partition {
        return .{
            .definition = self.definition,
            .interpretation = self.declared.declaration.interpretation,
            .partition = self.ordinal,
        };
    }

    pub fn requireSame(self: Request, other: Request) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentInitializationConflict;
    }
};

pub const Evidence = struct {
    request: Request,
    accepted: d.Position,
    record: d.Content,
};

pub fn encode(request: Request, output: *[max_bytes]u8) ![]const u8 {
    try request.validate();
    output[0..8].* = "DINIT001".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(request, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn decode(allocator: std.mem.Allocator, frame: Log.Frame) !Evidence {
    const bytes = frame.payload;
    if (bytes.len <= header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], "DINIT001")) {
        return error.InvalidDocumentInitialization;
    }
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Request, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidDocumentInitialization;
    if (frame.header.kind != .genesis or
        frame.header.lsn != 0 or
        frame.header.partition_id != parsed.value.partition or
        frame.header.writer_epoch == 0 or
        frame.header.policy_epoch == 0)
    {
        return error.InvalidDocumentInitialization;
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{
        .request = parsed.value,
        .accepted = .{ .partition = parsed.value.partition, .next_lsn = 1 },
        .record = .{ .bytes = bytes.len, .sha256 = digest },
    };
}

pub fn readStored(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request) !Evidence {
    var batch = log.read(allocator, request.partition, 0, 1) catch |err| switch (err) {
        error.WalHistoryTrimmed => return retained(allocator, log, objects, request),
        else => return err,
    };
    defer batch.deinit();
    if (batch.frames.len != 1) return error.DocumentInitializationMissing;
    const evidence = try decode(allocator, batch.frames[0]);
    try request.requireSame(evidence.request);
    return evidence;
}

fn retained(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request) !Evidence {
    const Records = @import("DocumentPartitionRecord.zig");
    const Recovery = @import("DocumentRecovery.zig");
    const end = try log.tail(request.partition);
    if (end <= 1) return error.WalHistoryTrimmed;
    var latest = try log.read(allocator, request.partition, end - 1, 1);
    defer latest.deinit();
    if (latest.frames.len != 1) return error.DocumentRecoveryMissing;
    const record = (try Records.decode(allocator, latest.frames[0], request.partition, end - 1)).record;
    try request.requireSame(record.root.initialization);
    const reference = record.root.recovery orelse return error.WalHistoryTrimmed;
    const basis = try Recovery.load(allocator, objects, reference, end, request);
    var publication = try log.read(allocator, request.partition, reference.next_lsn, 1);
    defer publication.deinit();
    if (publication.frames.len != 1) return error.DocumentRecoveryMissing;
    try Recovery.requirePublication(basis, reference, (try Records.decode(allocator, publication.frames[0], request.partition, reference.next_lsn)).record);
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(request, &buffer);
    return .{
        .request = request,
        .accepted = .{ .partition = request.partition, .next_lsn = 1 },
        .record = .{ .bytes = bytes.len, .sha256 = @import("DocumentEvidence.zig").hash(bytes) },
    };
}

pub fn observe(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request, guard: Guard) !Evidence {
    try request.validate();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var declaration = try Declaration.load(allocator, objects, request.declared);
    defer declaration.deinit();
    const evidence = try readStored(allocator, log, objects, request);
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return evidence;
}

pub fn initialize(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Request, guard: Guard) !Evidence {
    try request.validate();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var declaration = try Declaration.load(allocator, objects, request.declared);
    defer declaration.deinit();
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(request, &buffer);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidWalEpoch;
    if (try log.tail(request.partition) != 0) return readStored(allocator, log, objects, request);
    const receipt = log.append(request.partition, 0, fence.writer_epoch, fence.policy_epoch, .genesis, bytes) catch |err| switch (err) {
        error.StaleWriterEpoch, error.StalePolicyEpoch => return err,
        error.WalLsnConflict => return readStored(allocator, log, objects, request),
        else => return error.DocumentInitializationUncertain,
    };
    if (receipt.lsn != 0 or receipt.next_lsn != 1) return error.InvalidDocumentInitialization;
    return readStored(allocator, log, objects, request);
}

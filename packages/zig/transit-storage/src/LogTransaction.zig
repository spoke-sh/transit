//! Retained log transaction cuts and immutable preparation references. A staged
//! source is private until its partition WAL publishes a live pin. Neither its
//! content address nor its original transaction identity grants access.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const x = p.Transaction;
const r = @import("LogPartitionRecord.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
pub const max_bytes = 64 * 1024;
pub const Reference = struct {
    content: d.Content,
    pub fn validate(self: Reference) !void {
        try self.content.validate();
        if (self.content.bytes <= 40 or self.content.bytes > max_bytes) return error.InvalidLogTransaction;
    }
};
pub const Source = struct {
    definition: p.Growth.Definition,
    identity: x.Identity,
    root: r.Root,
    pub fn validate(self: Source) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        try self.root.validate();
        try self.identity.requireObject(self.root.declared.declaration.interpretation.object);
        if (self.root.declared.retired or self.root.transaction != null or self.root.transaction_pins != null) return error.InvalidLogTransaction;
    }
    pub fn guard(self: Source) !x.LogGuard {
        try self.validate();
        return logGuard(self.root);
    }
};
pub const Pin = struct {
    source: d.Content,
    released: bool,
    pub fn encode(self: Pin) !pages.Value {
        try (Reference{ .content = self.source }).validate();
        var bytes: [41]u8 = undefined;
        bytes[0] = @intFromBool(self.released);
        std.mem.writeInt(u64, bytes[1..9], self.source.bytes, .big);
        bytes[9..41].* = self.source.sha256;
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Pin {
        if (value.len != 41 or value.data[0] > 1) return error.InvalidLogTransaction;
        const result: Pin = .{ .source = .{ .bytes = std.mem.readInt(u64, value.data[1..9], .big), .sha256 = value.data[9..41].* }, .released = value.data[0] == 1 };
        try (Reference{ .content = result.source }).validate();
        return result;
    }
};
/// Admission bounds for private construction, separate from the host's borrowed
/// partition slabs and provider buffers. No evaluated root is accepted work.
pub const EvaluationLimits = struct {
    actions: u64,
    payload_bytes: u64,
    resident_bytes: usize,
    last_statement: u64,
    pub fn validate(self: EvaluationLimits) !void {
        if (self.actions == 0 or self.payload_bytes == 0 or self.resident_bytes == 0 or self.last_statement == 0) return error.InvalidTransactionLimits;
    }
};
pub const Evaluation = struct {
    root: r.Root,
    observed: ?@import("LogTime.zig").Sample,
    resident_peak: usize,
};
/// Transient output from prepared-owner validation. The host retains these
/// bounded fields until its final under-guard check; they grant no authority.
pub const DecisionTime = struct {
    reference: Reference,
    floor_ms: ?u64,
    lease_expires_ms: ?u64 = null,
    append_expires_ms: ?u64 = null,
};
pub const FixedTime = struct {
    value: @import("LogTime.zig").Sample,
    pub fn source(self: *FixedTime) @import("LogTime.zig").Source {
        return .{ .context = self, .read = read };
    }
    fn read(raw: *anyopaque) !?@import("LogTime.zig").Sample {
        const self: *FixedTime = @ptrCast(@alignCast(raw));
        return self.value;
    }
};
pub const PinState = struct { handle: ?x.Pin, released: bool, position: d.Position };

pub fn logGuard(root: r.Root) !x.LogGuard {
    try root.validate();
    return .{ .kind = if (root.declared.declaration.configuration.policy == .stream) .stream else .queue, .source = try root.retainedCut(root.declared), .changed_lsn = root.changed_lsn };
}
pub fn sourceKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try (Reference{ .content = content }).validate();
    return std.fmt.bufPrint(output, "log-tx-sources/{x}.data", .{&content.sha256});
}
fn encodeSource(value: Source, output: *[max_bytes]u8) ![]const u8 {
    try value.validate();
    output[0..8].* = "TXLSRC1\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. 40 + writer.end];
}
pub fn stageSource(objects: Objects.ObjectStore, source: Source) !x.Pin {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encodeSource(source, &buffer);
    const content = @import("LogBatch.zig").content(bytes);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try sourceKey(content, &name), bytes, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidLogTransaction;
    return .{ .owner = source.identity.begin, .content = content };
}
pub fn loadSource(objects: Objects.ObjectStore, handle: x.Pin) !Source {
    try handle.owner.validate();
    var name: [96]u8 = undefined;
    const path = try sourceKey(handle.content, &name);
    const metadata = try objects.head(path) orelse return error.LogTransactionSourceMissing;
    if (metadata.size != handle.content.bytes or !std.mem.eql(u8, &metadata.sha256, &handle.content.sha256)) return error.InvalidLogTransaction;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(path, 0, @intCast(handle.content.bytes), &buffer);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), handle.content) or !std.mem.eql(u8, bytes[0..8], "TXLSRC1\x00")) return error.InvalidLogTransaction;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const source = std.json.parseFromSliceLeaky(Source, fixed.allocator(), bytes[40..], .{}) catch |err| return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    try source.validate();
    if (!std.meta.eql(source.identity.begin, handle.owner)) return error.TransactionIdentityConflict;
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encodeSource(source, &canonical))) return error.InvalidLogTransaction;
    return source;
}

/// The WAL barrier accepts this exact immutable successor. A descriptor alone
/// grants neither visibility nor authority to settle a lease or input offset.
pub const Preparation = struct {
    definition: p.Growth.Definition,
    coordination: u64,
    binding: @import("TransactionDecisionLog.zig").Binding,
    guard: x.LogGuard,
    source: x.Pin,
    actions: x.Directory,
    predecessor: r.Root,
    successor: r.Root,
    observed: ?@import("LogTime.zig").Sample,

    pub fn validate(self: Preparation) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.binding.validate();
        try self.guard.validate();
        try self.predecessor.validate();
        try self.successor.validate();
        try self.actions.validate();
        try (Reference{ .content = self.source.content }).validate();
        try self.guard.requireUnchanged(try logGuard(self.predecessor));
        if (!std.meta.eql(self.source.owner, self.binding.begin.identity.begin) or self.actions.count == 0 or
            self.predecessor.transaction != null or self.predecessor.declared.retired or self.predecessor.transaction_pins == null or
            self.coordination == 0 or self.coordination == self.predecessor.initialization.partition or self.coordination == self.binding.begin.catalog.partition or
            self.successor.next_offset < self.predecessor.next_offset or self.successor.sealed_through < self.predecessor.sealed_through) return error.InvalidLogPreparation;
        try self.binding.begin.identity.requireObject(self.predecessor.declared.declaration.interpretation.object);
        if (self.observed) |observed| {
            try observed.validate();
            if (observed.latest_ms < (self.predecessor.clock_ms orelse 0) or
                (!std.meta.eql(self.successor.clock_ms, self.predecessor.clock_ms) and self.successor.clock_ms != observed.latest_ms)) return error.InvalidLogPreparation;
        } else if (self.predecessor.clock_ms != null or self.successor.clock_ms != null) return error.InvalidLogPreparation;
        var expected = self.predecessor;
        expected.next_lsn = try std.math.add(u64, expected.next_lsn, 1);
        expected.changed_lsn = expected.next_lsn;
        expected.maintenance.archive_source_lsn = expected.next_lsn;
        if (self.guard.kind == .stream) expected.maintenance.compaction_source_lsn = expected.next_lsn;
        expected.next_offset = self.successor.next_offset;
        expected.clock_ms = self.successor.clock_ms;
        expected.batches = self.successor.batches;
        expected.segments = self.successor.segments;
        expected.sealed_through = self.successor.sealed_through;
        expected.receipts = self.successor.receipts;
        expected.producers = self.successor.producers;
        expected.producer_receipts = self.successor.producer_receipts;
        expected.groups = self.successor.groups;
        expected.group_offsets = self.successor.group_offsets;
        expected.queue = self.successor.queue;
        if (!std.meta.eql(expected, self.successor)) return error.InvalidLogPreparation;
    }

    pub fn prepared(self: Preparation, reference: Reference) !x.Prepared {
        try self.validate();
        try reference.validate();
        return .{ .attempt = self.binding.attempt, .target = (x.Guard{ .log = self.guard }).target(), .predecessor = .{ .log = self.guard }, .position = self.successor.position(), .successor = reference.content };
    }
};

pub fn preparationKey(reference: Reference, output: *[96]u8) ![]const u8 {
    try reference.validate();
    return std.fmt.bufPrint(output, "log-preparations/{x}.data", .{&reference.content.sha256});
}
fn encodePreparation(value: Preparation, output: *[max_bytes]u8) ![]const u8 {
    try value.validate();
    output[0..8].* = "TLPREP1\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. 40 + writer.end];
}
pub fn stagePreparation(objects: Objects.ObjectStore, value: Preparation) !Reference {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encodePreparation(value, &buffer);
    const reference: Reference = .{ .content = @import("LogBatch.zig").content(bytes) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try preparationKey(reference, &name), bytes, reference.content.sha256);
    if (stored.size != reference.content.bytes or !std.mem.eql(u8, &stored.sha256, &reference.content.sha256)) return error.InvalidLogPreparation;
    return reference;
}
pub fn loadPreparation(objects: Objects.ObjectStore, reference: Reference) !Preparation {
    var name: [96]u8 = undefined;
    const path = try preparationKey(reference, &name);
    const meta = try objects.head(path) orelse return error.LogPreparationMissing;
    if (meta.size != reference.content.bytes or !std.mem.eql(u8, &meta.sha256, &reference.content.sha256)) return error.InvalidLogPreparation;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(path, 0, @intCast(reference.content.bytes), &buffer);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), reference.content) or !std.mem.eql(u8, bytes[0..8], "TLPREP1\x00")) return error.InvalidLogPreparation;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const value = std.json.parseFromSliceLeaky(Preparation, fixed.allocator(), bytes[40..], .{}) catch |err| return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    try value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encodePreparation(value, &canonical))) return error.InvalidLogPreparation;
    return value;
}

/// Reopen the actual frozen journal and verify membership in its committed
/// preparation directory. A caller-supplied decision is never sufficient.
pub fn decision(allocator: std.mem.Allocator, log: @import("TransitLog.zig").Log, objects: Objects.ObjectStore, value: Preparation, reference: Reference) !?x.Decision {
    var journal = try @import("TransactionDecisionLog.zig").init(allocator, log, objects, value.coordination, value.binding);
    try journal.recover();
    const outcome = journal.decision orelse return null;
    if (outcome.outcome == .committed) {
        var prepared = try @import("TransactionDirectory.zig").init(allocator, objects, value.binding.begin.identity, .preparations, value.binding.begin.limits.participants, 1, 1024 * 1024);
        defer prepared.deinit();
        try prepared.restore(outcome.prepared);
        const entry = try prepared.get((x.Guard{ .log = value.guard }).target()) orelse return error.InvalidLogPreparation;
        if (!std.meta.eql(entry.prepared, try value.prepared(reference))) return error.InvalidLogPreparation;
    }
    return outcome;
}

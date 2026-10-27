//! Independent direct Table cuts with native computation progress. Immutable
//! pin evidence survives closure; every native publication carries current guards.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Pin = q.CapturedTablePin;
const Self = @This();
turn: *q.station.Turn,
allocator: std.mem.Allocator,
bundle: q.RelationalBundle,
job: u64,
vector: Vector,
clients: []const c.DirectTableClient,
bases: [r.max_sources]c.DirectTableReader.Basis = undefined,
cuts: [r.max_sources]r.Cut = undefined,
reads: u64 = 0,
read_limit: u64,
pub const resident_bytes = @sizeOf(Self) + 2 * f.TableRow.max_bytes + 2 * f.TableSchema.max_bytes;

/// Fixed-size commitments fit one native value. Full handles, interpretations
/// and source authority remain in each computation-owned pin record.
pub const Entry = struct { partition: u64, position: u64, commitment: [32]u8 };
pub const Vector = struct {
    request: [32]u8,
    count: u8,
    entries: [r.max_sources]Entry = undefined,
    pub fn validate(self: Vector, bundle: q.RelationalBundle) !void {
        try bundle.validate();
        if (bundle.plan.lifetime != .captured) return error.InvalidRelationalCapture;
        if (self.count != bundle.sources.len or !std.mem.eql(u8, &self.request, &try bundle.fingerprint())) return error.RelationalSourceChanged;
        for (self.entries[0..self.count], 0..) |entry, i| {
            try (p.DataLifecycle.Position{ .partition = entry.partition, .next_lsn = entry.position }).validate();
            if (entry.position == 0 or std.mem.allEqual(u8, &entry.commitment, 0)) return error.InvalidRelationalCapture;
            const original = try bundle.sourceOrdinal(i);
            if (original != i and !std.meta.eql(entry, self.entries[original])) return error.InconsistentRelationalCut;
        }
    }
    pub fn encode(self: Vector, bundle: q.RelationalBundle) !p.Value {
        try self.validate(bundle);
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("RQV1");
        try writer.writeAll(&p.Growth.definition_bytes);
        try writer.writeAll(&self.request);
        try writer.writeByte(self.count);
        for (self.entries[0..self.count]) |entry| {
            try writer.writeInt(u64, entry.partition, .little);
            try writer.writeInt(u64, entry.position, .little);
            try writer.writeAll(&entry.commitment);
        }
        return p.Value.init(writer.buffered());
    }
    pub fn decode(bundle: q.RelationalBundle, value: p.Value) !Vector {
        const result = try decodeStored(value);
        if (!(try result.encode(bundle)).eql(value)) return error.InvalidRelationalCapture;
        return result;
    }
    pub fn decodeStored(value: p.Value) !Vector {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "RQV1")) return error.InvalidRelationalCapture;
        if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var result: Vector = .{ .request = (try reader.takeArray(32)).*, .count = try reader.takeByte() };
        if (result.count == 0 or result.count > r.max_sources) return error.InvalidRelationalCapture;
        for (result.entries[0..result.count]) |*entry| {
            entry.* = .{ .partition = try reader.takeInt(u64, .little), .position = try reader.takeInt(u64, .little), .commitment = (try reader.takeArray(32)).* };
            try (p.DataLifecycle.Position{ .partition = entry.partition, .next_lsn = entry.position }).validate();
            if (entry.position == 0 or std.mem.allEqual(u8, &entry.commitment, 0)) return error.InvalidRelationalCapture;
        }
        if (reader.bufferedLen() != 0) return error.InvalidRelationalCapture;
        return result;
    }
    pub fn boundCuts(self: Vector, bundle: q.RelationalBundle, output: *[r.max_sources]r.Cut) !void {
        try self.validate(bundle);
        for (self.entries[0..self.count], bundle.sources, bundle.plan.sources, 0..) |entry, source, declared, i| output[i] = .{
            .domain = .{ .table_partition = .{ .branch = source.branch, .object = source.object, .partition = entry.partition } },
            .resource = source.scope.resource,
            .revision = entry.position,
            .commitment = entry.commitment,
            .schema = try declared.schema.fingerprint(),
        };
        try (r.Bound{ .plan = bundle.plan, .cuts = output[0..self.count] }).validate();
    }
};
pub fn slot(bundle: q.RelationalBundle, job: u64, ordinal: usize) !Pin.Slot {
    return .{ .job = job, .source = try bundle.sourceOrdinal(ordinal) };
}
fn basisEntry(basis: c.DirectTableReader.Basis) !Entry {
    return .{ .partition = basis.accepted.partition, .position = basis.accepted.next_lsn, .commitment = try basis.fingerprint() };
}
/// Only committed handle records can establish the full source vector. Aliases
/// read the same immutable pin evidence, regardless of their catalog resource.
pub fn record(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, job: u64) !Vector {
    var vector: Vector = .{ .request = try bundle.fingerprint(), .count = @intCast(bundle.sources.len) };
    var current = turn.committed();
    for (bundle.sources, bundle.plan.sources, 0..) |source, declared, i| {
        const basis = try Pin.source(allocator, &current, try slot(bundle, job, i), turn.delivery.pid);
        _ = try source.basis(basis, declared.schema);
        vector.entries[i] = try basisEntry(basis);
    }
    try vector.validate(bundle);
    return vector;
}
/// Configured executor routes borrow the host; no caller credentials are
/// impersonated. Pin records supply the original signed grants for direct reads.
pub fn open(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, job: u64, vector: Vector, clients: []const c.DirectTableClient, read_limit: u64) !Self {
    try vector.validate(bundle);
    if (read_limit == 0) return error.InvalidQueryBudget;
    if (clients.len != bundle.sources.len) return error.InvalidRelationalSources;
    if (bundle.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    var self: Self = .{ .turn = turn, .allocator = allocator, .bundle = bundle, .job = job, .vector = vector, .clients = clients, .read_limit = read_limit };
    try vector.boundCuts(bundle, &self.cuts);
    var current = turn.committed();
    for (bundle.sources, bundle.plan.sources, 0..) |source, declared, i| {
        self.bases[i] = try Pin.source(allocator, &current, try slot(bundle, job, i), turn.delivery.pid);
        _ = try source.basis(self.bases[i], declared.schema);
        if (!std.meta.eql(try basisEntry(self.bases[i]), vector.entries[i])) return error.RelationalSourceChanged;
    }
    try self.validate(self.bound());
    return self;
}
pub fn bound(self: *const Self) r.Bound {
    return .{ .plan = self.bundle.plan, .cuts = self.cuts[0..self.vector.count] };
}
pub fn validate(self: *Self, expected: r.Bound) !void {
    if (!std.mem.eql(u8, &try expected.fingerprint(), &try self.bound().fingerprint())) return error.RelationalSourceChanged;
    for (0..self.vector.count) |i| if (try self.bundle.sourceOrdinal(i) == i) {
        try Pin.authorizeExecution(self.allocator, self.turn, try slot(self.bundle, self.job, i));
    };
}
pub fn next(self: *Self, ordinal: u8, after: ?r.RowIdentity) !?e.Row {
    if (ordinal >= self.vector.count) return error.InvalidRelationalSources;
    if (self.reads == self.read_limit) return error.RelationalWorkBudget;
    self.reads += 1;
    try self.validate(self.bound());
    const client = try Pin.readClient(self.allocator, self.turn, try slot(self.bundle, self.job, ordinal), self.clients[ordinal]);
    var reader = c.DirectTableReader.open(self.allocator, client, self.bases[ordinal].snapshot) catch |err| return Pin.readFailure(client, err);
    defer reader.deinit();
    if (!std.meta.eql(reader.basis, self.bases[ordinal])) return error.RelationalSourceChanged;
    var batch = reader.readAfter(client, after, .{ .rows = 1 }) catch |err| return Pin.readFailure(client, err);
    defer batch.deinit();
    try self.validate(self.bound());
    if (batch.count == 0) return null;
    const owned = batch.rows[0].?;
    return try e.Row.fromCells(self.allocator, owned.identity, self.bundle.plan.sources[ordinal].schema.columns, owned.row().cells);
}

test {
    _ = @import("relational_captured_test.zig");
}

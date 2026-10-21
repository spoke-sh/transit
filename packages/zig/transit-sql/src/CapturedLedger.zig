//! Fenced publication and sequencing for captured query callers. Compiled
//! bundles and signed submissions live in paged native storage. A source lane
//! cannot prepare a successor until its published input is observed processed.
const std = @import("std");
const g = @import("root.zig");
const r = g.LedgerRecords;
const ops = g.SessionOperations;
const s = g.station;
const p = g.catalog.protocol;
const Pub = s.Publication;
pub const State = struct {
    pub const magic = "GSC1";
    records: u64 = 0,
    staging: u64 = 0,
    pending: u64 = 0,
    input: u64 = 0,
    stored: u64 = 0,
    cancel: u8 = 0,
    rejected: u8 = 0,
    pub fn validate(self: State) !void {
        if (self.records > 1024 or self.staging > self.records or self.pending > self.records or (self.pending != 0 and (self.pending == 1 or self.staging != 0)) or (self.pending == 0 and self.input != 0) or self.cancel > 1 or self.rejected > 1) return error.InvalidCapturedQueryState;
    }
};
const Lane = struct {
    pub const magic = "GCL1";
    operation: u64,
    pub fn validate(self: Lane) !void {
        if (self.operation == 0 or self.operation > p.max_counter) return error.InvalidCapturedQueryState;
    }
};
pub const Command = union(enum(u8)) {
    begin: struct { target: g.Control.Record, spec: Pub.Spec } = 1,
    part: struct { target: g.Control.Record, part: g.Control.Part } = 2,
    publish: g.Control.Record = 3,
    receipt: struct { target: g.Control.Record, input: u64 } = 4,
    processed: struct { target: g.Control.Record, rejected: u8 } = 5,
    abandon: g.Control.Record = 6,
    cancel: g.Control.Qualified = 7,
};
fn laneKey(source: [32]u8) p.Value {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("sql-query-lane:" ++ source, &digest, .{});
    return p.Value.init(&digest) catch unreachable;
}
pub fn state(ledger: g.Ledger, reader: anytype, id: u64) !State {
    const item = try ops.external(ledger, reader, id);
    if (item.kind != .captured) return error.InvalidSqlOperationReference;
    return if (try reader.read(r.key('k', id, 0))) |bytes| try r.decode(State, bytes) else .{};
}
fn save(turn: *s.Turn, id: u64, value: State) !void {
    try turn.write(r.key('k', id, 0), try r.encode(value));
}
pub fn lane(reader: anytype, source: [32]u8) !?u64 {
    return if (try reader.read(laneKey(source))) |value| (try r.decode(Lane, value)).operation else null;
}
pub fn apply(ledger: g.Ledger, turn: *s.Turn, command: Command) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const target: g.Control.Record = switch (command) {
        .begin => |v| v.target,
        .part => |v| v.target,
        .receipt => |v| v.target,
        .processed => |v| v.target,
        .cancel => |v| .{ .operation = v.operation, .generation = v.generation, .record = 0 },
        inline else => |v| v,
    };
    try ledger.actor(turn, .ingress, target.generation);
    const id = target.operation;
    var item = try ops.external(ledger, turn, id);
    if (item.kind != .captured) return error.InvalidSqlOperationReference;
    var value = try state(ledger, turn, id);
    const publication = ledger.publication(id);
    if (command == .cancel) {
        if (item.phase == .terminal or value.cancel == 1) return;
        value.cancel = 1;
        if (item.phase == .reserved and value.staging == 1) {
            _ = try publication.abandon(turn, 1);
            value.staging = 0;
        }
        return save(turn, id, value);
    }
    if (item.phase == .terminal) return error.CapturedQueryComplete;
    const record = target.record;
    switch (command) {
        .begin => |input| {
            if (record == 1 and value.cancel == 1) return error.CapturedQueryComplete;
            if (value.staging == record and record != 0) {
                if (!std.meta.eql((try publication.inspect(turn, record)).spec, input.spec)) return error.GatewayUploadConflict;
                return;
            }
            if (record != value.records + 1 or record > 1024 or value.pending != 0 or value.staging != 0) return error.GatewayUnresolvedStep;
            if (record == 1) {
                if (item.phase != .reserved or input.spec.format != g.query.Bundle.format or input.spec.length > g.query.Bundle.max_bytes) return error.InvalidQueryBundle;
                _ = try Pub.create(turn, .sql_gateway, id, .{ .record_bytes = @max(g.query.Bundle.max_bytes, g.query.SavedSubmission.max_bytes), .staging_bytes = @max(g.query.Bundle.max_bytes, g.query.SavedSubmission.max_bytes), .staging_records = 1 });
            } else {
                if (item.phase != .ready or value.rejected != 0 or input.spec.format != g.query.SavedSubmission.format or input.spec.length > g.query.SavedSubmission.max_bytes) return error.InvalidSavedQuerySubmission;
                if (try lane(turn, item.source)) |owner| if (owner != id) return error.SqlSourceBusy;
                try turn.write(laneKey(item.source), try r.encode(Lane{ .operation = id }));
            }
            if (value.stored + input.spec.length + 512 > item.reservation) return error.GatewayRecoveryCapacity;
            _ = try publication.begin(turn, record, input.spec);
            value.records = record;
            value.staging = record;
            value.stored += input.spec.length;
            try save(turn, id, value);
        },
        .part => |input| {
            if (value.staging != record) return error.GatewayUploadClosed;
            try input.part.validate();
            _ = try g.Upload.append(publication, turn, record, input.part.offset, input.part.bytes[0..input.part.length]);
        },
        .publish => {
            if ((record == 1 and item.phase == .ready) or (record > 1 and value.pending == record)) return;
            if (value.staging != record or record == 0) return error.GatewayUnresolvedStep;
            try g.Upload.seal(publication, turn, record);
            value.staging = 0;
            if (record == 1) {
                const spec = (try publication.inspect(turn, record)).spec;
                item.phase = .ready;
                item.length = spec.length;
                item.digest = spec.digest;
                try turn.write(r.key('o', id, 0), try r.encode(item));
            } else value.pending = record;
            try save(turn, id, value);
        },
        .receipt => |input| {
            if (record == 0 or value.pending != record or input.input == 0 or input.input > p.max_counter) return error.InvalidCapturedQueryReceipt;
            if (value.input != 0 and value.input != input.input) return error.InvalidCapturedQueryReceipt;
            value.input = input.input;
            try save(turn, id, value);
        },
        .processed => |input| {
            if (record == 0 or value.pending != record or value.input == 0 or input.rejected > 1) return error.InvalidCapturedQueryReceipt;
            if (try lane(turn, item.source) != id) return error.SqlSourceBusy;
            value.pending = 0;
            value.input = 0;
            value.rejected = input.rejected;
            try save(turn, id, value);
            try turn.write(laneKey(item.source), null);
        },
        .abandon => {
            // Only a never-published proposal can be replaced. Frozen bundle
            // record 1 and all published native requests remain immutable.
            if (record <= 1 or value.staging != record or value.pending != 0) return error.GatewayUnresolvedStep;
            _ = try publication.abandon(turn, record);
            value.staging = 0;
            try save(turn, id, value);
            try turn.write(laneKey(item.source), null);
        },
        .cancel => unreachable,
    }
}

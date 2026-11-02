//! Original-operation acquisition and retention state for selected catalog cuts.
//! A selection is immutable input; only the catalog can publish its retained cut.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const H = c.DirectHistoryDirectory;
const w = c.DirectTableProtocol;
const P = c.storage.TablePartition;
pub const Selector = @import("DirectHistorySelector.zig");
pub const format: u32 = 0x48495331;
pub const max_bytes = 8192;

pub const Common = struct {
    key: c.DirectClientToken.Key,
    cut: d.CommonCut,
    pub fn validate(self: Common, connection: w.Connection, selection: H.Reference) !void {
        try self.key.validate();
        try self.cut.validate();
        if (!std.meta.eql(self.key.connection, connection) or selection.count > self.cut.source_count or selection.descriptors != 0 or
            !std.meta.eql(self.cut.transaction.scope, connection.scope) or
            self.cut.transaction.principal != connection.principal) return error.HistoricalIdentityConflict;
    }
};

pub const Intent = struct {
    connection: w.Connection,
    namespace: u64,
    operation: u64,
    selection: H.Reference,
    common: ?Common,
    pub fn identity(self: Intent) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }
    pub fn validate(self: Intent) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.identity().validate();
        var key: [96]u8 = undefined;
        _ = try H.objectKey(self.selection.content, &key);
        if (try self.selection.total() == 0) return error.EmptyHistoricalSelection;
        if (self.common) |common| {
            try common.validate(self.connection, self.selection);
            if (std.meta.eql(self.identity(), common.cut.transaction)) return error.HistoricalIdentityConflict;
        }
    }
    pub fn selectionOwner(self: Intent) d.Operation {
        return if (self.common) |common| common.cut.transaction else self.identity();
    }
    pub fn selectionKind(self: Intent) H.Kind {
        return if (self.common != null) .retained else .selection;
    }
    pub fn digest(self: Intent) ![32]u8 {
        try self.validate();
        var bytes: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.history.v1\x00");
        hash.update(writer.buffered());
        return hash.finalResult();
    }
};

/// Acquisition outcome and retained availability are separate. Published,
/// releasing and released all preserve the original successful acquisition.
pub const Phase = enum { acquiring, verifying, published, abandoning, cancelled, releasing, released };
pub const State = struct {
    definition: p.Growth.Definition,
    phase: Phase,
    retained: ?H.Reference,
    after: ?u64,
    /// Persisted before pin acquisition. A missing pin reply resumes only this
    /// source; a pin that predates this intent is never adopted.
    inflight: ?u64,
    verified_after: ?u64,
    descriptor_after: ?u64,
    descriptors_verified: u64,
    policy_epoch: ?u64,
    released_after: ?u64,
    snapshot: ?d.Snapshot,

    pub fn pending(self: State) bool {
        return self.phase == .acquiring or self.phase == .verifying or self.phase == .abandoning;
    }
    pub fn cancelled(self: State) bool {
        return self.phase == .abandoning or self.phase == .cancelled;
    }
    pub fn initial() State {
        return .{ .definition = p.Growth.current_definition, .phase = .acquiring, .retained = null, .after = null, .inflight = null, .verified_after = null, .descriptor_after = null, .descriptors_verified = 0, .policy_epoch = null, .released_after = null, .snapshot = null };
    }
    pub fn validate(self: State, progress: c.DirectClientToken.Progress) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (progress.receipt.binding.intent != .history or progress.pending != self.pending() or progress.cancel != self.cancelled()) return error.InvalidHistoricalState;
        const intent = progress.receipt.binding.intent.history;
        if ((self.snapshot != null) != (self.phase == .published or self.phase == .releasing or self.phase == .released)) return error.InvalidHistoricalState;
        if (self.after) |after| if (after == 0) return error.InvalidHistoricalState;
        if (self.inflight) |object| {
            if (object == 0 or object <= (self.after orelse 0) or (self.phase != .acquiring and self.phase != .abandoning)) return error.InvalidHistoricalState;
        }
        const count: u64 = if (self.retained) |retained| blk: {
            var key: [96]u8 = undefined;
            _ = try H.objectKey(retained.content, &key);
            if (retained.descriptors != 0 or retained.count > intent.selection.count or (retained.count == 0 and intent.selection.count != 0)) return error.InvalidHistoricalState;
            break :blk retained.count;
        } else 0;
        if ((count == 0) != (self.after == null)) return error.InvalidHistoricalState;
        if ((self.phase == .verifying or self.snapshot != null) and (self.retained == null or count != intent.selection.count)) return error.InvalidHistoricalState;
        if (self.verified_after) |object| if (object == 0 or object > (self.after orelse 0) or self.policy_epoch == null) return error.InvalidHistoricalState;
        if ((self.descriptor_after == null) != (self.descriptors_verified == 0) or self.descriptors_verified > intent.selection.descriptors) return error.InvalidHistoricalState;
        if (self.descriptor_after) |object| if (object == 0 or self.verified_after != self.after or self.policy_epoch == null) return error.InvalidHistoricalState;
        if (self.policy_epoch) |epoch| if (epoch == 0) return error.InvalidHistoricalState;
        if (self.phase == .acquiring and (self.verified_after != null or self.policy_epoch != null or self.descriptor_after != null)) return error.InvalidHistoricalState;
        if (self.released_after) |object| {
            if (object == 0 or object > (self.after orelse 0) or (self.phase != .abandoning and self.phase != .cancelled and self.phase != .releasing and self.phase != .released)) return error.InvalidHistoricalState;
        }
        if (self.snapshot) |snapshot| {
            try snapshot.validate();
            if (snapshot.definition != p.Growth.current_definition or !std.meta.eql(snapshot.owner, intent.identity()) or snapshot.branch != intent.connection.branch or
                !std.meta.eql(snapshot.catalog_root, intent.selection.content) or !std.meta.eql(snapshot.sources_root, self.retained.?.content) or snapshot.source_count != count or
                self.inflight != null or self.verified_after != self.after or self.policy_epoch == null or self.descriptors_verified != intent.selection.descriptors) return error.InvalidHistoricalState;
            if (intent.common) |common| {
                if (snapshot.consistency != .common_transaction or !std.meta.eql(snapshot.consistency.common_transaction, common.cut)) return error.InvalidHistoricalState;
            } else if (snapshot.consistency == .common_transaction or (snapshot.consistency == .single_partition) != (count == 1)) return error.InvalidHistoricalState;
        }
        if (self.phase == .cancelled and (self.inflight != null or self.released_after != self.after)) return error.InvalidHistoricalState;
        if (self.phase == .released and self.released_after != self.after) return error.InvalidHistoricalState;
    }
    pub fn stage(self: State, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !c.DirectRecord.Reference {
        try self.validate(progress);
        var bytes: [max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        return c.DirectRecord.store(objects, progress.receipt.binding.key.scope(), format, writer.buffered());
    }
    /// Validate bounded control progress independently of the live owner. The
    /// acquisition owner must also verify the actual selected entry and pin.
    pub fn transition(before: State, after: State) !void {
        var expected = before;
        switch (before.phase) {
            .acquiring => switch (after.phase) {
                .abandoning => expected.phase = .abandoning,
                .verifying => {
                    if (before.inflight != null) return error.InvalidHistoricalTransition;
                    expected.phase = .verifying;
                    if (before.retained == null) {
                        if (after.retained == null or after.retained.?.count != 0 or after.retained.?.descriptors != 0) return error.InvalidHistoricalTransition;
                        expected.retained = after.retained;
                    }
                },
                .acquiring => {
                    if (before.inflight) |object| {
                        const count = if (before.retained) |retained| retained.count else 0;
                        if (after.inflight != null or after.after != object or after.retained == null or after.retained.?.count != try std.math.add(u64, count, 1)) return error.InvalidHistoricalTransition;
                        expected.after = object;
                        expected.inflight = null;
                        expected.retained = after.retained;
                    } else {
                        if (after.inflight == null or after.inflight.? <= (before.after orelse 0)) return error.InvalidHistoricalTransition;
                        expected.inflight = after.inflight;
                    }
                },
                else => return error.InvalidHistoricalTransition,
            },
            .verifying => switch (after.phase) {
                .abandoning => expected.phase = .abandoning,
                .published => {
                    if (after.snapshot == null or before.verified_after != before.after) return error.InvalidHistoricalTransition;
                    expected.phase = .published;
                    expected.snapshot = after.snapshot;
                },
                .verifying => {
                    if (after.policy_epoch == null) {
                        if ((before.verified_after == null and before.descriptor_after == null) or after.verified_after != null or after.descriptor_after != null or after.descriptors_verified != 0) return error.InvalidHistoricalTransition;
                    } else {
                        if (before.policy_epoch != null and before.policy_epoch != after.policy_epoch) return error.InvalidHistoricalTransition;
                        if (after.verified_after != before.verified_after) {
                            if (after.verified_after == null or after.verified_after.? <= (before.verified_after orelse 0) or after.descriptor_after != before.descriptor_after or after.descriptors_verified != before.descriptors_verified) return error.InvalidHistoricalTransition;
                        } else {
                            if (before.verified_after != before.after or after.descriptor_after == null or after.descriptor_after.? <= (before.descriptor_after orelse 0) or after.descriptors_verified != try std.math.add(u64, before.descriptors_verified, 1)) return error.InvalidHistoricalTransition;
                        }
                    }
                    expected.verified_after = after.verified_after;
                    expected.descriptor_after = after.descriptor_after;
                    expected.descriptors_verified = after.descriptors_verified;
                    expected.policy_epoch = after.policy_epoch;
                },
                else => return error.InvalidHistoricalTransition,
            },
            .published => {
                if (after.phase != .releasing) return error.InvalidHistoricalTransition;
                expected.phase = .releasing;
            },
            .abandoning, .releasing => {
                const final: Phase = if (before.phase == .abandoning) .cancelled else .released;
                if (after.phase != before.phase and after.phase != final) return error.InvalidHistoricalTransition;
                if (before.inflight != null) {
                    if (after.inflight != null or after.phase != before.phase) return error.InvalidHistoricalTransition;
                    expected.inflight = null;
                } else if (after.phase == final) {
                    if (before.released_after != before.after) return error.InvalidHistoricalTransition;
                    expected.phase = final;
                } else {
                    if (after.released_after == null or after.released_after.? <= (before.released_after orelse 0) or after.released_after.? > (before.after orelse 0)) return error.InvalidHistoricalTransition;
                    expected.released_after = after.released_after;
                }
            },
            .cancelled, .released => return error.InvalidHistoricalTransition,
        }
        if (!std.meta.eql(expected, after)) return error.InvalidHistoricalTransition;
    }
    pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !State {
        try progress.validate();
        const reference = progress.record orelse {
            const value = initial();
            try value.validate(progress);
            return value;
        };
        if (reference.format != format or reference.content.bytes > max_bytes) return error.InvalidHistoricalState;
        const bytes = try c.DirectRecord.load(allocator, objects, reference);
        defer allocator.free(bytes);
        const parsed = try p.Json.parseFromSlice(State, allocator, bytes);
        defer parsed.deinit();
        try parsed.value.validate(progress);
        return parsed.value;
    }
};
pub const Status = struct { receipt: c.DirectClientToken.Receipt, revision: d.Position, state: State };
pub const Selection = struct { owner: d.Operation, branch: u64, directory: ?H.Reference };
pub const Source = struct {
    snapshot: d.Snapshot,
    binding: H.Entry,
    schema: w.Binary,
    rows: u64,
    changed_lsn: u64,
    authority: c.DirectReadAuthority,
    pub fn table(self: Source) w.Source {
        return .{ .snapshot = .{ .object = self.binding.source.interpretation.object, .handle = self.binding.pin.? }, .interpretation = self.binding.declaration, .accepted = self.binding.source.accepted, .changed_lsn = self.changed_lsn, .row_count = self.rows, .schema = self.schema, .authority = self.authority };
    }
};
pub const Listing = struct {
    pub const json_schema_sequence_bounds = .{ .entries = 8 };
    snapshot: d.Snapshot,
    namespace: u64,
    entries: []const H.Entry,
    next: ?H.Cursor,
};
pub const Read = struct { snapshot: d.Snapshot, object: u64, after: ?c.storage.TablePartition.SnapshotCursor, limits: c.storage.TablePartition.ReadLimits };
pub const Page = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 8 };
    snapshot: d.Snapshot,
    source: d.SourceCut,
    total_rows: u64,
    rows: []const w.Binary,
    encoded_bytes: u32,
    next: ?c.storage.TablePartition.SnapshotCursor,
};
pub const Request = union(enum) {
    /// Add one exact current binding to a private immutable selection. The
    /// returned selection remains caller input until accepted acquisition.
    select: struct { selection: Selection, namespace: u64, name: c.TableAuthority.Name },
    acquire: struct { key: c.DirectClientToken.Key, intent: Intent, budget: c.DirectClientToken.Budget = .{} },
    inspect: c.DirectClientToken.Key,
    advance: c.DirectClientToken.Key,
    abandon: c.DirectClientToken.Key,
    release: c.DirectClientToken.Key,
    source: struct { snapshot: d.Snapshot, object: u64, rows: bool = false },
    lookup: struct { snapshot: d.Snapshot, namespace: u64, name: c.TableAuthority.Name },
    namespace: struct { snapshot: d.Snapshot, name: c.TableAuthority.Name },
    list: struct { snapshot: d.Snapshot, namespace: u64, after: ?H.Cursor },
    scan: Read,
    definitions: struct { snapshot: d.Snapshot, object: u64, after: ?P.ProjectionEvidence.Cursor },
    locations: struct { snapshot: d.Snapshot, object: u64, after: ?P.SnapshotCursor },
    pub fn mutation(self: Request) bool {
        return switch (self) {
            .select, .acquire, .advance, .abandon, .release => true,
            .inspect, .source, .lookup, .namespace, .list, .scan, .definitions, .locations => false,
        };
    }
    pub fn validate(self: Request, connection: w.Connection) !void {
        switch (self) {
            .select => |value| {
                try value.selection.owner.validate();
                try c.Model.nativeId(value.namespace);
                try value.name.validate();
                if (!std.meta.eql(value.selection.owner.scope, connection.scope) or value.selection.owner.principal != connection.principal or value.selection.branch != connection.branch) return error.HistoricalIdentityConflict;
                if (value.selection.directory) |selected| {
                    var key: [96]u8 = undefined;
                    _ = try H.objectKey(selected.content, &key);
                }
            },
            .acquire => |value| {
                try value.key.validate();
                try value.intent.validate();
                try value.budget.validate();
                if (!std.meta.eql(value.key.connection, connection) or !std.meta.eql(value.intent.connection, connection)) return error.HistoricalIdentityConflict;
            },
            inline .inspect, .advance, .abandon, .release => |key| {
                try key.validate();
                if (!std.meta.eql(key.connection, connection)) return error.HistoricalIdentityConflict;
            },
            inline .source, .lookup, .namespace, .list, .scan, .definitions, .locations => |value, tag| {
                try value.snapshot.validate();
                if (value.snapshot.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                if (!std.meta.eql(value.snapshot.owner.scope, connection.scope) or value.snapshot.branch != connection.branch) return error.HistoricalIdentityConflict;
                if (comptime tag == .list) {
                    try c.Model.nativeId(value.namespace);
                    if (value.after) |cursor| if (!std.meta.eql(cursor.directory.content, value.snapshot.sources_root) or cursor.directory.count != value.snapshot.source_count or cursor.directory.descriptors != 0 or cursor.after == 0) return error.InvalidHistoricalCursor;
                } else if (comptime tag == .lookup or tag == .namespace) {
                    if (comptime tag == .lookup) try c.Model.nativeId(value.namespace);
                    try value.name.validate();
                } else if (value.object == 0) return error.InvalidHistoricalBinding;
                if (comptime tag == .scan) {
                    try value.limits.validate();
                    if (value.limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
                }
            },
        }
    }
};
pub const Result = union(enum) { selection: Selection, status: ?Status, object: ?u64, namespace: ?c.TableAuthority.Schema, listing: Listing, source: Source, page: Page, definitions: struct { snapshot: d.Snapshot, source: d.SourceCut, evidence: P.ProjectionEvidence }, locations: struct { snapshot: d.Snapshot, source: d.SourceCut, evidence: P.ProjectionLocations } };

/// Response owns schema/row bytes. Keep it alive through their bounded use.
pub fn call(client: c.DirectTableClient, request: Request) !std.json.Parsed(w.Response) {
    return client.call(.{ .historical_catalog = request }) catch |err| {
        // The shared transport preserves the native rejection separately from
        // its HTTP category. Interpret it only within this owning operation.
        if (err == error.Conflict and client.service.last_rejection == .QueryExpired) return error.HistoricalSnapshotReleased;
        return err;
    };
}
pub fn validateResult(allocator: std.mem.Allocator, connection: w.Connection, request: Request, result: Result) !void {
    try request.validate(connection);
    switch (request) {
        .select => |input| {
            if (result != .selection) return error.InvalidHistoricalResponse;
            const value = result.selection;
            if (!std.meta.eql(value.owner, input.selection.owner) or value.branch != input.selection.branch) return error.InvalidHistoricalResponse;
            const directory = value.directory orelse return error.InvalidHistoricalResponse;
            var key: [96]u8 = undefined;
            _ = try H.objectKey(directory.content, &key);
            const previous: u64 = if (input.selection.directory) |selected| selected.count else 0;
            const previous_descriptors: u64 = if (input.selection.directory) |selected| selected.descriptors else 0;
            if (try directory.total() == 0 or directory.count < previous or directory.descriptors < previous_descriptors or directory.descriptors > try std.math.add(u64, previous_descriptors, 1)) return error.InvalidHistoricalResponse;
            const maximum_added: u64 = if (directory.descriptors == previous_descriptors) 1 else c.CatalogDefinition.max_sources;
            if (directory.count > try std.math.add(u64, previous, maximum_added)) return error.InvalidHistoricalResponse;
            if (directory.count == previous and directory.descriptors == previous_descriptors and !std.meta.eql(directory, input.selection.directory.?)) return error.InvalidHistoricalResponse;
        },
        .acquire, .inspect, .advance, .abandon, .release => {
            if (result != .status) return error.InvalidHistoricalResponse;
            const status = result.status orelse {
                if (request != .inspect) return error.InvalidHistoricalResponse;
                return;
            };
            try status.receipt.validate();
            try status.revision.validate();
            const progress: c.DirectClientToken.Progress = .{ .receipt = status.receipt, .revision = status.revision, .pending = status.state.pending(), .cancel = status.state.cancelled(), .record = null };
            try progress.validate();
            try status.state.validate(progress);
            const intent = status.receipt.binding.intent.history;
            if (!std.meta.eql(intent.connection, connection)) return error.InvalidHistoricalResponse;
            switch (request) {
                .acquire => |value| {
                    try value.key.requireSame(status.receipt.binding.key);
                    if (!std.meta.eql(value.intent, intent)) return error.InvalidHistoricalResponse;
                },
                inline .inspect, .advance, .abandon, .release => |key| try key.requireSame(status.receipt.binding.key),
                else => unreachable,
            }
        },
        .lookup => {
            if (result != .object) return error.InvalidHistoricalResponse;
            if (result.object) |object| if (object == 0) return error.InvalidHistoricalResponse;
        },
        .namespace => |input| {
            if (result != .namespace) return error.InvalidHistoricalResponse;
            if (result.namespace) |value| {
                try value.validate();
                if (value.retired or !std.meta.eql(value.scope, connection.scope) or !std.meta.eql(value.name, input.name)) return error.InvalidHistoricalResponse;
            }
        },
        .list => |input| {
            if (result != .listing) return error.InvalidHistoricalResponse;
            const value = result.listing;
            if (!std.meta.eql(value.snapshot, input.snapshot) or value.namespace != input.namespace or value.entries.len > 8) return error.InvalidHistoricalResponse;
            var after: u64 = if (input.after) |cursor| cursor.after else 0;
            for (value.entries) |entry| {
                try entry.validate(input.snapshot.owner, input.snapshot.branch, .retained);
                try input.snapshot.requireSource(entry.source);
                if (entry.namespace.id != input.namespace or entry.source.interpretation.object.object <= after) return error.InvalidHistoricalResponse;
                after = entry.source.interpretation.object.object;
            }
            if (value.next) |cursor| {
                if (!std.meta.eql(cursor.directory.content, input.snapshot.sources_root) or cursor.directory.count != input.snapshot.source_count or cursor.directory.descriptors != 0 or cursor.after < after or cursor.after <= (if (input.after) |previous| previous.after else 0)) return error.InvalidHistoricalResponse;
            }
        },
        inline .definitions, .locations => |input, tag| {
            if (std.meta.activeTag(result) != @field(std.meta.Tag(Result), @tagName(tag))) return error.InvalidHistoricalResponse;
            const value = @field(result, @tagName(tag));
            if (!std.meta.eql(value.snapshot, input.snapshot) or value.source.interpretation.object.object != input.object or
                !std.meta.eql(value.evidence.snapshot.owner, input.snapshot.owner) or !std.meta.eql(value.source.interpretation, value.evidence.logical.interpretation) or
                !std.meta.eql(value.source.accepted, value.evidence.accepted)) return error.InvalidHistoricalResponse;
            try input.snapshot.requireSource(value.source);
            try value.evidence.snapshot.content.validate();
            const selected: w.Snapshot = .{ .object = value.source.interpretation.object, .handle = value.evidence.snapshot };
            const validation = @import("DirectTableResponse.zig");
            if (comptime tag == .definitions) try validation.projectionDefinitions(connection, .{ .snapshot = selected, .after = input.after }, value.evidence) else try validation.projectionLocations(connection, .{ .snapshot = selected, .after = input.after }, value.evidence);
        },
        .source => |input| {
            if (result != .source) return error.InvalidHistoricalResponse;
            const value = result.source;
            if (!std.meta.eql(value.snapshot, input.snapshot) or value.binding.source.interpretation.object.object != input.object) return error.InvalidHistoricalResponse;
            try value.binding.validate(input.snapshot.owner, input.snapshot.branch, .retained);
            try value.authority.validate();
            if (value.changed_lsn > value.binding.source.accepted.next_lsn) return error.InvalidHistoricalResponse;
            try input.snapshot.requireSource(value.binding.source);
            const bytes = try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
            defer allocator.free(bytes);
            var decoded = try c.fuze.TableSchema.decode(allocator, bytes);
            defer decoded.deinit();
            if (decoded.schema.object != input.object or !std.mem.eql(u8, &try decoded.schema.fingerprint(), &value.binding.declaration.schema_fingerprint)) return error.InvalidHistoricalResponse;
        },
        .scan => |input| {
            if (result != .page) return error.InvalidHistoricalResponse;
            const page = result.page;
            if (!std.meta.eql(page.snapshot, input.snapshot) or page.source.interpretation.object.object != input.object) return error.InvalidHistoricalResponse;
            try input.snapshot.requireSource(page.source);
            if (page.rows.len > input.limits.rows or page.rows.len > page.total_rows or page.encoded_bytes > input.limits.encoded_bytes) return error.InvalidHistoricalResponse;
            var total: usize = 0;
            for (page.rows) |row| {
                const bytes = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                defer allocator.free(bytes);
                total = try std.math.add(usize, total, bytes.len);
            }
            if (total != page.encoded_bytes) return error.InvalidHistoricalResponse;
            if (page.next) |next| {
                try next.source.validate();
                if (page.rows.len == 0) return error.InvalidHistoricalResponse;
                if (input.after) |previous| if (!std.meta.eql(next.source, previous.source) or std.mem.order(u8, &next.after, &previous.after) != .gt) return error.InvalidHistoricalResponse;
            } else if (input.after == null and page.rows.len != page.total_rows) return error.InvalidHistoricalResponse;
        },
    }
}

/// Resolve within the selected catalog before decoding or compiling a schema.
/// The returned response owns the source bytes; no current-name fallback.
pub fn resolve(client: c.DirectTableClient, snapshot: d.Snapshot, namespace_id: u64, name: []const u8, rows: bool) !std.json.Parsed(w.Response) {
    const lookup = try call(client, .{ .lookup = .{ .snapshot = snapshot, .namespace = namespace_id, .name = try .init(name) } });
    defer lookup.deinit();
    const object = lookup.value.result.historical_catalog.object orelse return error.HistoricalObjectNotSelected;
    return call(client, .{ .source = .{ .snapshot = snapshot, .object = object, .rows = rows } });
}

test {
    _ = @import("direct_history_test.zig");
}

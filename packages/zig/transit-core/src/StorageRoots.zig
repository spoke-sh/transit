//! Bounded enumeration of roots selected by an accepted collection cut.
//! Only the cut's current live pins own captured catalogs. Old pin metadata in
//! retained catalogs is ordinary history, not recursively renewed ownership.
const std = @import("std");
const core = @import("root.zig");
const c = core.catalog;
const Self = @This();
pub const Owner = enum { current, history, captured };
pub const Step = union(enum) { root: struct { root: core.StorageWalk.Root, owner: Owner }, progress, complete };
phase: enum { journal_catalog, journal_policy, views, versions, complete } = .journal_catalog,
record: u64,
after: ?core.pages.Key = null,

pub fn init(cut: core.growing.Head) Self {
    return .{ .record = cut.history_floor };
}
pub fn next(self: *Self, journal: anytype, store: anytype, cut: core.growing.Head) !Step {
    const before = self.*;
    errdefer self.* = before;
    switch (self.phase) {
        .journal_catalog, .journal_policy => {
            if (self.record < cut.history_floor or self.record > cut.position) return error.InvalidStorageGraph;
            if (self.record == cut.position) {
                self.phase = .views;
                return .progress;
            }
            const entry = (try journal.read(self.record)) orelse return error.IncompleteHistory;
            const head = switch (entry) {
                .genesis => |value| value.head,
                .operation => |value| value.next,
            };
            if (head.position != self.record + 1 or !std.mem.eql(u8, &head.genesis, &cut.genesis) or head.storage_epoch > cut.storage_epoch) return error.InvalidStorageGraph;
            if (self.record + 1 == cut.position and !std.meta.eql(head, cut)) return error.InvalidStorageGraph;
            const policy = self.phase == .journal_policy;
            if (policy) {
                self.phase = .journal_catalog;
                self.record += 1;
            } else self.phase = .journal_policy;
            const snapshot = if (policy) head.authorization.catalog else head.catalog;
            try snapshot.validate();
            return if (snapshot.root) |root| .{ .root = .{ .root = .{ .reference = root, .kind = if (policy) .policy else .catalog }, .owner = if (head.position == cut.position) .current else .history } } else .progress;
        },
        .views => {
            var catalog = try c.Catalog(@TypeOf(store.*)).open(store, cut.catalog);
            const batch = try catalog.scan(core.growing.StoredView, .{ .namespace = .view }, self.after);
            for (batch.records) |slot| if (slot) |record| {
                self.after = record.key;
                if (record.value.meta.closed_at == null) {
                    try record.value.snapshot.validate();
                    if (record.value.snapshot.root) |root| return .{ .root = .{ .root = .{ .reference = root, .kind = .catalog, .resource = record.value.meta.resource }, .owner = .captured } };
                }
            };
            if (batch.next == null) {
                self.phase = .versions;
                self.after = null;
            }
            return .progress;
        },
        .versions => {
            var catalog = try c.Catalog(@TypeOf(store.*)).open(store, cut.catalog);
            const batch = try catalog.scan(core.growing.StoredReadVersion, .{ .namespace = .read_version }, self.after);
            for (batch.records) |slot| if (slot) |record| {
                self.after = record.key;
                if (record.value.meta.released_at == null) {
                    try record.value.snapshot.validate();
                    if (record.value.snapshot.root) |root| return .{ .root = .{ .root = .{ .reference = root, .kind = .catalog, .resource = record.value.meta.resource }, .owner = .captured } };
                }
            };
            if (batch.next == null) {
                self.phase = .complete;
                self.after = null;
            }
            return .progress;
        },
        .complete => return .complete,
    }
}

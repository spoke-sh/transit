//! Read-only candidate execution. Scratch pages never reach the provider and
//! reservations never reach the native head. Bounds limit this operation, not
//! durable graph cardinality; larger changes use the retained staging workflow.
const std = @import("std");
const core = @import("root.zig");
const a = core.protocol.Authorization;
const pages = core.pages;
const admin = core.authorization_admin;

fn Overlay(comptime Backing: type) type {
    return struct {
        backing: *Backing,
        records: [a.preview_pages]struct { reference: pages.Reference, page: pages.Page } = undefined,
        len: u32 = 0,
        reads: u32 = 0,
        pub fn load(self: *@This(), reference: pages.Reference) !pages.Page {
            if (self.reads == a.preview_reads) return error.AuthorizationPreviewLimit;
            self.reads += 1;
            for (self.records[0..self.len]) |*record| if (std.mem.eql(u8, &record.reference.digest, &reference.digest)) return record.page;
            return self.backing.load(reference);
        }
        pub fn stage(self: *@This(), reference: pages.Reference, page: *const pages.Page) !pages.Reference {
            for (self.records[0..self.len]) |*record| if (std.mem.eql(u8, &record.reference.digest, &reference.digest)) return record.reference;
            if (self.len == a.preview_pages) return error.AuthorizationPreviewLimit;
            self.records[self.len] = .{ .reference = reference, .page = page.* };
            self.len += 1;
            return reference;
        }
    };
}

pub fn run(backing: anytype, snapshot: core.authorization_store.Snapshot, actor: admin.Actor, id: u64, action: a.Action, limits: a.Limits, quota: admin.Quota) !a.Preview {
    var overlay: Overlay(@TypeOf(backing.*)) = .{ .backing = backing };
    var store = try core.authorization_store.Store(@TypeOf(overlay)).open(&overlay, snapshot);
    var change = admin.begin(&store, actor, id, action, limits, quota) catch |err| switch (err) {
        error.AuthorizationPreviewLimit => return .{ .complete = false, .changed_records = 0, .steps = 0, .pages = overlay.len, .reads = overlay.reads },
        else => return err,
    };
    while (change.outcome.status == .preparing and change.outcome.steps < a.preview_steps) {
        admin.advance(&store, &change, limits) catch |err| switch (err) {
            error.AuthorizationPreviewLimit => break,
            else => return err,
        };
    }
    return .{ .complete = change.outcome.status == .ready, .changed_records = change.outcome.changed_records, .steps = change.outcome.steps, .pages = overlay.len, .reads = overlay.reads };
}

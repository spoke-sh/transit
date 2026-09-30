//! Explicit working-catalog collection. Each command removes at most one page
//! per family. Journal receipts, immutable roots and permanent identities remain.
const core = @import("root.zig");
const g = core.protocol.Growth;
const growth = @import("growing.zig");
const state = @import("growing_state.zig");
const work = @import("growing_work.zig");
const c = @import("catalog.zig");
const address = growth.address;

fn empty(candidate: anytype, namespace: c.Namespace, id: u64) !bool {
    return (try candidate.scan(u64, .{ .namespace = namespace, .major = id }, null)).records[0] == null;
}
fn removePage(candidate: anytype, comptime T: type, namespace: c.Namespace, id: u64) !bool {
    const batch = try candidate.scan(T, .{ .namespace = namespace, .major = id }, null);
    for (batch.records) |slot| if (slot) |record| try candidate.remove(record.key);
    return batch.records[0] != null;
}
fn detach(candidate: anytype, association: g.Association) !void {
    try candidate.remove(try c.key(.association, association.pid, 0, association.name.slice()));
    try candidate.remove(try c.key(.required_association, association.pid, 0, association.name.slice()));
    try candidate.remove(try c.key(.association_order, association.pid, association.revision, ""));
    try candidate.remove(try c.key(.associations_by_resource, association.resource, association.pid, association.name.slice()));
    try candidate.remove(try c.key(.required_resource_users, association.resource, association.pid, association.name.slice()));
    const index = try c.key(.associated_resource, association.pid, association.resource, "");
    const count = (try candidate.get(u64, index)) orelse return error.InvalidHistory;
    if (count == 1) try candidate.remove(index) else try candidate.put(index, count - 1);
}
/// A retired process cannot use its old views. Close their working indexes but
/// retain metadata needed to authorize exact receipts for the original turns.
fn closeViews(engine: anytype, candidate: anytype, namespace: c.Namespace, id: u64) !bool {
    const batch = try candidate.scan(u64, .{ .namespace = namespace, .major = id }, null);
    for (batch.records) |slot| if (slot) |record| {
        var stored = try state.view(engine, record.value);
        const process = try engine.process(stored.meta.pid);
        if (process.lifecycle == .running and process.generation == stored.meta.generation and (try state.resource(engine, stored.meta.resource)).phase == .active) return error.StateViewInUse;
        stored.meta.closed_at = engine.head.position;
        try candidate.put(address(.view, stored.meta.id), stored);
        try candidate.remove(try c.key(.views_by_pid, stored.meta.pid, stored.meta.id, ""));
        try candidate.remove(try c.key(.views_by_resource, stored.meta.resource, stored.meta.id, ""));
    };
    return batch.records[0] != null;
}
/// Resource reclamation is independently opted into by history_ms. It erases
/// at most one entry page per publication and preserves metadata and receipts.
pub fn reclaim(engine: anytype, candidate: anytype, id: u64, sample: ?core.Time.Sample) !void {
    var resource = try state.resource(engine, id);
    if (resource.phase != .retired) return error.StateResourceInUse;
    const age = resource.history_ms orelse return error.HistoryPinned;
    if (age > 0 and (sample orelse return error.ClockUnavailable).lower() < resource.changed_ms +| age) return error.HistoryPinned;
    if (!try empty(candidate, .versions_by_resource, id)) return error.StateViewInUse;
    if (try closeViews(engine, candidate, .views_by_resource, id)) return;
    const entries = try candidate.scan(g.Entry, .{ .namespace = .entry, .major = id }, null);
    for (entries.records) |slot| if (slot) |record| {
        try candidate.remove(record.key);
        resource.entries -= 1;
    };
    if (resource.entries == 0) resource.phase = .reclaimed;
    resource.revision = engine.head.position;
    try candidate.put(address(.resource, id), resource);
}
pub fn apply(engine: anytype, candidate: anytype, request: g.Collection) !void {
    const process = try engine.process(request.pid);
    if (!process.allow_collection) return error.RetentionNotEnabled;
    switch (request.kind) {
        .output => {
            const out = try work.output(engine, request.id);
            if (out.source != request.pid) return error.InvalidOutput;
            if (out.phase == .pending) return error.PendingWork;
            // Destination admission owns its value and authenticated origin.
            try candidate.remove(address(.output, out.id));
            try candidate.remove(try c.key(.outputs_by_source, out.source, out.id, ""));
            try candidate.remove(try c.key(.outputs_by_destination, out.destination, out.id, ""));
        },
        .effect => {
            const effect = try work.effect(engine, request.id);
            if (effect.pid != request.pid) return error.InvalidEffect;
            switch (effect.phase) {
                .observed, .cancelled, .closed_unknown => {},
                else => return error.PendingWork,
            }
            try candidate.remove(address(.effect, effect.id));
            try candidate.remove(try c.key(.effects_by_pid, effect.pid, effect.id, ""));
        },
        .payload => {
            const payload = try @import("growing_payload.zig").get(engine, .{ .pid = request.pid, .payload = request.id });
            if (payload.phase != .deleted) return error.PendingWork;
            try candidate.remove(address(.payload, payload.id));
            try candidate.remove(try c.key(.payloads_by_pid, payload.pid, payload.id, ""));
        },
        .resource => {
            const resource = try state.resource(engine, request.id);
            if (resource.writer != request.pid) return error.Forbidden;
            if (resource.phase != .reclaimed) return error.PendingWork;
            if (!try empty(candidate, .versions_by_resource, resource.id)) return error.StateViewInUse;
            if (try closeViews(engine, candidate, .views_by_resource, resource.id)) return;
            const associations = try candidate.scan(g.Association, .{ .namespace = .associations_by_resource, .major = resource.id }, null);
            for (associations.records) |slot| if (slot) |record| {
                if ((try engine.process(record.value.pid)).lifecycle == .running) return error.StateResourceInUse;
                try detach(candidate, record.value);
            };
            if (associations.records[0] != null) return;
            if (try removePage(candidate, growth.ResourceGrant, .grant, resource.id)) return;
            try candidate.remove(address(.resource, resource.id));
            try candidate.remove(try c.key(.resources_by_writer, resource.writer, resource.id, ""));
            if (resource.owner) |owner| try candidate.remove(try c.key(.resources_by_owner, owner, resource.id, ""));
        },
        .process => {
            if (request.id != request.pid) return error.InvalidRequest;
            if (process.lifecycle == .running) return error.PendingWork;
            if (process.binding) |binding| if (binding.phase != .stopped or binding.desired != .stopped or binding.upgrade_from != null) return error.PendingProviderOperation;
            inline for (.{ .outputs_by_source, .outputs_by_destination, .effects_by_pid, .payloads_by_pid }) |namespace| if (!try empty(candidate, namespace, request.pid)) return error.PendingWork;
            if (try closeViews(engine, candidate, .views_by_pid, request.pid)) return;
            const retained = try candidate.scan(g.ReadVersionId, .{ .namespace = .versions_by_pid, .major = request.pid }, null);
            for (retained.records) |slot| if (slot) |record| {
                var stored = try state.readVersion(engine, record.value);
                stored.meta.released_at = engine.head.position;
                const key = try state.versionKey(record.value);
                try candidate.put(key, stored);
                try candidate.remove(try c.key(.versions_by_resource, stored.meta.resource, record.value.pid, key.slice()[9..]));
                try candidate.remove(record.key);
            };
            if (retained.records[0] != null) return;
            inline for (.{ .resources_by_writer, .resources_by_owner }) |namespace| if (!try empty(candidate, namespace, request.pid)) return error.StateResourceInUse;
            const associations = try candidate.scan(g.Association, .{ .namespace = .association, .major = request.pid }, null);
            for (associations.records) |slot| if (slot) |record| try detach(candidate, record.value);
            if (associations.records[0] != null) return;
            if (try removePage(candidate, g.Input, .mailbox, request.pid)) return;
            try candidate.put(address(.retired_process, request.pid), growth.RetiredProcess{ .pid = request.pid, .lifecycle = process.lifecycle });
            try candidate.remove(address(.process, request.pid));
            // runtime_resource reservations are deliberately permanent.
        },
    }
}

/// Disposable bounded maintenance cursors. A suggestion grants no authority;
/// admission rechecks every gate, and a blocked item never stalls other families.
pub const Scan = struct {
    const Family = enum { output, effect, payload, resource, process };
    const Cursor = struct { after: ?core.pages.Key = null, through: ?u64 = null };
    family: Family = .output,
    cursors: [5]Cursor = @splat(.{}),
    pub fn next(self: *Scan, engine: anytype) !?g.Command {
        const family = self.family;
        self.family = @fromBackingInt(@intCast((@as(usize, @backingInt(family)) + 1) % self.cursors.len));
        const cursor = &self.cursors[@backingInt(family)];
        if (cursor.through == null) cursor.through = if (family == .output) engine.head.outputs else engine.head.position - 1;
        var catalog = try engine.state();
        switch (family) {
            inline else => |kind| {
                const T = switch (kind) {
                    .output => g.Outbox,
                    .effect => g.Effect,
                    .payload => g.Payload,
                    .resource => g.Resource,
                    .process => g.Process,
                };
                const namespace: c.Namespace = switch (kind) {
                    .output => .output,
                    .effect => .effect,
                    .payload => .payload,
                    .resource => .resource,
                    .process => .process,
                };
                const page = try catalog.scan(T, .{ .namespace = namespace }, cursor.after);
                const item = page.records[0] orelse {
                    cursor.* = .{};
                    return null;
                };
                const value = item.value;
                const id = if (kind == .process) value.pid else value.id;
                if (id > cursor.through.?) {
                    cursor.* = .{};
                    return null;
                }
                cursor.after = item.key;
                const pid = switch (kind) {
                    .output => value.source,
                    .resource => value.writer,
                    else => value.pid,
                };
                const process = try engine.process(pid);
                if (!process.allow_collection) return null;
                switch (kind) {
                    .output => if (value.phase == .pending) return null,
                    .effect => switch (value.phase) {
                        .observed, .cancelled, .closed_unknown => {},
                        else => return null,
                    },
                    .payload => if (value.phase != .deleted) return null,
                    .resource => if (value.phase != .reclaimed) return null,
                    .process => if (value.lifecycle == .running) return null,
                }
                return .{ .collect = .{ .pid = pid, .id = id, .kind = @field(@FieldType(g.Collection, "kind"), @tagName(kind)) } };
            },
        }
    }
};

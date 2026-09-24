//! Authorized state reads. Snapshot identity never substitutes for current grants.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const s = p.State;

pub fn read(engine: anytype, signed: s.SignedQuery) !s.Page {
    try engine.refresh();
    const state = &engine.state;
    const q = signed.query;
    if (q.realm != state.realm) return error.Unauthorized;
    const principal = state.principal(q.principal) catch return error.Unauthorized;
    const public = p.Ed25519.PublicKey.fromBytes(principal.grant.public_key) catch return error.Unauthorized;
    p.Ed25519.Signature.fromBytes(signed.signature).verify(&s.digest(q), public) catch return error.Unauthorized;
    if (principal.grant.permissions == 0) return error.Forbidden;
    if (q.kind == .associations or q.kind == .view) {
        if (q.pid == null or (principal.grant.pid != null and principal.grant.pid != q.pid)) return error.Forbidden;
        const permission: p.Permission = if (q.kind == .view) .execute else .inspect;
        if (principal.grant.permissions & p.permission(permission) == 0) return error.Forbidden;
    }
    // Resource checks precede existence, continuation, time, and value disclosure.
    if (q.resource) |id| {
        const cat = if (state.resources) |*value| value else return error.Forbidden;
        if (!cat.allowed(id, q.principal, .inspect)) return error.Forbidden;
        if (q.kind == .entries and !cat.allowed(id, q.principal, .read)) return error.Forbidden;
    }
    try s.validateQuery(q);
    const cut: p.Inspection.Cut = .{ .position = state.position, .policy_revision = principal.revision, .retained_from = state.history_floor };
    if (q.cut) |old| {
        if (old.retained_from < cut.retained_from) return error.HistoryReclaimed;
        if (!std.meta.eql(old, cut)) return error.QueryExpired;
    }
    var result: s.Page = .{ .realm = state.realm, .principal_sequence = principal.sequence, .cut = cut };
    if (q.kind == .capabilities) result.capabilities = .{};
    if (q.kind == .associations) _ = try state.process(q.pid.?);
    if (state.resources) |*cat| {
        switch (q.kind) {
            .capabilities => {},
            .resources => {
                if (q.resource) |id| {
                    if (q.after != 0) return error.InvalidRead;
                    result.resources[0] = (try cat.resource(id)).meta;
                } else {
                    if (q.after > s.max_resources) return error.InvalidRead;
                    var index: usize = q.after;
                    var count: usize = 0;
                    while (index < s.max_resources and count < s.page_size) : (index += 1) {
                        if (cat.resources[index]) |data| if (cat.allowed(data.meta.id, q.principal, .inspect)) {
                            result.resources[count] = data.meta;
                            count += 1;
                        };
                    }
                    if (index < s.max_resources) result.next = @intCast(index);
                }
            },
            .associations => {
                if (q.after > s.max_associations) return error.InvalidRead;
                var index: usize = q.after;
                var count: usize = 0;
                while (index < s.max_associations and count < s.page_size) : (index += 1) {
                    if (cat.associations[index]) |association| {
                        if (association.pid == q.pid and cat.allowed(association.resource, q.principal, .inspect)) {
                            result.associations[count] = association;
                            count += 1;
                        }
                    }
                }
                if (index < s.max_associations) result.next = @intCast(index);
            },
            .entries => {
                const data = try cat.resource(q.resource.?);
                try core.resources.usable(state, data, if (data.meta.deadline_ms != null) try sample(engine) else null);
                result.resources[0] = data.meta;
                try entries(&result, &data.entries, q);
            },
            .view => {
                const view = try cat.view(q.view.?);
                if (view.meta.principal != q.principal or view.meta.pid != q.pid) return error.Forbidden;
                const process = try state.process(q.pid.?);
                if (process.lifecycle != .running or process.generation != view.meta.generation or process.owner != q.principal) return error.StateViewExpired;
                if (!cat.allowed(view.meta.resource, q.principal, .read) or !cat.allowed(view.meta.resource, q.principal, .inspect)) return error.Forbidden;
                const now = try sample(engine);
                (try core.resources.time(state, now)).before(view.meta.deadline_ms) catch |err| {
                    if (err == error.DeadlineExpired) return error.StateViewExpired;
                    return err;
                };
                try core.resources.checkProcess(state, q.pid.?, now);
                try core.resources.usable(state, try cat.resource(view.meta.resource), now);
                result.view = view.meta;
                try entries(&result, &view.entries, q);
            },
        }
    } else if (q.kind == .view) return error.StateViewExpired;
    // This bounded batch linearizes permission at the observed journal tail.
    if (try engine.store.tail() != cut.position) return error.Conflict;
    return result;
}
fn sample(engine: anytype) !core.Time.Sample {
    return if (engine.clock) |clock| try clock.sample() else error.ClockUnavailable;
}
fn entries(result: *s.Page, values: *const [s.max_entries]?s.Entry, q: s.Query) !void {
    if (q.after > s.max_entries) return error.InvalidRead;
    var index: usize = q.after;
    var count: usize = 0;
    while (index < s.max_entries and count < s.page_size) : (index += 1) {
        if (values[index]) |value| {
            if (q.key) |key| if (!value.key.eql(key)) continue;
            result.entries[count] = value;
            count += 1;
        }
    }
    if (index < s.max_entries and q.key == null) result.next = @intCast(index);
}

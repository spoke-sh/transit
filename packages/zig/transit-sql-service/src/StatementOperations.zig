//! One durable statement dispatch boundary for sessions and migrations.
const g = @import("root.zig");
const api = g.session_protocol;

pub fn lookup(host: *g.Session, token: api.Token, fingerprint: ?[32]u8) !?g.SessionOperations.Reference {
    return host.fresh(g.ConfigurationOperations.find, .{ host, token, fingerprint });
}

pub fn admit(host: *g.Session, prepared: *g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom, token: api.Token, fingerprint: [32]u8, acceptance_possible: *bool) !api.Operation {
    switch (prepared.*) {
        .managed => {
            acceptance_possible.* = true;
            return g.ManagedOperations.admit(host, &prepared.managed, token, fingerprint);
        },
        .native => {
            const fresh = host.fresh_prepared == prepared;
            host.fresh_prepared = null;
            return host.runtime.submitPrepared(host.allocator, &host.observer, &host.table, &prepared.native, values, token, fingerprint, host.deadline, &host.operation, acceptance_possible, fresh, true);
        },
        .transaction, .probe, .settings, .inspection, .source, .captured, .workload => return error.SqlDurableStatementRequired,
    }
}

pub fn status(host: *g.Session, ref: g.SessionOperations.Reference) !api.Operation {
    return switch (ref.kind) {
        .table, .transaction, .workload => try host.fresh(g.DatabaseRuntime.status, .{ host.runtime, host.allocator, &host.observer, &host.table, host.namespace, ref.id }),
        .dataflow => try g.ManagedOperations.status(host, ref.id),
        .configuration => try g.ConfigurationOperations.status(host, ref.id),
        .captured => try g.CapturedOperations.status(host, ref.id),
    };
}

pub fn resumeOperation(host: *g.Session, ref: g.SessionOperations.Reference) !api.Operation {
    switch (ref.kind) {
        .table, .transaction, .workload => try host.runtime.resumeOperation(&host.observer, ref.id),
        .dataflow => return g.ManagedOperations.resumeOperation(host, ref.id),
        .configuration => return g.ConfigurationOperations.resumeOperation(host, ref.id),
        .captured => {
            try g.CapturedOperations.select(host, ref.id);
            return g.CapturedOperations.resumeOperation(host, ref.id);
        },
    }
    return status(host, ref);
}

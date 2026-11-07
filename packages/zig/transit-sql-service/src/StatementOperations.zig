//! One durable statement dispatch boundary for sessions and migrations.
const g = @import("root.zig");
const api = g.session_protocol;

pub fn lookup(host: *g.Session, token: api.Token, fingerprint: ?[32]u8) !?g.SessionOperations.Reference {
    return host.fresh(g.ConfigurationOperations.find, .{ host, token, fingerprint });
}

pub fn admit(host: *g.Session, prepared: *g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom, token: api.Token, fingerprint: [32]u8, acceptance_possible: *bool) !api.Operation {
    return admitReviewed(host, prepared, values, token, fingerprint, acceptance_possible, null);
}
pub fn admitReviewed(host: *g.Session, prepared: *g.Session.Prepared, values: []const ?g.fuze.Types.Values.Atom, token: api.Token, fingerprint: [32]u8, acceptance_possible: *bool, guard: ?g.ManagedOperations.Guard) !api.Operation {
    switch (prepared.*) {
        .managed => {
            return g.ManagedOperations.admitReviewed(host, &prepared.managed, token, fingerprint, acceptance_possible, guard);
        },
        .native => {
            const fresh = host.fresh_prepared == prepared;
            host.fresh_prepared = null;
            host.clearRetainedWorkload();
            return host.runtime.submitPreparedRetained(host.allocator, &host.observer, &host.table, &prepared.native, values, token, fingerprint, host.deadline, &host.operation, acceptance_possible, fresh, true, &host.retained_workload);
        },
        .transaction, .probe, .settings, .inspection, .source, .captured, .workload, .connector => return error.SqlDurableStatementRequired,
    }
}

pub fn status(host: *g.Session, ref: g.SessionOperations.Reference) !api.Operation {
    return switch (ref.kind) {
        .table, .transaction, .workload => try host.fresh(g.DatabaseRuntime.status, .{ host.runtime, host.allocator, &host.observer, &host.table, host.namespace, ref.id }),
        .connector => try g.SourceOperations.status(host, ref.id),
        .dataflow => try g.ManagedOperations.status(host, ref.id),
        .configuration => try g.ConfigurationOperations.status(host, ref.id),
        .captured => try g.CapturedOperations.status(host, ref.id),
    };
}

pub fn resumeOperation(host: *g.Session, ref: g.SessionOperations.Reference) !api.Operation {
    switch (ref.kind) {
        .table, .transaction, .workload => try host.runtime.resumeOperation(&host.observer, ref.id),
        .connector => return g.SourceOperations.resumeOperation(host, ref.id),
        .dataflow => return g.ManagedOperations.resumeOperation(host, ref.id),
        .configuration => return g.ConfigurationOperations.resumeOperation(host, ref.id),
        .captured => {
            try g.CapturedOperations.select(host, ref.id);
            return g.CapturedOperations.resumeOperation(host, ref.id);
        },
    }
    return status(host, ref);
}

/// Reopen retained rows from the original accepted operation, without SQL replay.
pub fn prepareResult(host: *g.Session, ref: g.SessionOperations.Reference) !g.Session.Prepared {
    return switch (ref.kind) {
        .workload => blk: {
            var source = try host.observer.source();
            const state = try source.operation(ref.id);
            if (state.receipt.binding.intent != .workload) return error.InvalidSqlOperationReference;
            const original = state.receipt.binding.intent.workload;
            if (original.namespace != host.namespace) return error.SqlOperationBindingChanged;
            break :blk .{ .workload = try g.database.WorkloadRead.Prepared.init(host.table, original) };
        },
        .captured => .{ .captured = try g.CapturedOperations.prepareResult(host, ref.id) },
        .table, .transaction, .dataflow, .configuration, .connector => error.InvalidSqlOperationReference,
    };
}

//! Pure response attribution and bounded decoding. Transport authenticity and
//! actual acceptance remain the service's responsibility, not a hash comparison.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const P = c.storage.TablePartition;

fn definition(connection: w.Connection, stored: c.storage.TableDeclaration.Stored) !void {
    try stored.validate();
    try connection.object(stored.interpretation.object);
}
fn frontier(position: d.Position, changed_lsn: u64) !void {
    try position.validate();
    if (position.next_lsn == 0 or changed_lsn > position.next_lsn) return error.InvalidTableResponse;
}
fn schema(allocator: std.mem.Allocator, binary: w.Binary, stored: c.storage.TableDeclaration.Stored) !void {
    const bytes = try binary.decode(allocator, c.fuze.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var decoded = try c.fuze.TableSchema.decode(allocator, bytes);
    defer decoded.deinit();
    if (decoded.schema.object != stored.interpretation.object.object or !std.mem.eql(u8, &try decoded.schema.fingerprint(), &stored.schema_fingerprint)) return error.InvalidTableResponse;
}

/// Names and native references are part of the accepted definition, not an
/// independently mutable hint attached to an otherwise valid row schema.
fn metadata(allocator: std.mem.Allocator, value: w.Definition) !void {
    const bytes = try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var decoded = try c.fuze.TableSchema.decode(allocator, bytes);
    defer decoded.deinit();
    const properties: c.DirectCatalog.Properties = .{ .namespace = value.namespace, .authorization = value.authorization, .name = value.name };
    var encoded: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
    var declaration = try c.storage.TableDeclaration.prepare(allocator, .{ .object = value.interpretation.interpretation.object, .revision = value.interpretation.interpretation.revision, .schema = decoded.schema, .properties = try properties.encode(&encoded) });
    defer declaration.deinit();
    if (!std.meta.eql(value.interpretation, try declaration.stored())) return error.InvalidTableResponse;
}
fn evidence(binding: d.Binding, value: P.Evidence) !void {
    try binding.requireSame(value.binding);
    try value.resulting.validate();
    try value.outcome.position.validate();
    if (!std.meta.eql(value.resulting.interpretation.object, binding.target) or
        value.outcome.position.next_lsn == 0 or value.outcome.affected > value.outcome.matched or
        value.resulting.retired != (binding.action == .drop)) return error.InvalidTableResponse;
    const expected_revision = switch (binding.action) {
        .create => @as(u64, 1),
        .alter, .rename, .drop => try std.math.add(u64, binding.expected_definition.?.revision, 1),
        .insert, .update, .delete => binding.expected_definition.?.revision,
    };
    if (value.resulting.interpretation.revision != expected_revision) return error.InvalidTableResponse;
    if (binding.action == .insert or binding.action == .update or binding.action == .delete) {
        if (!std.meta.eql(binding.expected_definition.?, value.resulting.interpretation)) return error.InvalidTableResponse;
    }
    if (binding.expected_data) |expected| if (value.outcome.position.partition != expected.partition or value.outcome.position.next_lsn <= expected.next_lsn) return error.InvalidTableResponse;
}
fn ddl(binding: d.Binding, value: c.DirectCatalog.Observation) !void {
    switch (value) {
        .not_observed => {},
        .committed => |result| try evidence(binding, result),
        inline .admitted, .rejected, .cancelled => |operation, tag| {
            try binding.requireSame(operation.binding);
            try operation.intent.validate();
            if ((operation.phase == .rejected) != (operation.reason != .none)) return error.InvalidTableResponse;
            const valid = switch (tag) {
                .admitted => operation.phase == .admitted or (operation.phase == .ready and binding.action == .create),
                .rejected => operation.phase == .rejected,
                .cancelled => operation.phase == .cancelled,
                else => unreachable,
            };
            if (!valid) return error.InvalidTableResponse;
        },
    }
}
fn rows(binding: d.Binding, value: P.OperationState) !void {
    switch (value) {
        .not_observed => {},
        .committed => |result| try evidence(binding, result),
        inline .admitted, .rejected, .cancelled => |operation, tag| {
            try binding.requireSame(operation.binding);
            try operation.validate();
            if (!std.mem.eql(u8, @tagName(operation.phase), @tagName(tag))) return error.InvalidTableResponse;
        },
    }
}

/// Validate each response against its exact request. Callers that consume pages
/// also bind them to the retained Source and decode FTR1 rows under its schema.
pub fn validate(allocator: std.mem.Allocator, request: w.Request, response: w.Response) !void {
    try request.validate(allocator);
    if (response.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try p.Authorization.revision(response.policy_revision);
    const subject = response.subject;
    const original = if (request.closure) |closure|
        (try closure.proof(request.delegation.?, allocator)).claim
    else if (request.borrow) |borrow| (try borrow.proof(request.delegation.?, allocator)).claim else if (request.delegation) |delegation| delegation.proof.claim else request.proof.claim;
    try p.Authorization.roleId(subject.login_role);
    try p.Authorization.roleId(subject.role);
    if (subject.principal != request.connection.principal or subject.audience != request.connection.audience or
        subject.credential_epoch != original.credential_epoch or subject.role != (request.connection.role orelse subject.login_role) or
        !std.mem.eql(u8, &subject.context, &original.context)) return error.InvalidTableResponse;
    if (!std.mem.eql(u8, &response.context, &try w.Request.context(request.input(), allocator))) return error.InvalidTableResponse;
    const expected: std.meta.Tag(w.Result) = switch (request.action) {
        .initialize => .initialized,
        .describe => .description,
        .namespace => .namespace,
        .namespaces => .namespaces,
        .check, .check_set => .checked,
        .list => .list,
        .lookup => .lookup,
        .name_assertion => .name_assertion,
        .preview => .preview,
        .stage => .staged,
        .admit_ddl => .ddl,
        .admit_rows, .admit_statement => .rows,
        inline .operation, .admit_saved => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => .ddl,
            .insert, .update, .delete => .rows,
        },
        .pin, .retain_history => .pin,
        .history_start, .history_source => .history_source,
        .history => .history,
        .history_scan => .history_page,
        .pin_status => .pin_state,
        .snapshot => .snapshot,
        .read_key => .point,
        .scan => .page,
        .release => .released,
    };
    if (std.meta.activeTag(response.result) != expected) return error.InvalidTableResponse;
    switch (response.result) {
        .name_assertion => |value| switch (value) {
            .not_observed => if (request.action.name_assertion.command != .inspect) return error.InvalidTableResponse,
            .outcome => |outcome| {
                try outcome.validate();
                try request.action.name_assertion.binding.requireSame(outcome.binding);
            },
        },
        .staged => |value| {
            const input = request.action.stage;
            var intent = try c.DirectTableIntent.create(allocator, input.intent.connection, input.intent.work);
            defer intent.deinit();
            try value.requireSame(try intent.reference(input.namespace));
        },
        .preview => |value| {
            const binding = request.action.preview.binding;
            try binding.requireSame(value.binding);
            try frontier(value.directory_position, 0);
            if ((value.reason == .none) != (value.work != null) or
                (value.work == null) != (value.schema_fingerprint == null) or
                (value.work == null and value.rebuild_key)) return error.InvalidTableResponse;
            if (value.current) |current| {
                try definition(request.connection, current.interpretation);
                if (!std.meta.eql(current.interpretation.interpretation.object, binding.target)) return error.InvalidTableResponse;
                try frontier(current.position, current.changed_lsn);
            }
            if (value.reason == .none) {
                if (binding.action == .create) {
                    if (value.current != null or value.work.? != .metadata or value.rebuild_key) return error.InvalidTableResponse;
                    const bytes = try request.action.preview.action.create.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
                    defer allocator.free(bytes);
                    var proposed = try c.fuze.TableSchema.decode(allocator, bytes);
                    defer proposed.deinit();
                    if (!std.mem.eql(u8, &try proposed.schema.fingerprint(), &value.schema_fingerprint.?)) return error.InvalidTableResponse;
                } else {
                    const current = value.current orelse return error.InvalidTableResponse;
                    if (current.interpretation.retired or !std.meta.eql(binding.expected_definition.?, current.interpretation.interpretation)) return error.InvalidTableResponse;
                    if (binding.expected_data) |basis| if (!basis.unchangedAt(current.position, current.changed_lsn)) return error.InvalidTableResponse;
                    if (binding.action == .rename or binding.action == .drop) {
                        if (value.work.? != .metadata or value.rebuild_key or !std.mem.eql(u8, &current.interpretation.schema_fingerprint, &value.schema_fingerprint.?)) return error.InvalidTableResponse;
                    }
                }
            }
        },
        .initialized, .released, .checked => {},
        .description => |value| {
            try value.validate();
            if (!request.connection.matches(value)) return error.InvalidTableResponse;
        },
        .namespace => |maybe| if (maybe) |value| {
            try value.validate();
            if (value.retired or value.id != request.action.namespace or !std.meta.eql(value.scope, request.connection.scope)) return error.InvalidTableResponse;
        },
        .namespaces => |value| {
            try frontier(value.directory_position, 0);
            var previous = request.action.namespaces.after orelse 0;
            var ended = false;
            for (value.entries) |slot| {
                const entry = slot orelse {
                    ended = true;
                    continue;
                };
                try entry.validate();
                if (ended or entry.retired or !std.meta.eql(entry.scope, request.connection.scope) or entry.id <= previous) return error.InvalidTableResponse;
                previous = entry.id;
            }
            if (value.next) |next| if (next <= (request.action.namespaces.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .lookup => |maybe| if (maybe) |value| {
            try definition(request.connection, value.interpretation);
            try value.name.validate();
            try frontier(value.position, value.changed_lsn);
            if (value.interpretation.retired or value.namespace != request.action.lookup.namespace or !std.mem.eql(u8, value.name.slice(), request.action.lookup.name)) return error.InvalidTableResponse;
            try metadata(allocator, value);
        },
        .list => |value| {
            try value.directory_position.validate();
            var previous = request.action.list.after orelse 0;
            var ended = false;
            for (value.entries) |slot| {
                const entry = slot orelse {
                    ended = true;
                    continue;
                };
                if (ended or entry.interpretation.object.object <= previous or entry.namespace != request.action.list.namespace) return error.InvalidTableResponse;
                try entry.interpretation.validate();
                try request.connection.object(entry.interpretation.object);
                try entry.name.validate();
                try frontier(entry.position, entry.changed_lsn);
                previous = entry.interpretation.object.object;
            }
            if (value.next) |next| if (next == 0 or next <= (request.action.list.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .ddl => |value| {
            const binding = switch (request.action) {
                inline .admit_ddl, .admit_saved, .operation => |work| work.binding,
                else => unreachable,
            };
            if (request.action != .operation and value == .not_observed) return error.InvalidTableResponse;
            try ddl(binding, value);
        },
        .rows => |value| {
            const binding = switch (request.action) {
                inline .admit_rows, .admit_statement, .admit_saved => |work| work.binding,
                .operation => |work| work.binding,
                else => unreachable,
            };
            if (request.action != .operation and value == .not_observed) return error.InvalidTableResponse;
            try rows(binding, value);
        },
        .pin_state => |value| {
            try value.authority.validate();
            try value.position.validate();
            if (value.position.next_lsn == 0 or (value.released and value.handle == null)) return error.InvalidTableResponse;
            if (value.handle) |handle| {
                if (!std.meta.eql(handle.owner, request.action.pin_status.owner)) return error.InvalidTableResponse;
                try handle.content.validate();
            }
        },
        .pin => |value| {
            try value.owner.validate();
            try value.content.validate();
            const acquisition = switch (request.action) {
                inline .pin, .retain_history => |input| input,
                else => unreachable,
            };
            if (!std.meta.eql(value.owner, acquisition.owner)) return error.InvalidTableResponse;
        },
        .snapshot => |value| {
            try value.authority.validate();
            if (request.delegation) |delegation| delegation.requireSource(value.interpretation.interpretation, value.accepted) catch return error.InvalidTableResponse;
            if (!std.meta.eql(value.snapshot, request.action.snapshot)) return error.InvalidTableResponse;
            try definition(request.connection, value.interpretation);
            if (!std.meta.eql(value.interpretation.interpretation.object, value.snapshot.object)) return error.InvalidTableResponse;
            try frontier(value.accepted, value.changed_lsn);
            try schema(allocator, value.schema, value.interpretation);
        },
        .point => |value| {
            if (request.delegation) |delegation| delegation.requireSource(value.interpretation.interpretation, value.accepted) catch return error.InvalidTableResponse;
            if (!std.meta.eql(value.snapshot, request.action.read_key.snapshot)) return error.InvalidTableResponse;
            try definition(request.connection, value.interpretation);
            if (!std.meta.eql(value.interpretation.interpretation.object, value.snapshot.object)) return error.InvalidTableResponse;
            try frontier(value.accepted, value.changed_lsn);
            if (value.row) |row| {
                if (value.total_rows == 0) return error.InvalidTableResponse;
                const bytes = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                defer allocator.free(bytes);
            }
        },
        .page => |value| {
            if (request.delegation) |delegation| delegation.requireSource(value.interpretation.interpretation, value.accepted) catch return error.InvalidTableResponse;
            const query = request.action.scan;
            try validatePage(allocator, request.connection, query.snapshot, query.snapshot.handle.content, query.after, query.limits, value);
        },
        .history_page => |value| {
            const query = request.action.history_scan;
            if (!std.meta.eql(value.point, query.source.point) or !std.meta.eql(value.page.accepted, value.point.position)) return error.InvalidTableResponse;
            if (request.delegation) |grant| grant.requireHistory(value.page.interpretation.interpretation, value.point.position) catch return error.InvalidTableResponse;
            try validatePage(allocator, request.connection, .{ .object = query.source.object, .handle = value.point.lease }, try value.point.cursorSource(), query.after, query.limits, value.page);
        },
        .history_source => |value| {
            _ = try value.point.cursorSource();
            const snapshot: w.Snapshot = switch (request.action) {
                .history_start => |input| input,
                .history_source => |input| blk: {
                    if (!std.meta.eql(input.point, value.point)) return error.InvalidTableResponse;
                    break :blk .{ .object = input.object, .handle = input.point.lease };
                },
                else => unreachable,
            };
            const source = value.source;
            if (!std.meta.eql(source.snapshot, snapshot) or !std.meta.eql(value.point.lease, snapshot.handle) or !std.meta.eql(source.accepted, value.point.position)) return error.InvalidTableResponse;
            try source.authority.validate();
            try definition(request.connection, source.interpretation);
            if (!std.meta.eql(source.interpretation.interpretation.object, snapshot.object)) return error.InvalidTableResponse;
            try frontier(source.accepted, source.changed_lsn);
            try schema(allocator, source.schema, source.interpretation);
            if (request.delegation) |grant| {
                grant.requireHistory(source.interpretation.interpretation, value.point.position) catch return error.InvalidTableResponse;
                if (request.action == .history_start) grant.requireSource(source.interpretation.interpretation, value.point.position) catch return error.InvalidTableResponse;
            }
        },
        .history => |value| {
            const query = request.action.history;
            if (!std.meta.eql(value.snapshot, query.snapshot) or !std.meta.eql(value.through, query.through) or value.next.partition != query.from.partition or
                value.next.next_lsn < query.from.next_lsn or value.next.next_lsn > query.through.next_lsn or
                value.scanned != @min(query.frames, query.through.next_lsn - query.from.next_lsn) or
                value.next.next_lsn - query.from.next_lsn != value.scanned or value.entries.len > value.scanned) return error.InvalidTableResponse;
            var previous = query.from.next_lsn;
            for (value.entries) |entry| {
                _ = try entry.point.cursorSource();
                try definition(request.connection, entry.interpretation);
                try frontier(entry.point.position, entry.changed_lsn);
                if (!std.meta.eql(entry.point.lease, query.snapshot.handle) or !std.meta.eql(entry.interpretation.interpretation.object, query.snapshot.object) or
                    entry.point.position.partition != query.from.partition or entry.point.position.next_lsn <= previous or entry.point.position.next_lsn > value.next.next_lsn or
                    !std.meta.eql(entry.receipt.outcome.position, entry.point.position) or entry.receipt.outcome.live_rows != entry.row_count) return error.InvalidTableResponse;
                try entry.receipt.binding.validate();
                try evidence(entry.receipt.binding, .{ .binding = entry.receipt.binding, .resulting = entry.interpretation, .outcome = entry.receipt.outcome });
                if (request.delegation) |grant| grant.requireHistory(entry.interpretation.interpretation, entry.point.position) catch return error.InvalidTableResponse;
                previous = entry.point.position.next_lsn;
            }
        },
    }
}

fn validatePage(allocator: std.mem.Allocator, connection: w.Connection, snapshot: w.Snapshot, cursor_source: d.Content, after: ?P.SnapshotCursor, limits: P.ReadLimits, value: w.Page) !void {
    if (!std.meta.eql(value.snapshot, snapshot) or value.rows.len > limits.rows or
        value.encoded_bytes > limits.encoded_bytes or value.total_rows < value.rows.len) return error.InvalidTableResponse;
    try definition(connection, value.interpretation);
    if (!std.meta.eql(value.interpretation.interpretation.object, value.snapshot.object)) return error.InvalidTableResponse;
    try frontier(value.accepted, value.changed_lsn);
    if (value.next) |next| {
        if (value.rows.len == 0 or !std.meta.eql(next.source, cursor_source)) return error.InvalidTableResponse;
        if (after) |cursor| if (std.mem.order(u8, &next.after, &cursor.after) != .gt) return error.InvalidTableResponse;
    }
    var bytes: u64 = 0;
    for (value.rows) |row| {
        const decoded = try row.decode(allocator, c.fuze.TableRow.max_bytes);
        defer allocator.free(decoded);
        bytes += decoded.len;
    }
    if (bytes != value.encoded_bytes) return error.InvalidTableResponse;
}

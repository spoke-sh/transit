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
    if (stored.kind != .table) return error.InvalidTableResponse;
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

fn workspace(request: w.Request, value: ?p.Transaction.ReadView, interpretation: d.Definition, position: d.Position, changed_lsn: u64, handle: ?P.SnapshotHandle) !void {
    const context = request.transaction orelse {
        if (value != null) return error.InvalidTableResponse;
        return;
    };
    const view = value orelse return error.InvalidTableResponse;
    try view.validate();
    try context.key.connection.owner(view.cut.begin.identity.begin);
    if (!std.meta.eql(view.revision, context.revision) or !std.meta.eql(view.source.source.interpretation, interpretation) or
        !std.meta.eql(view.source.source.accepted, position) or view.source.changed_lsn != changed_lsn) return error.InvalidTableResponse;
    if (handle) |selected| if (!std.meta.eql(selected.owner, view.cut.begin.identity.begin) or !std.meta.eql(selected.content, view.private)) return error.InvalidTableResponse;
}

fn resourceMetadata(allocator: std.mem.Allocator, connection: w.Connection, value: c.DirectCatalog.ResourceView) !void {
    try value.definition.validate();
    try connection.object(value.definition.object);
    try value.position.validate();
    if (value.position.next_lsn == 0 or !std.meta.eql(value.interpretation, try value.definition.interpretation(allocator))) return error.InvalidTableResponse;
}
fn storage(connection: w.Connection, object: d.Object, limit: u16, value: c.DirectCatalog.StorageObservation) !void {
    try definition(connection, value.interpretation);
    try frontier(value.position, value.changed_lsn);
    const pending = value.pending;
    if (!std.meta.eql(value.interpretation.interpretation.object, object) or value.position.next_lsn == 0 or
        pending.rows > limit or pending.rows > value.live_rows or (pending.rows == 0) != (pending.oldest_lsn == null) or
        (pending.rows == 0) != (pending.bytes == 0) or (!pending.complete and (pending.rows != limit or pending.rows >= value.live_rows)) or
        value.archive_through >= value.position.next_lsn or value.history_floor > value.position.next_lsn or value.next_segment == 0) return error.InvalidTableResponse;
    if (pending.oldest_lsn) |oldest| if (oldest >= value.position.next_lsn) return error.InvalidTableResponse;
    if (value.recovery_through) |through| if (through == 0 or through >= value.position.next_lsn) return error.InvalidTableResponse;
    value.maintenance.validate(.{ .next_lsn = value.position.next_lsn, .next_segment = value.next_segment, .archive = .{ .through = value.archive_through } }) catch return error.InvalidTableResponse;
}
fn evidence(binding: d.Binding, value: P.Evidence) !void {
    try binding.requireSame(value.binding);
    if (value.transaction) |decision| {
        try decision.validate();
        if (decision.outcome != .committed or binding.action != .update or
            !std.meta.eql(decision.attempt.operation, binding.identity) or
            !std.mem.eql(u8, &decision.attempt.workspace.sha256, &binding.intent)) return error.InvalidTableResponse;
    }
    try value.resulting.validate();
    if (value.resulting.kind != .table) return error.InvalidTableResponse;
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
        .stream => .stream,
        .queue => .queue,
        .transaction => .transaction,
        .record => .record,
        .client_token => .client_token,
        .client_progress => .client_progress,
        .initialize => .initialized,
        .describe => .description,
        .namespace => .namespace,
        .namespaces => .namespaces,
        .namespace_preview => .namespace_preview,
        .namespace_operation => .namespace_operation,
        .dependency_operation => .dependency_operation,
        .dependency_state => .dependency_state,
        .dependencies => .dependencies,
        .resource_preview => .resource_preview,
        .resource_operation => .resource_operation,
        .resource_lookup => .resource_lookup,
        .resource_list => .resource_list,
        .log_preview => .log_preview,
        .log_admit => .log_admitted,
        .log_operation => .log_operation,
        .log_lookup => .log_lookup,
        .log_list => .log_list,
        .log_pending => .log_pending,
        .check, .check_set => .checked,
        .list => .list,
        .lookup => .lookup,
        .observe => .observation,
        .storage => .storage,
        .flush => .flush,
        .read_current => .current_read,
        .read_authority => .read_authority,
        .name_assertion => .name_assertion,
        .preview => .preview,
        .name_preview => .name_preview,
        .preview_rows, .preview_statement => .row_preview,
        .stage => .staged,
        .admit_ddl => .ddl,
        .admit_rows, .admit_statement => .rows,
        inline .operation, .admit_saved, .commit_saved => |value| switch (value.binding.action) {
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
        .scan, .column_scan => .page,
        .filter_scan => .filtered_page,
        .key_range => .key_range,
        .release => .released,
    };
    if (std.meta.activeTag(response.result) != expected) return error.InvalidTableResponse;
    switch (response.result) {
        .stream => |value| try c.DirectStreamResponse.validate(allocator, request.connection, request.action.stream, value),
        .queue => |value| try c.DirectQueueResponse.validate(allocator, request.connection, request.action.queue, value),
        .transaction => |value| try c.DirectTransactionRequest.validateResult(request.action.transaction, value),
        .record => |value| {
            try value.reference.validate();
            const input = request.action.record;
            if (!std.meta.eql(value.reference.scope, input.scope())) return error.DataIdentityConflict;
            switch (input) {
                .stage => |staged| {
                    if (value.bytes != null) return error.InvalidTableResponse;
                    const bytes = try staged.bytes.decode(allocator, c.DirectRecord.max_bytes);
                    defer allocator.free(bytes);
                    try value.reference.requireSame(try c.DirectRecord.reference(staged.scope, staged.format, bytes));
                },
                .read => |saved| {
                    try saved.requireSame(value.reference);
                    const bytes = try (value.bytes orelse return error.InvalidTableResponse).decode(allocator, c.DirectRecord.max_bytes);
                    defer allocator.free(bytes);
                    try saved.requireSame(try c.DirectRecord.reference(saved.scope, saved.format, bytes));
                },
            }
        },
        .client_progress => |value| {
            const input = request.action.client_progress;
            if (input == .list) {
                if (value != .page) return error.InvalidTableResponse;
                var previous = input.list.after orelse 0;
                var count: usize = 0;
                var ended = false;
                for (value.page.entries) |slot| {
                    const state = slot orelse {
                        ended = true;
                        continue;
                    };
                    try state.validate();
                    if (ended or state.id() <= previous or !std.meta.eql(state.receipt.binding.key.scope(), input.scope()) or (input.list.pending and !state.pending)) return error.InvalidTableResponse;
                    previous = state.id();
                    count += 1;
                }
                if (value.page.next) |next| if (count != value.page.entries.len or next != previous) return error.InvalidTableResponse;
            } else {
                if (value != .state) return error.InvalidTableResponse;
                if (value.state) |state| {
                    try state.validate();
                    if (!std.meta.eql(state.receipt.binding.key.scope(), input.scope())) return error.DataIdentityConflict;
                    switch (input) {
                        .inspect => |key| try key.requireSame(state.receipt.binding.key),
                        .operation => |saved| if (saved.id != state.id()) return error.DataIdentityConflict,
                        .update => |saved| {
                            try saved.key.requireSame(state.receipt.binding.key);
                            if (state.pending != saved.pending or state.cancel != saved.cancel or !std.meta.eql(state.record, saved.record) or state.revision.partition != saved.expected.partition or state.revision.next_lsn < saved.expected.next_lsn) return error.InvalidTableResponse;
                        },
                        .list => unreachable,
                    }
                } else if (input == .update) return error.InvalidTableResponse;
            }
        },
        .client_token => |receipt| {
            const command = request.action.client_token;
            if (receipt) |value| {
                try value.validate();
                try command.key().requireSame(value.binding.key);
                if (command == .bind) try value.binding.retry(command.bind);
            } else if (command == .bind) return error.InvalidTableResponse;
        },
        .storage => |value| try storage(request.connection, request.action.storage.object, request.action.storage.pending_limit, value),
        .flush => |value| {
            const target = request.action.flush;
            if (!std.meta.eql(target, value.target) or value.observed.interpretation.retired or
                target.through.partition != value.observed.position.partition or target.through.next_lsn > value.observed.position.next_lsn) return error.InvalidTableResponse;
            try storage(request.connection, target.object, 1, value.observed);
            const complete = value.observed.pending.oldest_lsn == null or value.observed.pending.oldest_lsn.? >= target.through.next_lsn;
            if (value.complete != complete) return error.InvalidTableResponse;
        },
        .resource_preview => |value| {
            try request.action.resource_preview.requireSame(value.binding);
            try value.position.validate();
            if (value.position.next_lsn == 0) return error.InvalidTableResponse;
            if (value.current) |current| {
                try current.validate();
                if (!std.meta.eql(current.object, value.binding.object)) return error.InvalidTableResponse;
            }
        },
        .log_preview => |value| {
            try request.action.log_preview.binding.requireSame(value.binding);
            try value.position.validate();
            if (value.position.next_lsn == 0) return error.InvalidTableResponse;
            if (value.current) |current| {
                try current.validate();
                if (!std.meta.eql(current.stored.declaration.interpretation.object, value.binding.target)) return error.InvalidTableResponse;
            }
        },
        .log_admitted => |value| {
            try value.validate();
            try request.action.log_admit.binding.requireSame(value.binding);
        },
        .log_operation => |value| switch (value) {
            .not_observed => {},
            .operation => |operation| {
                try operation.validate();
                try request.action.log_operation.binding.requireSame(operation.binding);
            },
        },
        .log_lookup => |maybe| if (maybe) |value| {
            try c.DirectLogProtocol.validateMetadata(allocator, request.connection, value);
            const input = request.action.log_lookup;
            if (value.declaration.stored.retired or value.declaration.properties.namespace != input.namespace or !std.mem.eql(u8, value.declaration.properties.name.slice(), input.name)) return error.InvalidTableResponse;
        },
        .log_list => |page| {
            try page.position.validate();
            if (page.position.next_lsn == 0) return error.InvalidTableResponse;
            const input = request.action.log_list;
            var previous = input.after orelse 0;
            var gap = false;
            for (page.entries) |slot| {
                const value = slot orelse {
                    gap = true;
                    continue;
                };
                try value.validate();
                try request.connection.object(value.stored.declaration.interpretation.object);
                if (gap or value.stored.retired or value.properties.namespace != input.namespace or value.stored.declaration.interpretation.object.object <= previous) return error.InvalidTableResponse;
                previous = value.stored.declaration.interpretation.object.object;
            }
            if (page.next) |next| if (next <= (input.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .log_pending => |page| {
            try page.position.validate();
            if (page.position.next_lsn == 0) return error.InvalidTableResponse;
            const input = request.action.log_pending;
            var previous = input.after orelse 0;
            var gap = false;
            for (page.entries) |slot| {
                const value = slot orelse {
                    gap = true;
                    continue;
                };
                try value.validate();
                try request.connection.binding(value.binding);
                if (gap or !value.pending() or value.namespace != input.namespace or value.binding.target.object <= previous or
                    value.position.partition != page.position.partition or value.position.next_lsn > page.position.next_lsn) return error.InvalidTableResponse;
                previous = value.binding.target.object;
            }
            if (page.next) |next| if (next <= (input.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .resource_operation => |value| switch (value) {
            .not_observed => if (request.action.resource_operation.command != .inspect and request.action.resource_operation.command != .execute) return error.InvalidTableResponse,
            .operation => |operation| {
                try operation.validate();
                try request.action.resource_operation.binding.requireSame(operation.binding);
                if (request.action.resource_operation.signed_allocation) |signed| {
                    if (operation.allocation) |allocation| if (!std.meta.eql(allocation, signed.allocation)) return error.InvalidTableResponse;
                }
            },
        },
        .resource_lookup => |maybe| if (maybe) |value| {
            try resourceMetadata(allocator, request.connection, value);
            const input = request.action.resource_lookup;
            if (value.definition.namespace != input.namespace or !std.mem.eql(u8, value.definition.name.slice(), input.name)) return error.InvalidTableResponse;
        },
        .resource_list => |page| {
            try page.position.validate();
            if (page.position.next_lsn == 0) return error.InvalidTableResponse;
            const input = request.action.resource_list;
            var previous = input.after orelse 0;
            var gap = false;
            for (page.entries) |slot| {
                const value = slot orelse {
                    gap = true;
                    continue;
                };
                try resourceMetadata(allocator, request.connection, value);
                if (gap or value.definition.namespace != input.namespace or value.definition.object.object <= previous or value.position.partition != page.position.partition or value.position.next_lsn > page.position.next_lsn) return error.InvalidTableResponse;
                previous = value.definition.object.object;
            }
            if (page.next) |next| if (next <= (input.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .dependency_operation => |value| switch (value) {
            .not_observed => if (request.action.dependency_operation.command != .inspect) return error.InvalidTableResponse,
            .outcome => |outcome| {
                try outcome.validate();
                try request.action.dependency_operation.binding.requireSame(outcome.binding);
            },
        },
        .dependency_state => |state| {
            try state.edge.validate();
            try state.position.validate();
            if (state.position.next_lsn == 0 or !std.meta.eql(state.edge, request.action.dependency_state)) return error.InvalidTableResponse;
        },
        .dependencies => |page| {
            const input = request.action.dependencies;
            try page.position.validate();
            if (page.position.next_lsn == 0) return error.InvalidTableResponse;
            if (input.cursor) |cursor| if (!std.meta.eql(cursor.position, page.position)) return error.InvalidTableResponse;
            var previous: ?[32]u8 = if (input.cursor) |cursor| cursor.after else null;
            var ended = false;
            for (page.entries) |slot| {
                const edge = slot orelse {
                    ended = true;
                    continue;
                };
                if (ended) return error.InvalidTableResponse;
                try edge.validate();
                try request.connection.object(edge.source.object);
                switch (input.selection) {
                    .dependents => |object| if (!std.meta.eql(edge.source.object, object)) return error.InvalidTableResponse,
                    .dependencies => |object| if (!std.meta.eql(edge.dependent.interpretation.object, object)) return error.InvalidTableResponse,
                }
                const digest = try edge.digest();
                if (previous) |before| if (std.mem.order(u8, &before, &digest) != .lt) return error.InvalidTableResponse;
                previous = digest;
            }
            if (page.next) |cursor| {
                if (!std.meta.eql(cursor.selection, input.selection) or !std.meta.eql(cursor.position, page.position) or cursor.authority != input.authority) return error.InvalidTableResponse;
                if (input.cursor) |before| if (std.mem.order(u8, &before.after, &cursor.after) != .lt) return error.InvalidTableResponse;
                if (previous) |before| if (std.mem.order(u8, &before, &cursor.after) == .gt) return error.InvalidTableResponse;
            }
        },
        .namespace_preview => |value| {
            try request.action.namespace_preview.requireSame(value.binding);
            try value.position.validate();
            if (value.position.next_lsn == 0) return error.InvalidTableResponse;
            if (value.current) |current| {
                try current.validate();
                if (current.id != value.binding.namespace or !std.meta.eql(current.scope, request.connection.scope)) return error.InvalidTableResponse;
            }
        },
        .namespace_operation => |value| switch (value) {
            .not_observed => if (request.action.namespace_operation.command == .admit or request.action.namespace_operation.command == .cancel) return error.InvalidTableResponse,
            .operation => |operation| {
                try operation.validate();
                try request.action.namespace_operation.binding.requireSame(operation.binding);
            },
        },
        .read_authority => |value| try value.validate(),
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
        .name_preview => |value| {
            try request.action.name_preview.requireSame(value.binding);
            try frontier(value.position, 0);
            if (value.current) |current| {
                try current.validate();
                try request.connection.object(current.object);
                if (value.matches != std.meta.eql(value.binding.expected, @as(?d.Definition, current))) return error.InvalidTableResponse;
            } else if (value.matches and value.binding.expected != null) return error.InvalidTableResponse;
        },
        .row_preview => |value| {
            const binding = switch (request.action) {
                inline .preview_rows, .preview_statement => |input| input.binding,
                else => unreachable,
            };
            try binding.requireSame(value.binding);
            try frontier(value.directory_position, 0);
            try definition(request.connection, value.current.interpretation);
            if (!std.meta.eql(value.current.interpretation.interpretation.object, binding.target)) return error.InvalidTableResponse;
            try frontier(value.current.position, value.current.changed_lsn);
            const same_definition = !value.current.interpretation.retired and std.meta.eql(binding.expected_definition, @as(?d.Definition, value.current.interpretation.interpretation));
            const same_data = if (binding.expected_data) |basis| basis.unchangedAt(value.current.position, value.current.changed_lsn) else true;
            switch (value.reason) {
                .none => {
                    if (!same_definition or !same_data) return error.InvalidTableResponse;
                    const proposed_interpretation = switch (request.action) {
                        inline .preview_rows, .preview_statement => |input| input.interpretation,
                        else => unreachable,
                    };
                    if (!std.meta.eql(proposed_interpretation, value.current.interpretation)) return error.InvalidTableResponse;
                },
                .stale_definition => if (same_definition or value.current.interpretation.retired) return error.InvalidTableResponse,
                .stale_data => if (!same_definition or same_data) return error.InvalidTableResponse,
                .object_conflict => {},
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
            try workspace(request, value.workspace, value.interpretation.interpretation, value.position, value.changed_lsn, null);
            try definition(request.connection, value.interpretation);
            try value.name.validate();
            try frontier(value.position, value.changed_lsn);
            if (value.interpretation.retired or value.namespace != request.action.lookup.namespace or !std.mem.eql(u8, value.name.slice(), request.action.lookup.name)) return error.InvalidTableResponse;
            try metadata(allocator, value);
        },
        .observation => |value| {
            const input = request.action.observe;
            const found = value.definition;
            try workspace(request, found.workspace, found.interpretation.interpretation, found.position, found.changed_lsn, null);
            try definition(request.connection, found.interpretation);
            try found.name.validate();
            try frontier(found.position, found.changed_lsn);
            try value.authority.validate();
            if (found.interpretation.retired or found.namespace != input.namespace or
                !std.meta.eql(found.interpretation.interpretation, input.interpretation) or
                found.authorization != value.authority.table or (input.rows == null) != (value.page == null)) return error.InvalidTableResponse;
            try metadata(allocator, found);
            if (value.page) |page| {
                const limits = input.rows.?;
                if (page.rows.len > limits.rows or page.encoded_bytes > limits.encoded_bytes or page.rows.len > found.row_count or
                    (page.more and (page.rows.len == 0 or page.rows.len >= found.row_count)) or
                    (!page.more and page.rows.len != found.row_count)) return error.InvalidTableResponse;
                const encoded_schema = try found.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
                defer allocator.free(encoded_schema);
                var declared = try c.fuze.TableSchema.decode(allocator, encoded_schema);
                defer declared.deinit();
                var bytes: u64 = 0;
                var previous: ?[c.fuze.TableRow.Identity.encoded_bytes]u8 = null;
                for (page.rows) |row| {
                    const encoded = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                    defer allocator.free(encoded);
                    var decoded = try c.fuze.TableRow.decode(allocator, declared.schema, encoded);
                    defer decoded.deinit();
                    const identity = try decoded.identity.encode();
                    if (previous) |before| if (std.mem.order(u8, &before, &identity) != .lt) return error.InvalidTableResponse;
                    previous = identity;
                    bytes += encoded.len;
                }
                if (bytes != page.encoded_bytes) return error.InvalidTableResponse;
            }
        },
        .current_read => |value| {
            const input = request.action.read_current;
            const found = value.definition;
            try definition(request.connection, found.interpretation);
            try found.name.validate();
            try frontier(found.position, found.changed_lsn);
            try value.authority.validate();
            if (found.interpretation.retired or found.namespace != input.namespace or
                !std.meta.eql(found.interpretation.interpretation, input.interpretation) or
                found.authorization != value.authority.table or
                !input.expected.unchangedAt(found.position, found.changed_lsn) or
                !std.mem.eql(u8, @tagName(input.selection), @tagName(value.selection))) return error.InvalidTableResponse;
            try metadata(allocator, found);
            const encoded_schema = try found.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
            defer allocator.free(encoded_schema);
            var declared = try c.fuze.TableSchema.decode(allocator, encoded_schema);
            defer declared.deinit();
            switch (value.selection) {
                .key => |maybe| if (maybe) |row| {
                    if (found.row_count == 0) return error.InvalidTableResponse;
                    const key = try input.selection.key.decode(allocator, c.fuze.Collation.max_sort_key_bytes);
                    defer allocator.free(key);
                    const encoded = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                    defer allocator.free(encoded);
                    var decoded = try c.fuze.TableRow.decode(allocator, declared.schema, encoded);
                    defer decoded.deinit();
                    var actual: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
                    if (!std.mem.eql(u8, key, try decoded.row().storageKey(declared.schema, &actual))) return error.InvalidTableResponse;
                },
                .rows => |page| {
                    const selected = input.selection.rows;
                    if (page.rows.len > selected.limits.rows or page.encoded_bytes > selected.limits.encoded_bytes or page.rows.len > found.row_count or
                        (page.next != null and (page.rows.len == 0 or page.rows.len >= found.row_count)) or
                        (selected.after == null and page.next == null and page.rows.len != found.row_count) or
                        (selected.after != null and page.rows.len >= found.row_count)) return error.InvalidTableResponse;
                    var bytes: u64 = 0;
                    var previous: ?[c.fuze.TableRow.Identity.encoded_bytes]u8 = if (selected.after) |after| try after.encode() else null;
                    for (page.rows) |row| {
                        const encoded = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                        defer allocator.free(encoded);
                        var decoded = try c.fuze.TableRow.decode(allocator, declared.schema, encoded);
                        defer decoded.deinit();
                        const identity = try decoded.identity.encode();
                        if (previous) |before| if (std.mem.order(u8, &before, &identity) != .lt) return error.InvalidTableResponse;
                        previous = identity;
                        bytes += encoded.len;
                    }
                    if (bytes != page.encoded_bytes) return error.InvalidTableResponse;
                    if (page.next) |next| if (previous == null or !std.mem.eql(u8, &try next.encode(), &previous.?)) return error.InvalidTableResponse;
                },
            }
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
                inline .admit_rows, .admit_statement, .admit_saved, .commit_saved => |work| work.binding,
                .operation => |work| work.binding,
                else => unreachable,
            };
            if (request.action != .operation and value == .not_observed) return error.InvalidTableResponse;
            try rows(binding, value);
        },
        .pin_state => |value| {
            try value.authority.validate();
            try value.interpretation.validate();
            if (!std.meta.eql(value.interpretation.object, request.action.pin_status.object)) return error.InvalidTableResponse;
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
            try workspace(request, value.workspace, value.interpretation.interpretation, value.accepted, value.changed_lsn, value.snapshot.handle);
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
            switch (request.action) {
                .scan => |query| try validatePage(allocator, request.connection, query.snapshot, query.snapshot.handle.content, query.after, query.limits, value),
                .column_scan => |query| {
                    const selected = try query.projection();
                    try validatePage(allocator, request.connection, query.snapshot, try selected.cursorSource(query.snapshot.handle.content), query.after, query.limits, value);
                },
                else => unreachable,
            }
        },
        .filtered_page => |value| {
            const query = request.action.filter_scan;
            if (request.delegation) |grant| grant.requireSource(value.page.interpretation.interpretation, value.page.accepted) catch return error.InvalidTableResponse;
            try validateRowEnvelope(allocator, request.connection, query.snapshot, query.limits, value.page);
            try value.validate();
            if (value.page.next) |next| {
                if (!std.meta.eql(next.source, try P.filteredCursorFingerprint(query.snapshot.handle, query.fingerprint))) return error.InvalidTableResponse;
                if (query.after) |cursor| if (std.mem.order(u8, &next.after, &cursor.after) != .gt) return error.InvalidTableResponse;
            }
            if (value.failure) |failure| if (query.after) |cursor| if (std.mem.order(u8, &try failure.identity.encode(), &cursor.after) != .gt) return error.InvalidTableResponse;
        },
        .key_range => |value| {
            if (request.delegation) |grant| grant.requireSource(value.interpretation.interpretation, value.accepted) catch return error.InvalidTableResponse;
            const query = request.action.key_range;
            try validateRowEnvelope(allocator, request.connection, query.snapshot, query.limits, value);
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const interval = try query.interval.native(arena.allocator());
            if (value.next) |encoded| {
                const next = try encoded.native(arena.allocator());
                if (value.rows.len == 0 or !std.meta.eql(next.source, query.snapshot.handle.content) or
                    !std.mem.eql(u8, &next.interval, &try interval.fingerprint()) or !interval.contains(next.after.slice())) return error.InvalidTableResponse;
                if (query.after) |previous| {
                    const after = try previous.native(arena.allocator());
                    if (std.mem.order(u8, next.after.slice(), after.after.slice()) != .gt) return error.InvalidTableResponse;
                }
            }
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
                try evidence(entry.receipt.binding, .{ .binding = entry.receipt.binding, .resulting = entry.interpretation, .outcome = entry.receipt.outcome, .transaction = entry.receipt.transaction });
                if (request.delegation) |grant| grant.requireHistory(entry.interpretation.interpretation, entry.point.position) catch return error.InvalidTableResponse;
                previous = entry.point.position.next_lsn;
            }
        },
    }
}

fn validatePage(allocator: std.mem.Allocator, connection: w.Connection, snapshot: w.Snapshot, cursor_source: d.Content, after: ?P.SnapshotCursor, limits: P.ReadLimits, value: w.Page) !void {
    try validateRowEnvelope(allocator, connection, snapshot, limits, value);
    if (value.next) |next| {
        if (value.rows.len == 0 or !std.meta.eql(next.source, cursor_source)) return error.InvalidTableResponse;
        if (after) |cursor| if (std.mem.order(u8, &next.after, &cursor.after) != .gt) return error.InvalidTableResponse;
    }
}
fn validateRowEnvelope(allocator: std.mem.Allocator, connection: w.Connection, snapshot: w.Snapshot, limits: P.ReadLimits, value: anytype) !void {
    if (!std.meta.eql(value.snapshot, snapshot) or value.rows.len > limits.rows or
        value.encoded_bytes > limits.encoded_bytes or value.total_rows < value.rows.len) return error.InvalidTableResponse;
    try definition(connection, value.interpretation);
    if (!std.meta.eql(value.interpretation.interpretation.object, value.snapshot.object)) return error.InvalidTableResponse;
    try frontier(value.accepted, value.changed_lsn);
    var bytes: u64 = 0;
    for (value.rows) |row| {
        const decoded = try row.decode(allocator, c.fuze.TableRow.max_bytes);
        defer allocator.free(decoded);
        bytes += decoded.len;
    }
    if (bytes != value.encoded_bytes) return error.InvalidTableResponse;
}

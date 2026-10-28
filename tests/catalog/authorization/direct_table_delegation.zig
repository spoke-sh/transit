//! An unprivileged executor retains the caller's exact grant through lost
//! acquisition/closure replies, schema replacement and disk restart.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const w = c.DirectTableProtocol;
const t = std.testing;

pub const State = struct { grant: c.DirectReadDelegation, snapshot: ?w.Snapshot, authority: c.DirectReadAuthority, current_absent: c.DirectReadDelegation, current_retained: c.DirectReadDelegation };

fn executor(original: c.DirectTableClient, grant: c.DirectReadDelegation) !c.DirectTableClient {
    var client = original;
    client.delegation = grant;
    client.key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31));
    return client;
}
fn acquisition(grant: c.DirectReadDelegation) w.Action {
    return .{ .pin = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner, .expected = grant.binding.expected, .selection = grant.binding.selection } };
}
fn status(client: c.DirectTableClient, grant: c.DirectReadDelegation) !std.json.Parsed(w.Response) {
    return client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
}

pub fn prepare(client: c.DirectTableClient) !State {
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer current.deinit();
    const basis = current.value.result.lookup.?;
    const configuration = try client.call(.describe);
    defer configuration.deinit();
    const profile = configuration.value.result.description.authority;
    try t.expectEqual(profile.initial_schema, basis.namespace);
    const grant = try c.DirectReadDelegation.prepare(client, .{
        .definition = p.Growth.current_definition,
        .connection = client.connection,
        .executor = 102,
        .interpretation = basis.interpretation.interpretation,
        .expected = basis.position,
        .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 8200 },
        .retention = .snapshot,
        .purpose = @splat(23),
    });
    const delegated = try executor(client, grant);
    var unprivileged = delegated;
    unprivileged.delegation = null;
    unprivileged.connection.principal = 102;
    try t.expectError(error.AccessDenied, unprivileged.call(.describe));
    const absent = try status(delegated, grant);
    defer absent.deinit();
    try t.expect(absent.value.result.pin_state.handle == null);
    try t.expect(!absent.value.result.pin_state.released);
    // The proxy corrupts the successful reply. Retain the original grant;
    // acquisition recovery waits until after the node is restarted.
    try t.expectError(error.InvalidTableResponse, delegated.call(acquisition(grant)));
    var capture = grant.binding;
    capture.selection = .current;
    capture.owner.operation = 8201;
    const current_absent = try c.DirectReadDelegation.prepare(client, capture);
    capture.owner.operation = 8202;
    const current_retained = try c.DirectReadDelegation.prepare(client, capture);
    const retained = try (try executor(client, current_retained)).call(acquisition(current_retained));
    retained.deinit();
    return .{ .grant = grant, .snapshot = null, .authority = .{ .database = profile.database, .schema = profile.initial_schema_authority, .table = basis.authorization }, .current_absent = current_absent, .current_retained = current_retained };
}

/// A definition change before acquisition proves permanent absence. An older
/// accepted capture under the same definition still needs an explicit release.
pub fn afterAlter(client: c.DirectTableClient, state: State) !void {
    for ([_]c.DirectReadDelegation{ state.current_absent, state.current_retained }, 0..) |grant, i| {
        const delegated = try executor(client, grant);
        const before = try status(delegated, grant);
        defer before.deinit();
        try t.expect(!before.value.result.pin_state.retired);
        try t.expect(before.value.result.pin_state.interpretation.revision > grant.binding.interpretation.revision);
        try t.expectEqual(i == 1, before.value.result.pin_state.handle != null);
        try delegated.closeOriginalPin(grant.binding.interpretation.object, grant.binding.owner, grant.binding.expected, null);
        const after = try status(delegated, grant);
        defer after.deinit();
        if (i == 0) {
            try t.expect(after.value.result.pin_state.handle == null);
            try t.expectEqualDeep(before.value.result.pin_state.position, after.value.result.pin_state.position);
        } else try t.expect(after.value.result.pin_state.released);
        // A delayed original acquisition cannot reopen either closed case.
        try t.expectError(error.Conflict, delegated.call(acquisition(grant)));
    }
}

pub fn recover(client: c.DirectTableClient, state: *State) !void {
    const delegated = try executor(client, state.grant);
    const retained = try status(delegated, state.grant);
    defer retained.deinit();
    try t.expect(!retained.value.result.pin_state.released);
    state.snapshot = .{ .object = state.grant.binding.interpretation.object, .handle = retained.value.result.pin_state.handle.? };
    const retry = try delegated.call(acquisition(state.grant));
    defer retry.deinit();
    try t.expectEqualDeep(state.snapshot.?.handle, retry.value.result.pin);
    try verify(client, state.*);
}

pub fn verify(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state.grant);
    var reader = try c.DirectTableReader.open(client.allocator, delegated, state.snapshot.?);
    defer reader.deinit();
    try t.expectEqualDeep(state.grant.binding.interpretation, reader.basis.interpretation.interpretation);
    try t.expectEqualDeep(state.grant.binding.expected, reader.basis.accepted);
    try t.expectEqualDeep(state.authority, reader.basis.authority);
    // The caller checks the returned references through the native owner. An
    // executor's publication uses a separate proof addressed to its worker;
    // this Table-service proof does not grant inspection of that audience.
    const native: c.client.AuthorizationClient = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
    _ = try native.read(.{ .check = try reader.basis.authority.guard(.{ .signed = state.grant.proof }) });
    try t.expectEqual(@as(u64, 2), reader.basis.row_count);
    var page = (try reader.next(delegated, .{})).?;
    defer page.deinit();
    try t.expect(page.complete and page.count == 2);
    try t.expectEqual(@as(i128, 1), page.rows[0].?.row().cells[0].value.atom.signed);
    const payload = page.rows[0].?.row().cells[1].value.atom.bytes;
    try t.expectEqual(@as(usize, 64 * 1024), payload.len);
    for (payload, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate(i)), byte);
    try t.expectEqualStrings("bulk", page.rows[1].?.row().cells[1].value.atom.bytes);
    try t.expect(try reader.next(delegated, .{}) == null);
    const check = try delegated.call(.{ .check_set = &.{.{ .snapshot = state.snapshot.? }} });
    check.deinit();
    var wrong_frontier = state.grant.binding.expected;
    wrong_frontier.next_lsn += 1;
    // Recovering an unknown handle must validate its original acquisition;
    // a status result for the same pin owner cannot authorize a different cut.
    try t.expectError(error.TableDelegationDenied, delegated.closeOriginalPin(state.snapshot.?.object, state.grant.binding.owner, wrong_frontier, null));
    try t.expectError(error.Conflict, client.closeOriginalPin(state.snapshot.?.object, state.grant.binding.owner, wrong_frontier, null));
    try reader.check(delegated);
    try t.expectError(error.TableDelegationDenied, delegated.call(.describe));
    try t.expectError(error.TableDelegationDenied, delegated.call(.{ .lookup = .{ .namespace = 1, .name = "events" } }));
    var outside = state.snapshot.?;
    outside.handle.owner.operation += 1;
    try t.expectError(error.TableDelegationDenied, delegated.call(.{ .release = outside }));
    outside = state.snapshot.?;
    outside.object.object += 1;
    try t.expectError(error.TableDelegationDenied, delegated.call(.{ .snapshot = outside }));
    var changed = state.grant.binding;
    changed.interpretation.revision += 1;
    const wrong = try executor(client, try c.DirectReadDelegation.prepare(client, changed));
    try t.expectError(error.AccessDenied, wrong.call(.{ .snapshot = state.snapshot.? }));
    try t.expectError(error.InvalidTableDelegation, c.DirectReadDelegation.prepare(delegated, state.grant.binding));
}

pub fn close(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state.grant);
    // Closure is durable even when its response is unusable. The caller keeps
    // the same handle until the next restart verifies the terminal state.
    try t.expectError(error.InvalidTableResponse, delegated.closeOriginalPin(state.snapshot.?.object, state.grant.binding.owner, state.grant.binding.expected, state.snapshot.?.handle));
}

pub fn deniedClosure(client: c.DirectTableClient, state: State) !void {
    for ([_]c.DirectReadDelegation{ state.current_absent, state.current_retained }) |grant| {
        const delegated = try executor(client, grant);
        try t.expectError(error.AccessDenied, delegated.closeOriginalPin(grant.binding.interpretation.object, grant.binding.owner, grant.binding.expected, null));
    }
}

pub fn closed(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state.grant);
    const retained = try status(delegated, state.grant);
    defer retained.deinit();
    try t.expect(retained.value.result.pin_state.released);
    try delegated.closeOriginalPin(state.snapshot.?.object, state.grant.binding.owner, state.grant.binding.expected, state.snapshot.?.handle);
    try t.expectError(error.Conflict, delegated.call(acquisition(state.grant)));
    try t.expectError(error.Conflict, delegated.call(.{ .snapshot = state.snapshot.? }));
    for ([_]c.DirectReadDelegation{ state.current_absent, state.current_retained }, 0..) |grant, i| {
        const original = try executor(client, grant);
        try original.closeOriginalPin(grant.binding.interpretation.object, grant.binding.owner, grant.binding.expected, null);
        const observed = try status(original, grant);
        defer observed.deinit();
        if (i == 0) try t.expect(observed.value.result.pin_state.handle == null) else try t.expect(observed.value.result.pin_state.released);
        try t.expectError(error.Conflict, original.call(acquisition(grant)));
    }
}

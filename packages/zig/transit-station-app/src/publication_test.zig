const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const s = root.station;
const Pub = root.Publication;
const Turn = s.Turn;
const Store = struct {
    entries: std.AutoHashMap(p.Value, p.Value) = .init(t.allocator),
    position: u64 = 0,
    reads: usize = 0,
    fail_at: ?usize = null,
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail_at == self.reads) return error.Unavailable;
        return self.entries.get(key);
    }
    fn turn(self: *Store, principal: u64) !Turn {
        self.position += 1;
        return Turn.init(.{ .realm = 49, .principal = 77, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = self.position, .ordinal = 1, .value = try p.Value.init("proposal"), .origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 77, .generation = 3, .input = self.position, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Store, turn_value: *Turn) !void {
        try turn_value.validate();
        for (turn_value.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.entries.put(mutation.key, value) else _ = self.entries.remove(mutation.key);
        };
    }
    fn setup(self: *Store) !void {
        const owner = configured();
        var boot = try self.turn(33);
        try owner.initialize(&boot);
        try self.commit(&boot);
        for ([_]u64{ 44, 45 }) |who| {
            var grant = try self.turn(33);
            try owner.setPolicy(&grant, who, .{}, .{ .revision = .{ .value = 1 }, .publish = true });
            try self.commit(&grant);
        }
    }
    fn step(self: *Store, who: u64, proposal: Pub.Proposal, body: []const u8) !Pub.Phase {
        var input = try self.turn(who);
        const phase = try configured().step(t.allocator, &input, proposal, body);
        try self.commit(&input);
        return phase;
    }
    fn finish(self: *Store, who: u64, proposal: Pub.Proposal, body: []const u8) !void {
        var steps: usize = 0;
        while (try self.step(who, proposal, body) == .staging) {
            steps += 1;
            try t.expect(steps <= proposal.spec.chunks() + 2);
        }
    }
};
fn configured() Pub {
    return .{ .configuration = .{ .application = 9, .namespace = .{ .value = 19 }, .realm = 49, .administrator = 33, .name_digest = Pub.nameDigest("board") } };
}
fn canonicalBody(revision: u64, dense: bool) ![]u8 {
    var parsed = try root.Sql.parse(t.allocator, @embedFile("fixtures/board.sql"));
    defer parsed.deinit();
    parsed.definition.revision.value = revision;
    if (dense) parsed.definition.theme = "dense";
    var bytes: [root.Model.max_program_bytes]u8 = undefined;
    return t.allocator.dupe(u8, try root.Api.canonical(parsed.definition, &bytes));
}
fn makeProposal(operation: u64, record: u64, previous: ?Pub.Head, bytes: []const u8) !Pub.Proposal {
    const revision = if (previous) |head| head.revision.value else 0;
    return .{ .operation = .{ .value = operation }, .record = .{ .value = record }, .expected = .{ .value = revision }, .expected_digest = if (previous) |head| head.spec.digest else @splat(0), .revision = .{ .value = revision + 1 }, .spec = try s.Publication.Digest.of(Pub.format, bytes) };
}
fn mutationCount(turn: *const Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        count += 1;
    };
    return count;
}
test "cleanup continuation closes exact staging work and releases its reservation in bounded turns" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const body = try canonicalBody(1, false);
    defer t.allocator.free(body);
    const proposal = try makeProposal(51, 61, null, body);
    // Leave several complete chunks plus an interrupted half chunk.
    var begin = try store.turn(44);
    _ = try configured().beginUpload(&begin, proposal);
    try store.commit(&begin);
    for (0..7) |index| {
        var turn = try store.turn(44);
        const offset = index * s.PublicationParts.part_bytes;
        _ = try configured().appendUpload(&turn, proposal.operation, .{ .ordinal = @intCast(index / 2), .second = index % 2 != 0, .bytes = body[offset..@min(body.len, offset + s.PublicationParts.part_bytes)] });
        try store.commit(&turn);
    }
    var rounds: usize = 0;
    while (true) {
        var turn = try store.turn(44);
        const receipt = (try configured().receipt(&turn, 44, proposal.operation)).?;
        const descriptor = try s.Publication.Descriptor.decode((try turn.read(s.Publication.key(.application_definition, 19, 'r', proposal.record.value, 0))).?);
        const state: root.Native.State = .{
            .revision = .{ .value = store.position },
            .configuration = configured().configuration,
            .policy = try configured().policy(&turn, 44),
            .head = try configured().head(&turn),
            .receipt = receipt,
            .disposition = null,
            .upload = .{ .written = descriptor.written, .collected = descriptor.collected, .reserved = descriptor.reserved, .state = descriptor.state, .first_half = try turn.read(root.Records.key(9, 'x', 44, proposal.operation.value)) != null },
        };
        var wrong = proposal;
        wrong.record.value += 1;
        try t.expectError(error.ApplicationOperationConflict, root.Upload.nextCleanup(.{ .proposal = wrong, .state = state }));
        const next = (try root.Upload.nextCleanup(.{ .proposal = proposal, .state = state })) orelse {
            try t.expectEqual(Pub.Phase.abandoned, receipt.phase);
            try t.expectEqual(descriptor.written, descriptor.collected);
            try t.expect(!descriptor.reserved);
            break;
        };
        switch (next) {
            .abandon => |operation| try configured().abandon(&turn, operation),
            .collect => |operation| {
                _ = try configured().collect(&turn, operation);
            },
            else => return error.UnexpectedContinuation,
        }
        try t.expect(mutationCount(&turn) <= 4);
        try store.commit(&turn);
        rounds += 1;
        try t.expect(rounds <= 3);
    }
    try t.expectEqual(@as(usize, 3), rounds);
    var final = try store.turn(44);
    try t.expect(try configured().head(&final) == null);
}
test "independent AP1 layouts preserve full-width identities and reject unknown record data" {
    const Fixture = struct { version: u8, proposal: Pub.Proposal, proposal_hex: p.Value, receipt: Pub.Receipt, receipt_hex: p.Value, head: Pub.Head, head_hex: p.Value, key_hex: p.Value, disposition: root.PublicationFailure.Record, disposition_hex: p.Value, witness: root.PublicationFailure.Witness, witness_hex: p.Value, commands: []const struct { command: root.Request.Command, hex: p.Value } };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/publication-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    try t.expectEqual(@as(u8, 1), value.version);
    inline for (.{ .{ "proposal", "proposal_hex", 'r', Pub.Proposal }, .{ "receipt", "receipt_hex", 'o', Pub.Receipt }, .{ "head", "head_hex", 'h', Pub.Head }, .{ "disposition", "disposition_hex", 'e', root.PublicationFailure.Record }, .{ "witness", "witness_hex", 'f', root.PublicationFailure.Witness } }) |item| {
        const expected = @field(value, item[1]);
        try t.expect(expected.eql(try root.Records.encode(item[2], @field(value, item[0]))));
        try t.expectEqualDeep(@field(value, item[0]), try root.Records.decode(item[3], item[2], expected));
        var extra = expected;
        extra.data[extra.len] = 0;
        extra.len += 1;
        try t.expectError(error.InvalidApplicationRecord, root.Records.decode(item[3], item[2], extra));
        extra = expected;
        extra.data[2] = '2';
        try t.expectError(error.InvalidApplicationRecord, root.Records.decode(item[3], item[2], extra));
    }
    for (value.commands) |item| {
        try t.expect(item.hex.eql(try item.command.encode()));
        try t.expectEqualDeep(item.command, try root.Request.Command.decode(item.hex));
        _ = try (s.Frame{ .kind = .cast, .payload = item.hex }).encode();
    }
    try t.expect(value.key_hex.eql(root.Records.key(9, 'o', 44, std.math.maxInt(u64))));
    var store: Store = .{};
    defer store.entries.deinit();
    var input = try store.turn(44);
    input.delivery.input.position = 59;
    input.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try value.commands[4].command.encode() }).encode();
    try t.expectEqualDeep(value.disposition, try root.PublicationFailure.capture(&input, value.commands[4].command, .ApplicationDenied, .{}));
}
test "publication stages bounded chunks then atomically activates body head and attributed receipt" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const bytes = try canonicalBody(1, false);
    defer t.allocator.free(bytes);
    const request = try makeProposal(1, 100, null, bytes);
    try t.expectEqual(Pub.Phase.staging, try store.step(44, request, bytes));
    for (0..request.spec.chunks()) |_| {
        var input = try store.turn(44);
        try t.expectEqual(Pub.Phase.staging, try configured().step(t.allocator, &input, request, bytes));
        try t.expectEqual(@as(usize, 2), mutationCount(&input));
        try store.commit(&input);
        try t.expect(try configured().head(&input) == null);
    }
    var final = try store.turn(44);
    try t.expectEqual(Pub.Phase.applied, try configured().step(t.allocator, &final, request, bytes));
    try t.expectEqual(@as(usize, 4), mutationCount(&final));
    // An uncommitted activation is invisible to a fresh read/owner.
    var earlier = try store.turn(44);
    try t.expect(try configured().head(&earlier) == null);
    try store.commit(&final); // discard the reply; reconstruct owner and input
    var retry = try store.turn(44);
    try t.expectEqual(Pub.Phase.applied, try configured().step(t.allocator, &retry, request, bytes));
    try t.expectEqual(@as(usize, 0), mutationCount(&retry));
    const head = (try configured().head(&retry)).?;
    try t.expectEqual(@as(u64, 44), head.principal);
    try t.expectEqual(final.delivery.input.position, head.input);
    const reference = configured().reference(7, head);
    const descriptor = try reference.publication().inspect(&retry, reference.record);
    try t.expectEqual(s.Publication.State.published, descriptor.state);
    try t.expectEqual(final.delivery.input.position, descriptor.input);
    const receipt = (try configured().receipt(&retry, 44, request.operation)).?;
    try t.expectEqual(Pub.Phase.applied, receipt.phase);
    try t.expectEqual(head.input, receipt.input);
    var altered = request;
    altered.record.value += 1;
    try t.expectError(error.ApplicationIdentityConflict, configured().step(t.allocator, &retry, altered, bytes));
    try t.expectError(error.ApplicationAlreadyApplied, configured().abandon(&retry, request.operation));
}
test "competing proposals retain conflicts and cannot abandon another operator's body" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const bytes = try canonicalBody(1, false);
    defer t.allocator.free(bytes);
    const other = try canonicalBody(1, true);
    defer t.allocator.free(other);
    const first = try makeProposal(1, 100, null, bytes);
    const second = try makeProposal(1, 101, null, other);
    _ = try store.step(44, first, bytes);
    _ = try store.step(45, second, other);
    try store.finish(44, first, bytes);
    try t.expectEqual(Pub.Phase.conflict, try store.step(45, second, other));
    var close = try store.turn(45);
    try configured().abandon(&close, second.operation);
    try store.commit(&close);
    var collect = try store.turn(45);
    try t.expect(try configured().collect(&collect, second.operation));
    try store.commit(&collect);
    // A rejected stale proposal naming the winner never acquires its record.
    const spoof = try makeProposal(2, first.record.value, null, bytes);
    try t.expectEqual(Pub.Phase.conflict, try store.step(45, spoof, bytes));
    var denied_close = try store.turn(45);
    try configured().abandon(&denied_close, spoof.operation);
    try store.commit(&denied_close);
    const winner = try (s.Publication{ .domain = .application_definition, .resource = 7, .namespace = 19 }).inspect(&denied_close, first.record.value);
    try t.expectEqual(s.Publication.State.published, winner.state);
    try t.expectEqual(@as(u64, 1), (try configured().head(&denied_close)).?.revision.value);
}
test "current operator policy revokes staged and duplicate operations without changing history" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const bytes = try canonicalBody(1, false);
    defer t.allocator.free(bytes);
    const request = try makeProposal(1, 100, null, bytes);
    _ = try store.step(44, request, bytes);
    var revoke = try store.turn(33);
    try configured().setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .publish = false });
    try store.commit(&revoke);
    var denied = try store.turn(44);
    try t.expectError(error.ApplicationDenied, configured().step(t.allocator, &denied, request, bytes));
    try t.expectEqual(@as(usize, 0), mutationCount(&denied));
    try t.expectError(error.ApplicationDenied, configured().setPolicy(&denied, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .publish = true }));
    denied.delivery.input.origin = .{ .process = .{ .pid = 33, .turn = 1, .output = 1 } };
    try t.expectError(error.ApplicationDenied, configured().step(t.allocator, &denied, request, bytes));
    var restore = try store.turn(33);
    try configured().setPolicy(&restore, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .publish = true });
    try store.commit(&restore);
    try store.finish(44, request, bytes);
}
test "invalid body and failed reads cannot leak a partial application decision" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const bytes = try canonicalBody(1, false);
    defer t.allocator.free(bytes);
    const request = try makeProposal(1, 100, null, bytes);
    const malformed = "CREATE INTERFACE anything;";
    const invalid = try makeProposal(1, 100, null, malformed);
    var input = try store.turn(44);
    if (configured().step(t.allocator, &input, invalid, malformed)) |_| return error.AcceptedInvalidProgram else |_| {}
    try t.expectEqual(@as(usize, 0), mutationCount(&input));
    try t.expectError(error.ApplicationDigestMismatch, configured().step(t.allocator, &input, request, malformed));
    store.fail_at = store.reads + 3;
    try t.expectError(error.Unavailable, configured().step(t.allocator, &input, request, bytes));
    try t.expectEqual(@as(usize, 0), mutationCount(&input));
    try t.expectError(error.Unavailable, store.commit(&input));
}
test "retained interface revisions grow beyond active staging quota" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    var previous: ?Pub.Head = null;
    for (1..18) |revision| {
        const bytes = try canonicalBody(revision, revision % 2 == 0);
        defer t.allocator.free(bytes);
        const request = try makeProposal(revision, 100 + revision, previous, bytes);
        try store.finish(44, request, bytes);
        var read = try store.turn(44);
        previous = (try configured().head(&read)).?;
        try t.expectEqual(revision, previous.?.revision.value);
        const quota = try (s.Publication{ .domain = .application_definition, .resource = 7, .namespace = 19 }).budget(&read);
        try t.expectEqual(@as(u32, 0), quota.records);
    }
    var read = try store.turn(44);
    try t.expectEqual(Pub.Phase.applied, (try configured().receipt(&read, 44, .{ .value = 1 })).?.phase);
}

fn uploadParts(store: *Store, who: u64, request: Pub.Proposal, bytes: []const u8) !void {
    for (0..request.spec.chunks()) |i| {
        const size = try request.spec.size(@intCast(i));
        for (0..if (size > s.PublicationParts.part_bytes) @as(usize, 2) else 1) |part| {
            var input = try store.turn(who);
            const offset = part * s.PublicationParts.part_bytes;
            _ = try configured().appendUpload(&input, request.operation, .{ .ordinal = @intCast(i), .second = part == 1, .bytes = bytes[i * 256 + offset ..][0..@min(s.PublicationParts.part_bytes, size - offset)] });
            try t.expect(mutationCount(&input) <= 3);
            try store.commit(&input);
        }
    }
}
test "ordinary envelope parts retain exact halves and validate the whole program before visibility" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const bytes = try canonicalBody(1, false);
    defer t.allocator.free(bytes);
    const request = try makeProposal(1, 100, null, bytes);
    var start = try store.turn(44);
    _ = try configured().beginUpload(&start, request);
    try store.commit(&start);
    var half = try store.turn(44);
    _ = try configured().appendUpload(&half, request.operation, .{ .ordinal = 0, .second = false, .bytes = bytes[0..128] });
    try store.commit(&half);
    var other_path = try store.turn(44);
    try t.expectError(error.ApplicationUploadPartConflict, configured().step(t.allocator, &other_path, request, bytes));
    try t.expectError(error.IncompletePublication, configured().finishUpload(t.allocator, &other_path, request.operation));
    // A caller crash restarts from descriptor progress, resending the exact half.
    try uploadParts(&store, 44, request, bytes);
    var complete = try store.turn(44);
    try t.expectEqual(Pub.Phase.applied, try configured().finishUpload(t.allocator, &complete, request.operation));
    try t.expectEqual(@as(usize, 4), mutationCount(&complete));
    try store.commit(&complete);
    var duplicate = try store.turn(44);
    try t.expectEqual(Pub.Phase.applied, try configured().finishUpload(t.allocator, &duplicate, request.operation));
    try t.expectEqual(@as(usize, 0), mutationCount(&duplicate));
}
test "a signed unsupported program can stage bytes but never activate or acquire authority" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const invalid = "GRANT everything TO everybody;";
    const request = try makeProposal(1, 100, null, invalid);
    var start = try store.turn(44);
    _ = try configured().beginUpload(&start, request);
    try store.commit(&start);
    try uploadParts(&store, 44, request, invalid);
    var complete = try store.turn(44);
    try t.expectError(error.InvalidApplicationProgram, configured().finishUpload(t.allocator, &complete, request.operation));
    try t.expectEqual(@as(usize, 0), mutationCount(&complete));
    try t.expect(try configured().head(&complete) == null);
    const descriptor = try (s.Publication{ .domain = .application_definition, .resource = 7, .namespace = 19 }).inspect(&complete, 100);
    try t.expectEqual(s.Publication.State.staging, descriptor.state);
    try configured().abandon(&complete, request.operation);
    try store.commit(&complete);
}
test "public behavior records denial but does not turn infrastructure failure into rejection" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    var behavior: root.Behavior = .{ .allocator = t.allocator, .owner = configured() };
    const handler = behavior.interface();
    var denied = try store.turn(46);
    const command: root.Request.Command = .{ .publish = .{ .value = 1 } };
    try handler.handle(handler.context, &denied, .{ .kind = .cast, .payload = try command.encode() });
    try store.commit(&denied);
    const rejected = try root.Records.decode(root.PublicationFailure.Record, 'e', (try denied.read(root.Records.key(9, 'e', 46, denied.delivery.input.position))).?);
    try t.expectEqual(root.PublicationFailure.Reason.ApplicationDenied, rejected.reason);
    var unavailable = try store.turn(44);
    store.fail_at = store.reads + 1;
    try t.expectError(error.Unavailable, handler.handle(handler.context, &unavailable, .{ .kind = .cast, .payload = try command.encode() }));
    try t.expectEqual(@as(usize, 0), mutationCount(&unavailable));
    try t.expectError(error.Unavailable, store.commit(&unavailable));
    store.fail_at = null;
    var malformed = try store.turn(44);
    const guard = behavior.guard();
    try t.expect(try guard.reject(guard.context, &malformed));
    try t.expectEqual(@as(usize, 2), mutationCount(&malformed));
}

test "original publication conflict basis survives a new head and explicit cleanup" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const first_body = try canonicalBody(1, false);
    defer t.allocator.free(first_body);
    const first = try makeProposal(1, 100, null, first_body);
    const losing = try makeProposal(2, 101, null, first_body);
    _ = try store.step(45, losing, first_body);
    try store.finish(44, first, first_body);
    try t.expectEqual(Pub.Phase.conflict, try store.step(45, losing, first_body));
    var read = try store.turn(44);
    const original = (try configured().receipt(&read, 45, losing.operation)).?;
    try t.expectEqual(@as(u64, 1), original.conflict_basis.head.revision.value);
    try t.expectEqualSlices(u8, &first.spec.digest, &original.conflict_basis.head.digest);
    const scope: root.Native.Scope = .{ .realm = 49, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } };
    const projected = try root.PublicationDiagnostic.receipt(scope, original);
    try t.expectEqualStrings("publication.base_conflict", projected.code.slice());
    try t.expectEqual(.rejected, projected.outcome);
    try t.expectEqual(.domain_status, projected.evidence);
    try t.expectEqual(@as(u64, 1), try projected.facts[8].?.value.?.unsigned.value());
    const next_body = try canonicalBody(2, true);
    defer t.allocator.free(next_body);
    const next = try makeProposal(3, 102, try configured().head(&read), next_body);
    try store.finish(44, next, next_body);
    try t.expectEqual(Pub.Phase.conflict, try store.step(45, losing, first_body));
    var later = try store.turn(45);
    try t.expectEqualDeep(original, (try configured().receipt(&later, 45, losing.operation)).?);
    try configured().abandon(&later, losing.operation);
    try store.commit(&later);
    var cleanup = try store.turn(45);
    _ = try configured().collect(&cleanup, losing.operation);
    try store.commit(&cleanup);
    const abandoned = (try configured().receipt(&cleanup, 45, losing.operation)).?;
    try t.expectEqualDeep(original.conflict_basis, abandoned.conflict_basis);
    try t.expectEqual(original.input, abandoned.input);
    try t.expectEqual(.cancelled, (try root.PublicationDiagnostic.receipt(scope, abandoned)).outcome);
    const encoded = try root.Records.encode('o', original);
    try t.expect(encoded.len <= p.Value.max_bytes);
    const old = try p.Value.init(encoded.slice()[0 .. encoded.len - 41]);
    try t.expectError(error.EndOfStream, root.Records.decode(Pub.Receipt, 'o', old));
}

fn handleCommand(store: *Store, who: u64, command: root.Request.Command) !u64 {
    var behavior: root.Behavior = .{ .allocator = t.allocator, .owner = configured() };
    const handler = behavior.interface();
    const frame: s.Frame = .{ .kind = .cast, .payload = try command.encode() };
    var turn = try store.turn(who);
    turn.delivery.input.value = try frame.encode();
    try handler.handle(handler.context, &turn, frame);
    try store.commit(&turn);
    return turn.delivery.input.position;
}
test "rejected publication input keeps compiler context while its upload remains staging" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const body = "CREATE INTERFACE board WITH (realm = 49);";
    const proposal = try makeProposal(10, 100, null, body);
    _ = try handleCommand(&store, 44, .{ .begin = proposal });
    try uploadParts(&store, 44, proposal, body);
    const input = try handleCommand(&store, 44, .{ .publish = proposal.operation });
    var read = try store.turn(44);
    const record = try root.Records.decode(root.PublicationFailure.Record, 'e', (try read.read(root.Records.key(9, 'e', 44, input))).?);
    const witness = try root.Records.decode(root.PublicationFailure.Witness, 'f', (try read.read(root.Records.key(9, 'f', 44, input))).?);
    try t.expectEqual(root.PublicationFailure.Reason.InvalidApplicationProgram, record.reason);
    try t.expectEqualStrings("MissingInterfaceOption", record.cause.slice());
    try t.expectEqualStrings("application.missing_interface_option", record.code.slice());
    try t.expectEqualStrings("board", witness.declaration.member.slice());
    try t.expectEqualSlices(u8, &proposal.spec.digest, &witness.declaration.body_digest);
    try t.expectEqualStrings("revision", witness.declaration.option.slice());
    try t.expectEqual(@as(u32, body.len), witness.declaration.location.offset);
    try t.expectEqual(Pub.Phase.staging, (try configured().receipt(&read, 44, proposal.operation)).?.phase);
    try t.expect(try configured().head(&read) == null);
    const detail = try root.PublicationFailure.project(.{ .realm = 49, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } }, record, witness);
    try t.expectEqual(.input_rejected, detail.outcome);
    try t.expectEqual(.domain_status, detail.evidence);
    try t.expectEqual(@as(u64, 10), try detail.identity.?.id.value());
    try t.expectEqual(@as(u64, body.len), try detail.location.?.offset.value());
    for (detail.actions) |slot| if (slot) |action| try t.expect(action.kind != .correct_input and action.kind != .recompile and action.kind != .resume_exact);
}
test "input policy denial and incomplete-upload quantities retain the rejecting turn" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const body = try canonicalBody(1, false);
    defer t.allocator.free(body);
    const proposal = try makeProposal(10, 100, null, body);
    _ = try handleCommand(&store, 44, .{ .begin = proposal });
    const incomplete = try handleCommand(&store, 44, .{ .publish = proposal.operation });
    var read = try store.turn(44);
    const progress = try root.Records.decode(root.PublicationFailure.Witness, 'f', (try read.read(root.Records.key(9, 'f', 44, incomplete))).?);
    try t.expectEqual(@as(u32, 0), progress.upload.written);
    try t.expectEqual(proposal.spec.chunks(), progress.upload.required);
    var revoke = try store.turn(33);
    try configured().setPolicy(&revoke, 44, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .publish = false });
    try store.commit(&revoke);
    const denied = try handleCommand(&store, 44, .{ .publish = proposal.operation });
    const original = (try read.read(root.Records.key(9, 'f', 44, denied))).?;
    const policy = try root.Records.decode(root.PublicationFailure.Witness, 'f', original);
    try t.expectEqual(@as(u64, 2), policy.policy.actual.value);
    try t.expect(!policy.policy.publish);
    var restore = try store.turn(33);
    try configured().setPolicy(&restore, 44, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .publish = true });
    try store.commit(&restore);
    try t.expectEqualDeep(original, (try read.read(root.Records.key(9, 'f', 44, denied))).?);
    try t.expectEqual(Pub.Phase.staging, (try configured().receipt(&read, 44, proposal.operation)).?.phase);
}

test "all retained publication input reasons project bounded safe guidance" {
    var store: Store = .{};
    defer store.entries.deinit();
    var turn = try store.turn(44);
    const scope: root.Native.Scope = .{ .realm = 49, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } };
    inline for (@typeInfo(root.PublicationFailure.Reason).@"enum".field_names) |name| {
        const reason = @field(root.PublicationFailure.Reason, name);
        const record = try root.PublicationFailure.capture(&turn, .{ .publish = .{ .value = 1 } }, reason, .{});
        const encoded = try root.Records.encode('e', record);
        try t.expectEqualDeep(record, try root.Records.decode(root.PublicationFailure.Record, 'e', encoded));
        const detail = try root.PublicationFailure.project(scope, record, .none);
        try t.expectEqual(.input_rejected, detail.outcome);
        try t.expectEqual(.domain_status, detail.evidence);
        try t.expect(detail.actions[0].?.kind == .inspect_status);
        for (detail.actions) |slot| if (slot) |action| try t.expect(action.kind != .correct_input and action.kind != .recompile and action.kind != .resume_exact);
    }
}

test "retained embedded SQL positions identify the verified body and the decoded query" {
    var store: Store = .{};
    defer store.entries.deinit();
    try store.setup();
    const canonical = try canonicalBody(1, false);
    defer t.allocator.free(canonical);
    const body = try std.mem.replaceOwned(u8, t.allocator, canonical, "SELECT id, value FROM items", "SELECT FROM items");
    defer t.allocator.free(body);
    const proposal = try makeProposal(11, 101, null, body);
    _ = try handleCommand(&store, 44, .{ .begin = proposal });
    try uploadParts(&store, 44, proposal, body);
    const input = try handleCommand(&store, 44, .{ .publish = proposal.operation });
    var read = try store.turn(44);
    const record = try root.Records.decode(root.PublicationFailure.Record, 'e', (try read.read(root.Records.key(9, 'e', 44, input))).?);
    const witness = try root.Records.decode(root.PublicationFailure.Witness, 'f', (try read.read(root.Records.key(9, 'f', 44, input))).?);
    try t.expectEqualStrings("items", witness.sql.member.slice());
    try t.expectEqualSlices(u8, &proposal.spec.digest, &witness.sql.body_digest);
    try t.expectEqualStrings("query", body[witness.sql.location.offset..][0..5]);
    try t.expect(witness.sql.sql.offset <= "SELECT FROM items".len);
    try t.expect(witness.sql.location.offset > witness.sql.sql.offset);
    const projected = try root.PublicationFailure.project(.{ .realm = 49, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } }, record, witness);
    try t.expectEqualStrings("assembled interface body", projected.location.?.source.?.slice());
    try t.expectEqual(.input_rejected, projected.outcome);
    try t.expect(std.mem.startsWith(u8, projected.code.slice(), "sql."));
    try t.expectEqual(Pub.Phase.staging, (try configured().receipt(&read, 44, proposal.operation)).?.phase);
}
test "retained publication failure bounds fit two values and old bare reasons reject" {
    const Failure = root.PublicationFailure;
    const record: Failure.Record = .{ .reason = .InvalidApplicationProgram, .input = p.max_counter, .operation = .{ .value = std.math.maxInt(u64) }, .payload = @splat(1), .cause = try p.Value.init(&@as([96]u8, @splat('a'))), .code = try p.Value.init(&@as([96]u8, @splat('a'))), .category = .binding, .stage = .parse };
    try t.expectEqual(@as(usize, 249), (try root.Records.encode('e', record)).len);
    const witness: Failure.Witness = .{ .declaration = .{ .body_digest = @splat(2), .location = .{ .offset = root.Model.max_program_bytes, .line = 1, .column = root.Model.max_program_bytes + 1 }, .member = try p.Value.init(&@as([64]u8, @splat('m'))), .option = try p.Value.init(&@as([64]u8, @splat('o'))), .extra = .{ .reference = try p.Value.init(&@as([64]u8, @splat('r'))) } } };
    try t.expectEqual(@as(usize, 245), (try root.Records.encode('f', witness)).len);
    _ = try Failure.project(.{ .realm = 49, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } }, record, witness);
    try t.expectError(error.InvalidApplicationRecord, root.Records.decode(Failure.Record, 'e', try p.Value.init("ApplicationDenied")));
}

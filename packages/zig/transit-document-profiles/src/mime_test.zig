const std = @import("std");
const t = std.testing;
const Profile = @import("Profile.zig");
const Mime = @import("Mime.zig");
const Reader = @import("Reader.zig");
const Candidate = @import("Candidate.zig");

const limits: Profile.contract.Limits = .{
    .input_bytes = 1024 * 1024,
    .expanded_bytes = 1024 * 1024,
    .expansion_ratio = 1,
    .parts = 1,
    .nodes = 1024,
    .depth = 1,
    .token_bytes = 2048,
    .attributes = 32,
    .diagnostics = 1,
    .work = 2 * 1024 * 1024,
};
const Workspace = struct {
    raw: [2048]u8 = undefined,
    unfolded: [2048]u8 = undefined,
    fn get(self: *@This()) Mime.Workspace {
        return .{ .raw = &self.raw, .unfolded = &self.unfolded };
    }
};

fn partFor(descriptor: Profile.contract.Descriptor, source: []const u8) Profile.contract.Part {
    return .{ .definition = descriptor.definition, .profile = descriptor.digest, .id = 17, .bytes = source.len, .sha256 = Profile.grammar(source).sha256, .coverage = .complete, .source = null };
}

fn candidateFor(descriptor: Profile.contract.Descriptor, part: Profile.contract.Part, workspace: *Workspace) !Candidate {
    var source = try Profile.contract.Container.Commitment.init(descriptor.digest, 0);
    try source.addPart(part);
    const binding = try (Profile.contract.Candidate.Binding{
        .definition = descriptor.definition,
        .target = .{ .partition = .{ .definition = descriptor.definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(9) }, .partition = 0 }, .document = @splat(7) },
        .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 8, .operation = 9 },
        .base = null,
        .interpretation = descriptor,
        .source = try source.finish(),
        .digest = undefined,
    }).sealed();
    return Candidate.init(binding, part, .{ .mime = workspace.get() });
}

test "MIME candidate preserves duplicate fields unfolded whitespace and binary spans at every split" {
    const source = "X-A: one\r\n\t two \r\nx-a:\r\nContent-Type: application/octet-stream\r\n\r\n\x00\xff\r\n.";
    const fields = [_]struct { raw: []const u8, name: []const u8, value: []const u8 }{
        .{ .raw = "X-A: one\r\n\t two ", .name = "X-A", .value = " one\t two " },
        .{ .raw = "x-a:", .name = "x-a", .value = "" },
        .{ .raw = "Content-Type: application/octet-stream", .name = "Content-Type", .value = " application/octet-stream" },
    };
    const descriptor = try Profile.descriptor(.mime, limits);
    const part = partFor(descriptor, source);
    for (0..source.len + 1) |split| {
        var workspace: Workspace = .{};
        var candidate = try candidateFor(descriptor, part, &workspace);
        var input: [source.len]u8 = undefined;
        var offset: usize = 0;
        var field: usize = 0;
        var expected_offset: u64 = 0;
        var body = false;
        var turns: usize = 0;
        while (true) : (turns += 1) {
            try t.expect(turns < source.len * 4 + 32);
            const end = if (offset < split) split else source.len;
            @memcpy(input[0 .. end - offset], source[offset..end]);
            const step = try candidate.next(input[0 .. end - offset], end == source.len, 1);
            @memset(&input, 0xcc);
            offset += step.consumed;
            switch (step.result) {
                .event => |pending| {
                    const event = pending.event;
                    try t.expectEqual(0, event.depth);
                    try event.span.requireWithin(part.id, .raw, source.len);
                    try t.expectEqual(expected_offset, event.span.byte_start);
                    switch (event.kind) {
                        .mime_field => {
                            try t.expect(!body and field < fields.len);
                            try t.expectEqualStrings(fields[field].raw, source[event.span.byte_start..event.span.byte_end]);
                            try t.expectEqualStrings(fields[field].name, event.value);
                            try t.expectEqualStrings(fields[field].value, event.detail);
                            expected_offset = event.span.byte_end + 2;
                            field += 1;
                        },
                        .mime_headers_end => {
                            try t.expect(!body);
                            try t.expectEqual(fields.len, field);
                            try t.expectEqualStrings("\r\n", source[event.span.byte_start..event.span.byte_end]);
                            expected_offset = event.span.byte_end;
                            body = true;
                        },
                        .mime_body => {
                            try t.expect(body);
                            try t.expectEqualSlices(u8, source[event.span.byte_start..event.span.byte_end], event.value);
                            try t.expect(event.value.len != 0 and event.value.len <= 1);
                            expected_offset = event.span.byte_end;
                        },
                        else => return error.UnexpectedMimeEvent,
                    }
                    try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
                    const repeated = try candidate.next("unconsumed input", true, 1);
                    try t.expectEqual(0, repeated.consumed);
                    try t.expectEqualDeep(pending, repeated.result.event);
                    try candidate.consume(pending.ticket);
                },
                .need_input, .yield => {},
                .verified => break,
            }
        }
        try t.expect(body);
        try t.expectEqual(source.len, expected_offset);
        try t.expectEqualDeep(part, try candidate.verifiedPart());
    }
}

fn parse(source: []const u8, budget: Profile.contract.Limits, chunk: usize) !void {
    var workspace: Workspace = .{};
    var parser = try Mime.init(try Profile.descriptor(.mime, budget), 17, workspace.get());
    var offset: usize = 0;
    for (0..source.len * 4 + 32) |_| {
        const end = @min(source.len, offset + chunk);
        const step = parser.next(source[offset..end], end == source.len, 7) catch |err| {
            try t.expectEqual(parser.budget.offset, parser.failure_offset.?);
            try t.expectError(error.DocumentParserFailed, parser.next("\r\n", true, 1));
            return err;
        };
        offset += step.consumed;
        if (step.result == .complete) {
            try t.expectEqual(source.len, offset);
            try t.expectEqual(.complete, (try parser.next("", true, 1)).result);
            try t.expectError(error.DocumentParserComplete, parser.next("x", true, 1));
            return;
        }
    }
    return error.MimeDidNotFinish;
}

test "MIME refuses ambiguous header framing controls and missing separator with sticky errors" {
    const cases = [_]struct { source: []const u8, cause: anyerror }{
        .{ .source = "", .cause = error.IncompleteDocumentFrame },
        .{ .source = "X: a\r\n", .cause = error.IncompleteDocumentFrame },
        .{ .source = "X: a\r", .cause = error.IncompleteDocumentFrame },
        .{ .source = "X: a\r\n\r", .cause = error.IncompleteDocumentFrame },
        .{ .source = "X: a\n\n", .cause = error.InvalidMimeField },
        .{ .source = "X: a\rb\r\n\r\n", .cause = error.InvalidMimeFraming },
        .{ .source = "X: a\r\n\rx", .cause = error.InvalidMimeFraming },
        .{ .source = " orphan\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = ": empty-name\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = "X : space\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = "X: \x00\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = "X: \x7f\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = "X: é\r\n\r\n", .cause = error.InvalidMimeField },
        .{ .source = "X\r\n\r\n", .cause = error.InvalidMimeField },
    };
    for (cases) |case| for ([_]usize{ 1, 3, 8192 }) |chunk| {
        try t.expectError(case.cause, parse(case.source, limits, chunk));
    };
    try parse("\r\n", limits, 1);
    try parse("X:\r\n\r\n", limits, 1);
    // Field semantics and opaque body syntax are deliberately not interpreted.
    try parse("Content-Type: invalid ?\r\nX: =?opaque?=\r\n\r\n\x00\xff\r\n\r\n", limits, 3);
}

test "MIME enforces line field node token byte expansion and work bounds" {
    var line: [1005]u8 = @splat('a');
    @memcpy(line[0..2], "X:");
    @memcpy(line[998..1002], "\r\n\r\n");
    try parse(line[0..1002], limits, 17);
    @memcpy(line[998..1005], "a\r\n\r\nxx");
    try t.expectError(error.MimeLineLimitExceeded, parse(&line, limits, 17));
    const source = "X: a\r\nX: b\r\n\r\nbody";
    const cases = .{
        .{ "attributes", 1, error.DocumentAttributeLimitExceeded },
        .{ "nodes", 2, error.DocumentNodeLimitExceeded },
        .{ "token_bytes", 5, error.DocumentTokenLimitExceeded },
        .{ "input_bytes", 8, error.DocumentInputLimitExceeded },
        .{ "expanded_bytes", 9, error.DocumentExpansionLimitExceeded },
        .{ "work", 1, error.DocumentWorkLimitExceeded },
    };
    inline for (cases) |case| {
        var budget = limits;
        @field(budget, case[0]) = case[1];
        try t.expectError(case[2], parse(source, budget, 1));
    }
    var workspace: Workspace = .{};
    const descriptor = try Profile.descriptor(.mime, limits);
    try t.expectError(error.DocumentWorkspaceTooSmall, Mime.init(descriptor, 1, .{ .raw = workspace.raw[0..1], .unfolded = &workspace.unfolded }));
    var parser = try Mime.init(descriptor, 1, workspace.get());
    try t.expectError(error.InvalidDocumentWorkBudget, parser.next("", false, 0));
    try t.expect(parser.failure_offset == null);
    const caps = try Profile.capabilities(descriptor);
    try caps.require(descriptor, .parse);
    try caps.require(descriptor, .construct);
    var changed = descriptor;
    changed.encoding = .utf8;
    changed = try changed.sealed();
    try t.expectError(error.UnsupportedDocumentProfile, Profile.capabilities(changed));
}

test "MIME candidate late hash failure and cancellation cannot certify body prefixes" {
    const source = "X: one\r\n\r\nbinary\x00";
    const descriptor = try Profile.descriptor(.mime, limits);
    for (0..5) |cancel_at| {
        var workspace: Workspace = .{};
        var part = partFor(descriptor, source);
        part.sha256[0] ^= 1;
        var candidate = try candidateFor(descriptor, part, &workspace);
        var offset: usize = 0;
        var events: usize = 0;
        var ended = false;
        for (0..128) |_| {
            const step = candidate.next(source[offset..], true, 3) catch |err| {
                try t.expectEqual(0, cancel_at);
                try t.expectEqual(error.DocumentProfilePartConflict, err);
                try t.expectError(error.DocumentCandidateFailed, candidate.next("", true, 1));
                ended = true;
                break;
            };
            offset += step.consumed;
            if (step.result == .event) {
                events += 1;
                if (events == cancel_at) {
                    candidate.cancel();
                    try t.expectError(error.DocumentCandidateCancelled, candidate.next("", true, 1));
                    ended = true;
                    break;
                }
                try candidate.consume(step.result.event.ticket);
            }
        }
        try t.expect(ended);
        try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
    }
}

test "MIME body history exceeds fixed workspace without charging each chunk as a node" {
    const count = 100_000;
    const body = "\x00\xffxy";
    var budget = limits;
    budget.nodes = 1;
    budget.token_bytes = 3;
    budget.input_bytes = 2 + count * body.len;
    budget.expanded_bytes = count * body.len;
    budget.work = budget.input_bytes;
    const descriptor = try Profile.descriptor(.mime, budget);
    var part = partFor(descriptor, "");
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("\r\n");
    for (0..count) |_| hash.update(body);
    part.bytes = budget.input_bytes;
    part.sha256 = hash.finalResult();
    var raw: [3]u8 = undefined;
    var unfolded: [3]u8 = undefined;
    var reader = try Reader.init(descriptor, part, .{ .mime = .{ .raw = &raw, .unfolded = &unfolded } });
    var body_bytes: usize = 0;
    for (0..count + 1) |i| {
        const input: []const u8 = if (i == 0) "\r\n" else body;
        var offset: usize = 0;
        while (true) {
            const step = try reader.next(input[offset..], i == count, 2);
            offset += step.consumed;
            switch (step.result) {
                .event => |event| if (event.kind == .mime_body) {
                    try t.expectEqualSlices(u8, input[offset - event.value.len .. offset], event.value);
                    body_bytes += event.value.len;
                },
                .yield => {},
                .need_input, .complete => break,
            }
        }
    }
    try t.expectEqual(count * body.len, body_bytes);
    try t.expectEqualDeep(part, try reader.verifiedPart());
}

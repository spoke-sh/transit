const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const Candidate = @import("Candidate.zig");
const Profile = @import("Profile.zig");
const Reader = @import("Reader.zig");
const Event = @import("Event.zig").Event;
const Json = @import("Json.zig");
const Xml = @import("Xml.zig");

const limits: Profile.contract.Limits = .{
    .input_bytes = 1024 * 1024,
    .expanded_bytes = 1024 * 1024,
    .expansion_ratio = 1,
    .parts = 2,
    .nodes = 1024 * 1024,
    .depth = 32,
    .token_bytes = 256,
    .attributes = 16,
    .diagnostics = 1,
    .work = 16 * 1024 * 1024,
};

const Workspace = struct {
    json: [32]Json.Frame = undefined,
    xml: [32]Xml.Frame = undefined,
    token: [256]u8 = undefined,
    decoded: [256]u8 = undefined,
    names: [32 * 256]u8 = undefined,
    attributes: [16]Xml.Attribute = undefined,

    fn reader(self: *Workspace, format: Profile.contract.Format) Reader.Workspace {
        return switch (format) {
            .json => .{ .json = .{ .frames = &self.json, .token = &self.token } },
            .xml => .{ .xml = .{ .frames = &self.xml, .names = &self.names, .attributes = &self.attributes, .raw = &self.token, .decoded = &self.decoded } },
            else => unreachable,
        };
    }
};

fn partFor(descriptor: Profile.contract.Descriptor, source: []const u8) Profile.contract.Part {
    return .{ .definition = descriptor.definition, .profile = descriptor.digest, .id = 17, .bytes = source.len, .sha256 = Profile.grammar(source).sha256, .coverage = .complete, .source = null };
}

fn bindingFor(descriptor: Profile.contract.Descriptor, part: Profile.contract.Part) !Profile.contract.Candidate.Binding {
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    var source = try Profile.contract.Container.Commitment.init(descriptor.digest, 0);
    try source.addPart(part);
    return (Profile.contract.Candidate.Binding{
        .definition = descriptor.definition,
        .target = .{ .partition = .{ .definition = descriptor.definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(9) }, .partition = 0 }, .document = @splat(7) },
        .operation = .{ .scope = scope, .principal = 8, .operation = 9 },
        .base = null,
        .interpretation = descriptor,
        .source = try source.finish(),
        .digest = undefined,
    }).sealed();
}

const Expected = struct { kind: @FieldType(Event, "kind"), value: []const u8 = "", detail: []const u8 = "" };

fn checkSplits(format: Profile.contract.Format, source: []const u8, expected: []const Expected) !void {
    const descriptor = try Profile.descriptor(format, limits);
    const part = partFor(descriptor, source);
    const binding = try bindingFor(descriptor, part);
    for (0..source.len + 1) |split| {
        var workspace: Workspace = .{};
        var candidate = try Candidate.init(binding, part, workspace.reader(format));
        var input: [512]u8 = undefined;
        var offset: usize = 0;
        var events: usize = 0;
        var turns: usize = 0;
        var previous: ?Candidate.Ticket = null;
        while (true) : (turns += 1) {
            try t.expect(turns < source.len * 8 + 128);
            const end = if (offset < split) split else source.len;
            const count = end - offset;
            @memcpy(input[0..count], source[offset..end]);
            const step = try candidate.next(input[0..count], end == source.len, 1);
            @memset(&input, 0xcc); // No retained pointer into caller input.
            offset += step.consumed;
            switch (step.result) {
                .event => |pending| {
                    try t.expect(events < expected.len);
                    try t.expectEqual(expected[events].kind, pending.event.kind);
                    try t.expectEqualStrings(expected[events].value, pending.event.value);
                    try t.expectEqualStrings(expected[events].detail, pending.event.detail);
                    try pending.event.span.requireWithin(part.id, .raw, source.len);
                    try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedPart());
                    try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
                    // Backpressure cannot advance the parser, inspect new input
                    // or invalidate the pending parser-owned bytes.
                    for (0..3) |_| {
                        const repeated = try candidate.next("ignored until consumed", true, 1);
                        try t.expectEqual(0, repeated.consumed);
                        try t.expectEqualDeep(pending, repeated.result.event);
                    }
                    var wrong = pending.ticket;
                    wrong.binding[0] ^= 1;
                    try t.expectError(error.DocumentCandidateConflict, candidate.consume(wrong));
                    if (previous) |ticket| try t.expectError(error.DocumentCandidateConflict, candidate.consume(ticket));
                    try candidate.consume(pending.ticket);
                    try t.expectError(error.DocumentCandidateNoEvent, candidate.consume(pending.ticket));
                    previous = pending.ticket;
                    events += 1;
                },
                .need_input, .yield => {},
                .verified => break,
            }
        }
        try t.expectEqual(expected.len, events);
        try t.expectEqual(source.len, offset);
        try t.expectEqualDeep(part, try candidate.verifiedPart());
        try t.expectEqualDeep(binding, try candidate.verifiedBinding());
        try t.expectEqual(.verified, (try candidate.next("", true, 1)).result);
        try t.expectError(error.DocumentParserComplete, candidate.next("x", true, 1));
    }
}

test "candidate event consumption preserves ordered semantics at every input split" {
    try checkSplits(.json, "{\"a\":123456789012345678901234567890,\"a\":[null,\"x\\u263a\"]}", &.{
        .{ .kind = .object_start },                                      .{ .kind = .key, .value = "a" },
        .{ .kind = .number, .value = "123456789012345678901234567890" }, .{ .kind = .key, .value = "a" },
        .{ .kind = .array_start },                                       .{ .kind = .null_value, .value = "null" },
        .{ .kind = .string, .value = "x☺" },
        .{ .kind = .array_end },                                         .{ .kind = .object_end },
    });
    try checkSplits(.xml, "<r a='x&amp;y'>one<c/>two</r>", &.{
        .{ .kind = .element_start, .value = "r" }, .{ .kind = .attribute, .value = "a", .detail = "x&y" },
        .{ .kind = .text, .value = "one" },        .{ .kind = .element_start, .value = "c" },
        .{ .kind = .element_end, .value = "c" },   .{ .kind = .text, .value = "two" },
        .{ .kind = .element_end, .value = "r" },
    });
    try checkSplits(.json, "{}", &.{ .{ .kind = .object_start }, .{ .kind = .object_end } });
    try checkSplits(.json, "[]", &.{ .{ .kind = .array_start }, .{ .kind = .array_end } });
    try checkSplits(.json, "\"\"", &.{.{ .kind = .string }});
}

test "candidate preserves exact JSON and XML failures and rejects incomplete sources" {
    const Case = struct {
        format: Profile.contract.Format,
        source: []const u8,
        cause: anyerror,
        bad_hash: bool = false,
        missing_byte: bool = false,
    };
    const cases = [_]Case{
        .{ .format = .json, .source = "[0]", .bad_hash = true, .cause = error.DocumentProfilePartConflict },
        .{ .format = .json, .source = "[0]", .missing_byte = true, .cause = error.DocumentProfilePartConflict },
        .{ .format = .json, .source = "[0] trailing", .cause = error.TrailingDocumentBytes },
        .{ .format = .json, .source = "[0", .cause = error.IncompleteDocumentFrame },
        .{ .format = .json, .source = "", .cause = error.IncompleteDocumentFrame },
        .{ .format = .xml, .source = "<r/>", .bad_hash = true, .cause = error.DocumentProfilePartConflict },
        .{ .format = .xml, .source = "<r/>", .missing_byte = true, .cause = error.DocumentProfilePartConflict },
        .{ .format = .xml, .source = "<r/><s/>", .cause = error.TrailingDocumentBytes },
        .{ .format = .xml, .source = "<r>", .cause = error.IncompleteDocumentFrame },
        .{ .format = .xml, .source = "", .cause = error.IncompleteDocumentFrame },
    };
    for (cases) |case| {
        const descriptor = try Profile.descriptor(case.format, limits);
        const source = case.source;
        var part = partFor(descriptor, source);
        if (case.bad_hash) part.sha256[0] ^= 1;
        if (case.missing_byte) part.bytes += 1;
        var workspace: Workspace = .{};
        var candidate = try Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(case.format));
        var offset: usize = 0;
        var failed = false;
        for (0..128) |_| {
            const step = candidate.next(source[offset..], true, 1) catch |err| {
                failed = true;
                try t.expectEqual(case.cause, err);
                try t.expectEqual(err, candidate.cause.?);
                try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
                try t.expectError(error.DocumentCandidateFailed, candidate.next("", true, 1));
                candidate.cancel();
                try t.expectEqual(err, candidate.cause.?);
                break;
            };
            offset += step.consumed;
            if (step.result == .event) try candidate.consume(step.result.event.ticket);
            try t.expect(step.result != .verified);
        }
        try t.expect(failed);
    }
}

test "candidate cancellation invalidates JSON and XML before during and after verification" {
    const Case = struct { format: Profile.contract.Format, source: []const u8, events: usize };
    for ([_]Case{
        .{ .format = .json, .source = "[null,true]", .events = 4 },
        .{ .format = .xml, .source = "<r a='x'>one<c/>two</r>", .events = 7 },
    }) |case| {
        const descriptor = try Profile.descriptor(case.format, limits);
        const part = partFor(descriptor, case.source);
        // Before parsing, at each pending event, and after verified completion.
        for (0..case.events + 2) |cancel_at| {
            var workspace: Workspace = .{};
            var candidate = try Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(case.format));
            var offset: usize = 0;
            var events: usize = 0;
            var turns: usize = 0;
            while (cancel_at != 0) : (turns += 1) {
                try t.expect(turns < case.source.len * 8 + 128);
                const step = try candidate.next(case.source[offset..], true, 1);
                offset += step.consumed;
                if (step.result == .event) {
                    events += 1;
                    if (events == cancel_at) break;
                    try candidate.consume(step.result.event.ticket);
                } else if (step.result == .verified) {
                    try t.expectEqual(case.events, events);
                    _ = try candidate.verifiedBinding();
                    break;
                }
            }
            const pending = candidate.pending;
            candidate.cancel();
            candidate.cancel();
            try t.expectError(error.DocumentCandidateCancelled, candidate.next("", true, 1));
            if (pending) |event| try t.expectError(error.DocumentCandidateCancelled, candidate.consume(event.ticket));
            try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedPart());
            try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
            try t.expect(candidate.pending == null);
        }
    }
}

test "candidate refuses unsupported interpretations manifests coverage and resource exhaustion" {
    var descriptor = try Profile.descriptor(.json, limits);
    var part = partFor(descriptor, "0");
    var workspace: Workspace = .{};
    var binding = try bindingFor(descriptor, part);
    var changed = binding;
    changed.source.digest[0] ^= 1;
    changed = try changed.sealed();
    try t.expectError(error.DocumentCandidateConflict, Candidate.init(changed, part, workspace.reader(.json)));
    changed = binding;
    changed.source.relationships = 1;
    changed = try changed.sealed();
    try t.expectError(error.UnsupportedDocumentCandidateSource, Candidate.init(changed, part, workspace.reader(.json)));
    part.coverage = .prefix;
    try t.expectError(error.DocumentProfileCoverageGap, Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(.json)));
    part = partFor(descriptor, "0");
    descriptor.schema = Profile.grammar("schema");
    descriptor = try descriptor.sealed();
    part.profile = descriptor.digest;
    try t.expectError(error.UnsupportedDocumentProfile, Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(.json)));
    descriptor = try Profile.descriptor(.json, limits);
    descriptor.limits.work = 1;
    descriptor = try descriptor.sealed();
    part = partFor(descriptor, "[0]");
    binding = try bindingFor(descriptor, part);
    var candidate = try Candidate.init(binding, part, workspace.reader(.json));
    try t.expectError(error.InvalidDocumentWorkBudget, candidate.next("", false, 0));
    try t.expect(candidate.cause == null);
    const first = try candidate.next("[0]", true, 1);
    try candidate.consume(first.result.event.ticket);
    try t.expectError(error.DocumentWorkLimitExceeded, candidate.next("0]", true, 1));
    try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedPart());
}

test "candidate push sink backpressure and failure preserve local handoff boundaries" {
    const Sink = struct {
        block: bool = true,
        accepted: usize = 0,
        fail_at: ?usize = null,
        pub fn offer(self: *@This(), _: Event) !Candidate.Offered {
            if (self.fail_at == self.accepted) return error.TestSinkFailure;
            self.block = !self.block;
            if (!self.block) return .blocked;
            self.accepted += 1;
            return .consumed;
        }
    };
    const descriptor = try Profile.descriptor(.json, limits);
    const source = "[true]";
    const part = partFor(descriptor, source);
    for ([_]?usize{ null, 0, 1, 2 }) |fail_at| {
        var workspace: Workspace = .{};
        var candidate = try Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(.json));
        var sink: Sink = .{ .fail_at = fail_at };
        var offset: usize = 0;
        var blocked: usize = 0;
        while (true) {
            const step = candidate.pump(source[offset..], true, 1, &sink) catch |err| {
                try t.expectEqual(error.TestSinkFailure, err);
                try t.expectEqual(fail_at.?, sink.accepted);
                try t.expectError(error.DocumentCandidateFailed, candidate.next("", true, 1));
                try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
                break;
            };
            offset += step.consumed;
            if (step.result == .blocked) blocked += 1;
            if (step.result == .verified) {
                try t.expect(fail_at == null);
                try t.expectEqual(3, sink.accepted);
                try t.expectEqual(3, blocked);
                _ = try candidate.verifiedBinding();
                break;
            }
        }
    }
}

test "candidate streams a hundred thousand values without growing resident state" {
    const count = 100_000;
    const descriptor = try Profile.descriptor(.json, limits);
    var part = partFor(descriptor, "");
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("[");
    for (0..count) |i| hash.update(if (i + 1 == count) "0]" else "0,");
    part.bytes = 1 + 2 * count;
    part.sha256 = hash.finalResult();
    var workspace: Workspace = .{};
    var candidate = try Candidate.init(try bindingFor(descriptor, part), part, workspace.reader(.json));
    var events: usize = 0;
    for (0..count + 1) |i| {
        const source: []const u8 = if (i == 0) "[" else if (i == count) "0]" else "0,";
        var offset: usize = 0;
        while (true) {
            const step = try candidate.next(source[offset..], i == count, 1);
            offset += step.consumed;
            switch (step.result) {
                .event => |pending| {
                    try candidate.consume(pending.ticket);
                    events += 1;
                },
                .need_input, .verified => break,
                .yield => {},
            }
        }
    }
    try t.expectEqual(count + 2, events);
    try t.expectEqual(part.bytes, (try candidate.verifiedPart()).bytes);
}

test "capability discovery binds exact grammar and independently reports support" {
    for ([_]Profile.contract.Format{ .json, .xml }) |format| {
        const descriptor = try Profile.descriptor(format, limits);
        const capabilities = try Profile.capabilities(descriptor);
        try capabilities.require(descriptor, .parse);
        try capabilities.require(descriptor, .construct);
        for ([_]Profile.contract.Capability{ .validate_schema, .edit, .persist, .query, .search, .branch, .live_transport }) |capability| {
            try t.expectError(error.UnsupportedDocumentProfileCapability, capabilities.require(descriptor, capability));
        }
        var changed = descriptor;
        changed.grammar.sha256[0] ^= 1;
        changed = try changed.sealed();
        try t.expectError(error.UnsupportedDocumentProfile, Profile.capabilities(changed));
        try t.expectError(error.DocumentProfileConflict, capabilities.require(changed, .parse));
    }
}

test "candidate writer and container composition cannot certify an unread source" {
    const JsonWriter = @import("JsonWriter.zig");
    const Container = @import("Container.zig");
    const descriptor = try Profile.descriptor(.json, limits);
    const source = "[ 1, true ]";
    const expected_bytes = "[1,true]";
    var expected_part = partFor(descriptor, expected_bytes);
    expected_part.id = 18;
    const expected_binding = try bindingFor(descriptor, expected_part);
    for ([_]bool{ false, true }) |late_failure| {
        var source_part = partFor(descriptor, source);
        if (late_failure) source_part.sha256[0] ^= 1;
        var workspace: Workspace = .{};
        var candidate = try Candidate.init(try bindingFor(descriptor, source_part), source_part, workspace.reader(.json));
        var frames: [32]JsonWriter.Frame = undefined;
        var writer = try JsonWriter.init(descriptor, expected_part.id, &frames);
        var container = try Container.verify(expected_binding.source, .{ .parts = 1, .relationships = 0, .retained_bytes = expected_bytes.len, .work = 128 });
        try container.beginPart(expected_part);
        var offset: usize = 0;
        var written: usize = 0;
        var failed = false;
        while (true) {
            const step = candidate.next(source[offset..], true, 1) catch |err| {
                try t.expect(late_failure);
                try t.expectEqual(error.DocumentProfilePartConflict, err);
                failed = true;
                break;
            };
            offset += step.consumed;
            switch (step.result) {
                .event => |pending| {
                    try writer.beginEvent(pending.event);
                    while (writer.needsDrain()) {
                        var byte: [1]u8 = undefined;
                        const count = try writer.drain(&byte, 1);
                        try t.expectEqualSlices(u8, expected_bytes[written..][0..count], byte[0..count]);
                        try t.expectEqual(count, try container.append(byte[0..count], 1));
                        written += count;
                        // The reader cannot advance while the writer borrows an event.
                        try t.expectEqual(0, (try candidate.next("", false, 1)).consumed);
                    }
                    try candidate.consume(pending.ticket);
                },
                .verified => break,
                .need_input, .yield => {},
            }
        }
        try t.expectEqual(late_failure, failed);
        try t.expectEqualDeep(expected_part, try writer.finish());
        try container.endPart();
        try t.expectEqualDeep(expected_binding.source, try container.finish());
        if (failed) {
            // Even fully generated and locally hashed output must be discarded.
            try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
        } else try t.expectEqualDeep(source_part, try candidate.verifiedPart());
    }
}

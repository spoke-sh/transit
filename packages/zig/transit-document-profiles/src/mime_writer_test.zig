const std = @import("std");
const t = std.testing;
const Profile = @import("Profile.zig");
const Writer = @import("MimeWriter.zig");
const Reader = @import("Reader.zig");
const Candidate = @import("Candidate.zig");
const Event = @import("Event.zig").Event;

const limits: Profile.contract.Limits = .{
    .input_bytes = 1024 * 1024,
    .expanded_bytes = 1024 * 1024,
    .expansion_ratio = 1,
    .parts = 1,
    .nodes = 1024,
    .depth = 1,
    .token_bytes = 4096,
    .attributes = 32,
    .diagnostics = 1,
    .work = 4 * 1024 * 1024,
};

fn repeated(comptime byte: u8, comptime count: usize) *const [count]u8 {
    return comptime &@as([count]u8, @splat(byte));
}

fn drain(writer: *Writer, out: []u8, used: *usize, window: usize) !void {
    while (writer.needsDrain()) {
        const count = try writer.drain(out[used.*..][0..@min(window, out.len - used.*)], 3);
        try t.expect(count != 0 and count <= @min(window, 3));
        used.* += count;
    }
}

fn partFor(descriptor: Profile.contract.Descriptor, source: []const u8) Profile.contract.Part {
    return .{ .definition = descriptor.definition, .profile = descriptor.digest, .id = 17, .bytes = source.len, .sha256 = Profile.grammar(source).sha256, .coverage = .complete, .source = null };
}

fn verifiedReader(descriptor: Profile.contract.Descriptor, part: Profile.contract.Part, bytes: []const u8) !void {
    var raw: [4096]u8 = undefined;
    var unfolded: [4096]u8 = undefined;
    var reader = try Reader.init(descriptor, part, .{ .mime = .{ .raw = &raw, .unfolded = &unfolded } });
    var offset: usize = 0;
    for (0..bytes.len * 3 + 32) |_| {
        const step = try reader.next(bytes[offset..], true, 1);
        offset += step.consumed;
        if (step.result == .complete) {
            try t.expectEqual(bytes.len, offset);
            try t.expectEqualDeep(part, try reader.verifiedPart());
            return;
        }
    }
    return error.MimeWriterReadDidNotFinish;
}

test "MIME construction preserves fields and binary bodies in tiny output windows" {
    const descriptor = try Profile.descriptor(.mime, limits);
    const expected = "X: one\t two \r\nx:\r\n\r\n\x00\xff\r\nbody";
    for (1..18) |window| {
        var header: [4096]u8 = undefined;
        var writer = try Writer.init(descriptor, 19, &header);
        var out: [1024]u8 = undefined;
        var used: usize = 0;
        var name = [_]u8{'X'};
        var value = " one\t two ".*;
        try writer.begin(.{ .field = .{ .name = &name, .value = &value } });
        // Field inputs are staged; reusing them cannot change pending output.
        @memset(&name, '?');
        @memset(&value, '?');
        try t.expectError(error.DocumentWriterBusy, writer.begin(.headers_end));
        try t.expectError(error.DocumentWriterBusy, writer.finish());
        try t.expectError(error.InvalidDocumentWorkBudget, writer.drain(out[0..0], 1));
        try t.expectError(error.InvalidDocumentWorkBudget, writer.drain(&out, 0));
        try drain(&writer, &out, &used, window);
        try writer.begin(.{ .field = .{ .name = "x", .value = "" } });
        try drain(&writer, &out, &used, window);
        try writer.begin(.headers_end);
        try drain(&writer, &out, &used, window);
        try writer.begin(.{ .body = "" });
        try t.expect(!writer.needsDrain());
        try t.expectError(error.DocumentWriterNoToken, writer.drain(&out, 1));
        try writer.begin(.{ .body = "\x00\xff\r\nbody" });
        try drain(&writer, &out, &used, window);
        try t.expectEqualStrings(expected, out[0..used]);
        const part = try writer.finish();
        try t.expectEqual(19, part.id);
        try t.expectEqual(expected.len, part.bytes);
        try t.expectEqualDeep(Profile.grammar(expected).sha256, part.sha256);
        try t.expectEqualDeep(part, try writer.finish());
        try t.expectError(error.DocumentWriterComplete, writer.begin(.{ .body = "x" }));
        try verifiedReader(descriptor, part, out[0..used]);
    }
}

test "MIME construction folds only at existing whitespace and preserves exact unfolded values" {
    const descriptor = try Profile.descriptor(.mime, limits);
    const value = repeated('a', 996) ++ " " ++ repeated('b', 997) ++ "\tccccc";
    const expected = "X:" ++ repeated('a', 996) ++ "\r\n " ++ repeated('b', 997) ++ "\r\n\tccccc\r\n\r\n";
    var header: [4096]u8 = undefined;
    var writer = try Writer.init(descriptor, 19, &header);
    var out: [4096]u8 = undefined;
    var used: usize = 0;
    try writer.begin(.{ .field = .{ .name = "X", .value = value } });
    try drain(&writer, &out, &used, 1);
    try writer.begin(.headers_end);
    try drain(&writer, &out, &used, 1);
    try t.expectEqualStrings(expected, out[0..used]);
    try verifiedReader(descriptor, try writer.finish(), out[0..used]);

    // Folding immediately after the colon is required when the name fills the
    // first physical line. Continuation whitespace is never dropped.
    writer = try Writer.init(descriptor, 19, &header);
    used = 0;
    try writer.begin(.{ .field = .{ .name = repeated('N', 997), .value = " x" } });
    try drain(&writer, &out, &used, 7);
    try t.expectEqualStrings(repeated('N', 997) ++ ":\r\n x\r\n", out[0..used]);

    writer = try Writer.init(descriptor, 19, &header);
    used = 0;
    try writer.begin(.{ .field = .{ .name = "X", .value = repeated(' ', 2000) } });
    try drain(&writer, &out, &used, 17);
    try t.expectEqualStrings("X:" ++ repeated(' ', 996) ++ "\r\n" ++ repeated(' ', 998) ++ "\r\n" ++ repeated(' ', 6) ++ "\r\n", out[0..used]);

    const bad = [_]Writer.Token{
        .{ .field = .{ .name = repeated('N', 998), .value = "" } },
        .{ .field = .{ .name = "X", .value = repeated('a', 997) } },
        .{ .field = .{ .name = "X", .value = " " ++ repeated('a', 998) } },
    };
    for (bad) |token| {
        writer = try Writer.init(descriptor, 19, &header);
        try t.expectError(error.MimeLineLimitExceeded, writer.begin(token));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    // A flattened value fits, but required folding exceeds the token budget.
    var small = limits;
    small.token_bytes = 1003;
    writer = try Writer.init(try Profile.descriptor(.mime, small), 19, &header);
    try t.expectError(error.DocumentTokenLimitExceeded, writer.begin(.{ .field = .{ .name = "X", .value = repeated('a', 996) ++ " bb" } }));
}

test "MIME construction rejects injection invalid event shapes and broken sequencing" {
    const descriptor = try Profile.descriptor(.mime, limits);
    var header: [4096]u8 = undefined;
    for ([_][]const u8{ "", "X:", "X Y", "X\tY", "é", "\x00", "\x7f" }) |name| {
        var writer = try Writer.init(descriptor, 19, &header);
        try t.expectError(error.InvalidMimeField, writer.begin(.{ .field = .{ .name = name, .value = "" } }));
        try t.expectError(error.DocumentWriterFailed, writer.begin(.headers_end));
    }
    for ([_][]const u8{ "a\r\nInjected: x", "a\r\n b", "\r", "\n", "\x00", "\x7f", "é" }) |value| {
        var writer = try Writer.init(descriptor, 19, &header);
        try t.expectError(error.InvalidMimeField, writer.begin(.{ .field = .{ .name = "X", .value = value } }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    const span: Profile.contract.Span = .{ .part_id = 1, .space = .raw, .byte_start = 0, .byte_end = 2 };
    const bad_events = [_]Event{
        .{ .kind = .mime_headers_end, .span = span, .depth = 1 },
        .{ .kind = .mime_headers_end, .span = span, .depth = 0, .value = "x" },
        .{ .kind = .mime_headers_end, .span = span, .depth = 0, .detail = "x" },
        .{ .kind = .mime_body, .span = span, .depth = 0 },
        .{ .kind = .mime_body, .span = span, .depth = 0, .value = "x", .detail = "x" },
        .{ .kind = .string, .span = span, .depth = 0, .value = "x" },
    };
    for (bad_events) |event| {
        var writer = try Writer.init(descriptor, 19, &header);
        try t.expectError(error.InvalidDocumentEvent, writer.beginEvent(event));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    var writer = try Writer.init(descriptor, 19, &header);
    try t.expectError(error.IncompleteDocumentFrame, writer.finish());
    try t.expectError(error.DocumentWriterFailed, writer.begin(.headers_end));
    writer = try Writer.init(descriptor, 19, &header);
    try t.expectError(error.InvalidMimeFraming, writer.begin(.{ .body = "body" }));
    for ([_]Writer.Token{ .headers_end, .{ .field = .{ .name = "X", .value = "late" } } }) |token| {
        writer = try Writer.init(descriptor, 19, &header);
        try writer.begin(.headers_end);
        var out: [2]u8 = undefined;
        _ = try writer.drain(&out, 2);
        try t.expectError(error.InvalidMimeFraming, writer.begin(token));
    }
}

test "MIME construction enforces workspace cumulative quotas and late drain failure" {
    var header: [4096]u8 = undefined;
    const cases = .{
        .{ "token_bytes", 5, error.DocumentTokenLimitExceeded },
        .{ "input_bytes", 5, error.DocumentInputLimitExceeded },
        .{ "expanded_bytes", 2, error.DocumentExpansionLimitExceeded },
        .{ "work", 1, error.DocumentWorkLimitExceeded },
    };
    inline for (cases) |case| {
        var budget = limits;
        @field(budget, case[0]) = case[1];
        var writer = try Writer.init(try Profile.descriptor(.mime, budget), 19, &header);
        try t.expectError(case[2], writer.begin(.{ .field = .{ .name = "X", .value = " a" } }));
        try t.expectError(error.DocumentWriterFailed, writer.finish());
    }
    inline for (.{ "attributes", "nodes" }) |field| {
        var budget = limits;
        @field(budget, field) = 1;
        var writer = try Writer.init(try Profile.descriptor(.mime, budget), 19, &header);
        var out: [16]u8 = undefined;
        var used: usize = 0;
        try writer.begin(.{ .field = .{ .name = "X", .value = "" } });
        try drain(&writer, &out, &used, 3);
        if (comptime std.mem.eql(u8, field, "attributes")) {
            try t.expectError(error.DocumentAttributeLimitExceeded, writer.begin(.{ .field = .{ .name = "Y", .value = "" } }));
        } else try t.expectError(error.DocumentNodeLimitExceeded, writer.begin(.headers_end));
    }
    var budget = limits;
    budget.work = 6;
    var writer = try Writer.init(try Profile.descriptor(.mime, budget), 19, &header);
    try writer.begin(.{ .field = .{ .name = "X", .value = " a" } });
    var out: [16]u8 = undefined;
    try t.expectEqual(2, try writer.drain(&out, 2));
    try t.expectError(error.DocumentWorkLimitExceeded, writer.drain(&out, 1));
    try t.expectError(error.DocumentWriterFailed, writer.finish());

    const descriptor = try Profile.descriptor(.mime, limits);
    try t.expectError(error.DocumentWorkspaceTooSmall, Writer.init(descriptor, 19, header[0..1]));
    try t.expectError(error.DocumentWorkspaceTooSmall, Writer.init(descriptor, 0, &header));
    var changed = descriptor;
    changed.encoding = .utf8;
    try t.expectError(error.UnsupportedDocumentProfile, Writer.init(try changed.sealed(), 19, &header));
    writer = try Writer.init(descriptor, 19, &header);
    try writer.begin(.headers_end);
    _ = try writer.drain(&out, 2);
    try t.expectError(error.DocumentTokenLimitExceeded, writer.begin(.{ .body = repeated('x', 4097) }));
}

test "MIME candidate construction does not turn complete output into verified source" {
    const source = "X: one\r\n\t two\r\n\r\nbody\x00\xff";
    const expected = "X: one\t two\r\n\r\nbody\x00\xff";
    const descriptor = try Profile.descriptor(.mime, limits);
    for ([_]bool{ false, true }) |corrupt| {
        var part = partFor(descriptor, source);
        if (corrupt) part.sha256[0] ^= 1;
        var manifest = try Profile.contract.Container.Commitment.init(descriptor.digest, 0);
        try manifest.addPart(part);
        const binding = try (Profile.contract.Candidate.Binding{
            .definition = descriptor.definition,
            .target = .{ .partition = .{ .definition = descriptor.definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(9) }, .partition = 0 }, .document = @splat(7) },
            .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 8, .operation = 9 },
            .base = null,
            .interpretation = descriptor,
            .source = try manifest.finish(),
            .digest = undefined,
        }).sealed();
        var raw: [4096]u8 = undefined;
        var unfolded: [4096]u8 = undefined;
        var candidate = try Candidate.init(binding, part, .{ .mime = .{ .raw = &raw, .unfolded = &unfolded } });
        var header: [4096]u8 = undefined;
        var writer = try Writer.init(descriptor, 19, &header);
        var out: [128]u8 = undefined;
        var used: usize = 0;
        var offset: usize = 0;
        var source_verified = false;
        for (0..256) |_| {
            const step = candidate.next(source[offset..], true, 3) catch |err| {
                try t.expect(corrupt);
                try t.expectEqual(error.DocumentProfilePartConflict, err);
                break;
            };
            offset += step.consumed;
            switch (step.result) {
                .event => |pending| {
                    try writer.beginEvent(pending.event);
                    try drain(&writer, &out, &used, 1);
                    try candidate.consume(pending.ticket);
                    if (offset == source.len) {
                        _ = try writer.finish();
                        try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding());
                    }
                },
                .verified => {
                    source_verified = true;
                    break;
                },
                .need_input, .yield => {},
            }
        }
        try t.expectEqual(!corrupt, source_verified);
        try t.expectEqualStrings(expected, out[0..used]);
        const generated = try writer.finish();
        try t.expectEqualDeep(Profile.grammar(expected).sha256, generated.sha256);
        if (corrupt) try t.expectError(error.IncompleteDocumentFrame, candidate.verifiedBinding()) else try t.expectEqualDeep(binding, try candidate.verifiedBinding());
    }
}

test "MIME construction streams body history through fixed workspace and one logical node" {
    const count = 100_000;
    const body = "\x00\xffxy";
    var budget = limits;
    budget.nodes = 1;
    budget.token_bytes = 4;
    budget.input_bytes = 2 + count * body.len;
    budget.expanded_bytes = count * body.len;
    budget.work = 3 + count * (1 + body.len);
    var header: [4]u8 = undefined;
    var writer = try Writer.init(try Profile.descriptor(.mime, budget), 19, &header);
    var expected = std.crypto.hash.sha2.Sha256.init(.{});
    var observed = std.crypto.hash.sha2.Sha256.init(.{});
    var out: [2]u8 = undefined;
    var total: usize = 0;
    for (0..count + 1) |i| {
        if (i == 0) try writer.begin(.headers_end) else try writer.begin(.{ .body = body });
        expected.update(if (i == 0) "\r\n" else body);
        while (writer.needsDrain()) {
            const bytes = try writer.drain(&out, 1);
            observed.update(out[0..bytes]);
            total += bytes;
        }
    }
    const part = try writer.finish();
    try t.expectEqual(budget.input_bytes, total);
    try t.expectEqual(total, part.bytes);
    try t.expectEqualDeep(expected.finalResult(), part.sha256);
    try t.expectEqualDeep(part.sha256, observed.finalResult());
    try t.expectEqual(budget.work, writer.work);
}

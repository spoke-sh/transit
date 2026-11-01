const std = @import("std");
const t = std.testing;
const Json = @import("Json.zig");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;

pub const limits: Profile.contract.Limits = .{
    .input_bytes = 1024 * 1024,
    .expanded_bytes = 1024 * 1024,
    .expansion_ratio = 1,
    .parts = 1,
    .nodes = 1024 * 1024,
    .depth = 32,
    .token_bytes = 256,
    .attributes = 16,
    .diagnostics = 1,
    .work = 4 * 1024 * 1024,
};

const Expected = struct {
    kind: @FieldType(Event, "kind"),
    value: []const u8 = "",
    start: u64,
    end: u64,
    depth: u32,
};

fn expectParse(input: []const u8, split: usize, expected: []const Expected) !void {
    var frames: [32]Json.Frame = undefined;
    var token: [256]u8 = undefined;
    var parser = try Json.init(try Profile.descriptor(.json, limits), 42, &frames, &token);
    var offset: usize = 0;
    var events: usize = 0;
    var first = true;
    var turns: usize = 0;
    while (turns < input.len * 3 + 10) : (turns += 1) {
        const end = if (first) split else input.len;
        const step = try parser.next(input[offset..end], !first, 3);
        offset += step.consumed;
        switch (step.result) {
            .event => |event| {
                try t.expect(events < expected.len);
                const wanted = expected[events];
                try t.expectEqual(wanted.kind, event.kind);
                try t.expectEqualStrings(wanted.value, event.value);
                try t.expectEqual(wanted.start, event.span.byte_start);
                try t.expectEqual(wanted.end, event.span.byte_end);
                try t.expectEqual(wanted.depth, event.depth);
                try t.expectEqual(@as(u64, 42), event.span.part_id);
                events += 1;
            },
            .need_input => {
                try t.expect(first);
                try t.expectEqual(split, offset);
                first = false;
            },
            .yield => try t.expect(step.consumed > 0),
            .complete => {
                try t.expect(!first);
                try t.expectEqual(input.len, offset);
                try t.expectEqual(expected.len, events);
                try t.expectEqual(@as(u64, input.len), parser.budget.offset);
                try t.expectEqual(.complete, (try parser.next("", true, 1)).result);
                try t.expectError(error.DocumentParserComplete, parser.next("0", true, 1));
                return;
            },
        }
    }
    return error.ParserDidNotComplete;
}

test "JSON scalar reference preserves exact spans duplicate keys and numbers at every split" {
    const input = " {\"a\":[null,true,-1.20e+03],\"a\":\"x\\n\"} ";
    const expected = [_]Expected{
        .{ .kind = .object_start, .start = 1, .end = 2, .depth = 0 },
        .{ .kind = .key, .value = "a", .start = 2, .end = 5, .depth = 1 },
        .{ .kind = .array_start, .start = 6, .end = 7, .depth = 1 },
        .{ .kind = .null_value, .value = "null", .start = 7, .end = 11, .depth = 2 },
        .{ .kind = .boolean, .value = "true", .start = 12, .end = 16, .depth = 2 },
        .{ .kind = .number, .value = "-1.20e+03", .start = 17, .end = 26, .depth = 2 },
        .{ .kind = .array_end, .start = 26, .end = 27, .depth = 1 },
        .{ .kind = .key, .value = "a", .start = 28, .end = 31, .depth = 1 },
        .{ .kind = .string, .value = "x\n", .start = 32, .end = 37, .depth = 1 },
        .{ .kind = .object_end, .start = 37, .end = 38, .depth = 0 },
    };
    for (0..input.len + 1) |split| try expectParse(input, split, &expected);
}

test "JSON UTF-8 escaped scalars and empty strings survive one-byte fragments" {
    const input = "[\"\",\"é\\uD834\\uDD1E\\u0000\",0]";
    const expected = [_]Expected{
        .{ .kind = .array_start, .start = 0, .end = 1, .depth = 0 },
        .{ .kind = .string, .start = 1, .end = 3, .depth = 1 },
        .{ .kind = .string, .value = "é𝄞\x00", .start = 4, .end = 26, .depth = 1 },
        .{ .kind = .number, .value = "0", .start = 27, .end = 28, .depth = 1 },
        .{ .kind = .array_end, .start = 28, .end = 29, .depth = 0 },
    };
    for (0..input.len + 1) |split| try expectParse(input, split, &expected);
}

fn finish(parser: *Json, input: []const u8, chunk: usize) !void {
    var offset: usize = 0;
    var turns: usize = 0;
    while (turns < input.len * 3 + 10) : (turns += 1) {
        const end = @min(input.len, offset + chunk);
        const step = try parser.next(input[offset..end], end == input.len, 7);
        offset += step.consumed;
        if (step.result == .complete) return;
    }
    return error.ParserDidNotComplete;
}

test "JSON malformed input never completes and failures are sticky" {
    const invalid = [_][]const u8{
        "",           " ",         "[",      "{\"a\":",        "[1,]",        "{,}",          "{\"a\":0,}",         "01",           "1.",               "-",                    "1e",              "1e+",      "1e-",              "1x",
        "true false", "trux",      "false0", "\"\\x\"",        "\"\\uDC00\"", "\"\\uD800a\"", "\"\\uD800\\u0000\"", "\"\xc0\x80\"", "\"\xed\xa0\x80\"", "\"\xf4\x90\x80\x80\"", "\"\xc2\\u0080\"", "\"\x01\"", "\xef\xbb\xbfnull", "[}",
        "{]",         "{\"a\" 1}", "[1 2]",  "\"unterminated", "NaN",         "Infinity",
    };
    for (invalid) |input| {
        for ([_]usize{ 1, 2, 17 }) |chunk| {
            var frames: [32]Json.Frame = undefined;
            var token: [256]u8 = undefined;
            var parser = try Json.init(try Profile.descriptor(.json, limits), 1, &frames, &token);
            if (finish(&parser, input, chunk)) |_| return error.InvalidInputAccepted else |err| {
                try t.expect(err != error.ParserDidNotComplete);
                try t.expect(parser.failure_offset != null);
                try t.expectError(error.DocumentParserFailed, parser.next("null", true, 1));
            }
        }
    }
}

test "JSON refuses descriptor drift and each active budget without allocating" {
    var frames: [32]Json.Frame = undefined;
    var token: [256]u8 = undefined;
    var descriptor = try Profile.descriptor(.json, limits);
    try t.expectError(error.DocumentWorkspaceTooSmall, Json.init(descriptor, 1, frames[0..1], &token));
    descriptor.grammar.sha256[0] ^= 1;
    descriptor = try descriptor.sealed();
    try t.expectError(error.UnsupportedDocumentProfile, Json.init(descriptor, 1, &frames, &token));
    const Case = struct { field: []const u8, value: u32, input: []const u8, expected: anyerror };
    inline for (.{
        Case{ .field = "input_bytes", .value = 1, .input = "[]", .expected = error.DocumentInputLimitExceeded },
        Case{ .field = "expanded_bytes", .value = 1, .input = "\"ab\"", .expected = error.DocumentExpansionLimitExceeded },
        Case{ .field = "nodes", .value = 1, .input = "[0]", .expected = error.DocumentNodeLimitExceeded },
        Case{ .field = "depth", .value = 1, .input = "[[]]", .expected = error.DocumentDepthLimitExceeded },
        Case{ .field = "token_bytes", .value = 1, .input = "\"ab\"", .expected = error.DocumentTokenLimitExceeded },
        Case{ .field = "token_bytes", .value = 3, .input = "true", .expected = error.DocumentTokenLimitExceeded },
        Case{ .field = "work", .value = 1, .input = "[]", .expected = error.DocumentWorkLimitExceeded },
    }) |case| {
        var bounded = limits;
        @field(bounded, case.field) = case.value;
        var parser = try Json.init(try Profile.descriptor(.json, bounded), 1, &frames, &token);
        try t.expectError(case.expected, finish(&parser, case.input, 1));
        try t.expect(parser.failed);
    }
}

test "JSON input cardinality is independent of parser workspace" {
    var frames: [32]Json.Frame = undefined;
    var token: [256]u8 = undefined;
    var parser = try Json.init(try Profile.descriptor(.json, limits), 1, &frames, &token);
    try t.expectEqual(.object_start, (try parser.next("{", false, 1)).result.event.kind);
    const field = "\"a\":0,";
    for (0..100_000) |_| {
        var offset: usize = 0;
        while (offset < field.len) {
            const step = try parser.next(field[offset..], false, 3);
            offset += step.consumed;
        }
    }
    try finish(&parser, "\"z\":null}", 1);
    try t.expectEqual(@as(u64, 200_003), parser.budget.nodes);
    try t.expectEqual(@as(usize, 32), parser.frames.len);
    try t.expectEqual(@as(usize, 256), parser.token.len);
}

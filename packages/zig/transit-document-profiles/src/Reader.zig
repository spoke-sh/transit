//! Verify a complete retained part and its interpretation together. Intermediate
//! events confer no completeness; they may precede a late parse/hash refusal.
const std = @import("std");
const Profile = @import("Profile.zig");
const Json = @import("Json.zig");
const Xml = @import("Xml.zig");
const Step = @import("Event.zig").Step;
const Self = @This();

pub const Workspace = union(enum) {
    json: struct { frames: []Json.Frame, token: []u8 },
    xml: Xml.Workspace,
};
const Parser = union(enum) { json: Json, xml: Xml };
part: Profile.contract.Part,
parser: Parser,
hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
observed: u64 = 0,
finished: bool = false,
failed: bool = false,

pub fn init(descriptor: Profile.contract.Descriptor, part: Profile.contract.Part, workspace: Workspace) !Self {
    try descriptor.validate();
    try part.requireExact();
    if (!std.mem.eql(u8, &part.profile, &descriptor.digest)) return error.DocumentProfilePartConflict;
    if (part.bytes > descriptor.limits.input_bytes) return error.DocumentInputLimitExceeded;
    const parser: Parser = switch (workspace) {
        .json => |value| .{ .json = try Json.init(descriptor, part.id, value.frames, value.token) },
        .xml => |value| .{ .xml = try Xml.init(descriptor, part.id, value) },
    };
    return .{ .part = part, .parser = parser };
}

pub fn next(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    if (work == 0) return error.InvalidDocumentWorkBudget;
    if (self.failed) return error.DocumentReaderFailed;
    if (self.finished) {
        if (input.len != 0) return error.DocumentParserComplete;
        return .{ .consumed = 0, .result = .complete };
    }
    return self.advance(input, eof, work) catch |err| {
        self.failed = true;
        return err;
    };
}

fn advance(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    // A caller must never supply a tail outside the descriptor's declared part.
    if (input.len > self.part.bytes - self.observed) return error.DocumentProfilePartConflict;
    const step = switch (self.parser) {
        inline else => |*parser| try parser.next(input, eof, work),
    };
    self.hash.update(input[0..step.consumed]);
    self.observed += step.consumed;
    if (step.result == .complete) {
        if (self.observed != self.part.bytes) return error.DocumentProfilePartConflict;
        if (!std.mem.eql(u8, &self.hash.finalResult(), &self.part.sha256)) return error.DocumentProfilePartConflict;
        self.finished = true;
    }
    return step;
}

pub fn verifiedPart(self: *const Self) !Profile.contract.Part {
    if (!self.finished or self.failed) return error.IncompleteDocumentFrame;
    return self.part;
}

test "part completion binds exact source bytes rather than a valid replacement document" {
    const t = std.testing;
    const limits = @import("json_test.zig").limits;
    const descriptor = try Profile.descriptor(.json, limits);
    const input = "[0]";
    var part = Profile.contract.Part{
        .definition = descriptor.definition,
        .profile = descriptor.digest,
        .id = 1,
        .bytes = input.len,
        .sha256 = Profile.grammar(input).sha256,
        .coverage = .complete,
        .source = null,
    };
    var frames: [32]Json.Frame = undefined;
    var token: [256]u8 = undefined;
    const workspace: Workspace = .{ .json = .{ .frames = &frames, .token = &token } };
    for ([_][]const u8{ input, "[1]", "0", "[0] " }) |source| {
        var reader = try init(descriptor, part, workspace);
        try t.expectError(error.IncompleteDocumentFrame, reader.verifiedPart());
        var offset: usize = 0;
        var complete = false;
        while (true) {
            const step = reader.next(source[offset..], true, 1) catch |err| {
                try t.expectEqual(error.DocumentProfilePartConflict, err);
                try t.expectError(error.DocumentReaderFailed, reader.next("", true, 1));
                break;
            };
            offset += step.consumed;
            if (step.result == .complete) {
                complete = true;
                break;
            }
            try t.expectError(error.IncompleteDocumentFrame, reader.verifiedPart());
        }
        try t.expectEqual(std.mem.eql(u8, source, input), complete);
        if (complete) {
            try t.expectEqualDeep(part, try reader.verifiedPart());
            try t.expectEqual(.complete, (try reader.next("", true, 1)).result);
            try t.expectError(error.DocumentParserComplete, reader.next(" ", true, 1));
        }
    }
    part.coverage = .redacted;
    try t.expectError(error.DocumentProfileCoverageGap, init(descriptor, part, workspace));
    part.coverage = .prefix;
    try t.expectError(error.DocumentProfileCoverageGap, init(descriptor, part, workspace));
    part.coverage = .complete;
    part.profile[0] ^= 1;
    try t.expectError(error.DocumentProfilePartConflict, init(descriptor, part, workspace));
}

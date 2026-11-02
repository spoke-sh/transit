const std = @import("std");
const p = @import("transit_protocol");
const Profile = @import("Profile.zig");
const Container = @import("Container.zig");
const t = std.testing;
const contract = Profile.contract.Container;
const Fixture = struct { manifest: contract.Manifest, parts: []const Profile.contract.Part, relationships: []const contract.Relationship };
const limits: Container.Limits = .{ .parts = 100_000, .relationships = 100_000, .retained_bytes = 1_000_000, .work = 1_000_000 };

fn part(id: u64, bytes: []const u8) Profile.contract.Part {
    return .{ .definition = p.Growth.current_definition, .profile = @splat(1), .id = id, .bytes = bytes.len, .sha256 = Profile.grammar(bytes).sha256, .coverage = .complete, .source = null };
}

fn feed(builder: *Container, value: Profile.contract.Part, bytes: []const u8, chunk: usize, work: u32) !void {
    try builder.beginPart(value);
    var offset: usize = 0;
    while (offset != bytes.len) {
        const end = @min(bytes.len, offset + chunk);
        const consumed = try builder.append(bytes[offset..end], work);
        try t.expect(consumed <= work);
        try t.expect(consumed > 0);
        offset += consumed;
    }
    try builder.endPart();
}

test "container independent metadata and local bytes survive every small split" {
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, contract.fixture_json);
    defer parsed.deinit();
    const sample = parsed.value;
    for (1..5) |chunk| {
        var builder = try Container.verify(sample.manifest, limits);
        try t.expectError(error.IncompleteDocumentFrame, builder.verifiedManifest());
        for (sample.parts) |value| {
            try feed(&builder, value, if (value.bytes == 0) "" else "123", chunk, 1);
            try t.expectError(error.IncompleteDocumentFrame, builder.verifiedManifest());
        }
        for (sample.relationships) |relationship| try builder.addRelationship(relationship);
        try t.expectEqualDeep(sample.manifest, try builder.finish());
        try t.expectEqualDeep(sample.manifest, try builder.verifiedManifest());
        try t.expectEqualDeep(sample.manifest, try builder.finish());
        try t.expectError(error.DocumentProfileCoverageGap, (try builder.finish()).requireExact());
        try t.expectError(error.DocumentContainerComplete, builder.beginPart(part(1, "")));
        try t.expectEqualDeep(sample.manifest, try builder.verifiedManifest());
    }
}

test "container constant resident state does not bound directory cardinality" {
    var builder = try Container.init(@splat(1), 99_999, limits);
    for (0..100_000) |ordinal| try feed(&builder, part(ordinal + 1, "x"), "x", 1, 1);
    for (0..100_000) |ordinal| try builder.addRelationship(.{ .kind = .references, .from = ordinal, .to = .{ .local = (ordinal + 1) % 100_000 }, .label = null });
    const result = try builder.finish();
    try result.requireExact();
    try t.expectEqual(@as(u64, 100_000), result.parts);
    try t.expectEqual(@as(u64, 100_000), result.relationships);
    try t.expectEqual(@as(u64, 100_000), result.retained_bytes);
    try t.expectEqual(@as(u64, 400_001), builder.work);
}

test "container replacement bytes incomplete parts and sticky refusals" {
    for ([_][]const u8{ "124", "12", "1234" }) |bytes| {
        var builder = try Container.init(@splat(1), 0, limits);
        try builder.beginPart(part(1, "123"));
        if (bytes.len == 4) {
            try t.expectError(error.DocumentProfilePartConflict, builder.append(bytes, 1));
        } else {
            _ = try builder.append(bytes, 10);
            if (bytes.len == 2) {
                try t.expectError(error.IncompleteDocumentFrame, builder.endPart());
            } else try t.expectError(error.DocumentProfilePartConflict, builder.endPart());
        }
        try t.expectError(error.DocumentContainerFailed, builder.finish());
        try t.expectError(error.DocumentContainerFailed, builder.beginPart(part(1, "123")));
        try t.expectError(error.DocumentContainerFailed, builder.verifiedManifest());
    }
    var builder = try Container.init(@splat(1), 0, limits);
    try builder.beginPart(part(1, "123"));
    try t.expectError(error.InvalidDocumentWorkBudget, builder.append("123", 0));
    try t.expect(!builder.failed);
    _ = try builder.append("123", 3);
    try builder.endPart();
    try (try builder.finish()).requireExact();
}

test "container ordering root endpoint and phase controls" {
    var builder = try Container.init(@splat(1), 0, limits);
    try feed(&builder, part(2, ""), "", 1, 1);
    try t.expectError(error.DocumentProfilePartOrder, builder.beginPart(part(2, "")));
    builder = try Container.init(@splat(1), 0, limits);
    try feed(&builder, part(2, ""), "", 1, 1);
    try t.expectError(error.DocumentProfilePartOrder, builder.beginPart(part(1, "")));
    builder = try Container.init(@splat(1), 1, limits);
    try feed(&builder, part(1, ""), "", 1, 1);
    try t.expectError(error.InvalidDocumentProfileManifest, builder.finish());
    for ([_]bool{ false, true }) |bad_from| {
        builder = try Container.init(@splat(1), 0, limits);
        try feed(&builder, part(1, ""), "", 1, 1);
        try t.expectError(error.DocumentProfileRelationshipConflict, builder.addRelationship(.{ .kind = .contains, .from = if (bad_from) 1 else 0, .to = .{ .local = if (bad_from) 0 else 1 }, .label = null }));
    }
    builder = try Container.init(@splat(1), 0, limits);
    try feed(&builder, part(1, ""), "", 1, 1);
    try builder.addRelationship(.{ .kind = .references, .from = 0, .to = .{ .local = 0 }, .label = null });
    try t.expectError(error.DocumentProfilePartOrder, builder.beginPart(part(2, "")));
    builder = try Container.init(@splat(1), 0, limits);
    try builder.beginPart(part(1, ""));
    try t.expectError(error.DocumentContainerPartActive, builder.beginPart(part(2, "")));
    builder = try Container.init(@splat(1), 0, limits);
    try builder.beginPart(part(1, ""));
    try t.expectError(error.IncompleteDocumentFrame, builder.finish());
}

test "container declared limits and work exhaustion never produce a manifest" {
    var bounded = limits;
    bounded.parts = 1;
    var builder = try Container.init(@splat(1), 0, bounded);
    try feed(&builder, part(1, ""), "", 1, 1);
    try t.expectError(error.DocumentProfileContainerLimitExceeded, builder.beginPart(part(2, "")));
    bounded = limits;
    bounded.retained_bytes = 2;
    builder = try Container.init(@splat(1), 0, bounded);
    try t.expectError(error.DocumentProfileContainerLimitExceeded, builder.beginPart(part(1, "123")));
    bounded = limits;
    bounded.relationships = 0;
    builder = try Container.init(@splat(1), 0, bounded);
    try feed(&builder, part(1, ""), "", 1, 1);
    try t.expectError(error.DocumentProfileContainerLimitExceeded, builder.addRelationship(.{ .kind = .references, .from = 0, .to = .{ .local = 0 }, .label = null }));
    bounded = limits;
    bounded.work = 3;
    builder = try Container.init(@splat(1), 0, bounded);
    try feed(&builder, part(1, "x"), "x", 1, 1);
    try t.expectError(error.DocumentWorkLimitExceeded, builder.finish());
    try t.expectError(error.DocumentContainerFailed, builder.verifiedManifest());
    bounded.work = 1;
    builder = try Container.init(@splat(1), 0, bounded);
    try builder.beginPart(part(1, "x"));
    try t.expectError(error.DocumentWorkLimitExceeded, builder.append("x", 1));
}

test "container final manifest detects a metadata or relationship replacement" {
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, contract.fixture_json);
    defer parsed.deinit();
    const sample = parsed.value;
    for (0..5) |mutation| {
        var builder = try Container.verify(sample.manifest, limits);
        for (sample.parts, 0..) |value, index| {
            var changed = value;
            if (mutation == 0 and index == 0) changed.profile[0] ^= 1;
            if (mutation == 1 and index == 1) changed.source = null;
            try feed(&builder, changed, if (value.bytes == 0) "" else "123", 2, 1);
        }
        for (sample.relationships, 0..) |value, index| {
            if (mutation == 2 and index == 1) continue;
            var changed = value;
            if (mutation == 3 and index == 1) changed.to.external.revision.revision -= 1;
            if (mutation == 4 and index == 1) changed.label = null;
            try builder.addRelationship(changed);
        }
        try t.expectError(error.DocumentProfileManifestConflict, builder.finish());
        try t.expectError(error.DocumentContainerFailed, builder.verifiedManifest());
    }
}

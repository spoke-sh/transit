const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const doc = p.DocumentOperation;

fn fixture() !std.json.Parsed(doc.SchemaTypes) {
    return p.Json.parseFromSlice(doc.SchemaTypes, t.allocator, @embedFile("fixtures/document-v1.json"));
}

test "document fixture roundtrips and preserves wide identities and separate logical revisions" {
    const parsed = try fixture();
    defer parsed.deinit();
    const v = parsed.value;
    try v.declaration.validate();
    try v.mutation.validate();
    try v.replica.validate();
    try v.checkpoint.validate();
    try v.read.validate();
    try v.read_cursor.requireReceipt(v.read);
    try v.read_release.validate();
    try t.expectEqual(std.math.maxInt(u64) - 1, v.mutation.accepted_revision);
    try t.expectEqual(@as(u32, 0), v.mutation.mutation.target.partition.partition);
    try t.expectEqual(@as(u64, 93), v.mutation.accepted.partition);
    try t.expectEqual(@as(u64, 15), v.mutation.accepted.next_lsn);
    try t.expectEqual(std.math.maxInt(u64), v.mutation.mutation.lineage.replica.?.sequence);
    const encoded = try p.Json.valueAlloc(t.allocator, v);
    defer t.allocator.free(encoded);
    const roundtrip = try p.Json.parseFromSlice(doc.SchemaTypes, t.allocator, encoded);
    defer roundtrip.deinit();
    try t.expectEqualDeep(v, roundtrip.value);
}

test "document mutation receipt refuses modified payload lineage target or operation" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.mutation;
    try receipt.requireMutation(receipt.mutation);
    inline for (.{ "payload", "epoch", "operation", "partition", "document", "schema" }) |field| {
        var changed = receipt.mutation;
        if (comptime std.mem.eql(u8, field, "payload")) changed.payload.sha256[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "epoch")) changed.lineage.merge_epoch += 1;
        if (comptime std.mem.eql(u8, field, "operation")) changed.operation.operation -= 1;
        if (comptime std.mem.eql(u8, field, "partition")) changed.target.partition.partition += 1;
        if (comptime std.mem.eql(u8, field, "document")) changed.target.document[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "schema")) changed.target.partition.interpretation.digest[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "epoch")) {
            try t.expectError(error.InvalidDocumentLineage, receipt.requireMutation(changed));
        } else {
            try t.expectError(error.DocumentMutationConflict, receipt.requireMutation(changed));
        }
    }
    var invalid = receipt;
    invalid.accepted_revision = invalid.mutation.lineage.base_revision;
    try t.expectError(error.InvalidDocumentMutationReceipt, invalid.validate());
    invalid = receipt;
    invalid.accepted.next_lsn = 0;
    try t.expectError(error.InvalidDocumentMutationReceipt, invalid.validate());
}

test "document versioned three way lineage validates distinct parents and raw span provenance" {
    const parsed = try fixture();
    defer parsed.deinit();
    var mutation = parsed.value.mutation.mutation;
    mutation.lineage = .{
        .profile = .versioned,
        .merge_epoch = 3,
        .base_revision = 10,
        .parent_revision = 14,
        .replica = null,
        .raw_span = .{ .part_id = 2, .byte_start = 128, .byte_end = 512 },
    };
    try mutation.validate();
    mutation.lineage.parent_revision = 10;
    try t.expectError(error.InvalidDocumentLineage, mutation.validate());
    mutation.lineage.parent_revision = 14;
    mutation.lineage.raw_span = .{ .part_id = 2, .byte_start = 512, .byte_end = 128 };
    try t.expectError(error.InvalidDocumentRawSpan, mutation.validate());
}

test "document replica floors fence epochs sequence gaps other principals and discarded receipts" {
    const parsed = try fixture();
    defer parsed.deinit();
    var mutation = parsed.value.mutation.mutation;
    mutation.lineage.merge_epoch = 1;
    mutation.lineage.replica.?.epoch = 1;
    mutation.lineage.replica.?.sequence = 1;
    mutation.lineage.replica.?.preceding_sequence = 0;
    const initial = try doc.ReplicaState.initial(mutation);
    try t.expectEqual(.retry, try initial.check(mutation));
    mutation.lineage.replica.?.sequence = 3;
    mutation.lineage.replica.?.preceding_sequence = 2;
    try t.expectError(error.DocumentReplicaSequenceGap, initial.check(mutation));
    mutation.lineage.replica.?.sequence = 2;
    mutation.lineage.replica.?.preceding_sequence = 1;
    try t.expectEqual(.apply, try initial.check(mutation));
    mutation.target.partition.interpretation.revision += 1;
    try t.expectEqual(.apply, try initial.check(mutation));
    mutation.operation.principal += 1;
    try t.expectError(error.DocumentReplicaConflict, initial.check(mutation));
    mutation.operation.principal -= 1;
    mutation.lineage.merge_epoch = 2;
    mutation.lineage.replica.?.epoch = 2;
    try t.expectError(error.DocumentReplicaSequenceGap, initial.check(mutation));
    mutation.lineage.replica.?.sequence = 1;
    mutation.lineage.replica.?.preceding_sequence = 0;
    try t.expectEqual(.advance_epoch, try initial.check(mutation));
    const renewed = try doc.ReplicaState.initial(mutation);
    mutation.lineage.merge_epoch = 1;
    mutation.lineage.replica.?.epoch = 1;
    try t.expectError(error.DocumentReplicaFenced, renewed.check(mutation));
    const expired = try initial.forgetThrough(1);
    try t.expectError(error.DocumentReplicaReceiptExpired, expired.check(mutation));
    try t.expectError(error.InvalidDocumentReplicaFloor, expired.forgetThrough(0));
}

test "document finite merge window checkpoints and retained reads enforce cut bounds" {
    const parsed = try fixture();
    defer parsed.deinit();
    const checkpoint_receipt = parsed.value.checkpoint;
    try checkpoint_receipt.requireCheckpoint(checkpoint_receipt.checkpoint);
    var changed_cp = checkpoint_receipt.checkpoint;
    changed_cp.retained_from -= 1;
    try t.expectError(error.DocumentCheckpointConflict, checkpoint_receipt.requireCheckpoint(changed_cp));

    const read_receipt = parsed.value.read;
    try read_receipt.validate();
    const initial = try read_receipt.initialCoverage();
    try t.expect(!initial.complete);
    try t.expectEqual(initial.from_revision, initial.next_revision);
    try t.expectEqual(@as(u32, 0), initial.steps);

    var request = read_receipt.request;
    request.through_revision = read_receipt.through_revision;
    try t.expectError(error.DocumentReadConflict, read_receipt.requireRequest(request));

    var cursor = parsed.value.read_cursor;
    cursor.read.source.sha256[0] ^= 1;
    try t.expectError(error.DocumentReadConflict, cursor.requireReceipt(read_receipt));
    cursor = parsed.value.read_cursor;
    cursor.authentication = @splat(0);
    try t.expectError(error.InvalidDocumentCursor, cursor.validate());

    var release = parsed.value.read_release.release;
    release.operation = release.read.owner;
    try t.expectError(error.InvalidDocumentRelease, release.validate());
}

test "document persisted binding has no missing or foreign definition fallback" {
    const parsed = try fixture();
    defer parsed.deinit();
    const bytes = try p.Json.valueAlloc(t.allocator, parsed.value.mutation.mutation.target.partition);
    defer t.allocator.free(bytes);
    const comma = std.mem.indexOfScalar(u8, bytes, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{bytes[comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(doc.Partition, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[at] = if (foreign[at] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(doc.Partition, t.allocator, foreign));
}

const std = @import("std");
const t = std.testing;
const f = @import("transit_fuze");
const s = @import("root.zig");
const D = s.DocumentDeclaration;

const sample_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "doc_key", .type = .utf8, .nullable = false, .collation = .ascii_ci },
    .{ .id = 2, .name = "severity", .type = .int64, .nullable = true },
};

fn sampleDefinition() D.Definition {
    return .{
        .object = .{
            .scope = .{ .realm = 1, .resource = 2, .catalog = 3 },
            .branch = 1,
            .object = 501,
        },
        .revision = 1,
        .schema = .{
            .object = 501,
            .revision = 1,
            .next_column = 3,
            .columns = &sample_columns,
        },
        .configuration = .{
            .partitioning = .{ .count = 4, .key_column = 1, .hash = .sha256_64 },
            .profile = .causal_crdt,
            .shredding = .{
                .frequent_path_threshold = 64,
                .max_shredded_columns = 32,
                .default_collation = .utf8_binary,
            },
            .retention = .{
                .max_age_ms = 86_400_000,
                .merge_window_revisions = 1024,
            },
        },
        .limits = .{
            .change_bytes = 65_536,
            .operations_per_change = 64,
            .path_depth = 32,
            .read_steps = 4096,
            .read_bytes = 262_144,
            .unresolved_conflicts = 16,
        },
        .properties = "document-catalog-properties",
    };
}

test "document declarations bind schema profile shredding and properties across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var stored: D.Stored = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "doc-decl");
        defer objects.deinit();
        var owned = try D.prepare(t.allocator, sampleDefinition());
        defer owned.deinit();
        stored = try D.stage(objects.objectStore(), &owned);
        try t.expectEqualStrings("DDECL001", owned.bytes[0..8]);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "doc-decl");
    defer objects.deinit();
    var loaded = try D.load(t.allocator, objects.objectStore(), stored);
    defer loaded.deinit();
    try t.expectEqualDeep(stored, try loaded.stored());
    try t.expectEqualStrings("document-catalog-properties", loaded.definition.properties);
    try t.expectEqualStrings("doc_key", loaded.schema.schema.columns[0].name);
    try t.expectEqual(.ascii_ci, loaded.schema.schema.columns[0].collation);

    var foreign = stored;
    foreign.declaration.configuration.shredding.max_shredded_columns += 1;
    try t.expectError(error.InvalidDocumentDeclaration, D.load(t.allocator, objects.objectStore(), foreign));

    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try D.key(stored.content, &name));
    try t.expectError(error.DocumentDeclarationMissing, D.load(t.allocator, objects.objectStore(), stored));
}

test "document declarations reject primary keys and nullable or unknown partition keys" {
    var def = sampleDefinition();
    def.configuration.partitioning.key_column = 99;
    try t.expectError(error.UnknownColumn, def.validate());

    def = sampleDefinition();
    def.configuration.partitioning.key_column = 2; // nullable column
    try t.expectError(error.InvalidDocumentKeyColumn, def.validate());

    def = sampleDefinition();
    def.schema.primary_key = &.{1};
    try t.expectError(error.UnsupportedDocumentPrimaryKey, def.validate());
}

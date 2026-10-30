const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const Collation = fuze.Collation;
const DecimalArithmetic = fuze.DecimalArithmetic;
const TableSchemaProjection = fuze.TableSchemaProjection;
const H = c.HistoricalCatalog;

test "historical catalog cuts resolve AS OF names/definitions, enforce EBCDIC zone-map pruning, and support explicit PROJECTING TO" {
    // Manifest v1 (LSN 10, fixture-a): table "orders" (object 10, rev 1)
    // Columns: id (1, int64), legacy_code (2, utf8, ebcdic_cp037)
    const v1_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "legacy_code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .ebcdic_cp037 },
    };
    const pk = [_]s.ColumnId{1};
    const v1_schema: s.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 3,
        .columns = &v1_cols,
        .primary_key = &pk,
    };
    const v1_profiles = [_]H.ColumnCollationProfile{
        .{ .column = 2, .profile = .ebcdic_037_pad },
    };

    // In EBCDIC CP037, 'A' (0xC1) < '9' (0xF9), so min="A1  ", max="99  ".
    const seg1_zm = [_]H.ZoneMapBound{
        .{ .column = 2, .min_atom = .{ .bytes = "A1  " }, .max_atom = .{ .bytes = "99  " } },
    };
    const seg1_r1_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .signed = 1 } } },
        .{ .value = .{ .atom = .{ .bytes = "A1  " } } },
    };
    const seg1_r2_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .signed = 2 } } },
        .{ .value = .{ .atom = .{ .bytes = "99  " } } },
    };
    const seg1_rows = [_]H.HistoricalRow{
        .{ .cells = &seg1_r1_cells },
        .{ .cells = &seg1_r2_cells },
    };
    const v1_segments = [_]H.HistoricalSegment{
        .{
            .segment_id = 1,
            .min_lsn = 1,
            .max_lsn = 10,
            .physical_schema = v1_schema,
            .zone_maps = &seg1_zm,
            .rows = &seg1_rows,
        },
    };
    const v1_tables = [_]H.HistoricalTableBinding{
        .{
            .namespace = 1,
            .name = "orders",
            .object = 10,
            .revision = 1,
            .schema = v1_schema,
            .collation_profiles = &v1_profiles,
            .segments = &v1_segments,
        },
    };
    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)),
        .tables = &v1_tables,
    };
    const digest_v1 = try cut_v1.digest();

    // Manifest v2 (LSN 20, fixture-a): "orders" (object 10, rev 2)
    // Renames legacy_code -> code (id 2), adds region (id 3, DEFAULT 'EU-WEST')
    const v2_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .ebcdic_cp037 },
        .{
            .id = 3,
            .name = "region",
            .type = .{ .utf8 = {} },
            .nullable = false,
            .default = .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } },
        },
    };
    const v2_schema: s.Schema = .{
        .object = 10,
        .revision = 2,
        .next_column = 4,
        .columns = &v2_cols,
        .primary_key = &pk,
    };
    const v2_origins = [_]TableSchemaProjection.Initial{
        .{ .column = 3, .value = .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } } },
    };
    const seg2_r1_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .signed = 3 } } },
        .{ .value = .{ .atom = .{ .bytes = "B2" } } },
        .{ .value = .{ .atom = .{ .bytes = "US-EAST" } } },
    };
    const seg2_rows = [_]H.HistoricalRow{.{ .cells = &seg2_r1_cells }};
    const v2_segments = [_]H.HistoricalSegment{
        v1_segments[0],
        .{
            .segment_id = 2,
            .min_lsn = 11,
            .max_lsn = 20,
            .physical_schema = v2_schema,
            .rows = &seg2_rows,
        },
    };
    const v2_tables = [_]H.HistoricalTableBinding{
        .{
            .namespace = 1,
            .name = "orders",
            .object = 10,
            .revision = 2,
            .schema = v2_schema,
            .collation_profiles = &v1_profiles,
            .column_origins = &v2_origins,
            .segments = &v2_segments,
        },
    };
    const cut_v2: H.ManifestCut = .{
        .manifest_version = 2,
        .commit_lsn = 20,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)),
        .previous_manifest_digest = digest_v1,
        .tables = &v2_tables,
    };
    const digest_v2 = try cut_v2.digest();

    // Manifest v3 (LSN 30, fixture-b):
    // - Object 10 is renamed to "orders_archive" (rev 3) and drops column 2 ("code")
    // - A brand new table named "orders" (object 20, rev 1) is created!
    const v3_archive_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{
            .id = 3,
            .name = "region",
            .type = .{ .utf8 = {} },
            .nullable = false,
            .default = .{ .value = .{ .atom = .{ .bytes = "EU-WEST" } } },
        },
    };
    const v3_archive_schema: s.Schema = .{
        .object = 10,
        .revision = 3,
        .next_column = 4,
        .columns = &v3_archive_cols,
        .primary_key = &pk,
    };
    const new_orders_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "code", .type = .{ .int64 = {} }, .nullable = false },
    };
    const new_orders_schema: s.Schema = .{
        .object = 20,
        .revision = 1,
        .next_column = 3,
        .columns = &new_orders_cols,
        .primary_key = &pk,
    };
    const v3_tables = [_]H.HistoricalTableBinding{
        .{
            .namespace = 1,
            .name = "orders_archive",
            .object = 10,
            .revision = 3,
            .schema = v3_archive_schema,
            .column_origins = &v2_origins,
            .segments = &v2_segments,
        },
        .{
            .namespace = 1,
            .name = "orders",
            .object = 20,
            .revision = 1,
            .schema = new_orders_schema,
        },
    };
    const cut_v3: H.ManifestCut = .{
        .manifest_version = 3,
        .commit_lsn = 30,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-b", @splat(2)),
        .previous_manifest_digest = digest_v2,
        .tables = &v3_tables,
    };

    const cuts = [_]H.ManifestCut{ cut_v1, cut_v2, cut_v3 };
    const timeline = try H.HistoricalTimeline.init(&cuts);
    const grants: H.GrantSet = .{
        .policy_epoch = 4,
        .select_objects = &.{ 10, 20 },
    };

    // 1. Query "orders" AS OF MANIFEST 1 with PADSPACE filter 'A1' (matches "A1  " under ebcdic_037_pad)
    var q_v1 = try H.admitHistoricalQuery(
        timeline,
        .{ .manifest_version = 1 },
        1,
        "orders",
        .select_rows,
        grants,
        null,
        .{ .column = 2, .literal = .{ .bytes = "A1" } },
    );
    try std.testing.expectEqual(@as(u64, 10), q_v1.provenance.resolved_object);
    try std.testing.expectEqual(@as(u64, 1), q_v1.provenance.historical_revision);
    try std.testing.expectEqualStrings("legacy_code", q_v1.output_schema.columns[1].name);
    try std.testing.expectEqualStrings("fixture-a", q_v1.provenance.tzdb_version_name);

    var out_rows: [4][s.max_columns]v.Cell = undefined;
    const b1 = (try H.fetchNextHistoricalBatch(&q_v1, grants, &out_rows)).?;
    try std.testing.expectEqual(@as(usize, 1), b1.row_count);
    try std.testing.expect(b1.is_terminal);
    try std.testing.expectEqual(@as(i128, 1), out_rows[0][0].value.atom.signed);
    try std.testing.expectEqualStrings("A1  ", out_rows[0][1].value.atom.bytes);

    // 2. Query "orders" AS OF MANIFEST 1 PROJECTING TO MANIFEST 3 ("orders_archive", Object 10, rev 3):
    // Drops column 2 and synthesizes column 3 ('EU-WEST') from column_origins!
    var q_proj = try H.admitHistoricalQuery(
        timeline,
        .{ .manifest_version = 1 },
        1,
        "orders",
        .select_rows,
        grants,
        3,
        null,
    );
    try std.testing.expectEqual(@as(u64, 1), q_proj.provenance.historical_revision);
    try std.testing.expectEqual(@as(u64, 3), q_proj.provenance.output_revision);
    try std.testing.expectEqual(@as(u32, 1), q_proj.provenance.segment_projection.lazily_projected_segments);
    try std.testing.expectEqual(@as(u16, 1), q_proj.provenance.segment_projection.synthesized_default_columns);
    try std.testing.expectEqual(@as(u16, 1), q_proj.provenance.segment_projection.omitted_dropped_columns);

    const b_proj = (try H.fetchNextHistoricalBatch(&q_proj, grants, &out_rows)).?;
    try std.testing.expectEqual(@as(usize, 2), b_proj.row_count);
    try std.testing.expectEqual(@as(i128, 1), out_rows[0][0].value.atom.signed);
    try std.testing.expectEqualStrings("EU-WEST", out_rows[0][1].value.atom.bytes);

    // 3. Query "orders" AS OF MANIFEST 3 resolves to the recreated table (Object 20, rev 1),
    // and attempting to project Object 20 to Manifest 1 (where only Object 10 existed) fails!
    try std.testing.expectError(
        error.IncompatibleHistoricalObjectLineage,
        H.admitHistoricalQuery(timeline, .{ .manifest_version = 3 }, 1, "orders", .select_rows, grants, 1, null),
    );
}

test "current policy_epoch gates historical AS OF queries, enforces mid-stream revocation, retention expiry, and branch movement immunity" {
    const cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{
        .object = 77,
        .revision = 1,
        .next_column = 2,
        .columns = &cols,
        .primary_key = &pk,
    };
    const r1 = [_]v.Cell{.{ .value = .{ .atom = .{ .signed = 101 } } }};
    const r2 = [_]v.Cell{.{ .value = .{ .atom = .{ .signed = 202 } } }};
    const seg1_rows = [_]H.HistoricalRow{.{ .cells = &r1 }};
    const seg2_rows = [_]H.HistoricalRow{.{ .cells = &r2 }};
    const segments = [_]H.HistoricalSegment{
        .{ .segment_id = 1, .min_lsn = 1, .max_lsn = 10, .physical_schema = schema, .rows = &seg1_rows },
        .{ .segment_id = 2, .min_lsn = 11, .max_lsn = 20, .physical_schema = schema, .rows = &seg2_rows },
    };
    const tables_v1 = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "ledger", .object = 77, .revision = 1, .schema = schema, .segments = segments[0..1] },
    };
    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)),
        .tables = &tables_v1,
    };
    const digest_v1 = try cut_v1.digest();

    const tables_v2 = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "ledger", .object = 77, .revision = 1, .schema = schema, .segments = &segments },
    };
    const cut_v2: H.ManifestCut = .{
        .manifest_version = 2,
        .commit_lsn = 20,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)),
        .previous_manifest_digest = digest_v1,
        .tables = &tables_v2,
    };

    const cuts = [_]H.ManifestCut{ cut_v1, cut_v2 };
    var timeline = try H.HistoricalTimeline.init(&cuts);

    // 1. Metadata-only caller can DESCRIBE AS OF, but cannot SELECT AS OF
    const metadata_only_grants: H.GrantSet = .{
        .policy_epoch = 10,
        .metadata_objects = &.{77},
        .select_objects = &.{},
    };
    const desc_q = try H.admitHistoricalQuery(
        timeline,
        .{ .manifest_version = 1 },
        1,
        "ledger",
        .metadata_only,
        metadata_only_grants,
        null,
        null,
    );
    try std.testing.expectEqual(@as(u64, 10), desc_q.provenance.admitted_policy_epoch);
    try std.testing.expectError(
        error.RowSelectPermissionDenied,
        H.admitHistoricalQuery(timeline, .{ .manifest_version = 1 }, 1, "ledger", .select_rows, metadata_only_grants, null, null),
    );

    // 2. Admit a 2-batch SELECT AS OF MANIFEST 2 at policy_epoch 11
    const select_grants: H.GrantSet = .{
        .policy_epoch = 11,
        .select_objects = &.{77},
    };
    var stream_q = try H.admitHistoricalQuery(
        timeline,
        .{ .manifest_version = 2 },
        1,
        "ledger",
        .select_rows,
        select_grants,
        null,
        null,
    );

    // Advance branch head via conditional CAS (simulating DROP TABLE ledger in v3)
    const digest_v2 = try cut_v2.digest();
    const cut_v3: H.ManifestCut = .{
        .manifest_version = 3,
        .commit_lsn = 30,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-b", @splat(2)),
        .previous_manifest_digest = digest_v2,
        .tables = &.{},
    };
    try std.testing.expectError(
        error.ConditionalBranchHeadConflict,
        timeline.publishHeadConditional(1, &.{ cut_v1, cut_v2, cut_v3 }),
    );
    const new_head = try timeline.publishHeadConditional(2, &.{ cut_v1, cut_v2, cut_v3 });
    try std.testing.expectEqual(@as(u64, 3), new_head.manifest_version);
    try std.testing.expectEqual(@as(u64, 3), (try timeline.selectCut(.{ .head = "main" })).manifest_version);
    try std.testing.expectEqual(@as(u64, 3), (try timeline.selectCut(.{ .manifest_version = 3 })).manifest_version);

    // Batch 1 succeeds even after main moved to v3 (branch movement immunity)
    var rows_buf: [4][s.max_columns]v.Cell = undefined;
    const batch1 = (try H.fetchNextHistoricalBatch(&stream_q, select_grants, &rows_buf)).?;
    try std.testing.expectEqual(@as(u64, 1), batch1.segment_id);
    try std.testing.expect(!batch1.is_terminal);
    try std.testing.expectEqual(@as(i128, 101), rows_buf[0][0].value.atom.signed);

    // Revoke SELECT at policy_epoch 12 before Batch 2 is fetched
    const revoked_grants: H.GrantSet = .{
        .policy_epoch = 12,
        .metadata_objects = &.{77},
        .select_objects = &.{},
    };
    try std.testing.expectError(
        error.AuthorizationRevokedMidStream,
        H.fetchNextHistoricalBatch(&stream_q, revoked_grants, &rows_buf),
    );

    // 3. Retention expiry watermark rejects expired historical cuts
    try timeline.expireBelow(2, 20);
    try std.testing.expectError(
        error.HistoricalSnapshotExpired,
        H.admitHistoricalQuery(timeline, .{ .manifest_version = 1 }, 1, "ledger", .select_rows, select_grants, null, null),
    );
}

test "multi-model catalog descriptors validate View, PropertyGraph (SQL/PGQ), and ForeignTable (SQL/MED) dependencies and M18 gates" {
    const account_cols = [_]s.Column{
        .{ .id = 1, .name = "account_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "holder_name", .type = .{ .utf8 = {} }, .nullable = false },
    };
    const transfer_cols = [_]s.Column{
        .{ .id = 1, .name = "transfer_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "from_account", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 3, .name = "to_account", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 4, .name = "amount", .type = .{ .decimal = .{ .precision = 12, .scale = 2 } }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const account_schema: s.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 3,
        .columns = &account_cols,
        .primary_key = &pk,
    };
    const transfer_schema: s.Schema = .{
        .object = 11,
        .revision = 1,
        .next_column = 5,
        .columns = &transfer_cols,
        .primary_key = &pk,
    };

    const tables = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "accounts", .object = 10, .revision = 1, .schema = account_schema },
        .{ .namespace = 1, .name = "transfers", .object = 11, .revision = 1, .schema = transfer_schema },
    };

    const view_deps = [_]H.DependencyColumnBinding{
        .{ .source_object = 10, .source_revision = 1, .columns = &.{ 1, 2 } },
    };
    const view: H.ViewDescriptor = .{
        .object = 30,
        .revision = 1,
        .namespace = 1,
        .name = "v_account_holders",
        .canonical_sql = "SELECT account_id, holder_name FROM accounts",
        .dependencies = &view_deps,
        .security_invoker = true,
    };

    const vertex_tables = [_]H.VertexTableBinding{
        .{
            .table_object = 10,
            .table_revision = 1,
            .key_columns = &.{1},
            .label = "Account",
            .exposed_properties = &.{ 1, 2 },
        },
    };
    const edge_tables = [_]H.EdgeTableBinding{
        .{
            .table_object = 11,
            .table_revision = 1,
            .key_columns = &.{1},
            .source_vertex_object = 10,
            .source_key_columns = &.{2},
            .destination_vertex_object = 10,
            .destination_key_columns = &.{3},
            .label = "TRANSFERRED_TO",
            .exposed_properties = &.{4},
        },
    };
    const graph: H.PropertyGraphDescriptor = .{
        .object = 40,
        .revision = 1,
        .namespace = 1,
        .name = "payment_graph",
        .vertex_tables = &vertex_tables,
        .edge_tables = &edge_tables,
    };

    // Mainframe copybook ForeignTableDescriptor (COMP-3, ZONED, EBCDIC)
    const mf_cols = [_]s.Column{
        .{ .id = 1, .name = "acct_num", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "branch_code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .ebcdic_cp037 },
        .{ .id = 3, .name = "balance", .type = .{ .decimal = .{ .precision = 9, .scale = 2 } }, .nullable = false },
    };
    const mf_schema: s.Schema = .{
        .object = 50,
        .revision = 1,
        .next_column = 4,
        .columns = &mf_cols,
        .primary_key = &pk,
    };
    const mf_layout = [_]H.MainframeColumnLayout{
        .{ .column = 1, .codec = .zoned, .byte_offset = 0, .byte_length = 8 },
        .{ .column = 2, .codec = .ebcdic, .collation_profile = .ebcdic_037_pad, .byte_offset = 8, .byte_length = 4 },
        .{ .column = 3, .codec = .comp3, .byte_offset = 12, .byte_length = 5 },
    };
    const foreign_table: H.ForeignTableDescriptor = .{
        .server_object = 5,
        .server_name = "zos_cics_prod",
        .wrapper_name = "mainframe_copybook_v1",
        .object = 50,
        .revision = 1,
        .namespace = 1,
        .name = "cics_balances",
        .schema = mf_schema,
        .record_byte_length = 17,
        .mainframe_columns = &mf_layout,
    };

    const cut: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)),
        .tables = &tables,
        .views = &.{view},
        .property_graphs = &.{graph},
        .foreign_tables = &.{foreign_table},
    };
    try cut.validate();

    // Base table column drops/type changes are blocked by View and PropertyGraph dependencies
    try std.testing.expectError(
        error.ColumnReferencedByView,
        H.validateChangeAgainstMultiModel(10, .{ .drop = 2 }, &.{view}, &.{graph}),
    );
    try std.testing.expectError(
        error.ColumnReferencedByPropertyGraph,
        H.validateChangeAgainstMultiModel(11, .{ .drop = 2 }, &.{view}, &.{graph}),
    );

    // Milestone 18 runtime execution gates fail closed
    try std.testing.expectError(error.SqlPgqExecutionDeferredToM18, graph.checkGraphTableExecutionAdmission());
    try std.testing.expectError(error.SqlMedScanDeferredToM18, foreign_table.checkForeignScanAdmission());
}

test "historical manifest digest commits collation overrides" {
    const cols = [_]s.Column{.{ .id = 1, .name = "code", .type = .utf8 }};
    const schema: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &cols };
    var tables = [_]H.HistoricalTableBinding{.{ .namespace = 1, .name = "t", .object = 1, .revision = 1, .schema = schema }};
    const cut: H.ManifestCut = .{ .manifest_version = 1, .commit_lsn = 1, .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-a", @splat(1)), .tables = &tables };
    const before = try cut.digest();
    tables[0].collation_profiles = &.{.{ .column = 1, .profile = .ebcdic_037_pad }};
    const after = try cut.digest();
    try std.testing.expect(!std.mem.eql(u8, &before, &after));
}

test "historical projection coverage exceeds one scratch page" {
    const cols = [_]s.Column{.{ .id = 1, .name = "id", .type = .int64 }};
    const schema: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &cols };
    var segments: [129]H.HistoricalSegment = undefined;
    for (&segments, 0..) |*seg, i| seg.* = .{ .segment_id = i + 1, .min_lsn = 1, .max_lsn = 1, .physical_schema = schema };
    const binding: H.HistoricalTableBinding = .{ .namespace = 1, .name = "t", .object = 1, .revision = 1, .schema = schema, .segments = &segments };
    const summary = try binding.segmentProjectionSummary(schema, &.{});
    try std.testing.expectEqual(@as(u32, 129), summary.native_target_segments);
}

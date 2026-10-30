const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const DecimalArithmetic = fuze.DecimalArithmetic;
const HistoricalCatalog = c.HistoricalCatalog;
const PublishedResource = c.PublishedResource;
const DisclosurePolicy = c.DisclosurePolicy;
const InvestigationBasis = c.InvestigationBasis;
const Attribution = c.Attribution;
const PublishedProjection = c.PublishedProjection;

fn sampleDeliveryResource(state: PublishedResource.ResourceLifecycleState) !PublishedResource.PublishedResourceDescriptor {
    const cols = &[_]s.Column{
        .{ .id = 1, .name = "region", .type = .{ .utf8 = {} }, .nullable = false },
        .{ .id = 2, .name = "delayed_shipments", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 3, .name = "sla_penalty_usd", .type = .{ .decimal = .{ .precision = 18, .scale = 2 } }, .nullable = false },
    };
    const pk = &[_]s.ColumnId{1};
    const schema: s.Schema = .{
        .object = 500,
        .revision = 1,
        .next_column = 4,
        .columns = cols,
        .primary_key = pk,
    };
    const dep_cols = &[_]s.ColumnId{ 1, 2, 3 };
    const deps = &[_]HistoricalCatalog.DependencyColumnBinding{
        .{ .source_object = 10, .source_revision = 1, .columns = dep_cols },
        .{ .source_object = 20, .source_revision = 1, .columns = dep_cols },
    };
    const allowed_regions = &[_][]const u8{ "NA", "EU", "APAC" };
    const params = &[_]PublishedResource.ParameterSpec{
        .{
            .ordinal = 1,
            .name = "region",
            .logical_type = .{ .utf8 = {} },
            .required = true,
            .domain = .{ .utf8_enum = allowed_regions },
        },
        .{
            .ordinal = 2,
            .name = "horizon_days",
            .logical_type = .{ .int64 = {} },
            .required = false,
            .default_value = .{ .value = .{ .atom = .{ .signed = 30 } } },
            .domain = .{ .signed_range = .{ .min = 1, .max = 90 } },
        },
    };
    const questions = &[_]PublishedResource.QuestionTemplate{
        .{
            .question_id = "regional_delivery_risk",
            .prompt_template = "What is the delivery delay exposure and SLA penalty for region $1 over $2 days?",
            .required_parameter_ordinals = &[_]u32{1},
        },
    };
    const semantics = &[_]PublishedResource.ColumnSemanticBinding{
        .{ .column_id = 2, .unit = .{ .si_unit = "shipments" }, .business_description = "Count of shipments exceeding SLA" },
        .{ .column_id = 3, .unit = .{ .iso4217_currency = "USD".* }, .business_description = "Contractual SLA penalty exposure in USD" },
    };
    const charts = &[_]PublishedResource.ChartSpec{
        .{ .chart_id = "delays_by_region", .title = "Delayed Shipments by Region", .mark = .bar, .x_column = 1, .y_column = 2 },
    };
    const reports = &[_]PublishedResource.ReportLayoutSpec{
        .{
            .report_id = "delivery_executive_brief",
            .title = "Regional Delivery Assessment",
            .sections = &[_]PublishedResource.ReportSectionKind{ .executive_summary, .kpi_table, .chart_panel, .evidence_narrative },
        },
    };
    const drilldowns = &[_]PublishedResource.DrilldownSpec{
        .{
            .action_id = "inspect_facility_summary",
            .target_resource_object = 501,
            .target_minimum_revision = 1,
            .requires_source_row_rights = false,
        },
        .{
            .action_id = "inspect_raw_shipment_rows",
            .target_resource_object = 502,
            .target_minimum_revision = 1,
            .requires_source_row_rights = true,
        },
    };

    return .{
        .namespace_id = 1,
        .resource_object = 500,
        .definition_id = 9001,
        .publication_revision = 1,
        .previous_revision = null,
        .branch_id = 1,
        .owning_application = 77,
        .created_at_lsn = 100,
        .state = state,
        .canonical_name = "regional_delivery_assessment_without_any_21_byte_station_kv_cap",
        .business_title = "Regional Delivery Risk Assessment",
        .business_meaning = "Aggregates shipment SLA delays and contractual financial penalties by operating region.",
        .tzdb_version = try DecimalArithmetic.TzdbVersion.init("tzdb_2026a"),
        .backing_kind = .managed_dataflow,
        .canonical_plan_or_sql = "SELECT region, COUNT(*) AS delayed_shipments, SUM(penalty_usd) AS sla_penalty_usd FROM shipments JOIN contracts ON ... WHERE region = $1 GROUP BY region",
        .dependencies = deps,
        .parameters = params,
        .supported_questions = questions,
        .result_schema = schema,
        .column_semantics = semantics,
        .freshness_requirement = .{ .max_staleness_ms = 60_000, .require_complete_watermark = true },
        .work_bound = .{ .max_rows = 10_000, .max_bytes = 4 * 1024 * 1024, .max_cpu_micros = 500_000, .max_iops = 128, .execution_timeout_ms = 5_000 },
        .presentation = .{
            .charts = charts,
            .reports = reports,
            .drilldowns = drilldowns,
            .mcp_ui_template_uri = "ui://logistics/delivery-assessment/v1",
        },
    };
}

test "published resource validates headless PBR1 descriptor without screens or themes and enforces parameter domain constraints" {
    const t_std = std.testing;
    const desc = try sampleDeliveryResource(.published);
    try desc.validate();
    const digest_1 = try desc.definitionDigest();

    var desc_rev2 = desc;
    desc_rev2.publication_revision = 2;
    desc_rev2.previous_revision = 1;
    desc_rev2.result_schema.revision = 2;
    const digest_2 = try desc_rev2.definitionDigest();
    try t_std.expect(!std.mem.eql(u8, &digest_1, &digest_2));

    // Valid parameter binding uses default for horizon_days
    const valid_bindings = [_]PublishedResource.ParameterValueBinding{
        .{ .ordinal = 1, .value = .{ .value = .{ .atom = .{ .bytes = "NA" } } } },
    };
    const param_digest = try desc.validateAndDigestParameters(&valid_bindings);
    try t_std.expect(!std.mem.allEqual(u8, &param_digest, 0));

    // Out-of-domain region parameter rejected
    const bad_region = [_]PublishedResource.ParameterValueBinding{
        .{ .ordinal = 1, .value = .{ .value = .{ .atom = .{ .bytes = "ANTARCTICA" } } } },
    };
    try t_std.expectError(error.ParameterDomainViolation, desc.validateAndDigestParameters(&bad_region));

    // Out-of-range horizon_days rejected
    const bad_horizon = [_]PublishedResource.ParameterValueBinding{
        .{ .ordinal = 1, .value = .{ .value = .{ .atom = .{ .bytes = "EU" } } } },
        .{ .ordinal = 2, .value = .{ .value = .{ .atom = .{ .signed = 365 } } } },
    };
    try t_std.expectError(error.ParameterDomainViolation, desc.validateAndDigestParameters(&bad_horizon));
}

test "disclosure policy separates computation, publication, and consumption authority and prevents raw-row leakage or cache reuse" {
    const t_std = std.testing;
    const desc = try sampleDeliveryResource(.published);
    const digest = try desc.definitionDigest();

    const publisher_grants = [_]DisclosurePolicy.PublisherGrant{
        .{ .principal_id = 900, .namespace_id = 1, .can_publish = true, .can_withdraw = true },
    };
    const full_source_table_objs = [_]u64{ 10, 20 };
    const publisher_sources: HistoricalCatalog.GrantSet = .{
        .policy_epoch = 5,
        .select_objects = &full_source_table_objs,
    };

    const derived_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .derived_publication,
        .boundary = .{
            .min_group_cardinality = 5,
            .scrub_restricted_type_errors = true,
            .forbid_ad_hoc_filter_pushdown = true,
            .forbid_raw_row_drilldown_for_report_only = true,
        },
        .attestation = .{
            .publisher_principal = 900,
            .resource_object = 500,
            .publication_revision = 1,
            .definition_digest = digest,
            .attested_policy_epoch = 4,
        },
    };

    // Report-only delegated agent (agent_triage = 201, delegated by employee = 100)
    // Has zero raw table `select_rows` grants on tables 10 and 20!
    const allowed_objs = [_]u64{ 500, 501, 502 };
    const agent_triage_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 201,
        .delegation = .{
            .delegator_principal = 100,
            .agent_principal = 201,
            .allowed_resource_objects = &allowed_objs,
            .audience_kind = .summary_or_report_only,
            .delegated_select_objects = &.{},
            .issued_at_policy_epoch = 4,
            .expires_at_policy_epoch = 10,
        },
        .service_transport_principal = 1,
        .service_transport_has_admin_source_rights = true,
        .consumer_grants = &.{},
        .caller_source_grants = .{ .policy_epoch = 5, .select_objects = &.{} },
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "masked_report_only",
    };

    // 1. Report-only agent can evaluate the attested derived publication
    const audience = try DisclosurePolicy.authorizeEvaluation(desc, derived_policy, agent_triage_access, 5, false);
    try t_std.expectEqual(DisclosurePolicy.ConsumerAudienceKind.summary_or_report_only, audience);

    // 2. Injecting an ad-hoc filter pushdown is rejected
    try t_std.expectError(
        error.UnexposedFilterPushdownRejected,
        DisclosurePolicy.authorizeEvaluation(desc, derived_policy, agent_triage_access, 5, true),
    );

    // 3. Service credential cannot supply missing caller source rights on a `caller_source_rights` resource
    const raw_row_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .caller_source_rights,
    };
    try t_std.expectError(
        error.ServiceCredentialAmplificationForbidden,
        DisclosurePolicy.authorizeEvaluation(desc, raw_row_policy, agent_triage_access, 5, false),
    );

    // 4. Drilldown from summary resource to raw-row resource (502) is blocked for report-only agent
    var raw_target_desc = desc;
    raw_target_desc.resource_object = 502;
    raw_target_desc.result_schema.object = 502;
    try t_std.expectError(
        error.DisclosureBoundaryViolation,
        DisclosurePolicy.authorizeDrilldown(desc, derived_policy, "inspect_raw_shipment_rows", raw_target_desc, raw_row_policy, agent_triage_access, 5),
    );

    // 5. k-anonymity minimum group cardinality (< 5 rows) and 5-state type_error scrubbing
    const raw_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "NA" } } },
        .{ .value = .{ .atom = .{ .signed = 2 } } },
        .{ .type_error = .decimal },
    };
    var filtered_cells: [3]v.Cell = undefined;
    try DisclosurePolicy.applyDisclosureRowFilter(
        derived_policy,
        .summary_or_report_only,
        .{ .contributing_source_row_count = 2, .cells = &raw_cells },
        1,
        &filtered_cells,
    );
    try t_std.expectEqual(v.Cell{ .value = .{ .atom = .{ .bytes = "NA" } } }, filtered_cells[0]);
    try t_std.expectEqual(v.Cell.missing, filtered_cells[1]);
    try t_std.expectEqual(v.Cell.missing, filtered_cells[2]);

    // Group with >= 5 rows retains aggregate value but still scrubs restricted `type_error` side channel
    try DisclosurePolicy.applyDisclosureRowFilter(
        derived_policy,
        .summary_or_report_only,
        .{ .contributing_source_row_count = 8, .cells = &raw_cells },
        1,
        &filtered_cells,
    );
    try t_std.expectEqual(v.Cell{ .value = .{ .atom = .{ .signed = 2 } } }, filtered_cells[1]);
    try t_std.expectEqual(v.Cell.missing, filtered_cells[2]);

    // 6. Cross-audience cache key isolation between employee_analyst and agent_triage
    const employee_grants = [_]DisclosurePolicy.ResourceConsumerGrant{
        .{ .principal_id = 100, .resource_object = 500, .audience_kind = .full_resource_and_drilldown },
    };
    const employee_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 100,
        .consumer_grants = &employee_grants,
        .caller_source_grants = publisher_sources,
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "unmasked_regional_analyst",
    };
    const emp_key: DisclosurePolicy.AudienceCacheKey = .{
        .resource_object = 500,
        .publication_revision = 1,
        .basis_digest = @splat(0xAA),
        .params_digest = @splat(0xBB),
        .audience_policy_hash = try employee_access.effectiveAudienceHash(500),
        .policy_epoch = 5,
    };
    const agent_key: DisclosurePolicy.AudienceCacheKey = .{
        .resource_object = 500,
        .publication_revision = 1,
        .basis_digest = @splat(0xAA),
        .params_digest = @splat(0xBB),
        .audience_policy_hash = try agent_triage_access.effectiveAudienceHash(500),
        .policy_epoch = 5,
    };
    try t_std.expect(!emp_key.canReuseFor(agent_key));
}

test "investigation basis freezes atomic cuts vs multi-source vectors, enforces pin expiry and missing captures, and creates immutable successor refreshes with 4-clock attribution" {
    const t_std = std.testing;
    const desc = try sampleDeliveryResource(.published);
    const def_digest = try desc.definitionDigest();

    const publisher_grants = [_]DisclosurePolicy.PublisherGrant{
        .{ .principal_id = 900, .namespace_id = 1, .can_publish = true, .can_withdraw = true },
    };
    const full_source_objs = [_]u64{ 10, 20 };
    const publisher_sources: HistoricalCatalog.GrantSet = .{
        .policy_epoch = 5,
        .select_objects = &full_source_objs,
    };
    const derived_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .derived_publication,
        .boundary = .{ .min_group_cardinality = 5 },
        .attestation = .{
            .publisher_principal = 900,
            .resource_object = 500,
            .publication_revision = 1,
            .definition_digest = def_digest,
            .attested_policy_epoch = 4,
        },
    };
    const employee_grants = [_]DisclosurePolicy.ResourceConsumerGrant{
        .{ .principal_id = 100, .resource_object = 500, .audience_kind = .full_resource_and_drilldown },
    };
    const employee_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 100,
        .consumer_grants = &employee_grants,
        .caller_source_grants = publisher_sources,
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "unmasked_regional_analyst",
    };

    // Multi-source basis vector: native source 10 + captured exchange 20
    const entries_v1 = [_]InvestigationBasis.SourceBasisEntry{
        .{
            .native_source = .{
                .source_object = 10,
                .source_revision = 1,
                .branch_id = 1,
                .manifest_version = 2,
                .commit_lsn = 50,
                .pin_lease = .{
                    .pin_id = 701,
                    .source_object = 10,
                    .owner_principal = 100,
                    .acquired_at_ms = 1_000,
                    .expires_at_ms = 60_000,
                },
            },
        },
        .{
            .captured_exchange = .{
                .exchange_object = 20,
                .exchange_revision = 1,
                .payload_sha256 = @splat(0xCC),
                .observed_at_ms = 1_100,
                .capture_present = true,
            },
        },
    };
    const inv_v1: InvestigationBasis.InvestigationBasis = .{
        .investigation_id = 888,
        .basis_revision = 1,
        .parent_basis_revision = null,
        .created_by_principal = 100,
        .created_at_ms = 1_200,
        .payload = .{ .multi_source_basis_vector = &entries_v1 },
    };

    // Multi-source basis vector never claims global atomicity
    try t_std.expect(!inv_v1.isGloballyAtomic());
    try t_std.expectError(error.NonAtomicBasisVector, inv_v1.requireGlobalAtomicity());

    // Valid evaluation at now_ms = 2_000, min_retained_manifest_version = 1
    _ = try inv_v1.verifyForResourceEvaluation(desc, derived_policy, employee_access, 5, 2_000, 1);

    // Pin lease expiry -> InvestigationBasisExpired
    try t_std.expectError(
        error.InvestigationBasisExpired,
        inv_v1.verifyForResourceEvaluation(desc, derived_policy, employee_access, 5, 70_000, 1),
    );

    // Retention watermark expiry -> InvestigationBasisExpired
    try t_std.expectError(
        error.InvestigationBasisExpired,
        inv_v1.verifyForResourceEvaluation(desc, derived_policy, employee_access, 5, 2_000, 3),
    );

    // Explicit successor refresh (`basis_revision = 2`) when source 10 advances to LSN 80 and exchange 20 updates
    var entries_v2 = entries_v1;
    entries_v2[0].native_source.commit_lsn = 80;
    entries_v2[0].native_source.source_revision = 2;
    entries_v2[1].captured_exchange.exchange_revision = 2;
    entries_v2[1].captured_exchange.payload_sha256 = @splat(0xDD);

    const refresh_out = try inv_v1.refreshSuccessor(
        .{ .multi_source_basis_vector = &entries_v2 },
        100,
        5_000,
    );
    try t_std.expectEqual(@as(u64, 2), refresh_out.successor.basis_revision);
    try t_std.expectEqual(@as(?u64, 1), refresh_out.successor.parent_basis_revision);
    try t_std.expectEqual(@as(u32, 1), refresh_out.diff.advanced_native_sources);
    try t_std.expectEqual(@as(u32, 1), refresh_out.diff.evolved_schema_sources);
    try t_std.expectEqual(@as(u32, 1), refresh_out.diff.changed_external_captures);

    // 4-clock freshness & AttributionReceipt verification
    const basis_v1_digest = try inv_v1.basisDigest();
    const audience_hash = try employee_access.effectiveAudienceHash(500);
    const freshness_v1: Attribution.FourClockFreshness = .{
        .source_observation_cut_ms = 1_100,
        .domain_event_valid_time_ms = 1_050,
        .computation_completion_cut_ms = 1_250,
        .requested_freshness_sla_ms = 60_000,
    };
    const f_status = try freshness_v1.evaluate(2_000, desc.freshness_requirement);
    try t_std.expectEqual(Attribution.FreshnessStatus.fresh, f_status);

    const receipt_v1: Attribution.AttributionReceipt = .{
        .investigation_id = 888,
        .basis_revision = 1,
        .basis_kind = .multi_source_basis_vector,
        .basis_digest = basis_v1_digest,
        .resource_object = 500,
        .publication_revision = 1,
        .definition_digest = def_digest,
        .parameter_bindings_digest = @splat(0x55),
        .schema_epoch = 1,
        .verified_policy_epoch = 5,
        .disclosure_mode = .derived_publication,
        .audience_policy_hash = audience_hash,
        .freshness = freshness_v1,
        .freshness_status = f_status,
        .completeness = .complete,
        .total_rows_observed = 3,
    };
    try receipt_v1.verifyMatchesBasis(inv_v1);
    // Receipt from basis_revision = 1 cannot be relabeled or attached to basis_revision = 2
    try t_std.expectError(error.AttributionBasisMismatch, receipt_v1.verifyMatchesBasis(refresh_out.successor));

    const r1_digest = try receipt_v1.receiptDigest();
    const claims = [_]Attribution.NarrativeClaim{
        .{
            .claim_id = "claim_na_delay_spike",
            .statement_text = "North America shipment delays increased due to port congestion.",
            .cited_receipt_digests = &[_][32]u8{r1_digest},
            .assumptions = &[_]Attribution.AssumptionTag{ .model_inference, .human_annotation },
            .provenance_establishes_truth = false,
        },
    };
    const report_v1: Attribution.ReportArtifact = .{
        .report_id = "rep_01",
        .investigation_id = 888,
        .basis_revision = 1,
        .basis_digest = basis_v1_digest,
        .section_receipts = &[_]Attribution.AttributionReceipt{receipt_v1},
        .narrative_claims = &claims,
    };
    const rep_digest = try report_v1.validateConsistentBasis(inv_v1);
    try t_std.expect(!std.mem.allEqual(u8, &rep_digest, 0));
    try t_std.expectError(error.AttributionBasisMismatch, report_v1.validateConsistentBasis(refresh_out.successor));
}

test "multi-actor qualification: 1 employee and 2 delegated agents run 5 related queries and a report on one retained basis across source changes, refresh, revocation, 5-state parity, and bounded memory" {
    const t_std = std.testing;
    const desc = try sampleDeliveryResource(.published);
    const def_digest = try desc.definitionDigest();

    // Facility summary drilldown target (object 501, derived_publication)
    var facility_desc = desc;
    facility_desc.resource_object = 501;
    facility_desc.definition_id = 9002;
    facility_desc.canonical_name = "facility_delivery_summary";
    facility_desc.result_schema.object = 501;
    const facility_def_digest = try facility_desc.definitionDigest();

    // Raw shipment rows target (object 502, caller_source_rights)
    var raw_shipment_desc = desc;
    raw_shipment_desc.resource_object = 502;
    raw_shipment_desc.definition_id = 9003;
    raw_shipment_desc.canonical_name = "raw_shipment_rows";
    raw_shipment_desc.result_schema.object = 502;

    const publisher_grants = [_]DisclosurePolicy.PublisherGrant{
        .{ .principal_id = 900, .namespace_id = 1, .can_publish = true, .can_withdraw = true },
    };
    const full_source_objs = [_]u64{ 10, 20 };
    const publisher_sources: HistoricalCatalog.GrantSet = .{
        .policy_epoch = 10,
        .select_objects = &full_source_objs,
    };

    const derived_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .derived_publication,
        .boundary = .{ .min_group_cardinality = 5 },
        .attestation = .{
            .publisher_principal = 900,
            .resource_object = 500,
            .publication_revision = 1,
            .definition_digest = def_digest,
            .attested_policy_epoch = 9,
        },
    };
    const facility_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .derived_publication,
        .boundary = .{ .min_group_cardinality = 5 },
        .attestation = .{
            .publisher_principal = 900,
            .resource_object = 501,
            .publication_revision = 1,
            .definition_digest = facility_def_digest,
            .attested_policy_epoch = 9,
        },
    };
    const raw_policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .caller_source_rights,
    };

    // Three participants:
    // 1. Human employee (`employee_analyst` = 100) with full source & drilldown access
    const emp_consumer_grants = [_]DisclosurePolicy.ResourceConsumerGrant{
        .{ .principal_id = 100, .resource_object = 500, .audience_kind = .full_resource_and_drilldown },
        .{ .principal_id = 100, .resource_object = 501, .audience_kind = .full_resource_and_drilldown },
        .{ .principal_id = 100, .resource_object = 502, .audience_kind = .full_resource_and_drilldown },
    };
    const employee_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 100,
        .consumer_grants = &emp_consumer_grants,
        .caller_source_grants = publisher_sources,
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "employee_full",
    };

    // 2. Delegated Agent 1 (`agent_triage` = 201) with summary/report-only access, zero raw table rights
    const triage_allowed = [_]u64{ 500, 501 };
    const agent_triage_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 201,
        .delegation = .{
            .delegator_principal = 100,
            .agent_principal = 201,
            .allowed_resource_objects = &triage_allowed,
            .audience_kind = .summary_or_report_only,
            .delegated_select_objects = &.{},
            .issued_at_policy_epoch = 9,
            .expires_at_policy_epoch = 20,
        },
        .consumer_grants = &.{},
        .caller_source_grants = .{ .policy_epoch = 10, .select_objects = &.{} },
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "agent_triage_summary",
    };

    // 3. Delegated Agent 2 (`agent_deep_dive` = 202) with delegated source rights on tables 10 & 20
    const deep_dive_allowed = [_]u64{ 500, 501, 502 };
    const agent_deep_dive_access: DisclosurePolicy.CallerAccessContext = .{
        .caller_principal = 202,
        .delegation = .{
            .delegator_principal = 100,
            .agent_principal = 202,
            .allowed_resource_objects = &deep_dive_allowed,
            .audience_kind = .full_resource_and_drilldown,
            .delegated_select_objects = &full_source_objs,
            .issued_at_policy_epoch = 9,
            .expires_at_policy_epoch = 20,
        },
        .consumer_grants = &.{},
        .caller_source_grants = .{ .policy_epoch = 10, .select_objects = &full_source_objs },
        .publisher_grants = &publisher_grants,
        .publisher_source_grants = publisher_sources,
        .rls_mask_profile_tag = "agent_deep_dive_full",
    };

    // Bounded, authorization-aware catalog discovery (`D6`)
    const catalog_entries = [_]PublishedProjection.CatalogEntry{
        .{ .descriptor = desc, .policy = derived_policy },
        .{ .descriptor = facility_desc, .policy = facility_policy },
        .{ .descriptor = raw_shipment_desc, .policy = raw_policy },
    };
    var disc_buf: [4]PublishedProjection.DiscoveredResourceSummary = undefined;
    const triage_page = try PublishedProjection.discoverPublishedResources(
        &catalog_entries,
        .{ .limit = 2 },
        agent_triage_access,
        10,
        &disc_buf,
    );
    // agent_triage only discovers 500 and 501 (not 502, which requires caller_source_rights)
    try t_std.expectEqual(@as(usize, 2), triage_page.items.len);
    try t_std.expectEqual(@as(?u64, null), triage_page.next_cursor_resource_object);

    // Declare frozen InvestigationBasis `inv_shared` (revision 1)
    const basis_entries_v1 = [_]InvestigationBasis.SourceBasisEntry{
        .{
            .native_source = .{
                .source_object = 10,
                .source_revision = 1,
                .branch_id = 1,
                .manifest_version = 1,
                .commit_lsn = 100,
                .pin_lease = .{
                    .pin_id = 1,
                    .source_object = 10,
                    .owner_principal = 100,
                    .acquired_at_ms = 1_000,
                    .expires_at_ms = 100_000,
                },
            },
        },
        .{
            .foreign_source = .{
                .foreign_object = 20,
                .uri = "s3://logistics-partner/contracts-v1.parquet",
                .etag_or_generation = "etag-v1",
                .content_sha256 = @splat(0x77),
                .schema_epoch = 1,
                .observed_at_ms = 1_050,
                .capture_present = true,
            },
        },
    };
    const inv_v1: InvestigationBasis.InvestigationBasis = .{
        .investigation_id = 999,
        .basis_revision = 1,
        .created_by_principal = 100,
        .created_at_ms = 1_100,
        .payload = .{ .multi_source_basis_vector = &basis_entries_v1 },
    };
    const basis_v1_digest = try inv_v1.basisDigest();

    // Prepare 5-state and wide-numeric test rows (value, null, missing, type_error, conflict)
    const conflict_alts = [_]v.Alternative{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 10 } } } },
        .{ .counter = 1, .replica = 2, .value = .{ .value = .{ .atom = .{ .signed = 12 } } } },
    };
    const r0 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "NA" } } },
        .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i64) } } },
        .{ .value = .{ .atom = .{ .decimal = 123456789012345678 } } },
    };
    const r1 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "EU" } } },
        .null,
        .{ .conflict = &conflict_alts },
    };
    const r2 = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "APAC" } } },
        .missing,
        .{ .type_error = .decimal },
    };
    const input_rows = [_]DisclosurePolicy.GroupSummaryInputRow{
        .{ .contributing_source_row_count = 10, .cells = &r0 },
        .{ .contributing_source_row_count = 8, .cells = &r1 },
        .{ .contributing_source_row_count = 6, .cells = &r2 },
    };
    const na_binding = [_]PublishedResource.ParameterValueBinding{
        .{ .ordinal = 1, .value = .{ .value = .{ .atom = .{ .bytes = "NA" } } } },
    };
    const freshness: Attribution.FourClockFreshness = .{
        .source_observation_cut_ms = 1_050,
        .domain_event_valid_time_ms = 1_000,
        .computation_completion_cut_ms = 1_150,
        .requested_freshness_sla_ms = 60_000,
    };

    var probe: PublishedProjection.AllocationProbe = .{ .warmup_complete = true };
    var cell_buf_0: [3]v.Cell = undefined;
    var cell_buf_1: [3]v.Cell = undefined;
    var cell_buf_2: [3]v.Cell = undefined;
    var batch_scratch = [_][]v.Cell{ &cell_buf_0, &cell_buf_1, &cell_buf_2 };

    // Execute 5 related queries across the 3 actors while simulated concurrent writers advance live state:
    // Query 1: employee_analyst evaluates `delivery_assessment` (500)
    var q1 = try PublishedProjection.PublishedResourceStreamReader.open(
        desc,
        derived_policy,
        inv_v1,
        &na_binding,
        employee_access,
        10,
        2_000,
        1,
        &input_rows,
        1,
        3,
        null,
        freshness,
        &probe,
    );
    try t_std.expectEqual(@as(usize, 3), try q1.fetchNextBatch(.published, employee_access, 10, &batch_scratch));
    // Verify lossless int64::MAX, decimal128, null, conflict, missing, and type_error cells for full analyst
    try t_std.expectEqual(@as(i128, std.math.maxInt(i64)), batch_scratch[0][1].value.atom.signed);
    try t_std.expectEqual(@as(i128, 123456789012345678), batch_scratch[0][2].value.atom.decimal);
    try t_std.expect(batch_scratch[1][1] == .null);
    try t_std.expect(batch_scratch[1][2] == .conflict);
    try t_std.expect(batch_scratch[2][1] == .missing);
    const receipt_1 = try q1.close();

    // Query 2: agent_triage evaluates `delivery_assessment` (500) on the same frozen basis
    var q2 = try PublishedProjection.PublishedResourceStreamReader.open(
        desc,
        derived_policy,
        inv_v1,
        &na_binding,
        agent_triage_access,
        10,
        2_100,
        1,
        &input_rows,
        1,
        3,
        null,
        freshness,
        &probe,
    );
    try t_std.expectEqual(@as(usize, 3), try q2.fetchNextBatch(.published, agent_triage_access, 10, &batch_scratch));
    // For summary_or_report_only agent_triage, `type_error` in row 2 col 2 is scrubbed to `.missing`
    try t_std.expect(batch_scratch[2][2] == .missing);
    const receipt_2 = try q2.close();

    // Query 3: agent_triage drills down to permitted `facility_delivery_summary` (501)
    try DisclosurePolicy.authorizeDrilldown(
        desc,
        derived_policy,
        "inspect_facility_summary",
        facility_desc,
        facility_policy,
        agent_triage_access,
        10,
    );
    var q3 = try PublishedProjection.PublishedResourceStreamReader.open(
        facility_desc,
        facility_policy,
        inv_v1,
        &na_binding,
        agent_triage_access,
        10,
        2_200,
        1,
        &input_rows,
        1,
        3,
        null,
        freshness,
        &probe,
    );
    _ = try q3.fetchNextBatch(.published, agent_triage_access, 10, &batch_scratch);
    const receipt_3 = try q3.close();

    // Query 4: agent_deep_dive drills down to `raw_shipment_rows` (502) using delegated source rights
    try DisclosurePolicy.authorizeDrilldown(
        desc,
        derived_policy,
        "inspect_raw_shipment_rows",
        raw_shipment_desc,
        raw_policy,
        agent_deep_dive_access,
        10,
    );
    var q4 = try PublishedProjection.PublishedResourceStreamReader.open(
        raw_shipment_desc,
        raw_policy,
        inv_v1,
        &na_binding,
        agent_deep_dive_access,
        10,
        2_300,
        1,
        &input_rows,
        1,
        3,
        null,
        freshness,
        &probe,
    );
    _ = try q4.fetchNextBatch(.published, agent_deep_dive_access, 10, &batch_scratch);
    const receipt_4 = try q4.close();

    // Query 5: employee_analyst runs a display-window-truncated preview (max 2 rows) on the same basis
    var q5 = try PublishedProjection.PublishedResourceStreamReader.open(
        desc,
        derived_policy,
        inv_v1,
        &na_binding,
        employee_access,
        10,
        2_400,
        1,
        &input_rows,
        1,
        3,
        2,
        freshness,
        &probe,
    );
    try t_std.expectEqual(@as(usize, 2), try q5.fetchNextBatch(.published, employee_access, 10, &batch_scratch));
    try t_std.expectEqual(@as(usize, 0), try q5.fetchNextBatch(.published, employee_access, 10, &batch_scratch));
    const receipt_5 = try q5.close();
    try t_std.expectEqual(Attribution.CompletenessState.window_truncated, receipt_5.completeness);

    // All 5 queries and the report retain the exact same `basis_revision = 1` and `basis_digest`
    const all_receipts = [_]Attribution.AttributionReceipt{ receipt_1, receipt_2, receipt_3, receipt_4, receipt_5 };
    for (all_receipts) |rcpt| {
        try rcpt.verifyMatchesBasis(inv_v1);
        try t_std.expectEqual(@as(u64, 1), rcpt.basis_revision);
        try t_std.expectEqualSlices(u8, &basis_v1_digest, &rcpt.basis_digest);
    }
    const report_v1: Attribution.ReportArtifact = .{
        .report_id = "joint_delivery_investigation_report",
        .investigation_id = 999,
        .basis_revision = 1,
        .basis_digest = basis_v1_digest,
        .section_receipts = &all_receipts,
    };
    _ = try report_v1.validateConsistentBasis(inv_v1);

    // Mid-stream revocation between pages: fetch page 1 at policy_epoch 10, then revoke at policy_epoch 11
    var q_revoked = try PublishedProjection.PublishedResourceStreamReader.open(
        desc,
        derived_policy,
        inv_v1,
        &na_binding,
        agent_deep_dive_access,
        10,
        2_500,
        1,
        &input_rows,
        1,
        1,
        null,
        freshness,
        &probe,
    );
    try t_std.expectEqual(@as(usize, 1), try q_revoked.fetchNextBatch(.published, agent_deep_dive_access, 10, &batch_scratch));
    var revoked_access = agent_deep_dive_access;
    revoked_access.caller_source_grants.policy_epoch = 11;
    revoked_access.delegation = .{
        .delegator_principal = 100,
        .agent_principal = 202,
        .allowed_resource_objects = &deep_dive_allowed,
        .audience_kind = .full_resource_and_drilldown,
        .delegated_select_objects = &full_source_objs,
        .issued_at_policy_epoch = 9,
        .expires_at_policy_epoch = 10, // Expired at epoch 11!
    };
    try t_std.expectError(
        error.AuthorizationRevokedMidStream,
        q_revoked.fetchNextBatch(.published, revoked_access, 11, &batch_scratch),
    );
    const revoked_receipt = try q_revoked.close();
    try t_std.expectEqual(Attribution.CompletenessState.interrupted_prefix, revoked_receipt.completeness);

    // Compare Console, SDK, and Presentation projections (`D6`)
    const sql_surface = try PublishedProjection.projectResourceSurface(desc, derived_policy, employee_access, 10, .sql_console);
    const sdk_surface = try PublishedProjection.projectResourceSurface(desc, derived_policy, employee_access, 10, .shared_sdk_client);
    const mcp_surface = try PublishedProjection.projectResourceSurface(desc, derived_policy, employee_access, 10, .mcp_resource_and_app);
    try t_std.expectEqualSlices(u8, &sql_surface.definition_digest, &sdk_surface.definition_digest);
    try t_std.expectEqualSlices(u8, &sdk_surface.schema_fingerprint, &mcp_surface.schema_fingerprint);
    try t_std.expectEqual(@as(usize, 2), sql_surface.permitted_drilldown_count);

    // Report-only agent_triage surface filters out raw-row drilldown (only 1 permitted drilldown)
    const triage_surface = try PublishedProjection.projectResourceSurface(desc, derived_policy, agent_triage_access, 10, .board_workbook);
    try t_std.expectEqual(@as(usize, 1), triage_surface.permitted_drilldown_count);

    // Verify zero steady-state heap allocations and complete reader/pin release (`D7`, `P7`)
    try probe.assertZeroSteadyStateHeapAllocations();
    try probe.assertCleanRelease();
}

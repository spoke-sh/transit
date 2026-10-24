//! Reviewed direct caller causes; native operation outcomes remain separate.
const common = @import("CallerCodes.zig");
pub const Entry = common.Entry;
pub const entries = [_]Entry{
    .{ .cause = error.InvalidTableResponse, .code = "catalog.invalid_direct_response", .category = .integrity, .message = "The direct response does not match its exact request and source evidence. Preserve the original binding and inspect its owner." },
    .{ .cause = error.InvalidCatalogCursor, .code = "catalog.invalid_cursor", .category = .binding, .message = "The cursor must retain its original connection, selection, authority and position." },
    .{ .cause = error.CatalogObservationChanged, .code = "catalog.observation_changed", .category = .conflict, .message = "The directory changed during traversal. The earlier prefix does not establish complete coverage." },
    .{ .cause = error.InvalidNamedResource, .code = "catalog.invalid_resource", .category = .binding, .message = "The named resource declaration is invalid. Preserve explicit identity, encoding, initialization and lifetime settings." },
    .{ .cause = error.InvalidNamedResourceOperation, .code = "catalog.invalid_resource_operation", .category = .integrity, .message = "The resource operation evidence is inconsistent with its original declaration and allocation." },
    .{ .cause = error.InvalidCatalogAssertion, .code = "catalog.invalid_name_assertion", .category = .binding, .message = "The conditional declaration must retain its complete proposed intent and original name expectation." },
    .{ .cause = error.TableDefinitionChanged, .code = "catalog.definition_changed", .category = .conflict, .message = "The Table no longer matches the prepared definition. Preserve earlier accepted work; a newly prepared request is a separate operation." },
    .{ .cause = error.InvalidTableBasis, .code = "catalog.invalid_table_basis", .category = .binding, .message = "The Table basis requires its exact definition and nonempty original data position." },
    .{ .cause = error.TableSnapshotReleased, .code = "catalog.snapshot_released", .category = .lifecycle, .message = "The original snapshot is released. It cannot be silently replaced by a new data cut." },
    .{ .cause = error.DataIdentityConflict, .code = "catalog.data_identity_conflict", .category = .conflict, .message = "The operation identity is bound to different work. Recover the original complete binding before deciding how to continue." },
    .{ .cause = error.UnsupportedDirectSchemaAdministration, .code = "catalog.unsupported_schema_administration", .category = .unsupported, .message = "Namespace changes use their explicit catalog lifecycle; native policy preparation does not publish them." },
    .{ .cause = error.CatalogDirectoryChanged, .code = "catalog.directory_changed", .category = .conflict, .message = "The catalog directory changed while resolving this request. Prepare again from a complete current observation and preserve earlier saved work." },
    .{ .cause = error.InvalidCatalogStepBudget, .code = "catalog.invalid_step_budget", .category = .binding, .message = "Execution requires a positive bounded step budget. Changing the budget does not change the saved operation identity." },
    .{ .cause = error.InvalidDataIdentity, .code = "catalog.invalid_data_identity", .category = .binding, .message = "The data identity must retain its explicit catalog, branch and stable object identifiers." },
    .{ .cause = error.InvalidDataOperation, .code = "catalog.invalid_data_operation", .category = .binding, .message = "The operation requires its original full-width identity and valid scoped binding." },
    .{ .cause = error.InvalidDirectCatalogOperation, .code = "catalog.invalid_catalog_operation", .category = .binding, .message = "The namespace operation must carry its complete original action, expectation and catalog identity." },
    .{ .cause = error.InvalidTableDelegation, .code = "catalog.invalid_read_delegation", .category = .binding, .message = "The read delegation must bind its original caller, executor, interpretation, snapshot and retention owner." },
    .{ .cause = error.InvalidTableSchema, .code = "catalog.invalid_schema", .category = .binding, .message = "The Table schema must retain stable column identities and valid logical, physical and collation descriptors." },
    .{ .cause = error.QueryPageBudget, .code = "catalog.metadata_page_budget", .category = .limit, .message = "The metadata response exceeds the bounded page budget. No complete observation was established." },
    .{ .cause = error.StaleAuthorizationCredential, .code = "catalog.credential_changed", .category = .access, .message = "The current credential no longer matches the prepared authorization subject. Inspect current rights and preserve any earlier accepted work." },
    .{ .cause = error.TableBatchTooLarge, .code = "catalog.batch_limit", .category = .limit, .message = "The batch exceeds the explicit row limit. Prepare a bounded batch with its own operation identity." },
    .{ .cause = error.TablePayloadTooLarge, .code = "catalog.payload_limit", .category = .limit, .message = "The saved Table intent exceeds its byte limit. Prepare bounded work before staging or admission." },
};

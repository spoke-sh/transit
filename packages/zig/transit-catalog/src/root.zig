//! Declarative identities, direct Table operations and named resource lifecycles.
pub const client = @import("transit_client");
pub const storage = @import("transit_storage");
pub const protocol = @import("transit_protocol");
pub const fuze = @import("transit_fuze");
pub const Model = @import("Model.zig");
pub const Records = @import("Records.zig");
pub const Inspection = @import("Inspection.zig");
pub const DirectCatalog = @import("DirectCatalog.zig");
pub const DirectCatalogRoots = @import("DirectCatalogRoots.zig");
pub const DirectCatalogWalk = @import("DirectCatalogWalk.zig");
pub const DirectStorageGraph = @import("DirectStorageGraph.zig");
pub const DirectTableProtocol = @import("DirectTableProtocol.zig");
pub const DirectTableDispatch = @import("DirectTableDispatch.zig");
pub const DirectTableClient = @import("DirectTableClient.zig");
pub const DirectAuthorizationSql = @import("DirectAuthorizationSql.zig");
pub const DirectReadDelegation = @import("DirectReadDelegation.zig");
pub const DirectReadAuthority = @import("DirectReadAuthority.zig");
pub const DirectTableBinding = @import("DirectTableBinding.zig");
pub const DirectTableIntent = @import("DirectTableIntent.zig");
pub const DirectTableIntentStore = @import("DirectTableIntentStore.zig");
pub const DirectTablePreparedDml = @import("DirectTablePreparedDml.zig");
pub const DirectTablePreparedDdl = @import("DirectTablePreparedDdl.zig");
pub const DirectTableValues = @import("DirectTableValues.zig");
pub const DirectTableBridge = @import("DirectTableBridge.zig");
pub const DirectCatalogInspection = @import("DirectCatalogInspection.zig");
pub const DirectCatalogRead = @import("DirectCatalogRead.zig");
pub const DirectCatalogAdministration = @import("DirectCatalogAdministration.zig");
pub const DirectCatalogDependencies = @import("DirectCatalogDependencies.zig");
pub const DirectCatalogResources = @import("DirectCatalogResources.zig");
pub const DirectCatalogRetention = @import("DirectCatalogRetention.zig");
pub const DirectTableDiagnostic = @import("DirectTableDiagnostic.zig");
pub const DirectTableTyped = @import("DirectTableTyped.zig");
pub const DirectTableReader = @import("DirectTableReader.zig");
pub const OperationBinding = @import("OperationBinding.zig");
pub const NameAssertion = @import("NameAssertion.zig");
pub const DirectNamespace = @import("DirectNamespace.zig");
pub const DirectDependency = @import("DirectDependency.zig");
pub const DirectResource = @import("DirectResource.zig");
pub const DirectResourceClient = @import("DirectResourceClient.zig");
pub const TableMetadata = @import("TableMetadata.zig");
pub const TableAuthority = @import("TableAuthority.zig");
pub const SchemaCommand = @import("SchemaCommand.zig");
pub const AuthorizationLowering = @import("AuthorizationLowering.zig");
pub const TableValues = @import("TableValues.zig");
pub const TableLowering = @import("TableLowering.zig");
test {
    // Keep hash contracts discoverable even when a test filter removes their
    // indirect callers in the catalog lifecycle suite.
    _ = @import("DirectCatalogRecords.zig");
    _ = DirectTableClient;
    _ = DirectTableDiagnostic;
    _ = DirectCatalogRetention;
    _ = DirectTableValues;
    _ = DirectTableBridge;
    _ = DirectCatalogInspection;
    _ = DirectCatalogAdministration;
    _ = DirectCatalogDependencies;
    _ = DirectCatalogResources;
    _ = DirectTableProtocol;
    _ = DirectTableIntent;
    _ = DirectTableReader;
    _ = DirectReadDelegation;
    _ = OperationBinding;
    _ = NameAssertion;
    _ = DirectNamespace;
    _ = DirectDependency;
    _ = @import("direct_catalog_test.zig");
    _ = @import("direct_storage_graph_test.zig");
    _ = AuthorizationLowering;
    _ = TableAuthority;
}

pub const testing = if (@import("builtin").is_test) struct {
    pub const Authority = @import("TestAuthority.zig");
} else struct {};
pub const DirectIntent = @import("DirectIntent.zig");
pub const DirectRecord = @import("DirectRecord.zig");
pub const DirectClientToken = @import("DirectClientToken.zig");
pub const DirectTransactionCall = @import("DirectTransactionCall.zig");
pub const DirectTransactionSavepoint = @import("DirectTransactionSavepoint.zig");
pub const DirectTransactionWorkspace = @import("DirectTransactionWorkspace.zig");
pub const DirectTransactionControl = @import("DirectTransactionControl.zig");
pub const DirectTransactionRequest = @import("DirectTransactionRequest.zig");
pub const DirectTransaction = @import("DirectTransaction.zig");

pub const DirectTransactionClient = @import("DirectTransactionClient.zig");

pub const DirectTransactionRead = @import("DirectTransactionRead.zig");

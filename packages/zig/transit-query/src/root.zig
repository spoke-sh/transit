//! One bounded public query model, shared by Board and the signed CLI.
pub const settings = @import("transit_config");
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const wire = station.client;
pub const document = @import("transit_station_document");
pub const catalog = @import("transit_catalog");
pub const storage = catalog.storage;
pub const DirectTableQuery = @import("DirectTableQuery.zig");
pub const DirectTablePrepared = @import("DirectTablePrepared.zig");
pub const ComputePool = @import("ComputePool.zig");
pub const TableChangeReader = @import("TableChangeReader.zig");
pub const TableSource = @import("TableSource.zig");
pub const TablePosition = @import("TablePosition.zig");
pub const CapturedTablePin = @import("CapturedTablePin.zig");
pub const RelationalRevision = @import("RelationalRevision.zig");
pub const RelationalResult = @import("RelationalResult.zig");
pub const RelationalFreshness = @import("RelationalFreshness.zig");
pub const RelationalCapture = @import("RelationalCapture.zig");
pub const RelationalRecords = @import("RelationalRecords.zig");
pub const RelationalBundle = @import("RelationalBundle.zig");
pub const RelationalCaptured = @import("RelationalCaptured.zig");
pub const RelationalHistory = @import("RelationalHistory.zig");
pub const RelationalHistoryRecord = @import("RelationalHistoryRecord.zig");
pub const RelationalMaintenance = @import("RelationalMaintenance.zig");
pub const RelationalMaintenanceRecords = @import("RelationalMaintenanceRecords.zig");
pub const RelationalState = @import("RelationalState.zig");
pub const RelationalExchangeRecords = @import("RelationalExchangeRecords.zig");
pub const RelationalExchange = @import("RelationalExchange.zig");
pub const RelationalExchangeProducer = @import("RelationalExchangeProducer.zig");
pub const ExchangeAuthorization = @import("ExchangeAuthorization.zig");
pub const RelationalSpill = @import("RelationalSpill.zig");
pub const RelationalBridge = @import("RelationalBridge.zig");
pub const RelationalCaller = @import("RelationalCaller.zig");
pub const RelationalWorkspace = @import("RelationalWorkspace.zig");
pub const QueryMemory = fuze.MemoryBudget;
pub const Bundle = @import("Bundle.zig");
pub const QueryAuthorization = @import("QueryAuthorization.zig");
pub const ResultDisclosure = @import("ResultDisclosure.zig");
pub const Basis = @import("Basis.zig");
pub const SqlTemplate = @import("SqlTemplate.zig");
pub const SavedSubmission = @import("SavedSubmission.zig");
pub const UnifiedClient = @import("UnifiedClient.zig");
pub const Interactive = @import("Interactive.zig");
pub const UnifiedBehavior = @import("UnifiedBehavior.zig");
pub const UnifiedRequest = @import("UnifiedRequest.zig");
pub const UnifiedUpload = @import("UnifiedUpload.zig");
pub const Draft = @import("Draft.zig");
pub const UnifiedResult = @import("UnifiedResult.zig");
pub const UnifiedCapture = @import("UnifiedCapture.zig");
pub const UnifiedRecords = @import("UnifiedRecords.zig");
pub const UnifiedSource = @import("UnifiedSource.zig");
pub const Decoder = @import("Decoder.zig");
pub const SourceDefinition = @import("SourceDefinition.zig");
test {
    _ = @import("direct_table_count_range_test.zig");
    _ = @import("table_source_test.zig");
    _ = @import("source_test.zig");
    _ = @import("sql_template_test.zig");
    _ = @import("sql_compilation_test.zig");
    _ = @import("unified_capture_test.zig");
    _ = @import("unified_upload_test.zig");
    _ = @import("unified_records_test.zig");
    @import("std").testing.refAllDecls(@This());
}

pub const Values = @import("Values.zig");
pub const Bridge = @import("Bridge.zig");
pub const Workspace = @import("Workspace.zig");
pub const Editor = @import("Editor.zig");
pub const TableCompletionGrammar = @import("TableCompletionGrammar.zig");
pub const Assistance = @import("Assistance.zig");
pub const SqlInspection = @import("SqlInspection.zig");
pub const SqlCompilation = @import("SqlCompilation.zig");

/// Test-only reference transactions; never a production authority or backend.
pub const testing = if (@import("builtin").is_test) struct {
    pub const Store = @import("source_store_test.zig");
} else struct {};

pub const SourceWitness = @import("SourceWitness.zig");
pub const RuntimeWitness = @import("RuntimeWitness.zig");
pub const ApiDiagnostic = @import("ApiDiagnostic.zig");
pub const ExecutionDiagnostic = @import("ExecutionDiagnostic.zig");
pub const QueryFailure = @import("QueryFailure.zig");

pub const SettingsClient = @import("SettingsClient.zig");

pub const SettingsAssistance = @import("SettingsAssistance.zig");
pub const SettingsSql = @import("SettingsSql.zig");

pub const SettingsSession = @import("SettingsSession.zig");
pub const SettingsReader = @import("SettingsReader.zig");

test {
    _ = SettingsSql;
    _ = SettingsSession;
}

pub const SettingsJournal = @import("SettingsJournal.zig");

pub const DirectRelationalCompilation = @import("DirectRelationalCompilation.zig");
pub const DirectRelationalTables = @import("DirectRelationalTables.zig");
pub const DirectRelationalQuery = @import("DirectRelationalQuery.zig");
pub const DirectTableAssistance = @import("DirectTableAssistance.zig");

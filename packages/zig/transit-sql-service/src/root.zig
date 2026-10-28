//! SQL session service composition, including explicit captured-source adapters.
pub const database = @import("transit_sql");
pub const query = @import("transit_query");
pub const results = database.results;
pub const wire = database.wire;
pub const direct = database.direct;
pub const catalog = database.catalog;
pub const fuze = database.fuze;
pub const session_protocol = database.session_protocol;
pub const Authentication = database.Authentication;
pub const Limits = database.Limits;
pub const Client = database.Client;
pub const SessionOperations = database.SessionOperations;
pub const Completion = database.Completion;
pub const DatabaseRuntime = database.DatabaseRuntime;
pub const Probe = database.Probe;
pub const ReadBatch = database.ReadBatch;
pub const Statement = database.Statement;
pub const Terminal = database.Terminal;
pub const DatabaseAccount = database.DatabaseAccount;
pub const OperationRecords = database.OperationRecords;
pub const IntentReference = database.IntentReference;
pub const ReadCache = database.ReadCache;
pub const Type = database.Type;
pub const Bytes = database.Bytes;
pub const BatchDisclosure = @import("BatchDisclosure.zig");
pub const CapturedOperations = @import("CapturedOperations.zig");
pub const CapturedRecovery = @import("CapturedRecovery.zig");
pub const Configuration = @import("Configuration.zig");
pub const ConfigurationOperations = @import("ConfigurationOperations.zig");
pub const OperatorConfiguration = @import("OperatorConfiguration.zig");
pub const Registry = @import("Registry.zig");
pub const Session = @import("Session.zig");
pub const SessionSettings = @import("SessionSettings.zig");
pub const SourceSession = @import("SourceSession.zig");
pub const ReadSources = @import("ReadSources.zig");
test {
    @import("std").testing.refAllDecls(@This());
}

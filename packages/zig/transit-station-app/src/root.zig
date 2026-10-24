//! Application definitions compose existing public owners; never kernel policy.
pub const serving = @import("transit_serving");
pub const station = serving.station;
pub const protocol = serving.protocol;
pub const Sql = @import("Sql.zig");
pub const Model = @import("Model.zig");
pub const Api = @import("Api.zig");
pub const Records = @import("Records.zig");
pub const PublicationFailure = @import("PublicationFailure.zig");
pub const PublicationDiagnostic = @import("PublicationDiagnostic.zig");
pub const Publication = @import("Publication.zig");
pub const Request = @import("Request.zig");
pub const Behavior = @import("Behavior.zig");
pub const Native = @import("Native.zig");
pub const Upload = @import("Upload.zig");
pub const Host = @import("Host.zig");
pub const HostDiagnostic = @import("HostDiagnostic.zig");
pub const MigrationFailure = @import("MigrationFailure.zig");
pub const MigrationDiagnostic = @import("MigrationDiagnostic.zig");
pub const Migration = @import("Migration.zig");
pub const query = @import("transit_query");
pub const NamedRelational = @import("NamedRelational.zig");
pub const NamedRelationalRecords = @import("NamedRelationalRecords.zig");
pub const NamedResource = @import("NamedResource.zig");
test {
    _ = @import("model_test.zig");
    _ = @import("publication_test.zig");
    _ = @import("native_test.zig");
    _ = @import("host_test.zig");
    _ = @import("migration_test.zig");
    _ = @import("named_relational_test.zig");
    _ = @import("named_resource_test.zig");
    @import("std").testing.refAllDecls(@This());
}

pub const Diagnostic = @import("Diagnostic.zig");

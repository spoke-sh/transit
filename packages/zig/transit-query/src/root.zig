//! One bounded public query model, shared by Board and the signed CLI.
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const fuze = station.fuze;
pub const wire = station.client;
pub const document = @import("transit_station_document");
pub const Bundle = @import("Bundle.zig");
pub const UnifiedClient = @import("UnifiedClient.zig");
pub const UnifiedBehavior = @import("UnifiedBehavior.zig");
pub const UnifiedRequest = @import("UnifiedRequest.zig");
pub const UnifiedUpload = @import("UnifiedUpload.zig");
pub const UnifiedResult = @import("UnifiedResult.zig");
pub const UnifiedCapture = @import("UnifiedCapture.zig");
pub const UnifiedRecords = @import("UnifiedRecords.zig");
pub const UnifiedSource = @import("UnifiedSource.zig");
pub const Decoder = @import("Decoder.zig");
pub const SourceDefinition = @import("SourceDefinition.zig");
pub const Model = @import("Model.zig");
pub const Request = @import("Request.zig");
pub const Behavior = @import("Behavior.zig");
pub const Client = @import("Client.zig");
test {
    _ = @import("source_test.zig");
    _ = @import("unified_capture_test.zig");
    _ = @import("unified_upload_test.zig");
    _ = @import("unified_records_test.zig");
    @import("std").testing.refAllDecls(@This());
}

pub const Values = @import("Values.zig");
pub const Bridge = @import("Bridge.zig");

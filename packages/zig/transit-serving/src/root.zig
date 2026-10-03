//! Public serving semantics above Station; no sockets or raw storage authority.
pub const ClientApi = @import("ClientApi.zig");
pub const Api = @import("Api.zig");
pub const query = @import("transit_query");
pub const TableWatch = @import("TableWatch.zig");
pub const RefreshFailure = @import("RefreshFailure.zig");
pub const Refresh = @import("Refresh.zig");
pub const RefreshModel = @import("RefreshModel.zig");
pub const RefreshReader = @import("RefreshReader.zig");
pub const FiniteService = @import("FiniteService.zig");
pub const LiveService = @import("LiveService.zig");
pub const ReactiveClient = @import("ReactiveClient.zig");
pub const ReactiveWire = @import("ReactiveWire.zig");
pub const ReactiveAdapter = @import("ReactiveAdapter.zig");
pub const station = @import("transit_station");
pub const protocol = station.protocol;
pub const Model = @import("Model.zig");
pub const Codec = @import("Codec.zig");
pub const ServingFailure = @import("ServingFailure.zig");
pub const Service = @import("Service.zig");
pub const Adapter = @import("Adapter.zig");
pub const ReactiveService = @import("ReactiveService.zig");
pub const ReactiveModel = @import("ReactiveModel.zig");
test {
    _ = @import("service_test.zig");
    _ = @import("watch_test.zig");
    _ = @import("capture_watch_test.zig");
    _ = @import("refresh_test.zig");
    _ = ReactiveModel;
    @import("std").testing.refAllDecls(@This());
}

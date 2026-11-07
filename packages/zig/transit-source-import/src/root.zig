//! Trusted component seam for already sealed finite HTTP observations. This
//! package has no dispatch, socket, credential resolver or scheduler capability.
pub const data = @import("transit_data_client");
pub const http = @import("transit_station_http");
pub const Saved = @import("Saved.zig");
pub const Journal = @import("Journal.zig");
pub const Importer = @import("Importer.zig").Importer;

test {
    _ = Saved;
    _ = Journal;
    _ = @import("import_test.zig");
}

//! Installation-owned local trust. One private checkpoint precedes PEM publication.
const std = @import("std");
const tls = @import("transit_tls_server");
const q = @import("transit_query");
const Installation = @import("Installation.zig");
const E = @import("SqlEnrollment.zig");
const Files = @import("Files.zig");
const Journal = @import("SqlJournal.zig");
pub const Paths = struct { certificate: []const u8, key: []const u8, ca: []const u8 };
const Record = struct { definition: q.protocol.Growth.Definition, installation: [16]u8, trust: tls.LocalTrust };
pub fn prepare(installation: *Installation, allocator: std.mem.Allocator, meta: *E.Meta) !Paths {
    const settings = installation.config.sql.tls;
    if (settings.certificate_file) |certificate| {
        const result: Paths = .{ .certificate = certificate, .key = settings.key_file.?, .ca = settings.ca_file.? };
        try validate(allocator, result);
        return result;
    }
    const file = try E.path(installation, allocator, "tls/trust.json");
    var record = Files.read(Record, installation.init.io, allocator, file) catch |err| blk: {
        if (err != error.FileNotFound or meta.managed_trust) return err;
        var trust = try tls.LocalTrust.issue(allocator, installation.init.io);
        errdefer trust.deinit(allocator);
        const created: Record = .{ .definition = q.protocol.Growth.current_definition, .installation = installation.record.installation, .trust = trust };
        try Journal.save(installation, file, created);
        break :blk created;
    };
    defer record.trust.deinit(allocator);
    if (record.definition != q.protocol.Growth.current_definition or !std.mem.eql(u8, &record.installation, &installation.record.installation)) return error.InstallationIdentityMismatch;
    const result: Paths = .{ .ca = try E.path(installation, allocator, "tls/ca.pem"), .certificate = try E.path(installation, allocator, "tls/server.pem"), .key = try E.path(installation, allocator, "tls/server.key") };
    try Files.write(installation.init.io, result.ca, record.trust.ca);
    try Files.write(installation.init.io, result.certificate, record.trust.certificate);
    try Files.write(installation.init.io, result.key, record.trust.key);
    if (!meta.managed_trust) {
        meta.managed_trust = true;
        try Journal.save(installation, try E.path(installation, allocator, "installation.json"), meta);
    }
    try validate(allocator, result);
    return result;
}
fn validate(allocator: std.mem.Allocator, paths: Paths) !void {
    const certificate = try allocator.dupeSentinel(u8, paths.certificate, 0);
    defer allocator.free(certificate);
    const key = try allocator.dupeSentinel(u8, paths.key, 0);
    defer allocator.free(key);
    var context = try tls.Context.init(certificate, key);
    defer context.deinit();
    const ca = try allocator.dupeSentinel(u8, paths.ca, 0);
    defer allocator.free(ca);
    try context.verifyLocalTrust(ca);
}

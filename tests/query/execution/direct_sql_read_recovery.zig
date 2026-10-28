//! Database-owned snapshot recovery against the real direct service. The
//! enclosing proof loses an acquisition reply and restarts disk-backed owners.
const std = @import("std");
const sql = @import("transit_sql_service");
const c = sql.catalog;
const t = std.testing;
const gateway: sql.ReadCache.Gateway = .{ .realm = 42, .account = @splat(47) };
fn acquire(pins: *sql.ReadCache, client: c.DirectTableClient) !sql.ReadCache.Record {
    const response = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer response.deinit();
    return pins.acquireCurrent(client, try c.DirectTableBinding.init(client.connection, response.value.result.lookup.?));
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, directory: std.Io.Dir) !void {
    var pins = try sql.ReadCache.init(init.gpa, init.io, directory, gateway, 1);
    defer pins.deinit();
    try t.expectError(error.InvalidTableResponse, acquire(&pins, client));
    const record = (try pins.inspect(client, 0)).?;
    try t.expect(record.handle == null);
    const response = try client.call(.{ .pin_status = .{ .object = record.table.interpretation.interpretation.object, .owner = record.owner() } });
    defer response.deinit();
    try t.expect(response.value.result.pin_state.handle != null and !response.value.result.pin_state.released);
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, directory: std.Io.Dir) !void {
    var replacement = try sql.ReadCache.init(init.gpa, init.io, directory, gateway, 2);
    defer replacement.deinit();
    const original = (try replacement.inspect(client, 0)).?;
    // A replacement recovers the exact accepted request with its original cut,
    // including an unknown acquisition reply. It never invents a new snapshot.
    try t.expect(try replacement.tick(client));
    try t.expect(try replacement.inspect(client, 0) == null);
    const response = try client.call(.{ .pin_status = .{ .object = original.table.interpretation.interpretation.object, .owner = original.owner() } });
    defer response.deinit();
    try t.expect(response.value.result.pin_state.released);
    const first = try acquire(&replacement, client);
    const second = try acquire(&replacement, client);
    try t.expectEqualDeep(first, second);
    try replacement.close(client, first);
    try replacement.close(client, second);
    const warm = try acquire(&replacement, client);
    try t.expectEqualDeep(first, warm);
    // Cleanup must not release a live cache entry, even between statements.
    for (0..sql.ReadCache.capacity) |_| try t.expect(!try replacement.tick(client));
    try replacement.close(client, warm);
    var newer = try sql.ReadCache.init(init.gpa, init.io, directory, gateway, 3);
    defer newer.deinit();
    try t.expect(try newer.tick(client));
    try t.expectError(error.StaleGatewayCoordinator, replacement.inspect(client, 0));
}

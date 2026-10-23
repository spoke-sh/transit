//! Disk SQL pin journal against the real direct service. The enclosing proof
//! restarts the node between prepare/recover and corrupts one acquisition reply.
const std = @import("std");
const sql = @import("transit_sql");
const c = sql.catalog;
const t = std.testing;
const gateway: sql.ReadPins.Gateway = .{ .realm = 42, .owner = 100, .account = @splat(47) };
fn acquire(pins: *sql.ReadPins, client: c.DirectTableClient) !sql.ReadPins.Record {
    const response = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer response.deinit();
    const metadata = response.value.result.lookup.?;
    return pins.acquire(client, try c.DirectTableBinding.init(client.connection, metadata), metadata.position);
}
fn saved(init: std.process.Init, pins: *sql.ReadPins) ![2]sql.ReadPins.Record {
    var iterator = pins.directory.iterate();
    var records: [2]sql.ReadPins.Record = undefined;
    var count: usize = 0;
    while (try iterator.next(init.io)) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".pin")) continue;
        if (count == records.len) return error.UnexpectedReadPinJournal;
        const bytes = try pins.directory.readFileAlloc(init.io, entry.name, init.gpa, .limited(sql.ReadPins.max_bytes));
        defer init.gpa.free(bytes);
        const value = try c.protocol.Json.parseFromSlice(sql.ReadPins.Record, init.gpa, bytes);
        defer value.deinit();
        try value.value.validate();
        records[count] = value.value;
        count += 1;
    }
    try t.expectEqual(@as(usize, 2), count);
    return records;
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, directory: std.Io.Dir) !void {
    var pins = try sql.ReadPins.init(init.gpa, init.io, directory, gateway, 1);
    defer pins.deinit();
    try t.expectError(error.InvalidTableResponse, acquire(&pins, client));
    _ = try acquire(&pins, client);
    const records = try saved(init, &pins);
    try t.expect(records[0].state != records[1].state);
    for (records) |record| {
        const response = try client.call(.{ .pin_status = .{ .object = record.table.interpretation.interpretation.object, .owner = record.owner() } });
        defer response.deinit();
        try t.expect(response.value.result.pin_state.handle != null and !response.value.result.pin_state.released);
        if (record.state == .closing) try t.expect(record.handle == null) else try t.expect(record.handle != null);
    }
    // Deinit closes only local resources, retaining both original requests.
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, directory: std.Io.Dir) !void {
    var previous = try sql.ReadPins.init(init.gpa, init.io, directory, gateway, 1);
    const records = try saved(init, &previous);
    // Closing work is recoverable even in the current generation. Active
    // cursors in that generation remain protected from the cleanup worker.
    for (0..3) |_| _ = try previous.tick(client.authority, client.key, client.connection.principal);
    for (records) |record| {
        const response = try client.call(.{ .pin_status = .{ .object = record.table.interpretation.interpretation.object, .owner = record.owner() } });
        defer response.deinit();
        try t.expectEqual(record.state == .closing, response.value.result.pin_state.released);
    }
    previous.deinit();
    var replacement = try sql.ReadPins.init(init.gpa, init.io, directory, gateway, 2);
    defer replacement.deinit();
    for (0..3) |_| _ = try replacement.tick(client.authority, client.key, client.connection.principal);
    for (records) |record| {
        const response = try client.call(.{ .pin_status = .{ .object = record.table.interpretation.interpretation.object, .owner = record.owner() } });
        defer response.deinit();
        try t.expect(response.value.result.pin_state.released);
    }
    var iterator = replacement.directory.iterate();
    while (try iterator.next(init.io)) |entry| try t.expect(!std.mem.endsWith(u8, entry.name, ".pin"));
    const current = try acquire(&replacement, client);
    try replacement.close(client, current);
    try replacement.close(client, current);
}

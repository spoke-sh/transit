//! Offline discovery, including routes absent from the selected connection.
const std = @import("std");
const Console = @import("Console.zig").Console;
pub fn write(console: *Console, topic: []const u8) !void {
    const mutation = std.ascii.eqlIgnoreCase(topic, "INSERT") or std.ascii.eqlIgnoreCase(topic, "UPDATE") or std.ascii.eqlIgnoreCase(topic, "DELETE");
    const creation = std.ascii.eqlIgnoreCase(topic, "CREATE TABLE");
    const text = if (mutation)
        "INSERT INTO items (id, value) VALUES (1, 100);\nUPDATE items SET value = 101 WHERE id = 1;\nDELETE FROM items WHERE id = 1;\nINSERT requires both columns and 1-3 literal rows. UPDATE/DELETE require key equality.\nConfigure writes.recovery_file and writes.table: {name, connection: {realm, principal, writer, resource, table}}.\nUse the provisioned writer's identities; realm/principal must match the console credential.\nNative grants and the writer's current mutation policy are required; query access grants no writes.\n.status observes; .resume reconciles exact saved work; .cancel requests mutation cancellation.\nCtrl-C stops waiting and retains recovery; it does not undo an accepted write.\n"
    else if (creation)
        "CREATE TABLE items (id INT64 NOT NULL, value INT64 NULL);\nExactly two columns: an int64 NOT NULL key and a NULL value of INT64, BOOL, UTF8 or BINARY.\nConfigure writes.recovery_file and writes.catalog: {scope: {realm, resource, catalog}, owner, principal}.\nUse provisioned identities; realm/principal must match the console credential.\nNative grants and current catalog create/inspect policy are required.\nCreation publishes the definition and Table descriptor. Query sources and writer policies remain explicitly configured.\n.status observes; .resume reconciles exact saved creation. CREATE TABLE has no cancellation operation.\n"
    else if (topic.len == 0 or std.ascii.eqlIgnoreCase(topic, "SQL"))
        "SQL: SELECT; DESCRIBE name; SHOW TABLES; EXPLAIN SELECT ...;\nWrites: INSERT, UPDATE, DELETE and CREATE TABLE through explicitly configured authorized routes.\n.help [SQL|INSERT|UPDATE|DELETE|CREATE TABLE] .tables .schema .sources .mode table|json\n.timing on|off .connect PATH .show .info .quit\n.execute FILE runs one JSON query object: sql and optional parameters.\nRecovery: .status .resume [query ID] .cancel\nCtrl-R searches SQL and dot-command history in ~/.transit_history. Enter accepts a match for editing.\nSELECT uses the configured source. Write recovery is available in both execution modes.\nReference-only families (including GRANT/REVOKE, CREATE CONNECTION/SOURCE/SINK) do not execute.\n"
    else
        return error.UnknownHelpTopic;
    const writer = console.writes != null and console.writes.?.mutation != null;
    const catalog = console.writes != null and console.writes.?.catalog != null;
    if (console.session.format == .json) return console.json(.{ .commands = [_][]const u8{ "help", "tables", "schema", "sources", "mode", "timing", "connect", "show", "execute", "info", "quit", "status", "resume", "cancel" }, .help = text, .table_writer_configured = writer, .catalog_configured = catalog, .authorization = "checked at execution" });
    try console.out.writeAll(text);
    try console.out.print("Table writer: {s}; catalog: {s}. Authorization is checked at execution.\n", .{ if (writer) "configured" else "not configured", if (catalog) "configured" else "not configured" });
}

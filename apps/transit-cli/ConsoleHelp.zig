//! Local command discovery. Help is independent of SQL result formatting.
const std = @import("std");
const Meta = @import("transit_query").Assistance.Meta;
const Entry = struct { name: Meta, arguments: []const u8, summary: []const u8, details: []const u8 };
pub const commands = [_]Entry{
    .{ .name = .connect, .arguments = "FILE", .summary = "Open a connection using a configuration file", .details = "Terminal only. Closes the current session and opens FILE.\nPaths may be quoted. Accepted writes remain owned by the service.\nExample: .connect ./connection.yaml" },
    .{ .name = .edit, .arguments = "", .summary = "Edit the latest SQL statement in $EDITOR", .details = "Opens the latest SQL statement, including one that failed; skips dot commands.\nSave and close to execute, even without text changes. Close without saving to cancel.\nRequires an interactive terminal and $EDITOR. With no SQL history, opens an empty file.\nEditors that detach must wait for the file to close, for example: code --wait." },
    .{ .name = .execute, .arguments = "FILE", .summary = "Run a JSON query file with typed parameters", .details = "FILE contains one SQL query object and optional typed parameters.\nExample: {\"sql\":\"SELECT * FROM items LIMIT $1\",\"parameters\":[{\"unsigned\":\"3\"}]}\nParameters are bound to prepared types, never substituted into SQL text.\nFile paths may be quoted. At most 65 parameters and 131072 input-file bytes." },
    .{ .name = .help, .arguments = "[--all] [TOPIC]", .summary = "Show command or topic help", .details = "Use .help COMMAND for one command, or .help --all for all command details.\nTopics: sql, settings, shortcuts, INSERT, UPDATE, DELETE, CREATE TABLE, ALTER TABLE, DROP TABLE.\nTopic names are case-insensitive; a command may include its leading dot.\nWith a topic, --all shows only that topic. Help is text in both output modes." },
    .{ .name = .info, .arguments = "", .summary = "Show account, database and source context", .details = "Displays the connected account, database, selected source and authorized source bindings.\nThe service checks current permissions. .sources is an alias for .info." },
    .{ .name = .mode, .arguments = "table|json", .summary = "Set the query result format", .details = "table displays escaped, bounded cell previews. json streams exact typed values.\nOnly the final JSON completion record confirms that all rows were received.\nErrors and timing use stderr. .help and .show remain text in either mode." },
    .{ .name = .quit, .arguments = "", .summary = "Exit the console", .details = "Closes this session and releases its active result. EOF also exits.\nExiting does not undo accepted writes." },
    .{ .name = .schema, .arguments = "[TABLE]", .summary = "Show table columns, or list available tables", .details = "With TABLE, runs DESCRIBE TABLE to show authorized columns, types, defaults and keys.\nWithout an argument, lists available tables.\nExample: .schema people" },
    .{ .name = .show, .arguments = "", .summary = "Show console settings and their sources", .details = "Prints effective connection, output-format and timing settings with their origins.\nFor server and SQL session settings, use .help settings." },
    .{ .name = .sources, .arguments = "", .summary = "Show session context; alias for .info", .details = "Displays the same account, database and authorized source context as .info." },
    .{ .name = .tables, .arguments = "", .summary = "List available tables", .details = "Runs SHOW TABLES in the current database under current permissions.\nUse .schema TABLE to inspect columns." },
    .{ .name = .timer, .arguments = "on|off", .summary = "Enable or disable query timing", .details = "Timing is off by default. Reports client-observed submission, waiting, fetching\nand rendering time to stderr, including failed statements.\nThis is elapsed client time, not a server execution or network-only measurement." },
};
const topics = .{
    .{ "sql", "Discover tables with .tables and inspect columns with .schema TABLE.\n\nSELECT * FROM people LIMIT 8;\nSELECT id, name FROM people WHERE id >= 0;\nSELECT COUNT(*) FROM people;\nSELECT SUM(chosen.value) FROM (SELECT value FROM items LIMIT 8) AS chosen;\n\nSUM requires INT64 values. An outer aggregate LIMIT does not limit its input.\nGeneral Table SQL is limited to 4096 UTF-8 bytes and 128 output columns.\nFinite relational SELECT supports the catalog query profile.\n\nStatement help: INSERT, UPDATE, DELETE, CREATE TABLE, ALTER TABLE, DROP TABLE.\nUse .help settings for SHOW, SET, RESET and configuration reload.\nTransactions, RETURNING and expression assignments are unsupported.\nGRANT/REVOKE and CREATE CONNECTION/SOURCE/SINK/KV/DOCUMENT do not execute here." },
    .{ "settings", "Console preferences: .mode table|json, .timer on|off, .show.\n\nSHOW ALL; SHOW ports.gateway; SHOW query.statement_timeout;\nSELECT name, value, pending_restart FROM transit_settings();\nSET query.statement_timeout = '5s'; RESET query.statement_timeout; RESET ALL;\nSHOW DATABASES; SHOW SCHEMAS; SHOW TABLES;\n\nSET affects this session within its administrator ceiling; RESET restores its defaults.\nSELECT transit_reload_conf(); reloads the pinned server file with its startup environment.\nReload requires its own grant. Ports and topology changes can require a server restart.\nPartial application is reported as partial. Interrupting the wait does not undo a reload." },
    .{ "shortcuts", "Enter          Submit SQL ending in a semicolon, or a dot command\nCtrl-C         Clear the draft, or interrupt the current statement\nCtrl-D         Exit when the draft is empty\nUp / Down      Recall command history\nCtrl-R         Search SQL and dot-command history\nEnter / Tab    Accept a history match for editing, without executing it\nCtrl-G / Esc   Cancel history search\nCtrl-Space     Request completion\nTab            Accept the selected completion\nCtrl-A / Home  Move to the start\nCtrl-E / End   Move to the end\nCtrl-U         Delete the text before the cursor\nCtrl-Z         Undo the previous edit\n\nHistory is stored in ~/.transit_history. Paste stays in the draft until Enter.\nInterrupting a statement discards any remaining statements in that pasted draft.\nStopping a wait does not undo an accepted write." },
    .{ "INSERT", "INSERT INTO people (id, name) VALUES (1, 'Ada'), (2, 'Grace');\n\nAccepts 1-1024 typed rows, reordered or omitted columns, DEFAULT and NULL.\nOne statement publishes atomically; a rejected row never leaves an inserted prefix.\nUse .schema people for columns, defaults and keys. Requires current write rights." },
    .{ "UPDATE", "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1;\n\nAssignments accept typed constants or DEFAULT; expression assignments are unsupported.\nPredicates support finite scalar comparisons and state tests with NOT, AND and OR.\nOne statement publishes atomically. Changed and matched rows can differ.\nRequires current write rights; query access alone does not grant writes." },
    .{ "DELETE", "DELETE FROM people WHERE id >= 1;\n\nPredicates support finite scalar comparisons and state tests with NOT, AND and OR.\nExact primary-key equality uses the point path; other predicates select a finite snapshot.\nOne statement publishes atomically. Requires current write rights." },
    .{ "CREATE TABLE", "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL);\nCREATE TABLE notes (id INT64, note UTF8);\n\nSchemas have 1-128 columns. Columns are nullable unless declared otherwise.\nPRIMARY KEY implies NOT NULL; without one, internal row identities preserve duplicates.\nINTEGER means int32; BIGINT means int64; INT8 means eight bits.\nVARCHAR(n) limits Unicode scalars. Logical types include signed/unsigned integers,\nfinite floats, decimals, temporal values, UUID, binary and nested types.\nIF NOT EXISTS preserves the existing object. Requires current catalog create rights.\nCreated tables are discoverable through .tables without another worker." },
    .{ "ALTER TABLE", "ALTER TABLE people ADD COLUMN email VARCHAR(320);\nALTER TABLE people RENAME COLUMN name TO full_name;\nALTER TABLE people DROP COLUMN email;\n\nAlso supports table rename, SET/DROP DEFAULT, SET/DROP NOT NULL and admitted\nexact type conversions. Requires current catalog alter rights." },
    .{ "DROP TABLE", "DROP TABLE people;\nDROP TABLE IF EXISTS people;\n\nUses RESTRICT: registered dependencies can block deletion. CASCADE is unsupported.\nRequires current catalog drop rights. Dropping a table is not undone by disconnecting." },
};

fn entry(out: *std.Io.Writer, value: Entry, extended: bool) !void {
    const name = @tagName(value.name);
    try out.print(".{s}", .{name});
    if (value.arguments.len != 0) try out.print(" {s}", .{value.arguments});
    const width = 1 + name.len + (if (value.arguments.len != 0) value.arguments.len + 1 else 0);
    try out.splatByteAll(' ', 29 - @min(width, 28));
    try out.print("{s}\n", .{value.summary});
    if (extended) {
        var lines = std.mem.splitScalar(u8, value.details, '\n');
        while (lines.next()) |line| try out.print("  {s}\n", .{line});
        try out.writeByte('\n');
    }
}
pub fn write(out: *std.Io.Writer, input: []const u8) !void {
    var topic = std.mem.trim(u8, input, " \t");
    var extended = false;
    if (std.mem.eql(u8, topic, "--all") or std.mem.startsWith(u8, topic, "--all ") or std.mem.startsWith(u8, topic, "--all\t")) {
        extended = true;
        topic = std.mem.trim(u8, topic[5..], " \t");
    }
    if (topic.len == 0) {
        for (commands) |command| try entry(out, command, extended);
        try out.writeAll("\nRun .help COMMAND for command details.\nRun .help --all for extended command help.\nOther topics: sql, settings, shortcuts.\n");
        return;
    }
    if (topic[0] == '.') topic = topic[1..];
    for (commands) |command| if (std.ascii.eqlIgnoreCase(topic, @tagName(command.name))) return entry(out, command, true);
    inline for (topics) |item| if (std.ascii.eqlIgnoreCase(topic, item[0])) return out.print("{s}\n", .{item[1]});
    if (std.ascii.eqlIgnoreCase(topic, "SHOW") or std.ascii.eqlIgnoreCase(topic, "SET") or std.ascii.eqlIgnoreCase(topic, "RESET")) return write(out, "settings");
    return error.UnknownHelpTopic;
}
test "help catalog covers exactly the supported commands in alphabetical order" {
    const t = std.testing;
    try t.expectEqual(@typeInfo(Meta).@"enum".field_names.len, commands.len);
    for (commands, 0..) |command, i| {
        if (i != 0) try t.expect(std.mem.order(u8, @tagName(commands[i - 1].name), @tagName(command.name)) == .lt);
    }
}

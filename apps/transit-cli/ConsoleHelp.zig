//! Local command discovery. Help is independent of SQL result formatting.
const std = @import("std");
const Assistance = @import("transit_query").Assistance;
const Meta = Assistance.Meta;
const Entry = struct { name: Meta, arguments: []const u8, summary: []const u8, details: []const u8 };
pub const commands = [_]Entry{
    .{ .name = .connect, .arguments = "FILE", .summary = Assistance.metaSummary(.connect), .details = "Terminal only. Closes the current session and opens FILE.\nPaths may be quoted. Accepted writes remain owned by the service.\nExample: .connect ./connection.yaml" },
    .{ .name = .edit, .arguments = "", .summary = Assistance.metaSummary(.edit), .details = "Opens the latest SQL statement, including one that failed; skips dot commands.\nSave and close to execute, even without text changes. Close without saving to cancel.\nRequires an interactive terminal and $EDITOR. With no SQL history, opens an empty file.\nEditors that detach must wait for the file to close, for example: code --wait." },
    .{ .name = .execute, .arguments = "FILE", .summary = Assistance.metaSummary(.execute), .details = "FILE contains one SQL query object and optional typed parameters.\nExample: {\"sql\":\"SELECT * FROM items LIMIT $1\",\"parameters\":[{\"unsigned\":\"3\"}]}\nParameters are bound to prepared types, never substituted into SQL text.\nFile paths may be quoted. At most 65 parameters and 131072 input-file bytes." },
    .{ .name = .help, .arguments = "[--all] [TOPIC]", .summary = Assistance.metaSummary(.help), .details = "Use .help COMMAND for one command, or .help --all for all command details.\nTopics: sql, settings, shortcuts, INSERT, UPDATE, DELETE, CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE SCHEMA, ALTER SCHEMA, DROP SCHEMA.\nTopic names are case-insensitive; a command may include its leading dot.\nWith a topic, --all shows only that topic. Help is text in both output modes." },
    .{ .name = .info, .arguments = "", .summary = Assistance.metaSummary(.info), .details = "Displays the connected account, database, selected source and authorized source bindings.\nThe service checks current permissions. .sources is an alias for .info." },
    .{ .name = .mode, .arguments = "table|json", .summary = Assistance.metaSummary(.mode), .details = "table displays escaped, bounded cell previews. json streams exact typed values.\nOnly the final JSON completion record confirms that all rows were received.\nErrors and timing use stderr. .help and .show remain text in either mode." },
    .{ .name = .quit, .arguments = "", .summary = Assistance.metaSummary(.quit), .details = "Closes this session and releases its active result. EOF also exits.\nExiting does not undo accepted writes." },
    .{ .name = .schema, .arguments = "[TABLE]", .summary = Assistance.metaSummary(.schema), .details = "With TABLE, runs DESCRIBE TABLE to show authorized columns, types, defaults and keys.\nWithout an argument, lists available tables.\nExample: .schema people" },
    .{ .name = .show, .arguments = "", .summary = Assistance.metaSummary(.show), .details = "Prints effective connection, output-format and timing settings with their origins.\nFor server and SQL session settings, use .help settings." },
    .{ .name = .sources, .arguments = "", .summary = Assistance.metaSummary(.sources), .details = "Displays the same account, database and authorized source context as .info." },
    .{ .name = .tables, .arguments = "", .summary = Assistance.metaSummary(.tables), .details = "Runs SHOW TABLES in the current database under current permissions.\nUse .schema TABLE to inspect columns." },
    .{ .name = .timer, .arguments = "on|off", .summary = Assistance.metaSummary(.timer), .details = "Timing is off by default. Reports client-observed submission, waiting, fetching\nand rendering time to stderr, including failed statements.\nThis is elapsed client time, not a server execution or network-only measurement." },
};
const topics = .{
    .{ "sql", "Discover tables with .tables and inspect columns with .schema TABLE.\n\nSELECT * FROM people LIMIT 8;\nSELECT id, name FROM people WHERE id >= 0;\nSELECT COUNT(*) FROM people;\nSELECT SUM(chosen.value) FROM (SELECT value FROM items LIMIT 8) AS chosen;\n\nSUM requires INT64 values. An outer aggregate LIMIT does not limit its input.\nGeneral Table SQL is limited to 4096 UTF-8 bytes and 128 output columns.\nFinite relational SELECT supports the catalog query profile.\n\nStatement help: INSERT, UPDATE, DELETE, CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE SCHEMA, ALTER SCHEMA, DROP SCHEMA.\nUse .help settings for SHOW, SET, RESET and configuration reload.\nTransactions, RETURNING and expression assignments are unsupported.\nGRANT/REVOKE and CREATE CONNECTION/SOURCE/SINK/KV/DOCUMENT do not execute here." },
    .{ "settings", "Console preferences: .mode table|json, .timer on|off, .show.\n\nSHOW ALL; SHOW ports.gateway; SHOW query.statement_timeout;\nSELECT name, value, pending_restart FROM transit_settings();\nSET query.statement_timeout = '5s'; RESET query.statement_timeout; RESET ALL;\nSHOW DATABASES; SHOW SCHEMAS; SHOW TABLES;\n\nSET affects this session within its administrator ceiling; RESET restores its defaults.\nSELECT transit_reload_conf(); reloads the pinned server file with its startup environment.\nReload requires its own grant. Ports and topology changes can require a server restart.\nPartial application is reported as partial. Interrupting the wait does not undo a reload." },
    .{ "shortcuts", "Enter          Submit semicolon-terminated SQL/dot commands; otherwise insert a newline\nTab            Open completion; accept a selected suggestion or history match\nShift-Tab      Open suggestions without insertion; select the previous item\nUp / Down      Move through draft rows, then history; select within a menu/search\nCtrl-P / Ctrl-N Recall older/newer history from any row\nCtrl-R         Search using the current draft (again: older match)\nEsc / Ctrl-G   Restore the original draft from search; dismiss suggestions\nCtrl-C         Clear the unsubmitted draft, including history search\nCtrl-Z / Ctrl-_ Undo edits; Ctrl-X then Ctrl-U also undoes\nCtrl-Space     Optional completion alias when the terminal sends NUL\nPgUp / PgDn    Page through the selected suggestion's full spelling and details\nCtrl-A / Home  Move to the start\nCtrl-E / End   Move to the end\nCtrl-U         Delete text before the cursor; clear the history filter in search\nCtrl-D         Exit when the draft is empty\n\nCompletion/history acceptance never executes; press Enter again to submit.\nSearch filter edits are discarded on Esc; accepting a match edits the draft.\nHistory search ignores ASCII case and folds whitespace, preserving original text.\nHistory is stored in ~/.transit_history. Paste is one undoable edit and never submits.\nCtrl-C during execution interrupts the current statement and discards pasted suffixes.\nStopping a wait does not undo an accepted write." },
    .{ "INSERT", "INSERT INTO people (id, name) VALUES (1, 'Ada'), (2, 'Grace');\n\nAccepts 1-1024 typed rows, reordered or omitted columns, DEFAULT and NULL.\nOne statement publishes atomically; a rejected row never leaves an inserted prefix.\nUse .schema people for columns, defaults and keys. Requires current write rights." },
    .{ "UPDATE", "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1;\n\nAssignments accept typed constants or DEFAULT; expression assignments are unsupported.\nPredicates support finite scalar comparisons and state tests with NOT, AND and OR.\nOne statement publishes atomically. Changed and matched rows can differ.\nRequires current write rights; query access alone does not grant writes." },
    .{ "DELETE", "DELETE FROM people WHERE id >= 1;\n\nPredicates support finite scalar comparisons and state tests with NOT, AND and OR.\nExact primary-key equality uses the point path; other predicates select a finite snapshot.\nOne statement publishes atomically. Requires current write rights." },
    .{ "CREATE TABLE", "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL);\nCREATE TABLE notes (id INT64, note UTF8);\n\nSchemas have 1-128 columns. Columns are nullable unless declared otherwise.\nPRIMARY KEY implies NOT NULL; without one, internal row identities preserve duplicates.\nINTEGER means int32; BIGINT means int64; INT8 means eight bits.\nVARCHAR(n) limits Unicode scalars. Logical types include signed/unsigned integers,\nfinite floats, decimals, temporal values, UUID, binary and nested types.\nIF NOT EXISTS preserves the existing object. Requires current catalog create rights.\nCreated tables are discoverable through .tables without another worker." },
    .{ "ALTER TABLE", "ALTER TABLE people ADD COLUMN email VARCHAR(320);\nALTER TABLE people RENAME COLUMN name TO full_name;\nALTER TABLE people DROP COLUMN email;\n\nAlso supports table rename, SET/DROP DEFAULT, SET/DROP NOT NULL and admitted\nexact type conversions. Requires current catalog alter rights." },
    .{ "CREATE SCHEMA", "CREATE SCHEMA reporting AUTHORIZATION CURRENT_USER;\n\nRequires database ownership and SET eligibility for the chosen owner.\nPublishes an empty namespace with a stable identity; SHOW SCHEMAS lists it.\nIt does not change the session's configured namespace or grant PUBLIC access." },
    .{ "ALTER SCHEMA", "ALTER SCHEMA reporting RENAME TO reports;\n\nRequires current schema ownership. Retains the schema identity and Table bindings.\nPrepared metadata rejects a later schema change or replacement." },
    .{ "DROP SCHEMA", "DROP SCHEMA reports RESTRICT;\n\nRequires current schema ownership. Live or pending Table declarations block DROP.\nCASCADE is unsupported. Name reuse allocates a new identity.\nDisconnecting does not undo an accepted change." },
    .{ "DROP TABLE", "DROP TABLE people;\nDROP TABLE IF EXISTS people;\n\nRetires the original Table and removes its live name. CASCADE is unsupported.\nExplicitly registered definition dependencies block DROP. Consumers must register them.\nRequires current catalog drop rights. Dropping a table is not undone by disconnecting." },
    .{ "migrations", "Plan, apply, resume and verify ordered SQL schema migrations with transit migrate:\n\ntransit migrate plan --dir migrations --out plan.json\ntransit migrate inspect --plan plan.json\ntransit migrate apply --dir migrations\ntransit migrate status\ntransit migrate resume\ntransit migrate verify --dir migrations\n\nEach step binds a deterministic token in DirectCatalog and reconciles CREATE TABLE\nIF NOT EXISTS against live TableSchema definitions to surface schema drift." },
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

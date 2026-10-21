//! Offline discovery of selected SQL semantics and connection requirements.
const std = @import("std");
const Console = @import("Console.zig").Console;
pub fn write(console: *Console, topic: []const u8) !void {
    const mutation = std.ascii.eqlIgnoreCase(topic, "INSERT") or std.ascii.eqlIgnoreCase(topic, "UPDATE") or std.ascii.eqlIgnoreCase(topic, "DELETE");
    const declaration = std.ascii.eqlIgnoreCase(topic, "CREATE TABLE") or std.ascii.eqlIgnoreCase(topic, "ALTER TABLE") or std.ascii.eqlIgnoreCase(topic, "DROP TABLE");
    const text = if (mutation)
        \\INSERT INTO people (id, name) VALUES (1, 'Ada'), (2, 'Grace');
        \\UPDATE people SET name = 'Ada Lovelace' WHERE id = 1;
        \\DELETE FROM people WHERE id >= 1;
        \\INSERT accepts 1-1024 typed rows, reordered/omitted columns, DEFAULT and NULL.
        \\UPDATE uses typed constant or DEFAULT assignments. UPDATE/DELETE accept finite scalar predicates and state tests with NOT, AND and OR.
        \\Exact primary-key equality uses the point path; other predicates select a frozen finite statement.
        \\One statement publishes atomically. A rejected row never leaves an inserted prefix.
        \\Affected counts mean changed rows; differing matched counts are reported separately.
        \\Use DESCRIBE people or .schema people for authorized columns, defaults and keys.
        \\The service owns the account ledger and catalog binding. No client recovery file is needed.
        \\Native grants and current catalog policy are required; query access grants no writes.
        \\.status observes; .resume reconciles exact saved work; .cancel requests cancellation before publication.
        \\Ctrl-C stops waiting and retains the operation token. It does not undo an accepted write.
        \\
    else if (declaration)
        \\CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL, active BOOL DEFAULT TRUE);
        \\CREATE TABLE notes (id INT64, note UTF8);
        \\Schemas have 1-128 columns. Omitted nullability is nullable; PRIMARY KEY implies NOT NULL.
        \\Without a declared primary key, stable internal row identities preserve duplicate rows.
        \\Aliases include SMALLINT/INTEGER/INT/BIGINT, BOOLEAN/BOOL, TEXT/VARCHAR, REAL, DOUBLE PRECISION and NUMERIC/DECIMAL.
        \\INT8 means eight bits. VARCHAR(n) limits Unicode scalars; it is not ignored.
        \\Logical types include all signed/unsigned widths through 128 bits, finite floats, decimals, temporal values, UUID, binary and nested types.
        \\ALTER TABLE people ADD COLUMN email VARCHAR(320);
        \\ALTER TABLE people RENAME COLUMN name TO full_name;
        \\ALTER TABLE people DROP COLUMN email;
        \\ALTER also supports table rename, SET/DROP DEFAULT, SET/DROP NOT NULL and exact admitted type conversions.
        \\DROP TABLE people; -- RESTRICT; registered dependencies can block deletion
        \\IF NOT EXISTS/IF EXISTS preserve the original object outcome. CASCADE is unsupported.
        \\New Tables are discoverable and routable in the configured catalog without another worker.
        \\CREATE, read, DML, ALTER and DROP require their separate current catalog rights.
        \\.status observes; .resume reconciles original intent; .cancel never undoes published work.
        \\
    else if (std.ascii.eqlIgnoreCase(topic, "SETTINGS") or std.ascii.eqlIgnoreCase(topic, "SHOW") or std.ascii.eqlIgnoreCase(topic, "SET") or std.ascii.eqlIgnoreCase(topic, "RESET"))
        \\SHOW ALL; SHOW ports.gateway; SHOW query.statement_timeout;
        \\SELECT name, value, pending_restart FROM transit_settings();
        \\SELECT transit_reload_conf();
        \\SELECT operation, phase FROM transit_config_reloads() ORDER BY ordinal DESC LIMIT 20;
        \\SET query.statement_timeout = '5s'; RESET query.statement_timeout; RESET ALL;
        \\SHOW DATABASES; SHOW SCHEMAS; SHOW TABLES;
        \\Reload validates the pinned file with captured startup environment, then applies live values.
        \\Ports and service topology remain pending until server restart; initialization-only values reject.
        \\Reload is standalone and requires its own current grant. Metadata reads never dispatch.
        \\.status observes a saved reload; .resume retries its exact identity. Timeout does not undo it.
        \\SET affects this session within its captured ceiling; RESET restores its captured default.
        \\The service supplies settings and catalog bindings; access uses current account rights.
        \\
    else if (topic.len == 0 or std.ascii.eqlIgnoreCase(topic, "SQL"))
        \\SQL: SELECT; DESCRIBE name; SHOW ALL/key/DATABASES/SCHEMAS/TABLES; SET/RESET; CREATE/ALTER/DROP TABLE; INSERT/UPDATE/DELETE.
        \\Use .help SETTINGS for configuration inspection, reload and session controls.
        \\Use .tables and DESCRIBE name to discover authorized Tables and columns.
        \\  SELECT * FROM people LIMIT 8;
        \\  SELECT id, name FROM people WHERE id >= 0;
        \\  SELECT COUNT(*) FROM people;
        \\  SELECT SUM(chosen.value) FROM (SELECT value FROM items LIMIT 8) AS chosen;
        \\SUM requires INT64 values. An outer aggregate LIMIT is not an input limit.
        \\General Table SQL is limited to 4096 UTF-8 bytes and 128 output columns.
        \\Finite relational SELECT supports the catalog query profile. Expression assignments, RETURNING and transaction sessions are not admitted.
        \\.help [SQL|SETTINGS|INSERT|UPDATE|DELETE|CREATE TABLE|ALTER TABLE|DROP TABLE]
        \\.tables .schema [name] .sources .mode table|json
        \\.timer on|off .connect PATH .show .info .quit
        \\.execute FILE runs one JSON query object; parameter admission depends on the query source.
        \\Recovery: .status [all|token:HEX|KIND:ID] .resume [token:HEX|KIND:ID] .cancel [token:HEX|KIND:ID]
        \\KIND is table, configuration or captured. Repeating SQL creates new work; exact recovery uses the original identity.
        \\General Table SELECT uses an interactive captured snapshot; its final completion marker verifies the emitted prefix.
        \\Table display truncates long cells explicitly; JSON output retains typed values.
        \\Ctrl-R searches SQL and dot-command history in ~/.transit_history. Enter accepts a match for editing.
        \\GRANT/REVOKE and CREATE CONNECTION/SOURCE/SINK/KV/DOCUMENT do not execute in the console.
        \\
    else
        return error.UnknownHelpTopic;
    const catalog = true;
    if (console.session.format == .json) return console.json(.{ .commands = [_][]const u8{ "help", "tables", "schema", "sources", "mode", "timer", "connect", "show", "execute", "info", "quit", "status", "resume", "cancel" }, .help = text, .table_writer_configured = true, .catalog_configured = catalog, .authorization = "checked at execution" });
    try console.out.writeAll(text);
    try console.out.print("Table catalog: {s}. Authorization is checked at execution.\n", .{if (catalog) "configured" else "not configured"});
}

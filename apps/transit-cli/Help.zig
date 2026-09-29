//! Offline command help. Human prose never shares a machine-result stream.
const std = @import("std");
const AppOptions = @import("AppOptions.zig");

pub const root =
    \\Transit
    \\
    \\Usage: transit COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  server    Run a local server
    \\  console   Open an SQL console
    \\  app       Manage installed applications
    \\
    \\Options:
    \\  --help     Show this help
    \\  --version  Show version
    \\
    \\Run transit COMMAND --help for command options.
    \\
;
pub const server =
    \\Run a local Transit server in the foreground.
    \\
    \\Usage: transit server [--config PATH] [--initialize] [--no-ui]
    \\
    \\Options:
    \\  --config PATH  Server configuration file (overrides discovery)
    \\  --initialize   Create a new installation; omit when restarting
    \\  --no-ui        Run without Board for this invocation
    \\  --help         Show this help
    \\
    \\The local bundle supplies defaults without a file. Override with the first transit.yaml found in
    \\the current directory, home directory or /etc/transit. TRANSIT_ environment
    \\variables override properties; use __ between nested field names.
    \\Board starts by default with configuration version 3.
    \\Versions 1 and 2 require --no-ui.
    \\Paths in the configuration resolve relative to its file.
    \\
    \\Alias: serve
    \\Configuration: apps/transit-cli/docs/server.md
    \\
;
pub const console =
    \\Open an SQL console.
    \\
    \\Usage: transit console [OPTIONS] [-c SQL | -f FILE]
    \\
    \\Options:
    \\  -c SQL               Execute one SQL statement and exit
    \\  -f FILE              Execute a SQL script and exit
    \\  --init FILE          Read this startup file instead of automatic rc files
    \\  --no-rc              Skip automatic rc files
    \\  --config PATH        Console connection YAML file
    \\  --format table|json  Result display (overrides rc and connection settings)
    \\  --help               Show this help
    \\
    \\Default: connect to the local installation using transit.yaml or server defaults.
    \\Merge /etc/transit/transitrc, ~/.transitrc and ./.transitrc settings.
    \\--config overrides TRANSIT_CONSOLE_CONFIG and rc .connect.
    \\Paths in the configuration resolve relative to its file.
    \\Submit SQL with a semicolon. .help lists dot commands.
    \\YAML configures connections; .transitrc contains dot commands.
    \\Disconnecting does not cancel accepted work.
    \\
    \\Configuration: apps/transit-cli/docs/console.md
    \\
;
pub fn query(v2: bool) []const u8 {
    return if (v2)
        \\Open the single-line KV/Table/Document query shell.
        \\
        \\Usage: transit query-v2 CONFIG
        \\
        \\Arguments:
        \\  CONFIG  Query configuration file (required)
        \\
        \\Options:
        \\  --help  Show this help
        \\
        \\SQL runs on Enter. .help lists session commands.
        \\Configuration: apps/transit-cli/docs/unified-query.md
        \\
    else
        \\Open the single-line Table query shell.
        \\
        \\Usage: transit query CONFIG
        \\
        \\Arguments:
        \\  CONFIG  Query configuration file (required)
        \\
        \\Options:
        \\  --help  Show this help
        \\
        \\SQL runs on Enter. .help lists session commands.
        \\Configuration: apps/transit-cli/README.md
        \\
    ;
}
pub const app =
    \\Manage installed applications.
    \\
    \\Usage: transit app COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  install  Submit an application installation
    \\  replace  Submit a conditional role replacement
    \\  retry    Retry a saved request with its original operation ID
    \\  status   Read application state and a receipt page
    \\  connect  Export a named caller connection
    \\
    \\Options:
    \\  --help  Show this help
    \\
    \\Run transit app COMMAND --help for command options.
    \\
;
pub fn application(io: std.Io, mode: AppOptions.Mode) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    const out = &writer.interface;
    try out.print("{s}\n\nUsage: {s}{s}\n\nOptions:\n  --config PATH       Management configuration YAML file (required)\n", .{
        switch (mode) {
            .install => "Submit an application installation.",
            .replace => "Submit a conditional role replacement.",
            .retry => "Retry the original saved application request.",
            .status => "Read application state and a receipt page.",
            .connect => "Export a named caller connection.",
        },
        AppOptions.usage(mode),
        switch (mode) {
            .status => " [--after INDEX] [--operation ID]",
            .connect => " [--output FILE] [--operation ID]",
            else => "",
        },
    });
    switch (mode) {
        .install => try out.writeAll("  --file DECLARATION  Application declaration file (required)\n"),
        .replace => try out.writeAll("  --file REPLACEMENT  Role replacement file (required)\n"),
        .status, .connect => try out.writeAll("  --application NAME  Installed application name (required)\n"),
        .retry => {},
    }
    if (mode == .connect) try out.writeAll("  --caller NAME       Caller connection name (required)\n  --output FILE       Write the connection to this file (default: stdout)\n");
    if (mode == .status) try out.writeAll("  --after INDEX       Receipt page index, 0-4294967295 (default: 0)\n");
    try out.writeAll(if (mode == .status or mode == .connect)
        "  --operation ID      Read request identity (default: read)\n"
    else
        "  --operation ID      Durable operation identity (required)\n");
    try out.writeAll("  --help              Show this help\n");
    switch (mode) {
        .install, .replace => try out.writeAll("\nThe request is saved before submission. Acceptance does not mean completion.\nAfter an unknown outcome, use app retry with the same config and operation ID.\nArtifact paths resolve relative to --file; omitted hashes are computed locally.\n"),
        .retry => try out.writeAll("\nUse the original configuration and operation ID to retry the saved signed request.\n"),
        .status => try out.writeAll("\nUse the previous page's next index as --after to read another receipt page.\n"),
        .connect => try out.writeAll("\nThe connection refers to the caller's seed file; it contains no private key.\n"),
    }
    try out.writeAll("\nConfiguration: apps/transit-cli/docs/applications.md\n");
    try out.flush();
}

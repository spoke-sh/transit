//! Offline command help. Human prose never shares a machine-result stream.

pub const root =
    \\Transit
    \\
    \\Usage: transit COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  server    Run a local server
    \\  console   Open an SQL console
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
    \\Usage: transit server [--config PATH] [--no-ui]
    \\
    \\Options:
    \\  --config PATH  Server configuration file (overrides discovery)
    \\  --no-ui        Run without Board for this invocation
    \\  --help         Show this help
    \\
    \\The local bundle supplies defaults without a file. Override with the first transit.yaml found in
    \\the current directory, home directory or /etc/transit. TRANSIT_ environment
    \\variables override properties; use __ between nested field names.
    \\Board starts by default with configuration version 1; --no-ui disables it.
    \\Paths in the configuration resolve relative to its file.
    \\
    \\Creates a missing or empty installation; otherwise opens or resumes it.
    \\Set startup.require_existing: true to require retained installation data.
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
    \\  --parameters FILE    Bind a JSON scalar array to a finite SELECT supplied by -c
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
    \\.execute FILE runs a JSON query object with sql and optional parameters.
    \\.edit opens the latest SQL in $EDITOR; save and close to submit it.
    \\Ctrl-R searches SQL and dot-command history in ~/.transit_history.
    \\YAML configures connections; .transitrc contains dot commands.
    \\Each SELECT gets a fresh snapshot. Ctrl-C cancels active reads.
    \\Use console .help for write routes and exact recovery after interruption.
    \\
;

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
;

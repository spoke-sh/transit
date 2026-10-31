//! Offline command help. Human prose never shares a machine-result stream.

pub const root =
    \\Transit
    \\
    \\Usage: transit COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  server    Run a local server
    \\  console   Open an SQL console
    \\  migrate   Plan, apply and verify application schema migrations
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
pub const migrate =
    \\Plan, apply and verify application schema migrations.
    \\
    \\Usage: transit migrate ACTION [OPTIONS]
    \\
    \\Actions:
    \\  plan      Compile and reconcile migration sources against the target schema
    \\  inspect   Inspect a saved plan or migration sources against live state
    \\  apply     Apply pending migration steps and record durable receipts
    \\  status    Show recorded migration ledger state for the target namespace
    \\  resume    Reconcile an interrupted migration attempt by its durable step tokens
    \\  verify    Verify recorded migration schemas and checksums against live state
    \\
    \\Options:
    \\  --dir PATH           Directory of ordered <version>-<name>.sql files
    \\  -f FILE              Explicit migration SQL file (repeatable)
    \\  --plan FILE          Saved migration plan JSON file
    \\  --out FILE           Write compiled plan JSON to FILE (with plan)
    \\  --config PATH        Console connection YAML/JSON file (overrides discovery)
    \\  --database NAME      Assert target database name
    \\  --schema NAME        Assert target schema name
    \\  --branch ID          Assert target branch ID
    \\  --account NAME       Assert target account name
    \\  --attempt HEX        Resume or bind a 16-byte attempt ID (32 hex characters)
    \\  --allow-grants       Allow GRANT/REVOKE/ROLE statements in migrations
    \\  --format table|json  Output format (default: table)
    \\  --help               Show this help
    \\
;

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
    \\  build     Compile application modules to executable SQL
    \\  test      Run isolated Table and Queue program tests
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

pub const build =
    \\Compile typed modules or explicit-basis Table migrations offline without applying SQL.
    \\
    \\Usage: transit build [-f FILE] [--target NAME] [--out DIRECTORY] [--check] [--fetch] [--override NAME=DIRECTORY] [--format text|json] [--help]
    \\
    \\Options:
    \\  -f FILE                    Build entry file (default: build.transit)
    \\  --target NAME              Build target (default: default)
    \\  --out DIRECTORY            Publish artifacts to a new directory
    \\  --check                    Validate and verify SQL without publishing artifacts
    \\  --fetch                    Fetch pinned repositories and write transit.lock
    \\  --override NAME=DIRECTORY  Use a local dependency directory (repeatable)
    \\  --format text|json         Output format (default: text)
    \\  --help                     Show this help
    \\
;

pub const @"test" =
    \\Run Table and Queue program tests in fresh local databases.
    \\
    \\Usage: transit test [-f FILE] [--target NAME] [--override NAME=DIRECTORY] [--format text|json] [--help]
    \\
    \\Options:
    \\  -f FILE                    Build entry file (default: build.transit)
    \\  --target NAME              Test target (default: tests)
    \\  --override NAME=DIRECTORY  Use a local dependency directory (repeatable)
    \\  --format text|json         Output format (default: text)
    \\  --help                     Show this help
    \\
;

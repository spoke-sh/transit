// Transit's SQL extension grammar: the statement forms Postgres has no
// opinion on (CONNECTION/SOURCE/SINK, AS OF time travel, SHOW/DESCRIBE),
// plus the DDL forms that are relational spellings of typed commands Station
// already implements (CREATE TABLE/DOCUMENT/KV, GRANT/REVOKE). See
// docs/QUERY_LANGUAGE.md. This is NOT a complete SQL grammar: it does not
// define SELECT/expression syntax, and it is meant to compose with (import
// into) a full Postgres-compatible base grammar later, not replace one.
// Keywords are fixed-case here for a first, checkable draft; the full
// grammar needs SQL's usual case-insensitive keyword matching.
grammar TransitExtensions;

// ---- Parser rules -----------------------------------------------------

extensionStatement
    : createConnection
    | createSource
    | createSink
    | createTable
    | createDocument
    | createKv
    | grantStatement
    | revokeStatement
    | showStatement
    | describeStatement
    ;

// CREATE CONNECTION kafka_conn TO HTTP (endpoint = 'https://...', token = SECRET('...'));
createConnection
    : CREATE CONNECTION identifier TO connectorKind connectionOptions
    ;

// CREATE SOURCE trades FROM HTTP CONNECTION kafka_conn WITH (poll_ms = '1000');
// A new Fuze source adapter (docs/GLOSSARY.md's "Query source adapter")
// backed by a connector's captured observations, not durable state.
createSource
    : CREATE SOURCE identifier FROM connectorKind CONNECTION identifier connectionOptions?
    ;

// CREATE SINK fills INTO HTTP CONNECTION kafka_conn WITH (path = '/orders');
// A write target that dispatches a connector effect attempt
// (contracts/../docs/CONNECTORS.md#effect-boundary), not a durable row store.
createSink
    : CREATE SINK identifier INTO connectorKind CONNECTION identifier connectionOptions?
    ;

connectorKind
    : identifier // e.g. HTTP, GRPC: a docs/CONNECTORS.md connector family name
    ;

connectionOptions
    : LPAREN connectionOption (COMMA connectionOption)* RPAREN
    ;

connectionOption
    : identifier EQ optionValue
    ;

optionValue
    : STRING
    | secretRef
    ;

// docs/CONNECTORS.md#variables-and-secrets: names a credential binding,
// never carries or echoes the secret value itself.
secretRef
    : SECRET LPAREN STRING RPAREN
    ;

// CREATE TABLE orders (id INT64 NOT NULL, sym UTF8);
// A relational spelling of Table.create/table_create; see
// docs/QUERY_LANGUAGE.md's noted prerequisite (today's Table is fixed at
// exactly two columns, so a real multi-column CREATE TABLE needs that
// model to grow first — this rule states the target shape, not current
// support).
createTable
    : CREATE TABLE identifier LPAREN columnDef (COMMA columnDef)* RPAREN
    ;

columnDef
    : identifier dataType nullability?
    ;

nullability
    : NOT NULL_
    | NULL_
    ;

dataType
    : INT64
    | BOOL
    | UTF8
    | BINARY
    ;

// CREATE DOCUMENT profile; — M13's Document model, DDL form.
createDocument
    : CREATE DOCUMENT identifier
    ;

// CREATE KV settings (UTF8); — the growing profile's KV resource, DDL form.
createKv
    : CREATE KV identifier LPAREN dataType RPAREN
    ;

// GRANT/REVOKE spell the existing typed grant/revoke commands
// (packages/zig/transit-core's .grant/.revoke, Query.setPolicy) as DDL,
// exactly like CREATE TABLE spells table_create.
grantStatement
    : GRANT privilege (COMMA privilege)* ON identifier TO identifier
    ;

revokeStatement
    : REVOKE privilege (COMMA privilege)* ON identifier FROM identifier
    ;

privilege
    : identifier
    ;

// SHOW TABLES; SHOW SOURCES; SHOW SINKS; SHOW CONNECTIONS;
// The relational-surface answer to `transit-cli`'s planned `/tables`-style
// meta-commands (docs/roadmap/M12.md) — same catalog, two frontends.
showStatement
    : SHOW catalogKind
    ;

catalogKind
    : TABLES
    | SOURCES
    | SINKS
    | CONNECTIONS
    ;

describeStatement
    : DESCRIBE identifier
    ;

// A fragment only: composes into the eventual SELECT grammar attached to a
// table reference, not defined here — `orders FOR SYSTEM_TIME AS OF 240`.
// Deliberately the SQL:2011 system-versioned-table clause name (forensic
// point-in-time reconstruction, not a windowing/event-time concept: see
// docs/QUERY_LANGUAGE.md's forensic-first scoping), but its argument is a
// Transit revision — an integer journal position — not the standard's
// wall-clock TIMESTAMP literal. Names existing retained-read-version
// machinery (contracts/READ_VERSIONS_V1.md, GROWTH-10) rather than inventing
// new historical-read semantics.
asOfClause
    : FOR SYSTEM_TIME AS OF INTEGER
    ;

identifier
    : IDENTIFIER
    ;

// ---- Lexer rules --------------------------------------------------------

CREATE: 'CREATE';
CONNECTION: 'CONNECTION';
CONNECTIONS: 'CONNECTIONS';
SOURCE: 'SOURCE';
SOURCES: 'SOURCES';
SINK: 'SINK';
SINKS: 'SINKS';
TABLE: 'TABLE';
TABLES: 'TABLES';
DOCUMENT: 'DOCUMENT';
KV: 'KV';
TO: 'TO';
FROM: 'FROM';
INTO: 'INTO';
WITH: 'WITH';
GRANT: 'GRANT';
REVOKE: 'REVOKE';
ON: 'ON';
SHOW: 'SHOW';
DESCRIBE: 'DESCRIBE';
NOT: 'NOT';
NULL_: 'NULL';
SECRET: 'SECRET';
AS: 'AS';
OF: 'OF';
FOR: 'FOR';
SYSTEM_TIME: 'SYSTEM_TIME';
INT64: 'INT64';
BOOL: 'BOOL';
UTF8: 'UTF8';
BINARY: 'BINARY';

LPAREN: '(';
RPAREN: ')';
COMMA: ',';
EQ: '=';

IDENTIFIER: [a-zA-Z_][a-zA-Z0-9_]*;
INTEGER: [0-9]+;
STRING: '\'' (~['\\] | '\\' .)* '\'';

WS: [ \t\r\n]+ -> skip;
SEMI: ';' -> skip; // Statement termination; a full grammar owns statement lists.

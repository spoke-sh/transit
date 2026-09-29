// Read-only Table SQL plus grammar-only administrative extensions.
// See README.md for exact lexical, compilation and compatibility boundaries.
grammar TransitExtensions;
options { caseInsensitive = true; }

statement: (selectStatement | extensionStatement) SEMI? EOF;
asOfFragment: asOfClause EOF;

// A single predicate and at most two columns, matching Fuze's existing model.
// The one derived-table form spells filter -> limit -> aggregate without
// misinterpreting SQL's outer LIMIT as an aggregate input limit.
selectStatement
    : SELECT selection FROM identifier whereClause? limitClause?
    | SELECT aggregateSelection FROM LPAREN
        SELECT projection FROM identifier whereClause? limitClause?
      RPAREN AS identifier limitClause?
    ;
selection: projection | aggregateSelection;
aggregateSelection: COUNT LPAREN STAR RPAREN | SUM LPAREN columnReference RPAREN;
projection: STAR | columnReference (COMMA columnReference)?;
columnReference: identifier (DOT identifier)?;
whereClause: WHERE predicate;
predicate: columnReference (IS NULL_ | comparison literal);
comparison: EQ | NE | LT | LE | GT | GE;
literal: signedInteger | TRUE | FALSE | NULL_ | STRING (TYPECAST BYTEA)?;
signedInteger: (PLUS | MINUS)? INTEGER;
limitClause: LIMIT INTEGER;


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
// A new Fuze source adapter (docs/reference/glossary.md's "Query source adapter")
// backed by a connector's captured observations, not durable state.
createSource
    : CREATE SOURCE identifier FROM connectorKind CONNECTION identifier (WITH? connectionOptions)?
    ;

// CREATE SINK fills INTO HTTP CONNECTION kafka_conn WITH (path = '/orders');
// A write target that dispatches a connector effect attempt
// (docs/reference/connectors.md), not a durable row store.
createSink
    : CREATE SINK identifier INTO connectorKind CONNECTION identifier (WITH? connectionOptions)?
    ;

connectorKind
    : identifier // e.g. HTTP, GRPC: a docs/reference/connectors.md connector family name
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

// docs/reference/security.md#effects-and-secrets: names a credential binding,
// never carries or echoes the secret value itself.
secretRef
    : SECRET LPAREN STRING RPAREN
    ;

// CREATE TABLE orders (id INT64 NOT NULL, sym UTF8);
// A relational spelling of Table.create/table_create; see
// docs/internal/QUERY_LANGUAGE.md's noted prerequisite (today's Table is fixed at
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

// Proposed DDL over M17's Document model; M17 does not implement SQL DDL.
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
// meta-commands (docs/internal/roadmap/M13.md) — same catalog, two frontends.
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

// A fragment only: reserved for a future SELECT table-reference extension,
// deliberately excluded from the executable SELECT profile here — `orders FOR SYSTEM_TIME AS OF 240`.
// Deliberately the SQL:2011 system-versioned-table clause name (forensic
// point-in-time reconstruction, not a windowing/event-time concept: see
// docs/internal/QUERY_LANGUAGE.md's forensic-first scoping), but its argument is a
// Transit revision — an integer journal position — not the standard's
// wall-clock TIMESTAMP literal. Names existing retained-read-version
// machinery (contracts/READ_VERSIONS_V1.md, GROWTH-10) rather than inventing
// new historical-read semantics.
asOfClause
    : FOR SYSTEM_TIME AS OF INTEGER
    ;

identifier
    : IDENTIFIER | QUOTED_IDENTIFIER
    ;

// ---- Lexer rules --------------------------------------------------------

SELECT: 'SELECT';
WHERE: 'WHERE';
LIMIT: 'LIMIT';
COUNT: 'COUNT';
SUM: 'SUM';
IS: 'IS';
TRUE: 'TRUE';
FALSE: 'FALSE';
BYTEA: 'BYTEA';
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
DOT: '.';
STAR: '*';
TYPECAST: '::';
PLUS: '+';
MINUS: '-';
EQ: '=';
NE: '<>' | '!=';
LE: '<=';
LT: '<';
GE: '>=';
GT: '>';
SEMI: ';';

IDENTIFIER: [a-z_][a-z0-9_]*;
QUOTED_IDENTIFIER: '"' ('""' | ~["\u0000])+ '"';
INTEGER: [0-9]+;
// standard_conforming_strings=on: doubled quotes escape a quote; backslashes
// are literal. E strings, dollar quoting and adjacent string concatenation
// are outside this profile.
STRING: '\'' ('\'\'' | ~['\u0000])* '\'';
LINE_COMMENT: '--' ~[\r\n]* -> skip;
BLOCK_COMMENT: '/*' (BLOCK_COMMENT | .)*? '*/' -> skip;
WS: [ \t\r\n]+ -> skip;

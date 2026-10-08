// Finite queries, bounded Table mutations and administrative extensions.
// See README.md for exact lexical, compilation and compatibility boundaries.
grammar TransitExtensions;
options { caseInsensitive = true; }

statement: (selectStatement | mutationStatement | extensionStatement) SEMI? EOF;
asOfFragment: asOfClause EOF;
// Explicit compiler entry; parameters are not accepted by ordinary statements.
parameterTemplate: templateSelect SEMI? EOF;
templateSelect
    : SELECT selection FROM identifier sourceAlias? templateWhereClause? templateLimitClause?
    | SELECT aggregateSelection FROM LPAREN
        SELECT projection FROM identifier sourceAlias? templateWhereClause? templateLimitClause?
      RPAREN AS identifier templateLimitClause?
    ;
templateWhereClause: WHERE templatePredicate;
templatePredicate: columnReference (IS cellState | comparison (literal | PARAMETER));
templateLimitClause: LIMIT (INTEGER | PARAMETER);

// Boolean predicates and a projection bounded by the declared schema at compile time.
// The one derived-table form spells filter -> limit -> aggregate without
// misinterpreting SQL's outer LIMIT as an aggregate input limit.
selectStatement
    : SELECT selection FROM identifier sourceAlias? whereClause? limitClause?
    | SELECT aggregateSelection FROM LPAREN
        SELECT projection FROM identifier sourceAlias? whereClause? limitClause?
      RPAREN AS identifier limitClause?
    ;
sourceAlias: AS identifier;
selection: projection | aggregateSelection;
aggregateSelection: (COUNT LPAREN (STAR | columnReference) RPAREN | SUM LPAREN columnReference RPAREN) outputAlias?;
projection: STAR | projectionItem (COMMA projectionItem)*;
projectionItem: columnReference outputAlias?;
outputAlias: AS identifier;
columnReference: identifier (DOT identifier)?;
whereClause: WHERE predicate;
predicate: disjunction;
disjunction: conjunction (OR conjunction)*;
conjunction: negation (AND negation)*;
negation: NOT negation | LPAREN predicate RPAREN | predicateAtom;
predicateAtom: columnReference (IS NOT? cellState | comparison literal);
cellState: NULL_ | MISSING | TYPE_ERROR | VALUE | CONFLICT;
comparison: EQ | NE | LT | LE | GT | GE;
literal
    : signedInteger | signedNumber | TRUE | FALSE | NULL_ | MISSING
    | STRING (TYPECAST (BYTEA | UINT64 | FLOAT64))?
    | (X | DATE | TIME | TIMESTAMP | UUID | JSON) STRING
    | (STRUCT | LIST | ARRAY | MAP | INTERVAL) LPAREN (literal (COMMA literal)*)? RPAREN
    | UNION LPAREN identifier COMMA literal RPAREN
    ;
signedNumber: (PLUS | MINUS)? NUMBER;
signedInteger: (PLUS | MINUS)? INTEGER;
limitClause: LIMIT INTEGER;

// All mutations bind to a configured catalog and its current permissions.
// Literal/descriptor parsing conveys neither row validity nor execution rights.
mutationStatement
    : INSERT INTO identifier (LPAREN identifier (COMMA identifier)* RPAREN)?
      VALUES mutationRow (COMMA mutationRow)*
    | UPDATE identifier SET assignment (COMMA assignment)* whereClause?
    | DELETE FROM identifier whereClause?
    ;
assignment: columnReference EQ mutationValue;
mutationValue: DEFAULT | literal;
mutationRow: LPAREN mutationValue (COMMA mutationValue)* RPAREN;


// ---- Parser rules -----------------------------------------------------

extensionStatement
    : createConnection
    | createSource
    | createSink
    | createTable
    | alterTable
    | dropTable
    | createDocument
    | createKv
    | grantStatement
    | revokeStatement
    | showStatement
    | describeStatement
    | explainStatement
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

// General typed schemas; constraints, aliases and parameter values are checked
// by the shared compiler. Storage/operator/transport admission remains separate.
createTable
    : CREATE TABLE (IF NOT EXISTS)? identifier LPAREN tableElement (COMMA tableElement)* RPAREN
    ;
tableElement: columnDef | PRIMARY KEY LPAREN identifier (COMMA identifier)* RPAREN;
columnDef: identifier dataType columnConstraint*;
columnConstraint: nullability | DEFAULT literal | PRIMARY KEY;
nullability: NOT NULL_ | NULL_;

dataType
    : scalarTypeName (LPAREN INTEGER (COMMA INTEGER)? RPAREN)? ((WITH | WITHOUT) TIME ZONE)?
    | (STRUCT | UNION) LPAREN typeField (COMMA typeField)* RPAREN
    | LIST LPAREN dataType nullability? RPAREN
    | ARRAY LPAREN dataType nullability? COMMA INTEGER RPAREN
    | MAP LPAREN dataType nullability? COMMA dataType nullability? RPAREN
    ;
// Unknown scalar names/parameter combinations produce attributed binding errors.
// Quoted type names are not aliases. INT8 retains Transit's eight-bit meaning.
scalarTypeName
    : IDENTIFIER | INT64 | UINT64 | FLOAT64 | BOOL | UTF8 | BINARY | BYTEA
    | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL
    | DOUBLE PRECISION? | CHARACTER VARYING
    ;
typeField: identifier dataType nullability? OPTIONAL?;

alterTable
    : ALTER TABLE identifier (
        ADD COLUMN? columnDef
      | DROP COLUMN? identifier RESTRICT?
      | RENAME COLUMN? identifier TO identifier
      | RENAME TO identifier
      | ALTER COLUMN? identifier (
          SET DEFAULT literal | DROP DEFAULT
        | SET NOT NULL_ | DROP NOT NULL_
        | (SET DATA)? TYPE dataType
        )
      )
    ;
dropTable: DROP TABLE (IF EXISTS)? identifier RESTRICT?;

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
// meta-commands (docs/roadmap/M13.md) — same catalog, two frontends.
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

explainStatement
    : EXPLAIN selectStatement
    ;

// Isolated fragment only; no production operation interprets this integer.
// Keep the rule unchanged until a deliberate grammar/contract cutover.
// The intended language reserves FOR SYSTEM_TIME for SQL temporal semantics
// and uses separate typed Transit snapshot/branch/tag and resource selectors.
// See docs/reference/sql/as-of.md; this rule enables neither historical queries
// nor a mapping from a system-time expression to a resource journal revision.
asOfClause
    : FOR SYSTEM_TIME AS OF INTEGER
    ;

identifier
    : IDENTIFIER | QUOTED_IDENTIFIER | MISSING | TYPE_ERROR | VALUE | CONFLICT | UINT64 | FLOAT64 | EXPLAIN
    | INSERT | UPDATE | DELETE | SET | VALUES
    | ALTER | DROP | ADD | COLUMN | RENAME | RESTRICT | DEFAULT | PRIMARY | KEY | IF | EXISTS
    | DATA | TYPE | STRUCT | LIST | ARRAY | MAP | UNION | OPTIONAL | WITHOUT | ZONE
    | X | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | DOUBLE | PRECISION | CHARACTER | VARYING
    ;

// ---- Lexer rules --------------------------------------------------------

SELECT: 'SELECT';
WHERE: 'WHERE';
LIMIT: 'LIMIT';
COUNT: 'COUNT';
SUM: 'SUM';
IS: 'IS';
AND: 'AND';
OR: 'OR';
TRUE: 'TRUE';
FALSE: 'FALSE';
BYTEA: 'BYTEA';
// Contextual keywords remain usable as existing unquoted source/column names.
MISSING: 'MISSING';
TYPE_ERROR: 'TYPE_ERROR';
VALUE: 'VALUE';
CONFLICT: 'CONFLICT';
UINT64: 'UINT64';
FLOAT64: 'FLOAT64';
EXPLAIN: 'EXPLAIN';
ALTER: 'ALTER';
DROP: 'DROP';
ADD: 'ADD';
COLUMN: 'COLUMN';
RENAME: 'RENAME';
RESTRICT: 'RESTRICT';
DEFAULT: 'DEFAULT';
PRIMARY: 'PRIMARY';
KEY: 'KEY';
IF: 'IF';
EXISTS: 'EXISTS';
DATA: 'DATA';
TYPE: 'TYPE';
STRUCT: 'STRUCT';
LIST: 'LIST';
ARRAY: 'ARRAY';
MAP: 'MAP';
UNION: 'UNION';
OPTIONAL: 'OPTIONAL';
WITHOUT: 'WITHOUT';
ZONE: 'ZONE';
X: 'X';
DATE: 'DATE';
TIME: 'TIME';
TIMESTAMP: 'TIMESTAMP';
UUID: 'UUID';
JSON: 'JSON';
INTERVAL: 'INTERVAL';
DOUBLE: 'DOUBLE';
PRECISION: 'PRECISION';
CHARACTER: 'CHARACTER';
VARYING: 'VARYING';
INSERT: 'INSERT';
UPDATE: 'UPDATE';
DELETE: 'DELETE';
SET: 'SET';
VALUES: 'VALUES';
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
NUMBER: [0-9]+ ('.' [0-9]+ ([e] [+-]? [0-9]+)? | [e] [+-]? [0-9]+);
INTEGER: [0-9]+;
PARAMETER: '$' [0-9]+;
// standard_conforming_strings=on: doubled quotes escape a quote; backslashes
// are literal. E strings, dollar quoting and adjacent string concatenation
// are outside this profile.
STRING: '\'' ('\'\'' | ~['\u0000])* '\'';
LINE_COMMENT: '--' ~[\r\n]* -> skip;
BLOCK_COMMENT: '/*' (BLOCK_COMMENT | .)*? '*/' -> skip;
WS: [ \t\r\n]+ -> skip;

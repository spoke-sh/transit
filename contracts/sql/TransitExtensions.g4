// Finite queries, bounded Table mutations and administrative extensions.
// See README.md for exact lexical, compilation and compatibility boundaries.
grammar TransitExtensions;
options { caseInsensitive = true; }

statement: (historicalStatement | selectStatement | mutationStatement | extensionStatement | transactionStatement) SEMI? EOF;
// The SQL service binds this exact catalog before compiling the inner query.
historicalStatement: (selectStatement | SHOW TABLES | DESCRIBE identifier | EXPLAIN selectStatement) snapshotClause;
snapshotClause: AS OF SNAPSHOT STRING;
// Session controls lower to the Catalog-owned local Table transaction contract.
transactionStatement
    : (BEGIN (WORK | TRANSACTION)? | START TRANSACTION) transactionOptions?
    | COMMIT (WORK | TRANSACTION)?
    | ROLLBACK (WORK | TRANSACTION)? (TO SAVEPOINT? identifier)?
    | SAVEPOINT identifier
    | RELEASE SAVEPOINT? identifier
    ;
transactionOptions
    : ISOLATION LEVEL SERIALIZABLE transactionAccess?
    | transactionAccess (ISOLATION LEVEL SERIALIZABLE)?
    ;
transactionAccess: READ (ONLY | WRITE);

// Dedicated administration compiler. Query-only roots do not execute it.
authorizationStatement: authorizationCommand SEMI? EOF;
authorizationCommand
    : grantStatement | revokeStatement
    | CREATE ROLE identifier (WITH? roleOptions)?
    | ALTER ROLE identifier (RENAME TO identifier | WITH? roleOptions)
    | DROP ROLE identifier
    | CREATE SCHEMA identifier (AUTHORIZATION authorizationRole)?
    | ALTER SCHEMA identifier RENAME TO identifier
    | ALTER (DATABASE identifier | SCHEMA identifier | TABLE identifier (DOT identifier)?) OWNER TO authorizationRole
    | DROP SCHEMA identifier RESTRICT?
    | ALTER DEFAULT PRIVILEGES (FOR ROLE authorizationRole)? IN SCHEMA identifier
        (GRANT privilegeList ON TABLES TO grantee grantOption?
        | REVOKE (GRANT OPTION FOR)? privilegeList ON TABLES FROM grantee revokeBehavior?)
    | SET ROLE identifier
    | RESET ROLE
    ;
roleOptions: roleOption+;
roleOption: LOGIN | NOLOGIN | CREATEROLE | NOCREATEROLE;
// Contextual names include CURRENT_ROLE/CURRENT_USER/SESSION_USER/PUBLIC/NONE;
// the production compiler assigns their role meaning and rejects forbidden uses.
authorizationRole: identifier;
grantee: authorizationRole;
authorizationObject: DATABASE identifier | SCHEMA identifier | TABLE? identifier (DOT identifier)?;
privilegeList: ALL PRIVILEGES? | privilege (COMMA privilege)*;
grantOption: WITH GRANT OPTION;
revokeBehavior: RESTRICT | CASCADE;
membershipOption: (ADMIN | INHERIT | SET) (OPTION | TRUE | FALSE);
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

// Explicit Table relational root; admission/type checks remain with RelationalSql.
// The single-source statement root retains its independent LIMIT/subquery profile.
relationalQuery: EXPLAIN? relationalSelect snapshotClause? SEMI? EOF;
relationalSelect
    : SELECT relationalSelection (COMMA relationalSelection)* FROM relationalTarget
      relationalJoin? whereClause? (GROUP BY columnReference (COMMA columnReference)*)?
    ;
relationalSelection
    : (columnReference | COUNT LPAREN (STAR | columnReference) RPAREN
       | SUM LPAREN columnReference RPAREN) outputAlias?
    ;
relationalTarget: identifier relationalAlias?;
relationalAlias: AS identifier | relationalImplicitAlias;
// Clause words cannot consume the next join/group token as an implicit alias.
relationalImplicitAlias: legacyIdentifier | STREAMS | QUEUES | BY;
relationalJoin: (INNER | LEFT OUTER?)? JOIN relationalTarget ON columnReference EQ columnReference;

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
    | createLog
    | alterLog
    | dropLog
    | createDocument
    | createKv
    | grantStatement
    | revokeStatement
    | showStatement
    | sessionSettingStatement
    | configurationSelect
    | describeStatement
    | explainStatement
    ;

// Dedicated log declarations share logical columns, never Table DML semantics.
createLog: CREATE logKind identifier LPAREN tableElement (COMMA tableElement)* RPAREN
    logPartitioning? (WITH logOptions)?;
alterLog: ALTER logKind identifier (SET logOptions | RENAME TO identifier);
dropLog: DROP logKind identifier;
logKind: STREAM | QUEUE;
logPartitioning: (PARTITION BY HASH LPAREN identifier RPAREN)? PARTITIONS INTEGER;
logOptions: LPAREN logOption (COMMA logOption)* RPAREN;
logOption: identifier EQ literal;

// CREATE CONNECTION kafka_conn TO HTTP (endpoint = 'https://...', token = SECRET('...'));
createConnection
    : CREATE CONNECTION identifier TO connectorKind connectionOptions
    ;

// CREATE SOURCE trades FROM HTTP CONNECTION kafka_conn WITH (poll_ms = '1000');
// A new Fuze source adapter (docs/handbook/reference/glossary.md's "Query source adapter")
// backed by a connector's captured observations, not durable state.
createSource
    : CREATE SOURCE identifier FROM connectorKind CONNECTION identifier (WITH? connectionOptions)?
    ;

// CREATE SINK fills INTO HTTP CONNECTION kafka_conn WITH (path = '/orders');
// A write target that dispatches a connector effect attempt
// (docs/handbook/reference/connectors.md), not a durable row store.
createSink
    : CREATE SINK identifier INTO connectorKind CONNECTION identifier (WITH? connectionOptions)?
    ;

connectorKind
    : identifier // e.g. HTTP, GRPC: a docs/handbook/reference/connectors.md connector family name
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

// docs/handbook/reference/security.md#effects-and-secrets: names a credential binding,
// never carries or echoes the secret value itself.
secretRef
    : SECRET LPAREN STRING RPAREN
    ;

// General typed schemas; constraints, aliases and parameter values are checked
// by the shared compiler. Storage/operator/transport admission remains separate.
createTable
    : CREATE TABLE (IF NOT EXISTS)? identifier LPAREN tableElement (COMMA tableElement)* RPAREN
    ;
tableElement: columnDef | PRIMARY KEY LPAREN identifier (COMMA identifier)* RPAREN | tableConstraint;
tableConstraint: (CONSTRAINT identifier)? (checkConstraint | foreignKeyConstraint);
checkConstraint: CHECK LPAREN checkPredicate (AND checkPredicate)* RPAREN (NOT VALID)?;
checkPredicate: columnReference (IS NOT? NULL_ | comparison (literal | columnReference));
foreignKeyConstraint
    : FOREIGN KEY constraintColumns REFERENCES identifier constraintColumns referentialClause* NOT ENFORCED
    ;
constraintColumns: LPAREN identifier (COMMA identifier)* RPAREN;
referentialClause: ON (DELETE | UPDATE) (RESTRICT | NO ACTION | CASCADE | SET NULL_);
columnDef: identifier dataType columnConstraint*;
columnConstraint: nullability | DEFAULT literal | PRIMARY KEY | COLLATE collation;
collation: UTF8_BINARY | ASCII_CI | EBCDIC_CP037 | EBCDIC_037_PAD | EBCDIC_1047_NOPAD;
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
      | ADD tableConstraint
      | DROP CONSTRAINT identifier RESTRICT?
      | VALIDATE CONSTRAINT identifier
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

// One object/role and one recipient. Privilege applicability, duplicate options,
// PUBLIC delegation and role eligibility are production semantic checks.
grantStatement
    : GRANT privilegeList ON authorizationObject TO grantee grantOption?
    | GRANT identifier TO authorizationRole (WITH membershipOption (COMMA membershipOption)*)?
    ;

revokeStatement
    : REVOKE (GRANT OPTION FOR)? privilegeList ON authorizationObject FROM grantee revokeBehavior?
    | REVOKE ((ADMIN | INHERIT | SET) OPTION FOR)? identifier FROM authorizationRole revokeBehavior?
    ;

privilege
    : CONNECT | USAGE | CREATE | SELECT | INSERT | UPDATE | DELETE
    ;

// ALL and bare STORAGE are contextual identifiers parsed by settingKey;
// execution reserves them for settings listing and node storage inspection.
showStatement
    : SHOW (catalogKind | settingKey | STORAGE FOR identifier | logKind identifier)
    ;
settingKey: settingIdentifier (DOT identifier)*;
sessionSettingStatement
    : SET settingKey (EQ | TO) (STRING | INTEGER | DEFAULT)
    | RESET settingKey
    ;
// The shared settings compiler admits only these standalone administration and
// metadata forms. Query-only SELECT roots never dispatch configuration changes.
configurationSelect
    : SELECT TRANSIT_RELOAD_CONF LPAREN RPAREN
    | SELECT projection FROM (TRANSIT_SETTINGS | TRANSIT_CONFIG_RELOADS) LPAREN RPAREN
      whereClause? (ORDER BY identifier (ASC | DESC)?)? limitClause?
    ;

catalogKind
    : TABLES
    | STREAMS
    | QUEUES
    | DATABASES
    | SCHEMAS
    | SOURCES
    | SINKS
    | CONNECTIONS
    ;

describeStatement
    : DESCRIBE logKind? identifier
    ;

explainStatement
    : EXPLAIN selectStatement
    ;

identifier: settingIdentifier | STREAMS | QUEUES | SNAPSHOT;
settingIdentifier: legacyIdentifier | JOIN | INNER | LEFT | OUTER | RIGHT | FULL | CROSS | NATURAL | GROUP | BY | HAVING | ORDER;
legacyIdentifier
    : IDENTIFIER | QUOTED_IDENTIFIER | MISSING | TYPE_ERROR | VALUE | CONFLICT | UINT64 | FLOAT64 | EXPLAIN
    | INSERT | UPDATE | DELETE | SET | VALUES
    | ALTER | DROP | ADD | COLUMN | RENAME | RESTRICT | DEFAULT | PRIMARY | KEY | IF | EXISTS
    | COLLATE | UTF8_BINARY | ASCII_CI | EBCDIC_CP037 | EBCDIC_037_PAD | EBCDIC_1047_NOPAD
    | DATA | TYPE | STRUCT | LIST | ARRAY | MAP | UNION | OPTIONAL | WITHOUT | ZONE
    | X | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | DOUBLE | PRECISION | CHARACTER | VARYING
    | ROLE | LOGIN | NOLOGIN | CREATEROLE | NOCREATEROLE | SCHEMA | DATABASE | AUTHORIZATION
    | OWNER | CURRENT_ROLE | CURRENT_USER | SESSION_USER | PUBLIC | ALL | PRIVILEGES
    | OPTION | ADMIN | INHERIT | CASCADE | NONE | RESET | CONNECT | USAGE | IN
    | BEGIN | START | TRANSACTION | WORK | ISOLATION | LEVEL | SERIALIZABLE | READ | ONLY | WRITE | COMMIT | ROLLBACK | SAVEPOINT | RELEASE
    | TRANSIT_RELOAD_CONF | TRANSIT_SETTINGS | TRANSIT_CONFIG_RELOADS | ASC | DESC | SOURCE | STORAGE
    | STREAM | QUEUE | PARTITION | PARTITIONS | HASH
    | CONSTRAINT | CHECK | FOREIGN | REFERENCES | ENFORCED | VALID | VALIDATE | NO | ACTION
    ;

// ---- Lexer rules --------------------------------------------------------
BEGIN: 'BEGIN';
CONSTRAINT: 'CONSTRAINT';
CHECK: 'CHECK';
FOREIGN: 'FOREIGN';
REFERENCES: 'REFERENCES';
ENFORCED: 'ENFORCED';
VALID: 'VALID';
VALIDATE: 'VALIDATE';
NO: 'NO';
ACTION: 'ACTION';
STREAM: 'STREAM';
QUEUE: 'QUEUE';
STREAMS: 'STREAMS';
QUEUES: 'QUEUES';
PARTITION: 'PARTITION';
PARTITIONS: 'PARTITIONS';
HASH: 'HASH';
START: 'START';
TRANSACTION: 'TRANSACTION';
WORK: 'WORK';
ISOLATION: 'ISOLATION';
LEVEL: 'LEVEL';
SERIALIZABLE: 'SERIALIZABLE';
READ: 'READ';
ONLY: 'ONLY';
WRITE: 'WRITE';
COMMIT: 'COMMIT';
ROLLBACK: 'ROLLBACK';
SAVEPOINT: 'SAVEPOINT';
RELEASE: 'RELEASE';
TRANSIT_RELOAD_CONF: 'TRANSIT_RELOAD_CONF';
TRANSIT_SETTINGS: 'TRANSIT_SETTINGS';
TRANSIT_CONFIG_RELOADS: 'TRANSIT_CONFIG_RELOADS';
DATABASES: 'DATABASES';
SCHEMAS: 'SCHEMAS';
ASC: 'ASC';
DESC: 'DESC';

ROLE: 'ROLE';
LOGIN: 'LOGIN';
NOLOGIN: 'NOLOGIN';
CREATEROLE: 'CREATEROLE';
NOCREATEROLE: 'NOCREATEROLE';
SCHEMA: 'SCHEMA';
DATABASE: 'DATABASE';
AUTHORIZATION: 'AUTHORIZATION';
OWNER: 'OWNER';
CURRENT_ROLE: 'CURRENT_ROLE';
CURRENT_USER: 'CURRENT_USER';
SESSION_USER: 'SESSION_USER';
PUBLIC: 'PUBLIC';
ALL: 'ALL';
PRIVILEGES: 'PRIVILEGES';
OPTION: 'OPTION';
ADMIN: 'ADMIN';
INHERIT: 'INHERIT';
CASCADE: 'CASCADE';
NONE: 'NONE';
RESET: 'RESET';
CONNECT: 'CONNECT';
USAGE: 'USAGE';
IN: 'IN';

JOIN: 'JOIN';
INNER: 'INNER';
LEFT: 'LEFT';
OUTER: 'OUTER';
RIGHT: 'RIGHT';
FULL: 'FULL';
CROSS: 'CROSS';
NATURAL: 'NATURAL';
GROUP: 'GROUP';
BY: 'BY';
HAVING: 'HAVING';
ORDER: 'ORDER';
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
COLLATE: 'COLLATE';
UTF8_BINARY: 'UTF8_BINARY';
ASCII_CI: 'ASCII_CI';
EBCDIC_CP037: 'EBCDIC_CP037';
EBCDIC_037_PAD: 'EBCDIC_037_PAD';
EBCDIC_1047_NOPAD: 'EBCDIC_1047_NOPAD';
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
STORAGE: 'STORAGE';
DESCRIBE: 'DESCRIBE';
NOT: 'NOT';
NULL_: 'NULL';
SECRET: 'SECRET';
AS: 'AS';
OF: 'OF';
FOR: 'FOR';
SNAPSHOT: 'SNAPSHOT';
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

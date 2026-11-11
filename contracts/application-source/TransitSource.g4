// Independent application source reference. Runtime SQL keeps its own root.
grammar TransitSource;
options { caseInsensitive = true; }
import TransitExtensions;

sourceFile: (SEMI | sourceImport | dependency | definition)* EOF;
sourceImport: IMPORT sourceName FROM (PACKAGE sourceName FILE)? STRING SEMI;
dependency: DEPENDENCY sourceName FROM STRING REVISION STRING (SUBDIRECTORY STRING)? SEMI;
definition: CREATE PUBLIC? (MODULE sourceName parameters AS BEGIN body END
    | INTERFACE sourceName parameters
    | TEST? TARGET sourceName AS BEGIN body END) SEMI;
parameters: LPAREN (parameter (COMMA parameter)*)? RPAREN;
parameter: sourceName parameterKind;
parameterKind: BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | TYPE | MODULE sourceQualifiedName;
sourceQualifiedName: sourceName (DOT sourceName)?;
body: sourceStatement*;
sourceStatement
    : USE sourceCall SEMI
    | IF expression THEN body (ELSE body)? END IF SEMI
    | TEST STRING USING MODULES LPAREN (sourceCall (COMMA sourceCall)*)? RPAREN AS BEGIN body END SEMI
    | ASSERT assertion SEMI
    | tableTemplate SEMI
    ;
sourceCall: sourceQualifiedName LPAREN (expression (COMMA expression)*)? RPAREN;
assertion
    : ROWS LPAREN tableTemplate RPAREN EQUAL LPAREN expectedRows? RPAREN
    | COMMAND LPAREN tableTemplate RPAREN MATCHED INTEGER CHANGED INTEGER
    | STATEMENT LPAREN tableTemplate RPAREN FAILS WITH STRING
    ;
expectedRows: expectedRow (COMMA expectedRow)*;
expectedRow: LPAREN literal (COMMA literal)* RPAREN;
expression: sourceOr;
sourceOr: sourceAnd (OR sourceAnd)*;
sourceAnd: sourceComparison (AND sourceComparison)*;
sourceComparison: sourceAdd (sourceComparisonOp sourceAdd)*;
sourceComparisonOp: EQ | LT (EQ | GT)? | GT EQ? | LE | GE | NE;
sourceAdd: sourceMultiply ((PLUS | MINUS) sourceMultiply)*;
sourceMultiply: sourceUnary (STAR sourceUnary)*;
sourceUnary: MINUS sourceUnary | NOT sourceUnary | sourceAtom;
sourceAtom: INTEGER | STRING | TRUE | FALSE | NAME STRING
    | TYPE (BIGINT | TEXT | BOOLEAN) | LPAREN expression RPAREN
    | referenceHead (DOT sourceName)?;

// Only the delivered single-Table profile, with syntax before schema binding.
tableTemplate: CREATE PUBLIC TABLE identifier LPAREN tableElement (COMMA tableElement)* RPAREN
    | mutationStatement | sourceSelect;
sourceSelect: SELECT selection FROM identifier sourceTableAlias? whereClause? limitClause?
    | SELECT aggregateSelection FROM LPAREN SELECT projection FROM identifier sourceTableAlias?
      whereClause? limitClause? RPAREN AS identifier;
sourceTableAlias: AS identifier | sourceImplicitAlias;
sourceImplicitAlias: identifier;
sourceUnsigned: INTEGER | valueHole;
sourceString: STRING | valueHole;
limitClause: LIMIT sourceUnsigned;
comparison: EQ | NE | BANG_NE | LT | LE | GT | GE;
predicateAtom: columnReference (IS NOT? cellState | comparison literal);
// A bare CHECK hole may become a value or a column; its binding decides later.
checkPredicate: columnReference (IS NOT? NULL_ | comparison checkOperand);
checkOperand: checkHole | plainLiteral | plainColumnReference;
plainColumnReference: plainIdentifier (DOT identifier)?;
columnConstraint
    : nullability | DEFAULT literal | PRIMARY KEY | COLLATE collation
    | ROUNDING identifier | METRIC identifier
    | TIMEZONE sourceString TZDB sourceString TZIF X sourceString;
// Foreign keys require catalog resolution outside this source profile.
tableConstraint: (CONSTRAINT identifier)? checkConstraint;

identifier: identifierHole | plainIdentifier;
plainIdentifier: settingIdentifier | STREAMS | QUEUES | SNAPSHOT | CURRENT | PROJECTING
    | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | sourceKeyword;
sourceKeyword: USING | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE | MODULE | INTERFACE | TARGET | TEST | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND;
// Keep the inherited logical type/literal productions; holes extend their sites.
dataType: typeHole | sourceDataType;
sourceDataType
    : scalarTypeName (LPAREN sourceUnsigned (COMMA sourceUnsigned)? RPAREN)? ((WITH | WITHOUT) TIME ZONE)?
    | (STRUCT | ROW | UNION) LPAREN typeField (COMMA typeField)* RPAREN
    | LIST LPAREN dataType nullability? RPAREN
    | ARRAY LPAREN dataType nullability? COMMA sourceUnsigned RPAREN
    | MAP LPAREN dataType nullability? COMMA dataType nullability? RPAREN
    | (RANGE | MULTIRANGE) LT dataType GT
    | VECTOR LPAREN sourceUnsigned COMMA (scalarTypeName | typeHole) RPAREN;
scalarTypeName: IDENTIFIER | BIGINT | TEXT | BOOLEAN | INT64 | UINT64 | FLOAT64 | BOOL | UTF8 | BINARY | BYTEA
    | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | DOUBLE PRECISION? | CHARACTER VARYING?;
literal: valueHole | plainLiteral;
plainLiteral
    : signedInteger | signedNumber | TRUE | FALSE | NULL_ | MISSING
    | STRING (TYPECAST (BYTEA | UINT64 | FLOAT64))?
    | (X | DATE | TIME | TIMESTAMP | UUID | JSON) sourceString
    | (STRUCT | ROW | LIST | ARRAY | MAP | INTERVAL) LPAREN (literal (COMMA literal)*)? RPAREN
    | UNION LPAREN identifier COMMA literal RPAREN;
identifierHole: DOLLAR sourceName;
typeHole: DOLLAR sourceName;
valueHole: DOLLAR sourceName;
checkHole: DOLLAR sourceName;

// Source identifiers are contextual words, unlike reserved SQL identifiers.
sourceName: IDENTIFIER | AT | DECIMAL_ADD | DECIMAL_SUBTRACT | DECIMAL_MULTIPLY | DECIMAL_DIVIDE | DECIMAL_RESCALE | RANGE_OVERLAPS | RANGE_CONTAINS | RANGE_ADJACENT | RANGE_COMPARE | VECTOR_DISTANCE | TIME_BUCKET | LOCAL_TO_UTC | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | BEGIN | CONSTRAINT | CHECK | FOREIGN | REFERENCES | ENFORCED | VALID | VALIDATE | NO | ACTION | STREAM | STREAM_SLICE | QUEUE | STREAMS | QUEUES | PARTITION | PARTITIONS | HASH | PRODUCE | ENQUEUE | CONSUME | CLAIM | ACK | NACK | EXTEND | RECEIPT | LEASE | WAIT | PRODUCER | ID | EPOCH | SEQUENCE | VISIBLE_AT | RETURNING | START | TRANSACTION | WORK | ISOLATION | LEVEL | SERIALIZABLE | READ | ONLY | WRITE | COMMIT | OFFSET | ROLLBACK | SAVEPOINT | RELEASE | TRANSIT_RELOAD_CONF | TRANSIT_SETTINGS | TRANSIT_CONFIG_RELOADS | DATABASES | SCHEMAS | ASC | DESC | NULLS | FIRST | LAST | ROLE | LOGIN | NOLOGIN | CREATEROLE | NOCREATEROLE | SCHEMA | DATABASE | AUTHORIZATION | OWNER | CURRENT_ROLE | CURRENT_USER | SESSION_USER | PUBLIC | ALL | PRIVILEGES | OPTION | ADMIN | INHERIT | CASCADE | NONE | RESET | CONNECT | USAGE | IN | JOIN | INNER | LEFT | OUTER | RIGHT | FULL | CROSS | NATURAL | GROUP | BY | HAVING | ORDER | SELECT | WHERE | LIMIT | COUNT | SUM | IS | AND | OR | TRUE | FALSE | BYTEA | MISSING | TYPE_ERROR | VALUE | CONFLICT | UINT64 | FLOAT64 | EXPLAIN | ALTER | DROP | ADD | COLUMN | RENAME | RESTRICT | DEFAULT | PRIMARY | COLLATE | RANGE | MULTIRANGE | VECTOR | ROUNDING | METRIC | TIMEZONE | TZDB | TZIF | UTF8_BINARY | ASCII_CI | EBCDIC_CP037 | EBCDIC_037_PAD | EBCDIC_1047_NOPAD | KEY | PUT | GET | KEYS | ABSENT | PRESENT | IF | EXISTS | DATA | TYPE | STRUCT | ROW | LIST | ARRAY | MAP | UNION | OPTIONAL | WITHOUT | ZONE | X | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | DOUBLE | PRECISION | CHARACTER | VARYING | INSERT | UPDATE | DELETE | SET | VALUES | CREATE | CONNECTION | CONNECTIONS | SOURCE | SOURCES | SINK | SINKS | TABLE | TABLES | DOCUMENT | KV | TO | FROM | INTO | WITH | GRANT | REVOKE | ON | SHOW | STORAGE | DESCRIBE | NOT | NULL_ | SECRET | AS | OF | FOR | SNAPSHOT | PROJECTING | CURRENT | INT64 | BOOL | UTF8 | BINARY | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE | MODULE | INTERFACE | TARGET | TEST | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | USING;
referenceHead: IDENTIFIER | AT | DECIMAL_ADD | DECIMAL_SUBTRACT | DECIMAL_MULTIPLY | DECIMAL_DIVIDE | DECIMAL_RESCALE | RANGE_OVERLAPS | RANGE_CONTAINS | RANGE_ADJACENT | RANGE_COMPARE | VECTOR_DISTANCE | TIME_BUCKET | LOCAL_TO_UTC | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | BEGIN | CONSTRAINT | CHECK | FOREIGN | REFERENCES | ENFORCED | VALID | VALIDATE | NO | ACTION | STREAM | STREAM_SLICE | QUEUE | STREAMS | QUEUES | PARTITION | PARTITIONS | HASH | PRODUCE | ENQUEUE | CONSUME | CLAIM | ACK | NACK | EXTEND | RECEIPT | LEASE | WAIT | PRODUCER | ID | EPOCH | SEQUENCE | VISIBLE_AT | RETURNING | START | TRANSACTION | WORK | ISOLATION | LEVEL | SERIALIZABLE | READ | ONLY | WRITE | COMMIT | OFFSET | ROLLBACK | SAVEPOINT | RELEASE | TRANSIT_RELOAD_CONF | TRANSIT_SETTINGS | TRANSIT_CONFIG_RELOADS | DATABASES | SCHEMAS | ASC | DESC | NULLS | FIRST | LAST | ROLE | LOGIN | NOLOGIN | CREATEROLE | NOCREATEROLE | SCHEMA | DATABASE | AUTHORIZATION | OWNER | CURRENT_ROLE | CURRENT_USER | SESSION_USER | PUBLIC | ALL | PRIVILEGES | OPTION | ADMIN | INHERIT | CASCADE | NONE | RESET | CONNECT | USAGE | IN | JOIN | INNER | LEFT | OUTER | RIGHT | FULL | CROSS | NATURAL | GROUP | BY | HAVING | ORDER | SELECT | WHERE | LIMIT | COUNT | SUM | IS | AND | OR | BYTEA | MISSING | TYPE_ERROR | VALUE | CONFLICT | UINT64 | FLOAT64 | EXPLAIN | ALTER | DROP | ADD | COLUMN | RENAME | RESTRICT | DEFAULT | PRIMARY | COLLATE | RANGE | MULTIRANGE | VECTOR | ROUNDING | METRIC | TIMEZONE | TZDB | TZIF | UTF8_BINARY | ASCII_CI | EBCDIC_CP037 | EBCDIC_037_PAD | EBCDIC_1047_NOPAD | KEY | PUT | GET | KEYS | ABSENT | PRESENT | IF | EXISTS | DATA | STRUCT | ROW | LIST | ARRAY | MAP | UNION | OPTIONAL | WITHOUT | ZONE | X | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | DOUBLE | PRECISION | CHARACTER | VARYING | INSERT | UPDATE | DELETE | SET | VALUES | CREATE | CONNECTION | CONNECTIONS | SOURCE | SOURCES | SINK | SINKS | TABLE | TABLES | DOCUMENT | KV | TO | FROM | INTO | WITH | GRANT | REVOKE | ON | SHOW | STORAGE | DESCRIBE | NULL_ | SECRET | AS | OF | FOR | SNAPSHOT | PROJECTING | CURRENT | INT64 | BOOL | UTF8 | BINARY | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE | MODULE | INTERFACE | TARGET | TEST | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | USING;

IMPORT: 'IMPORT';
DEPENDENCY: 'DEPENDENCY';
SUBDIRECTORY: 'SUBDIRECTORY';
PACKAGE: 'PACKAGE';
FILE: 'FILE';
MODULE: 'MODULE';
INTERFACE: 'INTERFACE';
TARGET: 'TARGET';
TEST: 'TEST';
USE: 'USE';
MODULES: 'MODULES';
ASSERT: 'ASSERT';
ROWS: 'ROWS';
COMMAND: 'COMMAND';
STATEMENT: 'STATEMENT';
EQUAL: 'EQUAL';
MATCHED: 'MATCHED';
CHANGED: 'CHANGED';
FAILS: 'FAILS';
END: 'END';
THEN: 'THEN';
ELSE: 'ELSE';
NAME: 'NAME';
BIGINT: 'BIGINT';
TEXT: 'TEXT';
BOOLEAN: 'BOOLEAN';
IDENTIFIER_KIND: 'IDENTIFIER';
USING: 'USING';
DOLLAR: '$';
BANG_NE: '!=';
NE: '<>';


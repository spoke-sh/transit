// Independent application source reference. Runtime SQL keeps its own root.
grammar TransitSource;
options { caseInsensitive = true; }
import TransitExtensions;

sourceFile: (SEMI | sourceImport | dependency | definition)* EOF;
sourceImport: IMPORT sourceName FROM (PACKAGE sourceName FILE)? STRING SEMI;
dependency: DEPENDENCY sourceName FROM STRING REVISION STRING (SUBDIRECTORY STRING)? SEMI;
definition: CREATE PUBLIC? (MODULE sourceName parameters AS BEGIN body END
    | DOMAIN sourceName AS sourceBaseType IDENTITY STRING
    | VARIANT sourceName AS LPAREN variantConstructor (COMMA variantConstructor)* RPAREN
    | INTERFACE sourceName parameters
    | TEST? TARGET sourceName AS BEGIN body END) SEMI;
parameters: LPAREN (parameter (COMMA parameter)*)? RPAREN;
parameter: sourceName parameterKind;
parameterKind: BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | TYPE | MODULE sourceQualifiedName
    | (TABLE | STREAM | QUEUE) LPAREN signatureColumn (COMMA signatureColumn)* RPAREN | sourceParameterName;
sourceBaseType: BIGINT | TEXT | BOOLEAN;
sourceParameterName: parameterHead (DOT sourceName (DOT sourceName)?)?;
parameterHead: referenceTypeHead | TRUE | FALSE | NOT;
sourceTypeName: typeHead (DOT sourceName (DOT sourceName)?)?;
typeHead: referenceTypeHead | MODULE | TABLE | IDENTIFIER_KIND | TYPE | TRUE | FALSE | NOT;
sourceType: sourceBaseType | sourceTypeName;
signatureColumn: sourceName sourceType nullability? (PRIMARY KEY)? (COLLATE sourceName)?;
variantConstructor: sourceName parameters;
sourceQualifiedName: sourceName (DOT sourceName (DOT sourceName)?)?;
body: sourceStatement*;
sourceStatement
    : USE sourceCall (AS sourceName)? SEMI
    | EXPORT (TABLE | STREAM | QUEUE) DOLLAR? sourceQualifiedName AS sourceName SEMI
    | MATCH expression matchArm+ END MATCH SEMI
    | IF expression THEN body (ELSE body)? END IF SEMI
    | TEST STRING USING MODULES LPAREN (sourceCall (COMMA sourceCall)*)? RPAREN AS BEGIN body END SEMI
    | ASSERT assertion SEMI
    | ASSERT WORKFLOW expression COMPLETED INTEGER REFUSED INTEGER WITHIN INTEGER OBSERVATIONS SEMI
    | tableTemplate SEMI
    ;
matchArm: WHEN sourceQualifiedName LPAREN (sourceName (COMMA sourceName)*)? RPAREN THEN body;
sourceCall: sourceQualifiedName LPAREN (expression (COMMA expression)*)? RPAREN;
assertion
    : ROWS LPAREN simpleTemplate RPAREN EQUAL LPAREN expectedRows? RPAREN
    | COMMAND LPAREN simpleTemplate RPAREN MATCHED INTEGER CHANGED INTEGER
    | STATEMENT LPAREN simpleTemplate RPAREN FAILS WITH STRING
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
    | TYPE sourceType | LPAREN expression RPAREN
    | referenceHead (DOT sourceName (DOT sourceName)?)? (LPAREN (expression (COMMA expression)*)? RPAREN)?;

// Delivered public resource profile, with syntax before schema binding.
tableTemplate: simpleTemplate | sourceProgram;
simpleTemplate: CREATE PUBLIC (TABLE | STREAM | QUEUE) identifier LPAREN tableElement (COMMA tableElement)* RPAREN
    | PRODUCE INTO streamOperand (LPAREN identifier (COMMA identifier)* RPAREN)? VALUES mutationRow (COMMA mutationRow)*
    | ENQUEUE INTO queueOperand (LPAREN identifier (COMMA identifier)* RPAREN)? VALUES mutationRow (COMMA mutationRow)*
    | sourceProgramControl
    | CONSUME (STAR | columnReference outputAlias? (COMMA columnReference outputAlias?)*) FROM streamOperand (AS identifier)? whereClause? limitClause?
    | mutationStatement | sourceSelect;
streamOperand: streamHole | plainIdentifier;
queueOperand: queueHole | plainIdentifier;
streamHole: DOLLAR sourceName;
queueHole: DOLLAR sourceName;
tableOperand: tableHole | programName;
tableHole: DOLLAR sourceName;
programResourceName: identifierHole | programName;
programQueue: queueHole | programName;
programStream: streamHole | programName;
sourceProgram: CREATE PUBLIC DATAFLOW programResourceName FROM QUEUE programQueue AS programName
    (WHERE programExpression)? AS BEGIN programBlock (ON FAILURE programName programBlock)? END;
sourceProgramControl: AUTHORIZE DATAFLOW programResourceName AS ROLE CURRENT_ROLE
    | (ACTIVATE | SUSPEND | RESUME | RETIRE) DATAFLOW programResourceName;
programBlock: programInstruction*;
programInstruction
    : LET programName EQ (programSelect | programExpression) SEMI
    | REQUIRE programExpression ELSE sourceString SEMI
    | BEGIN ATOMIC programBlock END SEMI
    | IF programExpression THEN programBlock (ELSE programBlock)? END IF SEMI
    | INSERT INTO tableOperand VALUES programArguments ON CONFLICT LPAREN programName (COMMA programName)* RPAREN DO ASSERT SAME ROW SEMI
    | PRODUCE INTO programStream VALUES programArguments SEMI
    | ENQUEUE INTO programQueue VALUES programArguments SEMI;
programSelect: SELECT (STAR | programName (COMMA programName)*) FROM tableOperand (WHERE programExpression)?;
programArguments: LPAREN (programExpression (COMMA programExpression)*)? RPAREN;
programExpression: programOr;
programOr: programAnd (OR programAnd)*;
programAnd: programComparison (AND programComparison)*;
programComparison: programConcat ((EQ | LT | GT | LE | GE | NE) programConcat | IS NOT? NULL_)*;
programConcat: programAdd (CONCAT programAdd)*;
programAdd: programUnary ((PLUS | MINUS) programUnary)*;
// Recognize expression token structure without the ambiguous NOT/comparison
// recursion. Ordered-expression precedence is checked by the ordinary binder.
programUnary: NOT programUnary | MINUS programUnary | programPrimary;
programPrimary: (LPAREN programExpression RPAREN | valueHole | NULL_ | TRUE | FALSE | INTEGER | STRING
    | CASE WHEN programExpression THEN programExpression ELSE programExpression END
    | CAST LPAREN programExpression AS TEXT RPAREN
    | ROW programArguments | programAtomName programArguments?) (DOT programName)*;
programName: sourceName | QUOTED_IDENTIFIER;
programAtomName: typeWordOrdinary | STREAM | QUEUE | STRUCT | UNION | LIST | ARRAY | MAP | RANGE | MULTIRANGE | VECTOR
    | DOUBLE | CHARACTER | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | MODULE | TABLE | QUOTED_IDENTIFIER;
sourceSelect: SELECT selection FROM identifier sourceTableAlias? whereClause? limitClause?
    | SELECT aggregateSelection FROM LPAREN SELECT projection FROM identifier sourceTableAlias?
      whereClause? limitClause? RPAREN AS identifier;
sourceTableAlias: AS identifier | sourceImplicitAlias;
sourceImplicitAlias: identifierHole | legacyIdentifier | STREAMS | QUEUES | SNAPSHOT | CURRENT | PROJECTING
    | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | sourceKeyword;
sourceUnsigned: INTEGER | valueHole;
sourceString: STRING | valueHole;
limitClause: LIMIT sourceUnsigned;
comparison: EQ | NE | BANG_NE | LT | LE | GT | GE;
predicateAtom: columnReference (IS NOT? cellState | comparison literal);
// A bare CHECK hole may become a value or a column; its binding decides later.
checkPredicate: columnReference (IS NOT? NULL_ | comparison checkOperand);
checkOperand: checkHole | identifierHole DOT identifier | checkLiteral | plainColumnReference;
checkLiteral: signedInteger | signedNumber | TRUE | FALSE | NULL_
    | STRING (TYPECAST (BYTEA | UINT64 | FLOAT64))?
    | (X | DATE | TIME | TIMESTAMP | UUID | JSON) sourceString
    | (STRUCT | ROW | LIST | ARRAY | MAP | INTERVAL) LPAREN (literal (COMMA literal)*)? RPAREN
    | UNION LPAREN identifier COMMA literal RPAREN;
plainColumnReference: plainIdentifier (DOT identifier)?;
// A bare scalar hole can bind a column or value; qualification fixes its role.
scalarArgument: scalarHole (AT TIME ZONE sourceString)?
    | (plainColumnReference | identifierHole DOT identifier | scalarCall) (AT TIME ZONE sourceString)?
    | signedInteger | STRING;
scalarHole: DOLLAR sourceName;
sourceScalar: (columnReference | scalarCall) (AT TIME ZONE sourceString)?;
projectionItem: sourceScalar outputAlias?;
aggregateSelection: (COUNT LPAREN (STAR | sourceScalar) RPAREN | SUM LPAREN sourceScalar RPAREN) outputAlias?;
columnConstraint
    : nullability | DEFAULT literal | PRIMARY KEY | COLLATE collation
    | ROUNDING identifier | METRIC identifier
    | TIMEZONE sourceString TZDB sourceString TZIF X sourceString;
// Foreign keys require catalog resolution outside this source profile.
tableConstraint: (CONSTRAINT identifier)? checkConstraint;

identifier: identifierHole | plainIdentifier;
plainIdentifier: settingIdentifier | STREAMS | QUEUES | SNAPSHOT | CURRENT | PROJECTING
    | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | sourceKeyword;
sourceKeyword: DOMAIN | VARIANT | IDENTITY | EXPORT | MATCH | WHEN | USING | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE | MODULE | INTERFACE | TARGET | TEST | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | LET | REQUIRE | ATOMIC | DO | SAME | FAILURE | CASE | CAST | WORKFLOW | COMPLETED | REFUSED | WITHIN | OBSERVATIONS;
// Keep the inherited logical type/literal productions; holes extend their sites.
dataType: typeHole | sourceDataType;
sourceDataType
    : scalarTypeName (LPAREN sourceUnsigned (COMMA sourceUnsigned)? RPAREN)? ((WITH | WITHOUT) TIME ZONE)?
    | (STRUCT | ROW | UNION) LPAREN typeField (COMMA typeField)* RPAREN
    | LIST LPAREN dataType nullability? RPAREN
    | ARRAY LPAREN dataType nullability? COMMA sourceUnsigned RPAREN
    | MAP LPAREN dataType nullability? COMMA dataType nullability? RPAREN
    | (RANGE | MULTIRANGE) LT dataType GT
    | VECTOR LPAREN sourceUnsigned COMMA (sourceName | typeHole) RPAREN;
scalarTypeName: scalarTypeWord | DOUBLE PRECISION? | CHARACTER VARYING?;
// Unknown scalar names remain a later type-binding refusal, including contextual words.
scalarTypeWord: sourceWord | TYPE | TRUE | FALSE | NOT;
literal: (PLUS | MINUS)? valueHole (TYPECAST (BYTEA | UINT64 | FLOAT64))? | plainLiteral;
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
sourceName: referenceHead | TYPE | TRUE | FALSE | NOT;
referenceHead: referenceTypeHead | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | MODULE | TABLE;
referenceTypeHead: typeWord | STRUCT | ROW | UNION | LIST | ARRAY | MAP | RANGE | MULTIRANGE | VECTOR
    | DOUBLE | CHARACTER;
sourceWord: typeWord | BIGINT | TEXT | BOOLEAN | IDENTIFIER_KIND | MODULE | TABLE;
typeWord: typeWordWithoutLogs | STREAM | QUEUE;
typeWordWithoutLogs: typeWordOrdinary | NULL_ | CASE | CAST;
typeWordOrdinary: IDENTIFIER | AT | DECIMAL_ADD | DECIMAL_SUBTRACT | DECIMAL_MULTIPLY | DECIMAL_DIVIDE
    | DECIMAL_RESCALE | RANGE_OVERLAPS | RANGE_CONTAINS | RANGE_ADJACENT | RANGE_COMPARE
    | VECTOR_DISTANCE | TIME_BUCKET | LOCAL_TO_UTC | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE
    | SUSPEND | RESUME | REFRESH | RETIRE | BEGIN | CONSTRAINT | CHECK | FOREIGN | REFERENCES
    | ENFORCED | VALID | VALIDATE | NO | ACTION | STREAM_SLICE | STREAMS | QUEUES
    | PARTITION | PARTITIONS | HASH | PRODUCE | ENQUEUE | CONSUME | CLAIM | ACK | NACK | EXTEND
    | RECEIPT | LEASE | WAIT | PRODUCER | ID | EPOCH | SEQUENCE | VISIBLE_AT | RETURNING | START
    | TRANSACTION | WORK | ISOLATION | LEVEL | SERIALIZABLE | READ | ONLY | WRITE | COMMIT | OFFSET
    | ROLLBACK | SAVEPOINT | RELEASE | TRANSIT_RELOAD_CONF | TRANSIT_SETTINGS
    | TRANSIT_CONFIG_RELOADS | DATABASES | SCHEMAS | ASC | DESC | NULLS | FIRST | LAST | ROLE
    | LOGIN | NOLOGIN | CREATEROLE | NOCREATEROLE | SCHEMA | DATABASE | AUTHORIZATION | OWNER
    | CURRENT_ROLE | CURRENT_USER | SESSION_USER | PUBLIC | ALL | PRIVILEGES | OPTION | ADMIN
    | INHERIT | CASCADE | NONE | RESET | CONNECT | USAGE | IN | JOIN | INNER | LEFT | OUTER | RIGHT
    | FULL | CROSS | NATURAL | GROUP | BY | HAVING | ORDER | SELECT | WHERE | LIMIT | COUNT | SUM
    | IS | AND | OR | BYTEA | MISSING | TYPE_ERROR | VALUE | CONFLICT | UINT64 | FLOAT64 | EXPLAIN
    | ALTER | DROP | ADD | COLUMN | RENAME | RESTRICT | DEFAULT | PRIMARY | COLLATE | ROUNDING
    | METRIC | TIMEZONE | TZDB | TZIF | UTF8_BINARY | ASCII_CI | EBCDIC_CP037 | EBCDIC_037_PAD
    | EBCDIC_1047_NOPAD | KEY | PUT | GET | KEYS | ABSENT | PRESENT | IF | EXISTS | DATA | OPTIONAL
    | WITHOUT | ZONE | X | DATE | TIME | TIMESTAMP | UUID | JSON | INTERVAL | PRECISION | VARYING
    | INSERT | UPDATE | DELETE | SET | VALUES | CREATE | CONNECTION | CONNECTIONS | SOURCE | SOURCES
    | SINK | SINKS | TABLES | DOCUMENT | KV | TO | FROM | INTO | WITH | GRANT | REVOKE | ON
    | SHOW | STORAGE | DESCRIBE | SECRET | AS | OF | FOR | SNAPSHOT | PROJECTING | CURRENT
    | INT64 | BOOL | UTF8 | BINARY | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE
    | INTERFACE | TARGET | TEST | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL
    | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME
    | USING | DOMAIN | VARIANT | IDENTITY | EXPORT | MATCH | WHEN | LET | REQUIRE | ATOMIC | DO | SAME | FAILURE | WORKFLOW | COMPLETED | REFUSED | WITHIN | OBSERVATIONS;

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


DOMAIN: 'DOMAIN';
VARIANT: 'VARIANT';
IDENTITY: 'IDENTITY';
EXPORT: 'EXPORT';
MATCH: 'MATCH';
WHEN: 'WHEN';
LET: 'LET';
REQUIRE: 'REQUIRE';
ATOMIC: 'ATOMIC';
DO: 'DO';
SAME: 'SAME';
FAILURE: 'FAILURE';
CASE: 'CASE';
CAST: 'CAST';
CONCAT: '||';
WORKFLOW: 'WORKFLOW';
COMPLETED: 'COMPLETED';
REFUSED: 'REFUSED';
WITHIN: 'WITHIN';
OBSERVATIONS: 'OBSERVATIONS';

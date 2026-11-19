// Independent application source reference. Runtime SQL keeps its own root.
grammar TransitSource;
options { caseInsensitive = true; }
import TransitExtensions;

sourceFile: (SEMI | sourceImport | dependency | defaultTarget | definition | sourceStatement)* EOF;
sourceImport: IMPORT (MODULE FROM | MODULE sourceName FROM | sourceNameWithoutModule FROM) (PACKAGE sourceName FILE)? STRING SEMI;
dependency: DEPENDENCY sourceName FROM STRING REVISION STRING (SUBDIRECTORY STRING)? SEMI;
defaultTarget: EXPORT DEFAULT TARGET sourceName SEMI;
migrationClause: FROM (EMPTY | STRING) FOR DATABASE STRING SCHEMA STRING VERSION STRING NAME STRING;
exportMigrationClause: FROM (EMPTY | STRING) (FOR DATABASE STRING (SCHEMA STRING)?)? VERSION STRING (NAME STRING)?;
definition
    : CREATE PUBLIC? (MODULE sourceName parameters AS BEGIN body END
        | DOMAIN sourceName AS sourceBaseType IDENTITY STRING
        | VARIANT sourceName AS LPAREN variantConstructor (COMMA variantConstructor)* RPAREN
        | INTERFACE sourceName parameters
        | FUNCTION helperName parameters RETURNS sourceType AS BEGIN ATOMIC? functionBody END
        | GUARD helperName parameters AS (BEGIN ATOMIC? programBlock END | guardRequires)
        | PROCEDURE helperName parameters (RETURNS sourceType)? AS BEGIN ATOMIC? procedureBody END
        | MIGRATION TARGET sourceName migrationClause AS BEGIN body END
        | TEST? TARGET sourceName AS BEGIN body END) SEMI
    | EXPORT (MODULE sourceName parameters AS BEGIN body END
        | TEST SUITE sourceName FROM STRING
        | TARGET sourceName exportTargetBody) SEMI
    ;
guardRequires: guardRequireItem (COMMA guardRequireItem)*;
guardRequireItem: REQUIRE programExpression ELSE STRING;
exportTargetBody
    : EQ sourceName DOT sourceName
    | AS SQL OF sourceName (INTO STRING)?
    | AS MIGRATIONS OF sourceName exportMigrationClause (INTO STRING)?
    | AS TESTS OF sourceName USING SUITES LPAREN suiteRef (COMMA suiteRef)* RPAREN
      (WITH LPAREN targetOption (COMMA targetOption)* RPAREN)?
    ;
suiteRef: STRING | helperName;
targetOption: sourceName EQ expression;
procedureBody: programBlock (RETURN programExpression SEMI)?;
functionBody: RETURN programExpression SEMI | programInstruction+;
parameters: LPAREN (parameter (COMMA parameter)*)? RPAREN;
rowParameters: LPAREN parameter (COMMA parameter)* RPAREN;
parameter: sourceName parameterKind;
parameterKind: BIGINT | TEXT | BOOLEAN | UUID | TIMESTAMPTZ | BINARY | IDENTIFIER_KIND | TYPE | SCHEMA_BINDING
    | MODULE OF? sourceQualifiedName
    | ROW rowParameters
    | (TABLE | STREAM | QUEUE) LPAREN signatureColumn (COMMA signatureColumn)* RPAREN | sourceParameterName;
sourceBaseType: BIGINT | TEXT | BOOLEAN | UUID | TIMESTAMPTZ | BINARY;
sourceParameterName: parameterHead (DOT sourceName (DOT sourceName)?)?
    | sourceBaseType DOT sourceName (DOT sourceName)?;
parameterHead: referenceTypeHead | TRUE | FALSE | NOT;
sourceTypeName: typeHead (DOT sourceName (DOT sourceName)?)?
    | sourceBaseType DOT sourceName (DOT sourceName)?;
typeHead: referenceTypeHead | MODULE | TABLE | IDENTIFIER_KIND | SCHEMA_BINDING | TYPE | TRUE | FALSE | NOT;
sourceType: sourceBaseType | sourceTypeName;
signatureColumn: sourceName sourceType nullability? (PRIMARY KEY)? (COLLATE sourceName)?;
variantConstructor: sourceName parameters;
sourceQualifiedName: sourceName (DOT sourceName (DOT sourceName)?)?;
body: sourceStatement*;
sourceStatement
    : LET sourceName EQ USE MODULE? sourceCall SEMI
    | USE (MODULE sourceQualifiedName (LPAREN callArguments? RPAREN (AS sourceName)?)? | sourceCall (AS sourceName)?) SEMI
    | DECLARE FROM STRING SEMI
    | BIND SCHEMA sourceName TO expression SEMI
    | EXPORT REFERENCE TABLE helperName LPAREN sourceName (COMMA sourceName)* RPAREN (AS sourceName)? SEMI
    | EXPORT (TABLE | STREAM | QUEUE) (DOLLAR helperName AS sourceName | helperName (AS sourceName)?) SEMI
    | EXPORT (FUNCTION | GUARD | PROCEDURE | VIEW | DATAFLOW | PROFILE) helperName (AS sourceName)? SEMI
    | MATCH expression matchArm+ END MATCH SEMI
    | IF expression THEN body (ELSE body)? END IF SEMI
    | TEST STRING USING MODULES LPAREN (caseModule (COMMA caseModule)*)? RPAREN AS BEGIN body END SEMI
    | ASSERT assertion SEMI
    | ASSERT WORKFLOW expression COMPLETED INTEGER REFUSED INTEGER WITHIN INTEGER OBSERVATIONS SEMI
    | tableTemplate SEMI
    ;
matchArm: WHEN sourceQualifiedName LPAREN (sourceName (COMMA sourceName)*)? RPAREN THEN body;
caseModule: sourceQualifiedName (LPAREN callArguments? RPAREN)?;
sourceCall: sourceQualifiedName LPAREN callArguments? RPAREN;
callArguments: namedArgument (COMMA namedArgument)* | expression (COMMA expression)*;
namedArgument: sourceName FAT_ARROW expression;
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
    | UUID STRING
    | (TIMESTAMPTZ | TIMESTAMP) STRING
    | X STRING
    | SCHEMA_BINDING LPAREN STRING RPAREN
    | SCHEMA_BINDING (DOT sourceName (DOT sourceName)? (LPAREN callArguments? RPAREN)?)?
    | ROW LPAREN namedArgument (COMMA namedArgument)* RPAREN
    | ROW (DOT sourceName (DOT sourceName)? (LPAREN callArguments? RPAREN)?)?
    | TYPE sourceType | LPAREN expression RPAREN
    | plainReferenceHead (DOT sourceName (DOT sourceName)?)? (LPAREN callArguments? RPAREN)?;

// Delivered public resource profile, with syntax before schema binding.
tableTemplate: simpleTemplate | sourceProgram;
simpleTemplate: CREATE SCHEMA identifier
    | CREATE PUBLIC (TABLE | STREAM | QUEUE) qualifiedName LPAREN tableElement (COMMA tableElement)* RPAREN
    | PRODUCE INTO streamOperand (LPAREN identifier (COMMA identifier)* RPAREN)? VALUES mutationRow (COMMA mutationRow)*
    | ENQUEUE INTO queueOperand (LPAREN identifier (COMMA identifier)* RPAREN)? VALUES mutationRow (COMMA mutationRow)*
    | sourceProgramControl
    | CONSUME (STAR | columnReference outputAlias? (COMMA columnReference outputAlias?)*) FROM streamOperand (AS identifier)? whereClause? limitClause?
    | mutationStatement | sourceSelect;
streamOperand: streamHole | plainIdentifier (DOT identifier)?;
queueOperand: queueHole | plainIdentifier (DOT identifier)?;
streamHole: DOLLAR sourceName;
queueHole: DOLLAR sourceName;
tableOperand: tableHole | programQualifiedName;
tableHole: DOLLAR sourceName;
programResourceName: identifierHole | programQualifiedName;
programQueue: queueHole | programQualifiedName;
programStream: streamHole | programQualifiedName;
programQualifiedName: programName (DOT programName)?;
sourceProgram: CREATE PUBLIC DATAFLOW programResourceName FROM QUEUE programQueue AS programName
    (WHERE programExpression)? AS BEGIN programBlock (ON FAILURE programName programBlock)? END;
sourceProgramControl: AUTHORIZE DATAFLOW programResourceName AS ROLE CURRENT_ROLE
    | (ACTIVATE | SUSPEND | RESUME | RETIRE) DATAFLOW programResourceName;
programBlock: programInstruction*;
programInstruction
    : LET programName EQ (CALL helperName programArguments | programSelect | programExpression) SEMI
    | REQUIRE programExpression ELSE sourceString SEMI
    | CHECK GUARD helperName programArguments SEMI
    | CALL helperName programArguments SEMI
    | BEGIN ATOMIC programBlock END SEMI
    | IF programExpression THEN programBlock (ELSE programBlock)? END IF SEMI
    | INSERT INTO tableOperand VALUES programArguments ON CONFLICT LPAREN programName (COMMA programName)* RPAREN DO ASSERT SAME ROW SEMI
    | PRODUCE INTO programStream VALUES programArguments SEMI
    | ENQUEUE INTO programQueue VALUES programArguments SEMI;
helperName: sourceName (DOT sourceName)?;
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
    | (UUID | TIMESTAMP | TIMESTAMPTZ | X) STRING
    | CASE WHEN programExpression THEN programExpression ELSE programExpression END
    | CAST LPAREN programExpression AS TEXT RPAREN
    | ROW programArguments | programAtomName (DOT programName programArguments | programArguments)?) (DOT programName)*;
programName: sourceName | QUOTED_IDENTIFIER;
programAtomName: typeWordOrdinary | STREAM | QUEUE | STRUCT | UNION | LIST | ARRAY | MAP | RANGE | MULTIRANGE | VECTOR
    | DOUBLE | CHARACTER | BIGINT | TEXT | BOOLEAN | UUID | TIMESTAMPTZ | BINARY | IDENTIFIER_KIND | SCHEMA_BINDING | MODULE | TABLE | QUOTED_IDENTIFIER;
sourceSelect: SELECT selection FROM qualifiedName sourceTableAlias? whereClause? limitClause?
    | SELECT aggregateSelection FROM LPAREN SELECT projection FROM qualifiedName sourceTableAlias?
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
    | TIMEZONE sourceString TZDB sourceString TZIF X sourceString
    | (CONSTRAINT identifier)? (checkConstraint | columnReferencesConstraint)
    ;
tableConstraint: (CONSTRAINT identifier)? (checkConstraint | foreignKeyConstraint);

columnIdentifier: identifierHole | plainColumnIdentifier;
plainColumnIdentifier: settingIdentifier | STREAMS | QUEUES | SNAPSHOT | CURRENT | PROJECTING
    | DATAFLOW | REVISION | AUTHORIZE | ACTIVATE | SUSPEND | RESUME | REFRESH | RETIRE | sourceKeyword;
plainIdentifier: plainColumnIdentifier | CONSTRAINT | CHECK | FOREIGN | REFERENCES;
identifier: identifierHole | plainIdentifier;
sourceKeyword: MIGRATION | MIGRATIONS | EMPTY | VERSION | DOMAIN | VARIANT | IDENTITY | EXPORT | MATCH | WHEN | USING | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE | MODULE | INTERFACE | FUNCTION | GUARD | PROCEDURE | RETURNS | RETURN | CALL | TARGET | TEST | TESTS | SUITE | SUITES | SQL | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME | BIGINT | TEXT | BOOLEAN | TIMESTAMPTZ | IDENTIFIER_KIND | SCHEMA_BINDING | DECLARE | BIND | VIEW | PROFILE | REFERENCE | LET | REQUIRE | ATOMIC | DO | SAME | FAILURE | CASE | CAST | WORKFLOW | COMPLETED | REFUSED | WITHIN | OBSERVATIONS;
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
sourceNameWithoutModule: referenceHeadWithoutModule | TYPE | TRUE | FALSE | NOT;
referenceHead: referenceHeadWithoutModule | MODULE;
referenceHeadWithoutModule: plainReferenceHeadWithoutModule | ROW | SCHEMA_BINDING;
plainReferenceHead: plainReferenceHeadWithoutModule | MODULE;
plainReferenceHeadWithoutModule: plainReferenceTypeHead | BIGINT | TEXT | BOOLEAN | UUID | TIMESTAMPTZ | BINARY | IDENTIFIER_KIND | TABLE;
referenceTypeHead: plainReferenceTypeHead | ROW;
plainReferenceTypeHead: typeWord | STRUCT | UNION | LIST | ARRAY | MAP | RANGE | MULTIRANGE | VECTOR
    | DOUBLE | CHARACTER;
sourceWord: typeWord | BIGINT | TEXT | BOOLEAN | UUID | TIMESTAMPTZ | BINARY | IDENTIFIER_KIND | SCHEMA_BINDING | MODULE | TABLE;
typeWord: typeWordWithoutLogs | STREAM | QUEUE;
typeWordWithoutLogs: typeWordOrdinary | NULL_ | CASE | CAST;
typeWordOrdinary: IDENTIFIER | MIGRATION | MIGRATIONS | EMPTY | VERSION | FOR | AT | DECIMAL_ADD | DECIMAL_SUBTRACT | DECIMAL_MULTIPLY | DECIMAL_DIVIDE
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
    | WITHOUT | ZONE | X | DATE | TIME | TIMESTAMP | JSON | INTERVAL | PRECISION | VARYING
    | INSERT | UPDATE | DELETE | SET | VALUES | CREATE | CONNECTION | CONNECTIONS | SOURCE | SOURCES
    | SINK | SINKS | TABLES | DOCUMENT | KV | TO | FROM | INTO | WITH | GRANT | REVOKE | ON
    | SHOW | STORAGE | DESCRIBE | SECRET | AS | OF | FOR | SNAPSHOT | PROJECTING | CURRENT
    | INT64 | BOOL | UTF8 | IMPORT | DEPENDENCY | SUBDIRECTORY | PACKAGE | FILE
    | INTERFACE | TARGET | TEST | TESTS | SUITE | SUITES | SQL | USE | MODULES | ASSERT | ROWS | COMMAND | STATEMENT | EQUAL
    | MATCHED | CHANGED | FAILS | END | THEN | ELSE | NAME
    | DECLARE | BIND | VIEW | PROFILE | REFERENCE
    | USING | DOMAIN | VARIANT | IDENTITY | EXPORT | MATCH | WHEN | FUNCTION | GUARD | PROCEDURE | RETURNS | RETURN | CALL | LET | REQUIRE | ATOMIC | DO | SAME | FAILURE | WORKFLOW | COMPLETED | REFUSED | WITHIN | OBSERVATIONS;

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
TIMESTAMPTZ: 'TIMESTAMPTZ';
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
FUNCTION: 'FUNCTION';
GUARD: 'GUARD';
PROCEDURE: 'PROCEDURE';
RETURNS: 'RETURNS';
RETURN: 'RETURN';
CALL: 'CALL';
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

MIGRATION: 'MIGRATION';
MIGRATIONS: 'MIGRATIONS';
EMPTY: 'EMPTY';
VERSION: 'VERSION';
DECLARE: 'DECLARE';
BIND: 'BIND';
SCHEMA_BINDING: 'SCHEMA_BINDING';
SUITE: 'SUITE';
SUITES: 'SUITES';
SQL: 'SQL';
TESTS: 'TESTS';
VIEW: 'VIEW';
PROFILE: 'PROFILE';
REFERENCE: 'REFERENCE';
FAT_ARROW: '=>';

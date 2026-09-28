// Independent syntactic reference for APPLICATION_V1. Owning Zig validation
// checks option meanings, references, budgets and Fuze query compatibility.
grammar Application;
options { caseInsensitive = true; }
program: interfaceDeclaration memberDeclaration* EOF;
interfaceDeclaration: CREATE INTERFACE identifier WITH optionList SEMI;
memberDeclaration: CREATE kind identifier DOT identifier WITH optionList SEMI;
kind: THEME | SCREEN | BINDING | ACTION;
optionList: LPAREN option (COMMA option)* RPAREN;
option: identifier EQ (STRING | INTEGER);
identifier: NAME | QUOTED_NAME | CREATE | INTERFACE | WITH | THEME | SCREEN | BINDING | ACTION;
CREATE: 'CREATE';
INTERFACE: 'INTERFACE';
WITH: 'WITH';
THEME: 'THEME';
SCREEN: 'SCREEN';
BINDING: 'BINDING';
ACTION: 'ACTION';
DOT: '.';
SEMI: ';';
LPAREN: '(';
RPAREN: ')';
COMMA: ',';
EQ: '=';
STRING: '\'' ('\'\'' | ~'\'')* '\'';
QUOTED_NAME: '"' ('""' | ~'"')* '"';
INTEGER: '0' | [1-9] [0-9]*;
NAME: [a-z_] [a-z_0-9]*;
BLOCK_COMMENT: '/*' (BLOCK_COMMENT | .)*? '*/' -> skip;
LINE_COMMENT: '--' ~[\r\n]* -> skip;
WS: [ \t\r\n]+ -> skip;

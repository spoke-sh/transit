/* Actual pinned libpq: verified TLS, described prepared parameters, six types,
 * text/binary results, NULL and autocommit completion. No retry wrapper. */
#include <libpq-fe.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static PGresult *expect(PGconn *c, PGresult *r, ExecStatusType status) {
    if (!r || PQresultStatus(r) != status) {
        fprintf(stderr, "libpq: %s\n", r ? PQresultErrorMessage(r) : PQerrorMessage(c));
        exit(1);
    }
    return r;
}
static void command(PGconn *c, const char *sql) {
    PQclear(expect(c, PQexec(c, sql), PGRES_COMMAND_OK));
}
static void scalar_types(PGconn *c) {
    command(c, "CREATE TABLE c_pg_scalars (id INT NOT NULL, f REAL, salary DECIMAL(10,2))");
    PQclear(expect(c, PQprepare(c, "scalar_insert", "INSERT INTO c_pg_scalars VALUES ($1,$2,$3)", 0, NULL), PGRES_COMMAND_OK));
    PGresult *r = expect(c, PQdescribePrepared(c, "scalar_insert"), PGRES_COMMAND_OK);
    const Oid types[] = {23,700,1700};
    assert(PQnparams(r) == 3);
    for (int i=0; i<3; i++) assert(PQparamtype(r,i) == types[i]);
    PQclear(r);
    r = expect(c, PQexec(c, "SELECT * FROM c_pg_scalars"), PGRES_TUPLES_OK);
    assert(PQntuples(r) == 0 && PQnfields(r) == 3);
    assert(PQfmod(r,2) == (10<<16)+2+4);
    PQclear(r);
    const char *values[] = {"-2147483648","-1.25","-123.45"};
    PQclear(expect(c,PQexecPrepared(c,"scalar_insert",3,values,NULL,NULL,0),PGRES_COMMAND_OK));
    const unsigned char id[] = {128,0,0,0}, f[] = {191,160,0,0};
    const unsigned char numeric[] = {0,2,0,0,64,0,0,2,0,123,17,148};
    const char *binary[] = {(const char *)id,(const char *)f,(const char *)numeric};
    const int lengths[] = {4,4,12}, formats[] = {1,1,1};
    PQclear(expect(c,PQexecPrepared(c,"scalar_insert",3,binary,lengths,formats,0),PGRES_COMMAND_OK));
    for (int mode=0; mode<2; mode++) {
        r = expect(c,PQexecParams(c,"SELECT * FROM c_pg_scalars",0,NULL,NULL,NULL,NULL,mode),PGRES_TUPLES_OK);
        assert(PQntuples(r) == 2);
        for (int row=0; row<2; row++) for (int col=0; col<3; col++) {
            assert(PQftype(r,col) == types[col] && PQfformat(r,col) == mode);
            if (mode) assert(PQgetlength(r,row,col) == lengths[col] && !memcmp(PQgetvalue(r,row,col),binary[col],lengths[col]));
            else assert(!strcmp(PQgetvalue(r,row,col),values[col]));
        }
        PQclear(r);
    }
    puts("libpq: int32/float32/decimal inferred parameters, empty metadata and exact text/binary input/output passed");
}
int main(int argc, char **argv) {
    PGconn *c = PQconnectdb(""); /* Credentials/verified TLS via private environment. */
    assert(PQstatus(c) == CONNECTION_OK);
    assert(PQsslInUse(c));
    fprintf(stderr, "libpq phase: connected\n");
    assert(PQlibVersion() == 180006);
    scalar_types(c);
    if (argc == 2 && !strcmp(argv[1], "types")) { PQfinish(c); return 0; }
    command(c, "CREATE TABLE c_pg_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)");
    fprintf(stderr, "libpq phase: created\n");
    PGresult *r = expect(c, PQprepare(c, "insert", "INSERT INTO c_pg_rows (id,n,f,b,label,payload) VALUES ($1,$2,$3,$4,$5,$6)", 0, NULL), PGRES_COMMAND_OK);
    PQclear(r);
    r = expect(c, PQdescribePrepared(c, "insert"), PGRES_COMMAND_OK);
    const Oid oids[] = {20, 1700, 701, 16, 25, 17};
    assert(PQnparams(r) == 6);
    for (int i = 0; i < 6; i++) assert(PQparamtype(r, i) == oids[i]);
    PQclear(r);
    const char *values[] = {"-9223372036854775808", "18446744073709551615", "-1.25", "true", "snow \xe2\x98\x83", "\\x00ff"};
    r = expect(c, PQexecPrepared(c, "insert", 6, values, NULL, NULL, 0), PGRES_COMMAND_OK);
    assert(strcmp(PQcmdTuples(r), "1") == 0);
    PQclear(r);
    fprintf(stderr, "libpq phase: inserted\n");
    PQclear(expect(c, PQprepare(c, "read", "SELECT id,n,f,b,label,payload FROM c_pg_rows WHERE id=$1", 0, NULL), PGRES_COMMAND_OK));
    for (int binary = 0; binary < 2; binary++) {
        r = expect(c, PQexecPrepared(c, "read", 1, values, NULL, NULL, binary), PGRES_TUPLES_OK);
        assert(PQntuples(r) == 1 && PQnfields(r) == 6);
        for (int i = 0; i < 6; i++) {
            assert(PQftype(r, i) == oids[i] && PQfformat(r, i) == binary);
            assert(!PQgetisnull(r, 0, i));
        }
        assert(strcmp(PQgetvalue(r, 0, 4), values[4]) == 0);
        if (binary) {
            const unsigned char i64[] = {128,0,0,0,0,0,0,0};
            assert(PQgetlength(r,0,0) == 8 && memcmp(PQgetvalue(r,0,0), i64, 8) == 0);
            const unsigned char *n = (const unsigned char *)PQgetvalue(r,0,1);
            assert(PQgetlength(r,0,1) == 18 && n[1] == 5 && n[3] == 4 && n[5] == 0 && n[7] == 0);
            unsigned long long number = 0;
            for (int i=8; i<18; i+=2) number = number*10000 + n[i]*256u+n[i+1];
            assert(number == 18446744073709551615ULL);
            assert(PQgetlength(r,0,3) == 1 && PQgetvalue(r,0,3)[0] == 1);
            assert(PQgetlength(r,0,5) == 2 && memcmp(PQgetvalue(r,0,5), "\0\xff", 2) == 0);
        } else {
            assert(strcmp(PQgetvalue(r,0,0), values[0]) == 0);
            assert(strcmp(PQgetvalue(r,0,1), values[1]) == 0);
            assert(strcmp(PQgetvalue(r,0,3), "t") == 0);
        }
        PQclear(r);
    }
    fprintf(stderr, "libpq phase: text and binary read complete\n");
    r = PQexecPrepared(c, "insert", 6, values, NULL, NULL, 0);
    assert(PQresultStatus(r) == PGRES_FATAL_ERROR);
    assert(strcmp(PQresultErrorField(r, PG_DIAG_SQLSTATE), "23505") == 0);
    PQclear(r);
    fprintf(stderr, "libpq phase: duplicate rejected\n");
    values[0] = "2";
    for (int i=1; i<6; i++) values[i] = NULL;
    PQclear(expect(c, PQexecPrepared(c, "insert", 6, values, NULL, NULL, 0), PGRES_COMMAND_OK));
    fprintf(stderr, "libpq phase: null row inserted\n");
    r = expect(c, PQexecPrepared(c, "read", 1, values, NULL, NULL, 1), PGRES_TUPLES_OK);
    assert(PQntuples(r) == 1);
    for (int i=1; i<6; i++) assert(PQgetisnull(r,0,i));
    PQclear(r);
    fprintf(stderr, "libpq phase: null read complete\n");
    r = expect(c, PQexec(c, "DELETE FROM c_pg_rows"), PGRES_COMMAND_OK);
    assert(strcmp(PQcmdTuples(r), "2") == 0);
    PQclear(r);
    PQfinish(c);
    puts("libpq 18.6: prepared six types, both formats, NULL, duplicate and counts passed");
}

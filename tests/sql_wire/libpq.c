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
int main(void) {
    PGconn *c = PQconnectdb(""); /* Credentials/verified TLS via private environment. */
    assert(PQstatus(c) == CONNECTION_OK);
    assert(PQsslInUse(c));
    assert(PQlibVersion() == 180006);
    command(c, "CREATE TABLE c_pg_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)");
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
    r = PQexecPrepared(c, "insert", 6, values, NULL, NULL, 0);
    assert(PQresultStatus(r) == PGRES_FATAL_ERROR);
    assert(strcmp(PQresultErrorField(r, PG_DIAG_SQLSTATE), "23505") == 0);
    PQclear(r);
    values[0] = "2";
    for (int i=1; i<6; i++) values[i] = NULL;
    PQclear(expect(c, PQexecPrepared(c, "insert", 6, values, NULL, NULL, 0), PGRES_COMMAND_OK));
    r = expect(c, PQexecPrepared(c, "read", 1, values, NULL, NULL, 1), PGRES_TUPLES_OK);
    assert(PQntuples(r) == 1);
    for (int i=1; i<6; i++) assert(PQgetisnull(r,0,i));
    PQclear(r);
    r = expect(c, PQexec(c, "DELETE FROM c_pg_rows"), PGRES_COMMAND_OK);
    assert(strcmp(PQcmdTuples(r), "2") == 0);
    PQclear(r);
    PQfinish(c);
    puts("libpq 18.6: prepared six types, both formats, NULL, duplicate and counts passed");
}

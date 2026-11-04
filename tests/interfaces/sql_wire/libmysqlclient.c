/* Oracle libmysqlclient, not the MariaDB substitute. */
#include <mysql.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void query(MYSQL *c, const char *sql) {
    if (mysql_query(c, sql)) { fprintf(stderr,"mysql: %s\n",mysql_error(c)); exit(1); }
}
static MYSQL_STMT *prepare(MYSQL *c, const char *sql) {
    MYSQL_STMT *s = mysql_stmt_init(c);
    if (mysql_stmt_prepare(s,sql,strlen(sql))) { fprintf(stderr,"prepare: %s\n",mysql_stmt_error(s)); exit(1); }
    return s;
}
static void execute(MYSQL_STMT *s) {
    if (mysql_stmt_execute(s)) { fprintf(stderr,"execute: %s\n",mysql_stmt_error(s)); exit(1); }
}
static void scalar_types(MYSQL *c) {
    query(c,"CREATE TABLE c_mysql_scalars (id INT NOT NULL, f REAL, salary DECIMAL(10,2))");
    MYSQL_STMT *read = prepare(c,"SELECT * FROM c_mysql_scalars");
    MYSQL_RES *meta = mysql_stmt_result_metadata(read);
    assert(mysql_num_fields(meta) == 3);
    MYSQL_FIELD *fields = mysql_fetch_fields(meta);
    assert(fields[0].type == MYSQL_TYPE_LONG && (fields[0].flags & NOT_NULL_FLAG));
    assert(fields[1].type == MYSQL_TYPE_FLOAT && fields[2].type == MYSQL_TYPE_NEWDECIMAL);
    assert(fields[2].length == 12 && fields[2].decimals == 2 && fields[2].charsetnr == 63);
    mysql_free_result(meta);
    execute(read);
    assert(mysql_stmt_fetch(read) == MYSQL_NO_DATA);
    MYSQL_STMT *insert = prepare(c,"INSERT INTO c_mysql_scalars VALUES (?,?,?)");
    int32_t id = INT32_MIN;
    float f = -1.25f;
    char decimal[20] = "-123.45";
    unsigned long length = 7;
    MYSQL_BIND binds[3] = {{0}};
    binds[0].buffer_type=MYSQL_TYPE_LONG; binds[0].buffer=&id;
    binds[1].buffer_type=MYSQL_TYPE_FLOAT; binds[1].buffer=&f;
    binds[2].buffer_type=MYSQL_TYPE_NEWDECIMAL; binds[2].buffer=decimal;
    binds[2].buffer_length=sizeof(decimal); binds[2].length=&length;
    assert(!mysql_stmt_bind_param(insert,binds));
    execute(insert);
    assert(mysql_stmt_affected_rows(insert) == 1);
    id=0; f=0; memset(decimal,0,sizeof(decimal));
    assert(!mysql_stmt_bind_result(read,binds));
    execute(read);
    assert(!mysql_stmt_fetch(read));
    assert(id == INT32_MIN && f == -1.25f && length == 7 && !memcmp(decimal,"-123.45",7));
    assert(mysql_stmt_fetch(read) == MYSQL_NO_DATA);
    mysql_stmt_close(read); mysql_stmt_close(insert);
    puts("libmysqlclient: int32/float32/decimal prepared metadata, NULL flags and exact binary input/output passed");
}
int main(int argc, char **argv) {
    assert(mysql_get_client_version() == 80411);
    MYSQL *c = mysql_init(NULL);
    enum mysql_ssl_mode ssl = SSL_MODE_VERIFY_IDENTITY;
    unsigned int protocol = MYSQL_PROTOCOL_TCP;
    bool reconnect = false;
    assert(!mysql_options(c, MYSQL_OPT_SSL_MODE, &ssl));
    assert(!mysql_options(c, MYSQL_OPT_PROTOCOL, &protocol));
    assert(!mysql_options(c, MYSQL_OPT_SSL_CA, getenv("PGSSLROOTCERT")));
    assert(!mysql_options(c, MYSQL_OPT_RECONNECT, &reconnect));
    assert(!mysql_options(c, MYSQL_SET_CHARSET_NAME, "utf8mb4"));
    if (!mysql_real_connect(c, "localhost", "proof", getenv("PGPASSWORD"), "data", atoi(getenv("MYSQL_TCP_PORT")), NULL, CLIENT_FOUND_ROWS)) {
        fprintf(stderr,"connect: %s\n",mysql_error(c)); return 1;
    }
    assert(mysql_get_ssl_cipher(c));
    query(c, "SET NAMES utf8mb4 COLLATE utf8mb4_0900_bin");
    query(c, "SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");
    scalar_types(c);
    if (argc == 2 && !strcmp(argv[1], "types")) { mysql_close(c); return 0; }
    query(c, "CREATE TABLE c_mysql_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)");
    MYSQL_STMT *insert = prepare(c,"INSERT INTO c_mysql_rows (id,n,f,b,label,payload) VALUES (?,?,?,?,?,?)");
    assert(mysql_stmt_param_count(insert) == 6);
    int64_t id = INT64_MIN;
    uint64_t n = UINT64_MAX;
    double f = -1.25;
    unsigned char b = 1;
    char label[] = "snow \xe2\x98\x83";
    unsigned char payload[] = {0,255};
    unsigned long lengths[] = {8,8,8,1,sizeof(label)-1,sizeof(payload)};
    bool nulls[6] = {false};
    MYSQL_BIND binds[6] = {{0}};
    void *buffers[] = {&id,&n,&f,&b,label,payload};
    enum enum_field_types types[] = {MYSQL_TYPE_LONGLONG, MYSQL_TYPE_LONGLONG, MYSQL_TYPE_DOUBLE, MYSQL_TYPE_TINY, MYSQL_TYPE_STRING, MYSQL_TYPE_BLOB};
    for (int i=0; i<6; i++) { binds[i].buffer_type=types[i]; binds[i].buffer=buffers[i]; binds[i].buffer_length=lengths[i]; binds[i].length=&lengths[i]; binds[i].is_null=&nulls[i]; }
    binds[1].is_unsigned = binds[3].is_unsigned = true;
    assert(!mysql_stmt_bind_param(insert,binds));
    execute(insert);
    assert(mysql_stmt_affected_rows(insert) == 1);
    MYSQL_STMT *read = prepare(c,"SELECT id,n,f,b,label,payload FROM c_mysql_rows WHERE id=?");
    assert(!mysql_stmt_bind_param(read,binds));
    execute(read);
    MYSQL_RES *metadata = mysql_stmt_result_metadata(read);
    assert(mysql_num_fields(metadata) == 6);
    MYSQL_FIELD *fields = mysql_fetch_fields(metadata);
    assert(fields[0].type == MYSQL_TYPE_LONGLONG && !(fields[0].flags & UNSIGNED_FLAG));
    assert(fields[1].type == MYSQL_TYPE_LONGLONG && (fields[1].flags & UNSIGNED_FLAG));
    assert(fields[4].charsetnr == 309 && fields[5].charsetnr == 63);
    mysql_free_result(metadata);
    id=0; n=0; f=0; b=0; memset(label,0,sizeof(label)); memset(payload,0,sizeof(payload));
    assert(!mysql_stmt_bind_result(read,binds));
    assert(!mysql_stmt_fetch(read));
    assert(id == INT64_MIN && n == UINT64_MAX && f == -1.25 && b == 1);
    assert(lengths[4] == 8 && memcmp(label,"snow \xe2\x98\x83",8) == 0);
    assert(lengths[5] == 2 && payload[0] == 0 && payload[1] == 255);
    assert(mysql_stmt_fetch(read) == MYSQL_NO_DATA);
    assert(!mysql_stmt_reset(read));
    id=2;
    for (int i=1; i<6; i++) nulls[i]=true;
    execute(insert);
    execute(read);
    assert(!mysql_stmt_fetch(read));
    for (int i=1; i<6; i++) assert(nulls[i]);
    assert(mysql_stmt_fetch(read) == MYSQL_NO_DATA);
    mysql_stmt_close(read);
    mysql_stmt_close(insert);
    query(c,"UPDATE c_mysql_rows SET n=NULL WHERE id=2");
    assert(mysql_affected_rows(c) == 1);
    query(c,"DELETE FROM c_mysql_rows");
    assert(mysql_affected_rows(c) == 2);
    assert(!mysql_reset_connection(c));
    mysql_close(c);
    puts("libmysqlclient 8.4.11: prepared six types, NULL, found rows and reset passed");
}

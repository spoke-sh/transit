/* Independent pinned ADBC C ABI consumer. All stream/array/schema handles are
 * released explicitly; driver execution remains outside the native gateway. */
#include "adbc.h"
#include <dlfcn.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(call) do { AdbcStatusCode rc = (call); if (rc != ADBC_STATUS_OK) { \
  fprintf(stderr, "ADBC C step %d failed with status %u\n", __LINE__, rc); goto cleanup; } } while (0)
#define REQUIRE(test) do { if (!(test)) { fprintf(stderr, "ADBC C check %d failed\n", __LINE__); goto cleanup; } } while (0)

int main(int argc, char **argv) {
  if (argc != 6) return 2; /* driver path, URI, credential file, explicit sequence, trusted CA */
  int result = 1, loaded = 0, database_new = 0, connection_new = 0, statement_new = 0;
  struct AdbcDriver driver = {0};
  struct AdbcDatabase database = {0};
  struct AdbcConnection connection = {0};
  struct AdbcStatement statement = {0};
  struct AdbcError error = ADBC_ERROR_INIT;
  struct ArrowArrayStream stream = {0};
  struct ArrowSchema schema = {0};
  struct ArrowArray array = {0};
  char credential[129] = {0}, authorization[136] = "Bearer ";
  FILE *file = fopen(argv[3], "rb");
  if (!file) return 2;
  size_t length = fread(credential, 1, 128, file);
  int extra = fgetc(file);
  fclose(file);
  if (length < 32 || extra != EOF) return 2;
  memcpy(authorization + 7, credential, length);
  char certificate[8193] = {0};
  file = fopen(argv[5], "rb");
  if (!file) return 2;
  length = fread(certificate, 1, 8192, file);
  extra = fgetc(file);
  fclose(file);
  if (!length || extra != EOF) return 2;
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) return 2;
  AdbcDriverInitFunc init = (AdbcDriverInitFunc)dlsym(library, "AdbcDriverInit");
  REQUIRE(init != NULL);
  CHECK(init(ADBC_VERSION_1_1_0, &driver, &error)); loaded = 1;
  CHECK(driver.DatabaseNew(&database, &error)); database_new = 1;
  CHECK(driver.DatabaseSetOption(&database, "uri", argv[2], &error));
  CHECK(driver.DatabaseSetOption(&database, "adbc.flight.sql.authorization_header", authorization, &error));
  CHECK(driver.DatabaseSetOption(&database, "adbc.flight.sql.client_option.tls_root_certs", certificate, &error));
  CHECK(driver.DatabaseInit(&database, &error));
  CHECK(driver.ConnectionNew(&connection, &error)); connection_new = 1;
  CHECK(driver.ConnectionInit(&connection, &database, &error));
  CHECK(driver.ConnectionGetTableSchema(&connection, "transit", "public", "items", &schema, &error));
  REQUIRE(schema.n_children == 2 && strcmp(schema.children[0]->format, "l") == 0 && strcmp(schema.children[1]->format, "l") == 0);
  schema.release(&schema);
  CHECK(driver.StatementNew(&connection, &statement, &error)); statement_new = 1;
  CHECK(driver.StatementSetOption(&statement, "adbc.flight.sql.rpc.call_header.x-transit-request-sequence", argv[4], &error));
  CHECK(driver.StatementSetSqlQuery(&statement, "SELECT id, value FROM items", &error));
  int64_t affected = -1, rows = 0;
  CHECK(driver.StatementExecuteQuery(&statement, &stream, &affected, &error));
  REQUIRE(stream.get_schema(&stream, &schema) == 0);
  REQUIRE(schema.n_children == 2 && strcmp(schema.children[0]->format, "l") == 0 && strcmp(schema.children[1]->format, "l") == 0);
  for (;;) {
    REQUIRE(stream.get_next(&stream, &array) == 0);
    if (!array.release) break;
    REQUIRE(array.n_children == 2);
    const struct ArrowArray *ids = array.children[0], *values = array.children[1];
    REQUIRE(ids->n_buffers == 2 && values->n_buffers == 2);
    for (int64_t i = 0; i < array.length; ++i, ++rows) {
      int64_t key = ((const int64_t*)ids->buffers[1])[ids->offset + i];
      REQUIRE(key == rows);
      const uint8_t *validity = (const uint8_t*)values->buffers[0];
      int64_t offset = values->offset + i;
      int valid = !validity || ((validity[offset / 8] >> (offset % 8)) & 1);
      REQUIRE(valid == (rows % 5 != 0));
      if (valid) REQUIRE(((const int64_t*)values->buffers[1])[offset] == INT64_C(9007199254740993) + rows);
    }
    array.release(&array);
  }
  REQUIRE(rows == 41);
  printf("ADBC C: verified %" PRId64 " exact int64/null rows and native Table schema\n", rows);
  result = 0;
cleanup:
  if (array.release) array.release(&array);
  if (schema.release) schema.release(&schema);
  if (stream.release) stream.release(&stream);
  if (error.release) error.release(&error);
  if (statement_new && driver.StatementRelease(&statement, &error) != ADBC_STATUS_OK) result = 1;
  if (connection_new && driver.ConnectionRelease(&connection, &error) != ADBC_STATUS_OK) result = 1;
  if (database_new && driver.DatabaseRelease(&database, &error) != ADBC_STATUS_OK) result = 1;
  if (loaded && driver.release && driver.release(&driver, &error) != ADBC_STATUS_OK) result = 1;
  if (error.release) error.release(&error);
  memset(credential, 0, sizeof credential);
  memset(authorization, 0, sizeof authorization);
  dlclose(library);
  return result;
}

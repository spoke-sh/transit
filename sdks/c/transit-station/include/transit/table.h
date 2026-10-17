#ifndef TRANSIT_SDK_TABLE_H
#define TRANSIT_SDK_TABLE_H
#include <transit/catalog.h>
#ifdef __cplusplus
extern "C" {
#endif

/* General application-owned Tables. Construction views borrow input only for
 * the synchronous call. Schema/row views borrow their returned owner; destroy
 * that owner only after all users have finished. Saved work owns original bytes. */
typedef struct transit_station_table_page transit_station_table_page;
typedef struct transit_station_table_mutation transit_station_table_mutation;
typedef struct transit_station_row_identity { uint8_t bytes[20]; } transit_station_row_identity;
typedef struct transit_station_row_view {
    transit_station_row_identity identity;
    const transit_logical_cell_view *cells;
    size_t cell_count;
} transit_station_row_view;
typedef uint32_t transit_station_table_creation_state;
enum { TRANSIT_TABLE_CREATION_BUILDING, TRANSIT_TABLE_CREATION_APPLIED };
typedef struct transit_station_table_creation {
    transit_station_table_creation_state state;
    uint64_t admitted_input;
    bool has_completed_input;
    uint64_t completed_input;
} transit_station_table_creation;
typedef uint32_t transit_station_table_mutation_kind;
enum { TRANSIT_TABLE_INSERT, TRANSIT_TABLE_UPDATE, TRANSIT_TABLE_DELETE };
typedef struct transit_station_table_mutation_spec {
    transit_station_table_mutation_kind kind;
    union {
        struct { const transit_station_catalog_assignments *rows; size_t row_count; } insert;
        struct { transit_station_catalog_assignments assignments; transit_station_catalog_predicate predicate; } update;
        transit_station_catalog_predicate remove;
    } as;
} transit_station_table_mutation_spec;
typedef struct transit_station_table_reference {
    char definition[65];
    transit_sdk_resource resource;
    uint64_t object, principal, operation;
    uint8_t digest[32];
} transit_station_table_reference;
typedef uint32_t transit_station_table_mutation_state;
enum { TRANSIT_TABLE_BUILDING, TRANSIT_TABLE_APPLIED, TRANSIT_TABLE_REJECTED, TRANSIT_TABLE_CANCELLED };
typedef uint32_t transit_station_table_mutation_route;
enum { TRANSIT_TABLE_POINT, TRANSIT_TABLE_STATEMENT, TRANSIT_TABLE_ALTER };
typedef uint32_t transit_station_table_rejection;
enum { TRANSIT_TABLE_NONE, TRANSIT_TABLE_ROW_EXISTS, TRANSIT_TABLE_ROW_IDENTITY_EXISTS, TRANSIT_TABLE_NULL_NOT_ALLOWED,
    TRANSIT_TABLE_MISSING_REQUIRED_FIELD, TRANSIT_TABLE_CHARACTER_LIMIT_EXCEEDED, TRANSIT_TABLE_OVERFLOW, TRANSIT_TABLE_INEXACT };
typedef uint32_t transit_station_table_witness_source;
enum { TRANSIT_TABLE_WITNESS_INPUT, TRANSIT_TABLE_WITNESS_STORED, TRANSIT_TABLE_WITNESS_WITHHELD };
typedef struct transit_station_table_witness {
    transit_station_table_witness_source source;
    bool has_row;
    transit_station_row_identity row;
    uint64_t column;
    char text[257];
    size_t text_bytes;
    bool truncated;
} transit_station_table_witness;
typedef struct transit_station_table_status {
    transit_station_table_reference reference;
    transit_station_table_mutation_state state;
    transit_station_table_mutation_route route;
    uint64_t admitted_input;
    bool has_completed_input;
    uint64_t completed_input;
    bool has_counts;
    transit_station_catalog_counts counts;
    transit_station_table_rejection rejection;
    bool has_witness;
    transit_station_table_witness witness;
} transit_station_table_status;

transit_sdk_error transit_station_table_open(transit_station_turn *, uint64_t object, const transit_station_read_version *, transit_station_table **out);
/* One private creation step; repeat original schema/limits after commit. */
transit_sdk_error transit_station_table_create(transit_station_turn *, const transit_station_catalog_schema *, const transit_station_catalog_limits *, transit_station_table_creation *out);
transit_sdk_error transit_station_table_schema(transit_station_table *, const transit_station_catalog_schema **out);
transit_sdk_error transit_station_table_read_basis(transit_station_table *, transit_station_table_basis *out);
transit_sdk_error transit_station_table_get(transit_station_table *, transit_station_row_identity, transit_station_row **out);
transit_sdk_error transit_station_table_get_key(transit_station_table *, const transit_logical_cell_view *, size_t count, transit_station_row **out);
transit_sdk_error transit_station_table_page_read(transit_station_table *, const transit_station_cursor *, size_t limit, transit_station_table_page **out);
transit_sdk_error transit_station_row_inspect(const transit_station_row *, transit_station_row_view *out);
void transit_station_row_destroy(transit_station_row *);
size_t transit_station_table_page_size(const transit_station_table_page *);
transit_sdk_error transit_station_table_page_row(const transit_station_table_page *, size_t index, transit_station_row_view *out);
transit_sdk_error transit_station_table_page_next(const transit_station_table_page *, transit_station_cursor **out);
void transit_station_table_page_destroy(transit_station_table_page *);
/* Companion-language conversion failures also invalidate the private read.
 * Pass a non-OK SDK error. Scope/thread checks still apply; no I/O is issued. */
transit_sdk_error transit_station_table_fail_read(transit_station_table *, transit_sdk_error);
void transit_station_table_destroy(transit_station_table *);

/* A mutation freezes the original schema and explicit operation namespace.
 * Each step prepares one private turn. It neither commits nor schedules work. */
transit_sdk_error transit_station_table_mutation_prepare(transit_sdk_resource, uint64_t principal, uint64_t operation, const transit_station_catalog_schema *, const transit_station_table_mutation_spec *, transit_station_table_mutation **out);
transit_sdk_error transit_station_table_prepare(transit_station_table *, uint64_t principal, uint64_t operation, const transit_station_table_mutation_spec *, transit_station_table_mutation **out);
transit_sdk_error transit_station_table_mutation_import(transit_sdk_bytes, transit_station_table_mutation **out);
transit_sdk_error transit_station_table_mutation_bytes(const transit_station_table_mutation *, transit_sdk_bytes *out);
transit_sdk_error transit_station_table_mutation_schema(const transit_station_table_mutation *, const transit_station_catalog_schema **out);
transit_sdk_error transit_station_table_mutation_step(transit_station_turn *, const transit_station_table_mutation *, transit_station_table_status *out);
void transit_station_table_mutation_destroy(transit_station_table_mutation *);
transit_sdk_error transit_station_table_reference_import(transit_sdk_bytes, transit_station_table_reference *out);
transit_sdk_error transit_station_table_reference_export(const transit_station_table_reference *, transit_sdk_buffer *out);
transit_sdk_error transit_station_table_status_read(transit_station_turn *, const transit_station_table_reference *, bool *found, transit_station_table_status *out);
transit_sdk_error transit_station_table_cancel(transit_station_turn *, const transit_station_table_reference *, transit_station_table_status *out);
#ifdef __cplusplus
}
#endif
#endif

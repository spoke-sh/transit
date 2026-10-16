#include <transit/table.h>
#include <transit/unified_query.h>
#include <assert.h>
#include <string.h>
#ifndef transit_station_table_mutation_prepare
#error "Table C symbols must be bound to the shared contract definition"
#endif
void transit_test_table_c11(void) {
    transit_logical_type_view type = {0}; type.kind = TRANSIT_LOGICAL_INT64;
    transit_logical_cell_view cell = {0}; cell.state = TRANSIT_LOGICAL_NULL;
    const transit_station_catalog_column columns[] = {{1, "id", &type, true, &cell, 0}};
    const transit_station_catalog_schema schema = {UINT64_MAX, 1, 2, columns, 1, NULL, 0};
    const transit_station_catalog_assignment assignment = {1, NULL};
    const transit_station_catalog_assignments row = {&assignment, 1};
    transit_station_table_mutation_spec spec = {0}; spec.kind = TRANSIT_TABLE_INSERT; spec.as.insert.rows = &row; spec.as.insert.row_count = 1;
    transit_station_table_mutation *saved = NULL;
    assert(transit_station_table_mutation_prepare((transit_sdk_resource){46, 7}, 0, UINT64_MAX, &schema, &spec, &saved).kind == TRANSIT_SDK_OK);
    transit_sdk_bytes data = {0}; assert(transit_station_table_mutation_bytes(saved, &data).kind == TRANSIT_SDK_OK);
    transit_station_table_mutation *loaded = NULL;
    assert(transit_station_table_mutation_import(data, &loaded).kind == TRANSIT_SDK_OK);
    transit_station_table_mutation_destroy(saved);
    const transit_station_catalog_schema *owned = NULL;
    assert(transit_station_table_mutation_schema(loaded, &owned).kind == TRANSIT_SDK_OK && owned->object == UINT64_MAX && !strcmp(owned->columns[0].name, "id"));
    transit_station_table_mutation_destroy(loaded);
}

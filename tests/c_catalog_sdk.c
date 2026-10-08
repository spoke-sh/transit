/* Installed C11 general Table lifecycle through public typed APIs only. */
#include "catalog_sdk_io.h"
static transit_logical_cell_view atom(transit_logical_atom value) {
    transit_logical_cell_view out = {.state = TRANSIT_LOGICAL_VALUE, .as.value = {.kind = TRANSIT_VALUE_ATOM, .as.atom = value}}; return out;
}
static transit_station_catalog_outcome finish(transit_station_catalog_client *client, const transit_station_catalog_compiled *compiled, const char *root) {
    transit_station_catalog_intent intent; const transit_station_catalog_saved_intent *saved = NULL;
    checked(transit_station_catalog_compiled_get(compiled, &intent, &saved)); persist_saved(root, saved); const double deadline = now() + 120;
    for (;;) {
        assert(now() < deadline); transit_station_catalog_next *next = NULL; checked(transit_station_catalog_next_read(client, &intent.reference, &next));
        transit_station_catalog_next_view view; checked(transit_station_catalog_next_get(next, &view));
        if (view.kind == TRANSIT_CATALOG_NEXT_TERMINAL) { transit_station_catalog_outcome out = *view.outcome; transit_station_catalog_next_destroy(next); return out; }
        if (view.kind == TRANSIT_CATALOG_NEXT_RUNNING) { transit_station_catalog_next_destroy(next); continue; }
        assert(view.kind == TRANSIT_CATALOG_NEXT_SEND && view.prepared);
        transit_sdk_bytes bytes; checked(transit_station_catalog_prepared_bytes(view.prepared, &bytes)); persist(root, "step.json", bytes);
        uint64_t position = 0; checked(transit_station_catalog_submit(client, view.prepared, &position)); persist_receipt(root, position);
        transit_station_catalog_progress progress;
        do { assert(now() < deadline); checked(transit_station_catalog_progress_read(client, &intent.reference, view.prepared, position, true, &progress)); } while (progress.observation == TRANSIT_CATALOG_PENDING);
        assert(!progress.disposition.found); transit_station_catalog_next_destroy(next);
        if (progress.state.has_outcome && progress.state.outcome.terminal) return progress.state.outcome;
    }
}
static transit_station_catalog_outcome execute(transit_station_catalog_client *client, const char *root, const char *name, transit_station_catalog_identity id, transit_station_catalog_action action) {
    transit_station_catalog_request request = {name, id, action}; transit_station_catalog_compiled *compiled = NULL;
    checked(transit_station_catalog_prepare(client, &request, &compiled)); transit_station_catalog_outcome out = finish(client, compiled, root); transit_station_catalog_compiled_destroy(compiled); return out;
}
static void values(void) {
    transit_station_catalog_prepared *prepared = (transit_station_catalog_prepared *)(uintptr_t)1;
    assert(transit_station_catalog_prepared_import((transit_sdk_bytes){NULL, 0}, &prepared).kind == TRANSIT_SDK_INVALID_ARGUMENT && !prepared);
    uint8_t bytes[8193] = {1}; assert(transit_station_catalog_prepared_import((transit_sdk_bytes){bytes, sizeof(bytes)}, &prepared).kind == TRANSIT_SDK_INVALID_ARGUMENT && !prepared);
    checked(transit_station_catalog_prepared_import((transit_sdk_bytes){bytes, 1}, &prepared)); bytes[0] = 2;
    transit_sdk_bytes saved; checked(transit_station_catalog_prepared_bytes(prepared, &saved)); assert(saved.size == 1 && saved.data[0] == 1); transit_station_catalog_prepared_destroy(prepared);
    transit_station_catalog_saved_intent *intent = NULL;
    assert(transit_station_catalog_saved_import("", (transit_sdk_bytes){bytes, 1}, &intent).kind == TRANSIT_SDK_INVALID_ARGUMENT && !intent);
    uint8_t *large = malloc(300000); assert(large); memset(large, 9, 300000);
    checked(transit_station_catalog_saved_import(TRANSIT_SDK_STATION_DEFINITION, (transit_sdk_bytes){large, 300000}, &intent)); memset(large, 0, 300000); free(large);
    const char *definition = NULL; checked(transit_station_catalog_saved_get(intent, &definition, &saved)); assert(saved.size == 300000 && saved.data[299999] == 9 && !strcmp(definition, TRANSIT_SDK_STATION_DEFINITION)); transit_station_catalog_saved_destroy(intent);
}
static void scenario(transit_station_catalog_client *client, const transit_sdk_config *config, const transit_sdk_credential *credential, transit_station_catalog_connection connection, const char *root, uint64_t index) {
    uint64_t base = 1100 + index * 100, object = 12001 + index * 10; char name[80], sql[512];
    snprintf(name, sizeof(name), "sdk_people_%llu", (unsigned long long)index);
    snprintf(sql, sizeof(sql), "CREATE TABLE %s (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))", name);
    transit_station_catalog_capabilities caps; checked(transit_station_catalog_capabilities_read(client, &caps)); assert(caps.max_columns == 128 && caps.max_rows == 1024);
    transit_station_catalog_description description; checked(transit_station_catalog_describe(client, &description)); assert(description.policy.principal == credential->principal);
    transit_station_catalog_compiled *create = NULL; checked(transit_station_catalog_compile_sql(client, sql, identity(base, 0), &object, &create)); assert(finish(client, create, root).phase == TRANSIT_CATALOG_APPLIED); transit_station_catalog_compiled_destroy(create);
    transit_station_catalog_definition *original = NULL; checked(transit_station_catalog_lookup(client, name, &original)); assert(original);
    const transit_station_catalog_definition_view *original_view; checked(transit_station_catalog_definition_get(original, &original_view));
    assert(original_view->schema.column_count == 3 && original_view->schema.columns[1].type->kind == TRANSIT_LOGICAL_STRUCTURE);
    transit_station_catalog_basis source = basis(&original_view->metadata);
    uint8_t raw[] = {0, 128, 255};
    transit_logical_cell_view children[] = {
        atom((transit_logical_atom){.kind = TRANSIT_ATOM_BINARY, .as.bytes = {raw, sizeof(raw)}}),
        atom((transit_logical_atom){.kind = TRANSIT_ATOM_UTF8, .as.bytes = {(const uint8_t *)"東京", 6}})
    };
    transit_logical_cell_view payload = {.state = TRANSIT_LOGICAL_VALUE, .as.value = {.kind = TRANSIT_VALUE_STRUCTURE, .as.cells = {children, 2}}};
    transit_logical_cell_view key = atom((transit_logical_atom){.kind = TRANSIT_ATOM_SIGNED, .as.signed_value = {1, 0}});
    transit_logical_cell_view amount = atom((transit_logical_atom){.kind = TRANSIT_ATOM_DECIMAL, .as.signed_value = {UINT64_C(14083847773837265618), INT64_C(6692605942)}});
    transit_station_catalog_assignment assignments[] = {{3, &amount}, {1, &key}, {2, &payload}};
    transit_station_catalog_assignments row = {assignments, 3};
    transit_station_catalog_request insert_request = {name, identity(base, 1), {.kind = TRANSIT_CATALOG_INSERT, .as.insert = {source, &row, 1}}};
    transit_station_catalog_compiled *insert = NULL; checked(transit_station_catalog_prepare(client, &insert_request, &insert));
    transit_station_catalog_outcome applied = finish(client, insert, root); assert(applied.has_counts && applied.counts.matched == 1 && applied.counts.changed == 1);
    transit_station_catalog_predicate_term term = {.kind = TRANSIT_CATALOG_COMPARE, .column = 1, .as.compare = {TRANSIT_CATALOG_EQ, {.kind = TRANSIT_ATOM_SIGNED, .as.signed_value = {1, 0}}}};
    transit_station_catalog_predicate predicate = {&term, 1};
    transit_station_catalog_assignment unchanged = {3, &amount};
    transit_station_catalog_outcome updated = execute(client, root, name, identity(base, 2), (transit_station_catalog_action){.kind = TRANSIT_CATALOG_UPDATE, .as.update = {source, {&unchanged, 1}, predicate}});
    assert(updated.has_counts && updated.counts.matched == 1 && updated.counts.changed == 0);
    transit_logical_type_view boolean = {.kind = TRANSIT_LOGICAL_BOOLEAN};
    transit_logical_cell_view yes = atom((transit_logical_atom){.kind = TRANSIT_ATOM_BOOLEAN, .as.boolean = true});
    transit_station_catalog_change add = {.kind = TRANSIT_CATALOG_ADD_COLUMN, .as.add = {"enabled", &boolean, false, &yes, 0}};
    assert(execute(client, root, name, identity(base, 3), (transit_station_catalog_action){.kind = TRANSIT_CATALOG_ALTER, .as.alter = {source, add}}).phase == TRANSIT_CATALOG_APPLIED);
    transit_station_catalog_request stale = {name, identity(base, 4), {.kind = TRANSIT_CATALOG_DROP, .as.drop = {&source, false}}};
    transit_station_catalog_compiled *rejected = NULL; assert(transit_station_catalog_prepare(client, &stale, &rejected).kind != TRANSIT_SDK_OK && !rejected);
    transit_station_catalog_definition *current = NULL; checked(transit_station_catalog_lookup(client, name, &current)); assert(current);
    const transit_station_catalog_definition_view *current_view; checked(transit_station_catalog_definition_get(current, &current_view)); source = basis(&current_view->metadata);
    transit_station_catalog_outcome removed = execute(client, root, name, identity(base, 5), (transit_station_catalog_action){.kind = TRANSIT_CATALOG_DELETE, .as.remove = {source, predicate}});
    assert(removed.has_counts && removed.counts.matched == 1 && removed.counts.changed == 1);
    assert(execute(client, root, name, identity(base, 6), (transit_station_catalog_action){.kind = TRANSIT_CATALOG_DROP, .as.drop = {&source, false}}).phase == TRANSIT_CATALOG_APPLIED);
    uint64_t replacement = object + 1; transit_logical_type_view text_type = {.kind = TRANSIT_LOGICAL_UTF8};
    transit_station_catalog_column column = {1, "replacement", &text_type, true, NULL, 0};
    transit_station_catalog_schema new_schema = {replacement, 1, 2, &column, 1, NULL, 0};
    assert(execute(client, root, name, identity(base, 7), (transit_station_catalog_action){.kind = TRANSIT_CATALOG_CREATE, .as.create = {&new_schema, false}}).phase == TRANSIT_CATALOG_APPLIED);
    checked(transit_station_catalog_close(client));
    transit_station_catalog_client *fresh = NULL; checked(transit_station_catalog_open(config, credential, connection, &fresh));
    transit_station_catalog_intent intent; const transit_station_catalog_saved_intent *saved = NULL; checked(transit_station_catalog_compiled_get(insert, &intent, &saved));
    transit_station_catalog_intent loaded; checked(transit_station_catalog_load(fresh, saved, &loaded)); assert(loaded.object == object && !memcmp(loaded.reference.digest, intent.reference.digest, 32));
    transit_station_catalog_state state; checked(transit_station_catalog_status_read(fresh, &loaded.reference, &state)); assert(state.has_outcome && outcome_equal(&applied, &state.outcome));
    transit_station_catalog_definition *latest = NULL; checked(transit_station_catalog_lookup(fresh, name, &latest)); assert(latest);
    const transit_station_catalog_definition_view *latest_view; checked(transit_station_catalog_definition_get(latest, &latest_view)); assert(latest_view->metadata.object == replacement);
    transit_station_catalog_historical *history = NULL; checked(transit_station_catalog_definition_read(fresh, object, original_view->metadata.revision, &history)); assert(history);
    const transit_station_catalog_historical_view *historical; checked(transit_station_catalog_historical_get(history, &historical));
    assert(historical->metadata.object == object && historical->metadata.revision == original_view->metadata.revision && !memcmp(historical->metadata.schema_fingerprint, original_view->metadata.schema_fingerprint, 32));
    assert(historical->schema.column_count == 3 && historical->schema.columns[1].type->kind == TRANSIT_LOGICAL_STRUCTURE);
    transit_station_catalog_historical *missing = NULL; checked(transit_station_catalog_definition_read(fresh, object, 999, &missing)); assert(!missing);
    transit_station_catalog_page page; checked(transit_station_catalog_list(fresh, NULL, &page)); assert(page.count);
    checked(transit_station_catalog_close(fresh)); transit_station_catalog_client_destroy(fresh);
    /* Both current and original recursive definitions outlive native clients. */
    assert(historical->schema.columns[2].type->as.decimal.precision == 38 && original_view->schema.columns[1].type->as.fields.size == 2);
    transit_station_catalog_historical_destroy(history); transit_station_catalog_definition_destroy(latest); transit_station_catalog_definition_destroy(current); transit_station_catalog_definition_destroy(original); transit_station_catalog_compiled_destroy(insert);
    printf("{\"status\":0,\"value\":{\"profile\":\"installed-c-general-table\",\"original_object\":\"%llu\",\"replacement_object\":\"%llu\",\"counts\":{\"matched\":\"1\",\"changed\":\"1\"}}}\n", (unsigned long long)object, (unsigned long long)replacement);
}
int main(int argc, char **argv) {
    assert(argc == 9); setvbuf(stdout, NULL, _IOLBF, 0); values();
    uint64_t realm = number(argv[3]); transit_station_catalog_connection connection = {{realm, number(argv[5])}, {{realm, number(argv[6])}, number(argv[7])}};
    transit_sdk_config config = transit_sdk_growing_config(argv[1]); config.timeout_ms = 10000;
    transit_sdk_credential credential = {realm, number(argv[4]), argv[2]}; transit_station_catalog_client *client = NULL;
    checked(transit_station_catalog_open(&config, &credential, connection, &client)); puts("{\"ready\":true}");
    while (read_command() && strcmp(args[0], "close")) { assert(!strcmp(args[0], "scenario")); scenario(client, &config, &credential, connection, argv[8], number(args[1])); }
    checked(transit_station_catalog_close(client)); transit_station_catalog_client_destroy(client); puts("{\"closed\":true}"); return 0;
}

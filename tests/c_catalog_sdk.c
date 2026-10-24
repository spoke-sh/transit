/* Installed C11 direct lifecycle; no native wire calls or storage access. */
#include "catalog_sdk_io.h"
static const char *directory;
static transit_station_catalog_client *client;
static uint64_t base, object;
static const char *table_name = "c_items";
#define SAVE(K, P, N) do { transit_sdk_bytes bytes_; checked(transit_station_catalog_##K##_export(P, &bytes_)); persist(directory, N, bytes_); } while (0)
#define LOAD(K, P, N) do { transit_sdk_bytes bytes_ = read_saved(directory, N); checked(transit_station_catalog_##K##_restore(bytes_, &(P))); free((void *)bytes_.data); } while (0)
static transit_station_catalog_commit finish(transit_station_catalog_compiled *work) {
    const transit_station_catalog_intent *intent; const transit_station_catalog_saved_intent *saved;
    checked(transit_station_catalog_compiled_get(work, &intent, &saved)); SAVE(saved_intent, saved, "work.json");
    transit_station_catalog_reference *reference = NULL; checked(transit_station_catalog_stage(client, intent, &reference)); SAVE(reference, reference, "work-reference.json");
    transit_station_catalog_observation *observed = NULL; checked(transit_station_catalog_admit(client, reference, &observed));
    const transit_station_catalog_observation_view *v; checked(transit_station_catalog_observation_get(observed, &v));
    for (unsigned i = 0; i < 16 && v->state == TRANSIT_CATALOG_ADMITTED; ++i) {
        transit_station_catalog_observation_destroy(observed); checked(transit_station_catalog_execute(client, reference, 32, &observed)); checked(transit_station_catalog_observation_get(observed, &v));
    }
    assert(v->state == TRANSIT_CATALOG_COMMITTED && v->has_commit); transit_station_catalog_commit out = v->commit;
    transit_station_catalog_observation_destroy(observed); transit_station_catalog_reference_destroy(reference); transit_station_catalog_compiled_destroy(work); return out;
}
static transit_station_catalog_compiled *compile(const char *sql, uint64_t operation, const uint64_t *id) {
    transit_station_catalog_compiled *out = NULL; checked(transit_station_catalog_compile_sql(client, sql, (transit_station_catalog_identity){base + operation, 1}, id, TRANSIT_CATALOG_TRANSIT, TRANSIT_CATALOG_POINT, &out)); return out;
}
static transit_station_catalog_metadata *lookup(void) {
    transit_station_catalog_metadata *out = NULL; checked(transit_station_catalog_lookup(client, table_name, 1, &out)); assert(out); return out;
}
static transit_station_catalog_snapshot *load_snapshot(void) { transit_station_catalog_snapshot *s = NULL; LOAD(snapshot, s, "snapshot.json"); return s; }
static transit_logical_cell_view atom(transit_logical_atom value) { transit_logical_cell_view out = {.state = TRANSIT_LOGICAL_VALUE, .as.value = {.kind = TRANSIT_VALUE_ATOM, .as.atom = value}}; return out; }
int main(int argc, char **argv) {
    assert(argc == 11); setvbuf(stdout, NULL, _IOLBF, 0); assert(!strcmp(argv[1], "c")); base = 0; object = UINT64_MAX - 1; directory = argv[9];
    transit_sdk_config config = transit_sdk_growing_config(argv[2]); config.timeout_ms = 10000;
    transit_sdk_credential credential = {number(argv[4]), number(argv[5]), argv[3]};
    transit_station_catalog_connection connection = {{{credential.realm, number(argv[7])}, number(argv[8])}, number(argv[6]), 1, false, 0};
    checked(transit_station_catalog_open(&config, &credential, connection, argv[10], &client)); puts("{\"ready\":true}");
    while (read_command() && strcmp(args[0], "close")) {
        if (!strcmp(args[0], "prepare")) {
            transit_station_catalog_description d; checked(transit_station_catalog_describe(client, &d)); assert(d.subject.principal == credential.principal);
            bool found = false; transit_station_catalog_namespace ns; checked(transit_station_catalog_namespace_read(client, 1, &found, &ns)); assert(found && !strcmp(ns.name, "public"));
            transit_station_catalog_namespace_page *page = NULL; checked(transit_station_catalog_namespaces(client, NULL, &page)); const transit_station_catalog_namespace_page_view *p; checked(transit_station_catalog_namespace_page_get(page, &p)); assert(p->count && p->entries[0].id == 1); transit_station_catalog_namespace_page_destroy(page);
            finish(compile("CREATE TABLE c_items (id BIGINT PRIMARY KEY, payload BINARY)", 1, &object));
            transit_station_catalog_metadata *m = lookup(); const transit_station_catalog_metadata_view *v; checked(transit_station_catalog_metadata_get(m, &v)); assert(v->row_count == 0);
            uint8_t payloads[9][32768]; transit_logical_cell_view cells[9][2]; transit_station_catalog_assignment assignments[9][2]; transit_station_catalog_assignments rows[9];
            for (size_t i = 0; i < 9; ++i) {
                memset(payloads[i], (int)i, sizeof(payloads[i])); cells[i][0] = atom((transit_logical_atom){.kind = TRANSIT_ATOM_SIGNED, .as.signed_value = {(uint64_t)i, 0}});
                cells[i][1] = atom((transit_logical_atom){.kind = TRANSIT_ATOM_BINARY, .as.bytes = {payloads[i], sizeof(payloads[i])}});
                assignments[i][0] = (transit_station_catalog_assignment){1, &cells[i][0]}; assignments[i][1] = (transit_station_catalog_assignment){2, &cells[i][1]}; rows[i] = (transit_station_catalog_assignments){assignments[i], 2};
            }
            transit_station_catalog_request request = {.name = table_name, .identity = {base + 2, 1}, .action = {.kind = TRANSIT_CATALOG_INSERT, .ingestion = TRANSIT_CATALOG_BULK, .as.insert = {v->basis, rows, 9}}};
            transit_station_catalog_compiled *work = NULL; checked(transit_station_catalog_prepare(client, &request, &work)); transit_station_catalog_metadata_destroy(m);
            const transit_station_catalog_intent *intent; const transit_station_catalog_saved_intent *saved; checked(transit_station_catalog_compiled_get(work, &intent, &saved));
            transit_station_catalog_preview *preview = NULL; checked(transit_station_catalog_preview_read(client, intent, &preview)); const transit_station_catalog_preview_view *pv; checked(transit_station_catalog_preview_get(preview, &pv)); assert(pv->has_current && pv->current.row_count == 0); transit_station_catalog_preview_destroy(preview);
            SAVE(saved_intent, saved, "intent.json"); transit_station_catalog_saved_intent *restored = NULL; LOAD(saved_intent, restored, "intent.json"); transit_station_catalog_intent *loaded = NULL; checked(transit_station_catalog_load(client, restored, &loaded));
            transit_station_catalog_reference *reference = NULL; checked(transit_station_catalog_stage(client, loaded, &reference)); SAVE(reference, reference, "original.json");
            transit_station_catalog_observation *observed = NULL; checked(transit_station_catalog_admit(client, reference, &observed)); const transit_station_catalog_observation_view *ov; checked(transit_station_catalog_observation_get(observed, &ov)); assert(ov->state == TRANSIT_CATALOG_ADMITTED); transit_station_catalog_observation_destroy(observed);
            uncertain(transit_station_catalog_execute(client, reference, 32, &observed)); assert(!observed);
            transit_station_catalog_reference_destroy(reference); transit_station_catalog_intent_destroy(loaded); transit_station_catalog_saved_intent_destroy(restored); transit_station_catalog_compiled_destroy(work);
            puts("{\"status\":0,\"value\":{\"uncertain\":true}}");
        } else if (!strcmp(args[0], "recover")) {
            transit_station_catalog_reference *reference = NULL; LOAD(reference, reference, "original.json"); transit_station_catalog_observation *observed = NULL; checked(transit_station_catalog_inspect(client, reference, &observed));
            const transit_station_catalog_observation_view *v; checked(transit_station_catalog_observation_get(observed, &v)); assert(v->state == TRANSIT_CATALOG_COMMITTED && v->commit.matched == 9 && v->commit.affected == 9 && v->commit.live_rows == 9); transit_station_catalog_commit original = v->commit;
            transit_station_catalog_observation_destroy(observed); checked(transit_station_catalog_execute(client, reference, 32, &observed)); checked(transit_station_catalog_observation_get(observed, &v)); assert(v->commit.position.next_lsn == original.position.next_lsn && v->commit.affected == 9); transit_station_catalog_observation_destroy(observed); transit_station_catalog_reference_destroy(reference);
            transit_station_catalog_metadata *m = lookup(); const transit_station_catalog_metadata_view *mv; checked(transit_station_catalog_metadata_get(m, &mv)); SAVE(basis, mv->basis, "basis.json");
            transit_station_catalog_snapshot_acquisition *a = NULL; checked(transit_station_catalog_prepare_snapshot(m, 90000 + base, &a)); SAVE(snapshot_acquisition, a, "acquisition.json"); transit_station_catalog_metadata_destroy(m);
            transit_station_catalog_snapshot *s = NULL; uncertain(transit_station_catalog_acquire_snapshot(client, a, &s)); assert(!s); transit_station_catalog_snapshot_acquisition_destroy(a);
            puts("{\"status\":0,\"value\":{\"retention_uncertain\":true}}");
        } else if (!strcmp(args[0], "retained")) {
            transit_station_catalog_snapshot_acquisition *a = NULL; LOAD(snapshot_acquisition, a, "acquisition.json"); const transit_station_catalog_snapshot_acquisition_view *av; checked(transit_station_catalog_snapshot_acquisition_get(a, &av));
            transit_station_catalog_snapshot_status *status = NULL; checked(transit_station_catalog_snapshot_status_read(client, av->owner, &status)); const transit_station_catalog_snapshot_status_view *v; checked(transit_station_catalog_snapshot_status_get(status, &v)); assert(!v->released && v->snapshot); SAVE(snapshot, v->snapshot, "snapshot.json");
            transit_station_catalog_snapshot_metadata *m = NULL; checked(transit_station_catalog_snapshot_metadata_read(client, v->snapshot, &m)); const transit_station_catalog_snapshot_metadata_view *mv; checked(transit_station_catalog_snapshot_metadata_get(m, &mv)); assert(mv->accepted.partition == av->expected.partition && mv->accepted.next_lsn == av->expected.next_lsn && mv->row_count == 9 && mv->schema.column_count == 2);
            transit_station_catalog_snapshot_metadata_destroy(m); transit_station_catalog_snapshot_status_destroy(status); transit_station_catalog_snapshot_acquisition_destroy(a); puts("{\"status\":0,\"value\":{\"retained\":true}}");
        } else if (!strcmp(args[0], "denied") || !strcmp(args[0], "metadata")) {
            transit_station_catalog_snapshot *s = load_snapshot(); transit_station_catalog_snapshot_metadata *m = NULL; transit_sdk_error e = transit_station_catalog_snapshot_metadata_read(client, s, &m);
            if (!strcmp(args[0], "denied")) { assert(e.kind == TRANSIT_SDK_ACCESS_DENIED && e.native_status == 4 && !m); puts("{\"status\":0,\"value\":{\"denied\":true}}"); }
            else {
                checked(e); const transit_station_catalog_snapshot_metadata_view *v; checked(transit_station_catalog_snapshot_metadata_get(m, &v)); transit_station_catalog_basis *b = NULL; LOAD(basis, b, "basis.json"); const transit_station_catalog_basis_view *bv; checked(transit_station_catalog_basis_get(b, &bv));
                assert(v->interpretation.interpretation.revision == bv->interpretation.interpretation.revision && !memcmp(v->interpretation.content.sha256, bv->interpretation.content.sha256, 32)); assert(v->row_count == 9 && v->schema.column_count == 2); transit_station_catalog_basis_destroy(b); transit_station_catalog_snapshot_metadata_destroy(m); puts("{\"status\":0,\"value\":{\"rows\":9,\"columns\":2}}");
            }
            transit_station_catalog_snapshot_destroy(s);
        } else if (!strcmp(args[0], "retire")) {
            transit_station_catalog_commit r = finish(compile("UPDATE c_items SET id=0 WHERE id=0", 3, NULL)); assert(r.matched == 1 && r.affected == 0);
            r = finish(compile("DELETE FROM c_items WHERE id=8", 4, NULL)); assert(r.matched == 1 && r.affected == 1);
            transit_station_catalog_metadata *old = lookup(); const transit_station_catalog_metadata_view *mv; checked(transit_station_catalog_metadata_get(old, &mv));
            transit_logical_type_view type = {.kind = TRANSIT_LOGICAL_INT64}; transit_station_catalog_request request = {.name = table_name, .identity = {base + 5, 1}, .action = {.kind = TRANSIT_CATALOG_ALTER, .as.alter = {.basis = mv->basis, .change = {.kind = TRANSIT_CATALOG_ADD_COLUMN, .as.add = {"extra", &type, true, NULL, 0, TRANSIT_CATALOG_PLAIN, TRANSIT_CATALOG_NONE}}}}};
            transit_station_catalog_compiled *work = NULL; checked(transit_station_catalog_prepare(client, &request, &work)); finish(work);
            request.identity.operation = base + 55; request.action.kind = TRANSIT_CATALOG_DROP; request.action.as.drop.basis = mv->basis; request.action.as.drop.if_exists = false;
            transit_sdk_error e = transit_station_catalog_prepare(client, &request, &work); assert(e.kind && !strcmp(e.code, "TableDefinitionChanged") && !work); transit_station_catalog_metadata_destroy(old);
            finish(compile("ALTER TABLE c_items RENAME TO c_items_old", 6, NULL)); finish(compile("DROP TABLE c_items_old", 7, NULL)); uint64_t replacement = object - 1; finish(compile("CREATE TABLE c_items (replacement BIGINT)", 8, &replacement));
            puts("{\"status\":0,\"value\":{\"original\":true}}");
        } else if (!strcmp(args[0], "release") || !strcmp(args[0], "verify")) {
            transit_station_catalog_snapshot *s = load_snapshot(); const transit_station_catalog_snapshot_view *sv; checked(transit_station_catalog_snapshot_get(s, &sv)); transit_station_catalog_snapshot_status *status = NULL; checked(transit_station_catalog_snapshot_status_read(client, sv->owner, &status)); const transit_station_catalog_snapshot_status_view *v; checked(transit_station_catalog_snapshot_status_get(status, &v));
            if (!strcmp(args[0], "release")) { assert(!v->released); uncertain(transit_station_catalog_release_snapshot(client, s)); puts("{\"status\":0,\"value\":{\"release_uncertain\":true}}"); }
            else {
                assert(v->released); checked(transit_station_catalog_release_snapshot(client, s)); transit_station_catalog_reference *reference = NULL; LOAD(reference, reference, "original.json"); transit_station_catalog_observation *observed = NULL; checked(transit_station_catalog_inspect(client, reference, &observed)); const transit_station_catalog_observation_view *ov; checked(transit_station_catalog_observation_get(observed, &ov)); assert(ov->commit.affected == 9); transit_station_catalog_observation_destroy(observed); transit_station_catalog_reference_destroy(reference);
                transit_station_catalog_saved_intent *saved = NULL; LOAD(saved_intent, saved, "intent.json"); transit_station_catalog_intent *intent = NULL; checked(transit_station_catalog_load(client, saved, &intent)); const transit_station_catalog_intent_view *iv; checked(transit_station_catalog_intent_get(intent, &iv)); assert(iv->identity.operation == base + 2); transit_station_catalog_intent_destroy(intent); transit_station_catalog_saved_intent_destroy(saved);
                transit_station_catalog_metadata *m = lookup(); const transit_station_catalog_metadata_view *mv; checked(transit_station_catalog_metadata_get(m, &mv)); const transit_station_catalog_basis_view *bv; checked(transit_station_catalog_basis_get(mv->basis, &bv)); assert(bv->interpretation.interpretation.object.object == object - 1); transit_station_catalog_metadata_destroy(m);
                transit_station_catalog_table_page *page = NULL; checked(transit_station_catalog_tables(client, 1, NULL, &page)); transit_station_catalog_table_page_destroy(page); puts("{\"status\":0,\"value\":{\"recovered\":true}}");
            }
            transit_station_catalog_snapshot_status_destroy(status); transit_station_catalog_snapshot_destroy(s);
        } else assert(0);
    }
    checked(transit_station_catalog_close(client)); transit_station_catalog_client_destroy(client); puts("{\"closed\":true}"); return 0;
}

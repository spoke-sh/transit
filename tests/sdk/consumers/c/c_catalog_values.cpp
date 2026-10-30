// Installed C/C++ API boundary: complete bindings, bounded values and joined cancellation.
#include <transit/catalog.hpp>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <pthread.h>
#include <thread>
namespace cat = transit::sdk::station::catalog;
namespace sdk = transit::sdk;
namespace logical = transit::sdk::logical;
namespace fs = std::filesystem;
using namespace std::chrono_literals;
static void ok(transit_sdk_error e) { if (e.kind) std::cerr << e.kind << " " << e.phase << " " << e.code << std::endl; assert(!e.kind); }
static sdk::Bytes read(const fs::path &p) { std::ifstream f(p, std::ios::binary); assert(f); return {std::istreambuf_iterator<char>(f), {}}; }
template<class F> static void wait(F condition) { auto deadline = std::chrono::steady_clock::now() + 10s; while (!condition()) { assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(10ms); } }
struct Waiting { transit_station_catalog_client *client; const transit_station_catalog_reference *reference; };
static void *execute_thread(void *raw) {
    const auto &v = *static_cast<Waiting *>(raw); transit_station_catalog_observation *out = nullptr;
    ok(transit_station_catalog_execute(v.client, v.reference, 32, &out)); transit_station_catalog_observation_destroy(out); pthread_testcancel(); return nullptr;
}
int main(int argc, char **argv) {
    assert(argc == 2); const fs::path root(argv[1]); const auto directory = (root / "native").string(), seed = (root / "seed").string();
    auto config = transit_sdk_growing_config("http://127.0.0.1:9"); config.timeout_ms = 1000; config.native_directory = directory.c_str();
    const transit_sdk_credential identity{46, 17, seed.c_str()}; const transit_station_catalog_connection connection{{{46, 7}, UINT64_MAX}, 3, 1, true, 23};
    transit_station_catalog_client *client = nullptr; ok(transit_station_catalog_open(&config, &identity, connection, nullptr, &client));
    auto reference = cat::Reference::restore(read(root / "reference.json")); auto basis = cat::Basis::restore(read(root / "basis.json")); auto cursor = cat::Cursor::restore(read(root / "cursor.json"));
    auto acquisition = cat::SnapshotAcquisition::restore(read(root / "acquisition.json")); auto snapshot = cat::Snapshot::restore(read(root / "snapshot.json")); const auto original = reference.save();
    std::string command;
    while (std::cin >> command) {
        transit_sdk_error result{};
        if (command == "describe") {
            transit_station_catalog_description out{}; result = transit_station_catalog_describe(client, &out);
            if (!result.kind) assert(out.subject.principal == 17 && out.subject.role == 23 && out.subject.context[31] == 171 && out.policy_revision == 9 && out.configuration.authority.table_domain == 3 && out.configuration.authority.stream_domain == 31 && out.configuration.authority.queue_domain == 32 && out.configuration.authority.kv_domain == 33);
        } else if (command == "lookup" || command == "wrong_name") {
            transit_station_catalog_metadata *out = nullptr; result = transit_station_catalog_lookup(client, command == "lookup" ? "items" : "wrong", 1, &out);
            if (!result.kind && out) {
                const transit_station_catalog_metadata_view *v = nullptr; ok(transit_station_catalog_metadata_get(out, &v)); const transit_station_catalog_basis_view *b = nullptr; ok(transit_station_catalog_basis_get(v->basis, &b));
                assert(b->interpretation.content.bytes == 300 && b->interpretation.content.sha256[31] == 171 && b->interpretation.interpretation.object.object == UINT64_MAX && v->schema.columns[0].type->kind == TRANSIT_LOGICAL_INT128);
                assert(v->schema.columns[0].encoding == TRANSIT_CATALOG_RLE && v->schema.columns[1].encoding == TRANSIT_CATALOG_EBCDIC && v->schema.columns[1].collation == TRANSIT_CATALOG_EBCDIC_CP037);
            } else assert(!out); transit_station_catalog_metadata_destroy(out);
        } else if (command == "list" || command == "list_next" || command == "empty_next") {
            transit_station_catalog_table_page *out = nullptr; result = transit_station_catalog_tables(client, 1, command == "list" ? nullptr : cursor.native(), &out);
            if (!result.kind && command == "empty_next") { const transit_station_catalog_table_page_view *v = nullptr; ok(transit_station_catalog_table_page_get(out, &v)); assert(!v->count && v->next); }
            else if (result.kind) assert(!out); transit_station_catalog_table_page_destroy(out);
        } else if (command == "prepare" || command == "oversize") {
            const auto cell = logical::Cell::atom(logical::Atom::binary(sdk::Bytes(command == "prepare" ? 300000 : 1048576, 0)));
            std::vector<transit_station_catalog_assignment> assignments(command == "prepare" ? 1 : 128);
            for (size_t i = 0; i < assignments.size(); ++i) assignments[i] = {i + 1, &cell.native()};
            std::vector<transit_station_catalog_assignments> rows(command == "prepare" ? 1 : 1024, {assignments.data(), assignments.size()});
            transit_station_catalog_request request{}; request.name = "items"; request.identity = {10, 1}; request.action.kind = TRANSIT_CATALOG_INSERT; request.action.ingestion = TRANSIT_CATALOG_BULK; request.action.as.insert = {basis.native(), rows.data(), rows.size()};
            transit_station_catalog_compiled *out = nullptr; result = transit_station_catalog_prepare(client, &request, &out);
            if (!result.kind) { const transit_station_catalog_intent *i = nullptr; const transit_station_catalog_saved_intent *s = nullptr; ok(transit_station_catalog_compiled_get(out, &i, &s)); transit_sdk_bytes data{}; ok(transit_station_catalog_saved_intent_export(s, &data)); assert(data.size > 600000); }
            else assert(!out); transit_station_catalog_compiled_destroy(out);
        } else if (command == "physical_create" || command == "physical_alter" || command == "physical_invalid") {
            const auto type = logical::Type::scalar(TRANSIT_LOGICAL_UTF8); const transit_station_catalog_column column{1, "text", &type.native(), true, nullptr, 0, TRANSIT_CATALOG_EBCDIC, TRANSIT_CATALOG_EBCDIC_CP037}; const transit_station_catalog_schema schema{UINT64_MAX, 1, 2, &column, 1, nullptr, 0};
            transit_station_catalog_request request{}; request.name = "items"; request.identity = {10, 1};
            if (command == "physical_create") { request.action.kind = TRANSIT_CATALOG_CREATE; request.action.as.create = {&schema, false}; }
            else { request.action.kind = TRANSIT_CATALOG_ALTER; request.action.as.alter.basis = basis.native(); request.action.as.alter.change.kind = TRANSIT_CATALOG_PHYSICAL; request.action.as.alter.change.column = 1; request.action.as.alter.change.as.physical = {command == "physical_invalid" ? UINT32_MAX : TRANSIT_CATALOG_FSST, TRANSIT_CATALOG_ASCII_CI}; }
            transit_station_catalog_compiled *out = nullptr; result = transit_station_catalog_prepare(client, &request, &out); transit_station_catalog_compiled_destroy(out);
        } else if (command == "execute" || command == "inspect") {
            transit_station_catalog_observation *out = nullptr;
            result = command == "execute" ? transit_station_catalog_execute(client, reference.native(), 32, &out) : transit_station_catalog_inspect(client, reference.native(), &out);
            if (!result.kind) { const transit_station_catalog_observation_view *v = nullptr; ok(transit_station_catalog_observation_get(out, &v)); assert(v->state == TRANSIT_CATALOG_COMMITTED && v->commit.affected == 9 && v->commit.position.next_lsn == UINT64_MAX); }
            else assert(!out); transit_station_catalog_observation_destroy(out);
        } else if (command == "acquire") {
            transit_station_catalog_snapshot *out = nullptr; result = transit_station_catalog_acquire_snapshot(client, acquisition.native(), &out); if (result.kind) assert(!out); transit_station_catalog_snapshot_destroy(out);
        } else if (command == "metadata") {
            transit_station_catalog_snapshot_metadata *out = nullptr; result = transit_station_catalog_snapshot_metadata_read(client, snapshot.native(), &out);
            if (!result.kind) { const transit_station_catalog_snapshot_metadata_view *v = nullptr; ok(transit_station_catalog_snapshot_metadata_get(out, &v)); assert(v->row_count == 9 && v->schema.column_count == 2 && v->accepted.next_lsn == UINT64_MAX); } else assert(!out);
            transit_station_catalog_snapshot_metadata_destroy(out);
        } else if (command == "release") result = transit_station_catalog_release_snapshot(client, snapshot.native());
        else if (command == "restore_reference" || command == "restore_basis" || command == "restore_saved") {
            const auto data = read(root / "response");
            if (command == "restore_reference") { transit_station_catalog_reference *out = nullptr; result = transit_station_catalog_reference_restore(sdk::bytes_view(data), &out); transit_station_catalog_reference_destroy(out); }
            else if (command == "restore_basis") { transit_station_catalog_basis *out = nullptr; result = transit_station_catalog_basis_restore(sdk::bytes_view(data), &out); transit_station_catalog_basis_destroy(out); }
            else { transit_station_catalog_saved_intent *out = nullptr; result = transit_station_catalog_saved_intent_restore(sdk::bytes_view(data), &out); transit_station_catalog_saved_intent_destroy(out); }
        } else if (command == "cpp_lookup" || command == "cpp_execute") {
            try {
                auto settings = sdk::ClientConfig::growing("http://127.0.0.1:9"); settings.native_directory(directory);
                auto cpp = cat::Client::open(settings, sdk::Credential{46, 17, seed}, {{sdk::ResourceRef(46, 7), UINT64_MAX}, 3, 1, 23});
                if (command == "cpp_lookup") { auto v = cpp.lookup("items"); cpp.close(); assert(v && v->basis().interpretation().content.bytes == 300 && v->schema().columns[0].name == "id" && v->schema().columns[1].collation == cat::Collation::EbcdicCp037); }
                else { auto v = cpp.execute(reference, 32); assert(v.commit()->affected == 9); }
            } catch (const cat::Uncertain &e) { assert(std::visit([](const auto &v) { return v.save(); }, e.original()) == original); result = e.failure(); }
            catch (const sdk::Error &e) { result = e.detail(); }
        } else if (command == "block") {
            Waiting work{client, reference.native()}; pthread_t caller; assert(!pthread_create(&caller, nullptr, execute_thread, &work)); wait([&] { return fs::exists(root / "entered"); }); assert(!pthread_cancel(caller));
            transit_station_catalog_capabilities caps{}; assert(transit_station_catalog_capabilities_read(client, &caps).kind == TRANSIT_SDK_BUSY);
            std::atomic<bool> closed{false}; std::thread closer([&] { ok(transit_station_catalog_close(client)); closed = true; }); std::this_thread::sleep_for(100ms); assert(!closed); std::ofstream(root / "release") << "1";
            void *status = nullptr; assert(!pthread_join(caller, &status) && status == PTHREAD_CANCELED); closer.join(); assert(closed && transit_station_catalog_capabilities_read(client, &caps).kind == TRANSIT_SDK_CLOSED);
        } else { assert(command == "close"); break; }
        assert(reference.save() == original); std::cout << static_cast<unsigned>(result.kind) << std::endl;
    }
    ok(transit_station_catalog_close(client)); transit_station_catalog_client_destroy(client);
}

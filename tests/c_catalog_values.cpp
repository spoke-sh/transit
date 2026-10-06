// Installed public C/C++ APIs against a forwarding native-library fault fixture.
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

static void ok(transit_sdk_error e) { assert(e.kind == TRANSIT_SDK_OK); }
template<class F> static void wait(F condition) {
    auto deadline = std::chrono::steady_clock::now() + 10s;
    while (!condition()) { assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(10ms); }
}
struct Waiting { transit_station_catalog_client *client; transit_station_catalog_prepared *prepared; };
static void *submit_thread(void *raw) {
    auto &v = *static_cast<Waiting *>(raw); uint64_t position = 0;
    ok(transit_station_catalog_submit(v.client, v.prepared, &position));
    pthread_testcancel(); return nullptr;
}
int main(int argc, char **argv) {
    assert(argc == 2); const fs::path root(argv[1]);
    const auto directory = (root / "native").string(), seed = (root / "seed").string();
    auto config = transit_sdk_growing_config("http://127.0.0.1:9"); config.timeout_ms = 1000; config.native_directory = directory.c_str();
    const transit_sdk_credential identity{46, 17, seed.c_str()};
    const transit_station_catalog_connection connection{{46, 3}, {{46, 7}, UINT64_MAX}};
    transit_station_catalog_client *client = nullptr; ok(transit_station_catalog_open(&config, &identity, connection, &client));
    const std::string original = "opaque fixture command";
    transit_station_catalog_prepared *prepared = nullptr;
    ok(transit_station_catalog_prepared_import({reinterpret_cast<const uint8_t *>(original.data()), original.size()}, &prepared));
    std::string command;
    while (std::cin >> command) {
        transit_sdk_error result{};
        if (command == "lookup" || command == "wrong_name") {
            transit_station_catalog_definition *out = nullptr;
            result = transit_station_catalog_lookup(client, command == "lookup" ? "items" : "wrong", &out);
            if (result.kind == TRANSIT_SDK_OK && out) {
                const transit_station_catalog_definition_view *v = nullptr; ok(transit_station_catalog_definition_get(out, &v));
                assert(v->metadata.object == UINT64_MAX && v->metadata.revision == UINT64_MAX && v->schema.columns[0].type->kind == TRANSIT_LOGICAL_INT128);
            } else assert(!out);
            transit_station_catalog_definition_destroy(out);
        } else if (command == "history" || command == "wrong_history") {
            transit_station_catalog_historical *out = nullptr;
            result = transit_station_catalog_definition_read(client, UINT64_MAX, command == "history" ? UINT64_MAX : 1, &out);
            if (result.kind != TRANSIT_SDK_OK) assert(!out);
            transit_station_catalog_historical_destroy(out);
        } else if (command == "list" || command == "list_next" || command == "empty_next") {
            transit_station_catalog_cursor cursor{}; std::strcpy(cursor.definition, TRANSIT_SDK_STATION_DEFINITION);
            cursor.scope = connection.scope; cursor.resource_revision = 9; cursor.after_object = command == "empty_next" ? 8 : UINT64_MAX;
            transit_station_catalog_page out{};
            result = transit_station_catalog_list(client, command == "list" ? nullptr : &cursor, &out);
            if (result.kind == TRANSIT_SDK_OK && command == "empty_next") assert(!out.count && out.has_next && out.next.after_object == 9);
        } else if (command == "prepare" || command == "oversize") {
            const auto cell = logical::Cell::atom(logical::Atom::binary(sdk::Bytes(command == "prepare" ? 300000 : 1048576, 0)));
            std::vector<transit_station_catalog_assignment> assignments(command == "prepare" ? 1 : 128);
            for (size_t i = 0; i < assignments.size(); ++i) assignments[i] = {i + 1, &cell.native()};
            std::vector<transit_station_catalog_assignments> rows(command == "prepare" ? 1 : 1024, {assignments.data(), assignments.size()});
            transit_station_catalog_request request{}; request.name = "items"; request.identity = {10, 100}; request.action.kind = TRANSIT_CATALOG_INSERT;
            request.action.as.insert = {{1, 1, {}}, rows.data(), rows.size()};
            transit_station_catalog_compiled *out = nullptr; result = transit_station_catalog_prepare(client, &request, &out);
            if (result.kind == TRANSIT_SDK_OK) {
                transit_station_catalog_intent intent{}; const transit_station_catalog_saved_intent *saved = nullptr;
                ok(transit_station_catalog_compiled_get(out, &intent, &saved)); const char *definition = nullptr; transit_sdk_bytes data{};
                ok(transit_station_catalog_saved_get(saved, &definition, &data)); assert(data.size == 300000 && data.data[0] == 0xab && std::strcmp(definition, TRANSIT_SDK_STATION_DEFINITION) == 0);
            } else assert(!out);
            transit_station_catalog_compiled_destroy(out);
        } else if (command == "submit") {
            uint64_t position = 99; result = transit_station_catalog_submit(client, prepared, &position);
            assert(position == (result.kind == TRANSIT_SDK_OK ? 7 : 0));
            if (result.kind == TRANSIT_SDK_ACCESS_DENIED) assert(result.has_native_status && result.native_status == 4 && std::strcmp(result.code, "CatalogDenied") == 0);
        } else if (command == "cpp_lookup" || command == "cpp_submit") {
            try {
                auto settings = sdk::ClientConfig::growing("http://127.0.0.1:9"); settings.native_directory(directory);
                auto cpp = cat::Client::open(settings, sdk::Credential{46, 17, seed}, {sdk::ProcessRef(46, 3), {sdk::ResourceRef(46, 7), UINT64_MAX}});
                if (command == "cpp_lookup") { auto v = cpp.lookup("items"); cpp.close(); assert(v && v->metadata.object == UINT64_MAX && v->schema.columns[0].name == "id"); }
                else { auto p = cat::Prepared::recover(sdk::Bytes(original.begin(), original.end())); assert(cpp.submit(p) == 7); }
            } catch (const sdk::Error &e) { result = e.detail(); }
        } else if (command == "block") {
            Waiting work{client, prepared}; pthread_t caller; assert(!pthread_create(&caller, nullptr, submit_thread, &work));
            wait([&] { return fs::exists(root / "entered"); }); assert(!pthread_cancel(caller));
            transit_station_catalog_capabilities caps{}; assert(transit_station_catalog_capabilities_read(client, &caps).kind == TRANSIT_SDK_BUSY);
            std::atomic<bool> closed{false}; std::thread closer([&] { ok(transit_station_catalog_close(client)); closed = true; });
            std::this_thread::sleep_for(100ms); assert(!closed); std::ofstream(root / "release") << "1";
            void *status = nullptr; assert(!pthread_join(caller, &status) && status == PTHREAD_CANCELED); closer.join(); assert(closed);
            assert(transit_station_catalog_capabilities_read(client, &caps).kind == TRANSIT_SDK_CLOSED);
        } else { assert(command == "close"); break; }
        transit_sdk_bytes retained{}; ok(transit_station_catalog_prepared_bytes(prepared, &retained));
        assert(retained.size == original.size() && std::memcmp(retained.data, original.data(), original.size()) == 0);
        std::cout << static_cast<unsigned>(result.kind) << std::endl;
    }
    ok(transit_station_catalog_close(client)); transit_station_catalog_client_destroy(client); transit_station_catalog_prepared_destroy(prepared);
}

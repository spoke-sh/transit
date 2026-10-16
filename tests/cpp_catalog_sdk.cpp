/* Installed C++17 general Table lifecycle through the public typed facade. */
#include "catalog_sdk_io.h"
#include <transit/catalog.hpp>
using namespace transit::sdk;
namespace cat = transit::sdk::station::catalog;
namespace logical = transit::sdk::logical;
static cat::Identity id(uint64_t base, uint64_t offset) { return {base + offset, base + offset + 100000}; }
static cat::Outcome finish(cat::Client &client, const cat::Compiled &compiled, const char *root) {
    const auto intent = compiled.intent(); auto saved = compiled.saved(); persist_saved(root, saved.native()); const double deadline = now() + 120;
    for (;;) {
        assert(now() < deadline); auto next = client.next(intent.reference);
        if (next.kind == cat::NextKind::Terminal) return *next.outcome;
        if (next.kind == cat::NextKind::Running) continue;
        assert(next.kind == cat::NextKind::Send && next.prepared); const auto bytes = next.prepared->data(); persist(root, "step.json", bytes_view(bytes));
        const auto position = client.submit(*next.prepared); persist_receipt(root, position);
        for (;;) {
            assert(now() < deadline); auto progress = client.progress(intent.reference, *next.prepared, position, true);
            if (progress.observation == cat::Observation::Pending) continue;
            assert(!progress.disposition); if (progress.state.outcome && progress.state.outcome->terminal) return *progress.state.outcome; break;
        }
    }
}
static bool equal(const cat::Outcome &a, const cat::Outcome &b) {
    return a.kind == b.kind && a.operation == b.operation && a.object == b.object && a.actual_object == b.actual_object && a.phase == b.phase && a.terminal == b.terminal &&
        a.admitted_input == b.admitted_input && a.completed_input == b.completed_input && a.diagnostic == b.diagnostic && bool(a.counts) == bool(b.counts) &&
        (!a.counts || (a.counts->matched == b.counts->matched && a.counts->changed == b.counts->changed));
}
static void values() {
    Bytes original{1, 2}; auto prepared = cat::Prepared::recover(original); original[0] = 0; assert(prepared.data()[0] == 1);
    auto moved = std::move(prepared); bool rejected = false; try { prepared.data(); } catch (const Error &e) { rejected = e.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT; } assert(rejected && moved.data()[0] == 1);
    Bytes large(300000, 9); auto saved = cat::SavedIntent::recover(TRANSIT_SDK_STATION_DEFINITION, large); large.clear(); assert(saved.data().size() == 300000 && saved.data()[299999] == 9);
    rejected = false; try { cat::SavedIntent::recover(std::string(64, '0'), {1}); } catch (const Error &e) { rejected = e.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT; } assert(rejected);
}
static void scenario(cat::Client &client, const ClientConfig &config, const Credential &credential, const cat::Connection &connection, const char *root, uint64_t index, const std::optional<std::string> &service) {
    const uint64_t base = 1100 + index * 100, object = 12001 + index * 10; const auto name = "sdk_people_" + std::to_string(index);
    assert(client.capabilities().max_columns == 128); assert(client.describe().configuration.scope.catalog == connection.scope.catalog);
    auto create = client.compile_sql("CREATE TABLE " + name + " (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))", id(base, 0), object);
    assert(finish(client, create, root).phase == cat::Phase::Applied);
    auto original = client.lookup(name); assert(original && original->schema.columns.size() == 3 && original->schema.columns[1].type.kind() == TRANSIT_LOGICAL_STRUCTURE);
    auto source = cat::basis(original->metadata);
    auto payload = logical::Cell::structure({logical::Cell::atom(logical::Atom::binary({0, 128, 255})), logical::Cell::atom(logical::Atom::utf8("東京"))});
    auto amount = logical::Cell::atom(logical::Atom::decimal(logical::Int128{UINT64_C(14083847773837265618), INT64_C(6692605942)}));
    auto key = logical::Cell::atom(logical::Atom::signed_integer(1));
    auto insert = client.prepare(name, id(base, 1), cat::Insert{source, {{{3, amount}, {1, key}, {2, payload}}}});
    const auto applied = finish(client, insert, root); assert(applied.counts && applied.counts->matched == 1 && applied.counts->changed == 1);
    cat::Predicate predicate{cat::Compare{1, cat::CompareOp::Eq, logical::Atom::signed_integer(1)}};
    auto update = client.prepare(name, id(base, 2), cat::Update{source, {{3, amount}}, predicate}); const auto unchanged = finish(client, update, root);
    assert(unchanged.counts && unchanged.counts->matched == 1 && unchanged.counts->changed == 0);
    auto alter = client.prepare(name, id(base, 3), cat::Alter{source, cat::AddColumn{"enabled", logical::Type::scalar(TRANSIT_LOGICAL_BOOLEAN), false, logical::Cell::atom(logical::Atom::boolean(true)), {}}});
    assert(finish(client, alter, root).phase == cat::Phase::Applied);
    bool rejected = false; try { client.prepare(name, id(base, 4), cat::Drop{source, false}); } catch (const Error &) { rejected = true; } assert(rejected);
    source = cat::basis(client.lookup(name)->metadata);
    auto remove = client.prepare(name, id(base, 5), cat::Delete{source, predicate}); const auto removed = finish(client, remove, root);
    assert(removed.counts && removed.counts->matched == 1 && removed.counts->changed == 1);
    auto drop = client.prepare(name, id(base, 6), cat::Drop{source, false}); assert(finish(client, drop, root).phase == cat::Phase::Applied);
    cat::Schema schema{object + 1, 1, 2, {{1, "replacement", logical::Type::scalar(TRANSIT_LOGICAL_UTF8), true, {}, {}}}, {}};
    auto replacement = client.prepare(name, id(base, 7), cat::Create{schema, false}); schema.columns.clear(); assert(finish(client, replacement, root).phase == cat::Phase::Applied);
    auto saved = insert.saved(); const auto intent = insert.intent(); client.close();
    auto fresh = cat::Client::open(config, credential, connection, service); const auto loaded = fresh.load(saved); assert(loaded.object == object && loaded.reference.digest == intent.reference.digest);
    const auto state = fresh.status(loaded.reference); assert(state.outcome && equal(applied, *state.outcome)); assert(fresh.lookup(name)->metadata.object == object + 1);
    auto history = fresh.definition(object, original->metadata.revision); assert(history && history->metadata.object == object && history->metadata.revision == original->metadata.revision && history->metadata.schema_fingerprint == original->metadata.schema_fingerprint);
    assert(history->schema.columns.size() == original->schema.columns.size());
    for (size_t i = 0; i < history->schema.columns.size(); ++i) assert(history->schema.columns[i].type.encode() == original->schema.columns[i].type.encode());
    assert(!fresh.definition(object, 999)); assert(!fresh.list().entries.empty()); fresh.close();
    assert(history->schema.columns[1].type.fields().size() == 2 && saved.data().size() > 0);
    printf("{\"status\":0,\"value\":{\"profile\":\"installed-cpp-general-table\",\"original_object\":\"%llu\",\"replacement_object\":\"%llu\",\"counts\":{\"matched\":\"1\",\"changed\":\"1\"}}}\n", (unsigned long long)object, (unsigned long long)(object + 1));
}
int main(int argc, char **argv) {
    assert(argc == 12); setvbuf(stdout, nullptr, _IOLBF, 0); values();
    const auto realm = number(argv[3]); auto config = ClientConfig::growing(argv[1]).timeout(argv[9][0] ? 30000 : 10000); Credential credential(realm, number(argv[4]), argv[2]);
    cat::Connection connection{ProcessRef(realm, number(argv[5])), {ResourceRef(realm, number(argv[6])), number(argv[7])}};
    const std::optional<std::string> service = argv[9][0] ? std::optional<std::string>(argv[9]) : std::nullopt;
    if (number(argv[10])) connection.role = number(argv[10]);
    connection.namespace_id = number(argv[11]);
    try {
        auto client = cat::Client::open(config, credential, connection, service); puts("{\"ready\":true}");
        while (read_command() && strcmp(args[0], "close")) {
            if (!strcmp(args[0], "denied")) {
                auto fresh = cat::Client::open(config, credential, connection, service);
                bool denied = false; try { fresh.describe(); } catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_ACCESS_DENIED); denied = true; }
                assert(denied); fresh.close(); puts("{\"status\":0,\"value\":{\"denied\":true}}"); continue;
            }
            assert(!strcmp(args[0], "scenario")); scenario(client, config, credential, connection, argv[8], number(args[1]), service); }
        client.close(); puts("{\"closed\":true}");
    } catch (const Error &e) { checked(e.detail()); }
}

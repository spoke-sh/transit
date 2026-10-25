/* Installed C++17 direct lifecycle through the owning public facade. */
#include "catalog_sdk_io.h"
#include <transit/catalog.hpp>
using namespace transit::sdk;
namespace cat = transit::sdk::station::catalog;
namespace logical = transit::sdk::logical;
static const char *directory;
static const uint64_t base = 10, object = UINT64_MAX - 11;
static const std::string name = "cpp_items";
template<class T> static void save(const T &v, const char *file) { const auto data = v.save(); persist(directory, file, bytes_view(data)); }
template<class T> static T load(const char *file) { const auto data = read_saved(directory, file); Bytes owned(data.data, data.data + data.size); free(const_cast<uint8_t *>(data.data)); return T::restore(owned); }
template<class T, class F> static void expect_uncertain(const T &value, F work) {
    const auto before = value.save(); bool unknown = false;
    try { work(); } catch (const cat::Uncertain &error) { uncertain(error.failure()); assert(std::visit([](const auto &v) { return v.save(); }, error.original()) == before); unknown = true; }
    assert(unknown && value.save() == before);
}
static cat::Commit finish(cat::Client &client, const cat::Compiled &work) {
    save(work.saved(), "work.json"); const auto reference = client.stage(work.intent()); save(reference, "work-reference.json"); auto observation = client.admit(reference);
    for (unsigned i = 0; i < 16 && observation.state() == cat::OperationState::Admitted; ++i) observation = client.execute(reference, 32);
    assert(observation.state() == cat::OperationState::Committed && observation.commit()); return *observation.commit();
}
int main(int argc, char **argv) {
    assert(argc == 12 && !strcmp(argv[1], "cpp")); directory = argv[9]; setvbuf(stdout, nullptr, _IOLBF, 0);
    auto config = ClientConfig::growing(argv[2]).timeout(10000); const Credential credential(number(argv[4]), number(argv[5]), argv[3]);
    const cat::Connection connection{{ResourceRef(number(argv[4]), number(argv[7])), number(argv[8])}, number(argv[6]), 1, number(argv[11])};
    try {
        auto client = cat::Client::open(config, credential, connection, argv[10]);
        auto compile = [&](const std::string &sql, uint64_t operation, std::optional<uint64_t> create = {}) { return client.compile_sql(sql, {base + operation, 1}, create); };
        puts("{\"ready\":true}");
        while (read_command() && strcmp(args[0], "close")) {
            const std::string command(args[0]);
            if (command == "prepare") {
                assert(client.describe().subject.principal == number(argv[5])); assert(std::string(client.namespace_read(1)->name) == "public" && client.namespaces().entries()[0].id == 1);
                finish(client, compile("CREATE TABLE " + name + " (id BIGINT PRIMARY KEY, payload BINARY)", 1, object));
                auto current = client.lookup(name); assert(current && current->row_count() == 0 && current->basis().interpretation().interpretation.object.object == object);
                std::vector<std::vector<cat::Assignment>> rows;
                for (int i = 0; i < 9; ++i) rows.push_back({{1, logical::Cell::atom(logical::Atom::signed_integer(i))}, {2, logical::Cell::atom(logical::Atom::binary(Bytes(32768, static_cast<uint8_t>(i))))}});
                auto work = client.prepare(name, {base + 2, 1}, cat::Insert{current->basis(), std::move(rows), cat::Ingestion::Bulk});
                assert(client.preview(work.intent()).view().current.row_count == 0); save(work.saved(), "intent.json"); auto loaded = client.load(load<cat::SavedIntent>("intent.json")); auto original = client.stage(loaded); save(original, "original.json");
                assert(client.admit(original).state() == cat::OperationState::Admitted); expect_uncertain(original, [&] { client.execute(original, 32); }); puts("{\"status\":0,\"value\":{\"uncertain\":true}}");
            } else if (command == "recover") {
                auto original = load<cat::Reference>("original.json"); auto observed = client.inspect(original); assert(observed.state() == cat::OperationState::Committed); const auto commit = *observed.commit(); assert(commit.matched == 9 && commit.affected == 9 && commit.live_rows == 9);
                auto replay = client.execute(original, 32); assert(replay.commit()->position.next_lsn == commit.position.next_lsn && replay.commit()->affected == 9);
                auto current = client.lookup(name); auto acquisition = client.prepare_snapshot(*current, 90000 + base); save(current->basis(), "basis.json"); save(acquisition, "acquisition.json"); expect_uncertain(acquisition, [&] { client.acquire_snapshot(acquisition); }); puts("{\"status\":0,\"value\":{\"retention_uncertain\":true}}");
            } else if (command == "retained") {
                const auto acquisition = load<cat::SnapshotAcquisition>("acquisition.json"); auto status = client.snapshot_status(acquisition.owner()); assert(!status.released() && status.snapshot()); auto snapshot = *std::move(status.snapshot()); save(snapshot, "snapshot.json");
                auto metadata = client.snapshot_metadata(snapshot); assert(metadata.accepted().partition == acquisition.expected().partition && metadata.accepted().next_lsn == acquisition.expected().next_lsn && metadata.row_count() == 9 && metadata.schema().columns.size() == 2); puts("{\"status\":0,\"value\":{\"retained\":true}}");
            } else if (command == "denied") {
                bool denied = false; try { client.snapshot_metadata(load<cat::Snapshot>("snapshot.json")); } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_ACCESS_DENIED && error.detail().native_status == 4); denied = true; }
                assert(denied); puts("{\"status\":0,\"value\":{\"denied\":true}}");
            } else if (command == "metadata") {
                auto metadata = client.snapshot_metadata(load<cat::Snapshot>("snapshot.json")); auto basis = load<cat::Basis>("basis.json"); const auto actual = metadata.interpretation(), expected = basis.interpretation(); assert(actual.interpretation.revision == expected.interpretation.revision && !memcmp(actual.content.sha256, expected.content.sha256, 32));
                assert(metadata.row_count() == 9 && metadata.schema().columns.size() == 2); puts("{\"status\":0,\"value\":{\"rows\":9,\"columns\":2}}");
            } else if (command == "retire") {
                auto changed = finish(client, compile("UPDATE " + name + " SET id=0 WHERE id=0", 3)); assert(changed.matched == 1 && changed.affected == 0);
                changed = finish(client, compile("DELETE FROM " + name + " WHERE id=8", 4)); assert(changed.matched == 1 && changed.affected == 1); auto old = client.lookup(name);
                finish(client, client.prepare(name, {base + 5, 1}, cat::Alter{old->basis(), cat::AddColumn{"extra", logical::Type::scalar(TRANSIT_LOGICAL_INT64), true, {}, {}}}));
                bool stale = false; try { client.prepare(name, {base + 55, 1}, cat::Drop{old->basis(), false}); } catch (const Error &error) { assert(std::string(error.detail().code) == "TableDefinitionChanged"); stale = true; } assert(stale);
                finish(client, compile("ALTER TABLE " + name + " RENAME TO " + name + "_old", 6)); finish(client, compile("DROP TABLE " + name + "_old", 7)); finish(client, compile("CREATE TABLE " + name + " (replacement BIGINT)", 8, object - 1)); assert(client.lookup(name)->basis().interpretation().interpretation.object.object == object - 1); puts("{\"status\":0,\"value\":{\"original\":true}}");
            } else if (command == "release") {
                auto snapshot = load<cat::Snapshot>("snapshot.json"); assert(!client.snapshot_status(snapshot.owner()).released()); expect_uncertain(snapshot, [&] { client.release_snapshot(snapshot); }); puts("{\"status\":0,\"value\":{\"release_uncertain\":true}}");
            } else if (command == "verify") {
                auto snapshot = load<cat::Snapshot>("snapshot.json"); assert(client.snapshot_status(snapshot.owner()).released()); client.release_snapshot(snapshot); auto original = load<cat::Reference>("original.json"); assert(client.inspect(original).commit()->affected == 9);
                assert(client.load(load<cat::SavedIntent>("intent.json")).identity().operation == base + 2); assert(client.lookup(name)->basis().interpretation().interpretation.object.object == object - 1); assert(!client.tables().entries().empty()); puts("{\"status\":0,\"value\":{\"recovered\":true}}");
            } else assert(false);
        }
        client.close(); puts("{\"closed\":true}");
    } catch (const Error &error) { checked(error.detail()); }
    return 0;
}

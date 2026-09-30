#include <transit/sdk_examples.hpp>
#include <atomic>
#include <cassert>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <thread>
#include <fcntl.h>
#include <unistd.h>
using namespace transit::sdk;
using namespace transit::sdk::station;
using namespace transit::sdk::examples;
using namespace std::chrono_literals;
namespace fs = std::filesystem;
struct Config {
    std::string mode, url, seed, role, pending, output, fixtures, wrong;
    uint64_t realm, principal, pid, generation, peer, resource;
    bool queries;
    explicit Config(char **a) : mode(a[1]), url(a[2]), seed(a[7]), role(a[9]), pending(a[11]), output(a[12]), fixtures(a[13]), wrong(a[15]),
        realm(std::stoull(a[3])), principal(std::stoull(a[4])), pid(std::stoull(a[5])), generation(std::stoull(a[6])), peer(std::stoull(a[8])), resource(std::stoull(a[10])), queries(std::string(a[14]) == "1") {}
    ServiceConfig service() const { auto client = ClientConfig::growing(url); client.timeout(3000); ServiceConfig value(client, ProcessRef(realm, pid), principal, generation, seed); value.query_results(queries); return value; }
};
static Bytes read_file(const std::string &path) {
    std::ifstream file(path, std::ios::binary); assert(file); return Bytes{std::istreambuf_iterator<char>(file), {}};
}
static void write_file(const std::string &path, const Bytes &bytes) {
    std::ofstream file(path, std::ios::binary); file.write(reinterpret_cast<const char *>(bytes.data()), bytes.size()); assert(file);
}
static void write_text(const std::string &path, const std::string &value) { write_file(path, Bytes(value.begin(), value.end())); }
static void wait_file(const std::string &path) {
    const auto deadline = std::chrono::steady_clock::now() + 30s;
    while (!fs::exists(path)) { assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(10ms); }
}
static void report(const std::string &value) { std::cout << value << std::endl; }
struct SavedSegment { transit_station_segment_info info; Bytes bytes; std::optional<IpcSegment> owner; };
struct Shared {
    size_t initialized = 0, handled = 0;
    std::string purpose;
    std::set<std::string> before_failed, confirm_failed, confirmations;
    std::map<std::string, Bytes> saved;
    std::optional<Turn> escaped;
    std::vector<SavedSegment> segments;
    std::function<void()> check_reentry;
};
class Store final : public RecoveryStore {
    const Config &cfg_;
    Shared &shared_;
public:
    Store(const Config &cfg, Shared &shared) : cfg_(cfg), shared_(shared) {}
    void before_dispatch(const FrozenMutation &mutation) override {
        auto info = mutation.info(); const std::string purpose = info.purpose == TRANSIT_MUTATION_PERMIT ? "permit" : info.purpose == TRANSIT_MUTATION_OPEN ? "open" : "commit";
        shared_.purpose = purpose;
        if (shared_.check_reentry) shared_.check_reentry();
        if (cfg_.mode == "gates" && shared_.before_failed.insert(purpose).second) {
            if (purpose == "permit") throw std::runtime_error("injected persistence exception");
            throw failure(TRANSIT_SDK_HANDLER_ERROR, "injected-persistence");
        }
        auto bytes = mutation.export_bytes(); auto [found, inserted] = shared_.saved.emplace(info.operation.identity, bytes); assert(inserted || found->second == bytes);
        int file = open(cfg_.pending.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600); assert(file >= 0);
        size_t offset = 0; while (offset < bytes.size()) { const auto count = write(file, bytes.data() + offset, bytes.size() - offset); assert(count > 0); offset += count; }
        assert(!fsync(file)); assert(!::close(file));
    }
    void confirmed(std::string_view identity, MutationReceipt receipt) override {
        assert(receipt.position && shared_.saved.count(std::string(identity)));
        if (cfg_.mode == "gates" && shared_.confirm_failed.insert(shared_.purpose).second) {
            if (shared_.purpose == "open") throw std::runtime_error("injected confirmation exception");
            throw failure(TRANSIT_SDK_HANDLER_ERROR, "injected-confirmation");
        }
        shared_.confirmations.insert(std::string(identity));
    }
};
static void before_initialize(Turn &turn, Shared &shared) { ++shared.initialized; assert(turn.budgets().mutations == 3); }
static bool before_handle(Turn &turn, const Config &cfg, Shared &shared) {
    ++shared.handled;
    bool foreign_rejected = false;
    std::thread foreign([&] { try { turn.info(); } catch (const Error &error) { foreign_rejected = error.detail().kind == TRANSIT_SDK_BUSY; } });
    foreign.join(); assert(foreign_rejected);
    shared.escaped = turn;
    if (cfg.mode == "poison") {
        try { turn.state().require(total_key); assert(false); } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_READ_FAILED); }
        return true; // Native and host poison must survive catching this read error.
    }
    if (cfg.mode == "invalid-thread") throw failure(TRANSIT_SDK_HANDLER_ERROR, "foreign-thread-handler");
    if (cfg.mode.rfind("handler-", 0) == 0 || cfg.mode.rfind("exception-", 0) == 0) {
        turn.state().put(total_key, uint64_t{73});
        if (cfg.mode.rfind("exception-", 0) == 0) throw std::runtime_error("injected handler exception");
        throw failure(TRANSIT_SDK_HANDLER_ERROR, "injected-handler");
    }
    return false;
}
static bool table_extra(Turn &turn, const Config &cfg, bool rows, bool initialize) {
    const auto saved = cfg.output + "/version.txt";
    if (rows) {
        auto table = turn.table(table_schema); std::optional<Cursor> cursor; size_t count = 0, pages = 0;
        do {
            auto page = table.page(cursor ? &*cursor : nullptr); assert(page.entries.size() <= 8); ++pages;
            assert(page.basis->resource.resource == table.basis().resource.resource && page.basis->revision == table.basis().revision);
            if (!count) { assert(page.entries.front().key == INT64_MIN && !page.entries.front().value); }
            count += page.entries.size(); cursor = std::move(page.next);
        } while (cursor);
        assert(count == 41 && pages == 6); const auto version = turn.retain();
        write_text(saved, std::to_string(version.pid) + " " + std::to_string(version.input) + " " + std::to_string(version.index));
        turn.table(table_schema).update({INT64_MIN, 17}); return true;
    }
    if (initialize && fs::exists(saved)) {
        ReadVersion version{}; unsigned index; std::ifstream file(saved); file >> version.pid >> version.input >> index; assert(file && index <= 255); version.index = index;
        assert(turn.table(table_schema).get(INT64_MIN)->value == 17);
        const auto source = turn.source(version); auto table = source.table(table_schema);
        assert(!table.get(INT64_MIN)->value); assert(table.page().entries.size() == 8); assert(source.state().page().entries.size() <= 8);
        turn.release(version); return true;
    }
    return false;
}
static void save_manifest(const Config &cfg, const Manifest &manifest) {
    write_text(cfg.output + "/manifest.json", "{\"rows\":" + std::to_string(manifest.rows) + ",\"segments\":" + std::to_string(manifest.segments) +
        ",\"correlation\":\"" + std::to_string(manifest.correlation) + "\",\"source\":" + std::to_string(manifest.source.pid) + ",\"destination\":" + std::to_string(manifest.destination.pid) +
        ",\"resource\":" + std::to_string(manifest.basis.resource.resource) + ",\"revision\":" + std::to_string(manifest.basis.revision) + ",\"bytes\":" + std::to_string(manifest.bytes) + "}");
    write_text(cfg.output + "/correlation.txt", std::to_string(manifest.correlation));
}
static bool query_extra(Turn &turn, const Config &cfg) {
    if (!fs::exists(cfg.output + "/manifest.json")) return false;
    uint64_t correlation; std::ifstream(cfg.output + "/correlation.txt") >> correlation;
    const auto reader = turn.result(correlation); assert(reader.manifest().rows == 41);
    write_text(cfg.output + "/ready", ""); wait_file(cfg.output + "/continue"); reader.segment(0); return true;
}
template<class M> class Instrumented : public Handler<M> {
    std::unique_ptr<Handler<M>> inner_;
    const Config &cfg_;
    Shared &shared_;
public:
    Instrumented(std::unique_ptr<Handler<M>> inner, const Config &cfg, Shared &shared) : inner_(std::move(inner)), cfg_(cfg), shared_(shared) {}
    void initialize(Turn &turn) override { before_initialize(turn, shared_); inner_->initialize(turn); }
    void handle(Turn &turn, const Incoming<M> &input) override {
        if (before_handle(turn, cfg_, shared_)) return;
        if constexpr (std::is_same_v<M, QueryMessage>) {
            if (auto cast = std::get_if<Cast<M>>(&input)) if (table_extra(turn, cfg_, std::holds_alternative<Rows>(cast->value), std::holds_alternative<Initialize>(cast->value))) return;
        }
        if constexpr (std::is_same_v<M, QueryStart>) if (query_extra(turn, cfg_)) return;
        inner_->handle(turn, input);
    }
    void handle_result(Turn &turn, const ResultComplete &complete) override {
        inner_->handle_result(turn, complete); save_manifest(cfg_, turn.result(complete.correlation).manifest());
    }
};
class Controller {
public:
    virtual ~Controller() = default;
    virtual Event next() = 0;
    virtual Event reconcile() = 0;
    virtual Event close() = 0;
    virtual void stop() = 0;
};
template<class M> class CppController final : public Controller {
    Runner<M> runner_;
public:
    CppController(const Config &cfg, Shared &shared, std::unique_ptr<Handler<M>> handler, std::shared_ptr<const Codec<M>> codec, std::shared_ptr<RecoveryStore> store)
        : runner_(Runner<M>::open(cfg.service(), std::make_unique<Instrumented<M>>(std::move(handler), cfg, shared), std::move(codec),
            RunnerOptions::persist(std::move(store), cfg.mode.size() >= 6 && cfg.mode.substr(cfg.mode.size() - 6) == "-block" ? FailurePolicy::BlockInput : FailurePolicy::Stop))) {}
    Event next() override { return runner_.next(); }
    Event reconcile() override { return runner_.reconcile(); }
    Event close() override { return runner_.close(); }
    void stop() override { runner_.stop(); }
};
// A shared C++ test controller also drives the C API directly. The C example
// callback library and installed transit-c-counter are compiled as C11.
class CController final : public Controller {
    const Config &cfg_;
    Shared &shared_;
    std::shared_ptr<RecoveryStore> store_;
    transit_example_peer peer_;
    transit_example_query_requester query_;
    transit_station_handler inner_;
    std::unique_ptr<transit_station_runner, decltype(&transit_station_runner_destroy)> runner_{nullptr, transit_station_runner_destroy};
public:
    CController(const Config &cfg, Shared &shared, std::shared_ptr<RecoveryStore> store) : cfg_(cfg), shared_(shared), store_(std::move(store)), peer_{{cfg.realm, cfg.peer}}, query_{peer_.peer, &shared, [](void *context, const transit_station_segment *segment) {
        return callback([&] { SavedSegment saved; check(transit_station_segment_inspect(segment, &saved.info)); transit_sdk_buffer bytes{};
            check(transit_station_segment_ipc(segment, &bytes)); saved.bytes = Buffer(bytes).copy(); static_cast<Shared *>(context)->segments.push_back(std::move(saved)); }); }} {
        transit_station_codec codec;
        if (cfg.role == "service") { inner_ = transit_example_counter_handler(); codec = transit_example_counter_codec(); }
        else if (cfg.role == "requester") { inner_ = transit_example_requester_handler(&peer_); codec = transit_example_requester_codec(); }
        else if (cfg.role == "table") { inner_ = transit_example_table_handler(&peer_); codec = transit_example_query_codec(); }
        else { inner_ = transit_example_query_requester_handler(&query_); codec = transit_example_query_start_codec(); }
        transit_station_handler handler{this,
            [](void *context, transit_station_turn *pointer) { return callback([&] { auto &self = *static_cast<CController *>(context); Turn turn(pointer); before_initialize(turn, self.shared_); if (self.inner_.initialize) check(self.inner_.initialize(self.inner_.context, pointer)); }); },
            [](void *context, transit_station_turn *pointer, const transit_station_incoming *input) { return callback([&] { auto &self = *static_cast<CController *>(context); Turn turn(pointer);
                if (before_handle(turn, self.cfg_, self.shared_)) return;
                if (self.cfg_.role == "table" && input->kind == TRANSIT_INPUT_CAST) { const auto &message = *static_cast<const transit_query_message *>(input->value); if (table_extra(turn, self.cfg_, message.tag == TRANSIT_QUERY_ROWS, message.tag == TRANSIT_QUERY_INITIALIZE)) return; }
                if (self.cfg_.role == "query" && query_extra(turn, self.cfg_)) return;
                check(self.inner_.message(self.inner_.context, pointer, input)); }); }, nullptr,
            [](void *context, transit_station_turn *pointer, const transit_station_incoming *input) { return callback([&] { auto &self = *static_cast<CController *>(context); assert(self.inner_.result); check(self.inner_.result(self.inner_.context, pointer, input)); Turn turn(pointer); save_manifest(self.cfg_, turn.result(input->correlation).manifest()); }); }};
        transit_station_options options{cfg.mode.size() >= 6 && cfg.mode.substr(cfg.mode.size() - 6) == "-block" ? TRANSIT_FAILURE_BLOCK_INPUT : TRANSIT_FAILURE_STOP, TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH, this,
            [](void *context, const transit_station_mutation *mutation) { return callback([&] { static_cast<CController *>(context)->store_->before_dispatch(FrozenMutation(mutation)); }); },
            [](void *context, const char *identity, transit_sdk_confirmation receipt) { return callback([&] { static_cast<CController *>(context)->store_->confirmed(identity, receipt); }); }};
        const auto settings = cfg.service(); const auto native = settings.native(); transit_station_runner *runner = nullptr;
        check(transit_station_runner_open(&native, &handler, &codec, &options, &runner)); runner_.reset(runner);
    }
    Event next() override { transit_station_event *event = nullptr; check(transit_station_runner_next(runner_.get(), &event)); return Event(event); }
    Event reconcile() override { transit_station_event *event = nullptr; check(transit_station_runner_reconcile(runner_.get(), &event)); return Event(event); }
    Event close() override { transit_station_event *event = nullptr; check(transit_station_runner_close(runner_.get(), &event)); return Event(event); }
    void stop() override { transit_station_runner_stop(runner_.get()); }
};
static std::unique_ptr<Controller> open_controller(const Config &cfg, Shared &shared, std::shared_ptr<RecoveryStore> store) {
#ifdef TRANSIT_TEST_C_API
    return std::make_unique<CController>(cfg, shared, std::move(store));
#else
    const ProcessRef peer(cfg.realm, cfg.peer);
    if (cfg.role == "service") return std::make_unique<CppController<CounterMessage>>(cfg, shared, std::make_unique<Counter>(), std::make_shared<CounterCodec>(), store);
    if (cfg.role == "requester") return std::make_unique<CppController<RequesterMessage>>(cfg, shared, std::make_unique<Requester>(peer), std::make_shared<RequesterCodec>(), store);
    if (cfg.role == "table") return std::make_unique<CppController<QueryMessage>>(cfg, shared, std::make_unique<TableService>(peer), std::make_shared<QueryCodec>(), store);
    return std::make_unique<CppController<QueryStart>>(cfg, shared, std::make_unique<QueryRequester>(peer, [&](IpcSegment segment) { const auto info = segment.info(); shared.segments.push_back({info, {}, std::move(segment)}); }), std::make_shared<QueryStartCodec>(), store);
#endif
}
static Bytes from_hex(const std::string &text) {
    if (text == "-") return {}; assert(text.size() % 2 == 0); Bytes out;
    for (size_t i = 0; i < text.size(); i += 2) out.push_back(static_cast<uint8_t>(std::stoul(text.substr(i, 2), nullptr, 16))); return out;
}
[[maybe_unused]] static Bytes c_roundtrip(transit_station_codec codec, const Bytes &bytes) {
    alignas(std::max_align_t) unsigned char value[64]{}; assert(codec.object_bytes <= sizeof(value));
    check(codec.decode(codec.context, bytes_view(bytes), value)); Bytes out(codec.max_encoded_bytes); size_t written = 0;
    check(codec.encode(codec.context, value, out.data(), out.size(), &written)); assert(written <= out.size()); out.resize(written); return out;
}
static Bytes roundtrip(const std::string &kind, const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    if (kind == "u64") return c_roundtrip(transit_example_u64_codec(), bytes);
    if (kind == "counter") { try { return c_roundtrip(transit_example_counter_codec(), bytes); } catch (const Error &) { return c_roundtrip(transit_example_requester_codec(), bytes); } }
    try { return c_roundtrip(transit_example_query_codec(), bytes); } catch (const Error &) { return c_roundtrip(transit_example_query_start_codec(), bytes); }
#else
    if (kind == "u64") return U64Codec{}.encode(U64Codec{}.decode(bytes));
    if (kind == "counter") { try { return CounterCodec{}.encode(CounterCodec{}.decode(bytes)); } catch (const Error &) { return RequesterCodec{}.encode(RequesterCodec{}.decode(bytes)); } }
    try { return QueryCodec{}.encode(QueryCodec{}.decode(bytes)); } catch (const Error &) { return QueryStartCodec{}.encode(QueryStartCodec{}.decode(bytes)); }
#endif
}
static void codecs(const Config &cfg) {
    assert(std::string(CounterCodec{}.type_id()) == "transit.examples.counter" && CounterCodec{}.version() == 1);
    assert(std::string(RequesterCodec{}.type_id()) == "transit.examples.counter" && RequesterCodec{}.version() == 1);
    assert(std::string(U64Codec{}.type_id()) == "transit.examples.u64" && U64Codec{}.version() == 1);
    assert(std::string(QueryCodec{}.type_id()) == "transit.examples.query" && QueryStartCodec{}.version() == 1);
    std::ifstream fixture(cfg.fixtures); assert(fixture); std::string validity, codec, hex, expected;
    while (fixture >> validity >> codec >> hex >> expected) {
        const auto bytes = from_hex(hex);
        if (validity == "valid") {
            assert(roundtrip(codec, bytes) == bytes);
            if (codec == "u64") assert(std::to_string(U64Codec{}.decode(bytes)) == expected);
        } else { bool failed = false; try { roundtrip(codec, bytes); } catch (const Error &error) { failed = error.detail().kind == TRANSIT_SDK_CODEC_ERROR; } assert(failed); }
    }
    const CounterMessage message = Add{(uint64_t{1} << 53) + 1}; auto payload = CounterCodec{}.encode(message);
    Bytes frame{'S','T','N','1',1,0,0,0,0,0,0,0,0}; frame.insert(frame.end(), payload.begin(), payload.end());
#ifdef TRANSIT_TEST_C_API
    const auto native = transit_example_counter_codec(); const transit_counter_message value{TRANSIT_COUNTER_ADD, (uint64_t{1} << 53) + 1}; transit_sdk_buffer out{};
    check(transit_station_encode_cast(&value, &native, nullptr, &out)); assert(Buffer(out).copy() == frame);
    auto error = transit_station_encode_cast(&value, &native, cfg.wrong.c_str(), &out); assert(error.kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && std::string(error.phase) == "station-version");
#else
    assert(encode_cast(message, CounterCodec{}) == frame);
    try { encode_cast(message, CounterCodec{}, cfg.wrong.c_str()); assert(false); }
    catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && std::string(error.detail().phase) == "station-version"); }
#endif
}
static void save_owned(Shared &shared, const Config &cfg) {
    for (auto &segment : shared.segments) {
        auto bytes = segment.owner ? segment.owner->ipc() : segment.bytes;
        auto copy = bytes; std::fill(copy.begin(), copy.end(), 0);
        assert(bytes != copy && (!segment.owner || segment.owner->ipc() == bytes));
        write_file(cfg.output + "/" + std::to_string(segment.info.ordinal) + ".arrow", bytes);
    }
}
static void check_expired(Shared &shared) {
    if (shared.escaped) { try { shared.escaped->info(); assert(false); } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_TURN_EXPIRED); } }
}
static void drive(const Config &cfg) {
    Shared shared; auto store = std::make_shared<Store>(cfg, shared); std::unique_ptr<Controller> runner;
    try { runner = open_controller(cfg, shared, store); }
    catch (const Error &error) { if (cfg.mode == "denied") { assert(error.detail().kind == TRANSIT_SDK_ACCESS_DENIED); return; } throw; }
    assert(cfg.mode != "denied");
    shared.check_reentry = [&] {
        try { runner->next(); assert(false); } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_BUSY); }
        try { runner->close(); assert(false); } catch (const Error &error) { assert(error.detail().kind == TRANSIT_SDK_BUSY); }
    };
    if (cfg.mode == "async") {
        assert(runner->next().info().kind != TRANSIT_EVENT_COMMITTED);
        std::atomic<bool> done{false}; std::optional<Event> evidence;
        std::thread task([&] { for (;;) { if (runner->next().info().kind == TRANSIT_EVENT_COMMITTED) break; } evidence = runner->close(); done = true; });
        wait_file(cfg.output + "/accepted"); runner->stop(); size_t beats = 0;
        while (!done) { ++beats; assert(beats < 1500); std::this_thread::sleep_for(10ms); }
        task.join(); assert(beats > 5 && !evidence->pending() && evidence->info().kind == TRANSIT_EVENT_COMMITTED && shared.handled == 1);
        check_expired(shared); report("{\"committed\":true,\"beats\":" + std::to_string(beats) + "}"); return;
    }
    if (cfg.mode == "gates") {
        bool done = false; std::set<std::string> phases;
        for (size_t i = 0; i < 40; ++i) {
            auto event = runner->next(); auto info = event.info();
            if (info.kind == TRANSIT_EVENT_NEEDS_RECOVERY) {
                phases.insert(info.phase); if (std::string(info.phase) == "confirm") assert(info.has_receipt);
                assert(runner->next().info().kind == TRANSIT_EVENT_NEEDS_RECOVERY); event = runner->reconcile(); info = event.info();
            }
            if (info.kind == TRANSIT_EVENT_COMMITTED) { done = true; break; }
        }
        assert(done && phases == std::set<std::string>({"confirm", "persist"}));
        assert(shared.initialized == 1 && shared.handled == 1 && shared.confirmations.size() == 3 && shared.saved.size() == 3);
        assert(shared.confirm_failed == std::set<std::string>({"commit", "open", "permit"}));
        report("{\"gates\":[\"commit\",\"open\",\"permit\"],\"handled\":1,\"dispatches\":3}");
    } else if (cfg.mode.rfind("decode-", 0) == 0 || cfg.mode.rfind("handler-", 0) == 0 || cfg.mode.rfind("exception-", 0) == 0 || cfg.mode == "invalid-thread") {
        bool stopped = false; const bool block = cfg.mode.size() >= 6 && cfg.mode.substr(cfg.mode.size() - 6) == "-block";
        for (size_t i = 0; i < 8; ++i) {
            try { const auto event = runner->next().info(); if (event.kind == TRANSIT_EVENT_BLOCKED && event.has_receipt) { assert(block); stopped = true; break; } }
            catch (const Error &error) { assert(!block); assert(error.detail().kind == (cfg.mode.rfind("decode-", 0) == 0 ? TRANSIT_SDK_CODEC_ERROR : TRANSIT_SDK_HANDLER_ERROR)); stopped = true; break; }
        }
        assert(stopped);
    } else if (cfg.mode == "stale" || cfg.mode == "expired" || cfg.mode == "revoked-result" || cfg.mode == "poison") {
        const auto expected = cfg.mode == "stale" ? TRANSIT_SDK_STALE_OWNERSHIP : cfg.mode == "expired" ? TRANSIT_SDK_PROCESS_RETIRED : cfg.mode == "poison" ? TRANSIT_SDK_READ_FAILED : TRANSIT_SDK_ACCESS_DENIED;
        bool failed = false;
        for (size_t i = 0; i < 8; ++i) { try { runner->next(); } catch (const Error &error) { assert(error.detail().kind == expected); failed = true; break; } }
        assert(failed); report("{\"denied\":true}");
    } else {
        std::string line;
        while (std::getline(std::cin, line)) {
            if (line == "close") { runner->close(); runner.reset(); check_expired(shared); save_owned(shared, cfg); report("{\"closed\":true}"); return; }
            assert(line == "one" || line == "reconcile"); bool observed = false;
            for (size_t i = 0; i < 32; ++i) {
                const auto event = line == "reconcile" && i == 0 ? runner->reconcile() : runner->next(); const auto info = event.info();
                if (info.kind == TRANSIT_EVENT_PROGRESS) continue;
                const char *name = info.kind == TRANSIT_EVENT_COMMITTED ? "Committed" : info.kind == TRANSIT_EVENT_IDLE ? "Idle" : info.kind == TRANSIT_EVENT_BLOCKED ? "Blocked" : "NeedsRecovery";
                if (info.kind == TRANSIT_EVENT_NEEDS_RECOVERY) assert(event.pending()->export_bytes() == read_file(cfg.pending));
                report(std::string("{\"event\":\"") + name + "\",\"phase\":\"" + info.phase + "\",\"code\":\"" + info.error.code + "\"}"); observed = true; break;
            }
            assert(observed); check_expired(shared);
        }
    }
    runner->close(); runner.reset(); check_expired(shared);
}
int main(int argc, char **argv) {
    assert(argc == 16); const Config cfg(argv);
    try {
        if (cfg.mode == "codecs") { codecs(cfg); return 0; }
        if (cfg.mode == "recover") {
            auto client = Client::open(ClientConfig::growing(cfg.url)); const auto pending = client.recover_mutation(read_file(cfg.pending));
            const auto receipt = std::get<MutationReceipt>(client.dispatch(pending)); client.close(); report("{\"receipt\":" + std::to_string(receipt.position) + "}"); return 0;
        }
        drive(cfg); return 0;
    } catch (const Error &error) { std::cerr << error.what() << " kind=" << error.detail().kind << " code=" << error.detail().code << std::endl; return 1; }
    catch (const std::exception &error) { std::cerr << error.what() << std::endl; return 1; }
}

#include <transit/sdk_examples.hpp>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <fcntl.h>
#include <filesystem>
#include <thread>
#include <unistd.h>
using namespace transit::sdk;
using namespace transit::sdk::station;
using namespace transit::sdk::examples;
class Store final : public RecoveryStore {
    std::string path_;
public:
    explicit Store(std::string path) : path_(std::move(path)) {}
    void before_dispatch(const FrozenMutation &mutation) override {
        const auto bytes = mutation.export_bytes(); int file = open(path_.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
        bool success = file >= 0; size_t offset = 0;
        while (success && offset < bytes.size()) {
            const auto written = write(file, bytes.data() + offset, bytes.size() - offset);
            if (written < 0 && errno == EINTR) continue;
            if (written <= 0) success = false; else offset += static_cast<size_t>(written);
        }
        if (file >= 0) { if (fsync(file)) success = false; if (::close(file)) success = false; }
        auto parent = std::filesystem::path(path_).parent_path(); if (parent.empty()) parent = ".";
        int directory = open(parent.c_str(), O_RDONLY | O_DIRECTORY);
        if (directory < 0) success = false;
        else { if (fsync(directory)) success = false; if (::close(directory)) success = false; }
        if (!success) throw failure(TRANSIT_SDK_HANDLER_ERROR, "persist-request");
    }
    void confirmed(std::string_view, MutationReceipt) override {}
};
template<class M> int drive(Runner<M> runner, uint64_t target) {
    uint64_t commits = 0;
    for (size_t steps = 0; commits < target && steps < 1000; ++steps) {
        const auto event = runner.next().info();
        if (event.kind == TRANSIT_EVENT_COMMITTED) ++commits;
        else if (event.kind == TRANSIT_EVENT_NEEDS_RECOVERY || event.kind == TRANSIT_EVENT_BLOCKED) throw failure(TRANSIT_SDK_HANDLER_ERROR, "explicit-recovery-required");
        else if (event.kind == TRANSIT_EVENT_IDLE) std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    runner.close(); std::printf("{\"commits\":%llu}\n", static_cast<unsigned long long>(commits)); return commits == target ? 0 : 1;
}
static uint64_t number(const char *text) {
    std::string value(text); if (value.empty() || value.find_first_not_of("0123456789") != std::string::npos) throw std::invalid_argument("Expected an unsigned integer");
    return std::stoull(value);
}
int main(int argc, char **argv) {
    if (argc != 11) { std::fputs("Usage: transit-cpp-counter URL service|requester REALM PRINCIPAL PID GENERATION SEED_FILE PEER COMMITS PENDING_FILE\n", stderr); return 2; }
    try {
        const auto realm = number(argv[3]);
        ServiceConfig config(ClientConfig::growing(argv[1]), ProcessRef(realm, number(argv[5])), number(argv[4]), number(argv[6]), argv[7]);
        const ProcessRef peer(realm, number(argv[8])); const auto target = number(argv[9]);
        auto options = RunnerOptions::persist(std::make_shared<Store>(argv[10]));
        if (std::string(argv[2]) == "service") return drive(Runner<CounterMessage>::open(config, std::make_unique<Counter>(), std::make_shared<CounterCodec>(), options), target);
        if (std::string(argv[2]) == "requester") return drive(Runner<RequesterMessage>::open(config, std::make_unique<Requester>(peer), std::make_shared<RequesterCodec>(), options), target);
        return 2;
    } catch (const std::exception &error) { std::fprintf(stderr, "%s\n", error.what()); return 1; }
}

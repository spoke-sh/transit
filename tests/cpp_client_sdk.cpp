#include <transit/client.hpp>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <future>
#include <iterator>
#include <thread>
#include <type_traits>
using namespace transit::sdk;
using namespace std::chrono_literals;
static_assert(!std::is_copy_constructible_v<Client> && !std::is_copy_constructible_v<PendingSend>);
static_assert(!std::is_convertible_v<ResourceRef, ProcessRef>);
static Bytes read_file(const char *path) {
    std::ifstream stream(path, std::ios::binary); assert(stream); Bytes bytes{std::istreambuf_iterator<char>(stream), {}};
    assert(bytes.size() <= 262144); return bytes;
}
static void write_file(const char *path, const Bytes &bytes) {
    std::ofstream stream(path, std::ios::binary); stream.write(reinterpret_cast<const char *>(bytes.data()), bytes.size()); assert(stream);
}
int main(int argc, char **argv) {
    assert(argc == 9);
    const std::string mode(argv[1]);
    auto config = ClientConfig::growing(argv[2]); config.timeout(3000);
    Credential credential(72, 65536, argv[3]); ProcessRef peer(72, std::stoull(argv[4]));
    try { ProcessRef invalid(72, 0); assert(false); } catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_INVALID_ARGUMENT); }
    try { auto bad = Client::open(ClientConfig::growing(argv[2]).native_directory("/missing-transit")); assert(false); }
    catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE); }
    try { auto bad = Client::open(ClientConfig::growing(argv[2]).native_directory(argv[8])); assert(false); }
    catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_INCOMPATIBLE_NATIVE && std::string(e.detail().phase) == "native-version"); }
    auto client = Client::open(config);
    if (mode == "first") {
        auto caps = client.capabilities(credential); assert(caps.principal_sequence == 0 && caps.page_size == 8 && caps.retained_versions);
        Bytes value{'w','i','d','e'}; auto pending = client.prepare_send(peer, value, credential, 1); value.assign(4, 0);
        auto frozen = pending.export_bytes(); write_file(argv[5], frozen);
        auto copy = pending.export_bytes(); copy.assign(copy.size(), 0); assert(pending.export_bytes() == frozen);
        auto outcome = client.dispatch(pending); auto *uncertain = std::get_if<Uncertain>(&outcome);
        assert(uncertain && uncertain->recovery == frozen && uncertain->cause.detail().native_status == 6);
    } else if (mode == "recover" || mode == "denied") {
        auto frozen = read_file(argv[5]); auto pending = client.recover_send(frozen); auto result = client.dispatch(pending);
        if (mode == "denied") { auto &rejected = std::get<Rejected>(result); assert(rejected.cause.detail().kind == TRANSIT_SDK_ACCESS_DENIED && rejected.cause.detail().native_status == 4); }
        else {
            assert(!std::filesystem::exists(argv[3])); auto receipt = std::get<AdmissionReceipt>(result);
            std::printf("{\"position\":%llu}\n", static_cast<unsigned long long>(receipt.position));
            assert(std::get<AdmissionReceipt>(client.dispatch(pending)).position == receipt.position);
            const auto spawn = read_file(argv[6]);
            try { auto bad = client.recover_send(spawn); assert(false); } catch (const Error &e) { assert(e.detail().kind == TRANSIT_SDK_UNSUPPORTED_CAPABILITY); }
            auto mutation = client.recover_mutation(spawn); assert(std::string(mutation.info().command) == "spawn" && mutation.export_bytes() == spawn);
            frozen.insert(frozen.begin(), ' '); try { auto bad = client.recover_send(frozen); assert(false); } catch (const Error &) {}
        }
    } else if (mode == "async") {
        auto pending = client.prepare_send(peer, Bytes{'a','s','y','n','c'}, credential, 2); auto bytes = pending.export_bytes();
        std::atomic<bool> done{false}; uint64_t position = 0;
        std::promise<AdmissionReceipt> response; auto receive = response.get_future();
        std::thread task([owned = std::move(client), pending = std::move(pending), reply = std::move(response), &done, &position]() mutable {
            const auto receipt = std::get<AdmissionReceipt>(owned.dispatch(pending)); position = receipt.position;
            auto shutdown = owned.close(); assert(shutdown.has_admission && shutdown.last_admission.position == position);
            reply.set_value(receipt); done = true;
        });
        const auto deadline = std::chrono::steady_clock::now() + 15s;
        while (!std::filesystem::exists(argv[7])) { assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(5ms); }
        receive = {}; // Local observation ends; task ownership continues.
        int beats = 0; while (!done) { ++beats; assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(10ms); }
        task.join(); assert(beats > 5);
        auto fresh = Client::open(config); auto recovered = fresh.recover_send(bytes);
        assert(std::get<AdmissionReceipt>(fresh.dispatch(recovered)).position == position); fresh.close();
        std::puts("{\"scenario\":\"blocking-owner-disposal\",\"observations\":{\"controller_wait_abandoned\":true,\"responsive_during_join\":true,\"owned_work_joined\":true,\"receipt_recovered\":true}}");
        return 0;
    } else std::abort();
    client.close();
}

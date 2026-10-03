// Installed C11 callbacks and typed C++ callers run the same external schedule.
#include <transit/sdk_examples.hpp>
#include "c_grpc_sdk.h"
#include <atomic>
#include <cassert>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <thread>
using namespace transit::sdk;
using namespace transit::sdk::station;
using namespace transit::sdk::examples;
using namespace std::chrono_literals;
struct Config {
    std::string mode, url, seed, body, outcome, ready, resume, accepted, fixtures, descriptor;
    uint64_t principal, pid, generation, peer, resource, deadline;
    explicit Config(char **a) : mode(a[1]), url(a[2]), seed(a[6]), body(a[9]), outcome(a[11]), ready(a[12]), resume(a[13]), accepted(a[14]), fixtures(a[15]), descriptor(a[16]),
        principal(std::stoull(a[3])), pid(std::stoull(a[4])), generation(std::stoull(a[5])), peer(std::stoull(a[7])), resource(std::stoull(a[8])), deadline(std::stoull(a[10])) {}
    ServiceConfig service() const { auto client = ClientConfig::growing(url); client.timeout(3000); return ServiceConfig(client, ProcessRef(72, pid), principal, generation, seed); }
};
static Bytes unhex(const std::string &value) {
    assert(value.size() % 2 == 0); Bytes out;
    for (size_t i = 0; i < value.size(); i += 2) out.push_back(static_cast<uint8_t>(std::stoul(value.substr(i, 2), nullptr, 16)));
    return out;
}
static std::string hex(const Bytes &value) {
    const char *digits = "0123456789abcdef"; std::string out;
    for (const auto byte : value) { out += digits[byte >> 4]; out += digits[byte & 15]; } return out;
}
static void report(const std::string &value) { std::cout << value << std::endl; }
static void wait_file(const std::string &value) {
    const auto deadline = std::chrono::steady_clock::now() + 30s;
    while (!std::filesystem::exists(value)) { assert(std::chrono::steady_clock::now() < deadline); std::this_thread::sleep_for(10ms); }
}
template<class F> static void expect(transit_sdk_error_kind kind, F &&work, const char *code = nullptr) {
    bool caught = false; try { work(); } catch (const Error &error) { assert(error.detail().kind == kind); if (code) assert(std::string(error.detail().code) == code); caught = true; } assert(caught);
}
static PreparedGrpcRequest prepare(uint64_t resource, const Bytes &descriptor, const Bytes &body, uint64_t deadline) {
#ifdef TRANSIT_TEST_C_API
    transit_station_grpc_request *out = nullptr; check(grpc_test_prepare(resource,bytes_view(descriptor),bytes_view(body),deadline,&out)); return PreparedGrpcRequest(out);
#else
    GrpcRequest request{grpc_method(descriptor,"/test.Peer/Bidi"), {
        {"x-tag",Bytes{'o','n','e'}}, {"x-tag",Bytes{'t','w','o'}}, {"x-data-bin",Bytes{0,255}}, {"authorization",GrpcSecretRef{"api",7}}
    }};
    return prepare_grpc(ResourceRef(72,resource),UINT64_MAX,request,{body,{}},{7,deadline,1});
#endif
}
static GrpcOutcome decode(const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    transit_station_grpc_outcome out{}; check(transit_station_grpc_decode(72, bytes_view(bytes), nullptr, &out)); return GrpcOutcome(out);
#else
    return decode_grpc_reply(72, bytes);
#endif
}
static GrpcReleased decode_released(const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    transit_station_grpc_released out{}; check(transit_station_grpc_decode_released(72, bytes_view(bytes), nullptr, &out)); return GrpcReleased(out);
#else
    return decode_grpc_released(72, bytes);
#endif
}
static void golden(const Config &cfg) {
    std::ifstream file(cfg.fixtures); std::string outcome, unknown, rejected, released; file >> outcome >> unknown >> rejected >> released; assert(file);
    const auto result = decode(unhex(outcome));
    assert(!result.rejected() && result.exchange() == UINT64_MAX && result.status() == 0 && result.reference() && result.phase() == TRANSIT_GRPC_OBSERVED);
    const auto uncertain = decode(unhex(unknown));
    assert(uncertain.phase() == TRANSIT_GRPC_CLOSED_UNKNOWN && !uncertain.status() && !uncertain.reference());
    assert(decode(unhex(rejected)).rejection() == TRANSIT_GRPC_DENIED);
    assert(result.diagnostic().find("grpc.ok_observed") != std::string::npos);
    assert(result.diagnostic().find("18446744073709551615") != std::string::npos);
    assert(decode(unhex(rejected)).diagnostic().find("grpc.request_denied") != std::string::npos);
    bool failed = false; try { decode(unhex(outcome.substr(0,outcome.size()-2))); } catch (const Error &) { failed=true; } assert(failed);
    const auto acknowledgement = decode_released(unhex(released));
    assert(acknowledgement.resource().realm() == 72 && acknowledgement.exchange() == UINT64_MAX);
#ifndef TRANSIT_TEST_C_API
    const GrpcReplyCodec<uint64_t> codec(std::make_shared<U64Codec>(),72);
    assert(std::get<uint64_t>(codec.decode(codec.encode(UINT64_MAX))) == UINT64_MAX);
    assert(std::get<GrpcOutcome>(codec.decode(unhex(outcome))).status() == 0);
    expect(TRANSIT_SDK_CODEC_ERROR,[&] { codec.encode(result); });
#endif
}
class GrpcBytesCodec final : public Codec<Bytes> {
public:
    const char *type_id() const noexcept override { return "test.grpc-control"; }
    uint32_t version() const noexcept override { return 1; }
    size_t max_encoded_bytes() const noexcept override { return 243; }
    Bytes encode(const Bytes &value) const override { return value; }
    Bytes decode(const Bytes &value) const override { return value; }
};
struct Shared { unsigned result = 0; std::optional<Turn> escaped; };
class GrpcHandler final : public Handler<GrpcMessage<Bytes>> {
    Shared &shared_;
    ProcessRef peer_;
    PreparedGrpcRequest request_;
    Key<uint64_t> correlation_{"grpc-correlation", std::make_shared<U64Codec>()};
    Key<uint64_t> release_correlation_{"grpc-release-correlation", std::make_shared<U64Codec>()};
    Key<uint64_t> followup_correlation_{"grpc-followup-correlation", std::make_shared<U64Codec>()};
    std::optional<GrpcOutcome> disposal_;
public:
    GrpcHandler(Shared &shared, ProcessRef peer, PreparedGrpcRequest request, const std::string &outcome) : shared_(shared), peer_(peer), request_(std::move(request)) {
        if (!outcome.empty()) disposal_ = decode(unhex(outcome));
    }
    void handle(Turn &turn, const Incoming<GrpcMessage<Bytes>> &input) override {
        shared_.escaped = turn; const auto saved = turn.state().find(correlation_);
        if (std::holds_alternative<Cast<GrpcMessage<Bytes>>>(input)) {
            const auto &value = std::get<Cast<GrpcMessage<Bytes>>>(input).value;
            if (std::holds_alternative<Bytes>(value) && std::get<Bytes>(value) == Bytes({'f','o','l','l','o','w','u','p'})) {
                assert(disposal_); auto wrong = disposal_->native(); wrong.resource.realm = 73;
                expect(TRANSIT_SDK_INVALID_ARGUMENT, [&] { turn.retry_grpc(peer_, GrpcOutcome(wrong), request_); });
                const auto call = turn.retry_grpc(peer_, *disposal_, request_);
                turn.state().put(followup_correlation_, call); shared_.result = 5; return;
            }
            if (std::holds_alternative<Bytes>(value) && std::get<Bytes>(value) == Bytes({'d','i','s','p','o','s','e'})) {
                assert(disposal_);
                expect(TRANSIT_SDK_INVALID_ARGUMENT, [&] { turn.release_grpc(peer_, ResourceRef(73, disposal_->resource().resource()), disposal_->exchange()); });
                const auto call = turn.release_grpc(peer_, disposal_->resource(), disposal_->exchange());
                turn.state().put(release_correlation_, call); shared_.result = 3; return;
            }
            if (saved) shared_.result = 1;
            else if (turn.stage_grpc(request_)) { const auto call = turn.call_grpc(peer_, request_); turn.state().put(correlation_, call); shared_.result = 1; }
            else shared_.result = 0;
        } else {
            const auto &reply = std::get<Reply<GrpcMessage<Bytes>>>(input); assert(saved);
            if (std::holds_alternative<GrpcOutcome>(reply.value) && std::get<GrpcOutcome>(reply.value).rejected()) {
                const auto correlation = turn.state().require(followup_correlation_); turn.require_reply(peer_, correlation);
                assert(std::get<GrpcOutcome>(reply.value).rejection() == TRANSIT_GRPC_DENIED);
                const auto diagnostic = std::get<GrpcOutcome>(reply.value).diagnostic();
                for (const auto field : {"field_path", "native_input", "proposal"}) assert(diagnostic.find(field) != std::string::npos);
                turn.state().put(Key<uint64_t>("grpc-followup-denied", std::make_shared<U64Codec>()), correlation); shared_.result = 6; return;
            }
            if (std::holds_alternative<GrpcReleased>(reply.value)) {
                turn.require_reply(peer_, turn.state().require(release_correlation_));
                const auto &released = std::get<GrpcReleased>(reply.value);
                assert(disposal_ && released.resource().realm() == disposal_->resource().realm() && released.resource().resource() == disposal_->resource().resource() && released.exchange() == disposal_->exchange());
                turn.state().put(Key<uint64_t>("grpc-disposed", std::make_shared<U64Codec>()), released.exchange()); shared_.result = 4; return;
            }
            turn.require_reply(peer_, *saved); const auto &outcome = std::get<GrpcOutcome>(reply.value);
            assert(!outcome.rejected() && outcome.phase() == TRANSIT_GRPC_OBSERVED && outcome.status() == 0);
            turn.state().put(Key<uint64_t>("grpc-status", std::make_shared<U64Codec>()), uint64_t{0}); shared_.result = 2;
        }
    }
};
#ifdef TRANSIT_TEST_C_API
class Reader {
    std::unique_ptr<transit_station_grpc_reader, decltype(&transit_station_grpc_reader_destroy)> value_;
    bool complete_ = false;
public:
    explicit Reader(transit_station_grpc_reader *value) : value_(value, transit_station_grpc_reader_destroy) {}
    Reader(Reader &&) noexcept = default;
    Reader &operator=(Reader &&) noexcept = default;
    std::optional<GrpcPart> read() {
        transit_station_grpc_part out{}; check(transit_station_grpc_read(value_.get(), &out)); complete_ = out.complete;
        if (!out.present) return {}; assert(out.size <= 256); return GrpcPart{out.kind, Bytes(out.bytes, out.bytes + out.size), out.complete};
    }
    bool complete() const { return complete_; }
    void close() { check(transit_station_grpc_close(value_.get())); }
};
class Controller {
    grpc_test_context context_;
    std::unique_ptr<transit_station_runner, decltype(&transit_station_runner_destroy)> value_{nullptr, transit_station_runner_destroy};
public:
    Controller(const Config &cfg, const PreparedGrpcRequest &request) : context_{{72, cfg.peer}, request.native(), nullptr, 0, {}, {}} {
        if (!cfg.outcome.empty()) { const auto outcome = decode(unhex(cfg.outcome)); context_.disposal = {outcome.native().resource, outcome.exchange()}; context_.parent = outcome.native(); }
        const auto config = cfg.service(); const auto settings = config.native(); const auto handler = grpc_test_handler(&context_); const auto codec = grpc_test_codec(&context_);
        const transit_station_options options{TRANSIT_FAILURE_STOP, TRANSIT_RECOVERY_FRESH_OWNERSHIP, nullptr, nullptr, nullptr}; transit_station_runner *out = nullptr;
        check(transit_station_runner_open(&settings, &handler, &codec, &options, &out)); value_.reset(out);
    }
    ~Controller() { value_.reset(); transit_station_turn_release(context_.escaped); }
    Event next() { transit_station_event *out = nullptr; check(transit_station_runner_next(value_.get(), &out)); return Event(out); }
    void close() { transit_station_event *out = nullptr; check(transit_station_runner_close(value_.get(), &out)); transit_station_event_destroy(out); }
    void stop() { transit_station_runner_stop(value_.get()); }
    Reader open(const GrpcOutcome &outcome) { transit_station_grpc_reader *out = nullptr; check(transit_station_grpc_open(value_.get(), &outcome.native(), TRANSIT_GRPC_CAPTURED, &out)); return Reader(out); }
    std::optional<std::string> diagnostic(const GrpcOutcome &outcome, ExchangeDiagnosticKind kind) {
        transit_sdk_diagnostic out{}; check(transit_station_grpc_diagnostic(value_.get(), &outcome.native(), static_cast<transit_station_exchange_diagnostic_kind>(kind), &out));
        if (!out.size) return {}; return std::string(out.json, out.size);
    }
    unsigned result() const { return context_.result; }
    void expired(const PreparedGrpcRequest &request) {
        bool ready = false; expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_grpc_stage(context_.escaped, request.native(), &ready)); });
        uint64_t correlation = 1; expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_grpc_release(context_.escaped, context_.peer, {72, 1}, 1, &correlation)); }); assert(correlation == 0);
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_grpc_retry(context_.escaped, context_.peer, &context_.parent, request.native(), &correlation)); }); assert(correlation == 0);
    }
};
#else
using Reader = GrpcReader;
class Controller {
    Shared shared_;
    Runner<GrpcMessage<Bytes>> value_;
public:
    Controller(const Config &cfg, const PreparedGrpcRequest &request) : value_(Runner<GrpcMessage<Bytes>>::open(cfg.service(),
        std::make_unique<GrpcHandler>(shared_, ProcessRef(72, cfg.peer), request, cfg.outcome), std::make_shared<GrpcReplyCodec<Bytes>>(std::make_shared<GrpcBytesCodec>(), 72), RunnerOptions::fresh_ownership())) {}
    Event next() { return value_.next(); }
    void close() { value_.close(); }
    void stop() { value_.stop(); }
    Reader open(const GrpcOutcome &outcome) { return value_.open_grpc(outcome); }
    std::optional<std::string> diagnostic(const GrpcOutcome &outcome, ExchangeDiagnosticKind kind) { return value_.grpc_diagnostic(outcome, kind); }
    unsigned result() const { return shared_.result; }
    void expired(const PreparedGrpcRequest &request) {
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->stage_grpc(request); });
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->release_grpc(ProcessRef(72, 1), ResourceRef(72, 1), 1); });
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->retry_grpc(ProcessRef(72, 1), GrpcOutcome({}), request); });
    }
};
#endif
static void drive(const Config &cfg) {
    auto body = unhex(cfg.body); const auto request = prepare(cfg.resource, unhex(cfg.descriptor), body, cfg.deadline); body.clear(); assert(request.batch().size() > 513);
    auto runner = std::make_unique<Controller>(cfg, request); std::optional<Reader> reader; std::optional<GrpcOutcome> outcome; Bytes owned;
    if (cfg.mode == "grpc-async") {
        reader = runner->open(decode(unhex(cfg.outcome))); const auto first = reader->read(); assert(first && !first->data.empty() && !first->complete);
        std::ofstream(cfg.ready).close(); wait_file(cfg.resume);
        std::thread pending([&] { assert(reader->read()); }); wait_file(cfg.accepted);
        expect(TRANSIT_SDK_BUSY, [&] { reader->read(); }); runner->stop();
        std::atomic<bool> done{false}; std::thread closing([&] { runner->close(); done = true; }); size_t beats = 0;
        while (!done) { assert(++beats < 3000); std::this_thread::sleep_for(10ms); }
        closing.join(); pending.join(); assert(beats > 5); runner.reset();
        assert(!first->data.empty()); expect(TRANSIT_SDK_CLOSED, [&] { reader->read(); }); report("{\"joined\":true}"); return;
    }
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line == "step") {
            bool committed = false;
            for (size_t i = 0; i < 32; ++i) { if (runner->next().info().kind == TRANSIT_EVENT_COMMITTED) { committed = true; break; } }
            assert(committed); runner->expired(request);
            report(runner->result() == 6 ? "{\"followup\":true}" : runner->result() == 5 ? "{\"followup\":false}" : runner->result() == 4 ? "{\"released\":true}" : runner->result() == 3 ? "{\"released\":false}" : runner->result() == 2 ? "{\"observed\":true}" : runner->result() == 1 ? "{\"called\":true}" : "{\"called\":false}");
        } else if (line == "open") {
            outcome = decode(unhex(cfg.outcome));
            assert(!runner->diagnostic(*outcome, ExchangeDiagnosticKind::CaptureFailure));
            const auto evidence = runner->diagnostic(*outcome, ExchangeDiagnosticKind::NativeEffect); assert(evidence);
            assert(evidence->find("effect.result_recorded") != std::string::npos && evidence->find("completed") != std::string::npos);
            assert(evidence->find("\"id\":\"" + std::to_string(outcome->effect()) + "\"") != std::string::npos); reader = runner->open(*outcome);
            expect(TRANSIT_SDK_BUSY, [&] { runner->open(*outcome); }); const auto first = reader->read(); assert(first && !first->data.empty() && !first->complete); report("{\"prefix\":true}");
        } else if (line == "denied") {
            expect(TRANSIT_SDK_ACCESS_DENIED, [&] { runner->diagnostic(*outcome, ExchangeDiagnosticKind::CaptureFailure); });
            expect(TRANSIT_SDK_ACCESS_DENIED, [&] { runner->diagnostic(*outcome, ExchangeDiagnosticKind::NativeEffect); });
            expect(TRANSIT_SDK_ACCESS_DENIED, [&] { reader->read(); }); report("{\"denied\":true}");
        } else if (line == "reopen") {
            expect(TRANSIT_SDK_READ_FAILED, [&] { reader->read(); }, "GrpcReplayFailed"); reader->close(); reader->close(); reader = runner->open(*outcome);
            while (const auto part = reader->read()) { assert(part->data.size() <= 256); if (part->kind == TRANSIT_GRPC_RESPONSE_BODY) owned.insert(owned.end(), part->data.begin(), part->data.end()); }
            assert(reader->complete()); reader->close(); report("{\"complete\":true,\"body\":\"" + hex(owned) + "\"}");
        } else {
            assert(line == "close"); runner->close(); runner.reset(); if (reader) expect(TRANSIT_SDK_CLOSED, [&] { reader->read(); });
            report("{\"closed\":true,\"owned\":\"" + hex(owned) + "\"}"); return;
        }
    }
}
int main(int argc, char **argv) {
    assert(argc == 17); const Config cfg(argv);
    try { golden(cfg); if (cfg.mode != "codecs") drive(cfg); }
    catch (const Error &error) { std::cerr << error.what() << " kind=" << error.detail().kind << " code=" << error.detail().code << std::endl; return 1; }
}

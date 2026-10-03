// Installed C11 callbacks and typed C++ callers run the same external schedule.
#include <transit/sdk_examples.hpp>
#include "c_http_sdk.h"
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
    std::string mode, url, seed, body, outcome, ready, resume, accepted, fixtures;
    uint64_t principal, pid, generation, peer, resource, deadline;
    HttpFollowupReason followup_reason;
    explicit Config(char **a) : mode(a[1]), url(a[2]), seed(a[6]), body(a[9]), outcome(a[11]), ready(a[12]), resume(a[13]), accepted(a[14]), fixtures(a[15]),
        principal(std::stoull(a[3])), pid(std::stoull(a[4])), generation(std::stoull(a[5])), peer(std::stoull(a[7])), resource(std::stoull(a[8])), deadline(std::stoull(a[10])),
        followup_reason(std::string(a[16]) == "redirect" ? HttpFollowupReason::Redirect : std::string(a[16]) == "reconcile" ? HttpFollowupReason::Reconcile : std::string(a[16]) == "cancel" ? HttpFollowupReason::Cancel : HttpFollowupReason::Retry) {}
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
static PreparedHttpRequest prepare(uint64_t resource, const Bytes &body, uint64_t deadline, bool rich) {
#ifdef TRANSIT_TEST_C_API
    transit_station_http_request *out = nullptr; check(http_test_prepare(resource, bytes_view(body), deadline, rich, &out)); return PreparedHttpRequest(out);
#else
    HttpRequest request{HttpMethod::Post, {HttpLiteral{rich ? "/items/" : "/write"}}, {}};
    if (rich) {
        request.target.push_back(HttpVariable{"id", "λ /"});
        request.headers = {{"X-Tag", {HttpLiteral{"one"}}}, {"X-Tag", {HttpLiteral{"two"}}}, {"Authorization", {HttpLiteral{"Bearer "}, HttpSecretRef{"api", 7}}}};
    }
    return prepare_http(ResourceRef(72, resource), UINT64_MAX, request, body, {7, deadline, rich ? 1u : 2u});
#endif
}
static HttpOutcome decode(const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    transit_station_http_outcome out{}; check(transit_station_http_decode(72, bytes_view(bytes), nullptr, &out)); return HttpOutcome(out);
#else
    return decode_http_reply(72, bytes);
#endif
}
static HttpReleased decode_released(const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    transit_station_http_released out{}; check(transit_station_http_decode_released(72, bytes_view(bytes), nullptr, &out)); return HttpReleased(out);
#else
    return decode_http_released(72, bytes);
#endif
}
static void golden(const Config &cfg) {
    std::ifstream file(cfg.fixtures); std::string body, reference, metadata, outcome, rejected, released; file >> body >> reference >> metadata >> outcome >> rejected >> released; assert(file);
    auto source = unhex(body); auto prepared = prepare(8, source, 9000, false); source.clear();
    assert(hex(prepared.reference()) == reference && hex(prepared.metadata()) == metadata && hex(prepared.body()) == body);
    const auto result = decode(unhex(outcome));
    assert(!result.rejected() && result.exchange() == UINT64_MAX && result.status() == 200 && result.reference() && result.phase() == TRANSIT_HTTP_OBSERVED);
    assert(decode(unhex(rejected)).rejection() == TRANSIT_HTTP_DENIED);
    assert(result.diagnostic().find("http.response_observed") != std::string::npos);
    assert(result.diagnostic().find("18446744073709551615") != std::string::npos);
    assert(decode(unhex(rejected)).diagnostic().find("http.request_denied") != std::string::npos);
    bool failed = false; try { decode(unhex(outcome.substr(0, outcome.size() - 2))); } catch (const Error &) { failed = true; } assert(failed);
    const auto acknowledgement = decode_released(unhex(released));
    assert(acknowledgement.resource().realm() == 72 && acknowledgement.resource().resource() == 7 && acknowledgement.exchange() == UINT64_MAX);
    failed = false; try { decode_released(unhex(released.substr(0, released.size() - 2))); } catch (const Error &) { failed = true; } assert(failed);
#ifndef TRANSIT_TEST_C_API
    const HttpReplyCodec<uint64_t> codec(std::make_shared<U64Codec>(), 72);
    assert(std::get<uint64_t>(codec.decode(codec.encode(UINT64_MAX))) == UINT64_MAX);
    assert(std::get<HttpOutcome>(codec.decode(unhex(outcome))).exchange() == UINT64_MAX);
    expect(TRANSIT_SDK_CODEC_ERROR, [&] { codec.encode(result); });
    assert(std::get<HttpReleased>(codec.decode(unhex(released))).exchange() == UINT64_MAX);
    expect(TRANSIT_SDK_CODEC_ERROR, [&] { codec.encode(acknowledgement); });
    failed = false;
    try { prepare_http(ResourceRef(72, 8), 1, {HttpMethod::Get, {HttpLiteral{"//other/"}}, {}}, {}, {1, 9000}); } catch (const Error &) { failed = true; } assert(failed);
#endif
}
class HttpBytesCodec final : public Codec<Bytes> {
public:
    const char *type_id() const noexcept override { return "test.http-control"; }
    uint32_t version() const noexcept override { return 1; }
    size_t max_encoded_bytes() const noexcept override { return 243; }
    Bytes encode(const Bytes &value) const override { return value; }
    Bytes decode(const Bytes &value) const override { return value; }
};
struct Shared { unsigned result = 0; std::optional<Turn> escaped; };
class HttpHandler final : public Handler<HttpMessage<Bytes>> {
    Shared &shared_;
    ProcessRef peer_;
    PreparedHttpRequest request_;
    Key<uint64_t> correlation_{"http-correlation", std::make_shared<U64Codec>()};
    Key<uint64_t> release_correlation_{"http-release-correlation", std::make_shared<U64Codec>()};
    Key<uint64_t> followup_correlation_{"http-followup-correlation", std::make_shared<U64Codec>()};
    HttpFollowupReason followup_reason_;
    std::optional<HttpOutcome> disposal_;
public:
    HttpHandler(Shared &shared, ProcessRef peer, PreparedHttpRequest request, const std::string &outcome, HttpFollowupReason reason) : shared_(shared), peer_(peer), request_(std::move(request)), followup_reason_(reason) {
        if (!outcome.empty()) disposal_ = decode(unhex(outcome));
    }
    void handle(Turn &turn, const Incoming<HttpMessage<Bytes>> &input) override {
        shared_.escaped = turn; const auto saved = turn.state().find(correlation_);
        if (std::holds_alternative<Cast<HttpMessage<Bytes>>>(input)) {
            const auto &value = std::get<Cast<HttpMessage<Bytes>>>(input).value;
            if (std::holds_alternative<Bytes>(value) && std::get<Bytes>(value) == Bytes({'f','o','l','l','o','w','u','p'})) {
                assert(disposal_); auto wrong = disposal_->native(); wrong.resource.realm = 73;
                expect(TRANSIT_SDK_INVALID_ARGUMENT, [&] { turn.followup_http(peer_, HttpOutcome(wrong), followup_reason_, request_); });
                expect(TRANSIT_SDK_INVALID_ARGUMENT, [&] { turn.followup_http(peer_, *disposal_, static_cast<HttpFollowupReason>(100), request_); });
                const auto call = turn.followup_http(peer_, *disposal_, followup_reason_, request_);
                turn.state().put(followup_correlation_, call); shared_.result = 5; return;
            }
            if (std::holds_alternative<Bytes>(value) && std::get<Bytes>(value) == Bytes({'d','i','s','p','o','s','e'})) {
                assert(disposal_);
                expect(TRANSIT_SDK_INVALID_ARGUMENT, [&] { turn.release_http(peer_, ResourceRef(73, disposal_->resource().resource()), disposal_->exchange()); });
                const auto call = turn.release_http(peer_, disposal_->resource(), disposal_->exchange());
                turn.state().put(release_correlation_, call); shared_.result = 3; return;
            }
            if (saved) shared_.result = 1;
            else if (turn.stage_http(request_)) { const auto call = turn.call_http(peer_, request_); turn.state().put(correlation_, call); shared_.result = 1; }
            else shared_.result = 0;
        } else {
            const auto &reply = std::get<Reply<HttpMessage<Bytes>>>(input); assert(saved);
            if (std::holds_alternative<HttpOutcome>(reply.value) && std::get<HttpOutcome>(reply.value).rejected()) {
                const auto correlation = turn.state().require(followup_correlation_); turn.require_reply(peer_, correlation);
                assert(std::get<HttpOutcome>(reply.value).rejection() == TRANSIT_HTTP_DENIED);
                const auto diagnostic = std::get<HttpOutcome>(reply.value).diagnostic();
                for (const auto field : {"field_path", "native_input", "proposal"}) assert(diagnostic.find(field) != std::string::npos);
                turn.state().put(Key<uint64_t>("http-followup-denied", std::make_shared<U64Codec>()), correlation); shared_.result = 6; return;
            }
            if (std::holds_alternative<HttpReleased>(reply.value)) {
                turn.require_reply(peer_, turn.state().require(release_correlation_));
                const auto &released = std::get<HttpReleased>(reply.value);
                assert(disposal_ && released.resource().realm() == disposal_->resource().realm() && released.resource().resource() == disposal_->resource().resource() && released.exchange() == disposal_->exchange());
                turn.state().put(Key<uint64_t>("http-disposed", std::make_shared<U64Codec>()), released.exchange()); shared_.result = 4; return;
            }
            turn.require_reply(peer_, *saved); const auto &outcome = std::get<HttpOutcome>(reply.value);
            assert(!outcome.rejected() && outcome.phase() == TRANSIT_HTTP_OBSERVED && outcome.status() == 200);
            turn.state().put(Key<uint64_t>("http-status", std::make_shared<U64Codec>()), uint64_t{200}); shared_.result = 2;
        }
    }
};
#ifdef TRANSIT_TEST_C_API
class Reader {
    std::unique_ptr<transit_station_http_reader, decltype(&transit_station_http_reader_destroy)> value_;
    bool complete_ = false;
public:
    explicit Reader(transit_station_http_reader *value) : value_(value, transit_station_http_reader_destroy) {}
    Reader(Reader &&) noexcept = default;
    Reader &operator=(Reader &&) noexcept = default;
    std::optional<HttpPart> read() {
        transit_station_http_part out{}; check(transit_station_http_read(value_.get(), &out)); complete_ = out.complete;
        if (!out.present) return {}; assert(out.size <= 256); return HttpPart{out.kind, Bytes(out.bytes, out.bytes + out.size), out.complete};
    }
    bool complete() const { return complete_; }
    void close() { check(transit_station_http_close(value_.get())); }
};
class Controller {
    http_test_context context_;
    std::unique_ptr<transit_station_runner, decltype(&transit_station_runner_destroy)> value_{nullptr, transit_station_runner_destroy};
public:
    Controller(const Config &cfg, const PreparedHttpRequest &request) : context_{{72, cfg.peer}, request.native(), nullptr, 0, {}, {}, static_cast<transit_station_http_followup_reason>(cfg.followup_reason)} {
        if (!cfg.outcome.empty()) { const auto outcome = decode(unhex(cfg.outcome)); context_.disposal = {outcome.native().resource, outcome.exchange()}; context_.parent = outcome.native(); }
        const auto config = cfg.service(); const auto settings = config.native(); const auto handler = http_test_handler(&context_); const auto codec = http_test_codec(&context_);
        const transit_station_options options{TRANSIT_FAILURE_STOP, TRANSIT_RECOVERY_FRESH_OWNERSHIP, nullptr, nullptr, nullptr}; transit_station_runner *out = nullptr;
        check(transit_station_runner_open(&settings, &handler, &codec, &options, &out)); value_.reset(out);
    }
    ~Controller() { value_.reset(); transit_station_turn_release(context_.escaped); }
    Event next() { transit_station_event *out = nullptr; check(transit_station_runner_next(value_.get(), &out)); return Event(out); }
    void close() { transit_station_event *out = nullptr; check(transit_station_runner_close(value_.get(), &out)); transit_station_event_destroy(out); }
    void stop() { transit_station_runner_stop(value_.get()); }
    Reader open(const HttpOutcome &outcome) { transit_station_http_reader *out = nullptr; check(transit_station_http_open(value_.get(), &outcome.native(), TRANSIT_HTTP_CAPTURED, &out)); return Reader(out); }
    unsigned result() const { return context_.result; }
    void expired(const PreparedHttpRequest &request) {
        bool ready = false; expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_http_stage(context_.escaped, request.native(), &ready)); });
        uint64_t correlation = 1; expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_http_release(context_.escaped, context_.peer, {72, 1}, 1, &correlation)); }); assert(correlation == 0);
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { check(transit_station_turn_http_followup(context_.escaped, context_.peer, &context_.parent, context_.followup_reason, request.native(), &correlation)); }); assert(correlation == 0);
    }
};
#else
using Reader = HttpReader;
class Controller {
    Shared shared_;
    Runner<HttpMessage<Bytes>> value_;
public:
    Controller(const Config &cfg, const PreparedHttpRequest &request) : value_(Runner<HttpMessage<Bytes>>::open(cfg.service(),
        std::make_unique<HttpHandler>(shared_, ProcessRef(72, cfg.peer), request, cfg.outcome, cfg.followup_reason), std::make_shared<HttpReplyCodec<Bytes>>(std::make_shared<HttpBytesCodec>(), 72), RunnerOptions::fresh_ownership())) {}
    Event next() { return value_.next(); }
    void close() { value_.close(); }
    void stop() { value_.stop(); }
    Reader open(const HttpOutcome &outcome) { return value_.open_http(outcome); }
    unsigned result() const { return shared_.result; }
    void expired(const PreparedHttpRequest &request) {
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->stage_http(request); });
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->release_http(ProcessRef(72, 1), ResourceRef(72, 1), 1); });
        expect(TRANSIT_SDK_TURN_EXPIRED, [&] { shared_.escaped->followup_http(ProcessRef(72, 1), HttpOutcome({}), HttpFollowupReason::Retry, request); });
    }
};
#endif
static void drive(const Config &cfg) {
    auto body = unhex(cfg.body); const auto request = prepare(cfg.resource, body, cfg.deadline, true); body.clear(); assert(request.body().size() == 513);
    auto runner = std::make_unique<Controller>(cfg, request); std::optional<Reader> reader; std::optional<HttpOutcome> outcome; Bytes owned;
    if (cfg.mode == "http-async") {
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
            outcome = decode(unhex(cfg.outcome)); reader = runner->open(*outcome);
            expect(TRANSIT_SDK_BUSY, [&] { runner->open(*outcome); }); const auto first = reader->read(); assert(first && !first->data.empty() && !first->complete); report("{\"prefix\":true}");
        } else if (line == "denied") {
            expect(TRANSIT_SDK_ACCESS_DENIED, [&] { reader->read(); }); report("{\"denied\":true}");
        } else if (line == "reopen") {
            expect(TRANSIT_SDK_READ_FAILED, [&] { reader->read(); }, "HttpReplayFailed"); reader->close(); reader->close(); reader = runner->open(*outcome);
            while (const auto part = reader->read()) { assert(part->data.size() <= 256); if (part->kind == TRANSIT_HTTP_RESPONSE_BODY) owned.insert(owned.end(), part->data.begin(), part->data.end()); }
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

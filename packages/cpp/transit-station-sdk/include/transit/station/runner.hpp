#pragma once
#include <transit/station.hpp>
#include <string_view>
namespace transit::sdk::station {
template<class T> struct Cast { T value; uint64_t position; Origin origin; };
template<class T> struct Call { T value; uint64_t position; Origin origin; uint64_t correlation; };
template<class T> struct Reply { T value; uint64_t position; Origin origin; uint64_t correlation; };
template<class T> using Incoming = std::variant<Cast<T>, Call<T>, Reply<T>>;
struct Control { InputKind kind; uint64_t position; Origin origin; uint64_t correlation; };
struct ResultComplete { uint64_t position; Origin origin; uint64_t correlation; };
template<class T> class Handler {
public:
    virtual ~Handler() = default;
    virtual void initialize(Turn &) {}
    virtual void handle(Turn &turn, const Incoming<T> &input) = 0;
    virtual void handle_control(Turn &, const Control &) { throw failure(TRANSIT_SDK_HANDLER_ERROR, "unhandled-control"); }
    virtual void handle_result(Turn &, const ResultComplete &) { throw failure(TRANSIT_SDK_HANDLER_ERROR, "unhandled-result"); }
};
class FrozenMutation {
    transit_station_mutation_info info_;
    Bytes bytes_;
public:
    explicit FrozenMutation(const transit_station_mutation *value) {
        check(transit_station_mutation_inspect(value, &info_)); transit_sdk_buffer bytes{};
        check(transit_station_mutation_export(value, &bytes)); bytes_ = Buffer(bytes).copy();
    }
    transit_station_mutation_info info() const { return info_; }
    Bytes export_bytes() const { return bytes_; }
};
class Event {
    std::unique_ptr<transit_station_event, decltype(&transit_station_event_destroy)> value_;
public:
    explicit Event(transit_station_event *value) : value_(value, transit_station_event_destroy) {}
    Event(Event &&) noexcept = default;
    Event &operator=(Event &&) noexcept = default;
    transit_station_event_info info() const { transit_station_event_info out{}; check(transit_station_event_inspect(value_.get(), &out)); return out; }
    std::optional<FrozenMutation> pending() const {
        transit_station_mutation *value = nullptr; check(transit_station_event_pending(value_.get(), &value));
        std::unique_ptr<transit_station_mutation, decltype(&transit_station_mutation_destroy)> owner(value, transit_station_mutation_destroy);
        if (!value) return {}; return FrozenMutation(value);
    }
};
class RecoveryStore {
public:
    virtual ~RecoveryStore() = default;
    virtual void before_dispatch(const FrozenMutation &mutation) = 0;
    virtual void confirmed(std::string_view identity, MutationReceipt receipt) = 0;
};
enum class FailurePolicy { Stop = TRANSIT_FAILURE_STOP, BlockInput = TRANSIT_FAILURE_BLOCK_INPUT };
struct RunnerOptions {
    FailurePolicy failure;
    std::shared_ptr<RecoveryStore> store;
    static RunnerOptions fresh_ownership(FailurePolicy failure = FailurePolicy::Stop) { return {failure, {}}; }
    static RunnerOptions persist(std::shared_ptr<RecoveryStore> store, FailurePolicy failure = FailurePolicy::Stop) {
        if (!store) throw station::failure(TRANSIT_SDK_INVALID_ARGUMENT, "recovery-store"); return {failure, std::move(store)};
    }
};
class ServiceConfig {
    ClientConfig client_;
    ProcessRef process_;
    Credential credential_;
    uint64_t generation_;
    std::string association_ = "data";
    bool queries_ = false;
public:
    ServiceConfig(ClientConfig client, ProcessRef process, uint64_t principal, uint64_t generation, std::string seed_file)
        : client_(std::move(client)), process_(process), credential_(process.realm(), principal, std::move(seed_file)), generation_(generation) {}
    ServiceConfig &association(std::string name) { association_ = checked_string(std::move(name)); return *this; }
    ServiceConfig &query_results(bool enabled = true) { queries_ = enabled; return *this; }
    transit_station_config native() const { return {client_.native(), process_.native(), credential_.native(), generation_, association_.c_str(), queries_}; }
};
template<class T> class Runner {
    struct Context {
        std::unique_ptr<Handler<T>> handler;
        std::shared_ptr<const Codec<T>> codec;
        RunnerOptions options;
    };
    std::unique_ptr<Context> context_;
    std::unique_ptr<transit_station_runner, decltype(&transit_station_runner_destroy)> value_;
    Runner(std::unique_ptr<Context> context, transit_station_runner *value) : context_(std::move(context)), value_(value, transit_station_runner_destroy) {}
public:
    Runner(Runner &&) noexcept = default;
    // Destroy the native runner before replacing callback storage.
    Runner &operator=(Runner &&other) noexcept {
        if (this != &other) { value_.reset(); context_ = std::move(other.context_); value_ = std::move(other.value_); }
        return *this;
    }
    static Runner open(const ServiceConfig &config, std::unique_ptr<Handler<T>> handler, std::shared_ptr<const Codec<T>> codec, RunnerOptions options) {
        if (!handler || !codec) throw failure(TRANSIT_SDK_INVALID_ARGUMENT, "runner-handlers");
        auto context = std::make_unique<Context>(Context{std::move(handler), std::move(codec), std::move(options)});
        transit_station_handler callbacks{context.get(),
            [](void *context, transit_station_turn *pointer) { return callback([&] { Turn turn(pointer); static_cast<Context *>(context)->handler->initialize(turn); }); },
            [](void *context, transit_station_turn *pointer, const transit_station_incoming *value) {
                return callback([&] { Turn turn(pointer); const auto &message = *static_cast<const T *>(value->value);
                    Incoming<T> input = value->kind == TRANSIT_INPUT_CAST ? Incoming<T>(Cast<T>{message, value->position, value->origin}) :
                        value->kind == TRANSIT_INPUT_CALL ? Incoming<T>(Call<T>{message, value->position, value->origin, value->correlation}) : Incoming<T>(Reply<T>{message, value->position, value->origin, value->correlation});
                    static_cast<Context *>(context)->handler->handle(turn, input); });
            },
            [](void *context, transit_station_turn *pointer, const transit_station_incoming *value) {
                return callback([&] { Turn turn(pointer); static_cast<Context *>(context)->handler->handle_control(turn, {value->kind, value->position, value->origin, value->correlation}); });
            },
            [](void *context, transit_station_turn *pointer, const transit_station_incoming *value) {
                return callback([&] { Turn turn(pointer); static_cast<Context *>(context)->handler->handle_result(turn, {value->position, value->origin, value->correlation}); });
            }};
        transit_station_options settings{static_cast<transit_station_failure_policy>(context->options.failure),
            context->options.store ? TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH : TRANSIT_RECOVERY_FRESH_OWNERSHIP, context.get(),
            [](void *context, const transit_station_mutation *mutation) { return callback([&] { static_cast<Context *>(context)->options.store->before_dispatch(FrozenMutation(mutation)); }); },
            [](void *context, const char *identity, transit_sdk_confirmation receipt) { return callback([&] { static_cast<Context *>(context)->options.store->confirmed(identity, receipt); }); }};
        auto native = config.native(); auto encoding = context->codec->native(); transit_station_runner *value = nullptr;
        check(transit_station_runner_open(&native, &callbacks, &encoding, &settings, &value)); return Runner(std::move(context), value);
    }
    Event next() { transit_station_event *event = nullptr; check(transit_station_runner_next(value_.get(), &event)); return Event(event); }
    Event reconcile() { transit_station_event *event = nullptr; check(transit_station_runner_reconcile(value_.get(), &event)); return Event(event); }
    Event evidence() { transit_station_event *event = nullptr; check(transit_station_runner_evidence(value_.get(), &event)); return Event(event); }
    Event close() { transit_station_event *event = nullptr; check(transit_station_runner_close(value_.get(), &event)); return Event(event); }
    void stop() const { transit_station_runner_stop(value_.get()); }
    DocumentReader documents() {
        transit_station_document_reader *out = nullptr;
        check(transit_station_documents_open(value_.get(), &out)); return DocumentReader(out);
    }
    std::optional<std::string> http_diagnostic(const HttpOutcome &outcome, ExchangeDiagnosticKind kind = ExchangeDiagnosticKind::CaptureFailure) {
        transit_sdk_diagnostic out{};
        check(transit_station_http_diagnostic(value_.get(), &outcome.native(), static_cast<transit_station_exchange_diagnostic_kind>(kind), &out));
        if (out.size == 0) return std::nullopt;
        return std::string(out.json, out.size);
    }
    HttpReader open_http(const HttpOutcome &outcome, HttpReplayPolicy policy = HttpReplayPolicy::Captured) {
        transit_station_http_reader *out = nullptr;
        check(transit_station_http_open(value_.get(), &outcome.native(), static_cast<transit_station_http_replay_policy>(policy), &out));
        return HttpReader(out);
    }
    std::optional<std::string> grpc_diagnostic(const GrpcOutcome &outcome, ExchangeDiagnosticKind kind = ExchangeDiagnosticKind::CaptureFailure) {
        transit_sdk_diagnostic out{};
        check(transit_station_grpc_diagnostic(value_.get(), &outcome.native(), static_cast<transit_station_exchange_diagnostic_kind>(kind), &out));
        if (out.size == 0) return std::nullopt;
        return std::string(out.json, out.size);
    }
    GrpcReader open_grpc(const GrpcOutcome &outcome, GrpcReplayPolicy policy = GrpcReplayPolicy::Captured) {
        transit_station_grpc_reader *out = nullptr;
        check(transit_station_grpc_open(value_.get(), &outcome.native(), static_cast<transit_station_grpc_replay_policy>(policy), &out));
        return GrpcReader(out);
    }
};
}

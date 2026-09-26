#include "internal.hpp"
using namespace transit::sdk::station_detail;
using namespace transit::sdk::internal;

struct RunnerState {
    Bridge bridge;
    transit_sdk_process process;
    transit_station_handler handler;
    transit_station_codec codec;
    transit_station_options options;
    std::atomic<bool> &stop;
    std::shared_ptr<const transit_station_mutation> pending;
    std::optional<Bytes> confirmed;
    bool paused = false, attempted = false;
    transit_station_event last;
    RunnerState(const transit_station_config &config, transit_station_handler handler_, transit_station_codec codec_, transit_station_options options_, std::atomic<bool> &stop_)
        : bridge(config, options_.failure), process(config.process), handler(handler_), codec(codec_), options(options_), stop(stop_) {
        codec_contract(codec, bridge.local.caps.message);
    }
    transit_station_event record(transit_station_event event) { last = event; return event; }
    transit_station_event pause(transit_sdk_error error, const char *phase, std::optional<transit_sdk_confirmation> receipt = {}) {
        transit_station_event event{}; event.info.kind = TRANSIT_EVENT_NEEDS_RECOVERY;
        event.pending = pending; event.info.input = pending->info.input; event.info.error = error;
        std::strncpy(event.info.phase, phase, sizeof(event.info.phase) - 1);
        if (receipt) { event.info.has_receipt = true; event.info.receipt = *receipt; }
        paused = true; return record(std::move(event));
    }
    transit_station_event accept() {
        auto &raw = bridge.local.raw; std::optional<transit_sdk_confirmation> receipt;
        const auto error = boundary([&] {
            const char *expected = pending->info.purpose == TRANSIT_MUTATION_PERMIT ? "permit" : pending->info.purpose == TRANSIT_MUTATION_OPEN ? "open" : "commit";
            if (raw.field(*confirmed, "confirmation/kind", true) != expected || raw.number(*confirmed, "confirmation/input") != pending->info.input)
                fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "confirmation-identity");
            receipt = transit_sdk_confirmation{raw.number(*confirmed, "confirmation/receipt/position")};
            if (options.recovery == TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH)
                callback_result(options.confirmed(options.context, pending->info.operation.identity, *receipt));
        });
        if (error.kind != TRANSIT_SDK_OK) return pause(error, "confirm", receipt);
        transit_station_event event{}; event.info.input = pending->info.input; event.info.has_receipt = true; event.info.receipt = *receipt;
        try {
            event.info.kind = raw.field(*confirmed, "event", true) == "blocked" ? TRANSIT_EVENT_BLOCKED :
                pending->info.purpose == TRANSIT_MUTATION_COMMIT ? TRANSIT_EVENT_COMMITTED : TRANSIT_EVENT_PROGRESS;
        } catch (...) { return pause(transit::sdk::internal::error(TRANSIT_SDK_UNKNOWN_OUTCOME, "confirmation-event"), "confirm", receipt); }
        pending.reset(); confirmed.reset(); paused = false; attempted = false; return record(std::move(event));
    }
    transit_station_event attempt() {
        require(pending != nullptr, "no-pending-mutation");
        if (confirmed) return accept();
        if (attempted) {
            const auto error = boundary([&] { confirmed = bridge.confirmation(*pending); });
            if (error.kind != TRANSIT_SDK_OK) return pause(error, "observe-confirmation");
            if (confirmed) return accept();
        }
        if (stop) return {};
        if (options.recovery == TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH) {
            const auto error = boundary([&] { callback_result(options.before_dispatch(options.context, pending.get())); });
            if (error.kind != TRANSIT_SDK_OK) return pause(error, "persist");
        }
        if (stop) return {};
        attempted = true;
        const auto error = boundary([&] { confirmed = bridge.dispatch(); });
        if (error.kind != TRANSIT_SDK_OK) return pause(error, "dispatch");
        return accept();
    }
    bool handle(const Bytes &event) {
        auto &raw = bridge.local.raw;
        const uint64_t scope = raw.number(event, "scope");
        const transit_station_turn_info info{process, {process.realm, raw.number(event, "resource")}, raw.number(event, "resource_revision", true), raw.boolean(event, "initializing")};
        auto input = incoming(raw, event, process.realm);
        std::unique_ptr<transit_station_turn, decltype(&transit_station_turn_release)> turn(new transit_station_turn(bridge, stop, scope, info, input), transit_station_turn_release);
        const auto error = boundary([&] {
            if (stop) return;
            std::unique_ptr<transit_station_value> value;
            if (input.kind <= TRANSIT_INPUT_REPLY) {
                value = decode(codec, unhex(raw.field(event, "input/payload", true), bridge.local.caps.message), bridge.local.caps.message);
                input.value = value->data;
            }
            if (info.initializing && handler.initialize) callback_result(handler.initialize(handler.context, turn.get()));
            if (stop) return;
            auto callback = input.kind <= TRANSIT_INPUT_REPLY ? handler.message : input.kind == TRANSIT_INPUT_RESULT_COMPLETE ? handler.result : handler.control;
            if (!callback) fail(TRANSIT_SDK_HANDLER_ERROR, "unhandled-input");
            callback_result(callback(handler.context, turn.get(), &input));
        });
        turn->active.store(false, std::memory_order_release);
        if (stop) { bridge.discard(scope); return false; }
        if (turn->poison.kind != TRANSIT_SDK_OK) { bridge.discard(scope); throw Failure{turn->poison}; }
        try { bridge.finish(scope, error.kind != TRANSIT_SDK_OK); }
        catch (const Failure &failure) {
            if (options.failure == TRANSIT_FAILURE_STOP && error.kind != TRANSIT_SDK_OK && !std::strcmp(failure.value.code, "ForeignHandlerFailure")) throw Failure{error};
            throw;
        }
        return true;
    }
    transit_station_event next() {
        if (paused) return last;
        if (stop) return {};
        if (pending) return attempt();
        for (size_t step = 0; step < 16; ++step) {
            if (stop) return {};
            const auto event = bridge.prepare(); const auto kind = bridge.local.raw.field(event, "event", true);
            if (kind == "pending") { pending = bridge.pending(event); return attempt(); }
            if (kind == "idle" || kind == "blocked") {
                transit_station_event value{}; value.info.kind = kind == "idle" ? TRANSIT_EVENT_IDLE : TRANSIT_EVENT_BLOCKED; return record(value);
            }
            if (kind == "ready") { if (!handle(event)) return {}; }
            else if (kind != "progress") fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "prepare-event");
        }
        transit_station_event event{}; event.info.kind = TRANSIT_EVENT_PROGRESS; return record(event);
    }
    transit_station_event evidence() const { auto event = last; event.pending = pending; return event; }
};
struct transit_station_runner {
    Worker worker;
    std::atomic<bool> stop{false};
    std::unique_ptr<RunnerState> state;
    transit_station_event closed;
    void close() {
        worker.check_close(); stop = true;
        worker.close([&] { if (state) closed = state->evidence(); state.reset(); });
    }
    ~transit_station_runner() { close(); }
};
extern "C" {
transit_sdk_error transit_station_runner_open(const transit_station_config *config, const transit_station_handler *handler, const transit_station_codec *codec, const transit_station_options *options, transit_station_runner **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] {
        require(config && handler && codec && options && out, "open-runner");
        require(options->failure == TRANSIT_FAILURE_STOP || options->failure == TRANSIT_FAILURE_BLOCK_INPUT, "failure-policy");
        require(options->recovery == TRANSIT_RECOVERY_FRESH_OWNERSHIP || options->recovery == TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH, "recovery-policy");
        require(options->recovery != TRANSIT_RECOVERY_PERSIST_BEFORE_DISPATCH || (options->before_dispatch && options->confirmed), "recovery-hooks");
        require(handler->message, "handler");
        auto runner = std::make_unique<transit_station_runner>();
        runner->worker.run([&] { runner->state = std::make_unique<RunnerState>(*config, *handler, *codec, *options, runner->stop); });
        *out = runner.release();
    });
}
transit_sdk_error transit_station_runner_next(transit_station_runner *runner, transit_station_event **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(runner && out, "runner-next"); runner->worker.run([&] { const auto event = runner->state->next(); *out = new transit_station_event(event); }); });
}
transit_sdk_error transit_station_runner_reconcile(transit_station_runner *runner, transit_station_event **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(runner && out, "runner-reconcile"); runner->worker.run([&] { const auto event = runner->state->attempt(); *out = new transit_station_event(event); }); });
}
void transit_station_runner_stop(transit_station_runner *runner) { if (runner) runner->stop = true; }
transit_sdk_error transit_station_runner_evidence(transit_station_runner *runner, transit_station_event **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(runner && out, "runner-evidence"); runner->worker.run([&] { *out = new transit_station_event(runner->state->evidence()); }); });
}
transit_sdk_error transit_station_runner_close(transit_station_runner *runner, transit_station_event **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] { require(runner && out, "close-runner"); runner->close(); *out = new transit_station_event(runner->closed); });
}
void transit_station_runner_destroy(transit_station_runner *runner) { Uninterruptible guard; delete runner; }
transit_sdk_error transit_station_event_inspect(const transit_station_event *event, transit_station_event_info *out) {
    return boundary([&] { require(event && out, "event"); *out = event->info; });
}
transit_sdk_error transit_station_event_pending(const transit_station_event *event, transit_station_mutation **out) {
    if (out) *out = nullptr;
    return boundary([&] { require(event && out, "event-pending"); if (event->pending) *out = new transit_station_mutation(*event->pending); });
}
void transit_station_event_destroy(transit_station_event *event) { delete event; }
transit_sdk_error transit_station_mutation_inspect(const transit_station_mutation *mutation, transit_station_mutation_info *out) {
    return boundary([&] { require(mutation && out, "mutation"); *out = mutation->info; });
}
transit_sdk_error transit_station_mutation_export(const transit_station_mutation *mutation, transit_sdk_buffer *out) {
    if (out) *out = {}; return boundary([&] { require(mutation && out, "mutation-export"); *out = owned(mutation->bytes); });
}
void transit_station_mutation_destroy(transit_station_mutation *mutation) { delete mutation; }
}

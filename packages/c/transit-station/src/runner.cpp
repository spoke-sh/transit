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
    std::atomic<size_t> references{1};
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
struct transit_station_http_reader {
    transit_station_runner *runner = nullptr;
    uint64_t identity = 0;
    bool complete = false, closed = false, failed = false;
};
static void runner_release(transit_station_runner *runner) {
    if (runner && runner->references.fetch_sub(1, std::memory_order_acq_rel) == 1) delete runner;
}
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
void transit_station_runner_destroy(transit_station_runner *runner) { Uninterruptible guard; if (runner) { runner->close(); runner_release(runner); } }
transit_sdk_error transit_station_http_open(transit_station_runner *runner, const transit_station_http_outcome *outcome, transit_station_http_replay_policy policy, transit_station_http_reader **out) {
    Uninterruptible guard; if (out) *out = nullptr;
    return boundary([&] {
        require(runner && outcome && out && !outcome->rejected && outcome->phase == TRANSIT_HTTP_OBSERVED && outcome->reference_size > 0 && outcome->reference_size <= sizeof(outcome->reference), "http-open");
        require(policy == TRANSIT_HTTP_CAPTURED || policy == TRANSIT_HTTP_REQUIRE_UNREDACTED, "http-replay-policy");
        auto reader = std::make_unique<transit_station_http_reader>();
        const auto action = "{\"open\":{\"reference\":" + quote(hex(copy({outcome->reference, outcome->reference_size}, 256))) +
            ",\"policy\":" + quote(policy == TRANSIT_HTTP_CAPTURED ? "captured" : "require_unredacted") + "}}";
        runner->worker.run([&] {
            auto &state = *runner->state;
            require(outcome->resource.realm == state.process.realm, "http-realm");
            if (state.pending) fail(TRANSIT_SDK_BUSY, "pending-mutation");
            const auto value = state.bridge.http_read(action);
            reader->identity = state.bridge.local.raw.number(value, "opened");
            runner->references.fetch_add(1, std::memory_order_relaxed); reader->runner = runner;
        });
        *out = reader.release();
    });
}
transit_sdk_error transit_station_http_read(transit_station_http_reader *reader, transit_station_http_part *out) {
    Uninterruptible guard; if (out) *out = {};
    return boundary([&] {
        require(reader && out, "http-reader");
        reader->runner->worker.run([&] {
            if (reader->closed) fail(TRANSIT_SDK_CLOSED, "http-reader");
            if (reader->failed) {
                auto value = error(TRANSIT_SDK_READ_FAILED, "http-reader");
                std::strncpy(value.code, "HttpReplayFailed", sizeof(value.code) - 1); throw Failure{value};
            }
            auto &state = *reader->runner->state;
            if (state.pending) fail(TRANSIT_SDK_BUSY, "pending-mutation");
            // Host response allocation/materialization failure also invalidates
            // this reader, so subsequent calls cannot skip undisclosed bytes.
            reader->failed = true;
            const auto value = state.bridge.http_read("{\"next\":" + decimal(reader->identity) + "}");
            auto &raw = state.bridge.local.raw; transit_station_http_part part{};
            if (raw.field(value, "part") == "null") {
                if (!reader->complete) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-incomplete");
                part.complete = true;
            } else {
                const char *kinds[] = {"request_template", "request_head", "request_body", "response_head", "response_body", "response_trailers", "timing", "omission", "completion"};
                const auto kind = raw.field(value, "part/kind", true);
                size_t index = 0; for (; index < 9 && kind != kinds[index]; ++index) {}
                if (index == 9) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-part-kind");
                const auto bytes = unhex(raw.field(value, "part/bytes", true), sizeof(part.bytes));
                part.present = true; part.kind = static_cast<transit_station_http_part_kind>(index);
                part.complete = raw.boolean(value, "part/complete"); part.size = bytes.size();
                std::copy(bytes.begin(), bytes.end(), part.bytes);
            }
            *out = part; reader->complete = part.complete; reader->failed = false;
        });
    });
}
transit_sdk_error transit_station_http_close(transit_station_http_reader *reader) {
    Uninterruptible guard;
    return boundary([&] {
        require(reader, "http-reader");
        reader->runner->worker.run([&] {
            if (reader->closed) return;
            auto &state = *reader->runner->state;
            if (state.pending) fail(TRANSIT_SDK_BUSY, "pending-mutation");
            const auto value = state.bridge.http_read("{\"close\":" + decimal(reader->identity) + "}");
            if (!state.bridge.local.raw.boolean(value, "closed")) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE, "http-close");
            reader->closed = true;
        });
    });
}
void transit_station_http_reader_destroy(transit_station_http_reader *reader) {
    Uninterruptible guard;
    if (!reader) return;
    (void)transit_station_http_close(reader);
    auto *runner = reader->runner; delete reader; runner_release(runner);
}
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

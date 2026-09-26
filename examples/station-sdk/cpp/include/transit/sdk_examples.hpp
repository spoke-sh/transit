#pragma once
#include <transit/station.hpp>
#include <transit/sdk_examples.h>
#include <functional>
#include <limits>

namespace transit::sdk::examples {
using namespace station;
struct Add { uint64_t value; };
struct Read {};
struct Start {};
struct Total { uint64_t value; };
using CounterMessage = std::variant<Add, Read>;
using RequesterMessage = std::variant<Start, Total>;
struct Initialize {};
struct Insert { int64_t key; std::optional<int64_t> value; };
struct Rows {};
struct QueryStart {};
using QueryMessage = std::variant<Initialize, Insert, Rows>;

// This is the application's C codec library, independent of native Transit ABI.
template<class T, class Wire> class ApplicationCodec : public Codec<T> {
protected:
    virtual transit_station_codec application_codec() const noexcept = 0;
    virtual Wire to_wire(const T &) const = 0;
    virtual T from_wire(const Wire &) const = 0;
public:
    const char *type_id() const noexcept override { return application_codec().type_id; }
    uint32_t version() const noexcept override { return application_codec().version; }
    size_t max_encoded_bytes() const noexcept override { return application_codec().max_encoded_bytes; }
    Bytes encode(const T &value) const override {
        const auto codec = application_codec(); const auto wire = to_wire(value); Bytes bytes(codec.max_encoded_bytes); size_t written = 0;
        check(codec.encode(codec.context, &wire, bytes.data(), bytes.size(), &written)); bytes.resize(written); return bytes;
    }
    T decode(const Bytes &value) const override {
        const auto codec = application_codec(); Wire wire{}; check(codec.decode(codec.context, bytes_view(value), &wire)); return from_wire(wire);
    }
};
class CounterCodec final : public ApplicationCodec<CounterMessage, transit_counter_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_counter_codec(); }
    transit_counter_message to_wire(const CounterMessage &value) const override {
        if (auto add = std::get_if<Add>(&value)) return {TRANSIT_COUNTER_ADD, add->value}; return {TRANSIT_COUNTER_READ, 0};
    }
    CounterMessage from_wire(const transit_counter_message &value) const override {
        if (value.tag == TRANSIT_COUNTER_ADD) return Add{value.value}; return Read{};
    }
};
class RequesterCodec final : public ApplicationCodec<RequesterMessage, transit_counter_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_requester_codec(); }
    transit_counter_message to_wire(const RequesterMessage &value) const override {
        if (auto total = std::get_if<Total>(&value)) return {TRANSIT_COUNTER_TOTAL, total->value}; return {TRANSIT_COUNTER_START, 0};
    }
    RequesterMessage from_wire(const transit_counter_message &value) const override {
        if (value.tag == TRANSIT_COUNTER_TOTAL) return Total{value.value}; return Start{};
    }
};
class TotalCodec final : public ApplicationCodec<Total, transit_counter_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_total_codec(); }
    transit_counter_message to_wire(const Total &value) const override { return {TRANSIT_COUNTER_TOTAL, value.value}; }
    Total from_wire(const transit_counter_message &value) const override { return {value.value}; }
};
class U64Codec final : public ApplicationCodec<uint64_t, uint64_t> {
    transit_station_codec application_codec() const noexcept override { return transit_example_u64_codec(); }
    uint64_t to_wire(const uint64_t &value) const override { return value; }
    uint64_t from_wire(const uint64_t &value) const override { return value; }
};
class QueryCodec final : public ApplicationCodec<QueryMessage, transit_query_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_query_codec(); }
    transit_query_message to_wire(const QueryMessage &value) const override {
        if (auto insert = std::get_if<Insert>(&value)) return {TRANSIT_QUERY_INSERT, insert->key, insert->value.has_value(), insert->value.value_or(0)};
        return {std::holds_alternative<Rows>(value) ? TRANSIT_QUERY_ROWS : TRANSIT_QUERY_INITIALIZE, 0, false, 0};
    }
    QueryMessage from_wire(const transit_query_message &value) const override {
        if (value.tag == TRANSIT_QUERY_INSERT) return Insert{value.key, value.has_value ? std::optional<int64_t>(value.value) : std::nullopt};
        if (value.tag == TRANSIT_QUERY_ROWS) return Rows{}; return Initialize{};
    }
};
class QueryStartCodec final : public ApplicationCodec<QueryStart, transit_query_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_query_start_codec(); }
    transit_query_message to_wire(const QueryStart &) const override { return {TRANSIT_QUERY_START, 0, false, 0}; }
    QueryStart from_wire(const transit_query_message &) const override { return {}; }
};
inline const auto u64_codec = std::make_shared<U64Codec>();
inline const Key<uint64_t> total_key("total", u64_codec), request_key("request", u64_codec), observed_key("observed", u64_codec);
inline const TableSchema<int64_t> table_schema(1);
inline Error unexpected() { return failure(TRANSIT_SDK_HANDLER_ERROR, "unexpected-example-message"); }
class Counter : public Handler<CounterMessage> {
public:
    void initialize(Turn &turn) override { turn.state().put(total_key, uint64_t{0}); }
    void handle(Turn &turn, const Incoming<CounterMessage> &input) override {
        if (auto cast = std::get_if<Cast<CounterMessage>>(&input)) {
            if (auto add = std::get_if<Add>(&cast->value)) {
                auto total = turn.state().require(total_key); if (UINT64_MAX - total < add->value) throw unexpected();
                total += add->value; turn.state().put(total_key, total); return;
            }
        }
        if (auto call = std::get_if<Call<CounterMessage>>(&input)) {
            if (std::holds_alternative<Read>(call->value)) { turn.reply(Total{turn.state().require(total_key)}, TotalCodec{}); return; }
        }
        throw unexpected();
    }
};
class Requester : public Handler<RequesterMessage> {
    ProcessRef peer_;
public:
    explicit Requester(ProcessRef peer) : peer_(peer) {}
    void handle(Turn &turn, const Incoming<RequesterMessage> &input) override {
        if (auto cast = std::get_if<Cast<RequesterMessage>>(&input)) {
            if (std::holds_alternative<Start>(cast->value)) {
                if (turn.state().find(request_key)) throw unexpected();
                auto correlation = turn.call(peer_, CounterMessage(Read{}), CounterCodec{});
                turn.state().put(request_key, correlation); return;
            }
        }
        if (auto reply = std::get_if<Reply<RequesterMessage>>(&input)) {
            if (auto total = std::get_if<Total>(&reply->value)) {
                turn.require_reply(peer_, turn.state().require(request_key)); turn.state().put(observed_key, total->value); return;
            }
        }
        throw unexpected();
    }
};
class TableService : public Handler<QueryMessage> {
    ProcessRef requester_;
public:
    explicit TableService(ProcessRef requester) : requester_(requester) {}
    void initialize(Turn &turn) override { turn.create_table(table_schema); turn.allow_query(requester_, table_schema, 0, true); }
    void handle(Turn &turn, const Incoming<QueryMessage> &input) override {
        if (auto cast = std::get_if<Cast<QueryMessage>>(&input)) {
            if (std::holds_alternative<Initialize>(cast->value)) return;
            if (auto insert = std::get_if<Insert>(&cast->value)) { turn.table(table_schema).insert({insert->key, insert->value}); return; }
        }
        if (auto call = std::get_if<Call<QueryMessage>>(&input)) {
            if (std::holds_alternative<Rows>(call->value)) { QueryPlan plan; plan.limit = UINT64_MAX; turn.table(table_schema).start_query(plan); return; }
        }
        throw unexpected();
    }
};
class QueryRequester : public Handler<QueryStart> {
    ProcessRef source_;
    std::function<void(IpcSegment)> consume_;
public:
    QueryRequester(ProcessRef source, std::function<void(IpcSegment)> consume) : source_(source), consume_(std::move(consume)) {}
    void handle(Turn &turn, const Incoming<QueryStart> &input) override {
        if (!std::holds_alternative<Cast<QueryStart>>(input) || turn.state().find(request_key)) throw unexpected();
        auto correlation = turn.call(source_, QueryMessage(Rows{}), QueryCodec{}); turn.state().put(request_key, correlation);
    }
    void handle_result(Turn &turn, const ResultComplete &input) override {
        auto reader = turn.result(input.correlation); const auto manifest = reader.manifest();
        if (manifest.correlation != turn.state().require(request_key) || manifest.source.realm != source_.realm() || manifest.source.pid != source_.pid()) throw unexpected();
        // Consumer effects happen during a private turn; supply application idempotency.
        for (uint64_t ordinal = 0; ordinal < manifest.segments; ++ordinal) consume_(reader.segment(ordinal));
        turn.state().put(observed_key, manifest.rows);
    }
};
}

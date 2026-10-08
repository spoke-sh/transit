#pragma once
#include <transit/station.hpp>
#include <transit/sdk_examples.h>
#include <functional>
#include <limits>
#include <iomanip>
#include <sstream>

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
struct Advance {};
struct NotReady {};
struct Update { int64_t key; std::optional<int64_t> value; };
struct Delete { int64_t key; };
using QueryStart = std::variant<Start, NotReady>;
using QueryMessage = std::variant<Initialize, Insert, Rows, Advance, Update, Delete>;

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
public:
    transit_station_codec application_codec() const noexcept override { return transit_example_query_codec(); }
    transit_query_message to_wire(const QueryMessage &value) const override {
        if (auto insert = std::get_if<Insert>(&value)) return {TRANSIT_QUERY_INSERT, insert->key, insert->value.has_value(), insert->value.value_or(0)};
        if (auto update = std::get_if<Update>(&value)) return {TRANSIT_QUERY_UPDATE, update->key, update->value.has_value(), update->value.value_or(0)};
        if (auto remove = std::get_if<Delete>(&value)) return {TRANSIT_QUERY_DELETE, remove->key, false, 0};
        return {std::holds_alternative<Rows>(value) ? TRANSIT_QUERY_ROWS : std::holds_alternative<Advance>(value) ? TRANSIT_QUERY_ADVANCE : TRANSIT_QUERY_INITIALIZE, 0, false, 0};
    }
    QueryMessage from_wire(const transit_query_message &value) const override {
        if (value.tag == TRANSIT_QUERY_INSERT) return Insert{value.key, value.has_value ? std::optional<int64_t>(value.value) : std::nullopt};
        if (value.tag == TRANSIT_QUERY_UPDATE) return Update{value.key, value.has_value ? std::optional<int64_t>(value.value) : std::nullopt};
        if (value.tag == TRANSIT_QUERY_DELETE) return Delete{value.key};
        if (value.tag == TRANSIT_QUERY_ADVANCE) return Advance{};
        if (value.tag == TRANSIT_QUERY_ROWS) return Rows{}; return Initialize{};
    }
};
class QueryStartCodec final : public ApplicationCodec<QueryStart, transit_query_message> {
    transit_station_codec application_codec() const noexcept override { return transit_example_query_start_codec(); }
    transit_query_message to_wire(const QueryStart &value) const override { return {std::holds_alternative<Start>(value) ? TRANSIT_QUERY_START : TRANSIT_QUERY_NOT_READY, 0, false, 0}; }
    QueryStart from_wire(const transit_query_message &value) const override { if (value.tag == TRANSIT_QUERY_NOT_READY) return NotReady{}; return Start{}; }
};
inline const auto u64_codec = std::make_shared<U64Codec>();
inline const Key<uint64_t> total_key("total", u64_codec), request_key("request", u64_codec), observed_key("observed", u64_codec);
inline logical::Cell signed_cell(int64_t value) { return logical::Cell(transit_example_signed(value)); }
inline const TableSchema table_schema = [] {
    const auto schema = transit_example_table();
    std::vector<catalog::Column> columns;
    for (size_t i=0;i<schema.column_count;++i) { const auto &c=schema.columns[i]; columns.push_back({c.id,c.name,logical::Type(*c.type),c.nullable,c.default_value?std::optional<logical::Cell>(logical::Cell(*c.default_value)):std::nullopt,{}}); }
    return TableSchema{schema.object,schema.revision,schema.next_column,std::move(columns),{1}};
}();
inline const TableLimits table_limits{65536,8388608,1024};
using TableQueue = transit_example_table_queue;
using TableWork = transit_example_table_work;
using TableOutcome = transit_example_table_outcome;
template<class T, transit_station_codec (*Factory)()> class TableRecordCodec final : public ApplicationCodec<T,T> {
    transit_station_codec application_codec() const noexcept override { return Factory(); }
    T to_wire(const T &value) const override { return value; }
    T from_wire(const T &value) const override { return value; }
};
inline const auto queue_codec=std::make_shared<TableRecordCodec<TableQueue,transit_example_table_queue_codec>>();
inline const auto work_codec=std::make_shared<TableRecordCodec<TableWork,transit_example_table_work_codec>>();
inline const auto outcome_codec=std::make_shared<TableRecordCodec<TableOutcome,transit_example_table_outcome_codec>>();
inline const Key<TableQueue> metadata_key("table.queue",queue_codec);
inline const Key<uint64_t> not_ready_key("not-ready",u64_codec);
inline std::string table_key(const char *prefix,uint64_t identity) { std::ostringstream name; name<<prefix<<std::hex<<std::setfill('0')<<std::setw(16)<<identity; return name.str(); }
inline Key<TableWork> work_key(uint64_t identity) { return Key<TableWork>(table_key("table.work.",identity),work_codec); }
inline Key<TableOutcome> outcome_key(uint64_t identity) { return Key<TableOutcome>(table_key("table.done.",identity),outcome_codec); }
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
    static TableQueue queue(Turn &turn) { auto found=turn.state().find(metadata_key); return found?*found:TableQueue{}; }
    static void wake(Turn &turn) { auto p=turn.info().process; turn.cast(ProcessRef(p.realm,p.pid),QueryMessage(Advance{}),QueryCodec{}); }
    static void enqueue(Turn &turn,uint64_t identity,const QueryMessage &command) {
        if(!identity || identity>((uint64_t{1}<<53)-1)) throw unexpected(); auto q=queue(turn); const bool empty=q.head==0;
        if(turn.state().find(work_key(identity)) || turn.state().find(outcome_key(identity))) throw unexpected();
        if(q.tail) {
            if(identity<=q.tail) throw unexpected(); auto previous=turn.state().require(work_key(q.tail)); if(previous.next) throw unexpected();
            previous.next=identity; turn.state().put(work_key(q.tail),previous);
        } else if(!q.ready && !std::holds_alternative<Initialize>(command)) {
            turn.state().put(work_key(UINT64_MAX),TableWork{identity,{TRANSIT_QUERY_INITIALIZE,0,false,0}}); q.head=UINT64_MAX;
        } else q.head=identity;
        turn.state().put(work_key(identity),TableWork{0,QueryCodec{}.to_wire(command)}); q.tail=identity; turn.state().put(metadata_key,q); if(empty) wake(turn);
    }
    static std::optional<TableOutcome> step(Turn &turn,const TableQueue &q,const QueryMessage &command) {
        if(std::holds_alternative<Initialize>(command)) {
            auto status=turn.create_table(table_schema,table_limits); if(status.state==TableCreationState::Building) return {};
            return TableOutcome{0,status.admitted_input,status.completed_input.value(),0,0,0};
        }
        if(!q.ready || q.head==UINT64_MAX) throw unexpected();
        const auto wire=QueryCodec{}.to_wire(command);
        const catalog::Predicate predicate{catalog::Compare{1,catalog::CompareOp::Eq,logical::Atom(signed_cell(wire.key).native().as.value.as.atom)}};
        const auto value=wire.has_value?signed_cell(wire.value):logical::Cell::null();
        TableMutationSpec mutation;
        if(wire.tag==TRANSIT_QUERY_INSERT) mutation=TableInsert{{{{1,signed_cell(wire.key)},{2,value}}}};
        else if(wire.tag==TRANSIT_QUERY_UPDATE) mutation=TableUpdate{{{2,value}},predicate};
        else if(wire.tag==TRANSIT_QUERY_DELETE) mutation=TableDelete{predicate}; else throw unexpected();
        const auto resource=turn.info().resource;
        auto status=TableMutation::prepare(ResourceRef(resource.realm,resource.resource),0,q.head,table_schema,mutation).step(turn);
        if(status.state==TableMutationState::Building) return {};
        return TableOutcome{static_cast<uint8_t>(status.state),status.admitted_input,status.completed_input.value(),status.counts?status.counts->matched:0,status.counts?status.counts->changed:0,static_cast<uint8_t>(status.rejection)};
    }
    void drive(Turn &turn) const {
        auto q=queue(turn); if(!q.head) return; const auto work=turn.state().require(work_key(q.head));
        if((work.next==0)!=(q.head==q.tail) || (work.next && q.head!=UINT64_MAX && work.next<=q.head)) throw unexpected();
        const auto command=QueryCodec{}.from_wire(work.command); auto outcome=step(turn,q,command); const bool initialize=std::holds_alternative<Initialize>(command);
        if(!outcome || turn.budgets().mutations<3u+(initialize&&!q.ready?1u:0u)) { wake(turn); return; }
        if(initialize&&!q.ready) turn.allow_query(requester_,1,0,true);
        turn.state().put(outcome_key(q.head),*outcome); turn.state().erase(work_key(q.head)); q.head=work.next; if(!work.next) q.tail=0; q.ready=q.ready||initialize;
        turn.state().put(metadata_key,q); if(work.next) wake(turn);
    }
public:
    explicit TableService(ProcessRef requester) : requester_(requester) {}
    void handle(Turn &turn,const Incoming<QueryMessage> &input) override {
        if(auto cast=std::get_if<Cast<QueryMessage>>(&input)) {
            if(std::holds_alternative<Advance>(cast->value)) {
                const auto p=turn.info().process; if(cast->origin.kind!=TRANSIT_ORIGIN_PROCESS || cast->origin.process.realm!=p.realm || cast->origin.process.pid!=p.pid) throw unexpected(); drive(turn); return;
            }
            if(!std::holds_alternative<Rows>(cast->value)) { enqueue(turn,cast->position,cast->value); return; }
        }
        if(auto call=std::get_if<Call<QueryMessage>>(&input)) if(std::holds_alternative<Rows>(call->value)) {
            auto q=queue(turn); if(!q.ready || q.head) { turn.reply(QueryStart(NotReady{}),QueryStartCodec{}); return; }
            unified::Plan plan; plan.projection={0,1,2,3}; plan.limit=UINT64_MAX; turn.start_query(1,QueryPlan(plan)); return;
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
        if(auto reply=std::get_if<Reply<QueryStart>>(&input)) {
            if(!std::holds_alternative<NotReady>(reply->value)) throw unexpected();
            turn.require_reply(source_,turn.state().require(request_key)); turn.state().put(not_ready_key,reply->correlation); return;
        }
        const auto cast=std::get_if<Cast<QueryStart>>(&input); if(!cast || !std::holds_alternative<Start>(cast->value)) throw unexpected();
        auto previous=turn.state().find(request_key),busy=turn.state().find(not_ready_key); if(previous && (!busy || *previous!=*busy)) throw unexpected();
        auto correlation = turn.call(source_, QueryMessage(Rows{}), QueryCodec{}); turn.state().put(request_key, correlation); if(busy) turn.state().erase(not_ready_key);
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

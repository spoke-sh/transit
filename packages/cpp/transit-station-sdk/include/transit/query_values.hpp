#pragma once
#include <transit/station_values.hpp>
#include <transit/logical.hpp>
#include <transit/unified_query.h>
#include <array>
#include <optional>
namespace transit::sdk::station {
enum class Aggregate { Rows = TRANSIT_AGGREGATE_ROWS, Count = TRANSIT_AGGREGATE_COUNT, Sum = TRANSIT_AGGREGATE_SUM, CountValues = TRANSIT_AGGREGATE_COUNT_VALUES };
enum class Comparison { Eq, Ne, Lt, Le, Gt, Ge };
struct All {};
namespace unified {
enum class State { Missing, Null, TypeError, Value, Conflict };
using Scalar = logical::Atom;
struct IsState { uint8_t column; State state; };
struct Compare { uint8_t column; Comparison comparison; Scalar value; };
using PredicateAtom = std::variant<All, IsState, Compare>;
enum class PredicateOperator { Negate, Conjunction, Disjunction };
using PredicateInstruction = std::variant<PredicateAtom, PredicateOperator>;
struct PredicateProgram { std::vector<PredicateInstruction> instructions; };
struct Plan {
    std::vector<uint8_t> projection;
    std::variant<All, IsState, Compare, PredicateProgram> predicate;
    Aggregate aggregate = Aggregate::Rows;
    std::optional<uint64_t> limit;
    std::optional<std::vector<std::optional<std::string>>> output_names;
};
namespace detail {
inline transit_station_unified_scalar scalar(const Scalar &value) { return value.native(); }
template<class T> inline transit_station_unified_predicate_atom atom(const T &p) {
    transit_station_unified_predicate_atom out{};
    if constexpr (std::is_same_v<T, IsState>) { out.kind=TRANSIT_UNIFIED_IS_STATE; out.column=p.column; out.state=static_cast<transit_station_unified_state>(p.state); }
    else if constexpr (std::is_same_v<T, Compare>) { out.kind=TRANSIT_UNIFIED_COMPARE; out.column=p.column; out.comparison=static_cast<transit_station_comparison>(p.comparison); out.value=scalar(p.value); }
    else static_assert(std::is_same_v<T, All>);
    return out;
}
// Pointers borrow Plan's owned values and this view's bounded instruction array.
// The view cannot move while the synchronous C operation uses those pointers.
struct PlanView {
    transit_station_unified_plan value{};
    std::array<transit_station_unified_instruction,64> instructions{};
    PlanView(const PlanView &) = delete;
    explicit PlanView(const Plan &v) {
        value.projection=v.projection.data(); value.projection_count=v.projection.size();
        if(v.output_names){
            if(v.output_names->size()!=v.projection.size() || v.output_names->size()>128)throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"query-output-names");
            for(size_t i=0;i<v.output_names->size();++i)if((*v.output_names)[i]){checked_string(*(*v.output_names)[i]);value.output_names[i]=(*v.output_names)[i]->c_str();}
        }
        value.aggregate=static_cast<transit_station_aggregate>(v.aggregate);
        value.has_limit=v.limit.has_value(); value.limit=v.limit.value_or(0);
        std::visit([&](const auto &p) {
            using P=std::decay_t<decltype(p)>;
            if constexpr(std::is_same_v<P, PredicateProgram>){
                if(p.instructions.empty() || p.instructions.size()>instructions.size())throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"query-program-bound");
                value.predicate=TRANSIT_UNIFIED_PROGRAM; value.instruction_count=p.instructions.size(); value.instructions=instructions.data();
                for(size_t i=0;i<p.instructions.size();++i)std::visit([&](const auto &instruction){
                    using I=std::decay_t<decltype(instruction)>;
                    if constexpr(std::is_same_v<I,PredicateAtom>){
                        instructions[i].kind=TRANSIT_UNIFIED_ATOM;
                        instructions[i].atom=std::visit([](const auto &a){return atom(a);},instruction);
                    }else {
                        switch(instruction){
                            case PredicateOperator::Negate: instructions[i].kind=TRANSIT_UNIFIED_NEGATE;break;
                            case PredicateOperator::Conjunction: instructions[i].kind=TRANSIT_UNIFIED_CONJUNCTION;break;
                            case PredicateOperator::Disjunction: instructions[i].kind=TRANSIT_UNIFIED_DISJUNCTION;break;
                            default: throw failure(TRANSIT_SDK_INVALID_ARGUMENT,"query-program-instruction");
                        }
                    }
                },p.instructions[i]);
            }else {
                const auto a=atom(p); value.predicate=a.kind; value.column=a.column; value.state=a.state; value.comparison=a.comparison; value.value=a.value;
            }
        },v.predicate);
    }
};
}
}
// Copy the plan to freeze caller edits before the handler dispatches it.
class QueryPlan {
    unified::Plan value_;
public:
    explicit QueryPlan(unified::Plan value) : value_(std::move(value)) {}
    const unified::Plan &value() const { return value_; }
};
}

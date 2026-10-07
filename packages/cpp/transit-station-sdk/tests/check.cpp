#include <transit/station.hpp>
#include <transit/unified_query.hpp>
#include <transit/catalog.hpp>
#include <transit/logical.hpp>
#include <cassert>
using namespace transit::sdk;
using namespace transit::sdk::station;
static_assert(!std::is_copy_constructible_v<Runner<uint64_t>>);
static_assert(!std::is_copy_constructible_v<Table<int64_t>>);
static_assert(!std::is_copy_constructible_v<unified::Client>);
static_assert(!std::is_copy_constructible_v<unified::Prepared>);
static_assert(std::is_move_constructible_v<unified::Page>);
static_assert(!std::is_copy_constructible_v<catalog::Client>);
static_assert(!std::is_copy_constructible_v<catalog::Compiled>);
static_assert(!std::is_copy_constructible_v<catalog::Prepared>);
static_assert(std::is_move_constructible_v<catalog::Prepared>);
static_assert(std::is_copy_constructible_v<Turn>); // Copies retain scope checks, not native authority.
static_assert(std::is_copy_constructible_v<logical::Type>);
static_assert(std::is_copy_constructible_v<logical::Cell>);
template class transit::sdk::station::Runner<uint64_t>;
template class transit::sdk::station::Table<int64_t>;
template class transit::sdk::station::Table<bool>;
template class transit::sdk::station::Table<std::string>;
template class transit::sdk::station::Table<Bytes>;
int main() {
    TableSchema<int64_t> schema(1); assert(schema.native().value_type == TRANSIT_CELL_INT64);
    Cell value = INT64_MIN; assert(native_cell(value).integer == INT64_MIN);
    auto options = RunnerOptions::fresh_ownership(); assert(!options.store);
    auto descriptor = logical::Type::structure({{"value", logical::Type::scalar(TRANSIT_LOGICAL_INT128), true, false}});
    assert(logical::Type::decode(descriptor.encode()).fields()[0].type.kind() == TRANSIT_LOGICAL_INT128);
    auto nested = logical::Cell::list({logical::Cell::atom(logical::Atom::unsigned_integer(UINT64_MAX)), logical::Cell::null()});
    assert(logical::Cell::decode(nested.encode()).children().size() == 2);
}

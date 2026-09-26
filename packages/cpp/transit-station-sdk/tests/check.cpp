#include <transit/station.hpp>
#include <cassert>
using namespace transit::sdk;
using namespace transit::sdk::station;
static_assert(!std::is_copy_constructible_v<Runner<uint64_t>>);
static_assert(!std::is_copy_constructible_v<Table<int64_t>>);
static_assert(std::is_copy_constructible_v<Turn>); // Copies retain scope checks, not native authority.
template class transit::sdk::station::Runner<uint64_t>;
template class transit::sdk::station::Table<int64_t>;
template class transit::sdk::station::Table<bool>;
template class transit::sdk::station::Table<std::string>;
template class transit::sdk::station::Table<Bytes>;
int main() {
    TableSchema<int64_t> schema(1); assert(schema.native().value_type == TRANSIT_CELL_INT64);
    Cell value = INT64_MIN; assert(native_cell(value).integer == INT64_MIN);
    auto options = RunnerOptions::fresh_ownership(); assert(!options.store);
}

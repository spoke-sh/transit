#pragma once
#include <transit/logical.h>
#include "logical_json.hpp"

namespace transit::sdk::logical_detail {
// Allocations are owned by one immutable result. Views never retain input
// pointers or a native client. Counts are validated before allocating arrays.
class Arena {
    struct Allocation { virtual ~Allocation() = default; };
    template<class T> struct Block final : Allocation { std::vector<T> values; explicit Block(size_t size) : values(size) {} };
    std::vector<std::unique_ptr<Allocation>> allocations;
public:
    template<class T> T *array(size_t count) {
        if (!count) return nullptr;
        auto block = std::make_unique<Block<T>>(count); auto *out = block->values.data();
        allocations.push_back(std::move(block)); return out;
    }
    transit_sdk_bytes bytes(std::string_view value) {
        auto *out = array<uint8_t>(value.size()); if (!value.empty()) std::copy(value.begin(), value.end(), out); return {out, value.size()};
    }
    transit_sdk_bytes bytes(const Bytes &value) { return bytes({reinterpret_cast<const char *>(value.data()), value.size()}); }
};
struct Budget {
    size_t nodes = 0, data = 0, names = 0, max_nodes;
    explicit Budget(size_t maximum) : max_nodes(maximum) {}
    void enter(size_t depth) { require(depth < 16 && nodes < max_nodes, "logical-node-budget"); ++nodes; }
    void bytes(size_t size) { require(size <= 1048576 - data, "logical-data-budget"); data += size; }
    void name(size_t size) { require(size <= 4096 - names, "logical-name-budget"); names += size; }
};
const char *kind_name(transit_logical_kind kind);
transit_logical_kind kind_from(const std::string &name);
Json type_json(const transit_logical_type_view &, Budget &, size_t depth);
Json cell_json(const transit_logical_cell_view &, Budget &, size_t depth);
Json atom_json(const transit_logical_atom &, Budget &);
transit_logical_type_view type_from(const Json &, Arena &, Budget &, size_t depth);
transit_logical_cell_view cell_from(const Json &, Arena &, Budget &, size_t depth);
transit_logical_atom atom_from(const Json &, Arena &, Budget &);
inline Json type_json(const transit_logical_type_view &value) { Budget b(256); return type_json(value, b, 0); }
inline Json cell_json(const transit_logical_cell_view &value) { Budget b(65536); return cell_json(value, b, 0); }
inline Json atom_json(const transit_logical_atom &value) { Budget b(65536); return atom_json(value, b); }
inline transit_logical_type_view type_from(const Json &v, Arena &a) { Budget b(256); return type_from(v, a, b, 0); }
inline transit_logical_cell_view cell_from(const Json &v, Arena &a) { Budget b(65536); return cell_from(v, a, b, 0); }
std::string wide(uint64_t value);
uint64_t wide(const Json &, bool zero = true);
}
struct transit_logical_type { transit::sdk::logical_detail::Arena arena; transit_logical_type_view value{}; };
struct transit_logical_cell { transit::sdk::logical_detail::Arena arena; transit_logical_cell_view value{}; };

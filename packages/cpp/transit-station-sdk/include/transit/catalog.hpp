#pragma once
#include <transit/station.hpp>
#include <transit/catalog.h>

namespace transit::sdk::station::catalog {
enum class Type { Int64, Boolean, Utf8, Binary };
enum class Observation { Pending, Processed };
enum class Outcome { Applied, NameConflict, ObjectConflict, TableConflict };
enum class Origin { External, Process, Effect };
enum class DispositionOutcome { Initialized, PolicyApplied, InvalidCommand, Denied, IdentityConflict, StalePolicy };
struct Scope { ResourceRef resource; uint64_t catalog; };
struct Connection { ProcessRef owner; Scope scope; };
struct Configuration { Scope scope; ProcessRef owner; uint64_t administrator; };
struct Schema { std::array<std::string,2> names; Type value_type; };
struct CreateTable { Scope scope; uint64_t operation, object; uint32_t table; std::string name; Schema schema; };
struct Policy { Scope scope; uint64_t principal, revision; bool inspect, create; };
struct PolicyChange { uint64_t expected_revision; Policy policy; };
struct Capabilities {
    uint8_t version; std::string definition; bool initialize, create_table, conditional_policy, current_metadata;
    uint16_t max_saved_bytes; uint8_t table_columns;
};
struct Description { Configuration configuration; Policy policy; uint64_t resource_revision; };
struct TableSource { uint32_t table; Schema schema; };
struct Definition { Scope scope; uint64_t object, revision; std::string name; TableSource source; uint64_t principal, operation, input; };
struct Cursor { std::string definition; Scope scope; uint64_t resource_revision; std::string after; };
struct Page { uint64_t resource_revision; std::vector<Definition> entries; std::optional<Cursor> next; };
struct Receipt { CreateTable request; uint64_t principal, input; Outcome outcome; std::string diagnostic; };
struct Disposition { Scope scope; Origin origin; uint64_t principal, input; std::array<uint8_t,32> payload; DispositionOutcome outcome; std::string diagnostic; };
namespace detail {
inline void invalid() { transit_sdk_error error{};error.kind=TRANSIT_SDK_INVALID_ARGUMENT;throw Error(error); }
inline transit_station_cell_kind type(Type v) {
    switch(v) {
        case Type::Int64:return TRANSIT_CELL_INT64;case Type::Boolean:return TRANSIT_CELL_BOOLEAN;
        case Type::Utf8:return TRANSIT_CELL_UTF8;case Type::Binary:return TRANSIT_CELL_BINARY;
    }
    invalid();return TRANSIT_CELL_NULL;
}
inline void name(const std::string &v,char (&out)[17]) {
    checked_string(v);if(v.empty() || v.size()>16)invalid();std::copy(v.begin(),v.end(),out);
}
inline transit_station_catalog_scope native(const Scope &v) { return {v.resource.native(),v.catalog}; }
inline Scope from(transit_station_catalog_scope v) { return {ResourceRef(v.resource.realm,v.resource.resource),v.catalog}; }
inline transit_station_catalog_configuration native(const Configuration &v) { return {native(v.scope),v.owner.native(),v.administrator}; }
inline Configuration from(const transit_station_catalog_configuration &v) { return {from(v.scope),ProcessRef(v.owner.realm,v.owner.pid),v.administrator}; }
inline transit_station_catalog_policy native(const Policy &v) { return {native(v.scope),v.principal,v.revision,v.inspect,v.create}; }
inline Policy from(const transit_station_catalog_policy &v) { return {from(v.scope),v.principal,v.revision,v.inspect,v.create}; }
inline transit_station_catalog_create_table native(const CreateTable &v) {
    transit_station_catalog_create_table out{};out.scope=native(v.scope);out.operation=v.operation;out.object=v.object;out.table=v.table;
    name(v.name,out.name);for(size_t i=0;i<2;++i)name(v.schema.names[i],out.schema.names[i]);out.schema.value_type=type(v.schema.value_type);return out;
}
inline CreateTable from(const transit_station_catalog_create_table &v) {
    return {from(v.scope),v.operation,v.object,v.table,v.name,{{v.schema.names[0],v.schema.names[1]},static_cast<Type>(v.schema.value_type-1)}};
}
inline Definition from(const transit_station_catalog_definition &v) {
    return {from(v.scope),v.object,v.revision,v.name,{v.source.table,{{v.source.schema.names[0],v.source.schema.names[1]},static_cast<Type>(v.source.schema.value_type-1)}},v.principal,v.operation,v.input};
}
inline transit_station_catalog_cursor native(const Cursor &v) {
    transit_station_catalog_cursor out{};checked_string(v.definition);if(v.definition.size()!=64)invalid();
    std::copy(v.definition.begin(),v.definition.end(),out.definition);out.scope=native(v.scope);out.resource_revision=v.resource_revision;name(v.after,out.after);return out;
}
inline Cursor from(const transit_station_catalog_cursor &v) { return {v.definition,from(v.scope),v.resource_revision,v.after}; }
}
class Compiled {
    std::unique_ptr<transit_station_catalog_compiled,decltype(&transit_station_catalog_compiled_destroy)> value_;
public:
    explicit Compiled(transit_station_catalog_compiled *v):value_(v,transit_station_catalog_compiled_destroy){}
    Compiled(Compiled &&) noexcept = default;
    Compiled &operator=(Compiled &&) noexcept = default;
    static Compiled recover(const CreateTable &request,const Bytes &canonical) {
        auto value=detail::native(request);transit_station_catalog_compiled *out=nullptr;
        check(transit_station_catalog_compiled_import(&value,bytes_view(canonical),&out));return Compiled(out);
    }
    CreateTable request() const {
        transit_station_catalog_create_table request{};transit_sdk_bytes bytes{};
        check(transit_station_catalog_compiled_get(value_.get(),&request,&bytes));return detail::from(request);
    }
    Bytes canonical() const {
        transit_station_catalog_create_table request{};transit_sdk_bytes bytes{};
        check(transit_station_catalog_compiled_get(value_.get(),&request,&bytes));return copy_bytes(bytes);
    }
};
class Prepared {
    std::unique_ptr<transit_station_catalog_prepared,decltype(&transit_station_catalog_prepared_destroy)> value_;
public:
    explicit Prepared(transit_station_catalog_prepared *v):value_(v,transit_station_catalog_prepared_destroy){}
    Prepared(Prepared &&) noexcept = default;
    Prepared &operator=(Prepared &&) noexcept = default;
    static Prepared recover(const Bytes &bytes) {
        transit_station_catalog_prepared *out=nullptr;check(transit_station_catalog_prepared_import(bytes_view(bytes),&out));return Prepared(out);
    }
    Bytes data() const { transit_sdk_bytes out{};check(transit_station_catalog_prepared_bytes(value_.get(),&out));return copy_bytes(out); }
    const transit_station_catalog_prepared *native() const { return value_.get(); }
};
class Client {
    std::unique_ptr<transit_station_catalog_client,decltype(&transit_station_catalog_client_destroy)> value_;
    explicit Client(transit_station_catalog_client *v):value_(v,transit_station_catalog_client_destroy){}
public:
    Client(Client &&) noexcept = default;
    Client &operator=(Client &&) noexcept = default;
    static Client open(const ClientConfig &config,const Credential &credential,const Connection &connection) {
        const auto cfg=config.native();const auto identity=credential.native();transit_station_catalog_client *out=nullptr;
        check(transit_station_catalog_open(&cfg,&identity,{connection.owner.native(),detail::native(connection.scope)},&out));return Client(out);
    }
    Capabilities capabilities() {
        transit_station_catalog_capabilities out{};check(transit_station_catalog_capabilities_read(value_.get(),&out));
        return {out.version,out.definition,out.initialize,out.create_table,out.conditional_policy,out.current_metadata,out.max_saved_bytes,out.table_columns};
    }
    Description describe() {
        transit_station_catalog_description out{};check(transit_station_catalog_describe(value_.get(),&out));return {detail::from(out.configuration),detail::from(out.policy),out.resource_revision};
    }
    std::optional<Definition> lookup(const std::string &name) {
        checked_string(name);transit_station_catalog_definition out{};check(transit_station_catalog_lookup(value_.get(),name.c_str(),&out));if(!out.found)return {};return detail::from(out);
    }
    std::optional<Definition> definition(uint64_t object,uint64_t revision) {
        transit_station_catalog_definition out{};check(transit_station_catalog_definition_read(value_.get(),object,revision,&out));if(!out.found)return {};return detail::from(out);
    }
    Page list(const std::optional<Cursor> &cursor={}) {
        transit_station_catalog_cursor previous{};if(cursor)previous=detail::native(*cursor);
        transit_station_catalog_page out{};check(transit_station_catalog_list(value_.get(),cursor?&previous:nullptr,&out));
        Page result{out.resource_revision,{}, {}};result.entries.reserve(out.count);
        for(size_t i=0;i<out.count;++i)result.entries.push_back(detail::from(out.entries[i]));
        if(out.has_next)result.next=detail::from(out.next);return result;
    }
    Compiled compile_sql(const std::string &sql,uint64_t operation,uint64_t object,uint32_t table) {
        checked_string(sql);transit_station_catalog_compiled *out=nullptr;check(transit_station_catalog_compile_sql(value_.get(),sql.c_str(),operation,object,table,&out));return Compiled(out);
    }
    Prepared prepare_initialize(const Configuration &configuration) {
        const auto value=detail::native(configuration);transit_station_catalog_prepared *out=nullptr;check(transit_station_catalog_prepare_initialize(value_.get(),&value,&out));return Prepared(out);
    }
    Prepared prepare_create(const CreateTable &request) {
        const auto value=detail::native(request);transit_station_catalog_prepared *out=nullptr;check(transit_station_catalog_prepare_create(value_.get(),&value,&out));return Prepared(out);
    }
    Prepared prepare_policy(const PolicyChange &change) {
        const transit_station_catalog_policy_change value{change.expected_revision,detail::native(change.policy)};transit_station_catalog_prepared *out=nullptr;check(transit_station_catalog_prepare_policy(value_.get(),&value,&out));return Prepared(out);
    }
    uint64_t submit(const Prepared &prepared) { uint64_t out=0;check(transit_station_catalog_submit(value_.get(),prepared.native(),&out));return out; }
    Observation observe(const Prepared &prepared,uint64_t input) {
        transit_station_catalog_observation out{};check(transit_station_catalog_observe(value_.get(),prepared.native(),input,&out));return static_cast<Observation>(out);
    }
    std::optional<Disposition> input_disposition(const Prepared &prepared,uint64_t input) {
        transit_station_catalog_disposition out{};check(transit_station_catalog_input_disposition(value_.get(),prepared.native(),input,&out));if(!out.found)return {};
        Disposition result{detail::from(out.scope),static_cast<Origin>(out.origin),out.principal,out.input,{},static_cast<DispositionOutcome>(out.outcome),std::string(out.diagnostic.json,out.diagnostic.size)};
        std::copy_n(out.payload,32,result.payload.begin());return result;
    }
    std::optional<Receipt> status(const CreateTable &original) {
        const auto request=detail::native(original);transit_station_catalog_receipt out{};check(transit_station_catalog_status_read(value_.get(),&request,&out));if(!out.found)return {};
        return Receipt{detail::from(out.request),out.principal,out.input,static_cast<Outcome>(out.outcome),std::string(out.diagnostic.json,out.diagnostic.size)};
    }
    void close() { check(transit_station_catalog_close(value_.get())); }
};
}

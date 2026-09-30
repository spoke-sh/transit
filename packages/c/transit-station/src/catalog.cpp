#include "internal.hpp"
#include <transit/catalog.h>
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

struct transit_station_catalog_compiled { transit_station_catalog_create_table request{}; Bytes canonical; };
struct transit_station_catalog_prepared { Bytes bytes; };
namespace {
using Scope = transit_station_catalog_scope;
using Configuration = transit_station_catalog_configuration;
using Schema = transit_station_catalog_schema;
using Request = transit_station_catalog_create_table;
using Policy = transit_station_catalog_policy;
using Definition = transit_station_catalog_definition;
using Cursor = transit_station_catalog_cursor;
using Page = transit_station_catalog_page;
bool same_scope(Scope a,Scope b) { return a.catalog==b.catalog && a.resource.realm==b.resource.realm && a.resource.resource==b.resource.resource; }
std::string scope_wire(Scope v) {
    counter(v.resource.realm); counter(v.resource.resource); require(v.catalog, "catalog-id");
    return "{\"realm\":"+decimal(v.resource.realm)+",\"resource\":"+decimal(v.resource.resource)+",\"catalog\":"+quote(decimal(v.catalog))+"}";
}
std::string configuration_wire(const Configuration &v) {
    process(v.owner); counter(v.administrator); require(v.owner.realm==v.scope.resource.realm,"catalog-realm");
    return "{\"scope\":"+scope_wire(v.scope)+",\"owner\":"+decimal(v.owner.pid)+",\"administrator\":"+decimal(v.administrator)+"}";
}
std::string name(const char *value) { auto result=text(value,16); require(!result.empty(),"catalog-name"); return result; }
std::string catalog_name(const char *value) {
    auto result=name(value);const auto letter=[](char c){return (c>='A'&&c<='Z') || (c>='a'&&c<='z') || c=='_';};
    require(letter(result.front()),"catalog-name");
    for(const auto c:result)require(letter(c) || (c>='0'&&c<='9'),"catalog-name");return result;
}
void metadata_name(const char *value) {
    try{catalog_name(value);}catch(const Failure &){fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-metadata-name");}
}
std::string cursor_wire(const Cursor &v) {
    require(text(v.definition,64)==STATION_ABI_DEFINITION,"catalog-cursor-definition");counter(v.resource_revision);
    return "{\"definition\":"+quote(v.definition)+",\"scope\":"+scope_wire(v.scope)+",\"resource_revision\":"+decimal(v.resource_revision)+",\"after\":"+quote(catalog_name(v.after))+"}";
}
std::string request_wire(const Request &v) {
    require(v.operation && v.object && v.table,"catalog-request-id");
    return "{\"scope\":"+scope_wire(v.scope)+",\"operation\":"+quote(decimal(v.operation))+",\"object\":"+quote(decimal(v.object))+
        ",\"table\":"+decimal(v.table)+",\"name\":"+quote(name(v.name))+",\"schema\":{\"names\":["+quote(name(v.schema.names[0]))+","+quote(name(v.schema.names[1]))+
        "],\"value_type\":"+quote(cell_name(v.schema.value_type))+"}}";
}
std::string policy_wire(const Policy &v) {
    counter(v.principal,true); require(v.revision,"catalog-policy-revision");
    return "{\"scope\":"+scope_wire(v.scope)+",\"principal\":"+decimal(v.principal)+",\"revision\":"+quote(decimal(v.revision))+
        ",\"inspect\":"+(v.inspect?"true":"false")+",\"create\":"+(v.create?"true":"false")+"}";
}
size_t variant(const std::string &value,std::initializer_list<const char *> names) {
    size_t index=0; for(const auto *candidate:names){if(value==candidate)return index;++index;}
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-variant");
}
uint64_t full(const Raw &r,const Bytes &v,const std::string &p) {
    const auto value=wide(r,v,p);
    if(!value || r.field(v,p)!=quote(decimal(value))) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-u64");
    return value;
}
template<size_t N> void string_field(const Raw &r,const Bytes &v,const std::string &p,char (&out)[N]) {
    const auto value=r.field(v,p,true);
    if(value.empty() || value.size()>=N || value.find('\0')!=std::string::npos || r.field(v,p)!=quote(value))
        fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-name");
    std::copy(value.begin(),value.end(),out);
}
Scope parse_scope(const Raw &r,const Bytes &v,const std::string &p) {
    return {{r.number(v,p+"/realm"),r.number(v,p+"/resource")},full(r,v,p+"/catalog")};
}
Configuration parse_configuration(const Raw &r,const Bytes &v,const std::string &p) {
    const auto scope=parse_scope(r,v,p+"/scope");
    return {scope,{scope.resource.realm,r.number(v,p+"/owner")},r.number(v,p+"/administrator")};
}
Policy parse_policy(const Raw &r,const Bytes &v,const std::string &p) {
    return {parse_scope(r,v,p+"/scope"),r.number(v,p+"/principal",true),full(r,v,p+"/revision"),r.boolean(v,p+"/inspect"),r.boolean(v,p+"/create")};
}
Request parse_request(const Raw &r,const Bytes &v,const std::string &p) {
    Request out{}; out.scope=parse_scope(r,v,p+"/scope"); out.operation=full(r,v,p+"/operation"); out.object=full(r,v,p+"/object");
    const auto table=r.number(v,p+"/table"); if(table>UINT32_MAX)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-table");out.table=static_cast<uint32_t>(table);
    string_field(r,v,p+"/name",out.name);
    const auto names=r.field(v,p+"/schema/names");
    if(names.empty() || names.front()!='[' || exists(r,v,p+"/schema/names/2"))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-schema");
    for(size_t i=0;i<2;++i)string_field(r,v,p+"/schema/names/"+decimal(i),out.schema.names[i]);
    out.schema.value_type=static_cast<transit_station_cell_kind>(1+variant(r.field(v,p+"/schema/value_type",true),{"int64","boolean","utf8","binary"}));
    return out;
}
Definition parse_definition(const Raw &r,const Bytes &v,const std::string &p,Scope scope) {
    Definition out{};if(r.field(v,p)=="null")return out;
    out.scope=parse_scope(r,v,p+"/scope");if(!same_scope(out.scope,scope))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-definition-scope");
    out.object=full(r,v,p+"/object");out.revision=full(r,v,p+"/revision");out.operation=full(r,v,p+"/operation");
    string_field(r,v,p+"/name",out.name);metadata_name(out.name);
    out.principal=r.number(v,p+"/principal",true);out.input=r.number(v,p+"/input");
    const auto table=r.number(v,p+"/source/table/id");if(table>UINT32_MAX)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-table");out.source.table=static_cast<uint32_t>(table);
    const auto schema=p+"/source/table/schema";const auto names=r.field(v,schema+"/names");
    if(names.empty() || names.front()!='[' || exists(r,v,schema+"/names/2"))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-schema");
    for(size_t i=0;i<2;++i){string_field(r,v,schema+"/names/"+decimal(i),out.source.schema.names[i]);metadata_name(out.source.schema.names[i]);}
    if(std::string(out.source.schema.names[0])==out.source.schema.names[1])fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-schema");
    out.source.schema.value_type=static_cast<transit_station_cell_kind>(1+variant(r.field(v,schema+"/value_type",true),{"int64","boolean","utf8","binary"}));
    out.found=true;return out;
}
Cursor parse_cursor(const Raw &r,const Bytes &v,const std::string &p) {
    Cursor out{};string_field(r,v,p+"/definition",out.definition);
    if(std::string(out.definition)!=STATION_ABI_DEFINITION)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-cursor-definition");
    out.scope=parse_scope(r,v,p+"/scope");out.resource_revision=r.number(v,p+"/resource_revision");string_field(r,v,p+"/after",out.after);metadata_name(out.after);return out;
}
Page parse_page(const Raw &r,const Bytes &v,Scope scope,const Cursor *previous) {
    Page out{};out.resource_revision=r.number(v,"page/resource_revision");const auto slots=r.field(v,"page/entries");
    if(slots.empty() || slots.front()!='[' || exists(r,v,"page/entries/8"))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-page-size");
    bool ended=false;
    for(size_t i=0;i<8;++i){const auto entry=parse_definition(r,v,"page/entries/"+decimal(i),scope);
        if(!entry.found){ended=true;continue;}
        if(ended || (out.count && std::string(out.entries[out.count-1].name)>=entry.name))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-page-order");
        out.entries[out.count++]=entry;
    }
    if(r.field(v,"page/next")!="null"){
        out.next=parse_cursor(r,v,"page/next");out.has_next=true;
        if(!out.count || !same_scope(out.next.scope,scope) || out.next.resource_revision!=out.resource_revision || std::string(out.next.after)!=out.entries[out.count-1].name)
            fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-page-next");
    }
    if(previous && (out.resource_revision!=previous->resource_revision || (out.count && std::string(out.entries[0].name)<=previous->after)))
        fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-page-continuation");
    return out;
}
transit_station_catalog_capabilities capabilities(const Raw &r,const Bytes &v) {
    transit_station_catalog_capabilities out{};
    if(r.number(v,"capabilities/version")!=1 || r.field(v,"capabilities/definition",true)!=STATION_ABI_DEFINITION ||
        r.number(v,"capabilities/max_saved_bytes")!=8192 || r.number(v,"capabilities/table_columns")!=2)
        fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-capabilities");
    out.version=1; string_field(r,v,"capabilities/definition",out.definition);out.max_saved_bytes=8192;out.table_columns=2;
    out.initialize=r.boolean(v,"capabilities/initialize");out.create_table=r.boolean(v,"capabilities/create_table");
    out.conditional_policy=r.boolean(v,"capabilities/conditional_policy");out.current_metadata=r.boolean(v,"capabilities/current_metadata");
    return out;
}
struct NativeCatalog {
    Local local;
    std::unique_ptr<station_catalog_client,decltype(&::station_catalog_destroy)> handle;
    Scope scope;
    NativeCatalog(const transit_sdk_config &config,const transit_sdk_credential &identity,transit_station_catalog_connection c)
        :local(config.native_directory),handle(nullptr,local.station_catalog_destroy),scope(c.scope) {
        if(config.sdk_version!=TRANSIT_SDK_VERSION)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-sdk-version");
        credential(identity);process(c.owner);require(identity.realm==c.owner.realm && c.owner.realm==c.scope.resource.realm,"catalog-connection");
        const auto url=text(config.url,2048);
        const auto settings="{\"connection\":{\"scope\":"+scope_wire(c.scope)+",\"owner\":"+decimal(c.owner.pid)+",\"principal\":"+decimal(identity.principal)+"},\"timeout_ms\":"+decimal(config.timeout_ms)+"}";
        Seed seed(identity.seed_file);station_catalog_client *pointer=nullptr;
        const auto status=local.station_catalog_create(STATION_ABI_VERSION,reinterpret_cast<const uint8_t*>(url.data()),url.size(),seed.data(),reinterpret_cast<const uint8_t*>(settings.data()),settings.size(),&pointer);
        handle.reset(pointer);local.raw.check(status,{},"open-catalog");require(pointer,"catalog-handle");
        const auto caps=capabilities(local.raw,call("{\"capabilities\":{}}"));
        if(!caps.initialize || !caps.create_table || !caps.conditional_policy || !caps.current_metadata)fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY,"catalog-capabilities");
    }
    Bytes call(const std::string &action,bool mutation=false) {
        require(action.size()<=TRANSIT_CLIENT_MAX_BODY,"catalog-action-bound");station_buffer *buffer=nullptr;
        const auto status=local.station_catalog_call(handle.get(),reinterpret_cast<const uint8_t*>(action.data()),action.size(),&buffer);
        return local.result(status,buffer,"catalog-action",mutation);
    }
};
std::unique_ptr<transit_station_catalog_prepared> prepare(NativeCatalog &n,const std::string &action) {
    const auto v=n.call(action);const auto data=n.local.raw.field(v,"prepared",true);
    if(data.empty() || data.size()>8192)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-prepared");
    return std::make_unique<transit_station_catalog_prepared>(transit_station_catalog_prepared{Bytes(data.begin(),data.end())});
}
std::string saved(const transit_station_catalog_prepared *v) {
    require(v && !v->bytes.empty(),"catalog-prepared");return quote(std::string(v->bytes.begin(),v->bytes.end()));
}
std::string input_action(const char *tag,const transit_station_catalog_prepared *v,uint64_t input) {
    counter(input);return "{"+quote(tag)+":{\"prepared\":"+saved(v)+",\"input\":"+decimal(input)+"}}";
}
}
struct transit_station_catalog_client {
    Worker worker;std::unique_ptr<NativeCatalog> native;
    ~transit_station_catalog_client(){worker.close([&]{native.reset();});}
};
namespace {
template<class F> transit_sdk_error run(transit_station_catalog_client *owner,F &&work) {
    return boundary([&]{require(owner,"catalog-client");owner->worker.run([&]{require(bool(owner->native),"catalog-client");work(*owner->native);});});
}
}
extern "C" {
transit_sdk_error transit_station_catalog_compiled_import(const Request *request,transit_sdk_bytes data,transit_station_catalog_compiled **out) {
    if(out)*out=nullptr;return boundary([&]{require(out && request && data.size,"catalog-compiled");request_wire(*request);*out=new transit_station_catalog_compiled{*request,copy(data,256)};});
}
transit_sdk_error transit_station_catalog_compiled_get(const transit_station_catalog_compiled *v,Request *request,transit_sdk_bytes *canonical) {
    if(request)*request={};if(canonical)*canonical={};return boundary([&]{require(v && request && canonical,"catalog-compiled");*request=v->request;*canonical=view(v->canonical);});
}
void transit_station_catalog_compiled_destroy(transit_station_catalog_compiled *v){delete v;}
transit_sdk_error transit_station_catalog_prepared_import(transit_sdk_bytes data,transit_station_catalog_prepared **out) {
    if(out)*out=nullptr;return boundary([&]{require(out && data.size,"catalog-prepared");*out=new transit_station_catalog_prepared{copy(data,8192)};});
}
transit_sdk_error transit_station_catalog_prepared_bytes(const transit_station_catalog_prepared *v,transit_sdk_bytes *out) {
    if(out)*out={};return boundary([&]{require(v && out,"catalog-prepared");*out=view(v->bytes);});
}
void transit_station_catalog_prepared_destroy(transit_station_catalog_prepared *v){delete v;}
transit_sdk_error transit_station_catalog_open(const transit_sdk_config *config,const transit_sdk_credential *identity,transit_station_catalog_connection connection,transit_station_catalog_client **out) {
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(config && identity && out,"catalog-open");auto owner=std::make_unique<transit_station_catalog_client>();owner->worker.run([&]{owner->native=std::make_unique<NativeCatalog>(*config,*identity,connection);});*out=owner.release();});
}
transit_sdk_error transit_station_catalog_close(transit_station_catalog_client *v) {
    Uninterruptible guard;return boundary([&]{require(v,"catalog-client");v->worker.close([&]{v->native.reset();});});
}
void transit_station_catalog_client_destroy(transit_station_catalog_client *v){Uninterruptible guard;delete v;}
transit_sdk_error transit_station_catalog_capabilities_read(transit_station_catalog_client *client,transit_station_catalog_capabilities *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-capabilities");*out=capabilities(n.local.raw,n.call("{\"capabilities\":{}}"));});
}
transit_sdk_error transit_station_catalog_describe(transit_station_catalog_client *client,transit_station_catalog_description *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-description");const auto v=n.call("{\"describe\":{}}");const auto &r=n.local.raw;
        const transit_station_catalog_description result{parse_configuration(r,v,"description/configuration"),parse_policy(r,v,"description/policy"),r.number(v,"description/resource_revision",true)};*out=result;});
}
transit_sdk_error transit_station_catalog_lookup(transit_station_catalog_client *client,const char *name,Definition *out) {
    Uninterruptible guard;char input[17]{};if(name)for(size_t i=0;i<17;++i){input[i]=name[i];if(!name[i])break;}
    if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-definition");const auto expected=catalog_name(name?input:nullptr);
        const auto v=n.call("{\"lookup\":"+quote(expected)+"}");const auto result=parse_definition(n.local.raw,v,"definition",n.scope);
        if(result.found && result.name!=expected)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-definition-name");*out=result;});
}
transit_sdk_error transit_station_catalog_definition_read(transit_station_catalog_client *client,uint64_t object,uint64_t revision,Definition *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(out && object && revision,"catalog-definition");
        const auto v=n.call("{\"definition\":{\"object\":"+quote(decimal(object))+",\"revision\":"+quote(decimal(revision))+"}}");const auto result=parse_definition(n.local.raw,v,"definition",n.scope);
        if(result.found && (result.object!=object || result.revision!=revision))fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-definition-identity");*out=result;});
}
transit_sdk_error transit_station_catalog_list(transit_station_catalog_client *client,const Cursor *cursor,Page *out) {
    Uninterruptible guard;const Cursor input=cursor?*cursor:Cursor{};
    if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-page");const auto v=n.call("{\"list\":"+(cursor?cursor_wire(input):"null")+"}");*out=parse_page(n.local.raw,v,n.scope,cursor?&input:nullptr);});
}
transit_sdk_error transit_station_catalog_compile_sql(transit_station_catalog_client *client,const char *sql,uint64_t operation,uint64_t object,uint32_t table,transit_station_catalog_compiled **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeCatalog &n){require(out && operation && object && table,"catalog-compile");const auto statement=text(sql,4096);require(!statement.empty(),"catalog-sql");
        const auto v=n.call("{\"compile\":{\"sql\":"+quote(statement)+",\"operation\":"+quote(decimal(operation))+",\"object\":"+quote(decimal(object))+",\"table\":"+decimal(table)+"}}");
        auto result=std::make_unique<transit_station_catalog_compiled>();result->request=parse_request(n.local.raw,v,"compiled/request");result->canonical=unhex(n.local.raw.field(v,"compiled/canonical",true),256);
        if(result->canonical.empty())fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-canonical");*out=result.release();});
}
transit_sdk_error transit_station_catalog_prepare_initialize(transit_station_catalog_client *client,const Configuration *value,transit_station_catalog_prepared **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeCatalog &n){require(value && out,"catalog-initialize");*out=prepare(n,"{\"prepare_initialize\":"+configuration_wire(*value)+"}").release();});
}
transit_sdk_error transit_station_catalog_prepare_create(transit_station_catalog_client *client,const Request *value,transit_station_catalog_prepared **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeCatalog &n){require(value && out,"catalog-create");*out=prepare(n,"{\"prepare_create\":"+request_wire(*value)+"}").release();});
}
transit_sdk_error transit_station_catalog_prepare_policy(transit_station_catalog_client *client,const transit_station_catalog_policy_change *value,transit_station_catalog_prepared **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeCatalog &n){require(value && out,"catalog-policy");*out=prepare(n,"{\"prepare_policy\":{\"expected_revision\":"+quote(decimal(value->expected_revision))+",\"policy\":"+policy_wire(value->policy)+"}}").release();});
}
transit_sdk_error transit_station_catalog_submit(transit_station_catalog_client *client,const transit_station_catalog_prepared *value,uint64_t *out) {
    Uninterruptible guard;if(out)*out=0;return run(client,[&](NativeCatalog &n){require(out,"catalog-submit");const auto v=n.call("{\"submit\":"+saved(value)+"}",true);
        try{const auto position=n.local.raw.number(v,"receipt/position");if(n.local.raw.field(v,"")!="{\"receipt\":{\"position\":"+decimal(position)+"}}")fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-receipt");*out=position;}
        catch(...){fail(TRANSIT_SDK_UNKNOWN_OUTCOME,"catalog-receipt");}});
}
transit_sdk_error transit_station_catalog_observe(transit_station_catalog_client *client,const transit_station_catalog_prepared *value,uint64_t input,transit_station_catalog_observation *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-observe");const auto v=n.call(input_action("observe",value,input));*out=static_cast<transit_station_catalog_observation>(variant(n.local.raw.field(v,"observation",true),{"pending","processed"}));});
}
transit_sdk_error transit_station_catalog_input_disposition(transit_station_catalog_client *client,const transit_station_catalog_prepared *value,uint64_t input,transit_station_catalog_disposition *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(out,"catalog-disposition");const auto v=n.call(input_action("input_disposition",value,input));const auto &r=n.local.raw;if(r.field(v,"disposition")=="null")return;
        transit_station_catalog_disposition result{};result.found=true;result.scope=parse_scope(r,v,"disposition/scope");result.principal=r.number(v,"disposition/principal",true);result.input=r.number(v,"disposition/input");
        result.origin=static_cast<transit_station_catalog_origin>(variant(r.field(v,"disposition/origin",true),{"external","process","effect"}));
        result.outcome=static_cast<transit_station_catalog_disposition_outcome>(variant(r.field(v,"disposition/outcome",true),{"initialized","policy_applied","invalid_command","denied","identity_conflict","stale_policy"}));
        const auto payload=unhex(r.field(v,"disposition/payload",true),32);if(payload.size()!=32)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-payload");std::copy(payload.begin(),payload.end(),result.payload);*out=result;});
}
transit_sdk_error transit_station_catalog_status_read(transit_station_catalog_client *client,const Request *original,transit_station_catalog_receipt *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeCatalog &n){require(original && out,"catalog-status");const auto expected=request_wire(*original);const auto v=n.call("{\"status\":"+expected+"}");const auto &r=n.local.raw;if(r.field(v,"status")=="null")return;
        transit_station_catalog_receipt result{};result.found=true;result.request=parse_request(r,v,"status/request");if(request_wire(result.request)!=expected)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"catalog-original-request");
        result.principal=r.number(v,"status/principal",true);result.input=r.number(v,"status/input");result.outcome=static_cast<transit_station_catalog_outcome>(variant(r.field(v,"status/outcome",true),{"applied","name_conflict","object_conflict","table_conflict"}));*out=result;});
}
}

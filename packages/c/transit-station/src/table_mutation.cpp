#include "internal.hpp"
#include <transit/table_mutation.h>
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

struct transit_station_table_mutation_compiled {
    Bytes bytes; transit_station_table_mutation_reference reference;
};
struct transit_station_table_mutation_prepared { Bytes bytes; };
namespace {
using Reference = transit_station_table_mutation_reference;
size_t variant(const std::string &value, const char *const *names, size_t count) {
    for (size_t i=0; i<count; ++i) if (value==names[i]) return i;
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"mutation-variant");
}
std::string reference_wire(const Reference &v) { return quote(hex(Bytes(v.bytes,v.bytes+72))); }
void fixed(const Raw &r,const Bytes &v,const std::string &path,uint8_t *out,size_t count) {
    const auto data=unhex(r.field(v,path,true),count);
    if (data.size()!=count) fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"mutation-reference-width");
    std::copy(data.begin(),data.end(),out);
}
std::string prepared_wire(const transit_station_table_mutation_prepared *v) {
    require(v && !v->bytes.empty(),"mutation-prepared");
    return quote(std::string(v->bytes.begin(),v->bytes.end()));
}
uint64_t revision(const Raw &r,const Bytes &v,const std::string &path) {
    const auto result=wide(r,v,path);counter(result);return result;
}
struct NativeMutation {
    Local local;
    std::unique_ptr<station_mutation_client,decltype(&::station_table_mutation_destroy)> handle;
    NativeMutation(const transit_sdk_config &config,const transit_sdk_credential &identity,transit_station_table_mutation_connection c)
        :local(config.native_directory),handle(nullptr,local.station_table_mutation_destroy) {
        require(config.sdk_version==TRANSIT_SDK_VERSION,"mutation-sdk-version");
        credential(identity);process(c.writer);counter(c.resource.realm);counter(c.resource.resource);
        require(c.table && identity.realm==c.writer.realm && c.writer.realm==c.resource.realm,"mutation-connection");
        const auto url=text(config.url,2048);
        const auto settings="{\"connection\":{\"realm\":"+decimal(identity.realm)+",\"principal\":"+decimal(identity.principal)+",\"writer\":"+decimal(c.writer.pid)+",\"resource\":"+decimal(c.resource.resource)+",\"table\":"+decimal(c.table)+"},\"timeout_ms\":"+decimal(config.timeout_ms)+"}";
        Seed seed(identity.seed_file);station_mutation_client *pointer=nullptr;
        const auto status=local.station_table_mutation_create(STATION_ABI_VERSION,reinterpret_cast<const uint8_t*>(url.data()),url.size(),seed.data(),reinterpret_cast<const uint8_t*>(settings.data()),settings.size(),&pointer);
        handle.reset(pointer);local.raw.check(status,{},"open-mutation");require(pointer,"mutation-handle");
        const auto caps=call("{\"capabilities\":{}}");const auto &r=local.raw;
        if (r.number(caps,"capabilities/version")!=1 || r.number(caps,"capabilities/max_rows")!=3 || r.number(caps,"capabilities/max_request_bytes")!=799 || r.number(caps,"capabilities/max_saved_bytes")!=8192)
            fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY,"mutation-bounds");
        for (const char *name:{"insert","update_primary_key","delete_primary_key"})
            if (!r.boolean(caps,std::string("capabilities/")+name)) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY,"mutation-capabilities");
    }
    Bytes call(const std::string &action,bool mutation=false) {
        require(action.size()<=TRANSIT_CLIENT_MAX_BODY,"mutation-action-bound");station_buffer *buffer=nullptr;
        const auto status=local.station_table_mutation_call(handle.get(),reinterpret_cast<const uint8_t*>(action.data()),action.size(),&buffer);
        return local.result(status,buffer,"mutation-action",mutation);
    }
};
std::unique_ptr<transit_station_table_mutation_prepared> prepared(const Raw &r,const Bytes &v) {
    if (r.field(v,"prepared")=="null") return {};
    const auto text=r.field(v,"prepared",true);require(!text.empty() && text.size()<=8192,"mutation-prepared-bound");
    return std::make_unique<transit_station_table_mutation_prepared>(transit_station_table_mutation_prepared{Bytes(text.begin(),text.end())});
}
}
struct transit_station_table_mutation_client {
    Worker worker;std::unique_ptr<NativeMutation> native;transit_station_table_mutation_connection connection;
    explicit transit_station_table_mutation_client(transit_station_table_mutation_connection c):connection(c){}
    ~transit_station_table_mutation_client(){worker.close([&]{native.reset();});}
};
namespace {
template<class F> transit_sdk_error run(transit_station_table_mutation_client *owner,F &&work) {
    return boundary([&]{require(owner,"mutation-client");owner->worker.run([&]{require(bool(owner->native),"mutation-client");work(*owner->native);});});
}
}
extern "C" {
transit_sdk_error transit_station_table_mutation_compiled_import(transit_sdk_bytes data,Reference ref,transit_station_table_mutation_compiled **out) {
    if(out)*out=nullptr;
    return boundary([&]{require(out && data.size,"mutation-compiled");*out=new transit_station_table_mutation_compiled{copy(data,799),ref};});
}
transit_sdk_error transit_station_table_mutation_compiled_get(const transit_station_table_mutation_compiled *v,transit_sdk_bytes *request,Reference *reference) {
    if(request)*request={};if(reference)*reference={};
    return boundary([&]{require(v && request && reference,"mutation-compiled");*request=view(v->bytes);*reference=v->reference;});
}
void transit_station_table_mutation_compiled_destroy(transit_station_table_mutation_compiled *v){delete v;}
transit_sdk_error transit_station_table_mutation_prepared_import(transit_sdk_bytes data,transit_station_table_mutation_prepared **out) {
    if(out)*out=nullptr;
    return boundary([&]{require(out && data.size,"mutation-prepared");*out=new transit_station_table_mutation_prepared{copy(data,8192)};});
}
transit_sdk_error transit_station_table_mutation_prepared_bytes(const transit_station_table_mutation_prepared *v,transit_sdk_bytes *out) {
    if(out)*out={};return boundary([&]{require(v && out,"mutation-prepared");*out=view(v->bytes);});
}
void transit_station_table_mutation_prepared_destroy(transit_station_table_mutation_prepared *v){delete v;}
transit_sdk_error transit_station_table_mutation_open(const transit_sdk_config *config,const transit_sdk_credential *identity,transit_station_table_mutation_connection c,transit_station_table_mutation_client **out) {
    Uninterruptible guard;if(out)*out=nullptr;
    return boundary([&]{require(config && identity && out,"mutation-open");auto owner=std::make_unique<transit_station_table_mutation_client>(c);owner->worker.run([&]{owner->native=std::make_unique<NativeMutation>(*config,*identity,c);});*out=owner.release();});
}
transit_sdk_error transit_station_table_mutation_close(transit_station_table_mutation_client *v) {
    Uninterruptible guard;return boundary([&]{require(v,"mutation-client");v->worker.close([&]{v->native.reset();});});
}
void transit_station_table_mutation_client_destroy(transit_station_table_mutation_client *v){Uninterruptible guard;delete v;}
transit_sdk_error transit_station_table_mutation_describe(transit_station_table_mutation_client *client,transit_station_table_mutation_description *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeMutation &n){
        require(out,"mutation-description");const auto v=n.call("{\"describe\":{}}");const auto &r=n.local.raw;
        transit_station_table_mutation_description result{};result.resource=client->connection.resource;result.table=client->connection.table;
        require(r.number(v,"description/resource")==result.resource.resource && r.number(v,"description/table")==result.table,"mutation-target");
        for(size_t i=0;i<2;++i){const auto name=r.field(v,"description/names/"+decimal(i),true);require(name.size()<=16 && name.find('\0')==std::string::npos,"mutation-column-name");std::copy(name.begin(),name.end(),result.names[i]);}
        require(!exists(r,v,"description/names/2"),"mutation-columns");
        const char *types[]={"int64","boolean","utf8","binary"};result.value_type=static_cast<transit_station_cell_kind>(1+variant(r.field(v,"description/value_type",true),types,4));
        result.resource_revision=r.number(v,"description/resource_revision",true);result.policy_revision=revision(r,v,"description/policy_revision");fixed(r,v,"description/declaration",result.declaration,32);
        const auto permissions=r.number(v,"description/permissions",true);require(permissions<=7,"mutation-permissions");result.permissions=static_cast<uint8_t>(permissions);
        result.has_active=r.field(v,"description/active")!="null";if(result.has_active){result.active=wide(r,v,"description/active");require(result.active,"mutation-namespace");}*out=result;
    });
}
transit_sdk_error transit_station_table_mutation_compile_sql(transit_station_table_mutation_client *client,const char *name,const char *sql,uint64_t ns,transit_station_table_mutation_compiled **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeMutation &n){
        require(ns && out,"mutation-compile");const auto v=n.call("{\"compile\":{\"name\":"+quote(text(name,16))+",\"sql\":"+quote(text(sql,4096))+",\"namespace\":"+quote(decimal(ns))+"}}");
        auto result=std::make_unique<transit_station_table_mutation_compiled>();result->bytes=unhex(n.local.raw.field(v,"compiled/request",true),799);require(!result->bytes.empty(),"mutation-request");fixed(n.local.raw,v,"compiled/reference",result->reference.bytes,72);*out=result.release();
    });
}
transit_sdk_error transit_station_table_mutation_prepare_next(transit_station_table_mutation_client *client,const transit_station_table_mutation_compiled *compiled,transit_station_table_mutation_prepared **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeMutation &n){require(compiled && out,"mutation-next");auto result=prepared(n.local.raw,n.call("{\"next\":{\"request\":"+quote(hex(compiled->bytes))+",\"reference\":"+reference_wire(compiled->reference)+"}}"));*out=result.release();});
}
transit_sdk_error transit_station_table_mutation_prepare_control(transit_station_table_mutation_client *client,transit_station_table_mutation_control command,Reference reference,transit_station_table_mutation_prepared **out) {
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeMutation &n){require(out && (command==TRANSIT_TABLE_MUTATION_APPLY || command==TRANSIT_TABLE_MUTATION_CANCEL),"mutation-control");auto result=prepared(n.local.raw,n.call("{\"prepare\":{"+quote(command==TRANSIT_TABLE_MUTATION_APPLY?"apply":"cancel")+":"+reference_wire(reference)+"}}"));require(bool(result),"mutation-prepared");*out=result.release();});
}
transit_sdk_error transit_station_table_mutation_submit(transit_station_table_mutation_client *client,const transit_station_table_mutation_prepared *command,uint64_t *out) {
    Uninterruptible guard;if(out)*out=0;return run(client,[&](NativeMutation &n){require(out,"mutation-submit");const auto v=n.call("{\"submit\":"+prepared_wire(command)+"}",true);try{*out=n.local.raw.number(v,"receipt/position");}catch(...){fail(TRANSIT_SDK_UNKNOWN_OUTCOME,"mutation-receipt");}});
}
transit_sdk_error transit_station_table_mutation_observe(transit_station_table_mutation_client *client,const transit_station_table_mutation_prepared *command,uint64_t input,transit_station_table_mutation_observation *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeMutation &n){require(out,"mutation-observe");counter(input);const auto v=n.call("{\"observe\":{\"prepared\":"+prepared_wire(command)+",\"input\":"+decimal(input)+"}}");const char *names[]={"pending","processed"};*out=static_cast<transit_station_table_mutation_observation>(variant(n.local.raw.field(v,"observation",true),names,2));});
}
transit_sdk_error transit_station_table_mutation_input_rejection(transit_station_table_mutation_client *client,const transit_station_table_mutation_prepared *command,uint64_t input,bool *found,transit_station_table_mutation_rejection *out) {
    Uninterruptible guard;if(found)*found=false;if(out)*out={};return run(client,[&](NativeMutation &n){require(found && out,"mutation-rejection");counter(input);const auto v=n.call("{\"rejection\":{\"prepared\":"+prepared_wire(command)+",\"input\":"+decimal(input)+"}}");if(n.local.raw.field(v,"rejection")=="null")return;
        const char *names[]={"invalid_command","denied","identity_conflict","busy","not_found","not_active","upload_closed","not_sealed","invalid_part","incomplete_upload","source_changed","stale_policy"};
        *out=static_cast<transit_station_table_mutation_rejection>(variant(n.local.raw.field(v,"rejection",true),names,12));*found=true;});
}
transit_sdk_error transit_station_table_mutation_status_read(transit_station_table_mutation_client *client,Reference reference,transit_station_table_mutation_status *out) {
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeMutation &n){require(out,"mutation-status");const auto v=n.call("{\"status\":"+reference_wire(reference)+"}");const auto &r=n.local.raw;if(r.field(v,"status")=="null")return;
        transit_station_table_mutation_status result{};result.found=true;fixed(r,v,"status/reference",result.reference.bytes,72);require(std::equal(reference.bytes,reference.bytes+72,result.reference.bytes),"mutation-status-reference");
        result.table=client->connection.table;require(r.number(v,"status/table")==result.table,"mutation-status-table");result.principal=r.number(v,"status/principal");fixed(r,v,"status/declaration",result.declaration,32);result.policy_revision=revision(r,v,"status/policy_revision");
        const char *phases[]={"uploading","sealed","applied","rejected","cancelled"};result.phase=static_cast<transit_station_table_mutation_phase>(variant(r.field(v,"status/phase",true),phases,5));
        const auto affected=r.number(v,"status/affected_rows",true);require(affected<=3,"mutation-row-count");result.affected_rows=static_cast<uint8_t>(affected);
        const char *reasons[]={"none","row_exists","source_changed","invalid_request","denied","budget"};result.reason=static_cast<transit_station_table_mutation_reason>(variant(r.field(v,"status/reason",true),reasons,6));result.input=r.number(v,"status/input",true);*out=result;
    });
}
}

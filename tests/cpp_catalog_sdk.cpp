/* Installed C++17 consumer through public move-only catalog callers. */
#include <transit/catalog.hpp>
#include "catalog_sdk_io.h"
using namespace transit::sdk;
namespace cat=transit::sdk::station::catalog;
static cat::Scope cpp_scope(transit_station_catalog_scope v){return {ResourceRef(v.resource.realm,v.resource.resource),v.catalog};}
static transit_station_catalog_scope c_scope(const cat::Scope &v){return {{v.resource.realm(),v.resource.resource()},v.catalog};}
static cat::CreateTable cpp_request(const transit_station_catalog_create_table &v){return {cpp_scope(v.scope),v.operation,v.object,v.table,v.name,{{v.schema.names[0],v.schema.names[1]},static_cast<cat::Type>(v.schema.value_type-1)}};}
static transit_station_catalog_create_table c_request(const cat::CreateTable &v){
    transit_station_catalog_create_table out{};out.scope=c_scope(v.scope);out.operation=v.operation;out.object=v.object;out.table=v.table;
    copy_name(out.name,v.name.c_str());copy_name(out.schema.names[0],v.schema.names[0].c_str());copy_name(out.schema.names[1],v.schema.names[1].c_str());out.schema.value_type=static_cast<transit_station_cell_kind>(1+static_cast<int>(v.schema.value_type));return out;
}
int main(int argc,char **argv){
    assert(argc==8);setvbuf(stdout,nullptr,_IOLBF,0);const auto realm=number(argv[3]);
    bool rejected=false;try{cat::Prepared::recover({});}catch(const Error &e){rejected=e.detail().kind==TRANSIT_SDK_INVALID_ARGUMENT;}assert(rejected);
    cat::CreateTable value{{ResourceRef(1,7),UINT64_MAX},UINT64_MAX,UINT64_MAX,UINT32_MAX,"items",{{"id","value"},cat::Type::Utf8}};
    Bytes original{1,2};auto copy=cat::Compiled::recover(value,original);value.name="changed";original[0]=0;assert(copy.request().name=="items" && copy.request().object==UINT64_MAX && copy.canonical()[0]==1);
    auto moved=std::move(copy);rejected=false;try{copy.canonical();}catch(const Error &e){rejected=e.detail().kind==TRANSIT_SDK_INVALID_ARGUMENT;}assert(rejected && moved.canonical()[0]==1);
    value.schema.value_type=static_cast<cat::Type>(256);rejected=false;try{cat::Compiled::recover(value,original);}catch(const Error &e){rejected=e.detail().kind==TRANSIT_SDK_INVALID_ARGUMENT;}assert(rejected);
    auto config=ClientConfig::growing(argv[1]).timeout(10000);
    Credential credential(realm,number(argv[4]),argv[2]);cat::Connection connection{ProcessRef(realm,number(argv[5])),{ResourceRef(realm,number(argv[6])),number(argv[7])}};
    auto client=cat::Client::open(config,credential,connection);std::optional<cat::Prepared> retained;Bytes retained_bytes;std::optional<cat::Compiled> compiled;
    puts("{\"ready\":true}");
    while(read_command() && strcmp(args[0],"close")){
        const char *command=args[0];
        try{
            if(!strcmp(command,"capabilities")){
                auto v=client.capabilities();transit_station_catalog_capabilities out{};out.version=v.version;assert(v.definition.size()==64);memcpy(out.definition,v.definition.data(),64);
                out.initialize=v.initialize;out.create_table=v.create_table;out.conditional_policy=v.conditional_policy;out.current_metadata=v.current_metadata;out.max_saved_bytes=v.max_saved_bytes;out.table_columns=v.table_columns;emit_capabilities(&out);
            }else if(!strcmp(command,"describe")){
                auto v=client.describe();transit_station_catalog_description out{{c_scope(v.configuration.scope),{v.configuration.owner.realm(),v.configuration.owner.pid()},v.configuration.administrator},{c_scope(v.policy.scope),v.policy.principal,v.policy.revision,v.policy.inspect,v.policy.create},v.resource_revision};emit_description(&out);
            }else if(!strcmp(command,"compile")){
                auto sql=unhex(args[1]);std::string statement(reinterpret_cast<const char *>(sql.data),sql.size);free((void *)sql.data);
                auto v=client.compile_sql(statement,number(args[2]),number(args[3]),static_cast<uint32_t>(number(args[4])));auto r=v.request();auto canonical=v.canonical();auto wire=c_request(r);
                printf("{\"status\":0,\"value\":{\"compiled\":{\"request\":");emit_request(&wire);printf(",\"canonical\":\"");print_hex({canonical.data(),canonical.size()});puts("\"}}}");
                compiled=cat::Compiled::recover(r,canonical);r.name="changed";std::fill(canonical.begin(),canonical.end(),0);assert(compiled->request().name==wire.name && compiled->canonical()==v.canonical());
            }else if(!strcmp(command,"initialize") || !strcmp(command,"create") || !strcmp(command,"policy")){
                std::optional<cat::Prepared> out;
                if(!strcmp(command,"initialize"))out=client.prepare_initialize({cpp_scope(scope(1)),ProcessRef(number(args[1]),number(args[4])),number(args[5])});
                else if(!strcmp(command,"create"))out=client.prepare_create(cpp_request(request()));
                else out=client.prepare_policy({number(args[8]),{cpp_scope(scope(1)),number(args[4]),number(args[5]),number(args[6])!=0,number(args[7])!=0}});
                auto bytes=out->data();emit_prepared({bytes.data(),bytes.size()});
            }else if(!strcmp(command,"status")){
                auto v=client.status(cpp_request(request()));transit_station_catalog_receipt out{};
                if(v){out.found=true;out.request=c_request(v->request);out.principal=v->principal;out.input=v->input;out.outcome=static_cast<transit_station_catalog_outcome>(v->outcome);}emit_status(&out);
            }else{
                auto bytes=unhex(args[1]);Bytes saved(bytes.data,bytes.data+bytes.size);free((void *)bytes.data);
                auto prepared=cat::Prepared::recover(saved);retained_bytes=saved;std::fill(saved.begin(),saved.end(),0);assert(prepared.data()==retained_bytes);retained=std::move(prepared);
                if(!strcmp(command,"submit"))printf("{\"status\":0,\"value\":{\"receipt\":{\"position\":%llu}}}\n",static_cast<unsigned long long>(client.submit(*retained)));
                else if(!strcmp(command,"observe"))printf("{\"status\":0,\"value\":{\"observation\":\"%s\"}}\n",client.observe(*retained,number(args[2]))==cat::Observation::Pending?"pending":"processed");
                else {assert(!strcmp(command,"input_disposition"));auto v=client.input_disposition(*retained,number(args[2]));transit_station_catalog_disposition out{};
                    if(v){out.found=true;out.scope=c_scope(v->scope);out.origin=static_cast<transit_station_catalog_origin>(v->origin);out.principal=v->principal;out.input=v->input;std::copy(v->payload.begin(),v->payload.end(),out.payload);out.outcome=static_cast<transit_station_catalog_disposition_outcome>(v->outcome);}emit_disposition(&out);
                }
                assert(retained->data()==retained_bytes);
            }
        }catch(const Error &error){if(!strcmp(command,"submit"))assert(retained && retained->data()==retained_bytes);emit_error(error.detail());}
    }
    client.close();bool closed=false;try{client.describe();}catch(const Error &e){closed=e.detail().kind==TRANSIT_SDK_CLOSED;}assert(closed);
    if(retained)assert(retained->data()==retained_bytes);if(compiled)assert(compiled->request().object && !compiled->canonical().empty());
    puts("{\"closed\":true}");
}

#include "internal.hpp"
#include <transit/unified_query.h>
#include <cmath>
#include <limits>
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

struct transit_station_unified_bundle { Bytes bytes; };
struct transit_station_unified_prepared { Bytes bytes; };
struct transit_station_unified_cursor { Bytes bytes; };
namespace {
const char *types[] = {"int64","uint64","float64","boolean","utf8","binary"};
const char *states[] = {"missing","null","type_error","value","conflict"};
const char *phases[] = {"uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"};
const char *type_name(transit_station_unified_type v) { require(v>=TRANSIT_UNIFIED_INT64 && v<=TRANSIT_UNIFIED_BINARY,"query-type");return types[v]; }
size_t select_name(const std::string &name,const char *const *names,size_t count) {
    for(size_t i=0;i<count;++i) if(name==names[i])return i;
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"query-variant");
}
std::string string_bytes(transit_sdk_bytes v,size_t bound) { const auto bytes=copy(v,bound);return {bytes.begin(),bytes.end()}; }
std::string column_wire(const transit_station_unified_column &v) {return "{\"name\":"+quote(text(v.name,64))+",\"type\":"+quote(type_name(v.type))+"}";}
std::string columns_wire(const transit_station_unified_column *columns,size_t count) {
    require(columns && count>0 && count<=8,"query-columns");std::string out="[";
    for(size_t i=0;i<count;++i){if(i)out+=',';out+=column_wire(columns[i]);}return out+"]";
}
std::string path_wire(const char *const *names,size_t count) {
    require(count<=8 && (names || !count),"query-path");std::string out="[";
    for(size_t i=0;i<count;++i){if(i)out+=',';out+=quote(text(names[i],64));}return out+"]";
}
std::string decoder_wire(transit_station_unified_decoder v) {return "{\"version\":"+decimal(v.version)+",\"type\":"+quote(type_name(v.type))+"}";}
void resource_check(transit_sdk_resource v) {counter(v.realm);counter(v.resource);}
std::string source_wire(const transit_station_unified_source &v) {
    resource_check(v.resource);std::string source;
    if(v.kind==TRANSIT_UNIFIED_KV) {
        const auto &k=v.source.kv;source="{\"kv\":{\"prefix\":"+quote(hex(copy(k.prefix,32)))+",\"key\":"+decoder_wire(k.key)+",\"value\":"+decoder_wire(k.value)+"}}";
    }else if(v.kind==TRANSIT_UNIFIED_TABLE) {
        const auto &t=v.source.table;source="{\"table\":{\"id\":"+decimal(t.id)+",\"names\":["+quote(text(t.names[0],64))+","+quote(text(t.names[1],64))+"],\"value_type\":"+quote(type_name(t.value_type))+"}}";
    }else {
        require(v.kind==TRANSIT_UNIFIED_DOCUMENT,"query-source");const auto &d=v.source.document;const auto &r=d.reference;
        require(r.resource.realm==v.resource.realm && r.resource.resource==v.resource.resource,"query-document-resource");
        require(d.projections && d.projection_count>0 && d.projection_count<=8,"query-projections");
        std::string projections="[";const char *modes[]={"scalar","text","element_counter","element_replica"};
        for(size_t i=0;i<d.projection_count;++i){const auto &p=d.projections[i];require(p.mode>=TRANSIT_UNIFIED_SCALAR && p.mode<=TRANSIT_UNIFIED_ELEMENT_REPLICA,"query-projection-mode");if(i)projections+=',';
            projections+="{\"column\":"+column_wire(p.column)+",\"path\":"+path_wire(p.path,p.path_count)+",\"relative\":"+(p.relative?"true":"false")+",\"mode\":"+quote(modes[p.mode])+",\"text_bytes\":"+decimal(p.text_bytes)+",\"text_steps\":"+decimal(p.text_steps)+"}";}
        source="{\"document\":{\"reference\":{\"resource\":"+decimal(r.resource.resource)+",\"document\":"+quote(decimal(r.document))+",\"epoch\":"+quote(decimal(r.epoch))+",\"type_revision\":"+decimal(r.type_revision)+",\"revision\":"+quote(decimal(r.revision))+"},\"change_format\":1,\"expand\":"+(d.has_expansion?path_wire(d.expand,d.expand_count):"null")+",\"projections\":"+projections+"]}}";
    }
    return "{\"version\":1,\"resource\":"+decimal(v.resource.resource)+",\"source\":"+source+"}";
}
std::string scalar_wire(const transit_station_unified_scalar &v) {
    switch(v.type){
    case TRANSIT_UNIFIED_INT64:return "{\"int64\":"+quote(signed_decimal(v.signed_value))+"}";
    case TRANSIT_UNIFIED_UINT64:return "{\"uint64\":"+quote(decimal(v.unsigned_value))+"}";
    case TRANSIT_UNIFIED_FLOAT64:{
        require(std::isfinite(v.float_value),"query-float");static_assert(sizeof(double)==8 && std::numeric_limits<double>::is_iec559);
        uint64_t bits;std::memcpy(&bits,&v.float_value,8);Bytes bytes(8);for(size_t i=0;i<8;++i)bytes[i]=static_cast<uint8_t>(bits>>(i*8));
        return "{\"float_bits\":"+quote(hex(bytes))+"}";}
    case TRANSIT_UNIFIED_BOOLEAN:return std::string("{\"boolean\":")+(v.boolean?"true}":"false}");
    case TRANSIT_UNIFIED_UTF8:return "{\"utf8\":"+quote(string_bytes(v.bytes,4096))+"}";
    case TRANSIT_UNIFIED_BINARY:return "{\"binary\":"+quote(hex(copy(v.bytes,4096)))+"}";
    }fail(TRANSIT_SDK_INVALID_ARGUMENT,"query-scalar");
}
std::string plan_wire(const transit_station_unified_plan &v) {
    require(v.projection && v.projection_count>0 && v.projection_count<=8,"query-projection");
    require(v.aggregate>=TRANSIT_AGGREGATE_ROWS && v.aggregate<=TRANSIT_AGGREGATE_SUM,"query-aggregate");
    const char *aggregates[]={"rows","count","sum"};const char *comparisons[]={"eq","ne","lt","le","gt","ge"};
    std::string projection="[",predicate="{\"all\":{}}";
    for(size_t i=0;i<v.projection_count;++i){require(v.projection[i]<8,"query-column");if(i)projection+=',';projection+=decimal(v.projection[i]);}
    if(v.predicate==TRANSIT_UNIFIED_IS_STATE){require(v.state>=TRANSIT_UNIFIED_MISSING && v.state<=TRANSIT_UNIFIED_CONFLICT,"query-state");predicate="{\"state\":{\"column\":"+decimal(v.column)+",\"value\":"+quote(states[v.state])+"}}";}
    else if(v.predicate==TRANSIT_UNIFIED_COMPARE){require(v.comparison>=TRANSIT_COMPARE_EQ && v.comparison<=TRANSIT_COMPARE_GE,"query-comparison");predicate="{\"compare\":{\"column\":"+decimal(v.column)+",\"op\":"+quote(comparisons[v.comparison])+",\"value\":"+scalar_wire(v.value)+"}}";}
    else require(v.predicate==TRANSIT_UNIFIED_ALL,"query-predicate");
    return "{\"version\":1,\"projection\":"+projection+"],\"predicate\":"+predicate+",\"aggregate\":"+quote(aggregates[v.aggregate])+",\"limit\":"+(v.has_limit?quote(decimal(v.limit)):"null")+"}";
}
std::string limits_wire(transit_station_unified_budgets v) {require(v.pages && v.segments && v.result_bytes,"query-budgets");return "{\"pages\":"+quote(decimal(v.pages))+",\"segments\":"+quote(decimal(v.segments))+",\"result_bytes\":"+quote(decimal(v.result_bytes))+"}";}
Bytes codec(Local &local,const std::string &action) {
    require(action.size()<=TRANSIT_CLIENT_MAX_BODY,"query-codec-bound");station_buffer *buffer=nullptr;
    const auto status=local.station_unified_query_codec(reinterpret_cast<const uint8_t*>(action.data()),action.size(),&buffer);
    return local.result(status,buffer,"query-codec");
}
size_t array_size(const Raw &raw,const Bytes &bytes,const std::string &path,size_t bound) {
    size_t count=0;while(count<bound && exists(raw,bytes,path+"/"+decimal(count)))++count;
    require(!exists(raw,bytes,path+"/"+decimal(bound)),"query-array-bound");return count;
}
void fixed_bytes(const Raw &raw,const Bytes &bytes,const std::string &path,uint8_t *out,size_t count) {
    const auto value=unhex(raw.field(bytes,path,true),count);require(value.size()==count,"query-reference-width");std::copy(value.begin(),value.end(),out);
}
void inspected_name(const Raw &raw,const Bytes &bytes,const std::string &path,char (&out)[33]) {
    const auto value=raw.field(bytes,path,true);require(value.size()<=32 && value.find('\0')==std::string::npos,"inspection-name");
    std::copy(value.begin(),value.end(),out);out[value.size()]='\0';
}
transit_station_unified_source_description inspected_columns(const Raw &raw,const Bytes &bytes,const std::string &path) {
    transit_station_unified_source_description out{};out.column_count=array_size(raw,bytes,path,8);require(out.column_count>0,"inspection-columns");
    for(size_t i=0;i<out.column_count;++i){const auto column=path+"/"+decimal(i);inspected_name(raw,bytes,column+"/name",out.columns[i].name);out.columns[i].type=static_cast<transit_station_unified_type>(select_name(raw.field(bytes,column+"/type",true),types,6));}
    return out;
}
struct NativeQuery {
    Local local;
    std::unique_ptr<station_query_client,decltype(&::station_unified_query_destroy)> handle;
    NativeQuery(const transit_sdk_config &config,const transit_sdk_credential &identity,transit_station_unified_connection c)
        :local(config.native_directory),handle(nullptr,local.station_unified_query_destroy) {
        require(config.sdk_version==TRANSIT_SDK_VERSION,"query-sdk-version");credential(identity);process(c.source);process(c.requester);resource_check(c.resource);resource_check(c.requests);
        require(identity.realm==c.source.realm && c.source.realm==c.resource.realm && c.source.realm==c.requester.realm && c.source.realm==c.requests.realm,"query-realm");
        const auto url=text(config.url,2048);const auto json="{\"connection\":{\"realm\":"+decimal(identity.realm)+",\"principal\":"+decimal(identity.principal)+",\"source\":"+decimal(c.source.pid)+",\"resource\":"+decimal(c.resource.resource)+",\"requester\":"+decimal(c.requester.pid)+",\"requests\":"+decimal(c.requests.resource)+"},\"timeout_ms\":"+decimal(config.timeout_ms)+"}";
        Seed seed(identity.seed_file);station_query_client *pointer=nullptr;
        const auto status=local.station_unified_query_create(STATION_ABI_VERSION,reinterpret_cast<const uint8_t*>(url.data()),url.size(),seed.data(),reinterpret_cast<const uint8_t*>(json.data()),json.size(),&pointer);
        handle.reset(pointer);local.raw.check(status,{},"open-query");require(pointer,"query-handle");
        const auto caps=call("{\"capabilities\":{}}");require(local.raw.number(caps,"capabilities/version")==1,"query-version");
        for(const char *kind:{"kv","table","document"})require(local.raw.boolean(caps,std::string("capabilities/")+kind),"query-sources");
    }
    Bytes call(const std::string &action,bool mutation=false) {
        require(action.size()<=TRANSIT_CLIENT_MAX_BODY,"query-action-bound");station_buffer *buffer=nullptr;
        const auto status=local.station_unified_query_call(handle.get(),reinterpret_cast<const uint8_t*>(action.data()),action.size(),&buffer);
        return local.result(status,buffer,"query-action",mutation);
    }
};
struct OwnedScalar {
    transit_station_unified_scalar value{};Bytes bytes;
    transit_station_unified_scalar view_value()const{auto out=value;out.bytes=view(bytes);return out;}
};
OwnedScalar scalar_parse(const Raw &raw,const Bytes &bytes,const std::string &path) {
    const char *names[]={"int64","uint64","float_bits","boolean","utf8","binary"};size_t selected=6;
    for(size_t i=0;i<6;++i)if(exists(raw,bytes,path+"/"+names[i])){require(selected==6,"query-scalar-union");selected=i;}
    require(selected<6,"query-scalar");OwnedScalar out;out.value.type=static_cast<transit_station_unified_type>(selected);const auto p=path+"/"+names[selected];
    if(selected==0)out.value.signed_value=signed_number(raw,bytes,p);
    else if(selected==1)out.value.unsigned_value=wide(raw,bytes,p);
    else if(selected==2){const auto data=unhex(raw.field(bytes,p,true),8);require(data.size()==8,"query-float");uint64_t bits=0;for(size_t i=0;i<8;++i)bits|=uint64_t(data[i])<<(8*i);std::memcpy(&out.value.float_value,&bits,8);require(std::isfinite(out.value.float_value),"query-float");}
    else if(selected==3)out.value.boolean=raw.boolean(bytes,p);
    else {const auto value=raw.field(bytes,p,true);out.bytes=selected==5?unhex(value,4096):Bytes(value.begin(),value.end());require(out.bytes.size()<=4096,"query-scalar-bound");}
    return out;
}
struct OwnedCell;
struct OwnedAlternative {uint64_t counter,replica;std::unique_ptr<OwnedCell> cell;};
struct OwnedCell {
    transit_station_unified_state state{};OwnedScalar scalar;std::string actual_kind;std::vector<OwnedAlternative> alternatives;
    transit_station_unified_cell get()const{transit_station_unified_cell out{};out.state=state;out.value=scalar.view_value();std::copy(actual_kind.begin(),actual_kind.end(),out.actual_kind);out.alternative_count=alternatives.size();return out;}
};
OwnedCell cell_parse(const Raw &raw,const Bytes &bytes,const std::string &path,bool alternative=false) {
    OwnedCell out;size_t selected=5;for(size_t i=0;i<5;++i)if(exists(raw,bytes,path+"/"+states[i])){require(selected==5,"query-cell-union");selected=i;}
    require(selected<5 && (!alternative || (selected>0 && selected<4)),"query-cell-state");out.state=static_cast<transit_station_unified_state>(selected);
    const auto p=path+"/"+states[selected];
    if(selected==2){out.actual_kind=raw.field(bytes,p,true);require(out.actual_kind.size()<=16,"query-actual-kind");}
    else if(selected==3)out.scalar=scalar_parse(raw,bytes,p);
    else if(selected==4){const auto count=array_size(raw,bytes,p,8);require(count>=2,"query-conflicts");for(size_t i=0;i<count;++i){const auto entry=p+"/"+decimal(i);const auto counter=wide(raw,bytes,entry+"/counter"),replica=wide(raw,bytes,entry+"/replica");require(counter && replica,"query-dot");out.alternatives.push_back({counter,replica,std::make_unique<OwnedCell>(cell_parse(raw,bytes,entry+"/value",true))});}}
    return out;
}
}
struct transit_station_unified_client {
    Worker worker;std::unique_ptr<NativeQuery> native;transit_station_unified_connection connection;
    explicit transit_station_unified_client(transit_station_unified_connection c):connection(c){}
    ~transit_station_unified_client(){worker.close([&]{native.reset();});}
};
struct transit_station_unified_page {transit_station_unified_page_info info{};std::array<std::string,8> names;Bytes ipc;std::optional<Bytes> next;};
struct transit_station_unified_rows {std::vector<std::vector<OwnedCell>> rows;};
namespace {
template<class F> transit_sdk_error run(transit_station_unified_client *owner,F &&work){return boundary([&]{require(owner,"query-client");owner->worker.run([&]{require(bool(owner->native),"query-client");work(*owner->native);});});}
std::unique_ptr<transit_station_unified_prepared> prepared(const Raw &raw,const Bytes &value) {
    if(raw.field(value,"prepared")=="null")return {};
    const auto text=raw.field(value,"prepared",true);require(text.size()<=8192,"query-prepared-bound");return std::make_unique<transit_station_unified_prepared>(transit_station_unified_prepared{Bytes(text.begin(),text.end())});
}
std::unique_ptr<transit_station_unified_page> page_parse(const Raw &raw,const Bytes &v,uint64_t realm) {
    auto out=std::make_unique<transit_station_unified_page>();auto &m=out->info.manifest;const std::string p="page/manifest/",b=p+"basis/";
    m.job=raw.number(v,p+"job");m.source=read_version(raw,v,p+"source");m.requester={realm,raw.number(v,p+"requester")};m.correlation=wide(raw,v,p+"correlation");m.policy_revision=wide(raw,v,p+"policy_revision");fixed_bytes(raw,v,p+"request",m.request,72);
    const char *kinds[]={"kv","table","document"};m.source_kind=static_cast<transit_station_unified_source_kind>(select_name(raw.field(v,b+"kind",true),kinds,3));m.resource={realm,raw.number(v,b+"resource")};m.revision=raw.number(v,b+"revision",true);
    digest(raw,v,b+"contract",m.source_digest);digest(raw,v,b+"schema",m.schema_digest);digest(raw,v,p+"plan",m.plan_digest);digest(raw,v,p+"chain",m.chain);
    m.pages=wide(raw,v,p+"pages");m.scanned=wide(raw,v,p+"scanned");m.selected=wide(raw,v,p+"selected");m.segments=wide(raw,v,p+"segments");m.rows=wide(raw,v,p+"rows");m.byte_count=wide(raw,v,p+"bytes");
    m.has_sum=raw.field(v,p+"sum")!="null";if(m.has_sum)m.sum=signed_number(raw,v,p+"sum");const char *finished[]={"source_end","limit"};m.finished=static_cast<transit_station_unified_finished>(select_name(raw.field(v,p+"finished",true),finished,2));
    out->info.ordinal=wide(raw,v,"page/ordinal");const auto rows=raw.number(v,"page/rows",true);require(rows<=8,"query-row-bound");out->info.rows=static_cast<uint8_t>(rows);
    out->info.column_count=array_size(raw,v,"page/columns",8);require(out->info.column_count>0,"query-columns");
    for(size_t i=0;i<out->info.column_count;++i){const auto c="page/columns/"+decimal(i);out->names[i]=raw.field(v,c+"/name",true);require(out->names[i].size()<=64,"query-column-name");out->info.columns[i]={out->names[i].c_str(),static_cast<transit_station_unified_type>(select_name(raw.field(v,c+"/type",true),types,6))};}
    out->ipc=unhex(raw.field(v,"page/ipc",true),65536);out->info.ipc=view(out->ipc);
    if(raw.field(v,"page/next")!="null"){const auto next=raw.field(v,"page/next",true);require(next.size()<=4096,"query-cursor-bound");out->next=Bytes(next.begin(),next.end());}
    return out;
}
}
extern "C" {
transit_sdk_error transit_station_unified_prepare_bundle(const transit_station_unified_source *source,const transit_station_unified_plan *plan,transit_station_unified_budgets budgets,const char *directory,transit_station_unified_bundle **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(source && plan && out,"query-bundle");const auto action="{\"prepare\":{\"source\":"+source_wire(*source)+",\"plan\":"+plan_wire(*plan)+",\"limits\":"+limits_wire(budgets)+"}}";auto bundle=std::make_unique<transit_station_unified_bundle>();Worker worker;worker.run([&]{Local local(directory);bundle->bytes=unhex(local.raw.field(codec(local,action),"prepared/bytes",true),16384);});*out=bundle.release();});
}
transit_sdk_error transit_station_unified_bundle_import(transit_sdk_bytes bytes,transit_station_unified_bundle **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-bundle");*out=new transit_station_unified_bundle{copy(bytes,16384)};});}
transit_sdk_error transit_station_unified_bundle_bytes(const transit_station_unified_bundle *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-bundle");*out=view(v->bytes);});}
void transit_station_unified_bundle_destroy(transit_station_unified_bundle *v){delete v;}
transit_sdk_error transit_station_unified_prepared_import(transit_sdk_bytes bytes,transit_station_unified_prepared **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-prepared");*out=new transit_station_unified_prepared{copy(bytes,8192)};});}
transit_sdk_error transit_station_unified_prepared_bytes(const transit_station_unified_prepared *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-prepared");*out=view(v->bytes);});}
void transit_station_unified_prepared_destroy(transit_station_unified_prepared *v){delete v;}
transit_sdk_error transit_station_unified_cursor_import(transit_sdk_bytes bytes,transit_station_unified_cursor **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-cursor");*out=new transit_station_unified_cursor{copy(bytes,4096)};});}
transit_sdk_error transit_station_unified_cursor_bytes(const transit_station_unified_cursor *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-cursor");*out=view(v->bytes);});}
void transit_station_unified_cursor_destroy(transit_station_unified_cursor *v){delete v;}
transit_sdk_error transit_station_unified_open(const transit_sdk_config *config,const transit_sdk_credential *credential,transit_station_unified_connection connection,transit_station_unified_client **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(config && credential && out,"query-open");auto owner=std::make_unique<transit_station_unified_client>(connection);owner->worker.run([&]{owner->native=std::make_unique<NativeQuery>(*config,*credential,connection);});*out=owner.release();});
}
transit_sdk_error transit_station_unified_close(transit_station_unified_client *v){Uninterruptible guard;return boundary([&]{require(v,"query-client");v->worker.close([&]{v->native.reset();});});}
void transit_station_unified_client_destroy(transit_station_unified_client *v){Uninterruptible guard;delete v;}
transit_sdk_error transit_station_unified_describe(transit_station_unified_client *client,const transit_station_unified_source *source,transit_station_unified_description *out){
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){require(source&&out,"query-description");require(source->resource.realm==client->connection.resource.realm&&source->resource.resource==client->connection.resource.resource,"query-source-resource");const auto v=n.call("{\"describe\":"+source_wire(*source)+"}");const auto &r=n.local.raw;const std::string p="description/";transit_station_unified_description result{};
        result.resource_revision=r.number(v,p+"resource_revision",true);result.policy_revision=wide(r,v,p+"policy_revision");result.budgets={wide(r,v,p+"limits/pages"),wide(r,v,p+"limits/segments"),wide(r,v,p+"limits/result_bytes")};result.has_active=r.field(v,p+"active")!="null";if(result.has_active)result.active=wide(r,v,p+"active");result.bundle_bytes=r.number(v,p+"capabilities/bundle_bytes");result.segment_bytes=r.number(v,p+"capabilities/segment_bytes");result.batch_rows=r.number(v,p+"capabilities/batch_rows");*out=result;});
}
transit_sdk_error transit_station_unified_inspect_sql(transit_station_unified_client *client,const transit_station_unified_source *source,const char *name,const char *sql,transit_station_unified_budgets budgets,transit_station_unified_inspection *out){
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){
        require(source&&out,"query-inspection");require(source->resource.realm==client->connection.resource.realm&&source->resource.resource==client->connection.resource.resource,"query-source-resource");
        const auto v=n.call("{\"inspect\":{\"scope\":{\"source\":"+source_wire(*source)+",\"name\":"+quote(text(name,32))+",\"limits\":"+limits_wire(budgets)+"},\"sql\":"+quote(text(sql,4096))+"}}");
        const auto &r=n.local.raw;const std::string p="inspection/",d=p+"details/";transit_station_unified_inspection result{};
        require(r.number(v,p+"version")==1&&r.field(v,p+"scope",true)=="configured_source"&&r.number(v,p+"resource")==source->resource.resource,"inspection-scope");
        inspected_name(r,v,p+"name",result.name);result.resource=source->resource;const char *kinds[]={"kv","table","document"};
        result.source_kind=static_cast<transit_station_unified_source_kind>(select_name(r.field(v,p+"source_kind",true),kinds,3));
        digest(r,v,p+"contract",result.source_digest);digest(r,v,p+"schema",result.schema_digest);
        result.resource_revision=r.number(v,p+"resource_revision",true);result.policy_revision=wide(r,v,p+"policy_revision");
        if(exists(r,v,d+"description")){result.kind=TRANSIT_UNIFIED_DESCRIPTION;result.details.description=inspected_columns(r,v,d+"description/columns");}
        else if(exists(r,v,d+"tables")){result.kind=TRANSIT_UNIFIED_TABLES;auto &list=result.details.tables;list.count=array_size(r,v,d+"tables",1);for(size_t i=0;i<list.count;++i)inspected_name(r,v,d+"tables/"+decimal(i),list.names[i]);}
        else {result.kind=TRANSIT_UNIFIED_EXPLANATION;const auto e=d+"explanation/";auto &plan=result.details.explanation;
            const char *operators[]={"scan","filter","limit","project","count","sum"};plan.operator_count=array_size(r,v,e+"operators",4);require(plan.operator_count>=2,"inspection-operators");
            for(size_t i=0;i<plan.operator_count;++i)plan.operators[i]=static_cast<transit_station_unified_inspection_operator>(select_name(r.field(v,e+"operators/"+decimal(i),true),operators,6));
            if(exists(r,v,e+"predicate/all"))plan.predicate=TRANSIT_UNIFIED_ALL;
            else if(exists(r,v,e+"predicate/state")){plan.predicate=TRANSIT_UNIFIED_IS_STATE;inspected_name(r,v,e+"predicate/state/column",plan.column);plan.state=static_cast<transit_station_unified_state>(select_name(r.field(v,e+"predicate/state/value",true),states,5));}
            else {plan.predicate=TRANSIT_UNIFIED_COMPARE;const char *comparisons[]={"eq","ne","lt","le","gt","ge"};inspected_name(r,v,e+"predicate/compare/column",plan.column);plan.comparison=static_cast<transit_station_comparison>(select_name(r.field(v,e+"predicate/compare/op",true),comparisons,6));plan.type=static_cast<transit_station_unified_type>(select_name(r.field(v,e+"predicate/compare/type",true),types,6));}
            plan.projection_count=array_size(r,v,e+"projection",8);for(size_t i=0;i<plan.projection_count;++i)inspected_name(r,v,e+"projection/"+decimal(i),plan.projection[i]);
            plan.has_limit=r.field(v,e+"limit")!="null";if(plan.has_limit)plan.limit=wide(r,v,e+"limit");const char *aggregates[]={"rows","count","sum"};plan.aggregate=static_cast<transit_station_aggregate>(select_name(r.field(v,e+"aggregate",true),aggregates,3));
            plan.output=inspected_columns(r,v,e+"columns");plan.budgets={wide(r,v,e+"budgets/pages"),wide(r,v,e+"budgets/segments"),wide(r,v,e+"budgets/result_bytes")};
        }
        *out=result;
    });
}
transit_sdk_error transit_station_unified_prepare_next(transit_station_unified_client *client,uint64_t ns,const transit_station_unified_bundle *bundle,transit_station_unified_prepared **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){require(ns&&bundle&&out,"query-next");auto value=prepared(n.local.raw,n.call("{\"next\":{\"namespace\":"+quote(decimal(ns))+",\"bundle\":"+quote(hex(bundle->bytes))+"}}"));*out=value.release();});
}
transit_sdk_error transit_station_unified_prepare_control(transit_station_unified_client *client,transit_station_unified_control command,uint64_t ns,transit_station_unified_prepared **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){require(ns&&out&&command>=TRANSIT_UNIFIED_CANCEL&&command<=TRANSIT_UNIFIED_COLLECT,"query-control");const char *names[]={"cancel","retire","collect"};auto value=prepared(n.local.raw,n.call("{\"prepare\":{"+quote(names[command])+":"+quote(decimal(ns))+"}}"));require(bool(value),"query-prepared");*out=value.release();});
}
transit_sdk_error transit_station_unified_submit(transit_station_unified_client *client,const transit_station_unified_prepared *command,uint64_t *out){
    Uninterruptible guard;if(out)*out=0;return run(client,[&](NativeQuery &n){require(command&&out,"query-submit");const auto v=n.call("{\"submit\":"+quote(string_bytes(view(command->bytes),8192))+"}",true);try{*out=n.local.raw.number(v,"receipt/position");}catch(...){fail(TRANSIT_SDK_UNKNOWN_OUTCOME,"query-receipt");}});
}
transit_sdk_error transit_station_unified_observe(transit_station_unified_client *client,uint64_t input,transit_station_unified_observation *out){
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){require(out,"query-observe");counter(input);const auto v=n.call("{\"observe\":"+decimal(input)+"}");transit_station_unified_observation result{};if(exists(n.local.raw,v,"observation/pending"))result.state=TRANSIT_UNIFIED_PENDING;else if(exists(n.local.raw,v,"observation/committed"))result.state=TRANSIT_UNIFIED_COMMITTED;else{result.state=TRANSIT_UNIFIED_REJECTED;const auto reason=unhex(n.local.raw.field(v,"observation/rejected",true),256);std::copy(reason.begin(),reason.end(),result.reason);}*out=result;});
}
transit_sdk_error transit_station_unified_status_read(transit_station_unified_client *client,uint64_t ns,transit_station_unified_status *out){
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){require(ns&&out,"query-status");const auto v=n.call("{\"status\":"+quote(decimal(ns))+"}");const auto &r=n.local.raw;if(r.field(v,"status")=="null")return;transit_station_unified_status result{};result.found=true;result.phase=static_cast<transit_station_unified_phase>(select_name(r.field(v,"status/phase",true),phases,8));result.correlation=wide(r,v,"status/correlation");fixed_bytes(r,v,"status/reference",result.reference,72);result.has_manifest=r.field(v,"status/manifest")!="null";if(result.has_manifest)fixed_bytes(r,v,"status/manifest",result.manifest,72);result.collected=r.boolean(v,"status/collected");*out=result;});
}
transit_sdk_error transit_station_unified_page_read(transit_station_unified_client *client,uint64_t ns,const transit_station_unified_cursor *cursor,transit_station_unified_page **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){require(ns&&out,"query-page");const auto v=n.call("{\"page\":{\"namespace\":"+quote(decimal(ns))+",\"cursor\":"+(cursor?quote(string_bytes(view(cursor->bytes),4096)):"null")+"}}");auto result=page_parse(n.local.raw,v,client->connection.source.realm);*out=result.release();});
}
transit_sdk_error transit_station_unified_page_get(const transit_station_unified_page *v,transit_station_unified_page_info *out){if(out)*out={};return boundary([&]{require(v&&out,"query-page");*out=v->info;});}
transit_sdk_error transit_station_unified_page_next(const transit_station_unified_page *v,transit_station_unified_cursor **out){if(out)*out=nullptr;return boundary([&]{require(v&&out,"query-page");if(v->next)*out=new transit_station_unified_cursor{*v->next};});}
void transit_station_unified_page_destroy(transit_station_unified_page *v){delete v;}
transit_sdk_error transit_station_unified_decode_arrow(const transit_station_unified_column *columns,size_t count,transit_sdk_bytes ipc,uint8_t rows,const char *directory,transit_station_unified_rows **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(out&&rows<=8,"query-arrow");const auto action="{\"inspect_arrow\":{\"columns\":"+columns_wire(columns,count)+",\"rows\":"+decimal(rows)+",\"ipc\":"+quote(hex(copy(ipc,65536)))+"}}";auto decoded=std::make_unique<transit_station_unified_rows>();Worker worker;worker.run([&]{Local local(directory);const auto v=codec(local,action);require(array_size(local.raw,v,"rows",8)==rows,"query-row-count");for(size_t row=0;row<rows;++row){std::vector<OwnedCell> cells;const auto path="rows/"+decimal(row);require(array_size(local.raw,v,path,8)==count,"query-column-count");for(size_t col=0;col<count;++col)cells.push_back(cell_parse(local.raw,v,path+"/"+decimal(col)));decoded->rows.push_back(std::move(cells));}});*out=decoded.release();});
}
transit_sdk_error transit_station_unified_rows_cell(const transit_station_unified_rows *v,size_t row,size_t col,transit_station_unified_cell *out){if(out)*out={};return boundary([&]{require(v&&out&&row<v->rows.size()&&col<v->rows[row].size(),"query-cell");*out=v->rows[row][col].get();});}
transit_sdk_error transit_station_unified_rows_alternative(const transit_station_unified_rows *v,size_t row,size_t col,size_t alt,transit_station_unified_alternative *out){if(out)*out={};return boundary([&]{require(v&&out&&row<v->rows.size()&&col<v->rows[row].size()&&alt<v->rows[row][col].alternatives.size(),"query-alternative");const auto &a=v->rows[row][col].alternatives[alt];*out={a.counter,a.replica,a.cell->get()};});}
void transit_station_unified_rows_destroy(transit_station_unified_rows *v){delete v;}
}

#include "internal.hpp"
#include "catalog_internal.hpp"
#include <transit/unified_query.h>
#include <cmath>
#include <limits>
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;
namespace logical = transit::sdk::logical_detail;

struct transit_station_unified_bundle { Bytes bytes; };
struct transit_station_unified_prepared { Bytes bytes; };
struct transit_station_unified_cursor { Bytes bytes; };
struct transit_station_unified_table_definition { logical::Arena arena; transit_station_catalog_schema schema{}; transit_station_unified_table_definition_view value{}; };
struct transit_station_unified_inspection { logical::Arena arena; transit_station_unified_inspection_info info{}; };
namespace {
const char *types[] = {"int64","uint64","float64","boolean","utf8","binary"};
const char *states[] = {"missing","null","type_error","value","conflict"};
const char *phases[] = {"uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"};
const char *type_name(transit_station_unified_decoder_type v) { require(v>=TRANSIT_UNIFIED_INT64 && v<=TRANSIT_UNIFIED_BINARY,"query-type");return types[v]; }
size_t select_name(const std::string &name,const char *const *names,size_t count) {
    for(size_t i=0;i<count;++i) if(name==names[i])return i;
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"query-variant");
}
std::string string_bytes(transit_sdk_bytes v,size_t bound) { const auto bytes=copy(v,bound);return {bytes.begin(),bytes.end()}; }
std::string query_name(const char *value) { const auto out=text(value,255);require(!out.empty(),"query-name");return out; }
std::string column_wire(const transit_station_unified_column &v) {
    require(v.type,"query-column-type");return logical::encode(logical::Json::object({
        {"name",logical::Json::string(query_name(v.name))},{"type",logical::type_json(*v.type)},
        {"nullable",logical::Json::boolean(v.nullable)},{"optional",logical::Json::boolean(v.optional)}}));
}
std::string decoder_column_wire(const transit_station_unified_decoder_column &v) { return "{\"name\":"+quote(text(v.name,32))+",\"type\":"+quote(type_name(v.type))+"}"; }
std::string columns_wire(const transit_station_unified_column *columns,size_t count) {
    require(columns && count>0 && count<=128,"query-columns");std::string out="[";
    for(size_t i=0;i<count;++i){if(i)out+=',';out+=column_wire(columns[i]);}return out+"]";
}
logical::Json digest_array(const uint8_t (&bytes)[32]) {
    auto out=logical::Json::array();for(const auto b:bytes)out.items.push_back(logical::Json::integer(b));return out;
}
logical::Json table_semantics(const transit_station_catalog_schema &schema) {
    require(schema.columns && schema.column_count>0 && schema.column_count<=128,"query-table-columns");
    auto result=logical::Json::array();
    for(size_t n=0;n<schema.column_count;++n)result.items.push_back(logical::Json::object({{"rounding",logical::Json{}},{"metric",logical::Json{}},{"timezone",logical::Json{}},{"spatial",logical::Json{}}}));
    return result;
}
logical::Json table_collations(const transit_station_catalog_schema &schema) {
    require(schema.columns && schema.column_count>0 && schema.column_count<=128,"query-table-columns");
    auto result=logical::Json::array();
    for(size_t n=0;n<schema.column_count;++n)result.items.push_back(transit::sdk::catalog_detail::collation_wire(schema.columns[n].collation));
    return result;
}
std::string table_wire(const transit_station_unified_source &source) {
    const auto &t=source.source.table;require(t.schema,"query-table-definition");
    const auto &s=*t.schema;const auto scope=t.scope;const auto &i=t.interpretation;
    counter(t.audience);counter(t.namespace_id);counter(scope.resource.realm);counter(scope.resource.resource);
    require(source.resource.realm==scope.resource.realm && source.resource.resource==scope.resource.resource && scope.catalog && t.branch && s.object && s.revision && i.revision && i.byte_count,"query-table-identity");
    require(s.columns && s.column_count>0 && s.column_count<=128,"query-table-columns");
    std::vector<transit_logical_field> fields;fields.reserve(s.column_count);
    for(size_t n=0;n<s.column_count;++n){const auto &c=s.columns[n];const auto name=query_name(c.name);fields.push_back({{reinterpret_cast<const uint8_t*>(c.name),name.size()},c.type,c.nullable,false});}
    transit_logical_type_view row{};row.kind=TRANSIT_LOGICAL_STRUCTURE;row.as.fields={fields.data(),fields.size()};
    using J=logical::Json;
    return logical::encode(J::object({{"table",J::object({
        {"scope",transit::sdk::catalog_detail::scope_wire(scope)},
        {"owner",J::integer(t.audience)},{"branch",J::string(decimal(t.branch))},{"namespace",J::integer(t.namespace_id)},{"object",J::string(decimal(s.object))},
        {"interpretation",J::object({{"revision",J::string(decimal(i.revision))},{"digest",digest_array(i.digest)},{"bytes",J::string(decimal(i.byte_count))},{"schema",digest_array(i.schema_digest)}})},
        {"row_type",logical::type_json(row)},{"collations",table_collations(s)},{"semantics",table_semantics(s)}})}}));
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
        source=table_wire(v);
    }else {
        require(v.kind==TRANSIT_UNIFIED_DOCUMENT,"query-source");const auto &d=v.source.document;const auto &r=d.reference;
        require(r.resource.realm==v.resource.realm && r.resource.resource==v.resource.resource,"query-document-resource");
        require(d.projections && d.projection_count>0 && d.projection_count<=8,"query-projections");
        std::string projections="[";const char *modes[]={"scalar","text","element_counter","element_replica"};
        for(size_t i=0;i<d.projection_count;++i){const auto &p=d.projections[i];require(p.mode>=TRANSIT_UNIFIED_SCALAR && p.mode<=TRANSIT_UNIFIED_ELEMENT_REPLICA,"query-projection-mode");if(i)projections+=',';
            projections+="{\"column\":"+decoder_column_wire(p.column)+",\"path\":"+path_wire(p.path,p.path_count)+",\"relative\":"+(p.relative?"true":"false")+",\"mode\":"+quote(modes[p.mode])+",\"text_bytes\":"+decimal(p.text_bytes)+",\"text_steps\":"+decimal(p.text_steps)+"}";}
        source="{\"document\":{\"reference\":{\"resource\":"+decimal(r.resource.resource)+",\"document\":"+quote(decimal(r.document))+",\"epoch\":"+quote(decimal(r.epoch))+",\"type_revision\":"+decimal(r.type_revision)+",\"revision\":"+quote(decimal(r.revision))+"},\"change_format\":1,\"expand\":"+(d.has_expansion?path_wire(d.expand,d.expand_count):"null")+",\"projections\":"+projections+"]}}";
    }
    return "{\"version\":1,\"resource\":"+decimal(v.resource.resource)+",\"source\":"+source+"}";
}
std::string scalar_wire(const transit_station_unified_scalar &v) {
    if(v.kind==TRANSIT_ATOM_UTF8 || v.kind==TRANSIT_ATOM_BINARY)require(v.as.bytes.size<=4096,"query-scalar-bound");
    return logical::encode(logical::atom_json(v));
}
std::string atom_wire(const transit_station_unified_predicate_atom &v) {
    const char *comparisons[]={"eq","ne","lt","le","gt","ge"};
    if(v.kind==TRANSIT_UNIFIED_ALL)return "{\"all\":{}}";
    require(v.column<128,"query-column");
    if(v.kind==TRANSIT_UNIFIED_IS_STATE){require(v.state>=TRANSIT_UNIFIED_MISSING && v.state<=TRANSIT_UNIFIED_CONFLICT,"query-state");return "{\"state\":{\"column\":"+decimal(v.column)+",\"value\":"+quote(states[v.state])+"}}";}
    require(v.kind==TRANSIT_UNIFIED_COMPARE,"query-predicate-atom");
    require(v.comparison>=TRANSIT_COMPARE_EQ && v.comparison<=TRANSIT_COMPARE_GE,"query-comparison");
    return "{\"compare\":{\"column\":"+decimal(v.column)+",\"op\":"+quote(comparisons[v.comparison])+",\"value\":"+scalar_wire(v.value)+"}}";
}
std::string predicate_wire(const transit_station_unified_plan &v) {
    if(v.predicate!=TRANSIT_UNIFIED_PROGRAM){
        require(!v.instructions && !v.instruction_count,"query-unused-program");
        return atom_wire({v.predicate,v.column,v.state,v.comparison,v.value});
    }
    require(v.instructions && v.instruction_count>0 && v.instruction_count<=64,"query-program-bound");
    const char *operators[]={"negate","conjunction","disjunction"};
    std::string result="{\"program\":[";
    for(size_t i=0;i<v.instruction_count;++i){
        const auto &instruction=v.instructions[i];if(i)result+=',';
        if(instruction.kind==TRANSIT_UNIFIED_ATOM)result+="{\"atom\":"+atom_wire(instruction.atom)+"}";
        else {
            require(instruction.kind>=TRANSIT_UNIFIED_NEGATE && instruction.kind<=TRANSIT_UNIFIED_DISJUNCTION,"query-program-instruction");
            result+="{"+quote(operators[instruction.kind-TRANSIT_UNIFIED_NEGATE])+":{}}";
        }
    }
    return result+"]}";
}
std::string plan_wire(const transit_station_unified_plan &v) {
    require(v.projection && v.projection_count>0 && v.projection_count<=128,"query-projection");
    require(v.aggregate>=TRANSIT_AGGREGATE_ROWS && v.aggregate<=TRANSIT_AGGREGATE_COUNT_VALUES,"query-aggregate");
    const char *aggregates[]={"rows","count","sum","count_values"};
    std::string projection="[",names="[";
    for(size_t i=0;i<128;++i){if(i>=v.projection_count)require(!v.output_names[i],"query-output-names");else{if(i)names+=',';names+=v.output_names[i]?quote(query_name(v.output_names[i])):"null";}}
    for(size_t i=0;i<v.projection_count;++i){require(v.projection[i]<128,"query-column");if(i)projection+=',';projection+=decimal(v.projection[i]);}
    const auto predicate=predicate_wire(v);
    return "{\"version\":1,\"scalar_program\":\"00\",\"projection\":"+projection+"],\"output_names\":"+names+"],\"predicate\":"+predicate+",\"aggregate\":"+quote(aggregates[v.aggregate])+",\"limit\":"+(v.has_limit?quote(decimal(v.limit)):"null")+"}";
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
template<size_t N> void inspected_name(const Raw &raw,const Bytes &bytes,const std::string &path,char (&out)[N]) {
    const auto value=raw.field(bytes,path,true);require(!value.empty() && value.size()<N && value.find('\0')==std::string::npos,"inspection-name");
    std::copy(value.begin(),value.end(),out);out[value.size()]='\0';
}
const transit_logical_type_view *parsed_type(const Raw &raw,const Bytes &bytes,const std::string &path,logical::Arena &arena) {
    auto *out=arena.array<transit_logical_type_view>(1);const auto text=raw.field(bytes,path);*out=logical::type_from(logical::JsonParser(text).parse(),arena);return out;
}
transit_station_unified_source_description inspected_columns(const Raw &raw,const Bytes &bytes,const std::string &path,logical::Arena &arena) {
    transit_station_unified_source_description out{};out.column_count=array_size(raw,bytes,path,128);require(out.column_count>0,"inspection-columns");
    for(size_t i=0;i<out.column_count;++i){const auto column=path+"/"+decimal(i);inspected_name(raw,bytes,column+"/name",out.columns[i].name);out.columns[i].type=parsed_type(raw,bytes,column+"/type",arena);out.columns[i].nullable=raw.boolean(bytes,column+"/nullable");out.columns[i].optional=raw.boolean(bytes,column+"/optional");}
    return out;
}
// Raw::field serializes parsed JSON canonically. Match the complete tagged
// object as well as the selected child so extra or nested variants cannot pass.
size_t inspected_tag(const Raw &raw,const Bytes &bytes,const std::string &path,const char *const *names,size_t count) {
    for(size_t i=0;i<count;++i)if(exists(raw,bytes,path+"/"+names[i])){
        const auto child=raw.field(bytes,path+"/"+names[i]);
        if(raw.field(bytes,path)!="{"+quote(names[i])+":"+child+"}")fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-tag");
        return i;
    }
    fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-tag");
}
transit_station_unified_inspected_atom inspected_atom(const Raw &raw,const Bytes &bytes,const std::string &path,logical::Arena &arena) {
    transit_station_unified_inspected_atom out{};const char *atoms[]={"all","state","compare"};
    out.kind=static_cast<transit_station_unified_predicate_kind>(inspected_tag(raw,bytes,path,atoms,3));
    const auto payload=path+"/"+atoms[out.kind];
    if(out.kind==TRANSIT_UNIFIED_ALL){if(raw.field(bytes,payload)!="{}")fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-all");}
    else {
        inspected_name(raw,bytes,payload+"/column",out.column);
        if(out.kind==TRANSIT_UNIFIED_IS_STATE)out.state=static_cast<transit_station_unified_state>(select_name(raw.field(bytes,payload+"/value",true),states,5));
        else {
            const char *comparisons[]={"eq","ne","lt","le","gt","ge"};
            out.comparison=static_cast<transit_station_comparison>(select_name(raw.field(bytes,payload+"/op",true),comparisons,6));
            out.type=parsed_type(raw,bytes,payload+"/type",arena);
        }
    }
    return out;
}
void inspected_predicate(const Raw &raw,const Bytes &bytes,const std::string &path,transit_station_unified_explanation &out,logical::Arena &arena) {
    const char *predicates[]={"all","state","compare","program"};
    out.predicate=static_cast<transit_station_unified_predicate_kind>(inspected_tag(raw,bytes,path,predicates,4));
    if(out.predicate!=TRANSIT_UNIFIED_PROGRAM){
        const auto atom=inspected_atom(raw,bytes,path,arena);std::copy_n(atom.column,256,out.column);
        out.state=atom.state;out.comparison=atom.comparison;out.type=atom.type;return;
    }
    const auto program=path+"/program";
    if(raw.field(bytes,program).front()!='[')fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-program-array");
    out.instruction_count=array_size(raw,bytes,program,64);size_t depth=0;
    const char *instructions[]={"atom","negate","conjunction","disjunction"};
    for(size_t i=0;i<out.instruction_count;++i){
        const auto at=program+"/"+decimal(i);auto &instruction=out.instructions[i];
        instruction.kind=static_cast<transit_station_unified_instruction_kind>(inspected_tag(raw,bytes,at,instructions,4));
        const auto payload=at+"/"+instructions[instruction.kind];
        if(instruction.kind==TRANSIT_UNIFIED_ATOM){instruction.atom=inspected_atom(raw,bytes,payload,arena);++depth;}
        else {
            const size_t needed=instruction.kind==TRANSIT_UNIFIED_NEGATE?1:2;
            if(raw.field(bytes,payload)!="{}" || depth<needed)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-program-shape");
            depth-=needed-1;
        }
    }
    if(depth!=1)fail(TRANSIT_SDK_INCOMPATIBLE_NATIVE,"inspection-program-shape");
}
struct NativeQuery {
    Local local;
    std::unique_ptr<station_query_client,decltype(&::station_unified_query_destroy)> handle;
    NativeQuery(const transit_sdk_config &config,const transit_sdk_credential &identity,transit_station_unified_connection c,const transit_station_unified_tables *tables)
        :local(config.native_directory),handle(nullptr,local.station_unified_query_destroy) {
        require(config.sdk_version==TRANSIT_SDK_VERSION,"query-sdk-version");credential(identity);process(c.source);process(c.requester);resource_check(c.resource);resource_check(c.requests);
        require(identity.realm==c.source.realm && c.source.realm==c.resource.realm && c.source.realm==c.requester.realm && c.source.realm==c.requests.realm,"query-realm");
        if(c.has_role)counter(c.role,true);
        std::string direct="null";
        if(tables) {
            require(tables->scope.resource.realm==identity.realm && tables->branch,"query-table-realm");counter(tables->audience);
            direct="{\"url\":"+quote(text(tables->url,2048))+",\"connection\":{\"scope\":"+logical::encode(transit::sdk::catalog_detail::scope_wire(tables->scope))+",\"branch\":"+quote(decimal(tables->branch))+",\"audience\":"+decimal(tables->audience)+",\"principal\":"+decimal(identity.principal)+",\"role\":"+(c.has_role?decimal(c.role):"null")+"}}";
        }
        const auto url=text(config.url,2048);const auto json="{\"connection\":{\"realm\":"+decimal(identity.realm)+",\"principal\":"+decimal(identity.principal)+",\"source\":"+decimal(c.source.pid)+",\"resource\":"+decimal(c.resource.resource)+",\"requester\":"+decimal(c.requester.pid)+",\"requests\":"+decimal(c.requests.resource)+",\"role\":"+(c.has_role?decimal(c.role):"null")+"},\"tables\":"+direct+",\"timeout_ms\":"+decimal(config.timeout_ms)+"}";
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

}
struct transit_station_unified_client {
    Worker worker;std::unique_ptr<NativeQuery> native;transit_station_unified_connection connection;
    explicit transit_station_unified_client(transit_station_unified_connection c):connection(c){}
    ~transit_station_unified_client(){worker.close([&]{native.reset();});}
};
struct transit_station_unified_page {logical::Arena arena;transit_station_unified_page_info info{};std::array<std::string,128> names;Bytes ipc;std::optional<Bytes> next;};
struct transit_station_unified_rows {logical::Arena arena;std::vector<std::vector<transit_logical_cell_view>> rows;};
namespace {
template<class F> transit_sdk_error run(transit_station_unified_client *owner,F &&work){return boundary([&]{require(owner,"query-client");owner->worker.run([&]{require(bool(owner->native),"query-client");work(*owner->native);});});}
std::unique_ptr<transit_station_unified_prepared> prepared(const Raw &raw,const Bytes &value) {
    if(raw.field(value,"prepared")=="null")return {};
    const auto text=raw.field(value,"prepared",true);require(text.size()<=8192,"query-prepared-bound");return std::make_unique<transit_station_unified_prepared>(transit_station_unified_prepared{Bytes(text.begin(),text.end())});
}
std::unique_ptr<transit_station_unified_page> page_parse(const Raw &raw,const Bytes &v,uint64_t realm) {
    auto out=std::make_unique<transit_station_unified_page>();auto &m=out->info.manifest;const std::string p="page/manifest/",b=p+"basis/";
    m.job=raw.number(v,p+"job");m.requester={realm,raw.number(v,p+"requester")};m.correlation=wide(raw,v,p+"correlation");m.policy_revision=wide(raw,v,p+"policy_revision");fixed_bytes(raw,v,p+"request",m.request,72);
    const char *kinds[]={"kv","table","document"};m.source_kind=static_cast<transit_station_unified_source_kind>(select_name(raw.field(v,b+"cut/kind",true),kinds,3));m.resource={realm,raw.number(v,b+"cut/resource")};
    const auto root=logical::parse(v);const auto &manifest=root.at("page").at("manifest");const auto &position=manifest.at("basis").at("cut").at("position");
    if(m.source_kind==TRANSIT_UNIFIED_TABLE) {
        manifest.at("source").fields({"table"});position.fields({"table"});
        m.source.table_worker={realm,raw.number(v,p+"source/table/worker")};digest(raw,v,b+"cut/position/table",m.cut.table_commitment);
    } else {
        manifest.at("source").fields({"native"});position.fields({"native_revision"});
        m.source.native_version=read_version(raw,v,p+"source/native");m.cut.native_revision=raw.number(v,b+"cut/position/native_revision",true);
    }
    digest(raw,v,b+"contract",m.source_digest);digest(raw,v,b+"schema",m.schema_digest);digest(raw,v,p+"plan",m.plan_digest);digest(raw,v,p+"chain",m.chain);
    m.pages=wide(raw,v,p+"pages");m.scanned=wide(raw,v,p+"scanned");m.selected=wide(raw,v,p+"selected");m.value_count=wide(raw,v,p+"value_count");m.segments=wide(raw,v,p+"segments");m.rows=wide(raw,v,p+"rows");m.byte_count=wide(raw,v,p+"bytes");
    m.has_sum=raw.field(v,p+"sum")!="null";if(m.has_sum)m.sum=signed_number(raw,v,p+"sum");const char *finished[]={"source_end","limit"};m.finished=static_cast<transit_station_unified_finished>(select_name(raw.field(v,p+"finished",true),finished,2));
    out->info.ordinal=wide(raw,v,"page/ordinal");const auto rows=raw.number(v,"page/rows",true);require(rows<=8,"query-row-bound");out->info.rows=static_cast<uint8_t>(rows);
    out->info.column_count=array_size(raw,v,"page/columns",128);require(out->info.column_count>0,"query-columns");
    for(size_t i=0;i<out->info.column_count;++i){const auto c="page/columns/"+decimal(i);out->names[i]=raw.field(v,c+"/name",true);require(!out->names[i].empty() && out->names[i].size()<=255 && out->names[i].find('\0')==std::string::npos,"query-column-name");out->info.columns[i]={out->names[i].c_str(),parsed_type(raw,v,c+"/type",out->arena),raw.boolean(v,c+"/nullable"),raw.boolean(v,c+"/optional")};}
    out->ipc=unhex(raw.field(v,"page/ipc",true),65536);out->info.ipc=view(out->ipc);
    if(raw.field(v,"page/next")!="null"){const auto next=raw.field(v,"page/next",true);require(next.size()<=4096,"query-cursor-bound");out->next=Bytes(next.begin(),next.end());}
    return out;
}
}
namespace transit::sdk::station_detail {
std::string query_plan_wire(const transit_station_unified_plan &value) { return plan_wire(value); }
}
extern "C" {
transit_sdk_error transit_station_unified_prepare_bundle(const transit_station_unified_source *source,const transit_station_unified_plan *plan,transit_station_unified_budgets budgets,const char *directory,transit_station_unified_bundle **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{
        require(source && plan && out,"query-bundle");const auto declaration=source_wire(*source);auto parameters=plan_wire(*plan);
        if(source->kind==TRANSIT_UNIFIED_TABLE){parameters.pop_back();parameters+=",\"collations\":"+logical::encode(table_collations(*source->source.table.schema))+"}";}
        const auto action="{\"prepare\":{\"source\":"+declaration+",\"plan\":"+parameters+",\"limits\":"+limits_wire(budgets)+"}}";
        auto bundle=std::make_unique<transit_station_unified_bundle>();Worker worker;worker.run([&]{Local local(directory);bundle->bytes=unhex(local.raw.field(codec(local,action),"prepared/bytes",true),TRANSIT_SDK_STATION_QUERY_BUNDLE_BYTES);});*out=bundle.release();
    });
}
transit_sdk_error transit_station_unified_bundle_import(transit_sdk_bytes bytes,transit_station_unified_bundle **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-bundle");*out=new transit_station_unified_bundle{copy(bytes,TRANSIT_SDK_STATION_QUERY_BUNDLE_BYTES)};});}
transit_sdk_error transit_station_unified_bundle_bytes(const transit_station_unified_bundle *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-bundle");*out=view(v->bytes);});}
void transit_station_unified_bundle_destroy(transit_station_unified_bundle *v){delete v;}
transit_sdk_error transit_station_unified_prepared_import(transit_sdk_bytes bytes,transit_station_unified_prepared **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-prepared");*out=new transit_station_unified_prepared{copy(bytes,8192)};});}
transit_sdk_error transit_station_unified_prepared_bytes(const transit_station_unified_prepared *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-prepared");*out=view(v->bytes);});}
void transit_station_unified_prepared_destroy(transit_station_unified_prepared *v){delete v;}
transit_sdk_error transit_station_unified_cursor_import(transit_sdk_bytes bytes,transit_station_unified_cursor **out){if(out)*out=nullptr;return boundary([&]{require(out,"query-cursor");*out=new transit_station_unified_cursor{copy(bytes,4096)};});}
transit_sdk_error transit_station_unified_cursor_bytes(const transit_station_unified_cursor *v,transit_sdk_bytes *out){if(out)*out={};return boundary([&]{require(v&&out,"query-cursor");*out=view(v->bytes);});}
void transit_station_unified_cursor_destroy(transit_station_unified_cursor *v){delete v;}
transit_sdk_error transit_station_unified_open(const transit_sdk_config *config,const transit_sdk_credential *credential,transit_station_unified_connection connection,const transit_station_unified_tables *tables,transit_station_unified_client **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(config && credential && out,"query-open");auto owner=std::make_unique<transit_station_unified_client>(connection);owner->worker.run([&]{owner->native=std::make_unique<NativeQuery>(*config,*credential,connection,tables);});*out=owner.release();});
}
transit_sdk_error transit_station_unified_close(transit_station_unified_client *v){Uninterruptible guard;return boundary([&]{require(v,"query-client");v->worker.close([&]{v->native.reset();});});}
void transit_station_unified_client_destroy(transit_station_unified_client *v){Uninterruptible guard;delete v;}
transit_sdk_error transit_station_unified_lookup_table(transit_station_unified_client *client,uint64_t ns,const char *name,transit_station_unified_table_definition **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){
        require(out,"query-table-output");counter(ns);
        const auto bytes=n.call("{\"table\":{\"namespace\":"+decimal(ns)+",\"name\":"+quote(query_name(name))+"}}");
        const auto root=logical::parse(bytes);const auto &v=root.at("table");if(v.is_null())return;
        v.fields({"source","schema","expected"});const auto &envelope=v.at("source");envelope.fields({"version","resource","source"});
        envelope.at("source").fields({"table"});const auto &direct=envelope.at("source").at("table");
        direct.fields({"scope","owner","branch","namespace","object","interpretation","row_type","collations","semantics"});
        direct.at("scope").fields({"realm","resource","catalog"});direct.at("interpretation").fields({"revision","digest","bytes","schema"});v.at("expected").fields({"partition","next_lsn"});
        const auto &r=n.local.raw;const std::string p="table/source/source/table/";
        auto owner=std::make_unique<transit_station_unified_table_definition>();auto &source=owner->value.source;auto &table=source.source.table;
        source.kind=TRANSIT_UNIFIED_TABLE;source.resource={r.number(bytes,p+"scope/realm"),r.number(bytes,p+"scope/resource")};
        table.scope={source.resource,wide(r,bytes,p+"scope/catalog")};table.audience=r.number(bytes,p+"owner");table.branch=wide(r,bytes,p+"branch");table.namespace_id=r.number(bytes,p+"namespace");
        auto &i=table.interpretation;i.revision=wide(r,bytes,p+"interpretation/revision");i.byte_count=wide(r,bytes,p+"interpretation/bytes");digest(r,bytes,p+"interpretation/digest",i.digest);digest(r,bytes,p+"interpretation/schema",i.schema_digest);
        owner->schema=transit::sdk::catalog_detail::schema(v.at("schema"),owner->arena);table.schema=&owner->schema;
        require(r.number(bytes,"table/source/version")==1 && source.resource.realm==client->connection.resource.realm && source.resource.resource==r.number(bytes,"table/source/resource") && table.namespace_id==ns && owner->schema.object==wide(r,bytes,p+"object"),"query-table-definition");
        // Normalize logical descriptors before comparison; JSON key order is not identity.
        const auto row=logical::type_from(direct.at("row_type"),owner->arena);
        const auto expected=logical::JsonParser(table_wire(source)).parse();
        require(logical::encode(logical::type_json(row))==logical::encode(expected.at("table").at("row_type")),"query-table-row-type");
        require(logical::encode(direct.at("collations"))==logical::encode(expected.at("table").at("collations")),"query-table-collations");
        const auto &semantics=direct.at("semantics");
        require(semantics.items.size()==owner->schema.column_count,"query-table-semantics");
        for(const auto &semantic:semantics.items){semantic.fields({"rounding","metric","timezone","spatial"});for(const auto *key:{"rounding","metric","timezone","spatial"})require(semantic.at(key).is_null(),"unsupported-column-semantics");}
        owner->value.partition=wide(r,bytes,"table/expected/partition");owner->value.next_lsn=wide(r,bytes,"table/expected/next_lsn");
        require(owner->value.partition,"query-table-partition");*out=owner.release();
    });
}
transit_sdk_error transit_station_unified_table_definition_get(const transit_station_unified_table_definition *v,const transit_station_unified_table_definition_view **out){if(out)*out=nullptr;return boundary([&]{require(v&&out,"query-table-definition");*out=&v->value;});}
void transit_station_unified_table_definition_destroy(transit_station_unified_table_definition *v){delete v;}
transit_sdk_error transit_station_unified_describe(transit_station_unified_client *client,const transit_station_unified_source *source,transit_station_unified_description *out){
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){require(source&&out,"query-description");require(source->resource.realm==client->connection.resource.realm&&(source->kind==TRANSIT_UNIFIED_TABLE||source->resource.resource==client->connection.resource.resource),"query-source-resource");const auto v=n.call("{\"describe\":"+source_wire(*source)+"}");const auto &r=n.local.raw;const std::string p="description/";transit_station_unified_description result{};
        result.resource_revision=r.number(v,p+"resource_revision",true);result.policy_revision=wide(r,v,p+"policy_revision");result.budgets={wide(r,v,p+"limits/pages"),wide(r,v,p+"limits/segments"),wide(r,v,p+"limits/result_bytes")};result.has_active=r.field(v,p+"active")!="null";if(result.has_active)result.active=wide(r,v,p+"active");result.bundle_bytes=r.number(v,p+"capabilities/bundle_bytes");result.segment_bytes=r.number(v,p+"capabilities/segment_bytes");result.batch_rows=r.number(v,p+"capabilities/batch_rows");*out=result;});
}
transit_sdk_error transit_station_unified_compile_sql(transit_station_unified_client *client,const transit_station_unified_source *source,const char *name,const char *sql,transit_station_unified_budgets budgets,const transit_station_unified_bindings *parameters,transit_station_unified_bundle **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){
        require(source&&out,"query-compilation");require(source->resource.realm==client->connection.resource.realm&&(source->kind==TRANSIT_UNIFIED_TABLE||source->resource.resource==client->connection.resource.resource),"query-source-resource");
        std::string values="null";
        if(parameters){require(parameters->count<=65 && (parameters->values || !parameters->count),"query-parameters");values="[";for(size_t i=0;i<parameters->count;++i){if(i)values+=',';values+=scalar_wire(parameters->values[i]);}values+=']';}
        const auto result=n.call("{\"compile\":{\"scope\":{\"source\":"+source_wire(*source)+",\"name\":"+quote(query_name(name))+",\"limits\":"+limits_wire(budgets)+"},\"sql\":"+quote(text(sql,4096))+",\"parameters\":"+values+"}}");
        *out=new transit_station_unified_bundle{unhex(n.local.raw.field(result,"compiled/bundle",true),TRANSIT_SDK_STATION_QUERY_BUNDLE_BYTES)};
    });
}
transit_sdk_error transit_station_unified_inspect_sql(transit_station_unified_client *client,const transit_station_unified_source *source,const char *name,const char *sql,transit_station_unified_budgets budgets,transit_station_unified_inspection **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){
        require(source&&out,"query-inspection");require(source->resource.realm==client->connection.resource.realm&&(source->kind==TRANSIT_UNIFIED_TABLE||source->resource.resource==client->connection.resource.resource),"query-source-resource");
        const auto v=n.call("{\"inspect\":{\"scope\":{\"source\":"+source_wire(*source)+",\"name\":"+quote(query_name(name))+",\"limits\":"+limits_wire(budgets)+"},\"sql\":"+quote(text(sql,4096))+"}}");
        const auto &r=n.local.raw;const std::string p="inspection/",d=p+"details/";auto owner=std::make_unique<transit_station_unified_inspection>();auto &result=owner->info;
        require(r.number(v,p+"version")==1&&r.field(v,p+"scope",true)=="configured_source"&&r.number(v,p+"resource")==source->resource.resource,"inspection-scope");
        inspected_name(r,v,p+"name",result.name);result.resource=source->resource;const char *kinds[]={"kv","table","document"};
        result.source_kind=static_cast<transit_station_unified_source_kind>(select_name(r.field(v,p+"source_kind",true),kinds,3));
        digest(r,v,p+"contract",result.source_digest);digest(r,v,p+"schema",result.schema_digest);
        result.resource_revision=r.number(v,p+"resource_revision",true);result.policy_revision=wide(r,v,p+"policy_revision");
        if(exists(r,v,d+"description")){result.kind=TRANSIT_UNIFIED_DESCRIPTION;result.details.description=inspected_columns(r,v,d+"description/columns",owner->arena);}
        else if(exists(r,v,d+"tables")){result.kind=TRANSIT_UNIFIED_TABLES;auto &list=result.details.tables;list.count=array_size(r,v,d+"tables",1);for(size_t i=0;i<list.count;++i)inspected_name(r,v,d+"tables/"+decimal(i),list.names[i]);}
        else {result.kind=TRANSIT_UNIFIED_EXPLANATION;const auto e=d+"explanation/";auto &plan=result.details.explanation;
            const char *operators[]={"scan","filter","limit","project","count","sum","count_values"};plan.operator_count=array_size(r,v,e+"operators",4);require(plan.operator_count>=2,"inspection-operators");
            for(size_t i=0;i<plan.operator_count;++i)plan.operators[i]=static_cast<transit_station_unified_inspection_operator>(select_name(r.field(v,e+"operators/"+decimal(i),true),operators,7));
            inspected_predicate(r,v,e+"predicate",plan,owner->arena);
            plan.projection_count=array_size(r,v,e+"projection",128);for(size_t i=0;i<plan.projection_count;++i)inspected_name(r,v,e+"projection/"+decimal(i),plan.projection[i]);
            plan.has_limit=r.field(v,e+"limit")!="null";if(plan.has_limit)plan.limit=wide(r,v,e+"limit");const char *aggregates[]={"rows","count","sum","count_values"};plan.aggregate=static_cast<transit_station_aggregate>(select_name(r.field(v,e+"aggregate",true),aggregates,4));
            plan.output=inspected_columns(r,v,e+"columns",owner->arena);plan.budgets={wide(r,v,e+"budgets/pages"),wide(r,v,e+"budgets/segments"),wide(r,v,e+"budgets/result_bytes")};
        }
        *out=owner.release();
    });
}
transit_sdk_error transit_station_unified_inspection_get(const transit_station_unified_inspection *v,const transit_station_unified_inspection_info **out){if(out)*out=nullptr;return boundary([&]{require(v&&out,"query-inspection");*out=&v->info;});}
void transit_station_unified_inspection_destroy(transit_station_unified_inspection *v){delete v;}
transit_sdk_error transit_station_unified_authorize_bundle(transit_station_unified_client *client,const transit_station_unified_bundle *bundle,const transit_station_unified_capture *capture,transit_station_unified_bundle **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){
        require(bundle&&out,"query-authorization");
        std::string binding="null";
        if(capture){counter(capture->executor);require(capture->operation && capture->partition,"query-capture");binding="{\"executor\":"+decimal(capture->executor)+",\"operation\":"+quote(decimal(capture->operation))+",\"expected\":{\"partition\":"+quote(decimal(capture->partition))+",\"next_lsn\":"+quote(decimal(capture->next_lsn))+"}}";}
        const auto result=n.call("{\"authorize\":{\"bundle\":"+quote(hex(bundle->bytes))+",\"capture\":"+binding+"}}");
        *out=new transit_station_unified_bundle{unhex(n.local.raw.field(result,"authorized",true),TRANSIT_SDK_STATION_QUERY_BUNDLE_BYTES)};
    });
}
transit_sdk_error transit_station_unified_prepare_cleanup(transit_station_unified_client *client,uint64_t ns,const transit_station_unified_bundle *bundle,transit_station_unified_prepared **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){require(ns&&bundle&&out,"query-cleanup");auto result=prepared(n.local.raw,n.call("{\"cleanup\":{\"namespace\":"+quote(decimal(ns))+",\"bundle\":"+quote(hex(bundle->bytes))+"}}"));require(bool(result),"query-cleanup-command");*out=result.release();});
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
    Uninterruptible guard;if(out)*out={};return run(client,[&](NativeQuery &n){require(ns&&out,"query-status");const auto v=n.call("{\"status\":"+quote(decimal(ns))+"}");const auto &r=n.local.raw;if(r.field(v,"status")=="null")return;transit_station_unified_status result{};result.found=true;result.phase=static_cast<transit_station_unified_phase>(select_name(r.field(v,"status/phase",true),phases,8));result.correlation=wide(r,v,"status/correlation");fixed_bytes(r,v,"status/reference",result.reference,72);result.has_manifest=r.field(v,"status/manifest")!="null";if(result.has_manifest)fixed_bytes(r,v,"status/manifest",result.manifest,72);result.collected=r.boolean(v,"status/collected");
        result.has_failure=r.field(v,"status/failure")!="null";
        if(result.has_failure){inspected_name(r,v,"status/failure/code",result.failure.code);inspected_name(r,v,"status/failure/stage",result.failure.stage);inspected_name(r,v,"status/failure/dimension",result.failure.dimension);result.failure.limit=wide(r,v,"status/failure/limit");result.failure.observed=wide(r,v,"status/failure/observed");}
        const auto diagnostic=r.field(v,"status/diagnostic");
        if(diagnostic!="null"){require(diagnostic.size()<=32768,"diagnostic-bound");result.diagnostic.size=diagnostic.size();std::copy(diagnostic.begin(),diagnostic.end(),result.diagnostic.json);}
        *out=result;});
}
transit_sdk_error transit_station_unified_page_read(transit_station_unified_client *client,uint64_t ns,const transit_station_unified_cursor *cursor,transit_station_unified_page **out){
    Uninterruptible guard;if(out)*out=nullptr;return run(client,[&](NativeQuery &n){require(ns&&out,"query-page");const auto v=n.call("{\"page\":{\"namespace\":"+quote(decimal(ns))+",\"cursor\":"+(cursor?quote(string_bytes(view(cursor->bytes),4096)):"null")+"}}");auto result=page_parse(n.local.raw,v,client->connection.source.realm);*out=result.release();});
}
transit_sdk_error transit_station_unified_page_get(const transit_station_unified_page *v,transit_station_unified_page_info *out){if(out)*out={};return boundary([&]{require(v&&out,"query-page");*out=v->info;});}
transit_sdk_error transit_station_unified_page_next(const transit_station_unified_page *v,transit_station_unified_cursor **out){if(out)*out=nullptr;return boundary([&]{require(v&&out,"query-page");if(v->next)*out=new transit_station_unified_cursor{*v->next};});}
void transit_station_unified_page_destroy(transit_station_unified_page *v){delete v;}
transit_sdk_error transit_station_unified_decode_arrow(const transit_station_unified_column *columns,size_t count,transit_sdk_bytes ipc,uint8_t rows,const char *directory,transit_station_unified_rows **out){
    Uninterruptible guard;if(out)*out=nullptr;return boundary([&]{require(out&&rows<=8,"query-arrow");const auto action="{\"inspect_arrow\":{\"columns\":"+columns_wire(columns,count)+",\"rows\":"+decimal(rows)+",\"ipc\":"+quote(hex(copy(ipc,65536)))+"}}";auto decoded=std::make_unique<transit_station_unified_rows>();Worker worker;worker.run([&]{Local local(directory);const auto v=logical::parse(codec(local,action));v.fields({"rows"});const auto &values=v.at("rows").array(8);require(values.size()==rows,"query-row-count");for(const auto &row:values){std::vector<transit_logical_cell_view> cells;const auto &columns=row.array(128);require(columns.size()==count,"query-column-count");for(const auto &cell:columns)cells.push_back(logical::cell_from(cell,decoded->arena));decoded->rows.push_back(std::move(cells));}});*out=decoded.release();});
}
transit_sdk_error transit_station_unified_rows_cell(const transit_station_unified_rows *v,size_t row,size_t col,transit_logical_cell_view *out){if(out)*out={};return boundary([&]{require(v&&out&&row<v->rows.size()&&col<v->rows[row].size(),"query-cell");*out=v->rows[row][col];});}

void transit_station_unified_rows_destroy(transit_station_unified_rows *v){delete v;}
}

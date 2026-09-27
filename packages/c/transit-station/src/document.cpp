#include "internal.hpp"
#include <cmath>
#include <limits>
using namespace transit::sdk::internal;
using namespace transit::sdk::station_detail;

namespace {
std::string bytes_text(const uint8_t *data, size_t size, size_t bound) {
    const auto bytes = copy({data,size},bound); return std::string(bytes.begin(),bytes.end());
}
std::string scalar(const transit_station_document_value &v) {
    switch (v.kind) {
    case TRANSIT_DOCUMENT_NULL: return "{\"null_value\":{}}";
    case TRANSIT_DOCUMENT_BOOLEAN: return std::string("{\"boolean\":") + (v.boolean ? "true}" : "false}");
    case TRANSIT_DOCUMENT_SIGNED: return "{\"signed\":" + quote(signed_decimal(v.signed_value)) + "}";
    case TRANSIT_DOCUMENT_UNSIGNED: return "{\"unsigned\":" + quote(decimal(v.unsigned_value)) + "}";
    case TRANSIT_DOCUMENT_FLOAT: {
        require(std::isfinite(v.float_value), "document-float");
        static_assert(sizeof(double) == 8 && std::numeric_limits<double>::is_iec559);
        uint64_t bits; std::memcpy(&bits,&v.float_value,8); Bytes bytes(8);
        for (size_t i=0;i<8;++i) bytes[i] = static_cast<uint8_t>(bits >> (i*8));
        return "{\"float_bits\":" + quote(hex(bytes)) + "}";
    }
    case TRANSIT_DOCUMENT_STRING: return "{\"string\":" + quote(bytes_text(v.bytes,v.size,96)) + "}";
    case TRANSIT_DOCUMENT_BINARY: return "{\"binary\":" + quote(hex(copy({v.bytes,v.size},96))) + "}";
    case TRANSIT_DOCUMENT_MAP: return "{\"map\":{}}";
    case TRANSIT_DOCUMENT_LIST: return "{\"list\":{}}";
    case TRANSIT_DOCUMENT_TEXT: return "{\"text\":{}}";
    case TRANSIT_DOCUMENT_CHARACTER: return "{\"character\":" + quote(bytes_text(v.bytes,v.size,4)) + "}";
    }
    fail(TRANSIT_SDK_INVALID_ARGUMENT,"document-value");
}
transit_station_document_value scalar_parse(const Raw &raw,const Bytes &bytes,const std::string &path) {
    transit_station_document_value out{};
    const char *kinds[] = {"null_value","boolean","signed","unsigned","float_bits","string","binary","map","list","text","character"};
    size_t found=11;
    for (size_t i=0;i<11;++i) if (exists(raw,bytes,path+"/"+kinds[i])) { require(found==11,"document-scalar-union"); found=i; }
    require(found<11,"document-scalar-kind"); out.kind=static_cast<transit_station_document_value_kind>(found);
    const auto key=path+"/"+kinds[found];
    if (found==1) out.boolean=raw.boolean(bytes,key);
    else if (found==2) out.signed_value=signed_number(raw,bytes,key);
    else if (found==3) out.unsigned_value=wide(raw,bytes,key);
    else if (found==4) {
        const auto data=unhex(raw.field(bytes,key,true),8); require(data.size()==8,"document-float");
        uint64_t bits=0; for(size_t i=0;i<8;++i) bits|=static_cast<uint64_t>(data[i])<<(8*i);
        std::memcpy(&out.float_value,&bits,8); require(std::isfinite(out.float_value),"document-float");
    } else if (found==5 || found==6 || found==10) {
        const auto encoded=raw.field(bytes,key,true);
        const auto data=found==6 ? unhex(encoded,96) : Bytes(encoded.begin(),encoded.end());
        require(data.size()<=(found==10 ? 4u : 96u),"document-value-bound");
        out.size=data.size(); std::copy(data.begin(),data.end(),out.bytes);
    }
    return out;
}
std::string observations(const transit_station_document_operation &op) {
    require(op.observed_count<=8,"document-observed-bound"); std::string out="[";
    for(size_t i=0;i<op.observed_count;++i) { if(i) out+=','; out+=document_dot(op.observed[i]); } return out+"]";
}
std::string operation(const transit_station_document_operation &op) {
    require(op.kind>=TRANSIT_DOCUMENT_ASSIGN && op.kind<=TRANSIT_DOCUMENT_DELETE_ELEMENT,"document-operation-kind");
    const char *kinds[]={"assign","remove","insert","set_element","delete_element"};
    std::string out="{"+quote(kinds[op.kind])+":{\"object\":"+document_dot(op.object);
    if(op.kind==TRANSIT_DOCUMENT_ASSIGN || op.kind==TRANSIT_DOCUMENT_REMOVE) out+=",\"field\":"+quote(bytes_text(op.field,op.field_size,64));
    if(op.kind==TRANSIT_DOCUMENT_INSERT) out+=",\"after\":"+document_dot(op.anchor);
    if(op.kind==TRANSIT_DOCUMENT_SET_ELEMENT || op.kind==TRANSIT_DOCUMENT_DELETE_ELEMENT) out+=",\"element\":"+document_dot(op.anchor);
    if(op.kind==TRANSIT_DOCUMENT_ASSIGN || op.kind==TRANSIT_DOCUMENT_REMOVE || op.kind==TRANSIT_DOCUMENT_SET_ELEMENT) out+=",\"observed\":"+observations(op);
    if(op.kind==TRANSIT_DOCUMENT_ASSIGN || op.kind==TRANSIT_DOCUMENT_INSERT || op.kind==TRANSIT_DOCUMENT_SET_ELEMENT) out+=",\"value\":"+scalar(op.value);
    return out+"}}";
}
size_t array_size(const Raw &raw,const Bytes &bytes,const std::string &path,size_t bound) {
    const auto text=raw.field(bytes,path); require(!text.empty() && text.front()=='[',"document-array");
    size_t count=0; while(count<=bound && exists(raw,bytes,path+"/"+decimal(count))) ++count;
    require(count<=bound,"document-array-bound"); return count;
}
uint32_t u32(const Raw &raw,const Bytes &bytes,const std::string &path) {
    const auto value=raw.number(bytes,path,true); require(value<=UINT32_MAX,"document-u32"); return static_cast<uint32_t>(value);
}
Bytes document_apply(transit_station_turn &turn,const std::string &action) {
    if(!turn.bridge->local.caps.document_owner) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY,"document-owner");
    return turn_apply(turn,"{\"document\":"+action+"}");
}
std::string identity(transit_sdk_resource resource,uint64_t document) {
    counter(resource.realm); counter(resource.resource); require(document,"document-identity");
    return "{\"resource\":"+decimal(resource.resource)+",\"document\":"+quote(decimal(document))+"}";
}
std::string job(uint64_t document,uint64_t value) {
    require(document && value,"document-job"); return "\"document\":"+quote(decimal(document))+",\"job\":"+quote(decimal(value));
}
transit_station_document_progress progress(const Raw &raw,const Bytes &bytes) {
    transit_station_document_progress out{}; const auto path=std::string("document/progress/");
    const auto kind=raw.field(bytes,path+"phase",true); const char *kinds[]={"progress","accepted","duplicate","checkpoint_complete"};
    size_t index=0; for(;index<4 && kind!=kinds[index];++index) {} require(index<4,"document-progress");
    out.phase=static_cast<transit_station_document_phase>(index); out.has_revision=raw.field(bytes,path+"revision")!="null";
    require((index==0)!=out.has_revision,"document-progress-revision"); if(out.has_revision) out.revision=wide(raw,bytes,path+"revision"); return out;
}
}
namespace transit::sdk::station_detail {
Bytes document_codec(Local &local,const std::string &action) {
    require(action.size()<=32768,"document-codec-bound");
    if(!local.caps.document_codecs) fail(TRANSIT_SDK_UNSUPPORTED_CAPABILITY,"document-codecs");
    station_buffer *buffer=nullptr;
    const auto status=local.station_document_codec(reinterpret_cast<const uint8_t *>(action.data()),action.size(),&buffer);
    return local.result(status,buffer,"document-codec");
}
std::string document_dot(transit_station_document_dot dot) {
    require((dot.counter==0)==(dot.replica==0),"document-dot");
    return "{\"counter\":"+quote(decimal(dot.counter))+",\"replica\":"+quote(decimal(dot.replica))+"}";
}
transit_station_document_dot document_dot_parse(const Raw &raw,const Bytes &bytes,const std::string &path) {
    transit_station_document_dot out{wide(raw,bytes,path+"/counter"),wide(raw,bytes,path+"/replica")}; (void)document_dot(out); return out;
}
transit_station_document_change document_change_parse(const Raw &raw,const Bytes &bytes,const std::string &path) {
    transit_station_document_change out{};
    out.document=wide(raw,bytes,path+"/document"); out.epoch=wide(raw,bytes,path+"/epoch"); out.type_revision=u32(raw,bytes,path+"/type_revision");
    out.replica=wide(raw,bytes,path+"/replica"); out.previous=wide(raw,bytes,path+"/previous"); out.first=wide(raw,bytes,path+"/first");
    out.operation_count=array_size(raw,bytes,path+"/operations",8); require(out.operation_count,"document-empty-change");
    const char *kinds[]={"assign","remove","insert","set_element","delete_element"};
    for(size_t i=0;i<out.operation_count;++i) {
        auto &op=out.operations[i]; const auto base=path+"/operations/"+decimal(i); size_t index=5;
        for(size_t k=0;k<5;++k) if(exists(raw,bytes,base+"/"+kinds[k])) { require(index==5,"document-operation-union"); index=k; }
        require(index<5,"document-operation"); op.kind=static_cast<transit_station_document_operation_kind>(index); const auto key=base+"/"+kinds[index];
        op.object=document_dot_parse(raw,bytes,key+"/object");
        if(index<=1) { const auto field=raw.field(bytes,key+"/field",true); require(field.size()<=64,"document-field"); op.field_size=field.size(); std::copy(field.begin(),field.end(),op.field); }
        if(index==2) op.anchor=document_dot_parse(raw,bytes,key+"/after");
        if(index>=3) op.anchor=document_dot_parse(raw,bytes,key+"/element");
        if(index==0 || index==1 || index==3) { op.observed_count=array_size(raw,bytes,key+"/observed",8); for(size_t k=0;k<op.observed_count;++k) op.observed[k]=document_dot_parse(raw,bytes,key+"/observed/"+decimal(k)); }
        if(index==0 || index==2 || index==3) op.value=scalar_parse(raw,bytes,key+"/value");
    }
    return out;
}
std::string document_reference(Local &local,const transit_station_document_reference &ref) {
    (void)identity(ref.resource,ref.document);
    const auto value=document_codec(local,"{\"reference\":{\"resource\":"+decimal(ref.resource.resource)+",\"document\":"+quote(decimal(ref.document))+",\"epoch\":"+quote(decimal(ref.epoch))+",\"type_revision\":"+decimal(ref.type_revision)+",\"revision\":"+quote(decimal(ref.revision))+"}}");
    const auto out=local.raw.field(value,"reference",true); require(unhex(out,40).size()==40,"document-reference"); return out;
}
transit_station_document_reference document_reference_parse(Local &local,uint64_t realm,const std::string &encoded) {
    counter(realm); require(unhex(encoded,40).size()==40,"document-reference");
    const auto value=document_codec(local,"{\"inspect_reference\":"+quote(encoded)+"}"); const auto &raw=local.raw; const std::string p="inspected_reference/";
    return {{realm,raw.number(value,p+"resource")},wide(raw,value,p+"document"),wide(raw,value,p+"epoch"),u32(raw,value,p+"type_revision"),wide(raw,value,p+"revision")};
}
transit_station_document_field document_field_parse(const Raw &raw,const Bytes &bytes,const std::string &path) {
    transit_station_document_field out{}; const char *kinds[]={"missing","null_value","scalar","object","conflict"}; const auto kind=raw.field(bytes,path+"/status",true);
    size_t index=0; for(;index<5 && kind!=kinds[index];++index) {} require(index<5,"document-status"); out.status=static_cast<transit_station_document_status>(index);
    out.count=array_size(raw,bytes,path+"/assignments",8);
    require((index==0)==(out.count==0) && (index==4)==(out.count>1),"document-register");
    for(size_t i=0;i<out.count;++i) { const auto p=path+"/assignments/"+decimal(i); out.assignments[i]={document_dot_parse(raw,bytes,p+"/id"),scalar_parse(raw,bytes,p+"/value")}; }
    return out;
}
}
extern "C" {
transit_sdk_error transit_station_document_prepare(const transit_station_document_change *change,const char *directory,transit_station_document_prepared **out) {
    Uninterruptible guard; if(out) *out=nullptr;
    return boundary([&] {
        require(change && out && change->operation_count>0 && change->operation_count<=8,"document-change");
        std::string ops="["; for(size_t i=0;i<change->operation_count;++i) { if(i) ops+=','; ops+=operation(change->operations[i]); } ops+=']';
        const auto action="{\"prepare\":{\"document\":"+quote(decimal(change->document))+",\"epoch\":"+quote(decimal(change->epoch))+",\"type_revision\":"+decimal(change->type_revision)+",\"replica\":"+quote(decimal(change->replica))+",\"previous\":"+quote(decimal(change->previous))+",\"first\":"+quote(decimal(change->first))+",\"operations\":"+ops+"}}";
        auto prepared=std::make_unique<transit_station_document_prepared>(); prepared->document=change->document;
        Worker worker; worker.run([&] { Local local(directory); const auto value=document_codec(local,action); prepared->bytes=unhex(local.raw.field(value,"prepared/bytes",true),4096); }); *out=prepared.release();
    });
}
transit_sdk_error transit_station_document_prepared_bytes(const transit_station_document_prepared *value,transit_sdk_bytes *out) {
    if(out) *out={}; return boundary([&] { require(value && out,"document-prepared"); *out=view(value->bytes); });
}
void transit_station_document_prepared_destroy(transit_station_document_prepared *value) { delete value; }
transit_sdk_error transit_station_document_decode(transit_sdk_bytes bytes,const char *directory,transit_station_document_change *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] { require(out,"document-change"); const auto action="{\"decode\":"+quote(hex(copy(bytes,4096)))+"}"; Worker worker; worker.run([&] { Local local(directory); *out=document_change_parse(local.raw,document_codec(local,action),"change"); }); });
}
transit_sdk_error transit_station_document_reference_encode(const transit_station_document_reference *reference,const char *directory,uint8_t out[40]) {
    Uninterruptible guard; if(out) std::memset(out,0,40); return boundary([&] { require(reference && out,"document-reference"); Worker worker; worker.run([&] { Local local(directory); const auto bytes=unhex(document_reference(local,*reference),40); std::copy(bytes.begin(),bytes.end(),out); }); });
}
transit_sdk_error transit_station_document_reference_decode(uint64_t realm,transit_sdk_bytes bytes,const char *directory,transit_station_document_reference *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] { require(out,"document-reference"); const auto encoded=hex(copy(bytes,40)); Worker worker; worker.run([&] { Local local(directory); *out=document_reference_parse(local,realm,encoded); }); });
}
transit_sdk_error transit_station_turn_document_create(transit_station_turn *turn,uint64_t document,uint32_t type,transit_station_document_limits limits) {
    return with_turn(turn,false,[&](auto &owner) { require(document,"document-identity"); document_apply(owner,"{\"create\":{\"document\":"+quote(decimal(document))+",\"type_revision\":"+decimal(type)+",\"record_bytes\":"+decimal(limits.record_bytes)+",\"staging_bytes\":"+quote(decimal(limits.staging_bytes))+",\"staging_records\":"+decimal(limits.staging_records)+"}}"); });
}
transit_sdk_error transit_station_turn_document_stage(transit_station_turn *turn,uint64_t document,uint64_t id,const transit_station_document_prepared *change,uint32_t node_limit,transit_station_document_progress *out) {
    if(out) *out={}; return with_turn(turn,false,[&](auto &owner) { require(change && out && document==change->document,"document-stage"); const auto value=document_apply(owner,"{\"stage\":{"+job(document,id)+",\"change\":"+quote(hex(change->bytes))+",\"node_limit\":"+decimal(node_limit)+"}}"); *out=progress(owner.bridge->local.raw,value); });
}
transit_sdk_error transit_station_turn_document_checkpoint(transit_station_turn *turn,uint64_t document,uint64_t id,transit_station_document_progress *out) {
    if(out) *out={}; return with_turn(turn,false,[&](auto &owner) { require(out,"document-checkpoint"); *out=progress(owner.bridge->local.raw,document_apply(owner,"{\"checkpoint\":{"+job(document,id)+"}}")); });
}
transit_sdk_error transit_station_turn_document_merge_window(transit_station_turn *turn,uint64_t document,uint64_t revisions) {
    return with_turn(turn,false,[&](auto &owner) { require(document,"document-identity"); document_apply(owner,"{\"merge_window\":{\"document\":"+quote(decimal(document))+",\"revisions\":"+quote(decimal(revisions))+"}}"); });
}
transit_sdk_error transit_station_turn_document_reject(transit_station_turn *turn,uint64_t document,uint64_t id,bool checkpoint) {
    return with_turn(turn,false,[&](auto &owner) { document_apply(owner,"{\"reject\":{"+job(document,id)+",\"checkpoint\":"+(checkpoint?"true":"false")+"}}"); });
}
transit_sdk_error transit_station_turn_document_collect(transit_station_turn *turn,uint64_t document,uint64_t id,bool checkpoint,bool retired,bool *out) {
    if(out) *out=false; return with_turn(turn,false,[&](auto &owner) { require(out,"document-collect"); const auto value=document_apply(owner,"{\"collect\":{"+job(document,id)+",\"checkpoint\":"+(checkpoint?"true":"false")+",\"retired\":"+(retired?"true":"false")+"}}"); *out=owner.bridge->local.raw.boolean(value,"document/collected"); });
}
transit_sdk_error transit_station_turn_document_retire(transit_station_turn *turn,uint64_t document) {
    return with_turn(turn,false,[&](auto &owner) { require(document,"document-identity"); document_apply(owner,"{\"retire\":"+quote(decimal(document))+"}"); });
}
transit_sdk_error transit_station_document_describe(transit_station_document_reader *reader,transit_sdk_resource resource,uint64_t document,transit_station_document_description *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] {
        require(out,"document-description"); const auto action="{\"describe\":"+identity(resource,document)+"}";
        document_reader_run(reader,resource.realm,[&](auto &bridge) {
            const auto value=bridge.document_read(action); const auto &raw=bridge.local.raw; const std::string p="description/";
            *out={document_reference_parse(bridge.local,resource.realm,raw.field(value,p+"reference",true)),raw.number(value,p+"source_revision",true),wide(raw,value,p+"floor"),wide(raw,value,p+"merge_window"),wide(raw,value,p+"active_job"),raw.boolean(value,p+"retired"),u32(raw,value,p+"change_format")}; return Bytes{};
        });
    });
}
transit_sdk_error transit_station_document_path_read(transit_station_document_reader *reader,const transit_station_document_reference *ref,const transit_sdk_bytes *names,size_t count,transit_station_document_path *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] {
        require(ref && names && count>0 && count<=16 && out,"document-path"); std::string path="[";
        for(size_t i=0;i<count;++i) { if(i) path+=','; path+=quote(bytes_text(names[i].data,names[i].size,64)); } path+=']';
        document_reader_run(reader,ref->resource.realm,[&](auto &bridge) { const auto encoded=document_reference(bridge.local,*ref);
            const auto value=bridge.document_read("{\"path\":{\"reference\":"+quote(encoded)+",\"names\":"+path+"}}"); const auto &raw=bridge.local.raw;
            require(raw.field(value,"field/reference",true)==encoded,"document-reference"); *out={*ref,raw.number(value,"field/source_revision",true),document_field_parse(raw,value,"field/value")}; return Bytes{};
        });
    });
}
transit_sdk_error transit_station_document_sequence(transit_station_document_reader *reader,const transit_station_document_reference *ref,transit_station_document_dot object,const char *cursor,transit_station_document_page *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] {
        require(ref && out,"document-page"); const auto continuation=cursor?quote(text(cursor,1024)):"null"; const auto dot=document_dot(object);
        document_reader_run(reader,ref->resource.realm,[&](auto &bridge) { const auto encoded=document_reference(bridge.local,*ref);
            const auto value=bridge.document_read("{\"sequence\":{\"reference\":"+quote(encoded)+",\"object\":"+dot+",\"cursor\":"+continuation+"}}"); const auto &raw=bridge.local.raw;
            require(raw.field(value,"page/reference",true)==encoded,"document-reference"); transit_station_document_page page{}; page.reference=*ref; page.source_revision=raw.number(value,"page/source_revision",true);
            page.count=array_size(raw,value,"page/items",8); for(size_t i=0;i<page.count;++i) { const auto p="page/items/"+decimal(i); page.items[i]={document_dot_parse(raw,value,p+"/id"),document_field_parse(raw,value,p+"/values")}; }
            if(raw.field(value,"page/next")!="null") { const auto next=raw.field(value,"page/next",true); require(next.size()<=1024 && next.find('\0')==std::string::npos,"document-cursor"); page.has_next=true; std::copy(next.begin(),next.end(),page.next); } *out=page; return Bytes{};
        });
    });
}
transit_sdk_error transit_station_document_resynchronize(transit_station_document_reader *reader,transit_sdk_resource resource,uint64_t document,uint64_t replica,transit_station_document_resynchronization *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] {
        require(out && replica,"document-resynchronize"); const auto action="{\"resynchronize\":{\"identity\":"+identity(resource,document)+",\"replica\":"+quote(decimal(replica))+"}}";
        document_reader_run(reader,resource.realm,[&](auto &bridge) { const auto value=bridge.document_read(action); const auto &raw=bridge.local.raw; const std::string p="resynchronization/";
            *out={document_reference_parse(bridge.local,resource.realm,raw.field(value,p+"reference",true)),wide(raw,value,p+"floor"),wide(raw,value,p+"replica"),wide(raw,value,p+"previous_counter"),wide(raw,value,p+"clock")}; return Bytes{};
        });
    });
}
transit_sdk_error transit_station_document_accepted_change(transit_station_document_reader *reader,const transit_station_document_reference *ref,transit_station_document_change *out) {
    Uninterruptible guard; if(out) *out={}; return boundary([&] { require(ref && out,"document-change"); document_reader_run(reader,ref->resource.realm,[&](auto &bridge) {
        const auto encoded=document_reference(bridge.local,*ref); *out=document_change_parse(bridge.local.raw,bridge.document_read("{\"accepted_change\":"+quote(encoded)+"}"),"change"); return Bytes{};
    }); });
}
}

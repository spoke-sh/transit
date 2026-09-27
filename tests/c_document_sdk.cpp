#include <transit/station.hpp>
#include "c_document_sdk.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <thread>
using namespace transit::sdk;
using namespace transit::sdk::station;
struct Config {
    std::string mode,url,seed,fixtures; uint64_t principal,pid,generation,resource; std::array<Bytes,2> changes;
    ServiceConfig service() const { auto cfg=ClientConfig::growing(url); cfg.timeout(15000); return ServiceConfig(cfg,ProcessRef(72,pid),principal,generation,seed); }
};
static Bytes unhex(const std::string &s) { assert(s.size()%2==0); Bytes out; for(size_t i=0;i<s.size();i+=2) out.push_back(static_cast<uint8_t>(std::stoul(s.substr(i,2),nullptr,16))); return out; }
static void report(const std::string &s) { std::cout<<s<<std::endl; }
template<class F> static void expect(transit_sdk_error_kind kind,F &&f,const char *code=nullptr) { bool failed=false; try { f(); } catch(const Error &e) { assert(e.detail().kind==kind); if(code) assert(std::string(e.detail().code)==code); failed=true; } assert(failed); }
static PreparedDocumentChange prepare(const Bytes &bytes) {
#ifdef TRANSIT_TEST_C_API
    transit_station_document_change change{}; check(transit_station_document_decode(bytes_view(bytes),nullptr,&change)); transit_station_document_prepared *out=nullptr; check(transit_station_document_prepare(&change,nullptr,&out)); return PreparedDocumentChange(out);
#else
    return prepare_document(decode_document(bytes));
#endif
}
static void golden(const Config &cfg) {
    std::ifstream file(cfg.fixtures); std::string ref; file>>ref;
#ifdef TRANSIT_TEST_C_API
    transit_station_document_reference decoded{}; check(transit_station_document_reference_decode(72,bytes_view(unhex(ref)),nullptr,&decoded));
    assert(decoded.document==UINT64_MAX && decoded.revision==UINT64_MAX); Bytes encoded(40); check(transit_station_document_reference_encode(&decoded,nullptr,encoded.data())); assert(encoded==unhex(ref));
#else
    const auto reference=DocumentReference::decode(72,unhex(ref)); assert(reference.document==UINT64_MAX && reference.revision==UINT64_MAX && reference.data()==unhex(ref));
#endif
    std::string line; while(file>>line) {
        const auto bytes=unhex(line); auto prepared=prepare(bytes); assert(prepared.data()==bytes);
        for(const size_t n:{size_t(0),size_t(1),bytes.size()-1}) { bool rejected=false; try { prepare(Bytes(bytes.begin(),bytes.begin()+n)); } catch(const Error &) { rejected=true; } assert(rejected); }
    }
#ifdef TRANSIT_TEST_C_API
    transit_station_document_prepared *out=nullptr; check(document_test_bootstrap(&out)); PreparedDocumentChange bootstrap(out);
#else
    auto bootstrap=prepare_document({UINT64_MAX,1,1,UINT64_MAX,0,1,{
        DocumentAssign{{},"value",{},int64_t{INT64_MIN}}, DocumentAssign{{},"body",{},DocumentText{}}, DocumentInsert{{2,UINT64_MAX},{},U'🙂'}
    }});
    expect(TRANSIT_SDK_INVALID_ARGUMENT,[&] { prepare_document({1,1,1,1,0,1,{DocumentAssign{{},"x",{},char32_t{0xd800}}}}); });
#endif
    assert(bootstrap.data()==cfg.changes[0]); report("{\"codecs\":true}");
}
#ifdef TRANSIT_TEST_C_API
class Reader {
    std::unique_ptr<transit_station_document_reader,decltype(&transit_station_document_reader_destroy)> value_;
public:
    explicit Reader(transit_station_document_reader *v):value_(v,transit_station_document_reader_destroy) {}
    DocumentDescription describe(ResourceRef resource,uint64_t id) { transit_station_document_description v{}; check(transit_station_document_describe(value_.get(),resource.native(),id,&v)); return {DocumentReference::from_native(v.reference),v.source_revision,v.floor,v.merge_window,v.active_job,v.retired,v.change_format}; }
    DocumentPath path(const DocumentReference &reference,const std::vector<std::string> &names) { const auto ref=reference.native(); std::vector<transit_sdk_bytes> path; for(const auto &name:names) path.push_back({reinterpret_cast<const uint8_t *>(name.data()),name.size()}); transit_station_document_path out{}; check(transit_station_document_path_read(value_.get(),&ref,path.data(),path.size(),&out)); return {reference,out.source_revision,DocumentField::from_native(out.field)}; }
    DocumentPage sequence(const DocumentReference &reference,DocumentDot object) { const auto ref=reference.native(); transit_station_document_page out{}; check(transit_station_document_sequence(value_.get(),&ref,object.native(),nullptr,&out)); DocumentPage page{reference,out.source_revision,{},out.has_next?std::optional<std::string>(out.next):std::nullopt}; for(size_t i=0;i<out.count;++i) page.items.push_back({DocumentDot::from_native(out.items[i].id),DocumentField::from_native(out.items[i].field)}); return page; }
    DocumentChange accepted_change(const DocumentReference &reference) { const auto ref=reference.native(); transit_station_document_change out{}; check(transit_station_document_accepted_change(value_.get(),&ref,&out)); return DocumentChange::from_native(out); }
    DocumentResynchronization resynchronize(ResourceRef resource,uint64_t doc,uint64_t replica) { transit_station_document_resynchronization out{}; check(transit_station_document_resynchronize(value_.get(),resource.native(),doc,replica,&out)); return {DocumentReference::from_native(out.reference),out.floor,out.replica,out.previous_counter,out.clock}; }
};
class Controller {
    document_test_context context_{};
    std::unique_ptr<transit_station_runner,decltype(&transit_station_runner_destroy)> value_{nullptr,transit_station_runner_destroy};
public:
    Controller(const Config &cfg,const std::array<PreparedDocumentChange,2> &changes) {
        context_.changes[0]=changes[0].native(); context_.changes[1]=changes[1].native();
        const auto service=cfg.service(); const auto config=service.native(); const auto handler=document_test_handler(&context_); const auto codec=document_test_codec(); const transit_station_options options{TRANSIT_FAILURE_STOP,TRANSIT_RECOVERY_FRESH_OWNERSHIP,nullptr,nullptr,nullptr}; transit_station_runner *out=nullptr;
        check(transit_station_runner_open(&config,&handler,&codec,&options,&out)); value_.reset(out);
    }
    ~Controller() { value_.reset(); transit_station_turn_release(context_.escaped); }
    Event next() { transit_station_event *out=nullptr; check(transit_station_runner_next(value_.get(),&out)); return Event(out); }
    void close() { transit_station_event *out=nullptr; check(transit_station_runner_close(value_.get(),&out)); transit_station_event_destroy(out); }
    Reader documents() { transit_station_document_reader *out=nullptr; check(transit_station_documents_open(value_.get(),&out)); return Reader(out); }
    int phase() const { return context_.phase; }
    void expired() { expect(TRANSIT_SDK_TURN_EXPIRED,[&] { check(transit_station_turn_document_merge_window(context_.escaped,UINT64_MAX,0)); }); }
};
#else
class ByteCodec final:public Codec<Bytes> {
public:
    const char *type_id() const noexcept override { return "test.document-control"; }
    uint32_t version() const noexcept override { return 1; }
    size_t max_encoded_bytes() const noexcept override { return 243; }
    Bytes encode(const Bytes &v) const override { return v; } Bytes decode(const Bytes &v) const override { return v; }
};
struct Shared { int phase=-1; std::optional<DocumentOwner> escaped; };
class DocumentHandler final:public Handler<Bytes> {
    const std::array<PreparedDocumentChange,2> &changes_; Shared &shared_;
public:
    DocumentHandler(const std::array<PreparedDocumentChange,2> &changes,Shared &shared):changes_(changes),shared_(shared) {}
    void initialize(Turn &turn) override { turn.document(UINT64_MAX).create(1); }
    void handle(Turn &turn,const Incoming<Bytes> &input) override {
        const auto &value=std::get<Cast<Bytes>>(input).value; const std::string command(value.begin(),value.end()); auto owner=turn.document(UINT64_MAX); shared_.escaped=owner; shared_.phase=-1;
        if(command=="initialize") return;
        if(command=="window") { owner.merge_window(2); return; }
        if(command=="retire") { owner.retire(); return; }
        if(command=="checkpoint") { shared_.phase=static_cast<int>(owner.checkpoint(90).phase); return; }
        assert(command=="0" || command=="1"); const auto index=value[0]-'0'; shared_.phase=static_cast<int>(owner.stage(index+1,changes_[index],256).phase);
    }
};
using Reader=DocumentReader;
class Controller {
    Shared shared_; Runner<Bytes> value_;
public:
    Controller(const Config &cfg,const std::array<PreparedDocumentChange,2> &changes):value_(Runner<Bytes>::open(cfg.service(),std::make_unique<DocumentHandler>(changes,shared_),std::make_shared<ByteCodec>(),RunnerOptions::fresh_ownership())) {}
    Event next() { return value_.next(); } void close() { value_.close(); }
    Reader documents() { return value_.documents(); } int phase() const { return shared_.phase; }
    void expired() { expect(TRANSIT_SDK_TURN_EXPIRED,[&] { shared_.escaped->merge_window(0); }); }
};
#endif
static void drive(const Config &cfg) {
    const std::array<PreparedDocumentChange,2> changes{prepare(cfg.changes[0]),prepare(cfg.changes[1])};
    auto runner=std::make_unique<Controller>(cfg,changes); auto reader=runner->documents(); std::optional<DocumentReference> saved;
    const ResourceRef resource(72,cfg.resource); std::string command;
    while(std::getline(std::cin,command)) {
        if(command=="one") {
            bool committed=false; for(size_t i=0;i<12;++i) { const auto event=runner->next().info(); if(event.kind==TRANSIT_EVENT_COMMITTED) { committed=true; break; } assert(event.kind==TRANSIT_EVENT_PROGRESS); } assert(committed); runner->expired();
            const char *names[]={"progress","accepted","duplicate","checkpoint_complete"}; const int phase=runner->phase(); report("{\"event\":\"committed\",\"phase\":"+(phase<0?std::string("null"):std::string("\"")+names[phase]+"\"")+"}");
        } else if(command=="read") {
            const auto description=reader.describe(resource,UINT64_MAX); const auto ref=description.reference; assert(description.floor==0 && description.merge_window==0);
            const auto field=reader.path(ref,{"value"}).field; const auto page=reader.sequence(ref,{2,UINT64_MAX}); assert(!page.next);
            std::u32string text; for(const auto &item:page.items) text+=std::get<char32_t>(item.field.assignments.at(0).value);
            assert(text==(ref.revision==2?U"🙂":U"🙂́")); assert(std::get<int64_t>(field.assignments[0].value)==INT64_MIN);
            assert(reader.path(ref,{"missing"}).field.status==DocumentStatus::Missing);
            assert(prepare_document(reader.accepted_change(ref)).data()==cfg.changes.at(ref.revision-2)); if(!saved) saved=ref;
            assert(field.status==(ref.revision==2?DocumentStatus::Scalar:DocumentStatus::Conflict));
            report("{\"revision\":\""+std::to_string(ref.revision)+"\",\"items\":"+std::to_string(page.items.size())+",\"status\":\""+(ref.revision==2?"scalar":"conflict")+"\"}");
        } else if(command=="old") { assert(reader.path(*saved,{"value"}).field.status==DocumentStatus::Scalar); report("{\"retained\":true}"); }
        else if(command=="denied") { expect(TRANSIT_SDK_ACCESS_DENIED,[&] { reader.path(*saved,{"value"}); }); report("{\"denied\":true}"); }
        else if(command=="resynchronize") { const auto result=reader.resynchronize(resource,UINT64_MAX,UINT64_MAX); assert(result.reference.revision==3); report("{\"previous\":\""+std::to_string(result.previous_counter)+"\",\"clock\":\""+std::to_string(result.clock)+"\"}"); }
        else if(command=="retired") { assert(reader.describe(resource,UINT64_MAX).retired); expect(TRANSIT_SDK_READ_FAILED,[&] { reader.path(*saved,{"value"}); },"DocumentRetired"); report("{\"retired\":true}"); }
        else if(command=="async-close") {
            std::thread work([&] { auto other=std::make_unique<Controller>(cfg,changes); auto owned=other->documents(); const auto description=owned.describe(resource,UINT64_MAX); assert(description.retired); other->close(); other.reset(); expect(TRANSIT_SDK_CLOSED,[&] { owned.describe(resource,UINT64_MAX); }); assert(description.reference.document==UINT64_MAX); }); work.join(); report("{\"joined\":true}");
        } else { assert(command=="close"); runner->close(); runner.reset(); expect(TRANSIT_SDK_CLOSED,[&] { reader.describe(resource,UINT64_MAX); }); report("{\"closed\":true}"); return; }
    }
}
int main(int argc,char **argv) {
    assert(argc==12); Config cfg{argv[1],argv[2],argv[6],argv[9],std::stoull(argv[3]),std::stoull(argv[4]),std::stoull(argv[5]),std::stoull(argv[8]),{unhex(argv[10]),unhex(argv[11])}};
    try { if(cfg.mode=="document-codecs") golden(cfg); else drive(cfg); }
    catch(const Error &e) { std::cerr<<e.what()<<" kind="<<e.detail().kind<<" code="<<e.detail().code<<std::endl; return 1; }
}

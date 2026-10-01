#include <transit/unified_query.hpp>
#include <cassert>
#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cstring>
#include "unified_inspection_fixture.h"
using namespace transit::sdk;
using namespace transit::sdk::station;
namespace q = transit::sdk::station::unified;
static Bytes read(const std::string &path) { std::ifstream in(path,std::ios::binary); assert(in); return Bytes(std::istreambuf_iterator<char>(in),{}); }
static std::string hex(const Bytes &v) { const char *digits="0123456789abcdef"; std::string out; for(uint8_t b:v) { out+=digits[b>>4]; out+=digits[b&15]; } return out; }
static Bytes unhex(const std::string &s) { if(s=="-")return {}; assert(s.size()%2==0); Bytes out; for(size_t i=0;i<s.size();i+=2)out.push_back(static_cast<uint8_t>(std::stoul(s.substr(i,2),nullptr,16))); return out; }
static std::string maybe_hex(const std::optional<q::Prepared> &v) { return v?"\""+hex(v->data())+"\"":"null"; }
static void inspection(const q::Inspection &value) {
    transit_station_unified_inspection out{};
    auto name=[](char (&dst)[33],const std::string &src){assert(src.size()<=32);std::memcpy(dst,src.c_str(),src.size()+1);};
    auto columns=[&](const std::vector<q::Column> &values){transit_station_unified_source_description result{};assert(values.size()<=8);result.column_count=values.size();for(size_t i=0;i<values.size();++i){name(result.columns[i].name,values[i].name);result.columns[i].type=static_cast<transit_station_unified_type>(values[i].type);}return result;};
    name(out.name,value.name);out.resource=value.resource.native();out.source_kind=static_cast<transit_station_unified_source_kind>(value.source_kind);
    std::copy(value.source_digest.begin(),value.source_digest.end(),out.source_digest);std::copy(value.schema_digest.begin(),value.schema_digest.end(),out.schema_digest);
    out.resource_revision=value.resource_revision;out.policy_revision=value.policy_revision;
    std::visit([&](const auto &d){using T=std::decay_t<decltype(d)>;
        if constexpr(std::is_same_v<T,q::SourceDescription>){out.kind=TRANSIT_UNIFIED_DESCRIPTION;out.details.description=columns(d.columns);}
        else if constexpr(std::is_same_v<T,q::TableListing>){out.kind=TRANSIT_UNIFIED_TABLES;assert(d.names.size()<=1);out.details.tables.count=d.names.size();for(size_t i=0;i<d.names.size();++i)name(out.details.tables.names[i],d.names[i]);}
        else {
            out.kind=TRANSIT_UNIFIED_EXPLANATION;auto &plan=out.details.explanation;assert(d.operators.size()<=4&&d.projection.size()<=8);
            plan.operator_count=d.operators.size();for(size_t i=0;i<d.operators.size();++i)plan.operators[i]=static_cast<transit_station_unified_inspection_operator>(d.operators[i]);
            plan.projection_count=d.projection.size();for(size_t i=0;i<d.projection.size();++i)name(plan.projection[i],d.projection[i]);
            plan.output=columns(d.columns);plan.has_limit=d.limit.has_value();plan.limit=d.limit.value_or(0);plan.aggregate=static_cast<transit_station_aggregate>(d.aggregate);plan.budgets={d.budgets.pages,d.budgets.segments,d.budgets.result_bytes};
            std::visit([&](const auto &p){using P=std::decay_t<decltype(p)>;
                if constexpr(std::is_same_v<P,q::InspectedState>){plan.predicate=TRANSIT_UNIFIED_IS_STATE;name(plan.column,p.column);plan.state=static_cast<transit_station_unified_state>(p.state);}
                else if constexpr(std::is_same_v<P,q::InspectedComparison>){plan.predicate=TRANSIT_UNIFIED_COMPARE;name(plan.column,p.column);plan.comparison=static_cast<transit_station_comparison>(p.comparison);plan.type=static_cast<transit_station_unified_type>(p.type);}
                else if constexpr(std::is_same_v<P,q::InspectedProgram>){
                    plan.predicate=TRANSIT_UNIFIED_PROGRAM;assert(p.instructions.size()<=64);plan.instruction_count=p.instructions.size();
                    for(size_t i=0;i<p.instructions.size();++i)std::visit([&](const auto &instruction){using I=std::decay_t<decltype(instruction)>;auto &out_instruction=plan.instructions[i];
                        if constexpr(std::is_same_v<I,q::InspectedAtom>){out_instruction.kind=TRANSIT_UNIFIED_ATOM;auto &out_atom=out_instruction.atom;
                            std::visit([&](const auto &a){using A=std::decay_t<decltype(a)>;
                                if constexpr(std::is_same_v<A,q::InspectedState>){out_atom.kind=TRANSIT_UNIFIED_IS_STATE;name(out_atom.column,a.column);out_atom.state=static_cast<transit_station_unified_state>(a.state);}
                                else if constexpr(std::is_same_v<A,q::InspectedComparison>){out_atom.kind=TRANSIT_UNIFIED_COMPARE;name(out_atom.column,a.column);out_atom.comparison=static_cast<transit_station_comparison>(a.comparison);out_atom.type=static_cast<transit_station_unified_type>(a.type);}
                            },instruction);
                        }else {switch(instruction){
                            case q::PredicateOperator::Negate:out_instruction.kind=TRANSIT_UNIFIED_NEGATE;break;
                            case q::PredicateOperator::Conjunction:out_instruction.kind=TRANSIT_UNIFIED_CONJUNCTION;break;
                            case q::PredicateOperator::Disjunction:out_instruction.kind=TRANSIT_UNIFIED_DISJUNCTION;break;
                        }}
                    },p.instructions[i]);
                }
                else plan.predicate=TRANSIT_UNIFIED_ALL;
            },d.predicate);
        }
    },value.details);
    print_inspection(&out);
}
static q::Source source(ResourceRef resource,int kind,bool golden) {
    if(kind==0)return q::KvSource{resource,golden?Bytes{'d','a','t','a','/'}:Bytes{'k'},{q::Type::Binary},{golden?q::Type::UInt64:q::Type::Utf8}};
    if(kind==1)return q::TableSource{resource,static_cast<uint32_t>(golden?9:1),{"id",golden?"label":"value"},q::Type::Utf8};
    if(golden)return q::DocumentSource{{resource,UINT64_MAX,3,1,42},{{{"title",q::Type::Utf8},{"title"}},{{"body",q::Type::Utf8},{"body"},false,q::ProjectionMode::Text}},std::nullopt};
    return q::DocumentSource{{resource,17,1,1,13},{
        {{"value",q::Type::Utf8},{},true},{{"counter",q::Type::UInt64},{},true,q::ProjectionMode::ElementCounter},
        {{"replica",q::Type::UInt64},{},true,q::ProjectionMode::ElementReplica},{{"optional",q::Type::Utf8},{"optional"}}},std::vector<std::string>{"items"}};
}
static q::Bundle bundle(const q::Source &source,int kind,bool golden,bool named=false,bool compound=false) {
    std::optional<std::vector<std::optional<std::string>>> names;
    if(named){names.emplace(golden?2:kind==2?4:1);(*names)[0]="Result";}
    q::Plan plan{golden?std::vector<uint8_t>{1,0}:kind==2?std::vector<uint8_t>{0,1,2,3}:std::vector<uint8_t>{1},
        q::Compare{static_cast<uint8_t>(golden?1:kind==2?0:1),Comparison::Ne,golden&&kind==0?q::Scalar{uint64_t{UINT64_MAX}}:q::Scalar{std::string(512,'x')}},
        Aggregate::Rows,golden?std::optional<uint64_t>{UINT64_MAX}:std::nullopt,names};
    if(compound){
        assert(!golden);const auto comparison=std::get<q::Compare>(plan.predicate);const auto column=comparison.column;
        const auto ceiling=std::string("東京🙂/")+std::string(kind==2?64:128,'x')+(kind==2?"/10":"/39");
        plan.predicate=q::PredicateProgram{{q::PredicateAtom{comparison},q::PredicateAtom{q::Compare{column,Comparison::Ge,ceiling}},
            q::PredicateAtom{q::IsState{column,q::State::Null}},q::PredicateOperator::Disjunction,q::PredicateOperator::Negate,q::PredicateOperator::Conjunction}};
    }
    return q::prepare(source,plan,{1000,static_cast<uint64_t>(golden?500:100),1048576});
}
static void boolean_codecs(const std::string &root) {
    const std::array<q::Scalar,7> values{int64_t{INT64_MIN},uint64_t{UINT64_MAX},-0.0,true,std::string("café é 🙂"),Bytes{0,255,128},std::string(512,'x')};
    for(size_t i=0;i<9;++i){
        const auto type=i<6?static_cast<q::Type>(i):i==6?q::Type::Utf8:q::Type::Int64;
        q::Source source=q::KvSource{ResourceRef(46,7),{},{type},{q::Type::UInt64}};
        std::vector<q::PredicateInstruction> instructions;
        if(i<7)instructions={q::PredicateAtom{q::Compare{0,Comparison::Eq,values[i]}},q::PredicateOperator::Negate,q::PredicateAtom{q::IsState{0,q::State::Null}},q::PredicateOperator::Disjunction};
        else if(i==7)instructions={q::PredicateAtom{All{}},q::PredicateAtom{q::IsState{0,q::State::Null}},q::PredicateOperator::Negate,q::PredicateOperator::Conjunction};
        else {instructions.emplace_back(q::PredicateAtom{All{}});instructions.insert(instructions.end(),63,q::PredicateOperator::Negate);}
        q::PredicateProgram program{instructions};instructions.clear();
        auto bundle=q::prepare(source,{{0},program,Aggregate::Rows,std::nullopt,std::nullopt},{1000,500,1048576});program.instructions.clear();
        assert(bundle.data()==read(root+"/boolean"+std::to_string(i)+".bin"));
    }
    q::Source source=q::KvSource{ResourceRef(46,7),{},{q::Type::Int64},{q::Type::UInt64}};
    std::vector<q::PredicateInstruction> oversized{q::PredicateAtom{All{}}};oversized.insert(oversized.end(),64,q::PredicateOperator::Negate);
    const std::vector<std::vector<q::PredicateInstruction>> invalid{{},{q::PredicateOperator::Negate},{q::PredicateAtom{All{}},q::PredicateAtom{All{}}},oversized,
        {static_cast<q::PredicateOperator>(99)},{q::PredicateAtom{q::IsState{7,q::State::Null}}},{q::PredicateAtom{q::Compare{0,Comparison::Eq,std::string("wrong type")}}}};
    for(const auto &instructions:invalid){bool rejected=false;try{q::prepare(source,{{0},q::PredicateProgram{instructions},Aggregate::Rows,std::nullopt,std::nullopt},{1,1,1024});}catch(const Error &){rejected=true;}assert(rejected);}
}
static void codecs(const std::string &root) {
    for(int kind=0;kind<3;++kind) { auto b=bundle(source(ResourceRef(46,7),kind,true),kind,true); assert(b.data()==read(root+"/bundle"+std::to_string(kind)+".bin")); assert(bundle(source(ResourceRef(46,7),kind,true),kind,true,true).data()==read(root+"/named-bundle"+std::to_string(kind)+".bin"));
        q::Plan counted{{1},All{},Aggregate::CountValues,std::nullopt,std::vector<std::optional<std::string>>{"present"}};
        assert(q::prepare(source(ResourceRef(46,7),kind,true),counted,{1000,500,1048576}).data()==read(root+"/counted-bundle"+std::to_string(kind)+".bin")); }
    boolean_codecs(root);
    const std::vector<q::Column> columns{{"int64",q::Type::Int64},{"uint64",q::Type::UInt64},{"float64",q::Type::Float64},{"boolean",q::Type::Boolean},{"utf8",q::Type::Utf8},{"binary",q::Type::Binary}};
    auto ipc=read(root+"/arrow.ipc"); const auto rows=q::decode_arrow(columns,ipc,5); std::fill(ipc.begin(),ipc.end(),0);
    const std::array<q::Scalar,6> expected{int64_t{INT64_MIN},uint64_t{UINT64_MAX},-0.0,false,std::string("café é 東京🙂"),Bytes{0,255,128}};
    for(size_t row=0;row<5;++row)for(size_t col=0;col<6;++col) {
        const auto &cell=rows.at(row).at(col); assert(cell.index()==row);
        if(row==2)assert(std::get<q::TypeError>(cell).actual_kind=="map");
        if(row==3)assert(std::get<q::Scalar>(cell)==expected[col]);
        if(row==4) { const auto &a=std::get<q::Conflict>(cell).alternatives; assert(a.size()==2 && a[0].counter==UINT64_MAX && a[0].replica==1 && a[1].counter==UINT64_MAX && a[1].replica==2); assert(std::get<q::Scalar>(a[0].value)==expected[col] && std::holds_alternative<q::Null>(a[1].value)); }
    }
    assert(std::signbit(std::get<double>(std::get<q::Scalar>(rows[3][2]))));
    assert(q::decode_arrow(columns,read(root+"/empty.ipc"),0).empty());
    bool rejected=false; try { q::decode_arrow(columns,read(root+"/malformed.ipc"),5); }catch(const Error &) { rejected=true; } assert(rejected);
    std::cout<<"C++ installed unified codecs: three sources, nine Boolean bundles, six types, five states, owned values and malformed rejection passed"<<std::endl;
}
static void serve(char **args) {
    const auto realm=std::stoull(args[6]); const ResourceRef resource(realm,std::stoull(args[9]));
    const q::Connection connection{ProcessRef(realm,std::stoull(args[8])),resource,ProcessRef(realm,std::stoull(args[10])),ResourceRef(realm,std::stoull(args[11]))};
    const int kind=std::string(args[4])=="kv"?0:std::string(args[4])=="table"?1:2;
    const auto definition=source(resource,kind,false); assert(bundle(definition,kind,false,true,std::string(args[12])=="compound").data()==read(args[5]));
    std::optional<q::Client> owner(q::Client::open(ClientConfig::growing(args[2]).timeout(10000),Credential(realm,std::stoull(args[7]),args[3]),connection));
    auto &client=*owner; const auto description=client.describe(definition); assert(description.bundle_bytes==16384&&description.batch_rows==8);
    std::optional<q::Page> saved; std::cout<<"{\"ready\":true}"<<std::endl;
    std::string line;
    while(std::getline(std::cin,line)) {
        std::istringstream input(line); std::string command,arg,token; input>>command>>arg>>token;
        if(command=="close")break;
        try {
            std::string result;
            if(command=="inspect"){
                q::Budgets budgets{};input>>budgets.pages>>budgets.segments>>budgets.result_bytes;assert(input);
                const auto bytes=unhex(token);const auto value=client.inspect_sql(definition,arg,std::string(bytes.begin(),bytes.end()),budgets);
                assert(value.resource.resource()==resource.resource()&&static_cast<int>(value.source_kind)==kind);
                std::cout<<"{\"status\":0,\"value\":";inspection(value);std::cout<<"}"<<std::endl;continue;
            }
            else if(command=="next")result="{\"prepared_hex\":"+maybe_hex(client.prepare_next(std::stoull(arg),q::Bundle::recover(unhex(token))))+"}";
            else if(command=="submit") {
                const auto bytes=unhex(arg); auto prepared=q::Prepared::recover(bytes);
                try { result="{\"receipt\":{\"position\":"+std::to_string(client.submit(prepared).position)+"}}"; }
                catch(const Error &) { assert(prepared.data()==bytes); throw; }
            }else if(command=="observe") {
                const auto v=client.observe(std::stoull(arg)); const char *names[]={"pending","committed","rejected"};
                result=std::string("{\"observation\":{\"")+names[static_cast<size_t>(v.state)]+"\":"+(v.state==q::Observed::Rejected?"\""+hex(Bytes(v.reason.begin(),v.reason.end()))+"\"":"{}")+"}}";
            }else if(command=="status") {
                const auto v=client.status(std::stoull(arg)); const char *names[]={"uploading","sealed","admitted","complete","cancelled","denied","rejected","retired"};
                result=std::string("{\"status\":")+(v?"{\"phase\":\""+std::string(names[static_cast<size_t>(v->phase)])+"\",\"correlation\":\""+std::to_string(v->correlation)+"\"}":"null")+"}";
            }else {
                assert(command=="page"); std::optional<q::Cursor> cursor; if(token!="-")cursor.emplace(q::Cursor::recover(unhex(token)));
                auto page=client.page(std::stoull(arg),cursor?&*cursor:nullptr);
                assert(page.manifest.source_kind==static_cast<transit_station_unified_source_kind>(kind) && page.manifest.resource.resource==resource.resource()); assert(page.decode().size()==page.rows);
                result="{\"page\":{\"ordinal\":\""+std::to_string(page.ordinal)+"\",\"ipc\":\""+hex(page.ipc)+"\",\"manifest\":{\"segments\":\""+std::to_string(page.manifest.segments)+"\",\"selected\":\""+std::to_string(page.manifest.selected)+"\",\"value_count\":\""+std::to_string(page.manifest.value_count)+"\"},\"next_hex\":"+(page.next?"\""+hex(page.next->data())+"\"":"null")+"}}";
                saved=std::move(page);
            }
            std::cout<<"{\"status\":0,\"value\":"<<result<<"}"<<std::endl;
        }catch(const Error &error) { const auto &e=error.detail(); assert(e.has_native_status); std::cout<<"{\"status\":"<<e.native_status<<",\"value\":{\"err\":\""<<e.code<<"\"}}"<<std::endl; }
    }
    client.close(); bool closed=false; try { client.describe(definition); }catch(const Error &e) { closed=e.detail().kind==TRANSIT_SDK_CLOSED; } assert(closed); owner.reset();
    if(saved)assert(saved->decode().size()==saved->rows);
    std::cout<<"{\"closed\":true}"<<std::endl;
}
int main(int argc,char **argv) {
    assert(argc>=3);
    try { if(std::string(argv[1])=="codecs")codecs(argv[2]);else { assert(argc==13); serve(argv); } }
    catch(const Error &e) { std::cerr<<e.what()<<" status="<<e.detail().native_status<<" code="<<e.detail().code<<std::endl; return 1; }
}

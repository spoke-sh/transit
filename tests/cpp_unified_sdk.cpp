#include <transit/unified_query.hpp>
#include <transit/catalog.hpp>
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
    transit_station_unified_inspection_info out{};
    auto name=[](char (&dst)[256],const std::string &src){assert(src.size()<=255);std::memcpy(dst,src.c_str(),src.size()+1);};
    auto columns=[&](const std::vector<q::Column> &values){transit_station_unified_source_description result{};assert(values.size()<=128);result.column_count=values.size();for(size_t i=0;i<values.size();++i){name(result.columns[i].name,values[i].name);result.columns[i].type=&values[i].type.native();result.columns[i].nullable=values[i].nullable;result.columns[i].optional=values[i].optional;}return result;};
    name(out.name,value.name);out.resource=value.resource.native();out.source_kind=static_cast<transit_station_unified_source_kind>(value.source_kind);
    std::copy(value.source_digest.begin(),value.source_digest.end(),out.source_digest);std::copy(value.schema_digest.begin(),value.schema_digest.end(),out.schema_digest);
    out.resource_revision=value.resource_revision;out.policy_revision=value.policy_revision;
    std::visit([&](const auto &d){using T=std::decay_t<decltype(d)>;
        if constexpr(std::is_same_v<T,q::SourceDescription>){out.kind=TRANSIT_UNIFIED_DESCRIPTION;out.details.description=columns(d.columns);}
        else if constexpr(std::is_same_v<T,q::TableListing>){out.kind=TRANSIT_UNIFIED_TABLES;assert(d.names.size()<=1);out.details.tables.count=d.names.size();for(size_t i=0;i<d.names.size();++i)name(out.details.tables.names[i],d.names[i]);}
        else {
            out.kind=TRANSIT_UNIFIED_EXPLANATION;auto &plan=out.details.explanation;assert(d.operators.size()<=4&&d.projection.size()<=128);
            plan.operator_count=d.operators.size();for(size_t i=0;i<d.operators.size();++i)plan.operators[i]=static_cast<transit_station_unified_inspection_operator>(d.operators[i]);
            plan.projection_count=d.projection.size();for(size_t i=0;i<d.projection.size();++i)name(plan.projection[i],d.projection[i]);
            plan.output=columns(d.columns);plan.has_limit=d.limit.has_value();plan.limit=d.limit.value_or(0);plan.aggregate=static_cast<transit_station_aggregate>(d.aggregate);plan.budgets={d.budgets.pages,d.budgets.segments,d.budgets.result_bytes};
            std::visit([&](const auto &p){using P=std::decay_t<decltype(p)>;
                if constexpr(std::is_same_v<P,q::InspectedState>){plan.predicate=TRANSIT_UNIFIED_IS_STATE;name(plan.column,p.column);plan.state=static_cast<transit_station_unified_state>(p.state);}
                else if constexpr(std::is_same_v<P,q::InspectedComparison>){plan.predicate=TRANSIT_UNIFIED_COMPARE;name(plan.column,p.column);plan.comparison=static_cast<transit_station_comparison>(p.comparison);plan.type=&p.type.native();}
                else if constexpr(std::is_same_v<P,q::InspectedProgram>){
                    plan.predicate=TRANSIT_UNIFIED_PROGRAM;assert(p.instructions.size()<=64);plan.instruction_count=p.instructions.size();
                    for(size_t i=0;i<p.instructions.size();++i)std::visit([&](const auto &instruction){using I=std::decay_t<decltype(instruction)>;auto &out_instruction=plan.instructions[i];
                        if constexpr(std::is_same_v<I,q::InspectedAtom>){out_instruction.kind=TRANSIT_UNIFIED_ATOM;auto &out_atom=out_instruction.atom;
                            std::visit([&](const auto &a){using A=std::decay_t<decltype(a)>;
                                if constexpr(std::is_same_v<A,q::InspectedState>){out_atom.kind=TRANSIT_UNIFIED_IS_STATE;name(out_atom.column,a.column);out_atom.state=static_cast<transit_station_unified_state>(a.state);}
                                else if constexpr(std::is_same_v<A,q::InspectedComparison>){out_atom.kind=TRANSIT_UNIFIED_COMPARE;name(out_atom.column,a.column);out_atom.comparison=static_cast<transit_station_comparison>(a.comparison);out_atom.type=&a.type.native();}
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
static q::TableSource table_source(std::vector<catalog::Column> columns) {
    std::array<uint8_t,32> digest;digest.fill(1);
    return {ProcessRef(1,3),{{ResourceRef(1,7),9},9,1,"items",digest,17,1,1,{200,digest}},
        {9,1,columns.size()+1,columns,{}}};
}
static q::Source source(ResourceRef resource,int kind,bool golden) {
    if(kind==0)return q::KvSource{resource,golden?Bytes{'d','a','t','a','/'}:Bytes{'k'},{q::DecoderType::Binary},{golden?q::DecoderType::UInt64:q::DecoderType::Utf8}};
    if(kind==1){assert(golden);return table_source({{1,"id",logical::Type::scalar(TRANSIT_LOGICAL_INT64),false,std::nullopt,std::nullopt},{2,"label",logical::Type::scalar(TRANSIT_LOGICAL_UTF8),true,std::nullopt,std::nullopt}});}
    if(golden)return q::DocumentSource{{resource,UINT64_MAX,3,1,42},{{{"title",q::DecoderType::Utf8},{"title"}},{{"body",q::DecoderType::Utf8},{"body"},false,q::ProjectionMode::Text}},std::nullopt};
    return q::DocumentSource{{resource,17,1,1,13},{
        {{"value",q::DecoderType::Utf8},{},true},{{"counter",q::DecoderType::UInt64},{},true,q::ProjectionMode::ElementCounter},
        {{"replica",q::DecoderType::UInt64},{},true,q::ProjectionMode::ElementReplica},{{"optional",q::DecoderType::Utf8},{"optional"}}},std::vector<std::string>{"items"}};
}
static q::Bundle bundle(const q::Source &source,int kind,bool golden,bool named=false,bool compound=false) {
    std::optional<std::vector<std::optional<std::string>>> names;
    if(named){names.emplace(golden?2:kind==2?4:1);(*names)[0]="Result";}
    q::Plan plan{golden?std::vector<uint8_t>{1,0}:kind==2?std::vector<uint8_t>{0,1,2,3}:std::vector<uint8_t>{1},
        q::Compare{static_cast<uint8_t>(golden?1:kind==2?0:1),Comparison::Ne,golden&&kind==0?q::Scalar::unsigned_integer(UINT64_MAX):q::Scalar::utf8(std::string(512,'x'))},
        Aggregate::Rows,golden?std::optional<uint64_t>{UINT64_MAX}:std::nullopt,names};
    if(compound){
        assert(!golden);const auto comparison=std::get<q::Compare>(plan.predicate);const auto column=comparison.column;
        const auto ceiling=std::string("東京🙂/")+std::string(kind==2?64:128,'x')+(kind==2?"/10":"/39");
        plan.predicate=q::PredicateProgram{{q::PredicateAtom{comparison},q::PredicateAtom{q::Compare{column,Comparison::Ge,q::Scalar::utf8(ceiling)}},
            q::PredicateAtom{q::IsState{column,q::State::Null}},q::PredicateOperator::Disjunction,q::PredicateOperator::Negate,q::PredicateOperator::Conjunction}};
    }
    return q::prepare(source,plan,{1000,static_cast<uint64_t>(golden?500:100),1048576});
}
static void boolean_codecs(const std::string &root) {
    const std::array<q::Scalar,7> values{q::Scalar::signed_integer(INT64_MIN),q::Scalar::unsigned_integer(UINT64_MAX),q::Scalar::float64(-0.0),q::Scalar::boolean(true),q::Scalar::utf8("café é 🙂"),q::Scalar::binary({0,255,128}),q::Scalar::utf8(std::string(512,'x'))};
    for(size_t i=0;i<9;++i){
        const auto type=i<6?static_cast<q::DecoderType>(i):i==6?q::DecoderType::Utf8:q::DecoderType::Int64;
        q::Source source=q::KvSource{ResourceRef(46,7),{},{type},{q::DecoderType::UInt64}};
        std::vector<q::PredicateInstruction> instructions;
        if(i<7)instructions={q::PredicateAtom{q::Compare{0,Comparison::Eq,values[i]}},q::PredicateOperator::Negate,q::PredicateAtom{q::IsState{0,q::State::Null}},q::PredicateOperator::Disjunction};
        else if(i==7)instructions={q::PredicateAtom{All{}},q::PredicateAtom{q::IsState{0,q::State::Null}},q::PredicateOperator::Negate,q::PredicateOperator::Conjunction};
        else {instructions.emplace_back(q::PredicateAtom{All{}});instructions.insert(instructions.end(),63,q::PredicateOperator::Negate);}
        q::PredicateProgram program{instructions};instructions.clear();
        auto bundle=q::prepare(source,{{0},program,Aggregate::Rows,std::nullopt,std::nullopt},{1000,500,1048576});program.instructions.clear();
        assert(bundle.data()==read(root+"/boolean"+std::to_string(i)+".bin"));
    }
    q::Source source=q::KvSource{ResourceRef(46,7),{},{q::DecoderType::Int64},{q::DecoderType::UInt64}};
    std::vector<q::PredicateInstruction> oversized{q::PredicateAtom{All{}}};oversized.insert(oversized.end(),64,q::PredicateOperator::Negate);
    const std::vector<std::vector<q::PredicateInstruction>> invalid{{},{q::PredicateOperator::Negate},{q::PredicateAtom{All{}},q::PredicateAtom{All{}}},oversized,
        {static_cast<q::PredicateOperator>(99)},{q::PredicateAtom{q::IsState{7,q::State::Null}}},{q::PredicateAtom{q::Compare{0,Comparison::Eq,q::Scalar::utf8("wrong type")}}}};
    for(const auto &instructions:invalid){bool rejected=false;try{q::prepare(source,{{0},q::PredicateProgram{instructions},Aggregate::Rows,std::nullopt,std::nullopt},{1,1,1024});}catch(const Error &){rejected=true;}assert(rejected);}
}
static void codecs(const std::string &root) {
    for(int kind=0;kind<3;++kind) { auto b=bundle(source(ResourceRef(46,7),kind,true),kind,true); assert(b.data()==read(root+"/bundle"+std::to_string(kind)+".bin")); assert(bundle(source(ResourceRef(46,7),kind,true),kind,true,true).data()==read(root+"/named-bundle"+std::to_string(kind)+".bin"));
        q::Plan counted{{1},All{},Aggregate::CountValues,std::nullopt,std::vector<std::optional<std::string>>{"present"}};
        assert(q::prepare(source(ResourceRef(46,7),kind,true),counted,{1000,500,1048576}).data()==read(root+"/counted-bundle"+std::to_string(kind)+".bin")); }
    boolean_codecs(root);
    std::vector<q::Column> columns;const std::array<const char*,6> names{"int64","uint64","float64","boolean","utf8","binary"};
    const std::array<logical::Kind,6> kinds{TRANSIT_LOGICAL_INT64,TRANSIT_LOGICAL_UINT64,TRANSIT_LOGICAL_FLOAT64,TRANSIT_LOGICAL_BOOLEAN,TRANSIT_LOGICAL_UTF8,TRANSIT_LOGICAL_BINARY};
    for(size_t i=0;i<6;++i)columns.push_back({names[i],logical::Type::scalar(kinds[i]),true,true});
    auto ipc=read(root+"/arrow.ipc");const auto rows=q::decode_arrow(columns,ipc,5);std::fill(ipc.begin(),ipc.end(),0);
    const std::array<q::Scalar,6> expected{q::Scalar::signed_integer(INT64_MIN),q::Scalar::unsigned_integer(UINT64_MAX),q::Scalar::float64(-0.0),q::Scalar::boolean(false),q::Scalar::utf8("café é 東京🙂"),q::Scalar::binary({0,255,128})};
    for(size_t row=0;row<5;++row)for(size_t col=0;col<6;++col){
        const auto &cell=rows.at(row).at(col);assert(cell.state()==row);
        if(row==2)assert(cell.native().as.type_error==TRANSIT_LOGICAL_MAP);
        if(row==3)assert(cell.encode()==logical::Cell::atom(expected[col]).encode());
        if(row==4){const auto a=cell.alternatives();assert(a.size()==2&&a[0].counter==UINT64_MAX&&a[0].replica==1&&a[1].counter==UINT64_MAX&&a[1].replica==2);assert(a[0].value.encode()==logical::Cell::atom(expected[col]).encode()&&a[1].value.state()==TRANSIT_LOGICAL_NULL);}
    }
    assert(std::signbit(rows[3][2].atom().native().as.float64));
    assert(q::decode_arrow(columns,read(root+"/empty.ipc"),0).empty());
    bool rejected=false; try { q::decode_arrow(columns,read(root+"/malformed.ipc"),5); }catch(const Error &) { rejected=true; } assert(rejected);
    std::vector<catalog::Column> wide_columns;std::vector<uint8_t> projection;std::vector<std::optional<std::string>> names128;
    for(size_t i=0;i<128;++i){wide_columns.push_back({i+1,"列 "+std::to_string(i),logical::Type::scalar(TRANSIT_LOGICAL_UINT128),true,std::nullopt,std::nullopt});projection.push_back(static_cast<uint8_t>(i));names128.push_back("結果 "+std::to_string(i));}
    auto wide=q::prepare(table_source(wide_columns),{projection,q::Compare{127,Comparison::Eq,q::Scalar::unsigned_integer({UINT64_MAX,UINT64_MAX})},Aggregate::Rows,std::nullopt,names128},{1,1,65536});assert(!wide.data().empty()&&wide.data().size()<=25069);
    const auto nested=q::decode_arrow({{"value",logical::Type::list(logical::Type::scalar(TRANSIT_LOGICAL_UINT128),true),false,false}},read(root+"/nested.ipc"),1);
    const auto children=nested[0][0].children();assert(children.size()==2&&children[1].state()==TRANSIT_LOGICAL_NULL);const auto atom=children[0].atom().native();assert(atom.kind==TRANSIT_ATOM_UNSIGNED&&atom.as.unsigned_value.low==UINT64_MAX&&atom.as.unsigned_value.high==UINT64_MAX);
    std::cout<<"C++ installed unified codecs: three sources, nine Boolean bundles, six types, five states, owned values, 128 columns, uint128, nested values and malformed rejection passed"<<std::endl;
}
static void serve(char **args) {
    const auto realm=std::stoull(args[6]); const ResourceRef resource(realm,std::stoull(args[9]));
    const q::Connection connection{ProcessRef(realm,std::stoull(args[8])),resource,ProcessRef(realm,std::stoull(args[10])),ResourceRef(realm,std::stoull(args[11]))};
    const int kind=std::string(args[4])=="kv"?0:std::string(args[4])=="table"?1:2;
    const auto definition=[&]()->q::Source{if(kind!=1)return source(resource,kind,false);auto catalog= catalog::Client::open(ClientConfig::growing(args[2]).timeout(10000),Credential(realm,std::stoull(args[7]),args[3]),{connection.source,{resource,1}});auto table=catalog.lookup("items");assert(table);catalog.close();return q::TableSource{connection.source,table->metadata,table->schema};}(); assert(bundle(definition,kind,false,true,std::string(args[12])=="compound").data()==read(args[5]));
    std::optional<q::Client> owner(q::Client::open(ClientConfig::growing(args[2]).timeout(10000),Credential(realm,std::stoull(args[7]),args[3]),connection));
    auto &client=*owner; const auto description=client.describe(definition); assert(description.bundle_bytes==25069&&description.batch_rows==8);
    std::optional<q::Page> saved; std::cout<<"{\"ready\":true}"<<std::endl;
    std::string line;
    while(std::getline(std::cin,line)) {
        std::istringstream input(line); std::string command,arg,token; input>>command>>arg>>token;
        if(command=="close")break;
        try {
            std::string result;
            if(command=="compile"){
                q::Budgets budgets{};int count;input>>budgets.pages>>budgets.segments>>budgets.result_bytes>>count;assert(input&&count>=-1&&count<=65);
                std::optional<std::vector<q::Scalar>> parameters;
                if(count>=0){parameters.emplace();for(int i=0;i<count;++i){
                    std::string item;input>>item;const auto colon=item.find(':');assert(input&&colon!=std::string::npos);
                    const auto type=item.substr(0,colon),value=item.substr(colon+1);
                    if(type=="signed")parameters->push_back(q::Scalar::signed_integer(static_cast<int64_t>(std::stoll(value))));
                    else if(type=="unsigned")parameters->push_back(q::Scalar::unsigned_integer(static_cast<uint64_t>(std::stoull(value))));
                    else if(type=="boolean")parameters->push_back(q::Scalar::boolean(value=="true"));
                    else if(type=="float64_bits"){auto bits=unhex(value);assert(bits.size()==8);uint64_t raw=0;for(size_t j=0;j<8;++j)raw|=static_cast<uint64_t>(bits[j])<<(8*j);double number;std::memcpy(&number,&raw,8);parameters->push_back(q::Scalar::float64(number));}
                    else{const auto bytes=unhex(value);if(type=="utf8")parameters->push_back(q::Scalar::utf8(std::string(bytes.begin(),bytes.end())));else{assert(type=="binary");parameters->push_back(q::Scalar::binary(bytes));}}
                }}
                const auto bytes=unhex(token);auto compiled=client.compile_sql(definition,arg,std::string(bytes.begin(),bytes.end()),budgets,parameters);
                parameters.reset();result="{\"compiled\":{\"bundle\":\""+hex(compiled.data())+"\"}}";
            }
            else if(command=="inspect"){
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
                std::string failure = "null";
                if(v && v->failure) { const auto &f=*v->failure; failure="{\"code\":\""+f.code+"\",\"stage\":\""+f.stage+"\",\"dimension\":\""+f.dimension+"\",\"limit\":\""+std::to_string(f.limit)+"\",\"observed\":\""+std::to_string(f.observed)+"\"}"; }
                result=std::string("{\"status\":")+(v?"{\"phase\":\""+std::string(names[static_cast<size_t>(v->phase)])+"\",\"correlation\":\""+std::to_string(v->correlation)+"\",\"failure\":"+failure+",\"diagnostic\":"+v->diagnostic.value_or("null")+"}":"null")+"}";
            }else {
                assert(command=="page"); std::optional<q::Cursor> cursor; if(token!="-")cursor.emplace(q::Cursor::recover(unhex(token)));
                auto page=client.page(std::stoull(arg),cursor?&*cursor:nullptr);
                assert(page.manifest.source_kind==static_cast<transit_station_unified_source_kind>(kind) && page.manifest.resource.resource==resource.resource()); assert(page.decode().size()==page.rows);
                result="{\"page\":{\"ordinal\":\""+std::to_string(page.ordinal)+"\",\"ipc\":\""+hex(page.ipc)+"\",\"manifest\":{\"segments\":\""+std::to_string(page.manifest.segments)+"\",\"selected\":\""+std::to_string(page.manifest.selected)+"\",\"value_count\":\""+std::to_string(page.manifest.value_count)+"\"},\"next_hex\":"+(page.next?"\""+hex(page.next->data())+"\"":"null")+"}}";
                saved=std::move(page);
            }
            std::cout<<"{\"status\":0,\"value\":"<<result<<"}"<<std::endl;
        }catch(const Error &error) { const auto &e=error.detail(); assert(e.has_native_status); std::cout<<"{\"status\":"<<e.native_status<<",\"value\":{\"err\":\""<<e.code<<"\",\"diagnostic\":"<<(e.diagnostic.size?e.diagnostic.json:"null")<<",\"diagnostic_invalid\":"<<(e.diagnostic_invalid?"true":"false")<<"}}"<<std::endl; }
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

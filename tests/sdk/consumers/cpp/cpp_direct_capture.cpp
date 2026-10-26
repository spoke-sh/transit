#include <transit/unified_query.hpp>
#include <cassert>
#include <fstream>
#include <iostream>
using namespace transit::sdk;
using namespace transit::sdk::station;
namespace q=transit::sdk::station::unified;
static uint64_t number(const char *s){return std::stoull(s);}
int main(int argc,char **args) {
    assert(argc==19);const bool prepare=std::string(args[1])=="prepare";const auto realm=number(args[5]);
    const q::Connection connection{ProcessRef(realm,number(args[7])),ResourceRef(realm,number(args[8])),ProcessRef(realm,number(args[9])),ResourceRef(realm,number(args[10]))};
    const q::Tables tables{args[2],{ResourceRef(realm,number(args[11])),number(args[12])},number(args[14]),number(args[13])};
    assert(tables.scope.resource.native().resource!=connection.resource.native().resource);
    std::ifstream file(args[4],std::ios::binary);assert(file);const Bytes bytes((std::istreambuf_iterator<char>(file)),std::istreambuf_iterator<char>());const auto bundle=q::Bundle::recover(bytes);
    auto client=q::Client::open(ClientConfig::growing(args[2]).timeout(10000),Credential(realm,number(args[6]),args[3]),connection,tables);
    assert(!client.lookup_table(1,prepare?"missing_capture_input":"captured_input"));
    const auto definition=client.lookup_table(1,prepare?"captured_input":"captured_renamed");assert(definition);
    if(prepare) {
        assert(definition->partition==number(args[17])&&definition->next_lsn==number(args[18]));
        const auto compiled=client.compile_sql(definition->source,"captured_input","SELECT COUNT(*) AS n FROM captured_input",{64,64,1048576});
        assert(client.authorize_bundle(compiled,definition->capture(number(args[15]),number(args[16]))).data()==bytes);
    } else {
        assert(definition->source.interpretation.revision==2&&definition->source.schema.revision==1);
        const auto page=client.page(1);assert(!page.next&&page.rows==1);
        assert(page.manifest.source_kind==TRANSIT_UNIFIED_TABLE&&page.manifest.source.table_worker.pid==connection.source.native().pid);
        assert(page.manifest.resource.resource==tables.scope.resource.native().resource&&page.manifest.pages==3&&page.manifest.scanned==19);
        const auto rows=q::decode_arrow(page.columns,page.ipc,page.rows);assert(rows.size()==1);
        const auto &cell=rows[0][0].native();assert(cell.state==TRANSIT_LOGICAL_VALUE&&cell.as.value.as.atom.kind==TRANSIT_ATOM_UNSIGNED&&cell.as.value.as.atom.as.unsigned_value.low==19&&cell.as.value.as.atom.as.unsigned_value.high==0);
        assert(!client.prepare_cleanup(1,bundle).data().empty());
    }
    client.close();assert(!definition->source.schema.columns.empty());
    std::cout<<"C++ installed direct capture "<<args[1]<<": public API passed\n";
}

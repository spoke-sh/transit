/* Installed C++17 consumer. Protocol behavior stays behind the public API. */
#include <transit/table_mutation.hpp>
#include "mutation_sdk_io.h"
using namespace transit::sdk;
namespace m=transit::sdk::station::mutations;
static Bytes decoded(const char *text) {
    const auto value=unhex(text);Bytes out(value.data,value.data+value.size);free((void *)value.data);return out;
}
static m::Reference reference(const char *text) {
    const auto bytes=decoded(text);assert(bytes.size()==72);m::Reference out{};std::copy(bytes.begin(),bytes.end(),out.begin());return out;
}
static std::string decoded_text(const char *text) { const auto value=decoded(text);return {value.begin(),value.end()}; }
int main(int argc,char **argv) {
    assert(argc==8);setvbuf(stdout,NULL,_IOLBF,0);
    const auto realm=std::stoull(argv[3]);
    auto client=m::Client::open(ClientConfig::growing(argv[1]).timeout(10000),Credential(realm,std::stoull(argv[4]),argv[2]),
        {ProcessRef(realm,std::stoull(argv[5])),ResourceRef(realm,std::stoull(argv[6])),static_cast<uint32_t>(std::stoul(argv[7]))});
    std::optional<m::Prepared> retained;Bytes retained_bytes;
    puts("{\"ready\":true}");
    while(read_command() && strcmp(command,"close")) {
        try {
            if(!strcmp(command,"capabilities"))puts("{\"status\":0,\"value\":{\"capabilities\":{\"max_rows\":3}}}");
            else if(!strcmp(command,"describe")){const auto out=client.describe();printf("{\"status\":0,\"value\":{\"description\":{\"resource\":%llu}}}\n",(unsigned long long)out.resource.resource());}
            else if(!strcmp(command,"compile")) {
                const auto out=client.compile_sql(decoded_text(first),decoded_text(second),std::stoull(third));
                printf("{\"status\":0,\"value\":{\"compiled\":{\"request\":\"");print_hex(bytes_view(out.request()));printf("\",\"reference\":\"");const auto ref=out.reference();print_hex({ref.data(),ref.size()});puts("\"}}}");
            } else if(!strcmp(command,"next")) {
                auto input=decoded(first);const auto saved=input;auto ref=reference(second);
                const auto compiled=m::Compiled::recover(input,ref);std::fill(input.begin(),input.end(),0);ref.fill(0);
                assert(compiled.request()==saved && compiled.reference()==reference(second));
                const auto out=client.prepare_next(compiled);const auto bytes=out?out->data():Bytes{};emit_prepared(bytes_view(bytes),out.has_value());
            } else if(!strcmp(command,"prepare")) {
                assert(!strcmp(first,"apply")||!strcmp(first,"cancel"));
                const auto out=client.prepare_control(!strcmp(first,"apply")?m::Control::Apply:m::Control::Cancel,reference(second));emit_prepared(bytes_view(out.data()),true);
            } else if(!strcmp(command,"submit")||!strcmp(command,"observe")||!strcmp(command,"rejection")) {
                auto input=decoded(first);const auto saved=input;auto prepared=m::Prepared::recover(input);std::fill(input.begin(),input.end(),0);assert(prepared.data()==saved);
                try {
                    if(!strcmp(command,"submit"))printf("{\"status\":0,\"value\":{\"receipt\":{\"position\":%llu}}}\n",(unsigned long long)client.submit(prepared));
                    else if(!strcmp(command,"observe"))printf("{\"status\":0,\"value\":{\"observation\":\"%s\"}}\n",client.observe(prepared,std::stoull(second))==m::Observation::Pending?"pending":"processed");
                    else {
                        const auto out=client.rejection(prepared,std::stoull(second));
                        const char *names[]={"invalid_command","denied","identity_conflict","busy","not_found","not_active","upload_closed","not_sealed","invalid_part","incomplete_upload","source_changed","stale_policy"};
                        printf("{\"status\":0,\"value\":{\"rejection\":");if(out)printf("\"%s\"",names[static_cast<size_t>(*out)]);else printf("null");puts("}}");
                    }
                } catch(...) {assert(prepared.data()==saved);retained=std::move(prepared);retained_bytes=saved;throw;}
                assert(prepared.data()==saved);retained=std::move(prepared);retained_bytes=saved;
            } else {
                assert(!strcmp(command,"status"));const auto out=client.status(reference(first));
                const char *phases[]={"uploading","sealed","applied","rejected","cancelled"};const char *reasons[]={"none","row_exists","source_changed","invalid_request","denied","budget"};
                printf("{\"status\":0,\"value\":{\"status\":");
                if(out){printf("{\"reference\":\"");print_hex({out->reference.data(),out->reference.size()});printf("\",\"phase\":\"%s\",\"affected_rows\":%u,\"reason\":\"%s\",\"input\":%llu}",phases[static_cast<size_t>(out->phase)],out->affected_rows,reasons[static_cast<size_t>(out->reason)],(unsigned long long)out->input);}else printf("null");puts("}}");
            }
        } catch(const Error &error) {emit_error(error.detail());}
    }
    client.close();try {client.describe();assert(false);}catch(const Error &error){assert(error.detail().kind==TRANSIT_SDK_CLOSED);}
    if(retained)assert(retained->data()==retained_bytes);
    puts("{\"closed\":true}");
}

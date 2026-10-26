-module(beam_direct_capture).
-include_lib("transit_station_sdk/include/transit_unified_query.hrl").
-export([main/2]).
ok({ok,V})->V;
ok({error,E})->error({sdk,E}).
wide(V,K)->binary_to_integer(maps:get(K,V)).
main(A,Args) -> run(A,[unicode:characters_to_list(V)||V<-Args]).
run(A,[Endpoint,ProfilePath,Phase]) ->
    {ok,Bytes}=file:read_file(ProfilePath),#{<<"captured">>:=Profile}=json:decode(Bytes),
    Route=maps:get(<<"connection">>,Profile),Realm=maps:get(<<"realm">>,Route),
    #{<<"source">>:=#{<<"table">>:=Declaration}}=maps:get(<<"declaration">>,Profile),ScopeValue=maps:get(<<"scope">>,Declaration),
    Resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,ScopeValue)},Scope=#transit_catalog_scope{resource=Resource,catalog=wide(ScopeValue,<<"catalog">>)},
    Connection=#transit_unified_connection{source=#transit_process{realm=Realm,pid=maps:get(<<"source">>,Route)},resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,Route)},
        requester=#transit_process{realm=Realm,pid=maps:get(<<"requester">>,Route)},requests=#transit_resource{realm=Realm,resource=maps:get(<<"requests">>,Route)}},
    true=Resource=/=Connection#transit_unified_connection.resource,
    Seed=filename:join(filename:dirname(ProfilePath),"beam-capture.seed"),
    ok=file:write_file(Seed,binary:copy(case Phase of "prepare"-><<"1d">>; "result"-><<"3b">> end,32)),ok=file:change_mode(Seed,8#600),
    Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,Route),seed_file=list_to_binary(Seed)},
    Config=#transit_config{url=list_to_binary(Endpoint),profile=native_v1,timeout_ms=10000},
    Tables=#transit_unified_tables{url=list_to_binary(Endpoint),scope=Scope,branch=wide(Declaration,<<"branch">>),audience=maps:get(<<"owner">>,Declaration)},
    Bundle=#transit_unified_bundle{bytes=base64:decode(maps:get(<<"base64">>,maps:get(<<"bundle">>,Profile)))},
    Client=ok(A:open(Config,Identity,Connection,Tables)),
    try case Phase of
        "prepare" ->
            undefined=ok(A:table(Client,1,<<"missing_capture_input">>)),
            Definition=#transit_unified_table_definition{source=Source,partition=Partition,next_lsn=Next}=ok(A:table(Client,1,<<"captured_input">>)),
            Saved=maps:get(<<"capture">>,Profile),Expected=maps:get(<<"expected">>,Saved),Partition=wide(Expected,<<"partition">>),Next=wide(Expected,<<"next_lsn">>),
            Compiled=ok(A:compile(Client,Source,<<"captured_input">>,<<"SELECT COUNT(*) AS n FROM captured_input">>,#transit_unified_budgets{pages=64,segments=64,result_bytes=1048576},undefined)),
            Capture=A:capture(Definition,maps:get(<<"executor">>,Saved),wide(Saved,<<"operation">>)),
            Bundle=ok(A:authorize(Client,Compiled,Capture));
        "result" ->
            undefined=ok(A:table(Client,1,<<"captured_input">>)),
            #transit_unified_table_definition{source=#transit_unified_table{interpretation=#transit_unified_table_interpretation{revision=2},schema=#transit_catalog_schema{revision=1}}}=ok(A:table(Client,1,<<"captured_renamed">>)),
            Worker=Connection#transit_unified_connection.source,
            #transit_unified_page{manifest=#transit_unified_manifest{source={table,Worker},kind=table,cut={table,Commitment},resource=Resource,pages=3,scanned=19},columns=Columns,rows=1,ipc=Ipc,next=undefined}=ok(A:page(Client,1,undefined)),
            32=byte_size(Commitment),[[{value,{atom,{unsigned,19}}}]]=ok(A:decode(Columns,Ipc,1)),
            #transit_unified_prepared{}=ok(A:cleanup(Client,1,Bundle))
    end after ok(A:close(Client)) end,
    io:format("~p installed direct capture ~s: public API passed~n",[A,Phase]).

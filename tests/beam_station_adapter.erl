-module(beam_station_adapter).
-behaviour(transit_station_handler).
-behaviour(transit_station_recovery).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([open/2,next/1,reconcile/1,close/1,stop/1,view/1,codecs/1,recover/1,
         initialize/2,handle_message/3,handle_result/3,before_dispatch/2,confirmed/3,
         example_initialize/3,example_message/4,example_result/3,input_variant/1,
         budgets/1,state/1,key/1,require/2,put/3,require_reentrant/1,table/1,basis/1,
         table_get/2,table_update/3,table_page/2,retain/1,open_version/2,version/1,
         source_state/1,source_table/1,state_page/1,release/2,result/2,manifest/1,segment/2,raise_error/1]).
open(C, S) ->
    {ok, Client} = transit_client:config(maps:get(<<"url">>, C), growing_v3),
    Realm = maps:get(<<"realm">>, C), {ok, P} = transit_client:process(Realm, maps:get(<<"pid">>, C)),
    {ok, Credential} = transit_client:credential(Realm, maps:get(<<"principal">>, C), maps:get(<<"seed_file">>, C)),
    Service = #transit_service{client = Client, activation = #transit_activation{process = P, generation = maps:get(<<"generation">>, C), credential = Credential}, query_results = maps:get(<<"query_results">>, C)},
    Mode = beam_station_controller:get(S, mode), Failure = case binary:longest_common_suffix([Mode, <<"-block">>]) of 6 -> block_input; _ -> stop end,
    Codec = case maps:get(<<"role">>, C) of <<"service">> -> transit_example_counter_codec; <<"requester">> -> transit_example_requester_codec; <<"table">> -> transit_example_query_service_codec; <<"query">> -> transit_example_query_requester_codec end,
    transit_station_sdk:open(Service, ?MODULE, S, Codec, Failure, {persist_before_dispatch, ?MODULE, S}).
next(R) -> transit_station_sdk:next(R).
reconcile(R) -> transit_station_sdk:reconcile(R).
close(R) -> transit_station_sdk:close(R).
stop(R) -> transit_station_sdk:stop(R).
view(#transit_error{kind=K,phase=P,status=S,code=C}) -> #{kind=>K,phase=>P,status=>S,code=>C};
view(#transit_committed{receipt=R}) -> #{kind=>committed,receipt=>R};
view(#transit_blocked{receipt=R}) -> #{kind=>blocked,receipt=>R};
view(#transit_needs_recovery{mutation=M,phase=P,receipt=R}) -> #{kind=>needs_recovery,mutation=>M,phase=>P,receipt=>R};
view(#transit_runner_shutdown{pending=P,last_event=E}) -> #{pending=>P,last_event=>E};
view(#transit_frozen{identity=I,purpose=P,bytes=B}) -> #{identity=>I,purpose=>P,bytes=>B};
view(#transit_page{entries=E,cursor=C,basis=B}) -> #{entries=>E,cursor=>C,basis=>B};
view(#transit_row{key=K,value=null}) -> #{key=>K,value=>undefined};
view(#transit_row{key=K,value=V}) -> #{key=>K,value=>V};
view(#transit_read_version{pid=P,input=I,index=X}) -> #{pid=>P,input=>I,index=>X};
view(#transit_result_complete{correlation=C}) -> #{correlation=>C};
view(#transit_manifest{rows=R,segments=S,source=F,destination=D,basis=B,byte_count=N}) -> #{rows=>R,segments=>S,source=>F,destination=>D,basis=>B,byte_count=>N};
view(#transit_basis{resource=R,revision=V}) -> #{resource=>R,revision=>V};
view(#transit_process{pid=P}) -> #{pid=>P};
view(#transit_resource{resource=R}) -> #{resource=>R};
view(#transit_ipc_segment{ordinal=O,ipc=B}) -> #{ordinal=>O,ipc=>B}.
initialize(T,S) -> beam_station_controller:initialize(?MODULE,T,S).
handle_message(T,I,S) -> beam_station_controller:handle_message(?MODULE,T,I,S).
handle_result(T,I,S) -> beam_station_controller:handle_result(?MODULE,T,I,S).
before_dispatch(M,S) -> beam_station_controller:before_dispatch(?MODULE,M,S).
confirmed(I,R,S) -> beam_station_controller:confirmed(?MODULE,I,R,S).
context(S) ->
    C = beam_station_controller:get(S, config), {ok, P} = transit_client:process(maps:get(<<"realm">>,C), maps:get(<<"peer">>,C)),
    #{peer=>P,consume=>fun(Segment) -> #{ordinal:=O} = view(Segment), beam_station_controller:put(S,{segment,O},Segment), ok end}.
base(<<"service">>) -> transit_example_counter;
base(<<"requester">>) -> transit_example_requester;
base(<<"table">>) -> transit_example_table_service;
base(<<"query">>) -> transit_example_query_requester.
example_initialize(Role,T,S) ->
    M = base(Role), {module,M} = code:ensure_loaded(M),
    case erlang:function_exported(M,initialize,2) of true -> {ok,_} = M:initialize(T,context(S)); false -> ok end, {ok,S}.
example_message(Role,T,I,S) -> M = base(Role), {ok,_} = M:handle_message(T,I,context(S)), {ok,S}.
example_result(T,I,S) -> {ok,_} = transit_example_query_requester:handle_result(T,I,context(S)), {ok,S}.
input_variant(#transit_incoming{kind=cast,value=V}) -> V;
input_variant(_) -> other.
budgets(T) -> transit_turn:budgets(T).
state(T) -> transit_turn:state(T).
key(total) -> transit_example_keys:total().
require(S,K) -> transit_turn:require(S,K).
put(S,K,V) -> transit_turn:put(S,K,V).
require_reentrant(S) -> transit_turn:require(S,#transit_key{name= <<"total">>,codec=beam_station_reentrant}).
table(T) -> transit_table:open(T,transit_example_keys:table()).
basis(T) -> transit_table:basis(T).
table_get(T,K) -> transit_table:get(T,K).
table_update(T,K,V) -> transit_table:update(T,#transit_row{key=K,value=V}).
table_page(T,C) -> transit_table:page(T,C).
retain(T) -> transit_turn:retain(T).
open_version(T,V) -> transit_turn:open_version(T,V).
version(#{<<"pid">>:=P,<<"input">>:=I,<<"index">>:=X}) -> #transit_read_version{pid=P,input=I,index=X}.
source_state(S) -> transit_turn:source_state(S).
source_table(S) -> transit_table:open_source(S,transit_example_keys:table()).
state_page(S) -> transit_turn:page(S,undefined).
release(T,V) -> transit_turn:release(T,V).
result(T,C) -> transit_query:result(T,C).
manifest(R) -> transit_query:manifest(R).
segment(R,I) -> transit_query:segment(R,I).
raise_error(Error) -> throw({transit_sdk,Error}).
recover(C) ->
    {ok, Config} = transit_client:config(maps:get(<<"url">>, C), growing_v3), {ok, Client} = transit_client:open(Config),
    {ok, Bytes} = file:read_file(maps:get(<<"pending">>, C)), {ok, Pending} = transit_client:recover_mutation(Client, Bytes),
    {confirmed, _} = transit_client:dispatch_mutation(Client, Pending), {ok, _} = transit_client:close(Client), ok.
codecs(C) ->
    Fixtures = beam_station_controller:read(maps:get(<<"fixtures">>,C)),
    lists:foreach(fun(F) -> Codec = codec(maps:get(<<"codec">>,F)), Bytes = binary:decode_hex(maps:get(<<"hex">>,F)),
        Value = fixture(F), {ok,Bytes} = transit_example_codec:encode(Codec,Value), {ok,Value} = transit_example_codec:decode(Codec,Bytes)
    end,maps:get(<<"valid">>,Fixtures)),
    lists:foreach(fun(F) -> {error,_} = transit_example_codec:decode(codec(maps:get(<<"codec">>,F)),binary:decode_hex(maps:get(<<"hex">>,F))) end,maps:get(<<"invalid">>,Fixtures)),
    {ok, <<"STN1",1,0:64/little,"TSC",1,1,18446744073709551615:64/little>>} = transit_station_sdk:encode_cast({add,18446744073709551615},transit_example_counter_codec),
    {error,#transit_error{kind=incompatible_native}} = transit_station_sdk:encode_cast(read,transit_example_counter_codec,filename:join(filename:dirname(maps:get(<<"fixtures">>,C)),<<"bad-station-version">>)).
codec(<<"counter">>) -> counter; codec(<<"query">>) -> query; codec(<<"u64">>) -> u64.
fixture(#{<<"variant">>:= <<"Add">>,<<"value">>:=V}) -> {add,binary_to_integer(V)};
fixture(#{<<"variant">>:= <<"Total">>,<<"value">>:=V}) -> {total,binary_to_integer(V)};
fixture(#{<<"variant">>:= <<"U64">>,<<"value">>:=V}) -> binary_to_integer(V);
fixture(#{<<"variant">>:= <<"Insert">>,<<"key">>:=K}=F) -> {insert,binary_to_integer(K),case maps:find(<<"value">>,F) of {ok,V} -> binary_to_integer(V); error -> null end};
fixture(#{<<"variant">>:= <<"Read">>}) -> read; fixture(#{<<"variant">>:= <<"Start">>}) -> start;
fixture(#{<<"variant">>:= <<"Rows">>}) -> rows; fixture(#{<<"variant">>:= <<"Initialize">>}) -> initialize.

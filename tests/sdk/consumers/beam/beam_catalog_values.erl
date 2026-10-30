%% Strict installed direct values and actual joined-port ownership under caller loss.
-module(beam_catalog_values).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
max()->18446744073709551615.
definition()->maps:get(<<"definition">>,transit_sdk_value:contract(transit_station_sdk)).
scope()->#{realm=>46,resource=>7,catalog=>integer_to_binary(max())}.
connection()->#{scope=>scope(),branch=><<"1">>,audience=>3,principal=>17,role=>null}.
object()->#{scope=>scope(),branch=><<"1">>,object=>integer_to_binary(max())}.
interpretation()->#{object=>object(),revision=><<"1">>,digest=>binary:copy(<<"ab">>,32)}.
stored()->#{interpretation=>interpretation(),content=>#{bytes=><<"300">>,sha256=>binary:copy(<<"ab">>,32)},schema_fingerprint=>binary:copy(<<"cd">>,32),retired=>false}.
basis()->#{definition=>definition(),connection=>connection(),namespace=>1,name=><<"items">>,interpretation=>stored()}.
position()->#{partition=>integer_to_binary(max()),next_lsn=>integer_to_binary(max())}.
binding()->#{definition=>definition(),identity=>#{scope=>scope(),principal=>17,operation=><<"10">>},target=>object(),action=><<"insert">>,expected_definition=>interpretation(),expected_data=>null,intent=>binary:copy(<<"aa">>,32),prerequisite=>null}.
reference()->#{table=>#{definition=>definition(),connection=>connection(),namespace=>1,binding=>binding(),content=>#{bytes=><<"200">>,sha256=>binary:copy(<<"22">>,32)}}}.
summary()->#{id=>#{definition=>definition(),digest=>binary:copy(<<"11">>,32)},namespace=>1,binding=>#{table=>binding()}}.
observed()->#{rows=>#{committed=>#{binding=>binding(),resulting=>stored(),transaction=>null,outcome=>#{position=>position(),matched=><<"9">>,affected=><<"9">>,live_rows=><<"9">>}}}}.
schema()->#{definition=>definition(),object=>integer_to_binary(max()),revision=><<"1">>,next_column=><<"2">>,columns=>[#{id=><<"1">>,name=><<"id">>,type=>#{int128=>#{}},nullable=>true,default=>null,max_characters=>null,encoding=><<"plain">>,collation=><<"none">>}],primary_key=>[]}.
page()->#{position=>position(),entries=>[#{interpretation=>interpretation(),namespace=>1,name=><<"items">>,position=>position(),changed_lsn=><<"3">>}|lists:duplicate(7,null)],next=>#{definition=>definition(),connection=>connection(),selection=>#{tables=>1},position=>position(),'after'=>integer_to_binary(max())},consistency=><<"independent">>}.
config(Root,Override)->{#transit_config{url= <<"http://127.0.0.1:9">>,profile=native_v1,timeout_ms=1000,native_host=Override},#transit_credential{realm=46,principal=17,seed_file=unicode:characters_to_binary(filename:join(Root,"seed"))},#transit_catalog_connection{scope=#transit_catalog_scope{resource=#transit_resource{realm=46,resource=7},catalog=max()},audience=3}}.
open(A,Root,Mode)->file:delete(filename:join(Root,"entered")),file:delete(filename:join(Root,"release")),ok=file:write_file(filename:join(Root,"mode.json"),json:encode(Mode)),{C,I,B}=config(Root,filename:join(Root,"host")),{ok,Client}=A:open(C,I,B),Client.
wait(F)->wait(F,erlang:monotonic_time(millisecond)+5000).
wait(F,D)->case F() of true->ok;false->true=erlang:monotonic_time(millisecond)<D,timer:sleep(10),wait(F,D) end.
joined(Root)->{ok,Bytes}=file:read_file(filename:join(Root,"host-pid")),Pid=binary_to_integer(Bytes),wait(fun()->not filelib:is_dir(filename:join("/proc",integer_to_list(Pid))) end).
close(A,C)->case A:close(C) of {ok,_}->ok;{error,#transit_error{kind=cleanup},_}->ok end.
response(A,Root,Value,Action)->C=open(A,Root,#{status=>0,value=>Value}),try Action(C) after close(A,C) end,joined(Root).
invalid({error,#transit_error{kind=Kind}})->true=lists:member(Kind,[invalid_argument,incompatible_native,read_failed]),ok.
restore(A,K,V)->{ok,Out}=A:restore(K,iolist_to_binary(json:encode(V))),Out.
values(A,Root)->
    Authority=#{database_domain=>10,schema_domain=>11,table_domain=>12,stream_domain=>13,queue_domain=>14,database=>20,initial_schema_authority=>21,initial_schema=>1},
    Configuration=#{scope=>scope(),branch=><<"1">>,partition=>integer_to_binary(max()),audience=>3,authority=>Authority,database_name=><<"ledger">>,initial_schema_name=><<"public">>},
    Description=#{configuration=>Configuration,subject=>#{principal=>17,login_role=>17,role=>17,credential_epoch=>1,audience=>3,context=>lists:duplicate(32,1)},policy_revision=>2},
    response(A,Root,#{catalog=>#{description=>Description}},fun(C)->
        {ok,#transit_catalog_description{configuration=#transit_catalog_configuration{authority=Profile}}}=A:describe(C),
        #transit_catalog_authority{stream_domain=13,queue_domain=14}=Profile
    end),
    lists:foreach(fun(Field)->
        Other=case Field of stream_domain->14;queue_domain->13 end,
        lists:foreach(fun(BadAuthority)->
            response(A,Root,#{catalog=>#{description=>Description#{configuration=>Configuration#{authority=>BadAuthority}}}},fun(C)->invalid(A:describe(C)) end)
        end,[maps:remove(Field,Authority)|[Authority#{Field=>V}||V<-[0,10,11,12,Other,1 bsl 53]]])
    end,[stream_domain,queue_domain]),
    Basis=restore(A,basis,basis()),true=is_record(Basis,transit_catalog_basis),{ok,SavedBasis}=A:save(Basis),Size=byte_size(SavedBasis)-1,<<Prefix:Size/binary,_>>=SavedBasis,
    invalid(A:restore(basis,<<Prefix/binary,",\"name\":\"other\"}">>)),
    lists:foreach(fun(V)->invalid(A:restore(reference,iolist_to_binary(json:encode(#{table=>V})))) end,[maps:remove(definition,maps:get(table,reference())),(maps:get(table,reference()))#{definition=>binary:copy(<<"0">>,64)},(maps:get(table,reference()))#{binding=>(binding())#{identity=>#{scope=>scope(),principal=>18,operation=><<"10">>}}}]),
    Ref=restore(A,reference,reference()),
    response(A,Root,#{observation=>observed()},fun(C)->{ok,#transit_catalog_observation{state=committed,commit=#transit_catalog_commit{affected=9,position=#transit_catalog_position{next_lsn=N}}}}=A:inspect(C,Ref),true=N=:=max() end),
    Bad=#{rows=>#{committed=>#{binding=>(binding())#{identity=>#{scope=>scope(),principal=>17,operation=><<"11">>}},resulting=>stored(),transaction=>null,outcome=>#{position=>position(),matched=><<"9">>,affected=><<"9">>,live_rows=><<"9">>}}}},
    %% Failed native validation may close the host connection. Exercise read
    %% rejection and uncertain admission independently on fresh joined workers.
    response(A,Root,#{observation=>Bad},fun(C)->invalid(A:inspect(C,Ref)) end),
    response(A,Root,#{observation=>Bad},fun(C)->{uncertain,Ref,#transit_error{kind=unknown_outcome}}=A:admit(C,Ref) end),
    response(A,Root,#{catalog=>#{tables=>page()}},fun(C)->{ok,#transit_catalog_page{entries=[#transit_catalog_entry{interpretation=#transit_catalog_interpretation{object=#transit_catalog_object{object=O}}}],next=Cursor,consistency=independent}}=A:tables(C),true=O=:=max(),invalid(A:tables(C,1,Cursor)) end),
    Page=page(),Entries=maps:get(entries,Page),Next=maps:get(next,Page),
    lists:foreach(fun(P)->response(A,Root,#{catalog=>#{tables=>P}},fun(C)->invalid(A:tables(C)) end) end,
        [Page#{entries=>tl(Entries)},Page#{entries=>[null,hd(Entries)|lists:duplicate(6,null)]},Page#{entries=>[hd(Entries),hd(Entries)|lists:duplicate(6,null)]},Page#{next=>Next#{'after'=><<"1">>}},Page#{next=>Next#{position=>#{partition=><<"1">>,next_lsn=><<"1">>}}},Page#{next=>maps:remove(definition,Next)}]),
    Owner=#{definition=>definition(),connection=>connection(),object=>object(),operation=>integer_to_binary(max())},Acquisition=restore(A,snapshot_acquisition,#{owner=>Owner,expected=>position()}),true=(Acquisition#transit_catalog_snapshot_acquisition.owner)#transit_catalog_snapshot_owner.operation=:=max(),
    Snapshot=restore(A,snapshot,#{owner=>Owner,content=>#{bytes=><<"500">>,sha256=>binary:copy(<<"44">>,32)}}),
    Metadata=#{snapshot=>null,interpretation=>stored(),accepted=>position(),changed_lsn=><<"3">>,row_count=><<"9">>,schema=>schema(),authority=>#{database=>31,schema=>32,table=>33}},
    %% Saved bytes are decoded once; the response embeds the complete object.
    {ok,SnapshotBytes}=A:save(Snapshot),M=Metadata#{snapshot=>transit_sdk_value:json(SnapshotBytes,96)},
    response(A,Root,#{retention=>#{metadata=>M}},fun(C)->{ok,#transit_catalog_snapshot_metadata{row_count=9,schema=#transit_catalog_schema{columns=[_]}}}=A:snapshot_metadata(C,Snapshot) end),
    Stored=#{table=>#{definition=>definition(),namespace=>1,bytes=>binary:copy(<<"ab">>,300000)}},
    response(A,Root,#{compiled=>#{summary=>summary(),saved=>Stored}},fun(C)->
        Rows=[[#transit_catalog_assignment{column=1,value={value,{atom,{signed,1}}}}]],{ok,#transit_catalog_compiled{saved=Saved,intent=#transit_catalog_intent{identity=#transit_catalog_identity{operation=10}}}}=A:prepare(C,<<"items">>,#transit_catalog_identity{operation=10},{mutate,Basis,{insert,Rows},bulk}),
        {ok,Bytes}=A:save(Saved),true=byte_size(Bytes)>600000
    end),Ref.
main(A,[Root])->
    ok=beam_schema_values:run(),ok=beam_logical_values:run(),ok=file:write_file(filename:join(Root,"seed"),lists:duplicate(64,$1)),Ref=values(A,Root),
    lists:foreach(fun(Mode)->C=open(A,Root,Mode),try {uncertain,Ref,#transit_error{kind=unknown_outcome,status=6}}=A:admit(C,Ref) after close(A,C) end,joined(Root) end,
        [<<"loss">>,#{status=>0,value=>#{observation=>#{rows=>#{committed=>#{}}}}},#{status=>0,value=>#{observation=>observed(),extra=>true}}]),
    Denied=open(A,Root,#{status=>4,value=>#{err=><<"TableGrantDenied">>}}),try {error,#transit_error{kind=access_denied,status=4}}=A:admit(Denied,Ref) after close(A,Denied) end,joined(Root),
    ok=file:write_file(filename:join(Root,"reply.json"),json:encode(#{status=>0,value=>#{observation=>observed()}})),
    C=open(A,Root,<<"block">>),Parent=self(),{Waiting,Monitor}=spawn_monitor(fun()->Parent!{unexpected,A:admit(C,Ref)} end),
    try wait(fun()->filelib:is_file(filename:join(Root,"entered")) end),exit(Waiting,kill),receive {'DOWN',Monitor,process,Waiting,killed}->ok after 5000->error(waiter_alive) end,
        {error,#transit_error{kind=busy}}=A:capabilities(C),{Closer,CloseMonitor}=spawn_monitor(fun()->Parent!{closed,A:close(C)} end),receive {closed,_}->error(abandoned_native_work) after 100->ok end,
        ok=file:write_file(filename:join(Root,"release"),<<"1">>),receive {closed,{ok,_}}->ok after 5000->error(close_not_joined) end,receive {'DOWN',CloseMonitor,process,Closer,normal}->ok after 5000->error(closer_alive) end,
        {error,#transit_error{kind=closed}}=A:capabilities(C),joined(Root)
    after file:write_file(filename:join(Root,"release"),<<"1">>),A:close(C) end,
    file:delete(filename:join(Root,"seed")),io:format("~p direct values, complete bindings, wide saved work and joined waiter/port loss passed.~n",[A]).

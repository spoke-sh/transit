-module(beam_catalog_values).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
max()->18446744073709551615.
config(Root,Override)->
    {#transit_config{url = <<"http://127.0.0.1:9">>,profile=native_v1,timeout_ms=1000,native_host=Override},
     #transit_credential{realm=46,principal=17,seed_file=unicode:characters_to_binary(filename:join(Root,"seed"))},
     #transit_catalog_connection{owner=#transit_process{realm=46,pid=3},scope=#transit_catalog_scope{resource=#transit_resource{realm=46,resource=7},catalog=max()}}}.
open(A,Root,Mode)->
    file:delete(filename:join(Root,"entered")),file:delete(filename:join(Root,"release")),
    ok=file:write_file(filename:join(Root,"mode.json"),json:encode(Mode)),
    {Config,Identity,Connection}=config(Root,filename:join(Root,"host")),
    {ok,Client}=A:open(Config,Identity,Connection),Client.
wait(F)->wait(F,erlang:monotonic_time(millisecond)+5000).
wait(F,Deadline)->case F() of true->ok; false->true=erlang:monotonic_time(millisecond)<Deadline,timer:sleep(10),wait(F,Deadline) end.
joined(Root)->
    {ok,Bytes}=file:read_file(filename:join(Root,"host-pid")),Pid=binary_to_integer(Bytes),
    wait(fun()->not filelib:is_dir(filename:join("/proc",integer_to_list(Pid))) end).
close(A,C)->case A:close(C) of {ok,_}->ok; {error,#transit_error{kind=cleanup},_}->ok end.
metadata_definition()->
    #{scope=>#{realm=>46,resource=>7,catalog=>integer_to_binary(max())},object=>integer_to_binary(max()),revision=>integer_to_binary(max()),name=><<"items">>,
      source=>#{table=>#{id=>4294967295,schema=>#{names=>[<<"id">>,<<"value">>],value_type=><<"utf8">>}}},principal=>17,operation=>integer_to_binary(max()),input=>9}.
metadata_page()->
    #{resource_revision=>9,entries=>[metadata_definition()|lists:duplicate(7,null)],
      next=>#{definition=>maps:get(<<"definition">>,transit_sdk_value:contract(transit_station_sdk)),scope=>maps:get(scope,metadata_definition()),resource_revision=>9,'after'=><<"items">>}}.
metadata_response(A,Root,Value,Action)->
    C=open(A,Root,#{status=>0,value=>Value}),try Action(C) after close(A,C) end,joined(Root).
metadata_values(A,Root)->
    Max=max(),
    metadata_response(A,Root,#{definition=>metadata_definition()},fun(C)->
        {ok,#transit_catalog_definition{object=Max,revision=Max,operation=Max,name = <<"items">>,source=#transit_catalog_table_source{table=4294967295,schema=#transit_catalog_schema{names=[<<"id">>,<<"value">>]}}}=D}=A:lookup(C,<<"items">>),
        {ok,D}=A:definition(C,Max,Max),
        {error,#transit_error{kind=incompatible_native}}=A:lookup(C,<<"wrong">>),
        {error,#transit_error{kind=incompatible_native}}=A:definition(C,1,Max),
        {error,#transit_error{kind=incompatible_native}}=A:definition(C,Max,1)
    end),
    metadata_response(A,Root,#{definition=>null},fun(C)->{ok,undefined}=A:lookup(C,<<"items">>),{ok,undefined}=A:definition(C,Max,Max) end),
    Page=metadata_page(),
    metadata_response(A,Root,#{page=>Page},fun(C)->
        {ok,#transit_catalog_page{resource_revision=9,entries=[#transit_catalog_definition{object=Max}],next=Next}}=A:list(C),
        {error,#transit_error{kind=incompatible_native}}=A:list(C,Next),
        {error,#transit_error{kind=incompatible_native}}=A:list(C,Next#transit_catalog_cursor{resource_revision=8,after_name = <<"a">>}),
        {error,_}=A:list(C,Next#transit_catalog_cursor{definition=undefined}),
        {error,_}=A:list(C,Next#transit_catalog_cursor{definition=binary:copy(<<"0">>,64)})
    end),
    metadata_response(A,Root,#{page=>Page#{entries=>lists:duplicate(8,null),next=>null}},fun(C)->
        {ok,#transit_catalog_page{entries=[],next=undefined}}=A:list(C)
    end),
    D=metadata_definition(),Next=maps:get(next,Page),Source=maps:get(source,D),Table=maps:get(table,Source),Schema=maps:get(schema,Table),
    Invalid=[Page#{entries=>lists:duplicate(7,null)},Page#{entries=>[null,D|lists:duplicate(6,null)]},Page#{entries=>[D,D|lists:duplicate(6,null)]},
        Page#{entries=>[D#{scope=>(maps:get(scope,D))#{catalog=><<"1">>}}|lists:duplicate(7,null)]},
        Page#{next=>maps:remove(definition,Next)},Page#{next=>Next#{definition=>binary:copy(<<"0">>,64)}},Page#{next=>Next#{'after'=><<"wrong">>}},Page#{next=>Next#{resource_revision=>10}},
        Page#{entries=>[D#{object=>Max}|lists:duplicate(7,null)]},Page#{entries=>[D#{name=><<"bad-name">>}|lists:duplicate(7,null)]},Page#{extra=>true},
        Page#{entries=>[D#{source=>Source#{table=>Table#{schema=>Schema#{names=>[<<"id">>,<<"id">>]}}}}|lists:duplicate(7,null)]}],
    Expected=[read_failed,incompatible_native,incompatible_native,incompatible_native,read_failed,read_failed,incompatible_native,incompatible_native,read_failed,incompatible_native,read_failed,incompatible_native],
    lists:foreach(fun({Bad,Kind})->metadata_response(A,Root,#{page=>Bad},fun(C)->{error,#transit_error{kind=Kind}}=A:list(C) end) end,lists:zip(Invalid,Expected)).
main(A,[Root])->
    ok=file:write_file(filename:join(Root,"seed"),lists:duplicate(64,$1)),
    {Config,Identity,Connection}=config(Root,undefined),{ok,Native}=A:open(Config,Identity,Connection),
    try
        {ok,#transit_catalog_compiled{request=Request,canonical=Canonical}}=A:compile_sql(Native,<<"CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)">>,max(),max(),4294967295),
        #transit_catalog_create_table{scope=Scope,operation=Max,object=Max,table=4294967295,schema=#transit_catalog_schema{names=[<<"id">>,<<"value">>],value_type=utf8}}=Request,
        Max=max(),Scope=Connection#transit_catalog_connection.scope,true=is_binary(Canonical),true=byte_size(Canonical)>0,
        {error,_}=A:compile_sql(Native,<<"CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)">>,Max+1,Max,1),
        {error,_}=A:compile_sql(Native,<<"CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)">>,0,Max,1),
        {error,_}=A:submit(Native,#transit_catalog_prepared{bytes = <<>>}),
        {error,_}=A:submit(Native,#transit_catalog_prepared{bytes=binary:copy(<<0>>,8193)}),
        {error,_}=A:submit(Native,#transit_catalog_prepared{bytes = <<255>>})
    after {ok,_}=A:close(Native) end,
    metadata_values(A,Root),
    Prepared=#transit_catalog_prepared{bytes = <<"opaque fixture command">>},
    Modes=[<<"loss">>,#{status=>0,value=>#{receipt=>#{position=><<"1">>}}},
        #{status=>0,value=>#{receipt=>#{position=>7},extra=>true}}],
    lists:foreach(fun(Mode)->C=open(A,Root,Mode),try
        {uncertain,Prepared,#transit_error{kind=unknown_outcome,status=6}}=A:submit(C,Prepared)
        after close(A,C) end,joined(Root) end,Modes),
    Denied=open(A,Root,#{status=>4,value=>#{err=><<"CatalogDenied">>}}),
    try {error,#transit_error{kind=access_denied,status=4,code = <<"CatalogDenied">>}}=A:submit(Denied,Prepared)
    after {ok,_}=A:close(Denied) end,joined(Root),
    Success=open(A,Root,#{status=>0,value=>#{receipt=>#{position=>7}}}),
    try {ok,#transit_admission{position=7}}=A:submit(Success,Prepared)
    after {ok,_}=A:close(Success) end,joined(Root),
    C=open(A,Root,<<"block">>),Parent=self(),
    {Waiting,Monitor}=spawn_monitor(fun()->Parent!{unexpected,A:submit(C,Prepared)} end),
    try
        wait(fun()->filelib:is_file(filename:join(Root,"entered")) end),exit(Waiting,kill),
        receive {'DOWN',Monitor,process,Waiting,killed}->ok after 5000->error(waiter_alive) end,
        {error,#transit_error{kind=busy}}=A:capabilities(C),
        {Closer,CloseMonitor}=spawn_monitor(fun()->Parent!{closed,A:close(C)} end),
        receive {closed,_}->error(abandoned_native_work) after 100->ok end,
        ok=file:write_file(filename:join(Root,"release"),<<"1">>),
        receive {closed,{ok,_}}->ok after 5000->error(close_not_joined) end,
        receive {'DOWN',CloseMonitor,process,Closer,normal}->ok after 5000->error(closer_alive) end,
        {error,#transit_error{kind=closed}}=A:capabilities(C),joined(Root),
        <<"opaque fixture command">>=Prepared#transit_catalog_prepared.bytes
    after file:write_file(filename:join(Root,"release"),<<"1">>),A:close(C) end,
    file:delete(filename:join(Root,"seed")),
    io:format("~p catalog metadata, full-width records, uncertain receipts and joined waiting-process loss passed.~n",[A]).

%% Installed general Table lifecycle, shared by Erlang and the Elixir adapter.
-module(beam_catalog_controller).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
report(V) -> io:put_chars([json:encode(V),"\n"]).
result({ok,V}) -> V;
result({error,E}) -> throw({failure,E});
result({uncertain,_,E}) -> throw({failure,E}).
scope(#{<<"realm">>:=R,<<"resource">>:=K,<<"catalog">>:=C}) -> #transit_catalog_scope{resource=#transit_resource{realm=R,resource=K},catalog=binary_to_integer(C)}.
connect(A,Cfg) ->
    Conn=maps:get(<<"connection">>,Cfg),Scope=scope(maps:get(<<"scope">>,Conn)),Realm=(Scope#transit_catalog_scope.resource)#transit_resource.realm,
    Config=#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=case maps:get(<<"table_service_url">>,Cfg,null) of null->10000; _->30000 end},
    Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,Conn),seed_file=maps:get(<<"seed_file">>,Cfg)},
    Connection=#transit_catalog_connection{owner=#transit_process{realm=Realm,pid=maps:get(<<"owner">>,Conn)},scope=Scope,role=case maps:get(<<"role">>,Conn,null) of null->undefined; R->R end,namespace=maps:get(<<"namespace">>,Conn,1)},result(A:open(Config,Identity,Connection,case maps:get(<<"table_service_url">>,Cfg,null) of null->undefined; U->U end)).
persist(Path,Bytes) ->
    {ok,F}=file:open(Path,[write,binary,raw]),try ok=file:change_mode(Path,8#600),ok=file:write(F,Bytes),ok=file:sync(F) after ok=file:close(F) end.
finish(A,C,#transit_catalog_compiled{intent=#transit_catalog_intent{reference=Reference},saved=#transit_catalog_saved_intent{definition=Definition,bytes=Bytes}},Root) ->
    persist(filename:join(Root,"intent.json"),json:encode(#{definition=>Definition,bytes=>binary:encode_hex(Bytes,lowercase)})),
    advance(A,C,Reference,Root,erlang:monotonic_time(millisecond)+120000).
advance(A,C,Reference,Root,Deadline) ->
    true=erlang:monotonic_time(millisecond)<Deadline,
    case result(A:next(C,Reference)) of
        #transit_catalog_next{kind=terminal,outcome=Outcome}->Outcome;
        #transit_catalog_next{kind=running}->advance(A,C,Reference,Root,Deadline);
        #transit_catalog_next{kind=send,prepared=#transit_catalog_prepared{bytes=Bytes}=Prepared}->
            persist(filename:join(Root,"step.json"),Bytes),#transit_admission{position=Position}=result(A:submit(C,Prepared)),
            persist(filename:join(Root,"receipt.json"),integer_to_binary(Position)),
            processed(A,C,Reference,Prepared,Position,Root,Deadline)
    end.
processed(A,C,Reference,Prepared,Position,Root,Deadline) ->
    true=erlang:monotonic_time(millisecond)<Deadline,
    case result(A:progress(C,Reference,Prepared,Position,true)) of
        #transit_catalog_progress{observation=pending}->processed(A,C,Reference,Prepared,Position,Root,Deadline);
        #transit_catalog_progress{observation=processed,disposition=undefined,outcome=#transit_catalog_outcome{terminal=true}=Outcome}->Outcome;
        #transit_catalog_progress{observation=processed,disposition=undefined}->advance(A,C,Reference,Root,Deadline)
    end.
identity(Base,Offset) -> #transit_catalog_identity{operation=Base+Offset,namespace=Base+Offset+100000}.
atom(V) -> {value,{atom,V}}.
assignment(Column,Value) -> #transit_catalog_assignment{column=Column,value=Value}.
scenario(A,C,Cfg,Root,Index) ->
    Base=1100+Index*100,Object=12001+Index*10,Name= <<"sdk_people_",(integer_to_binary(Index))/binary>>,
    #transit_catalog_description{configuration=#transit_catalog_configuration{scope=Scope},subject=#transit_catalog_subject{principal=Principal}}=result(A:describe(C)),
    Scope=scope(maps:get(<<"scope">>,maps:get(<<"connection">>,Cfg))),Principal=maps:get(<<"principal">>,maps:get(<<"connection">>,Cfg)),
    Create=result(A:compile_sql(C,<<"CREATE TABLE ",Name/binary," (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))">>,identity(Base,0),Object)),
    #transit_catalog_outcome{phase=applied}=finish(A,C,Create,Root),
    #transit_catalog_definition{metadata=OriginalMetadata,schema=#transit_catalog_schema{columns=[_,#transit_catalog_column{type={structure,_}},_]}=OriginalSchema}=result(A:lookup(C,Name)),
    Basis=A:basis(OriginalMetadata),Payload={value,{structure,[atom({binary,<<0,128,255>>}),atom({utf8,<<"東京"/utf8>>})]}},Amount=atom({decimal,123456789012345678901234567890}),
    Insert=result(A:prepare(C,Name,identity(Base,1),{mutate,Basis,{insert,[[assignment(3,Amount),assignment(1,atom({signed,1})),assignment(2,Payload)]]}})),
    #transit_catalog_outcome{counts=#transit_catalog_counts{matched=1,changed=1}}=Applied=finish(A,C,Insert,Root),
    Predicate=[{compare,1,eq,{signed,1}}],Update=result(A:prepare(C,Name,identity(Base,2),{mutate,Basis,{update,[assignment(3,Amount)],Predicate}})),
    #transit_catalog_outcome{counts=#transit_catalog_counts{matched=1,changed=0}}=finish(A,C,Update,Root),
    Alter=result(A:prepare(C,Name,identity(Base,3),{alter,Basis,{add,<<"enabled">>,boolean,false,atom({boolean,true}),undefined,plain,none}})),
    #transit_catalog_outcome{phase=applied}=finish(A,C,Alter,Root),
    {error,_}=A:prepare(C,Name,identity(Base,4),{drop,Basis,false}),
    #transit_catalog_definition{metadata=CurrentMetadata}=result(A:lookup(C,Name)),Current=A:basis(CurrentMetadata),
    Delete=result(A:prepare(C,Name,identity(Base,5),{mutate,Current,{delete,Predicate}})),
    #transit_catalog_outcome{counts=#transit_catalog_counts{matched=1,changed=1}}=finish(A,C,Delete,Root),
    #transit_catalog_outcome{phase=applied}=finish(A,C,result(A:prepare(C,Name,identity(Base,6),{drop,Current,false})),Root),
    #transit_catalog_outcome{phase=applied}=finish(A,C,result(A:compile_sql(C,<<"CREATE TABLE ",Name/binary," (replacement TEXT)">>,identity(Base,7),Object+1)),Root),
    result(A:close(C)),Replacement=connect(A,Cfg),
    try
        #transit_catalog_intent{object=Object,reference=Reference}=result(A:load(Replacement,Insert#transit_catalog_compiled.saved)),
        #transit_catalog_state{outcome=Applied}=result(A:status(Replacement,Reference)),
        #transit_catalog_definition{metadata=#transit_catalog_metadata{object=NewObject}}=result(A:lookup(Replacement,Name)),true=NewObject=:=Object+1,
        #transit_catalog_historical_definition{metadata=OriginalMetadata,schema=OriginalSchema}=result(A:definition(Replacement,Object,OriginalMetadata#transit_catalog_metadata.revision)),
        undefined=result(A:definition(Replacement,Object,999)),#transit_catalog_page{entries=Entries}=result(A:list(Replacement)),true=Entries=/=[]
    after A:close(Replacement) end,
    Language=case A of transit_catalog-> <<"erlang">>; _-> <<"elixir">> end,
    #{profile=><<"installed-",Language/binary,"-general-table">>,original_object=>integer_to_binary(Object),replacement_object=>integer_to_binary(Object+1),counts=>#{matched=><<"1">>,changed=><<"1">>}}.
loop(A,C,Cfg,Root) ->
    case io:get_line("") of
        eof->ok;
        Line->case json:decode(unicode:characters_to_binary(Line)) of
            #{<<"close">>:=_}->ok;
            #{<<"denied">>:=_}->Fresh=connect(A,Cfg),try {error,#transit_error{status=4}}=A:describe(Fresh) after A:close(Fresh) end,report(#{status=>0,value=>#{denied=>true}}),loop(A,C,Cfg,Root);
            #{<<"scenario">>:=#{<<"index">>:=Index}}->report(#{status=>0,value=>scenario(A,C,Cfg,Root,Index)}),loop(A,C,Cfg,Root)
        end
    end.
main(A,[Path]) ->
    try
        {ok,Bytes}=file:read_file(Path),Cfg=json:decode(Bytes),Client=connect(A,Cfg),
        try report(#{ready=>true}),loop(A,Client,Cfg,filename:dirname(Path)),report(#{closed=>true}) after A:close(Client) end
    catch Class:Reason:Stack ->
        Safe=case Reason of {failure,#transit_error{kind=K,phase=P}}->{K,P}; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        Locations=[{M,F,case Args of N when is_integer(N)->N; _->arguments end,Info} || {M,F,Args,Info}<-Stack],
        io:format(standard_error,"Catalog SDK proof failed: ~p ~p ~p~n",[Class,Safe,Locations]),halt(1)
    end.

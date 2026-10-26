%% Installed direct lifecycle, shared by independently installed Erlang/Elixir APIs.
-module(beam_catalog_controller).
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([main/2]).
report(V)->io:put_chars([json:encode(V),"\n"]).
result({ok,V})->V;
result(Failure)->error({unexpected_catalog_result,Failure}).
persist(Path,Bytes)->{ok,F}=file:open(Path,[write,binary,raw]),try ok=file:change_mode(Path,8#600),ok=file:write(F,Bytes),ok=file:sync(F) after ok=file:close(F) end.
save(A,Root,Name,V)->persist(filename:join(Root,Name),result(A:save(V))).
restore(A,Root,Name,Kind)->{ok,Data}=file:read_file(filename:join(Root,Name)),result(A:restore(Kind,Data)).
finish(A,C,#transit_catalog_compiled{intent=I,saved=S},Root)->
    save(A,Root,"work.json",S),R=result(A:stage(C,I)),save(A,Root,"work-reference.json",R),advance(A,C,R,result(A:admit(C,R)),16).
advance(A,C,R,#transit_catalog_observation{state=admitted},N) when N>0->advance(A,C,R,result(A:execute(C,R,32)),N-1);
advance(_,_,_,#transit_catalog_observation{state=committed}=V,_)->V.
uncertain(A,Original,{uncertain,Recovery,#transit_error{kind=unknown_outcome,status=6,diagnostic=D,diagnostic_invalid=false}})->
    true=result(A:save(Recovery))=:=result(A:save(Original)),<<"unknown">>=maps:get(<<"outcome">>,D),ok.
identity(Operation)->#transit_catalog_identity{operation=Operation,namespace=1}.
compile(A,C,Sql,O,Object)->result(A:compile_sql(C,Sql,identity(O),Object)).
object(#transit_catalog_basis{interpretation=#transit_catalog_stored{interpretation=#transit_catalog_interpretation{object=#transit_catalog_object{object=O}}}})->O.
snapshot(A,Root)->restore(A,Root,"snapshot.json",snapshot).
main(A,[ConfigFile])->
    {ok,Bytes}=file:read_file(ConfigFile),Cfg=json:decode(Bytes),Conn=maps:get(<<"connection">>,Cfg),S=maps:get(<<"scope">>,Conn),Realm=maps:get(<<"realm">>,S),
    Scope=#transit_catalog_scope{resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,S)},catalog=binary_to_integer(maps:get(<<"catalog">>,S))},
    Connection=#transit_catalog_connection{scope=Scope,audience=maps:get(<<"audience">>,Conn),branch=binary_to_integer(maps:get(<<"branch">>,Conn)),role=case maps:get(<<"role">>,Conn) of null->undefined;R->R end},
    C=result(A:open(#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=10000},#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,Conn),seed_file=maps:get(<<"seed_file">>,Cfg)},Connection,maps:get(<<"service_url">>,Cfg))),
    Mode=maps:get(<<"mode">>,Cfg),Root=filename:join(filename:dirname(ConfigFile),Mode),ok=filelib:ensure_dir(filename:join(Root,"saved")),
    Offset=case Mode of <<"erlang">>->0;<<"elixir">>->10 end,Name= <<Mode/binary,"_items">>,Object=18446744073709551614-Offset,
    report(#{ready=>true}),try loop(A,C,Root,Name,Object,Offset) after A:close(C) end,report(#{closed=>true}).
loop(A,C,Root,Name,Object,Offset)->
    case io:get_line("") of eof->ok;Line->case json:decode(unicode:characters_to_binary(Line)) of
        #{<<"close">>:=_}->ok;
        Action->[{Command,_}]=maps:to_list(Action),Value=phase(Command,A,C,Root,Name,Object,Offset),report(#{status=>0,value=>Value}),loop(A,C,Root,Name,Object,Offset)
    end end.
phase(<<"prepare">>,A,C,Root,Name,Object,Offset)->
    #transit_catalog_description{subject=#transit_catalog_subject{principal=941002,role=Selected}}=result(A:describe(C)),true=is_integer(Selected) andalso Selected>0,#transit_catalog_namespace{name= <<"public">>}=result(A:namespace(C,1)),
    #transit_catalog_page{entries=Namespaces}=result(A:namespaces(C)),true=lists:any(fun(#transit_catalog_namespace{id=N})->N=:=1 end,Namespaces),
    finish(A,C,compile(A,C,<<"CREATE TABLE ",Name/binary," (id BIGINT PRIMARY KEY, payload BINARY)">>,1+Offset,Object),Root),
    #transit_catalog_metadata{basis=B,row_count=0}=result(A:lookup(C,Name)),Object=object(B),
    Rows=[[#transit_catalog_assignment{column=1,value={value,{atom,{signed,I}}}},#transit_catalog_assignment{column=2,value={value,{atom,{binary,binary:copy(<<I>>,32768)}}}}]||I<-lists:seq(0,8)],
    Work=result(A:prepare(C,Name,identity(2+Offset),{mutate,B,{insert,Rows},bulk})),#transit_catalog_preview{current=#transit_catalog_current{row_count=0}}=result(A:preview(C,Work#transit_catalog_compiled.intent)),
    save(A,Root,"intent.json",Work#transit_catalog_compiled.saved),Loaded=result(A:load(C,restore(A,Root,"intent.json",intent))),Original=result(A:stage(C,Loaded)),save(A,Root,"original.json",Original),
    #transit_catalog_observation{state=admitted}=result(A:admit(C,Original)),uncertain(A,Original,A:execute(C,Original,32)),#{uncertain=>true};
phase(<<"recover">>,A,C,Root,Name,_,Offset)->
    Original=restore(A,Root,"original.json",reference),#transit_catalog_observation{state=committed,commit=#transit_catalog_commit{matched=9,affected=9,live_rows=9}}=Observed=result(A:inspect(C,Original)),Observed=result(A:execute(C,Original,32)),
    Current=result(A:lookup(C,Name)),Acquisition=result(A:prepare_snapshot(C,Current,90000+Offset)),save(A,Root,"basis.json",Current#transit_catalog_metadata.basis),save(A,Root,"acquisition.json",Acquisition),
    uncertain(A,Acquisition,A:acquire_snapshot(C,Acquisition)),#{retention_uncertain=>true};
phase(<<"retained">>,A,C,Root,_,_,_)->
    Acquisition=restore(A,Root,"acquisition.json",snapshot_acquisition),#transit_catalog_snapshot_status{released=false,snapshot=S}=result(A:snapshot_status(C,Acquisition#transit_catalog_snapshot_acquisition.owner)),true=is_record(S,transit_catalog_snapshot),
    save(A,Root,"snapshot.json",S),#transit_catalog_snapshot_metadata{accepted=Expected,row_count=9,schema=#transit_catalog_schema{columns=Columns}}=result(A:snapshot_metadata(C,S)),Expected=Acquisition#transit_catalog_snapshot_acquisition.expected,2=length(Columns),#{retained=>true};
phase(<<"denied">>,A,C,Root,_,_,_)->
    {error,#transit_error{kind=access_denied,status=4,diagnostic=D}}=A:snapshot_metadata(C,snapshot(A,Root)),<<"access">>=maps:get(<<"category">>,D),#{denied=>true};
phase(<<"metadata">>,A,C,Root,_,_,_)->
    #transit_catalog_snapshot_metadata{interpretation=I,row_count=Rows,schema=#transit_catalog_schema{columns=Columns}}=result(A:snapshot_metadata(C,snapshot(A,Root))),#transit_catalog_basis{interpretation=I}=restore(A,Root,"basis.json",basis),#{rows=>Rows,columns=>length(Columns)};
phase(<<"retire">>,A,C,Root,Name,Object,Offset)->
    #transit_catalog_observation{commit=#transit_catalog_commit{matched=1,affected=0}}=finish(A,C,compile(A,C,<<"UPDATE ",Name/binary," SET id=0 WHERE id=0">>,3+Offset,undefined),Root),
    #transit_catalog_observation{commit=#transit_catalog_commit{matched=1,affected=1}}=finish(A,C,compile(A,C,<<"DELETE FROM ",Name/binary," WHERE id=8">>,4+Offset,undefined),Root),
    #transit_catalog_metadata{basis=B}=result(A:lookup(C,Name)),Work=result(A:prepare(C,Name,identity(5+Offset),{alter,B,{add,<<"extra">>,int64,true,undefined,undefined,plain,none}})),finish(A,C,Work,Root),
    {error,#transit_error{code= <<"TableDefinitionChanged">>}}=A:prepare(C,Name,identity(55+Offset),{drop,B,false}),
    finish(A,C,compile(A,C,<<"ALTER TABLE ",Name/binary," RENAME TO ",Name/binary,"_old">>,6+Offset,undefined),Root),
    finish(A,C,compile(A,C,<<"DROP TABLE ",Name/binary,"_old">>,7+Offset,undefined),Root),
    finish(A,C,compile(A,C,<<"CREATE TABLE ",Name/binary," (replacement BIGINT)">>,8+Offset,Object-1),Root),
    #transit_catalog_metadata{basis=New}=result(A:lookup(C,Name)),true=object(New)=:=Object-1,#transit_catalog_snapshot_metadata{row_count=9}=result(A:snapshot_metadata(C,snapshot(A,Root))),#{original=>true};
phase(<<"release">>,A,C,Root,_,_,_)->S=snapshot(A,Root),#transit_catalog_snapshot_status{released=false}=result(A:snapshot_status(C,S#transit_catalog_snapshot.owner)),uncertain(A,S,A:release_snapshot(C,S)),#{release_uncertain=>true};
phase(<<"verify">>,A,C,Root,Name,Object,Offset)->
    S=snapshot(A,Root),#transit_catalog_snapshot_status{released=true}=result(A:snapshot_status(C,S#transit_catalog_snapshot.owner)),S=result(A:release_snapshot(C,S)),
    #transit_catalog_observation{commit=#transit_catalog_commit{affected=9}}=result(A:inspect(C,restore(A,Root,"original.json",reference))),
    #transit_catalog_intent{identity=#transit_catalog_identity{operation=Operation}}=result(A:load(C,restore(A,Root,"intent.json",intent))),true=Operation=:=2+Offset,
    #transit_catalog_metadata{basis=B}=result(A:lookup(C,Name)),true=object(B)=:=Object-1,#transit_catalog_page{consistency=independent}=result(A:tables(C)),#{recovered=>true}.

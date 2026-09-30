-module(beam_unified_controller).
-include_lib("transit_station_sdk/include/transit_unified_query.hrl").
-export([main/2]).
-define(MAX,18446744073709551615).
read(Path)->{ok,B}=file:read_file(Path),B.
hex(B)->binary:encode_hex(B,lowercase).
ok({ok,V})->V;
ok({error,#transit_error{kind=K,phase=P,code=C}})->error({sdk,K,P,C}).
column(N,T)->#transit_unified_column{name=N,type=T}.
projection(N,T,Path,Relative,Mode)->#transit_unified_projection{column=column(N,T),path=Path,relative=Relative,mode=Mode}.
source(R,<<"kv">>,Golden)->#transit_unified_kv{resource=R,prefix=case Golden of true-><<"data/">>; false-><<"k">> end,key=#transit_unified_decoder{type=binary},value=#transit_unified_decoder{type=case Golden of true->uint64; false->utf8 end}};
source(R,<<"table">>,Golden)->#transit_unified_table{resource=R,id=case Golden of true->9; false->1 end,names=[<<"id">>,case Golden of true-><<"label">>; false-><<"value">> end],value_type=utf8};
source(R,<<"document">>,true)->#transit_unified_document{reference=#transit_document_reference{resource=R,document=?MAX,epoch=3,type_revision=1,revision=42},projections=[projection(<<"title">>,utf8,[<<"title">>],false,scalar),projection(<<"body">>,utf8,[<<"body">>],false,text)]};
source(R,<<"document">>,false)->#transit_unified_document{reference=#transit_document_reference{resource=R,document=17,epoch=1,type_revision=1,revision=13},expand=[<<"items">>],projections=[projection(<<"value">>,utf8,[],true,scalar),projection(<<"counter">>,uint64,[],true,element_counter),projection(<<"replica">>,uint64,[],true,element_replica),projection(<<"optional">>,utf8,[<<"optional">>],false,scalar)]}.
bundle(A,S,K,Golden)->
    {P,C}=case {Golden,K} of {true,_}->{[1,0],1}; {false,<<"document">>}->{[0,1,2,3],0}; _->{[1],1} end,
    V=case {Golden,K} of {true,<<"kv">>}->{uint64,?MAX}; _->{utf8,binary:copy(<<"x">>,512)} end,
    Plan=#transit_unified_plan{projection=P,predicate={compare,C,ne,V},limit=case Golden of true->?MAX; false->undefined end},
    ok(A:prepare(S,Plan,#transit_unified_budgets{pages=1000,segments=case Golden of true->500; false->100 end,result_bytes=1048576})).
scalar({int64,-9223372036854775808},int64)->ok;
scalar({uint64,?MAX},uint64)->ok;
scalar({float64,F},float64)-><<0,0,0,0,0,0,0,128>> = <<F:64/float-little>>,ok;
scalar({boolean,false},boolean)->ok;
scalar({utf8,<<"café é 東京🙂"/utf8>>},utf8)->ok;
scalar({binary,<<0,255,128>>},binary)->ok.
codecs(A,Cfg)->
    Fixtures=json:decode(read(maps:get(<<"bundles">>,Cfg))),
    lists:foreach(fun({Kind,F})->#transit_unified_bundle{bytes=B}=bundle(A,source(#transit_resource{realm=46,resource=7},Kind,true),Kind,true),B=binary:decode_hex(maps:get(<<"wire_hex">>,F)) end,lists:zip([<<"kv">>,<<"table">>,<<"document">>],Fixtures)),
    Types=[int64,uint64,float64,boolean,utf8,binary],Cols=[column(atom_to_binary(T,utf8),T)||T<-Types],
    [Missing,Null,Errors,Values,Conflicts]=ok(A:decode(Cols,read(maps:get(<<"arrow">>,Cfg)),5)),
    true=lists:all(fun(V)->V=:=missing end,Missing),true=lists:all(fun(V)->V=:=null end,Null),true=lists:all(fun(V)->V=:={type_error,map} end,Errors),
    lists:foreach(fun({{value,V},T})->scalar(V,T) end,lists:zip(Values,Types)),
    lists:foreach(fun({{conflict,[#transit_unified_alternative{counter=?MAX,replica=1,value={value,V}},#transit_unified_alternative{counter=?MAX,replica=2,value=null}]},T})->scalar(V,T) end,lists:zip(Conflicts,Types)),
    []=ok(A:decode(Cols,read(maps:get(<<"empty">>,Cfg)),0)),{error,_}=A:decode(Cols,read(maps:get(<<"malformed">>,Cfg)),5),
    io:format("~p installed unified codecs: three sources, six types, five states and malformed rejection passed~n",[A]).
report(V)->io:put_chars([json:encode(V),"\n"]).
config(Cfg)->
    C=maps:get(<<"connection">>,Cfg),Realm=maps:get(<<"realm">>,C),
    Client=#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=10000},
    Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,C),seed_file=maps:get(<<"seed_file">>,Cfg)},
    Connection=#transit_unified_connection{source=#transit_process{realm=Realm,pid=maps:get(<<"source">>,C)},resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,C)},requester=#transit_process{realm=Realm,pid=maps:get(<<"requester">>,C)},requests=#transit_resource{realm=Realm,resource=maps:get(<<"requests">>,C)}},
    {Client,Identity,Connection}.
serve(A,Cfg)->
    {Config,Identity,Connection}=config(Cfg),Kind=maps:get(<<"kind">>,Cfg),Source=source(Connection#transit_unified_connection.resource,Kind,false),
    #transit_unified_bundle{bytes=Bundle}=bundle(A,Source,Kind,false),Bundle=read(maps:get(<<"bundle">>,Cfg)),Client=ok(A:open(Config,Identity,Connection)),
    try
        #transit_unified_description{bundle_bytes=16384,batch_rows=8}=ok(A:describe(Client,Source)),report(#{ready=>true}),
        Saved=loop(A,Client,Cfg,Connection,undefined),ok(A:close(Client)),{error,#transit_error{kind=closed}}=A:status(Client,1),
        case Saved of undefined->ok; #transit_unified_page{columns=Columns,ipc=Ipc,rows=Rows}->Rows=length(ok(A:decode(Columns,Ipc,Rows))) end,
        report(#{closed=>true})
    after A:close(Client) end.
loop(A,C,Cfg,Connection,Saved)->
    case io:get_line("") of
        eof->Saved;
        Line->Action=json:decode(unicode:characters_to_binary(Line)),
            case maps:is_key(<<"close">>,Action) of
                true->Saved;
                false->
                    try action(A,C,Action,Connection,maps:get(<<"kind">>,Cfg)) of
                        {Result,Next}->report(#{status=>0,value=>Result}),loop(A,C,Cfg,Connection,case Next of undefined->Saved; _->Next end)
                    catch throw:{failure,#transit_error{status=Status,code=Code}}->true=is_integer(Status),report(#{status=>Status,value=>#{err=>case Code of undefined->null; _->Code end}}),loop(A,C,Cfg,Connection,Saved) end
            end
    end.
result({ok,V})->V;
result({error,E})->throw({failure,E}).
action(A,C,#{<<"next">>:=#{<<"namespace">>:=N,<<"bundle">>:=B}},_,_)->
    P=result(A:next(C,binary_to_integer(N),#transit_unified_bundle{bytes=binary:decode_hex(B)})),
    {#{prepared=>case P of undefined->null; #transit_unified_prepared{bytes=Bytes}->Bytes end},undefined};
action(A,C,#{<<"submit">>:=Bytes},_,_)->
    P=#transit_unified_prepared{bytes=Bytes},case A:submit(C,P) of
        {uncertain,P,E}->throw({failure,E});
        R->#transit_admission{position=Position}=result(R),{#{receipt=>#{position=>Position}},undefined}
    end;
action(A,C,#{<<"observe">>:=Position},_,_)->
    #transit_unified_observation{state=S,reason=Reason}=result(A:observe(C,Position)),{#{observation=>#{atom_to_binary(S,utf8)=>case Reason of undefined->#{}; _->hex(Reason) end}},undefined};
action(A,C,#{<<"status">>:=N},_,_)->
    Status=result(A:status(C,binary_to_integer(N))),{#{status=>case Status of undefined->null; #transit_unified_status{phase=P,correlation=Correlation}->#{phase=>atom_to_binary(P,utf8),correlation=>integer_to_binary(Correlation)} end},undefined};
action(A,C,#{<<"page">>:=#{<<"namespace">>:=N,<<"cursor">>:=Cursor}},Connection,Kind)->
    Page=#transit_unified_page{manifest=#transit_unified_manifest{resource=Resource,kind=K,segments=Segments},columns=Columns,rows=Rows,ordinal=Ordinal,ipc=Ipc,next=Next}=result(A:page(C,binary_to_integer(N),case Cursor of null->undefined; _->#transit_unified_cursor{opaque=Cursor} end)),
    Resource=Connection#transit_unified_connection.resource,Kind=atom_to_binary(K,utf8),Rows=length(ok(A:decode(Columns,Ipc,Rows))),
    {#{page=>#{ordinal=>integer_to_binary(Ordinal),ipc=>hex(Ipc),manifest=>#{segments=>integer_to_binary(Segments)},next=>case Next of undefined->null; #transit_unified_cursor{opaque=Opaque}->Opaque end}},Page}.
main(A,[Mode,Path])->
    try
        Cfg=json:decode(read(Path)),case unicode:characters_to_binary(Mode) of <<"codecs">>->codecs(A,Cfg); _->serve(A,Cfg) end
    catch Class:Reason:Stack ->
        Safe=case Reason of {sdk,K,P,C}->{K,P,C}; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        io:format(standard_error,"Unified SDK proof failed: ~p ~p ~p~n",[Class,Safe,Stack]),halt(1)
    end.

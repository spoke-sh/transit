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
bundle(A,S,K,Golden)->bundle(A,S,K,Golden,undefined).
bundle(A,S,K,Golden,Names)->bundle(A,S,K,Golden,Names,false).
bundle(A,S,K,Golden,Names,Compound)->
    {P,C}=case {Golden,K} of {true,_}->{[1,0],1}; {false,<<"document">>}->{[0,1,2,3],0}; _->{[1],1} end,
    V=case {Golden,K} of {true,<<"kv">>}->{uint64,?MAX}; _->{utf8,binary:copy(<<"x">>,512)} end,
    Predicate=case Compound of
        false->{compare,C,ne,V};
        true->false=Golden,{Padding,Suffix}=case K of <<"document">>->{64,<<"/10">>}; _->{128,<<"/39">>} end,
            Ceiling=iolist_to_binary([<<"東京🙂/"/utf8>>,binary:copy(<<"x">>,Padding),Suffix]),
            #transit_unified_predicate_program{instructions=[{atom,{compare,C,ne,V}},
                {atom,{compare,C,ge,{utf8,Ceiling}}},{atom,{state,C,null}},disjunction,negate,conjunction]}
    end,
    Plan=#transit_unified_plan{output_names=Names,projection=P,predicate=Predicate,limit=case Golden of true->?MAX; false->undefined end},
    ok(A:prepare(S,Plan,#transit_unified_budgets{pages=1000,segments=case Golden of true->500; false->100 end,result_bytes=1048576})).
scalar({int64,-9223372036854775808},int64)->ok;
scalar({uint64,?MAX},uint64)->ok;
scalar({float64,F},float64)-><<0,0,0,0,0,0,0,128>> = <<F:64/float-little>>,ok;
scalar({boolean,false},boolean)->ok;
scalar({utf8,<<"café é 東京🙂"/utf8>>},utf8)->ok;
scalar({binary,<<0,255,128>>},binary)->ok.
boolean_codecs(A,Cfg)->
    Fixtures=json:decode(read(maps:get(<<"boolean">>,Cfg))),Types=[int64,uint64,float64,boolean,utf8,binary],
    Scalars=[{int64,-9223372036854775808},{uint64,?MAX},{float64,-0.0},{boolean,true},{utf8,<<"café é 🙂"/utf8>>},{binary,<<0,255,128>>},{utf8,binary:copy(<<"x">>,512)}],
    lists:foreach(fun({F,I})->
        Type=lists:nth(maps:get(<<"type">>,F),Types),
        Source=#transit_unified_kv{resource=#transit_resource{realm=46,resource=7},key=#transit_unified_decoder{type=Type},value=#transit_unified_decoder{type=uint64}},
        Instructions=case I of
            _ when I=<7 -> [{atom,{compare,0,eq,lists:nth(I,Scalars)}},negate,{atom,{state,0,null}},disjunction];
            8 -> [{atom,all},{atom,{state,0,null}},negate,conjunction];
            9 -> [{atom,all}|lists:duplicate(63,negate)]
        end,
        Plan=#transit_unified_plan{projection=[0],predicate=#transit_unified_predicate_program{instructions=Instructions}},
        #transit_unified_bundle{bytes=Bytes}=ok(A:prepare(Source,Plan,#transit_unified_budgets{pages=1000,segments=500,result_bytes=1048576})),
        Bytes=binary:decode_hex(maps:get(<<"wire_hex">>,F))
    end,lists:zip(Fixtures,lists:seq(1,length(Fixtures)))),
    Source=#transit_unified_kv{resource=#transit_resource{realm=46,resource=7},key=#transit_unified_decoder{type=int64},value=#transit_unified_decoder{type=uint64}},
    Invalid=[[],[negate],[{atom,all},{atom,all}],[{atom,all}|lists:duplicate(64,negate)],
        [{atom,{state,7,null}}],[{atom,{compare,0,eq,{utf8,<<"wrong type">>}}}],
        [{atom,#transit_unified_predicate_program{instructions=[{atom,all}]}}]],
    lists:foreach(fun(Instructions)->
        {error,_}=A:prepare(Source,#transit_unified_plan{projection=[0],predicate=#transit_unified_predicate_program{instructions=Instructions}},#transit_unified_budgets{pages=1,segments=1,result_bytes=1024})
    end,Invalid).
codecs(A,Cfg)->
    Fixtures=json:decode(read(maps:get(<<"bundles">>,Cfg))),
    lists:foreach(fun({Kind,F})->#transit_unified_bundle{bytes=B}=bundle(A,source(#transit_resource{realm=46,resource=7},Kind,true),Kind,true),B=binary:decode_hex(maps:get(<<"wire_hex">>,F)),#transit_unified_bundle{bytes=Named}=bundle(A,source(#transit_resource{realm=46,resource=7},Kind,true),Kind,true,[<<"Result">>,undefined]),Named=binary:decode_hex(maps:get(<<"named_wire_hex">>,F)),
        #transit_unified_bundle{bytes=Counted}=ok(A:prepare(source(#transit_resource{realm=46,resource=7},Kind,true),#transit_unified_plan{projection=[1],aggregate=count_values,output_names=[<<"present">>]},#transit_unified_budgets{pages=1000,segments=500,result_bytes=1048576})),Counted=binary:decode_hex(maps:get(<<"counted_wire_hex">>,F)) end,lists:zip([<<"kv">>,<<"table">>,<<"document">>],Fixtures)),
    boolean_codecs(A,Cfg),
    Types=[int64,uint64,float64,boolean,utf8,binary],Cols=[column(atom_to_binary(T,utf8),T)||T<-Types],
    [Missing,Null,Errors,Values,Conflicts]=ok(A:decode(Cols,read(maps:get(<<"arrow">>,Cfg)),5)),
    true=lists:all(fun(V)->V=:=missing end,Missing),true=lists:all(fun(V)->V=:=null end,Null),true=lists:all(fun(V)->V=:={type_error,map} end,Errors),
    lists:foreach(fun({{value,V},T})->scalar(V,T) end,lists:zip(Values,Types)),
    lists:foreach(fun({{conflict,[#transit_unified_alternative{counter=?MAX,replica=1,value={value,V}},#transit_unified_alternative{counter=?MAX,replica=2,value=null}]},T})->scalar(V,T) end,lists:zip(Conflicts,Types)),
    []=ok(A:decode(Cols,read(maps:get(<<"empty">>,Cfg)),0)),{error,_}=A:decode(Cols,read(maps:get(<<"malformed">>,Cfg)),5),
    io:format("~p installed unified codecs: three sources, nine Boolean bundles, six types, five states and malformed rejection passed~n",[A]).
report(V)->io:put_chars([json:encode(V),"\n"]).
config(Cfg)->
    C=maps:get(<<"connection">>,Cfg),Realm=maps:get(<<"realm">>,C),
    Client=#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=10000},
    Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,C),seed_file=maps:get(<<"seed_file">>,Cfg)},
    Connection=#transit_unified_connection{source=#transit_process{realm=Realm,pid=maps:get(<<"source">>,C)},resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,C)},requester=#transit_process{realm=Realm,pid=maps:get(<<"requester">>,C)},requests=#transit_resource{realm=Realm,resource=maps:get(<<"requests">>,C)}},
    {Client,Identity,Connection}.
serve(A,Cfg)->
    {Config,Identity,Connection}=config(Cfg),Kind=maps:get(<<"kind">>,Cfg),Source=source(Connection#transit_unified_connection.resource,Kind,false),
    #transit_unified_bundle{bytes=Bundle}=bundle(A,Source,Kind,false,case Kind of <<"document">>->[<<"Result">>,undefined,undefined,undefined]; _->[<<"Result">>] end,maps:get(<<"compound">>,Cfg)),Bundle=read(maps:get(<<"bundle">>,Cfg)),Client=ok(A:open(Config,Identity,Connection)),
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
                    catch throw:{failure,#transit_error{status=Status,code=Code,diagnostic=Diagnostic,diagnostic_invalid=Invalid}}->true=is_integer(Status),report(#{status=>Status,value=>#{err=>case Code of undefined->null; _->Code end,diagnostic=>case Diagnostic of undefined->null; _->Diagnostic end,diagnostic_invalid=>Invalid}}),loop(A,C,Cfg,Connection,Saved) end
            end
    end.
result({ok,V})->V;
result({error,E})->throw({failure,E}).
inspection_columns(Columns)->[#{name=>N,type=>atom_to_binary(T)}||#transit_unified_column{name=N,type=T}<-Columns].
inspection_predicate(all)->#{all=>#{}};
inspection_predicate({state,N,S})->#{state=>#{column=>N,value=>atom_to_binary(S)}};
inspection_predicate({compare,N,O,T})->#{compare=>#{column=>N,op=>atom_to_binary(O),type=>atom_to_binary(T)}};
inspection_predicate(#transit_unified_predicate_program{instructions=Instructions})->
    #{program=>[case I of {atom,Atom}->#{atom=>inspection_predicate(Atom)}; Op->#{atom_to_binary(Op)=>#{}} end||I<-Instructions]}.
inspection_details(#transit_unified_source_description{columns=Columns})->#{description=>#{columns=>inspection_columns(Columns)}};
inspection_details(#transit_unified_table_listing{names=Names})->#{tables=>Names};
inspection_details(#transit_unified_explanation{operators=Operators,predicate=Predicate,projection=Projection,limit=Limit,aggregate=Aggregate,columns=Columns,budgets=#transit_unified_budgets{pages=Pages,segments=Segments,result_bytes=Bytes}})->
    P=inspection_predicate(Predicate),
    #{explanation=>#{operators=>[atom_to_binary(O)||O<-Operators],predicate=>P,projection=>Projection,limit=>case Limit of undefined->null; _->integer_to_binary(Limit) end,
        aggregate=>atom_to_binary(Aggregate),columns=>inspection_columns(Columns),budgets=>#{pages=>integer_to_binary(Pages),segments=>integer_to_binary(Segments),result_bytes=>integer_to_binary(Bytes)}}}.
parameter(#{<<"int64">>:=V})->{int64,binary_to_integer(V)};
parameter(#{<<"uint64">>:=V})->{uint64,binary_to_integer(V)};
parameter(#{<<"float_bits">>:=V})-><<F:64/float-little>>=binary:decode_hex(V),{float64,F};
parameter(#{<<"boolean">>:=V})->{boolean,V};
parameter(#{<<"utf8">>:=V})->{utf8,V};
parameter(#{<<"binary">>:=V})->{binary,binary:decode_hex(V)}.
action(A,C,#{<<"compile">>:=#{<<"scope">>:=Scope,<<"sql">>:=Sql}=Request},Connection,Kind)->
    Limits=maps:get(<<"limits">>,Scope),Resource=Connection#transit_unified_connection.resource,
    Budgets=#transit_unified_budgets{pages=binary_to_integer(maps:get(<<"pages">>,Limits)),segments=binary_to_integer(maps:get(<<"segments">>,Limits)),result_bytes=binary_to_integer(maps:get(<<"result_bytes">>,Limits))},
    Parameters=case maps:get(<<"parameters">>,Request,null) of null->undefined; Values->[parameter(V)||V<-Values] end,
    #transit_unified_bundle{bytes=Bytes}=result(A:compile(C,source(Resource,Kind,false),maps:get(<<"name">>,Scope),Sql,Budgets,Parameters)),
    {#{compiled=>#{bundle=>hex(Bytes)}},undefined};
action(A,C,#{<<"inspect">>:=#{<<"scope">>:=Scope,<<"sql">>:=Sql}},Connection,Kind)->
    Limits=maps:get(<<"limits">>,Scope),Resource=Connection#transit_unified_connection.resource,
    Budgets=#transit_unified_budgets{pages=binary_to_integer(maps:get(<<"pages">>,Limits)),segments=binary_to_integer(maps:get(<<"segments">>,Limits)),result_bytes=binary_to_integer(maps:get(<<"result_bytes">>,Limits))},
    #transit_unified_inspection{name=Name,resource=Resource,source_kind=K,source_digest=Contract,schema_digest=Schema,resource_revision=Revision,policy_revision=Policy,details=Details}=result(A:inspect(C,source(Resource,Kind,false),maps:get(<<"name">>,Scope),Sql,Budgets)),
    Kind=atom_to_binary(K),{#{inspection=>#{version=>1,scope=><<"configured_source">>,name=>Name,resource=>Resource#transit_resource.resource,source_kind=>Kind,
        contract=>binary_to_list(Contract),schema=>binary_to_list(Schema),resource_revision=>Revision,policy_revision=>integer_to_binary(Policy),details=>inspection_details(Details)}},undefined};
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
    Status=result(A:status(C,binary_to_integer(N))),{#{status=>case Status of undefined->null; #transit_unified_status{phase=P,correlation=Correlation,failure=F,diagnostic=D}->#{diagnostic=>case D of undefined->null; _->D end,phase=>atom_to_binary(P,utf8),correlation=>integer_to_binary(Correlation),failure=>failure_value(F)} end},undefined};
action(A,C,#{<<"page">>:=#{<<"namespace">>:=N}=Request},Connection,Kind)->
    Cursor=maps:get(<<"cursor">>,Request,null),
    Page=#transit_unified_page{manifest=#transit_unified_manifest{resource=Resource,kind=K,segments=Segments,selected=Selected,value_count=Counted},columns=Columns,rows=Rows,ordinal=Ordinal,ipc=Ipc,next=Next}=result(A:page(C,binary_to_integer(N),case Cursor of null->undefined; _->#transit_unified_cursor{opaque=Cursor} end)),
    Resource=Connection#transit_unified_connection.resource,Kind=atom_to_binary(K,utf8),Rows=length(ok(A:decode(Columns,Ipc,Rows))),
    {#{page=>#{ordinal=>integer_to_binary(Ordinal),ipc=>hex(Ipc),manifest=>#{segments=>integer_to_binary(Segments),selected=>integer_to_binary(Selected),value_count=>integer_to_binary(Counted)},next=>case Next of undefined->null; #transit_unified_cursor{opaque=Opaque}->Opaque end}},Page}.
main(A,[Mode,Path])->
    try
        Cfg=json:decode(read(Path)),case unicode:characters_to_binary(Mode) of <<"codecs">>->codecs(A,Cfg); _->serve(A,Cfg) end
    catch Class:Reason:Stack ->
        Safe=case Reason of {sdk,K,P,C}->{K,P,C}; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        io:format(standard_error,"Unified SDK proof failed: ~p ~p ~p~n",[Class,Safe,Stack]),halt(1)
    end.

failure_value(undefined)->null;
failure_value(#transit_unified_failure{code=C,stage=S,dimension=D,limit=L,observed=O})->#{code=>C,stage=>atom_to_binary(S),dimension=>atom_to_binary(D),limit=>integer_to_binary(L),observed=>integer_to_binary(O)}.

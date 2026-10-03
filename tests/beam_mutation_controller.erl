-module(beam_mutation_controller).
-include_lib("transit_station_sdk/include/transit_mutations.hrl").
-export([main/2]).
hex(B)->binary:encode_hex(B,lowercase).
ref(B)->#transit_mutation_reference{bytes=binary:decode_hex(B)}.
prepared(B)->#transit_mutation_prepared{bytes=B}.
report(V)->io:put_chars([json:encode(V),"\n"]).
result({ok,V})->V;
result({error,E})->throw({failure,E}).
optional(undefined,_)->null;
optional(V,F)->F(V).
permissions(Names)->lists:sum([case N of insert->1; update->2; delete->4 end || N<-Names]).
action(_,_,#{<<"capabilities">>:=_})->#{capabilities=>#{max_rows=>3}};
action(A,C,#{<<"describe">>:=_})->
    #transit_mutation_description{resource=#transit_resource{resource=Resource},table=Table,names=Names,value_type=Type,
        resource_revision=Revision,policy_revision=Policy,declaration=Declaration,permissions=Permissions,active=Active}=result(A:describe(C)),
    #{description=>#{resource=>Resource,table=>Table,names=>Names,value_type=>atom_to_binary(Type),resource_revision=>Revision,
        policy_revision=>integer_to_binary(Policy),declaration=>hex(Declaration),permissions=>permissions(Permissions),active=>optional(Active,fun integer_to_binary/1)}};
action(A,C,#{<<"compile">>:=#{<<"name">>:=Name,<<"sql">>:=Sql,<<"namespace">>:=Namespace}})->
    #transit_mutation_compiled{request=Request,reference=#transit_mutation_reference{bytes=Reference}}=result(A:compile_sql(C,Name,Sql,binary_to_integer(Namespace))),
    #{compiled=>#{request=>hex(Request),reference=>hex(Reference)}};
action(A,C,#{<<"next">>:=#{<<"request">>:=Request,<<"reference">>:=Reference}})->
    Compiled=#transit_mutation_compiled{request=binary:decode_hex(Request),reference=ref(Reference)},
    Value=result(A:prepare_next(C,Compiled)),Request=hex(Compiled#transit_mutation_compiled.request),
    #{prepared=>optional(Value,fun(#transit_mutation_prepared{bytes=B})->B end)};
action(A,C,#{<<"prepare">>:=Control})->
    [{Kind,Reference}]=maps:to_list(Control),Name=case Kind of <<"apply">>->apply; <<"cancel">>->cancel end,
    #transit_mutation_prepared{bytes=Bytes}=result(A:prepare_control(C,Name,ref(Reference))),#{prepared=>Bytes};
action(A,C,#{<<"submit">>:=Bytes})->
    Prepared=prepared(Bytes),case A:submit(C,Prepared) of
        {uncertain,Prepared,#transit_error{kind=unknown_outcome}=Error}->throw({failure,Error});
        R->#transit_admission{position=Position}=result(R),Bytes=Prepared#transit_mutation_prepared.bytes,#{receipt=>#{position=>Position}}
    end;
action(A,C,#{<<"observe">>:=#{<<"prepared">>:=Bytes,<<"input">>:=Input}})->
    #{observation=>atom_to_binary(result(A:observe(C,prepared(Bytes),Input)))};
action(A,C,#{<<"rejection">>:=#{<<"prepared">>:=Bytes,<<"input">>:=Input}})->
    #{rejection=>optional(result(A:rejection(C,prepared(Bytes),Input)),fun atom_to_binary/1)};
action(A,C,#{<<"status">>:=Reference})->
    #{status=>optional(result(A:status(C,ref(Reference))),fun(#transit_mutation_status{
        reference=#transit_mutation_reference{bytes=R},principal=P,table=T,declaration=D,policy_revision=Policy,
        phase=Phase,affected_rows=Rows,reason=Reason,input=Input,conflict=Conflict})->
        #{reference=>hex(R),principal=>P,table=>T,declaration=>hex(D),policy_revision=>integer_to_binary(Policy),
          phase=>atom_to_binary(Phase),affected_rows=>Rows,reason=>atom_to_binary(Reason),input=>Input,conflict=>optional(Conflict,fun(#transit_mutation_conflict{key=Key,row=Row})->#{key=>integer_to_binary(Key),row=>Row} end)} end)}.
loop(A,C,Saved)->case io:get_line("") of
    eof->Saved;
    Line->Action=json:decode(unicode:characters_to_binary(Line)),case maps:is_key(<<"close">>,Action) of
        true->Saved;
        false->
            try action(A,C,Action) of Value->report(#{status=>0,value=>Value})
            catch throw:{failure,#transit_error{kind=Kind,status=Status,code=Code,diagnostic=Diagnostic,diagnostic_invalid=Invalid}}->
                Native=case Status of undefined->case Kind of unknown_outcome->6; _->1 end; _->Status end,
                report(#{status=>Native,value=>#{err=>optional(Code,fun(X)->X end),diagnostic=>optional(Diagnostic,fun(X)->X end),diagnostic_invalid=>Invalid}})
            end,
            Next=case Action of #{<<"submit">>:=Bytes}->prepared(Bytes); _->Saved end,
            loop(A,C,Next)
    end end.
main(A,[Path])->
    try
        {ok,Bytes}=file:read_file(Path),Cfg=json:decode(Bytes),Conn=maps:get(<<"connection">>,Cfg),Realm=maps:get(<<"realm">>,Conn),
        Config=#transit_config{url=maps:get(<<"url">>,Cfg),profile=native_v1,timeout_ms=10000},
        Identity=#transit_credential{realm=Realm,principal=maps:get(<<"principal">>,Conn),seed_file=maps:get(<<"seed_file">>,Cfg)},
        Connection=#transit_mutation_connection{writer=#transit_process{realm=Realm,pid=maps:get(<<"writer">>,Conn)},
            resource=#transit_resource{realm=Realm,resource=maps:get(<<"resource">>,Conn)},table=maps:get(<<"table">>,Conn)},
        Client=result(A:open(Config,Identity,Connection)),
        try
            report(#{ready=>true}),Saved=loop(A,Client,undefined),result(A:close(Client)),
            {error,#transit_error{kind=closed}}=A:describe(Client),
            case Saved of undefined->ok; #transit_mutation_prepared{bytes=Value}->true=is_map(json:decode(Value)) end,
            report(#{closed=>true})
        after A:close(Client) end
    catch Class:Reason:_ ->
        Safe=case Reason of {failure,#transit_error{kind=K,phase=P}}->{K,P}; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        io:format(standard_error,"Mutation SDK proof failed: ~p ~p~n",[Class,Safe]),halt(1)
    end.

-module(beam_document_controller).
-export([main/2, put/3, get/2]).
main(A,[Mode0,Path]) ->
    try
        {ok,Bytes}=file:read_file(Path),Cfg=json:decode(Bytes),
        case unicode:characters_to_binary(Mode0) of
            <<"document-codecs">> -> {ok,F}=file:read_file(maps:get(<<"document_fixtures">>,Cfg)),A:golden(json:decode(F),Cfg),report(#{codecs=>true});
            _ -> Changes=A:prepare(Cfg),S=ets:new(document_proof,[set,public]),R=ok(A,A:open(Cfg,S,Changes)),
                 try loop(A,R,S,Cfg,Changes,undefined) after A:close(R) end
        end
    catch Class:Reason:Stack ->
        Safe=case Reason of {sdk_failure,Detail}->Detail; Atom when is_atom(Atom)->Atom; _->assertion_failed end,
        io:format(standard_error,"Document SDK proof failed: ~p ~p ~p~n",[Class,Safe,Stack]),halt(1)
    end.
put(S,K,V) -> true=ets:insert(S,{K,V}).
get(S,K) -> [{K,V}]=ets:lookup(S,K),V.
ok(A,{error,E}) -> error({sdk_failure,maps:with([kind,code,phase],A:view(E))});
ok(_,{ok,V}) -> V.
expect(A,K,{error,E}) -> K=maps:get(kind,A:view(E));
expect(_,K,_) -> error({expected,K}).
report(V) -> io:put_chars([json:encode(V),"\n"]).
committed(_,_,0) -> error(no_commit);
committed(A,R,N) -> case A:event(ok(A,A:next(R))) of committed->ok; progress->committed(A,R,N-1); _->error(unexpected_event) end.
loop(A,R,S,Cfg,Changes,Saved) ->
    Command=unicode:characters_to_binary(io:get_line("")),
    Next=case Command of
        <<"one\n">> -> committed(A,R,12),expect(A,turn_expired,A:expired(get(S,escaped))),report(#{event=><<"committed">>,phase=>get(S,phase)}),Saved;
        <<"read\n">> ->
            #{reference:=Ref,floor:=0,merge_window:=0}=ok(A,A:describe(R,Cfg)),Revision=A:revision(Ref),
            #{status:=Status,assignments:=[{_,{signed,-9223372036854775808}}|_]}=ok(A,A:path(R,Ref,[<<"value">>])),
            #{items:=Items,next:=undefined}=ok(A,A:sequence(R,Ref)),
            Text=unicode:characters_to_binary([C||{_,[{_,{character,C}}]}<-Items]),
            case Revision of 2->scalar=Status,<<"🙂"/utf8>>=Text; 3->conflict=Status,<<"🙂́"/utf8>>=Text end,
            #{status:=missing}=ok(A,A:path(R,Ref,[<<"missing">>])),
            Expected=binary:decode_hex(lists:nth(Revision-1,maps:get(<<"changes">>,Cfg))),Expected=ok(A,A:accepted(R,Ref)),
            report(#{revision=>integer_to_binary(Revision),items=>length(Items),status=>atom_to_binary(Status,utf8)}),case Saved of undefined->Ref; _->Saved end;
        <<"old\n">> -> #{status:=scalar}=ok(A,A:path(R,Saved,[<<"value">>])),report(#{retained=>true}),Saved;
        <<"denied\n">> -> expect(A,access_denied,A:path(R,Saved,[<<"value">>])),report(#{denied=>true}),Saved;
        <<"resynchronize\n">> -> #{previous_counter:=P,clock:=C}=ok(A,A:resynchronize(R,Cfg)),report(#{previous=>integer_to_binary(P),clock=>integer_to_binary(C)}),Saved;
        <<"retired\n">> -> #{retired:=true}=ok(A,A:describe(R,Cfg)),{error,E}=A:path(R,Saved,[<<"value">>]),#{code:=<<"DocumentRetired">>}=A:view(E),report(#{retired=>true}),Saved;
        <<"async-close\n">> ->
            Other=ok(A,A:open(Cfg,S,Changes)),Parent=self(),spawn(fun()->Parent!{read,A:describe(Other,Cfg)} end),
            receive {read,Result}->ok(A,Result) after 30000->error(read_timeout) end,
            ok(A,A:close(Other)),expect(A,closed,A:describe(Other,Cfg)),report(#{joined=>true}),Saved;
        <<"close\n">> -> ok(A,A:close(R)),expect(A,closed,A:describe(R,Cfg)),report(#{closed=>true}),closed;
        _ -> error(unknown_document_command)
    end,
    case Next of closed->ok; _->loop(A,R,S,Cfg,Changes,Next) end.

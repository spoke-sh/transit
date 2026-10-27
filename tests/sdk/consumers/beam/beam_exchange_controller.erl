-module(beam_exchange_controller).
-export([main/0, main/2, get/2, put/3, wait_file/1]).
main() -> main(beam_http_adapter, init:get_plain_arguments()), halt().
main(A, [Mode0, Path, Fixtures]) ->
    try
        A:golden(read(Fixtures)), Cfg = read(Path), Mode = unicode:characters_to_binary(Mode0),
        S = ets:new(exchange_proof, [set, public]), Request = ok(A, A:prepare(Cfg)),
        R = ok(A, A:open(Cfg, S, Request)),
        try
            case Mode of Async when Async =:= <<"http-async">>; Async =:= <<"grpc-async">> -> asynchronous(A, R, Cfg);
                _ -> loop(A, R, S, Cfg, Request, undefined, undefined, <<>>) end
        after A:close(R) end
    catch Class:Reason:Stack ->
        Safe = case Reason of {sdk_failure, Detail} -> Detail; Atom when is_atom(Atom) -> Atom; _ -> assertion_failed end,
        io:format(standard_error, "Exchange SDK proof failed: ~p ~p ~p~n", [Class, Safe, Stack]), halt(1)
    end.
read(Path) -> {ok, Bytes} = file:read_file(Path), json:decode(Bytes).
ok(A, {error, Error}) -> error({sdk_failure, maps:with([kind, code, phase], A:view(Error))});
ok(_, {ok, Value}) -> Value.
expect(A, Kind, {error, Error}) -> Kind = maps:get(kind, A:view(Error));
expect(_, Kind, _) -> error({expected, Kind}).
get(S, Key) -> [{Key, Value}] = ets:lookup(S, Key), Value.
put(S, Key, Value) -> true = ets:insert(S, {Key, Value}).
report(Value) -> io:put_chars([json:encode(Value), "\n"]).
wait_file(Path) -> wait_file(Path, 3000).
wait_file(_, 0) -> error(file_timeout);
wait_file(Path, N) -> case filelib:is_file(Path) of true -> ok; false -> timer:sleep(10), wait_file(Path, N - 1) end.
committed(_, _, 0) -> error(no_commit);
committed(A, R, N) -> case A:event(ok(A, A:next(R))) of committed -> ok; _ -> committed(A, R, N - 1) end.
loop(A, R, S, Cfg, Request, Reader, Outcome, Owned) ->
    Line = case io:get_line("") of eof -> eof; Input -> unicode:characters_to_binary(Input) end,
    case Line of
        <<"step\n">> -> committed(A, R, 32), expect(A, turn_expired, A:stage(get(S, escaped), Request)),
            expect(A, turn_expired, A:release_expired(get(S, escaped))),
            expect(A, turn_expired, A:followup_expired(get(S, escaped), Request)), report(get(S, result)),
            loop(A, R, S, Cfg, Request, Reader, Outcome, Owned);
        <<"open\n">> ->
            Decoded = ok(A, A:outcome(binary:decode_hex(maps:get(<<"outcome">>, Cfg)))),
            ok = A:diagnostics(R, Decoded),
            Opened = ok(A, A:open_capture(R, Decoded)), expect(A, busy, A:open_capture(R, Decoded)),
            {First, Advanced} = ok(A, A:read(Opened)), false = maps:get(complete, First), true = byte_size(maps:get(bytes, First)) > 0,
            %% Copies of old immutable handles cannot skip a returned part.
            expect(A, read_failed, A:read(Opened)), report(#{prefix => true}),
            loop(A, R, S, Cfg, Request, Advanced, Decoded, Owned);
        <<"denied\n">> -> ok = A:diagnostic_denied(R, Outcome), expect(A, access_denied, A:read(Reader)), report(#{denied => true}), loop(A, R, S, Cfg, Request, Reader, Outcome, Owned);
        <<"reopen\n">> ->
            {error, Error} = A:read(Reader), #{kind := read_failed, code := Code} = A:view(Error),
            Code = A:replay_error(),
            ok = ok(A, A:close_capture(Reader)), ok = ok(A, A:close_capture(Reader)),
            {Complete, Body} = drain(A, ok(A, A:open_capture(R, Outcome)), <<>>), true = A:complete(Complete),
            ok = ok(A, A:close_capture(Complete)), report(#{complete => true, body => binary:encode_hex(Body, lowercase)}),
            loop(A, R, S, Cfg, Request, Complete, Outcome, Body);
        <<"close\n">> -> ok(A, A:close(R)),
            case Reader of undefined -> ok; _ -> expect(A, closed, A:read(Reader)) end,
            report(#{closed => true, owned => binary:encode_hex(Owned, lowercase)});
        _ -> error(bad_command)
    end.
drain(A, Reader, Body) ->
    case ok(A, A:read(Reader)) of
        {done, Next} -> {Next, Body};
        {#{kind := Kind, bytes := Bytes}, Next} ->
            true = byte_size(Bytes) =< 256,
            drain(A, Next, case Kind of response_body -> <<Body/binary, Bytes/binary>>; _ -> Body end)
    end.
asynchronous(A, R, Cfg) ->
    Outcome = ok(A, A:outcome(binary:decode_hex(maps:get(<<"outcome">>, Cfg)))),
    {First, Reader} = ok(A, A:read(ok(A, A:open_capture(R, Outcome)))),
    false = maps:get(complete, First), true = byte_size(maps:get(bytes, First)) > 0,
    file:write_file(maps:get(<<"ready">>, Cfg), <<>>), wait_file(maps:get(<<"continue">>, Cfg)),
    Caller = spawn(fun() -> ok(A, A:read(Reader)) end), wait_file(maps:get(<<"accepted">>, Cfg)),
    expect(A, busy, A:read(Reader)), exit(Caller, kill), A:stop(R), Parent = self(),
    spawn(fun() -> Parent ! {closed, A:close(R)} end),
    {Result, Beats} = beats(0), ok(A, Result), true = Beats > 5,
    true = byte_size(maps:get(bytes, First)) > 0, expect(A, closed, A:read(Reader)), report(#{joined => true}).
beats(N) when N < 3000 -> receive {closed, Result} -> {Result, N} after 10 -> beats(N + 1) end;
beats(_) -> error(join_timeout).

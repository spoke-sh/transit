%% Shared schedule driver; adapters call each language's installed public API.
-module(beam_station_controller).
-compile({no_auto_import,[get/1,put/2]}).
-export([main/0, main/2, ok/2, expect/3, read/1, write/2, wait_file/1, get/2, put/3,
         initialize/3, handle_message/4, handle_result/4, before_dispatch/3, confirmed/4]).
main() -> [Mode, Path] = init:get_plain_arguments(), main(beam_station_adapter, [Mode, Path]), halt().
main(A, Args) ->
    try execute(A, Args) catch Class:Reason:Stack ->
        Safe = case Reason of {sdk_failure, Details} -> Details; Atom when is_atom(Atom) -> Atom; _ -> assertion_failed end,
        io:format(standard_error, "Proof failed: ~p ~p ~p~n", [Class, Safe, Stack]), halt(1) end.
execute(A, [Mode0, Path]) ->
    Mode = unicode:characters_to_binary(Mode0), Cfg = read(Path),
    S = ets:new(proof, [public, set]), put(S, mode, Mode), put(S, config, Cfg),
    case Mode of
        <<"codecs">> -> A:codecs(Cfg);
        <<"recover">> -> A:recover(Cfg);
        _ ->
            case A:open(Cfg, S) of
                {error, Error} -> denied = case {Mode, maps:get(kind, A:view(Error))} of {<<"denied">>, access_denied} -> denied end;
                {ok, Runner} ->
                    put(S, runner, Runner),
                    try run(A, Runner, S) after A:close(Runner) end
            end
    end.
ok(A, {error, E}) -> V = A:view(E), error({sdk_failure, maps:with([kind, phase, code, status], V)});
ok(_, {ok, Value}) -> Value;
ok(_, Other) -> error({unexpected_result, element(1, Other)}).
expect(A, Kind, {error, Error}) -> Kind = maps:get(kind, A:view(Error)), ok;
expect(_, Kind, _) -> error({expected_error, Kind}).
read(Path) -> {ok, Bytes} = file:read_file(Path), json:decode(Bytes).
write(Path, Value) -> ok = file:write_file(Path, json:encode(Value)).
report(Value) -> io:put_chars([json:encode(Value), "\n"]).
get(S, K) -> case ets:lookup(S, K) of [{K, V}] -> V; [] -> undefined end.
put(S, K, V) -> true = ets:insert(S, {K, V}), V.
count(S, K) -> ets:update_counter(S, K, 1, {K, 0}).
wait_file(Path) -> wait_file(Path, 3000).
wait_file(_, 0) -> error(file_timeout);
wait_file(Path, N) -> case filelib:is_file(Path) of true -> ok; false -> timer:sleep(10), wait_file(Path, N-1) end.
path(S, Name) -> filename:join(maps:get(<<"output">>, get(S, config)), Name).
view(A, X) -> A:view(X).
next(A, R) -> ok(A, A:next(R)).
kind(A, E) -> case E of X when is_atom(X) -> X; _ -> maps:get(kind, view(A, E)) end.
until_event(A, R, 0) -> error({no_event, A, is_tuple(R)});
until_event(A, R, N) -> E = next(A, R), case kind(A, E) of progress -> until_event(A, R, N-1); _ -> E end.
run(A, R, S) ->
    Mode = get(S, mode),
    case Mode of
        <<"gates">> ->
            gates(A, R, S, 40, []), 1 = get(S, initialized), 1 = get(S, handled),
            expect(A, turn_expired, A:require(get(S, escaped_state), A:key(total))),
            Purposes = lists:sort([atom_to_binary(P) || {{confirmed, P}, true} <- ets:tab2list(S)]),
            report(#{gates => Purposes, handled => 1, dispatches => length([I || {{saved, I}, _} <- ets:tab2list(S)])});
        <<"async">> ->
            progress = kind(A, next(A, R)),
            Caller = spawn(fun Loop() -> next(A, R), Loop() end),
            wait_file(path(S, <<"accepted">>)), expect(A, busy, A:next(R)),
            exit(Caller, kill), ok = A:stop(R), Parent = self(),
            spawn(fun() -> Parent ! {closed, A:close(R)} end),
            {Shutdown, Beats} = beats(0), true = Beats > 5,
            V = view(A, ok(A, Shutdown)), undefined = maps:get(pending, V),
            committed = kind(A, maps:get(last_event, V)), 1 = get(S, handled),
            report(#{committed => true, beats => Beats});
        <<"stale">> -> expect_loop(A, R, stale_ownership, 8), report(#{denied => true});
        <<"expired">> -> expect_loop(A, R, process_retired, 8), report(#{denied => true});
        <<"revoked-result">> -> expect_loop(A, R, access_denied, 8), report(#{denied => true});
        <<"poison">> -> expect_loop(A, R, read_failed, 8), report(#{denied => true});
        <<"worker">> -> worker(A, R, S);
        _ -> failure(A, R, Mode, 8)
    end.
beats(N) -> receive {closed, V} -> {V, N} after 10 -> beats(N+1) end.
gates(_, _, _, 0, _) -> error(gate_timeout);
gates(A, R, S, N, Phases) -> gates_event(A, R, S, N, next(A, R), Phases).
gates_event(A, R, S, N, E, Phases) ->
    case kind(A, E) of
        needs_recovery ->
            V = view(A, E), Phase = maps:get(phase, V),
            case Phase of confirm -> true = maps:get(receipt, V) =/= undefined; persist -> ok end,
            E = next(A, R), gates_event(A, R, S, N-1, ok(A, A:reconcile(R)), [Phase | Phases]);
        committed -> [confirm, persist] = lists:usort(Phases);
        _ -> gates(A, R, S, N-1, Phases)
    end.
expect_loop(_, _, _, 0) -> error(expected_failure);
expect_loop(A, R, Kind, N) -> case A:next(R) of {error, _} = E -> expect(A, Kind, E); _ -> expect_loop(A, R, Kind, N-1) end.
failure(_, _, _, 0) -> error(expected_handler_failure);
failure(A, R, Mode, N) ->
    Block = binary:longest_common_suffix([Mode, <<"-block">>]) =:= 6,
    case A:next(R) of
        {error, _} = E -> false = Block, Expected = case Mode of <<"decode-", _/binary>> -> codec; _ -> handler end, expect(A, Expected, E);
        {ok, E} -> case kind(A, E) of blocked -> true = Block, true = maps:get(receipt, view(A, E)) =/= undefined; _ -> failure(A, R, Mode, N-1) end
    end.
worker(A, R, S) ->
    case unicode:characters_to_binary(io:get_line("")) of
        Action when Action =:= <<"one\n">>; Action =:= <<"reconcile\n">> ->
            First = case Action of <<"reconcile\n">> -> ok(A, A:reconcile(R)); _ -> next(A, R) end,
            E = case kind(A, First) of progress -> until_event(A, R, 31); _ -> First end,
            case kind(A, E) of needs_recovery ->
                #{mutation := Mutation} = view(A, E), Bytes = maps:get(bytes, view(A, Mutation)),
                {ok, Bytes} = file:read_file(maps:get(<<"pending">>, get(S, config))); _ -> ok end,
            Name = case kind(A, E) of committed -> <<"Committed">>; idle -> <<"Idle">>; needs_recovery -> <<"NeedsRecovery">>; blocked -> <<"Blocked">> end,
            Result = case kind(A, E) of needs_recovery ->
                #{phase := Phase, error := Error} = view(A, E),
                #{event => Name, phase => Phase, code => maps:get(code, view(A, Error))};
                _ -> #{event => Name} end,
            report(Result), worker(A, R, S);
        <<"close\n">> -> ok(A, A:close(R)), expired(A, S),
            [begin #{ordinal := I, ipc := Bytes} = view(A, Segment), ok = file:write_file(path(S, <<(integer_to_binary(I))/binary, ".arrow">>), Bytes) end || {{segment, _}, Segment} <- ets:tab2list(S)],
            report(#{closed => true})
    end.
expired(A, S) ->
    case get(S, escaped_table) of undefined -> ok; T -> expect(A, turn_expired, A:table_get(T, 0)) end,
    case get(S, escaped_source) of undefined -> ok; Source -> expect(A, turn_expired, A:source_state(Source)) end,
    case get(S, escaped_reader) of undefined -> ok; Reader -> expect(A, turn_expired, A:manifest(Reader)) end.
initialize(A, Turn, S) ->
    Role = maps:get(<<"role">>, get(S, config)),
    case Role of <<"service">> -> count(S, initialized), #{mutations := 3} = ok(A, A:budgets(Turn)); _ -> ok end,
    A:example_initialize(Role, Turn, S).
handle_message(A, Turn, Input, S) ->
    Cfg = get(S, config), Role = maps:get(<<"role">>, Cfg), Mode = get(S, mode),
    case Role of
        <<"service">> ->
            count(S, handled), State = ok(A, A:state(Turn)), put(S, escaped_state, State),
            Parent = self(), spawn(fun() -> Parent ! {other_read, A:require(State, A:key(total))} end),
            receive {other_read, Other} -> expect(A, busy, Other) end,
            case Mode of
                <<"invalid-handler">> -> invalid_callback_return;
                <<"handler-", _/binary>> -> ok(A, A:put(State, A:key(total), 73)), throw(injected_handler_failure);
                <<"exit-", _/binary>> -> ok(A, A:put(State, A:key(total), 73)), exit(injected_handler_exit);
                <<"poison">> -> expect(A, read_failed, A:require(State, A:key(total))), {ok, S};
                _ -> erlang:put(proof_turn, {A, Turn}), ok(A, A:require_reentrant(State)), A:example_message(Role, Turn, Input, S)
            end;
        <<"table">> -> table_message(A, Turn, Input, S);
        <<"query">> when Mode =:= <<"revoked-result">> ->
            Saved = read(path(S, <<"manifest.json">>)), Reader = ok(A, A:result(Turn, binary_to_integer(maps:get(<<"correlation">>, Saved)))),
            #{rows := 41} = view(A, ok(A, A:manifest(Reader))),
            ok = file:write_file(path(S, <<"ready">>), <<>>), wait_file(path(S, <<"continue">>)),
            expect(A, access_denied, A:segment(Reader, 0)), {ok, S};
        _ -> A:example_message(Role, Turn, Input, S)
    end.
table_message(A, Turn, Input, S) ->
    case {A:input_variant(Input), filelib:is_file(path(S, <<"version.json">>))} of
        {rows, _} ->
            Table = ok(A, A:table(Turn)), put(S, escaped_table, Table),
            Basis = ok(A, A:basis(Table)), {Rows, 6} = pages(A, Table, undefined, Basis, [], 0),
            41 = length(Rows), #{key := -9223372036854775808, value := undefined} = view(A, hd(Rows)),
            Version = ok(A, A:retain(Turn)), write(path(S, <<"version.json">>), view(A, Version)),
            ok(A, A:table_update(Table, -9223372036854775808, 17)), {ok, S};
        {initialize, true} ->
            Table = ok(A, A:table(Turn)), {found, Row} = ok(A, A:table_get(Table, -9223372036854775808)), #{value := 17} = view(A, Row),
            Version = A:version(read(path(S, <<"version.json">>))), Source = ok(A, A:open_version(Turn, Version)), put(S, escaped_source, Source),
            Retained = ok(A, A:source_table(Source)), {found, Old} = ok(A, A:table_get(Retained, -9223372036854775808)), #{value := undefined} = view(A, Old),
            #{entries := Entries} = view(A, ok(A, A:table_page(Retained, undefined))), 8 = length(Entries),
            State = ok(A, A:source_state(Source)), #{entries := KV} = view(A, ok(A, A:state_page(State))), true = length(KV) =< 8,
            ok(A, A:release(Turn, Version)), {ok, S};
        _ -> A:example_message(<<"table">>, Turn, Input, S)
    end.
pages(A, Table, Cursor, Basis, Rows, N) ->
    #{entries := Entries, cursor := Next, basis := Basis} = view(A, ok(A, A:table_page(Table, Cursor))), true = length(Entries) =< 8,
    case Next of undefined -> {Rows ++ Entries, N+1}; _ -> pages(A, Table, Next, Basis, Rows ++ Entries, N+1) end.
handle_result(A, Turn, Input, S) ->
    {ok, _} = A:example_result(Turn, Input, S), #{correlation := Correlation} = view(A, Input),
    Reader = ok(A, A:result(Turn, Correlation)), put(S, escaped_reader, Reader),
    #{rows := Rows, segments := Segments, source := Source, destination := Dest, basis := Basis, byte_count := Bytes} = view(A, ok(A, A:manifest(Reader))),
    #{resource := Resource, revision := Revision} = view(A, Basis),
    write(path(S, <<"manifest.json">>), #{rows => Rows, segments => Segments, correlation => integer_to_binary(Correlation),
        source => maps:get(pid, view(A, Source)), destination => maps:get(pid, view(A, Dest)), resource => maps:get(resource, view(A, Resource)), revision => Revision, bytes => Bytes}), {ok, S}.
before_dispatch(A, Mutation, S) ->
    #{identity := Identity, purpose := Purpose, bytes := Bytes} = view(A, Mutation),
    put(S, {purpose, Identity}, Purpose),
    case get(S, mode) of <<"gates">> ->
        R = get(S, runner), expect(A, busy, A:next(R)), expect(A, busy, A:close(R)),
        case ets:insert_new(S, {{before, Purpose}, true}) of true -> throw(injected_persistence_failure); false -> ok end;
        _ -> ok end,
    case get(S, {saved, Identity}) of undefined -> put(S, {saved, Identity}, Bytes); Bytes -> ok end,
    {ok, File} = file:open(maps:get(<<"pending">>, get(S, config)), [write, raw, binary]),
    try ok = file:write(File, Bytes), ok = file:sync(File) after file:close(File) end, ok.
confirmed(_A, Identity, Receipt, S) ->
    Purpose = get(S, {purpose, Identity}),
    case get(S, mode) of <<"gates">> -> case ets:insert_new(S, {{confirmed, Purpose}, true}) of true -> error(injected_confirmation_failure); false -> ok end; _ -> ok end,
    case get(S, {receipt, Identity}) of undefined -> put(S, {receipt, Identity}, Receipt); Receipt -> ok end, ok.

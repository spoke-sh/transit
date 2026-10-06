%% Internal native port owner. Called only by its owned BEAM worker.
-module(transit_sdk_port).
-include("transit_client.hrl").
-export([open/4, request/5, request/6, close/1, schema/2, limit/2]).
-record(port_state, {port, directory, file, contract, request_schema, max_status}).
open(App, Override, Config, Contract) ->
    Executable = executable(App, Override),
    Root = case os:getenv("TMPDIR") of false -> "/tmp"; Path -> Path end,
    Directory = filename:join(Root, "transit-beam-" ++ binary_to_list(binary:encode_hex(crypto:strong_rand_bytes(16)))),
    ok = file:make_dir(Directory), ok = file:change_mode(Directory, 8#700),
    File = filename:join(Directory, "host.json"),
    try
        Bytes = transit_sdk_value:bytes(transit_sdk_value:encode(Config), maps:get(<<"host_config_bytes">>, maps:get(<<"limits">>, Contract))),
        ok = file:write_file(File, Bytes, [binary, exclusive]), ok = file:change_mode(File, 8#600),
        Port = open_port({spawn_executable, Executable}, [binary, exit_status, use_stdio, {line, 4096}, {args, [File]}]),
        RequestSchema = case App of transit_native_client -> <<"ClientHostRequest">>; transit_native_station -> <<"HostRequest">> end,
        #port_state{port = Port, directory = Directory, file = File, contract = Contract,
            request_schema = RequestSchema, max_status = lists:max(maps:values(maps:get(<<"statuses">>, Contract)))}
    catch _:_ -> file:delete(File), file:del_dir(Directory), transit_sdk_value:fail(incompatible_native, native_start) end.
executable(App, undefined) ->
    case application:load(App) of ok -> ok; {error, {already_loaded, App}} -> ok; _ -> transit_sdk_value:fail(incompatible_native, native_package) end,
    case application:get_key(App, vsn) of {ok, "0.2.0"} -> ok; _ -> transit_sdk_value:fail(incompatible_native, native_package_version) end,
    case code:priv_dir(App) of
        Dir when is_list(Dir) ->
            Name = case App of transit_native_client -> "transit-client-host"; transit_native_station -> "transit-station-host" end,
            executable(App, filename:join(Dir, Name));
        _ -> transit_sdk_value:fail(incompatible_native, native_package)
    end;
executable(_, Override) when is_list(Override); is_binary(Override) ->
    case filelib:is_regular(Override) of true -> filename:absname(Override); false -> transit_sdk_value:fail(incompatible_native, native_path) end;
executable(_, _) -> transit_sdk_value:fail(invalid_argument, native_path).
schema(#port_state{contract = Contract}, Name) -> maps:get(Name, maps:get(<<"schemas">>, Contract)).
limit(#port_state{contract = Contract}, Name) -> maps:get(Name, maps:get(<<"limits">>, Contract)).
request(State, Request, Phase, Mutation, ResponseSchema) ->
    request(State, Request, Phase, Mutation, ResponseSchema, {limit(State, <<"host_line_bytes">>),64}).
request(State, Request, Phase, Mutation, ResponseSchema, Bounds) ->
    case get({transit_broken_port, State#port_state.port}) of
        true -> transit_sdk_value:fail(read_failed, native_closed);
        _ -> ok
    end,
    try exchange(State, Request, Phase, Mutation, ResponseSchema, Bounds)
    catch
      throw:{transit_native, Error} -> throw({transit_sdk, Error});
      throw:{transit_sdk, #transit_error{kind = Kind} = Error} ->
        case lists:member(Kind, [read_failed, unknown_outcome, incompatible_native]) of
            true -> put({transit_broken_port, State#port_state.port}, true);
            false -> ok
        end,
        throw({transit_sdk, Error})
    end.
exchange(State, Request, Phase, Mutation, ResponseSchema, {LineBytes,JsonDepth}) ->
    transit_sdk_value:require(schema(State, State#port_state.request_schema), Request),
    Bytes = <<(transit_sdk_value:encode(Request))/binary, $\n>>,
    case byte_size(Bytes)=<LineBytes of true->ok; false->transit_sdk_value:fail(invalid_argument,bytes) end,
    Port = State#port_state.port,
    Failure = case Mutation of true -> unknown_outcome; false -> read_failed end,
    %% An unexpected line cannot be mistaken for the response to this request.
    receive
        {Port, _} -> transit_sdk_value:fail(Failure, Phase)
    after 0 -> ok end,
    try erlang:port_command(Port, Bytes, [nosuspend]) of
        false -> transit_sdk_value:fail(busy, native_pipe);
        true -> ok
    catch error:badarg -> transit_sdk_value:fail(Failure, Phase) end,
    Deadline = erlang:monotonic_time(millisecond) + 65000,
    Response = read(State, [], 0, Deadline, Failure, Phase, LineBytes),
    try transit_sdk_value:json(Response,JsonDepth) of
        #{<<"status">> := Status, <<"value">> := Value} = Envelope
          when map_size(Envelope) =:= 2, is_integer(Status), Status >= 0, Status =< State#port_state.max_status ->
            case Status of
                0 ->
                    try case ResponseSchema of undefined -> Value; _ -> transit_sdk_value:require(schema(State, ResponseSchema), Value) end
                    catch _:_ -> transit_sdk_value:fail(Failure, Phase) end;
                _ -> throw({transit_native, transit_sdk_value:native(Status, Value, Phase)})
            end;
        _ -> transit_sdk_value:fail(Failure, Phase)
    catch
        throw:{transit_sdk, #transit_error{kind = incompatible_native}} -> transit_sdk_value:fail(Failure, Phase)
    end.
read(State, Parts, Size, Deadline, Failure, Phase, LineBytes) ->
    Port = State#port_state.port,
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Port, {data, {Ending, Chunk}}} ->
            NextSize = Size + byte_size(Chunk),
            case NextSize > LineBytes of
                true -> transit_sdk_value:fail(Failure, Phase);
                false when Ending =:= noeol -> read(State, [Chunk | Parts], NextSize, Deadline, Failure, Phase, LineBytes);
                false -> iolist_to_binary(lists:reverse([Chunk | Parts]))
            end;
        {Port, {exit_status, _}} -> transit_sdk_value:fail(Failure, Phase);
        {'EXIT', Port, _} -> transit_sdk_value:fail(Failure, Phase)
    after Remaining -> transit_sdk_value:fail(Failure, Phase) end.
close(#port_state{port = Port, file = File, directory = Directory} = State) ->
    try
        #{<<"closed">> := true} = request(State, #{<<"shutdown">> => #{}}, cleanup, false, undefined),
        receive {Port, {exit_status, 0}} -> ok; {Port, {exit_status, _}} -> transit_sdk_value:fail(cleanup, native_exit)
        after 2000 -> transit_sdk_value:fail(cleanup, native_exit) end
    catch _:_ -> transit_sdk_value:fail(cleanup, native_shutdown)
    after catch erlang:port_close(Port), erase({transit_broken_port, Port}), file:delete(File), file:del_dir(Directory) end.

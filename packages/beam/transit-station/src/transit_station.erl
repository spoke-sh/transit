%% An owned native port. This process schedules transport, never durable turns.
-module(transit_station).
-behaviour(gen_server).
-include("transit_station.hrl").
-export([open/2, close/1, request/2, next/1, apply/2, finish/2, pending/1,
         call/2, prepare/4, arrow_cell/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-define(MAXIMUM, (256 * 1024 * 2 + 16384)).
-record(state, {port, owner, pending = undefined, parts = [], size = 0}).

open(Executable, Config) ->
    case gen_server:start(?MODULE, {self(), Executable, Config}, []) of
        {ok, Server} ->
            case request(Server, #{<<"hello">> => #{}}) of
                {ok, #{<<"host_version">> := ?STATION_VERSION,
                       <<"station_version">> := ?STATION_VERSION,
                       <<"transit_version">> := ?STATION_VERSION} = Hello}
                  when map_size(Hello) =:= 3 -> {ok, Server};
                _ -> close(Server), {error, {?STATION_INCOMPATIBLE_VERSION, <<"Version mismatch">>}}
            end;
        Error -> Error
    end.
close(Server) ->
    try gen_server:call(Server, close, infinity) catch exit:_ -> ok end.
request(Server, Request) ->
    try gen_server:call(Server, {request, Request}, infinity)
    catch exit:_ -> {error, {?STATION_UNCERTAIN, <<"Port owner unavailable">>}} end.
next(Server) -> request(Server, #{<<"next">> => erlang:system_time(millisecond) + 30000}).
apply(Server, Action) -> request(Server, #{<<"apply">> => Action}).
finish(Server, Failed) when is_boolean(Failed) -> request(Server, #{<<"finish">> => Failed}).
pending(Server) -> request(Server, #{<<"pending">> => #{}}).
call(Server, Frozen) when is_binary(Frozen) -> request(Server, #{<<"call">> => Frozen}).
prepare(Server, Kind, SeedFile, Document) ->
    request(Server, #{<<"prepare">> => #{<<"kind">> => Kind,
        <<"seed_file">> => unicode:characters_to_binary(SeedFile),
        <<"document">> => iolist_to_binary(json:encode(Document))}}).
arrow_cell(Server, Ipc, Row, Column) ->
    request(Server, #{<<"arrow_cell">> => #{<<"ipc">> => binary:encode_hex(Ipc, lowercase),
        <<"row">> => Row, <<"column">> => Column}}).

init({Owner, Executable, Config}) ->
    process_flag(trap_exit, true),
    Port = open_port({spawn_executable, filename:absname(Executable)},
        [binary, exit_status, use_stdio, {line, 4096}, {args, [filename:absname(Config)]}]),
    {ok, #state{port = Port, owner = monitor(process, Owner)}}.
handle_call(close, _From, State) ->
    {stop, normal, ok, abort(State, ?STATION_UNCERTAIN, <<"Port closed">>)};
handle_call({request, _}, _From, #state{pending = Pending} = State) when Pending =/= undefined ->
    {reply, {error, {?STATION_BUSY, <<"One operation per port">>}}, State};
handle_call({request, Request}, From, State) ->
    %% Freeze the request before publication; port_command never suspends this
    %% scheduler waiting for pipe capacity. Failed admission cannot be retried
    %% implicitly because the caller still owns the private proposal.
    case encode(Request) of
        {error, _} = Error -> {reply, Error, State};
        {ok, Bytes} ->
            try erlang:port_command(State#state.port, Bytes, [nosuspend]) of
                false -> {reply, {error, {?STATION_BUSY, <<"Native pipe full">>}}, State};
                true ->
                    Mon = monitor(process, element(1, From)),
                    Timer = erlang:send_after(65000, self(), {deadline, Mon}),
                    Uncertain = maps:is_key(<<"next">>, Request) orelse maps:is_key(<<"call">>, Request),
                    {noreply, State#state{pending = {From, Mon, Timer, Uncertain}}}
            catch error:badarg ->
                {stop, normal, {error, {?STATION_UNCERTAIN, <<"Native port unavailable">>}}, State}
            end
    end;
handle_call(_, _, State) -> {reply, {error, {?STATION_INVALID_ARGUMENT, <<"Unknown operation">>}}, State}.
handle_cast(_, State) -> {noreply, State}.
handle_info({Port, {data, {Ending, Chunk}}}, #state{port = Port, pending = Pending} = State)
  when Pending =/= undefined ->
    Size = State#state.size + byte_size(Chunk),
    case Size > ?MAXIMUM of
        true -> broken(State, <<"Oversized native response">>);
        false when Ending =:= noeol ->
            {noreply, State#state{parts = [Chunk | State#state.parts], size = Size}};
        false ->
            Bytes = iolist_to_binary(lists:reverse([Chunk | State#state.parts])),
            case decode(Bytes) of
                invalid -> broken(State, <<"Malformed native response">>);
                Result ->
                    {From, Mon, Timer, _} = Pending,
                    erlang:cancel_timer(Timer), demonitor(Mon, [flush]),
                    gen_server:reply(From, Result),
                    {noreply, State#state{pending = undefined, parts = [], size = 0}}
            end
    end;
handle_info({'DOWN', Mon, process, _, _}, #state{owner = Mon} = State) ->
    {stop, normal, abort(State, ?STATION_UNCERTAIN, <<"Handle owner exited">>)};
handle_info({'DOWN', Mon, process, _, _}, #state{pending = {_, Mon, _, _}} = State) ->
    {stop, normal, abort(State, ?STATION_UNCERTAIN, <<"Awaiting process exited">>)};
handle_info({deadline, Mon}, #state{pending = {_, Mon, _, _}} = State) ->
    broken(State, <<"Native deadline elapsed">>);
handle_info({Port, {exit_status, _}}, #state{port = Port} = State) -> broken(State, <<"Native process exited">>);
handle_info({'EXIT', Port, _}, #state{port = Port} = State) -> broken(State, <<"Native port exited">>);
handle_info({Port, {data, _}}, #state{port = Port} = State) -> broken(State, <<"Unsolicited native response">>);
handle_info(_, State) -> {noreply, State}.
terminate(_, #state{port = Port}) ->
    %% EOF is not an acknowledgement. The native host finishes any bounded
    %% in-flight operation before noticing it; its outcome may be unknown here.
    catch erlang:port_close(Port), ok.
encode(Request) when is_map(Request), map_size(Request) =:= 1 ->
    try [json:encode(Request), $\n] of
        Bytes -> case iolist_size(Bytes) =< ?MAXIMUM of
            true -> {ok, Bytes};
            false -> {error, {?STATION_INVALID_ARGUMENT, <<"Oversized request">>}}
        end
    catch _:_ -> {error, {?STATION_INVALID_ARGUMENT, <<"Invalid JSON request">>}} end;
encode(_) -> {error, {?STATION_INVALID_ARGUMENT, <<"Expected one operation">>}}.
decode(Bytes) ->
    try json:decode(Bytes) of
        #{<<"status">> := Status, <<"value">> := Value} = Envelope
          when map_size(Envelope) =:= 2, is_integer(Status), Status >= 0, Status =< ?STATION_MAX_STATUS ->
            case Status of 0 -> {ok, Value}; _ -> {error, {Status, Value}} end;
        _ -> invalid
    catch _:_ -> invalid end.
broken(#state{pending = {_, _, _, true}} = State, Detail) ->
    {stop, normal, abort(State, ?STATION_UNCERTAIN, Detail)};
broken(State, Detail) -> {stop, normal, abort(State, ?STATION_INVALID_RESPONSE, Detail)}.
abort(#state{pending = undefined} = State, _, _) -> State;
abort(#state{pending = {From, Mon, Timer, _}} = State, Status, Detail) ->
    erlang:cancel_timer(Timer), demonitor(Mon, [flush]),
    gen_server:reply(From, {error, {Status, Detail}}),
    State#state{pending = undefined}.

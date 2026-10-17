%% One admitted SDK operation; native work survives loss of its waiting caller.
-module(transit_sdk_worker).
-behaviour(gen_server).
-include("transit_client.hrl").
-export([open/3, start_link/2, handle/1, invoke/2, close/1, stop/1, stopped/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, format_status/1]).
-record(state, {owner, worker, module, gate, admission, waiting = undefined, acquire = undefined,
                ready = false, closing = undefined, evidence = undefined}).
-opaque handle() :: {transit_handle, pid(), atomics:atomics_ref(), ets:tid()}.
-export_type([handle/0]).
open(Module, Config, Linked) ->
    Start = case Linked of true -> start_link; false -> start end,
    case gen_server:Start(?MODULE, {self(), Module, Config}, []) of
        {ok, Pid} -> handle(Pid);
        _ -> {error, transit_sdk_value:error(incompatible_native, worker_start)}
    end.
start_link(Module, Config) -> gen_server:start_link(?MODULE, {self(), Module, Config}, []).
handle(Pid) -> call(Pid, acquire).
invoke({transit_handle, Pid, Gate, Admission}, Request) ->
    Ticket = make_ref(),
    case reserve(Gate, Admission, Ticket, 2) of
        ok -> call(Pid, {invoke, Ticket, Request});
        Error -> Error
    end.
reserve(_, _, _, 0) -> {error, transit_sdk_value:error(busy, admission)};
reserve(Gate, Table, Ticket, Attempts) ->
    try
        case atomics:get(Gate, 3) of
            0 ->
                case ets:insert_new(Table, {operation, self(), Ticket}) of
                    true -> ok;
                    false ->
                        case ets:lookup(Table, operation) of
                            [{operation, Owner, _} = Entry] ->
                                case is_process_alive(Owner) of
                                    true -> {error, transit_sdk_value:error(busy, admission)};
                                    false -> ets:delete_object(Table, Entry), reserve(Gate, Table, Ticket, Attempts - 1)
                                end;
                            [] -> reserve(Gate, Table, Ticket, Attempts - 1)
                        end
                end;
            _ -> {error, transit_sdk_value:error(closed, admission)}
        end
    catch error:badarg -> {error, transit_sdk_value:error(closed, admission)} end.
close({transit_handle, Pid, Gate, _}) ->
    %% A callback must not set stop or wait for its own completion.
    case get(transit_sdk_worker) of
        Pid -> {error, transit_sdk_value:error(busy, callback_close)};
        _ -> atomics:put(Gate, 3, 1), atomics:put(Gate, 1, 2), atomics:put(Gate, 2, 1), call(Pid, close)
    end.
stop({transit_handle, _, Gate, _}) -> atomics:put(Gate, 2, 1), ok.
stopped(Gate) -> atomics:get(Gate, 2) =/= 0.
call(Pid, Request) ->
    try gen_server:call(Pid, Request, infinity)
    catch exit:_ -> {error, transit_sdk_value:error(closed, worker)} end.
init({Owner, Module, Config}) ->
    process_flag(trap_exit, true), Gate = atomics:new(3, [{signed, false}]),
    Parent = self(), Worker = spawn_link(fun() -> worker(Parent, Module, Config, Gate) end),
    Admission = ets:new(transit_sdk_admission, [set, public]),
    {ok, #state{owner = monitor(process, Owner), worker = Worker, module = Module, gate = Gate, admission = Admission}}.
handle_call(acquire, From, #state{ready = false, acquire = undefined} = State) -> {noreply, State#state{acquire = From}};
handle_call(acquire, _, #state{ready = {error, Error}} = State) ->
    State#state.worker ! close, {stop, normal, {error, Error}, State};
handle_call(acquire, _, #state{ready = true, gate = Gate, admission = Admission} = State) -> {reply, {ok, {transit_handle, self(), Gate, Admission}}, State};
handle_call({invoke, Ticket, Request}, From, #state{ready = true, waiting = undefined, closing = undefined} = State) ->
    %% Transfer reservation ownership before dispatch. A dead caller's unpublished
    %% ticket can be reclaimed; an admitted job belongs to the live worker.
    Match = [{{operation, '$1', Ticket}, [{'=:=', '$1', {const, element(1, From)}}],
              [{const, {operation, State#state.worker, Ticket}}]}],
    case atomics:get(State#state.gate, 3) =:= 0 andalso ets:select_replace(State#state.admission, Match) =:= 1 of
        true -> State#state.worker ! {invoke, Request}, {noreply, State#state{waiting = From}};
        false -> {reply, {error, transit_sdk_value:error(closed, admission)}, State}
    end;
handle_call({invoke, _, _}, _, State) -> {reply, {error, transit_sdk_value:error(closed, admission)}, State};
handle_call(close, From, #state{closing = undefined, waiting = undefined, ready = true} = State) ->
    atomics:put(State#state.gate, 1, 2), State#state.worker ! close, {noreply, State#state{closing = From}};
handle_call(close, From, #state{closing = undefined} = State) -> {noreply, State#state{closing = From}};
handle_call(_, _, State) -> {reply, {error, transit_sdk_value:error(busy, admission)}, State}.
handle_cast(_, State) -> {noreply, State}.
handle_info({ready, Worker, {ok, Evidence}}, #state{worker = Worker} = State) ->
    reply(State#state.acquire, {ok, {transit_handle, self(), State#state.gate, State#state.admission}}),
    Next = State#state{ready = true, acquire = undefined, evidence = Evidence},
    case State#state.closing of undefined -> {noreply, Next}; _ -> Worker ! close, {noreply, Next} end;
handle_info({ready, Worker, {error, Error}}, #state{worker = Worker, acquire = undefined, closing = undefined} = State) ->
    {noreply, State#state{ready = {error, Error}}};
handle_info({ready, Worker, {error, Error}}, #state{worker = Worker} = State) ->
    reply(State#state.acquire, {error, Error}), reply(State#state.closing, {error, Error}),
    Worker ! close,
    {stop, normal, State#state{acquire = undefined, closing = undefined}};
handle_info({result, Worker, Reply, Evidence}, #state{worker = Worker} = State) ->
    ets:delete(State#state.admission, operation),
    Next = State#state{waiting = undefined, evidence = Evidence},
    case State#state.closing of
        undefined ->
            atomics:put(State#state.gate, 1, case atomics:get(State#state.gate, 3) of 0 -> 0; _ -> 2 end),
            reply(State#state.waiting, Reply), {noreply, Next};
        _ -> atomics:put(State#state.gate, 1, 2), reply(State#state.waiting, Reply), Worker ! close, {noreply, Next}
    end;
handle_info({closed, Worker, Result, Evidence}, #state{worker = Worker} = State) ->
    Reply = case Result of {ok, _} -> {ok, Evidence}; {error, Error} -> {error, Error, Evidence} end,
    reply(State#state.closing, Reply), {stop, normal, State#state{worker = undefined, closing = undefined, evidence = Evidence}};
handle_info({'DOWN', Mon, process, _, _}, #state{owner = Mon} = State) -> graceful(State);
handle_info({'EXIT', Worker, _}, #state{worker = Worker} = State) ->
    Error = transit_sdk_value:error(unknown_outcome, worker_loss),
    reply(State#state.waiting, {error, Error}), reply(State#state.acquire, {error, Error}),
    reply(State#state.closing, {error, Error, State#state.evidence}), {stop, normal, State#state{worker = undefined}};
handle_info({'EXIT', _, _}, State) -> graceful(State);
handle_info(_, State) -> {noreply, State}.
graceful(#state{ready = {error, _}} = State) -> State#state.worker ! close, {stop, normal, State};
graceful(State) ->
    atomics:put(State#state.gate, 3, 1), atomics:put(State#state.gate, 1, 2),
    atomics:put(State#state.gate, 2, 1),
    Next = State#state{closing = case State#state.closing of undefined -> abandoned; From -> From end},
    case State#state.waiting =:= undefined andalso State#state.ready =:= true of
        true -> atomics:put(State#state.gate, 1, 2), State#state.worker ! close;
        false -> ok
    end,
    {noreply, Next}.
reply(undefined, _) -> ok;
reply(abandoned, _) -> ok;
reply(From, Result) -> gen_server:reply(From, Result).
terminate(_, State) ->
    atomics:put(State#state.gate, 3, 1), atomics:put(State#state.gate, 1, 2), atomics:put(State#state.gate, 2, 1),
    %% OTP handles its parent's shutdown signal before handle_info. Join here
    %% too, so a supervisor's graceful shutdown preserves native ownership.
    case State#state.worker of
        undefined -> ok;
        Worker -> Worker ! close, shutdown_wait(State, erlang:monotonic_time(millisecond) + 68000)
    end.
shutdown_wait(State, Deadline) ->
    Worker = State#state.worker,
    receive
        {result, Worker, Reply, Evidence} -> reply(State#state.waiting, Reply),
            shutdown_wait(State#state{waiting = undefined, evidence = Evidence}, Deadline);
        {closed, Worker, Result, Evidence} ->
            Reply = case Result of {ok, _} -> {ok, Evidence}; {error, Error} -> {error, Error, Evidence} end,
            reply(State#state.closing, Reply);
        {'EXIT', Worker, _} -> ok
    after max(0, Deadline - erlang:monotonic_time(millisecond)) ->
        exit(Worker, kill), reply(State#state.waiting, {error, transit_sdk_value:error(unknown_outcome, forced_shutdown)})
    end.
format_status(Status) -> maps:map(fun(log, _) -> []; (_, _) -> redacted end, Status).
worker(Parent, Module, Config, Gate) ->
    process_flag(trap_exit, true),
    put(transit_sdk_worker, Parent),
    case transit_sdk_value:protect(fun() -> Module:open(Config, Gate) end) of
        {ok, State} -> Parent ! {ready, self(), {ok, Module:evidence(State)}}, loop(Parent, Module, State);
        {error, Error} -> Parent ! {ready, self(), {error, Error}}, receive close -> ok; {'EXIT', Parent, _} -> ok end
    end.
loop(Parent, Module, State) ->
    receive
        {invoke, Request} ->
            {Reply, Next} = case transit_sdk_value:protect(fun() -> Module:execute(Request, State) end) of
                {ok, Pair} -> Pair;
                {error, Error} -> {{error, Error}, State}
            end,
            Parent ! {result, self(), Reply, Module:evidence(Next)}, loop(Parent, Module, Next);
        close -> Result = transit_sdk_value:protect(fun() -> Module:close(State) end),
            Parent ! {closed, self(), Result, Module:evidence(State)};
        {'EXIT', Parent, _} -> catch Module:close(State), ok
    end.

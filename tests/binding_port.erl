-module(binding_port).
-export([run/0]).
run() ->
    [Fixture, Root] = init:get_plain_arguments(),
    lists:foreach(fun(Mode) ->
        Path = config(Root, Mode),
        {ok, Host} = transit_station:open(Fixture, Path),
        Down = monitor(process, Host),
        {error, {6, _}} = transit_station:next(Host),
        receive {'DOWN', Down, process, Host, _} -> ok after 1000 -> error(failed_port_leaked) end
    end, ["malformed", "oversize", "exit"]),
    Path = config(Root, "stall"),
    {ok, Host} = transit_station:open(Fixture, Path),
    Parent = self(),
    Caller = spawn(fun() -> Parent ! {result, transit_station:next(Host)} end),
    wait_entered(Path, 200),
    {error, {9, _}} = transit_station:pending(Host),
    %% Scheduling remains live while a native port is blocked on network I/O.
    erlang:send_after(10, self(), heartbeat),
    receive heartbeat -> ok after 500 -> error(scheduler_blocked) end,
    Monitor = monitor(process, Host), exit(Caller, kill),
    receive {'DOWN', Monitor, process, Host, _} -> ok after 1000 -> error(port_owner_leaked) end,
    Owner = spawn(fun() ->
        {ok, Owned} = transit_station:open(Fixture, config(Root, "echo")),
        Parent ! {owned, Owned}, receive stop -> ok end
    end),
    receive {owned, Owned} ->
        OwnerMonitor = monitor(process, Owned), exit(Owner, kill),
        receive {'DOWN', OwnerMonitor, process, Owned, _} -> ok after 1000 -> error(owner_monitor_missing) end
    after 1000 -> error(open_failed) end,
    io:format("BEAM: malformed/oversized/lost port, busy admission, scheduler heartbeat and owner/caller death passed~n"), halt().
config(Root, Mode) ->
    Path = filename:join(Root, Mode ++ ".json"), ok = file:write_file(Path, Mode), Path.
wait_entered(_, 0) -> error(no_native_request);
wait_entered(Path, Remaining) ->
    case file:read_file(filename:rootname(Path) ++ ".entered") of
        {ok, _} -> ok;
        _ -> receive after 5 -> wait_entered(Path, Remaining - 1) end
    end.

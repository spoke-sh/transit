-module(transit_erlang_counter).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-export([main/0, run/1]).
main() -> run(init:get_plain_arguments()), halt(0).
run([Path, Role, "--commits", Count]) -> run(Path, Role, list_to_integer(Count));
run([Path, Role]) -> run(Path, Role, 1).
run(Path, Role, Count) when Count > 0 ->
    {ok, File} = file:open(Path, [read, binary, raw]),
    Bytes = try {ok, Data} = file:read(File, 8193), true = byte_size(Data) =< 8192, Data after file:close(File) end,
    Cfg = json:decode(Bytes), <<"native_v1">> = maps:get(<<"profile">>, Cfg), Realm = maps:get(<<"realm">>, Cfg),
    {ok, Client} = transit_client:config(maps:get(<<"url">>, Cfg), native_v1),
    {ok, Process} = transit_client:process(Realm, maps:get(<<"pid">>, Cfg)),
    {ok, Peer} = transit_client:process(Realm, maps:get(<<"peer">>, Cfg)),
    {ok, Credential} = transit_client:credential(Realm, maps:get(<<"principal">>, Cfg), maps:get(<<"seed_file">>, Cfg)),
    Service = #transit_service{client = Client, activation = #transit_activation{process = Process, generation = maps:get(<<"generation">>, Cfg), credential = Credential}},
    {Handler, Codec} = case Role of "service" -> {transit_example_counter, transit_example_counter_codec}; "requester" -> {transit_example_requester, transit_example_requester_codec} end,
    {ok, Runner} = transit_station_sdk:open(Service, Handler, #{peer => Peer}, Codec, stop, fresh_ownership),
    try advance(Runner, Count) after transit_station_sdk:close(Runner) end.
advance(_, 0) -> ok;
advance(Runner, Count) ->
    case transit_station_sdk:next(Runner) of
        {ok, #transit_committed{input = Input, receipt = #transit_receipt{position = Position}}} ->
            io:format("~s~n", [json:encode(#{input => Input, committed => Position})]), advance(Runner, Count - 1);
        {ok, idle} -> timer:sleep(20), advance(Runner, Count);
        {ok, progress} -> advance(Runner, Count);
        _ -> erlang:error(runner_stopped_recovery_required)
    end.

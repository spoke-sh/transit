-module(beam_client_sdk).
-include_lib("transit_client/include/transit_client.hrl").
-export([main/0]).
check(true) -> ok;
check(_) -> erlang:error(proof_failed).
read(Path) -> {ok, Bytes} = file:read_file(Path), Bytes.
report(Value) -> io:format("~s~n", [json:encode(Value)]).
wait_file(Path) -> wait_file(Path, erlang:monotonic_time(millisecond) + 15000).
wait_file(Path, Deadline) ->
    case filelib:is_regular(Path) of true -> ok; false -> check(erlang:monotonic_time(millisecond) < Deadline), timer:sleep(5), wait_file(Path, Deadline) end.
main() ->
    [Mode, Path] = init:get_plain_arguments(), Cfg = json:decode(read(Path)),
    check(lists:prefix(filename:dirname(Path), code:which(transit_client))),
    check(code:which(transit_station) =:= non_existing),
    {ok, Config} = transit_client:config(maps:get(<<"url">>, Cfg), native_v1, #{timeout_ms => 3000}),
    {ok, Credential} = transit_client:credential(72, 65536, maps:get(<<"seed">>, Cfg)),
    {ok, Peer} = transit_client:process(72, maps:get(<<"pid">>, Cfg)),
    {error, _} = transit_client:process(72, true), {error, _} = transit_client:process(72, 1 bsl 53),
    {error, #transit_error{kind = incompatible_native}} = transit_client:open(Config#transit_config{native_host = <<"/missing-transit">>}),
    run(Mode, Cfg, Config, Credential, Peer), halt(0).
run("first", Cfg, Config, Credential, Peer) ->
    {ok, Client} = transit_client:open(Config),
    {ok, Caps} = transit_client:capabilities(Client, Credential),
    check(maps:get(principal_sequence, Caps) =:= 0 andalso maps:get(page_size, Caps) =:= 8 andalso maps:get(retained_versions, Caps)),
    {ok, Pending} = transit_client:prepare_send(Client, Peer, <<"wide">>, Credential, 1),
    Bytes = transit_client:export(Pending),
    check(maps:get(sequence, transit_client:info(Pending)) =:= 1),
    ok = file:write_file(maps:get(<<"pending">>, Cfg), Bytes),
    {uncertain, Bytes, #transit_error{kind = unknown_outcome, status = 6}} = transit_client:dispatch(Client, Pending),
    {ok, _} = transit_client:close(Client);
run("recover", Cfg, Config, _, _) ->
    check(not filelib:is_regular(maps:get(<<"seed">>, Cfg))), {ok, Client} = transit_client:open(Config),
    {ok, Pending} = transit_client:recover_send(Client, read(maps:get(<<"pending">>, Cfg))),
    {admitted, Receipt} = transit_client:dispatch(Client, Pending),
    {ok, #transit_shutdown{last_admission = Receipt}} = transit_client:evidence(Client),
    {admitted, Receipt} = transit_client:dispatch(Client, Pending),
    {error, #transit_error{kind = unsupported_capability}} = transit_client:recover_send(Client, read(maps:get(<<"spawn">>, Cfg))),
    {error, _} = transit_client:recover_send(Client, <<" ", (transit_client:export(Pending))/binary>>),
    {ok, _} = transit_client:close(Client), report(#{position => Receipt#transit_admission.position});
run("async", Cfg, Config, Credential, Peer) ->
    {ok, Client} = transit_client:open(Config),
    {ok, Pending} = transit_client:prepare_send(Client, Peer, <<"async">>, Credential, 2),
    {Caller, Monitor} = spawn_monitor(fun() -> transit_client:dispatch(Client, Pending), erlang:error(unexpected_completion) end),
    wait_file(maps:get(<<"accepted">>, Cfg)),
    {error, #transit_error{kind = busy}} = transit_client:capabilities(Client, Credential),
    exit(Caller, kill), receive {'DOWN', Monitor, process, Caller, killed} -> ok after 1000 -> erlang:error(caller_stuck) end,
    {error, #transit_error{kind = busy}} = transit_client:capabilities(Client, Credential),
    Parent = self(), spawn(fun() -> Parent ! {closed, transit_client:close(Client)} end),
    {Beats, Evidence} = joined(0), check(Beats > 5),
    {error, #transit_error{kind = closed}} = transit_client:recover_send(Client, transit_client:export(Pending)),
    {ok, Fresh} = transit_client:open(Config),
    {ok, Same} = transit_client:recover_send(Fresh, transit_client:export(Pending)),
    {admitted, Receipt} = transit_client:dispatch(Fresh, Same),
    check(Evidence#transit_shutdown.last_admission =:= Receipt), {ok, _} = transit_client:close(Fresh),
    report(#{scenario => <<"blocking-owner-disposal">>, observations => #{controller_wait_abandoned => true,
        responsive_during_join => Beats > 5, owned_work_joined => true, receipt_recovered => true}});
run("denied", Cfg, Config, _, _) ->
    {ok, Client} = transit_client:open(Config), {ok, Pending} = transit_client:recover_send(Client, read(maps:get(<<"pending">>, Cfg))),
    {rejected, #transit_error{kind = access_denied, status = 4}} = transit_client:dispatch(Client, Pending), {ok, _} = transit_client:close(Client).
joined(Beats) -> receive {closed, {ok, Evidence}} -> {Beats, Evidence} after 10 -> check(Beats < 3000), joined(Beats + 1) end.

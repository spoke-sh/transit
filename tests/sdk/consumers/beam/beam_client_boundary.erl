-module(beam_client_boundary).
-behaviour(supervisor).
-include_lib("transit_client/include/transit_client.hrl").
-export([main/0, init/1]).
init(Config) -> {ok, {#{strategy => one_for_one, intensity => 1, period => 5}, [transit_client:child_spec(Config)]}}.
main() ->
    [Directory, Mode] = init:get_plain_arguments(),
    {ok, Config} = transit_client:config(<<"http://127.0.0.1:1">>, native_v1),
    case Mode of
        "missing" -> {error, #transit_error{kind = incompatible_native}} = transit_client:open(Config);
        "normal" ->
            ok = beam_schema_values:run(),
            lists:foreach(fun(Name) ->
                {error, #transit_error{kind = incompatible_native}} = transit_client:open(Config#transit_config{native_host = filename:join(Directory, Name)})
            end, ["bad-version", "fraction", "duplicate", "oversized", "partial", "invalid-utf8", "invalid-status"]),
            lists:foreach(fun(Bytes) ->
                {error, #transit_error{kind = incompatible_native}} = transit_sdk_value:protect(fun() -> transit_sdk_value:json(Bytes) end)
            end, [<<"1.00000000000000000000000001">>, <<"1e999999999">>, <<"1e-999999999">>, <<"{\"a\":1,\"a\":2}">>, <<255>>, binary:copy(<<"[">>, 65)]),
            {ok, Sup} = supervisor:start_link(?MODULE, Config),
            [{transit_client, Pid, worker, _}] = supervisor:which_children(Sup),
            {ok, Client} = transit_client:handle(Pid),
            %% Inject the narrow pre-publication death window. Active jobs are
            %% worker-owned; the shared async schedule checks they stay busy.
            {Dead, Mon} = spawn_monitor(fun() -> ok end),
            receive {'DOWN', Mon, process, Dead, normal} -> ok end,
            {transit_handle, _, _, Admission} = Client,
            true = ets:insert_new(Admission, {operation, Dead, make_ref()}),
            {ok, _} = transit_client:evidence(Client),
            Status = sys:get_status(Pid),
            nomatch = binary:match(term_to_binary(Status), <<"transit_config">>),
            %% A supervised bridge shuts down normally and is not restarted.
            {ok, _} = transit_client:close(Client),
            Before = erlang:ports(),
            {ok, Restarted} = supervisor:restart_child(Sup, transit_client),
            {ok, _} = transit_client:handle(Restarted),
            [NativePort] = erlang:ports() -- Before,
            ok = supervisor:terminate_child(Sup, transit_client),
            undefined = erlang:port_info(NativePort),
            false = is_process_alive(Restarted),
            gen_server:stop(Sup)
    end,
    halt(0).

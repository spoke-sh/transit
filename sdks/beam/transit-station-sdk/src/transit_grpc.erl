%% Public owned RPC values; shared Zig owns encoding, publication and replay.
-module(transit_grpc).
-include("transit_station_sdk.hrl").
-export([method/2, method/3, prepare/5, prepare/6, decode_reply/2, decode_reply/3, stage/2, call/3,
         release/4, retry/4, diagnostic/2, diagnostic/3, open/2, open/3, read/1, complete/1, close/1, part/2]).
-export_type([reader/0, metadata_value/0]).
-opaque reader() :: {transit_grpc_reader, transit_station_sdk:runner(), pos_integer(), non_neg_integer(), boolean()}.
-type metadata_value() :: {literal, binary()} | {secret, binary(), pos_integer()}.
method(Descriptor, Path) -> method(Descriptor, Path, undefined).
method(Descriptor, Path, Override) -> transit_sdk_value:protect(fun() ->
    #{<<"descriptor">> := #{<<"method">> := Method}} = local(#{<<"descriptor">> => #{
        <<"bytes">> => transit_sdk_value:hex(transit_sdk_value:bytes(Descriptor,65536)), <<"method">> => transit_sdk_value:text(Path,512)}},Override),
    #transit_grpc_method{path = maps:get(<<"path">>,Method), shape = known(maps:get(<<"shape">>,Method),[unary,server_streaming,client_streaming,bidi]),
        descriptor_digest = transit_sdk_value:unhex(maps:get(<<"descriptor_digest">>,Method),32)}
end).
prepare(Resource, Namespace, Request, Messages, Options) -> prepare(Resource, Namespace, Request, Messages, Options, undefined).
prepare(#transit_resource{realm = Realm, resource = Resource} = Ref, Namespace, #transit_grpc_request{method = #transit_grpc_method{path=Path,shape=Shape,descriptor_digest=Digest}, metadata = Metadata}, Messages, Options, Override) ->
    transit_sdk_value:protect(fun() ->
        transit_sdk_value:counter(Realm), transit_sdk_value:counter(Resource), positive(Namespace),
        true = is_list(Messages) andalso length(Messages) =< 64,
        Batch = [transit_sdk_value:hex(transit_sdk_value:bytes(Message,16384)) || Message <- Messages],
        true = is_list(Metadata) andalso length(Metadata) =< 64,
        true = byte_size(Digest) =:= 32,
        Fields = [#{<<"name">>=>transit_sdk_value:text(Name,8192),<<"value">>=>metadata(Value)} || {Name,Value} <- Metadata],
        true = length(Fields) =:= length(Metadata),
        Request = #{<<"method">>=>#{<<"path">>=>transit_sdk_value:text(Path,512),<<"shape">>=>transit_station_value:enum(Shape,[unary,server_streaming,client_streaming,bidi]),
            <<"descriptor_digest">>=>transit_sdk_value:hex(Digest)},<<"metadata">>=>Fields},
        Revision = positive(maps:get(endpoint_revision, Options)), Deadline = transit_sdk_value:counter(maps:get(reconcile_before_ms, Options)),
        Attempts = transit_sdk_value:integer(maps:get(max_attempts, Options, 1), 1, 4294967295),
        #{<<"prepared">> := Prepared} = local(#{<<"prepare">> => #{<<"resource">> => Resource, <<"namespace">> => integer_to_binary(Namespace),
            <<"request">> => Request, <<"messages">> => Batch, <<"endpoint_revision">> => integer_to_binary(Revision),
            <<"reconcile_before_ms">> => Deadline, <<"max_attempts">> => Attempts}}, Override),
        #transit_grpc_prepared{resource = Ref, namespace = Namespace, reference = transit_sdk_value:unhex(maps:get(<<"reference">>, Prepared), 145),
            metadata = transit_sdk_value:unhex(maps:get(<<"metadata">>, Prepared), 8192), batch = transit_sdk_value:unhex(maps:get(<<"batch">>,Prepared),65544)}
    end);
prepare(_, _, _, _, _, _) -> {error, transit_sdk_value:error(invalid_argument, grpc_request)}.
metadata({literal, Value}) -> #{<<"literal">>=>transit_sdk_value:hex(transit_sdk_value:bytes(Value,8192))};
metadata({secret, Binding, Version}) -> #{<<"secret">> => #{<<"binding">> => transit_sdk_value:text(Binding, 128), <<"version">> => integer_to_binary(positive(Version))}};
metadata(_) -> transit_sdk_value:fail(invalid_argument, grpc_metadata).
positive(Value) -> transit_sdk_value:integer(Value, 1, 18446744073709551615).
local(Action, Override) -> local(Action, Override, <<"grpc_requests">>).
local(Action, Override, Capability) ->
    case transit_sdk_worker:open(transit_station_runner, {local, Override}, false) of
        {ok, Worker} ->
            try
                case transit_sdk_worker:invoke(Worker, {grpc_codec, Action, Capability}) of
                    {ok, Result} -> Result;
                    {error, Error} -> throw({transit_sdk, Error})
                end
            after transit_sdk_worker:close(Worker) end;
        {error, Error} -> throw({transit_sdk, Error})
    end.
decode_reply(Realm, Bytes) -> decode_reply(Realm, Bytes, undefined).
decode_reply(Realm, Bytes, Override) -> transit_sdk_value:protect(fun() ->
    transit_sdk_value:counter(Realm),
    Owned = transit_sdk_value:bytes(Bytes, 232),
    Capability = case Owned of <<"GRK1", _/binary>> -> <<"grpc_release">>; _ -> <<"grpc_requests">> end,
    Value = local(#{<<"outcome">> => transit_sdk_value:hex(Owned)}, Override, Capability),
    case Value of
        #{<<"rejected">> := Rejection} -> #transit_grpc_rejected{reason = known(maps:get(<<"reason">>, Rejection), [denied, invalid_request, busy]), diagnostic = maps:get(<<"diagnostic">>, Rejection)};
        #{<<"released">> := Released} -> #transit_grpc_released{
            resource = #transit_resource{realm = Realm, resource = transit_sdk_value:counter(maps:get(<<"resource">>, Released))},
            exchange = positive(transit_sdk_value:wide(maps:get(<<"exchange">>, Released)))};
        #{<<"outcome">> := Result} ->
            #transit_grpc_outcome{phase = known(maps:get(<<"phase">>, Result), [observed, closed_unknown, not_dispatched]),
                resource = #transit_resource{realm = Realm, resource = transit_sdk_value:counter(maps:get(<<"resource">>, Result))},
                exchange = positive(transit_sdk_value:wide(maps:get(<<"exchange">>, Result))), effect = transit_sdk_value:counter(maps:get(<<"effect">>, Result), 0),
                attempt = transit_sdk_value:counter(maps:get(<<"attempt">>, Result), 0),
                status = case maps:get(<<"status">>, Result) of null -> undefined; Code -> transit_sdk_value:integer(Code, 0, 16) end,
                reference = case maps:get(<<"reference">>, Result) of null -> undefined; Ref -> transit_sdk_value:unhex(Ref, 256) end, diagnostic = maps:get(<<"diagnostic">>, Result)}
    end end).
known(Value, Allowed) ->
    case [Atom || Atom <- Allowed, atom_to_binary(Atom, utf8) =:= Value] of [Result] -> Result; _ -> transit_sdk_value:fail(incompatible_native, grpc_enum) end.
scope(Turn, #transit_grpc_prepared{resource = #transit_resource{realm = Realm, resource = Resource}}) ->
    #{process := #transit_process{realm = Realm}, event := #{<<"resource">> := Resource}, bridge := Bridge} = transit_turn:data(Turn),
    case maps:get(<<"grpc_requests">>, transit_station_bridge:caps(Bridge)) of true -> ok; false -> transit_sdk_value:fail(unsupported_capability, grpc_requests) end.
stage(Turn, #transit_grpc_prepared{reference = Reference, metadata = Metadata, batch = Batch} = Request) -> transit_turn:access(Turn, false, fun() ->
    scope(Turn, Request),
    Result = transit_turn:raw(Turn, #{<<"grpc_stage">> => #{<<"reference">> => transit_sdk_value:hex(transit_sdk_value:bytes(Reference, 145)),
        <<"metadata">> => transit_sdk_value:hex(transit_sdk_value:bytes(Metadata, 8192)), <<"batch">> => transit_sdk_value:hex(transit_sdk_value:bytes(Batch, 65544))}}),
    transit_sdk_value:boolean(maps:get(<<"staged">>, Result)) end).
call(Turn, Peer, #transit_grpc_prepared{reference = Reference} = Request) -> transit_turn:access(Turn, false, fun() ->
    scope(Turn, Request),
    Result = transit_turn:raw(Turn, #{<<"grpc_call">> => #{<<"pid">> => transit_turn:peer(Turn, Peer), <<"reference">> => transit_sdk_value:hex(transit_sdk_value:bytes(Reference, 145))}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
release(Turn, Peer, Capture, Exchange) -> transit_turn:access(Turn, false, fun() ->
    #{process := #transit_process{realm = Realm}, bridge := Bridge} = transit_turn:data(Turn),
    Resource = case Capture of #transit_resource{realm = Realm, resource = Id} -> transit_sdk_value:counter(Id);
        _ -> transit_sdk_value:fail(invalid_argument, grpc_release_resource) end,
    positive(Exchange),
    case maps:get(<<"grpc_release">>, transit_station_bridge:caps(Bridge), false) of
        true -> ok; false -> transit_sdk_value:fail(unsupported_capability, grpc_release) end,
    Result = transit_turn:raw(Turn, #{<<"grpc_release">> => #{<<"pid">> => transit_turn:peer(Turn, Peer),
        <<"resource">> => Resource, <<"exchange">> => integer_to_binary(Exchange)}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
retry(Turn, Peer, Parent, #transit_grpc_prepared{reference = Reference} = Request) -> transit_turn:access(Turn, false, fun() ->
    scope(Turn, Request),
    #{process := #transit_process{realm = Realm}, bridge := Bridge} = transit_turn:data(Turn),
    {Resource, Exchange} = case Parent of
        #transit_grpc_outcome{resource = #transit_resource{realm = Realm, resource = Id}, exchange = ParentId} -> {transit_sdk_value:counter(Id), positive(ParentId)};
        _ -> transit_sdk_value:fail(invalid_argument, grpc_followup_parent) end,
    case maps:get(<<"grpc_followup">>, transit_station_bridge:caps(Bridge), false) of
        true -> ok; false -> transit_sdk_value:fail(unsupported_capability, grpc_followup) end,
    Result = transit_turn:raw(Turn, #{<<"grpc_followup">> => #{<<"pid">> => transit_turn:peer(Turn, Peer), <<"resource">> => Resource,
        <<"parent">> => integer_to_binary(Exchange), <<"reference">> => transit_sdk_value:hex(transit_sdk_value:bytes(Reference, 145))}}),
    positive(transit_sdk_value:wide(maps:get(<<"correlation">>, Result))) end).
diagnostic(Runner, Outcome) -> diagnostic(Runner, Outcome, capture_failure).
diagnostic(Runner, #transit_grpc_outcome{resource = #transit_resource{realm = Realm, resource = Resource}, exchange = Exchange}, Kind) ->
    case transit_sdk_value:protect(fun() -> {transit_sdk_value:counter(Resource), positive(Exchange), transit_station_value:enum(Kind, [capture_failure, native_effect])} end) of
        {ok, {Id, Ex, Selected}} -> transit_sdk_worker:invoke(Runner, {grpc, {diagnostic, Realm, Id, Ex, Selected}});
        Error -> Error
    end;
diagnostic(_, _, _) -> {error, transit_sdk_value:error(invalid_argument, grpc_outcome)}.
open(Runner, Outcome) -> open(Runner, Outcome, captured).
open(Runner, #transit_grpc_outcome{phase = observed, resource = #transit_resource{realm = Realm}, reference = Reference}, Policy) ->
    case transit_sdk_value:protect(fun() -> {transit_sdk_value:bytes(Reference, 256), transit_station_value:enum(Policy, [captured, require_unredacted])} end) of
        {ok, {Ref, Mode}} -> case transit_sdk_worker:invoke(Runner, {grpc, {open, Realm, Ref, Mode}}) of
            {ok, {Id, Step}} -> {ok, {transit_grpc_reader, Runner, Id, Step, false}};
            Error -> Error end;
        Error -> Error
    end;
open(_, _, _) -> {error, transit_sdk_value:error(invalid_argument, grpc_outcome)}.
read({transit_grpc_reader, Runner, Id, Step, _}) ->
    case transit_sdk_worker:invoke(Runner, {grpc, {next, Id, Step}}) of
        {ok, {Part, Next, Complete}} -> {ok, {Part, {transit_grpc_reader, Runner, Id, Next, Complete}}};
        Error -> Error
    end.
complete({transit_grpc_reader, _, _, _, Complete}) -> Complete.
close({transit_grpc_reader, Runner, Id, _, _}) -> transit_sdk_worker:invoke(Runner, {grpc, {close, Id}}).
part(#{<<"part">> := null}, true) -> {done, true};
part(#{<<"part">> := #{<<"kind">> := Kind, <<"bytes">> := Bytes, <<"complete">> := Complete}}, _) ->
    Part = #transit_grpc_part{kind = known(Kind, [request_metadata, request_batch, endpoint_policy, initial_metadata, response_message, response_body, half_close, trailers, timing, omission, completion]),
        bytes = transit_sdk_value:unhex(Bytes, 256), complete = transit_sdk_value:boolean(Complete)},
    {Part, Complete};
part(_, _) -> transit_sdk_value:fail(incompatible_native, grpc_incomplete).

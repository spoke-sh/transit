-module(transit_table).
-include("transit_station_sdk.hrl").
-export([schema/2, schema/4, create/2, open/2, open_source/2, basis/1, get/2,
         insert/2, update/2, upsert/2, delete/2, page/1, page/2, open_raw/3]).
-export_type([table/0]).
-opaque table() :: {transit_table, transit_turn:turn(), #transit_table_schema{}, undefined | #transit_read_version{}, #transit_basis{}}.
schema(Id, Cell) -> schema(Id, Cell, <<"id">>, <<"value">>).
schema(Id, Cell, KeyName, ValueName) -> transit_sdk_value:protect(fun() ->
    transit_station_value:enum(Cell, [int64, boolean, utf8, binary]),
    #transit_table_schema{id = transit_sdk_value:integer(Id, 1, 4294967295), cell = Cell,
        key_name = transit_sdk_value:text(KeyName, 256), value_name = transit_sdk_value:text(ValueName, 256)} end).
create(Turn, #transit_table_schema{id = Id, cell = Cell, key_name = KeyName, value_name = ValueName} = Schema) ->
    case transit_turn:access(Turn, false, fun() ->
        Bound = transit_turn:limit(Turn, <<"table_name_bytes">>),
        transit_turn:raw(Turn, #{<<"table_create">> => #{<<"id">> => transit_sdk_value:integer(Id, 1, 4294967295),
            <<"key_name">> => transit_sdk_value:text(KeyName, Bound), <<"value_name">> => transit_sdk_value:text(ValueName, Bound),
            <<"value_type">> => transit_station_value:enum(Cell, [int64, boolean, utf8, binary])}}), ok end) of
        {ok, _} -> open(Turn, Schema);
        Error -> Error
    end.
open(Turn, Schema) -> transit_turn:access(Turn, true, fun() -> open_raw(Turn, Schema, undefined) end).
open_source({transit_source, Turn, Version}, Schema) -> transit_turn:access(Turn, true, fun() -> open_raw(Turn, Schema, Version) end).
open_raw(Turn, #transit_table_schema{id = Id, cell = Cell, key_name = KeyName, value_name = ValueName} = Schema, Version) ->
    Request = versioned(#{<<"id">> => transit_sdk_value:integer(Id, 1, 4294967295)}, Version),
    Actual = maps:get(<<"schema">>, transit_turn:raw(Turn, #{<<"table_schema">> => Request})),
    case {maps:get(<<"key_name">>, Actual), maps:get(<<"value_name">>, Actual), maps:get(<<"value_type">>, Actual)} of
        {KeyName, ValueName, CellName} ->
            case CellName =:= transit_station_value:enum(Cell, [int64, boolean, utf8, binary]) of
                true -> ok; false -> transit_sdk_value:fail(handler, table_schema_changed) end;
        _ -> transit_sdk_value:fail(handler, table_schema_changed)
    end,
    {transit_table, Turn, Schema, Version, transit_station_value:basis(maps:get(<<"basis">>, Actual), realm(Turn))}.
basis({transit_table, Turn, _, _, Basis}) -> transit_turn:access(Turn, false, fun() -> Basis end).
get({transit_table, Turn, #transit_table_schema{id = Id}, Version, _}, Key) -> transit_turn:access(Turn, true, fun() ->
    Request = versioned(#{<<"id">> => Id, <<"key">> => transit_station_value:signed(Key)}, Version),
    Kind = case Version of undefined -> <<"table_get">>; _ -> <<"version_table_get">> end,
    case maps:get(<<"row">>, transit_turn:raw(Turn, #{Kind => Request})) of null -> missing; Value -> {found, row(Turn, Value)} end end).
insert(Table, Row) -> write(Table, insert, Row).
update(Table, Row) -> write(Table, update, Row).
upsert(Table, Row) -> write(Table, upsert, Row).
write({transit_table, Turn, #transit_table_schema{id = Id, cell = Cell}, Version, _}, Mode, #transit_row{key = Key, value = Value}) ->
    transit_turn:access(Turn, false, fun() -> writable(Version),
        Row = #{<<"key">> => transit_station_value:signed(Key), <<"value">> => transit_station_value:cell(Value, Cell, transit_turn:limit(Turn, <<"table_cell_bytes">>))},
        transit_turn:raw(Turn, #{<<"table_write">> => #{<<"id">> => Id, <<"mode">> => atom_to_binary(Mode, utf8), <<"row">> => Row}}), ok end).
delete({transit_table, Turn, #transit_table_schema{id = Id}, Version, _}, Key) -> transit_turn:access(Turn, false, fun() -> writable(Version),
    transit_turn:raw(Turn, #{<<"table_delete">> => #{<<"id">> => Id, <<"key">> => transit_station_value:signed(Key)}}), ok end).
page(Table) -> page(Table, undefined).
page({transit_table, Turn, #transit_table_schema{id = Id}, Version, _}, Cursor) -> transit_turn:access(Turn, true, fun() ->
    Request = versioned(#{<<"id">> => Id, <<"cursor">> => transit_station_value:cursor(Cursor)}, Version),
    Value = maps:get(<<"rows">>, transit_turn:raw(Turn, #{<<"table_page">> => Request})),
    #transit_page{entries = [row(Turn, Item) || Item <- maps:get(<<"rows">>, Value), Item =/= null],
        cursor = transit_station_value:cursor(maps:get(<<"next">>, Value)), basis = transit_station_value:basis(maps:get(<<"basis">>, Value), realm(Turn))} end).
versioned(Request, undefined) -> Request;
versioned(Request, Identity) -> Request#{<<"version">> => transit_turn:version(Identity)}.
row(Turn, Value) -> #transit_row{key = transit_sdk_value:signed(maps:get(<<"key">>, Value)), value = transit_station_value:cell_value(maps:get(<<"value">>, Value), transit_turn:limit(Turn, <<"table_cell_bytes">>))}.
realm(Turn) -> #transit_process{realm = Realm} = maps:get(process, transit_turn:data(Turn)), Realm.
writable(undefined) -> ok;
writable(_) -> transit_sdk_value:fail(handler, retained_source_read_only).

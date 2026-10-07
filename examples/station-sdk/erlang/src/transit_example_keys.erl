-module(transit_example_keys).
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
-include_lib("transit_station_sdk/include/transit_catalog.hrl").
-export([total/0, request/0, observed/0, table/0, limits/0, not_ready/0, signed/1]).
total() -> #transit_key{name = <<"total">>, codec = transit_example_u64_codec}.
request() -> #transit_key{name = <<"request">>, codec = transit_example_u64_codec}.
observed() -> #transit_key{name = <<"observed">>, codec = transit_example_u64_codec}.
not_ready() -> #transit_key{name = <<"not-ready">>, codec = transit_example_u64_codec}.
signed(Value) -> {value,{atom,{signed,Value}}}.
limits() -> #transit_catalog_limits{record_bytes=65536,staging_bytes=8388608,staging_records=1024}.
table() -> #transit_catalog_schema{object=1,revision=1,next_column=5,primary_key=[1],columns=[
    #transit_catalog_column{id=1,name= <<"id">>,type=int64,nullable=false},
    #transit_catalog_column{id=2,name= <<"value">>,type=int64},
    #transit_catalog_column{id=3,name= <<"label">>,type=utf8,nullable=false,default={value,{atom,{utf8,<<"example">>}}}},
    #transit_catalog_column{id=4,name= <<"tags">>,type={list,#transit_logical_element{type=int64}},nullable=false,default={value,{list,[signed(1),signed(2)]}}}
]}.

-ifndef(TRANSIT_MUTATIONS_HRL).
-define(TRANSIT_MUTATIONS_HRL, true).
-include("transit_station_sdk.hrl").
-record(transit_mutation_connection, {writer :: #transit_process{}, resource :: #transit_resource{}, table :: pos_integer()}).
-record(transit_mutation_reference, {bytes :: binary()}).
-record(transit_mutation_compiled, {request :: binary(), reference :: #transit_mutation_reference{}}).
-record(transit_mutation_prepared, {bytes :: binary()}).
-record(transit_mutation_description, {resource :: #transit_resource{}, table, names = [], value_type,
    resource_revision, policy_revision, declaration :: binary(), permissions = [], active = undefined}).
-record(transit_mutation_status, {reference :: #transit_mutation_reference{}, principal, table,
    declaration :: binary(), policy_revision, phase, affected_rows, reason, input}).
-endif.

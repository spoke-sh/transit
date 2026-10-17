%% Public host values; generated ABI declarations live separately in priv/.
-ifndef(TRANSIT_CLIENT_HRL).
-define(TRANSIT_CLIENT_HRL, true).
-type transit_counter() :: 1..9007199254740991.
-record(transit_process, {realm :: transit_counter(), pid :: transit_counter()}).
-record(transit_resource, {realm :: transit_counter(), resource :: transit_counter()}).
-record(transit_credential, {realm :: transit_counter(), principal :: 0..9007199254740991, seed_file :: binary()}).
-record(transit_config, {url :: binary(), profile :: native_v1, timeout_ms = 5000 :: 1..60000,
                         native_host = undefined :: undefined | binary() | string()}).
-record(transit_error, {kind :: atom(), phase :: atom(), status = undefined :: undefined | non_neg_integer(),
                       code = undefined :: undefined | binary(), diagnostic = undefined :: undefined | map(),
                       diagnostic_invalid = false :: boolean()}).
-record(transit_identity, {sha256 :: binary()}).
-record(transit_admission, {position :: transit_counter()}).
-record(transit_receipt, {position :: transit_counter()}).
-record(transit_shutdown, {last_admission = undefined :: undefined | #transit_admission{},
                          last_mutation = undefined :: undefined | #transit_receipt{}}).
-endif.

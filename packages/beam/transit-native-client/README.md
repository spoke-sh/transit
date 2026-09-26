# Transit BEAM native client artifact

This independent OTP application contains the version-matched Zig client port
in `priv/transit-client-host`. It imports no Station implementation. Version
0.2.0 targets Linux x86_64 and requires the pinned Nix closure. Loading the app
starts no port, signing or authority work. The public client discovers it through
standard `code:priv_dir/1` resolution and verifies its package/host versions.

Build and clean-consumer qualification run through `just bindings::beam-sdk-test`. Registry
publication and portable artifacts are outside the qualified scope.

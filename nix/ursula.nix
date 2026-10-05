{ upstream }:

# Keep the overlay's exact source, Cargo lock and Rust toolchain. This local
# correction lets a large stream use the remainder of a cold-flush batch after
# a smaller stream, without raising provider memory or admission limits.
assert upstream.version == "0.5.1";
upstream.overrideAttrs (old: {
  version = "${old.version}-transit-cold-flush";
  __intentionallyOverridingVersion = true;
  patches = (old.patches or [ ]) ++ [ ./ursula-cold-flush.patch ];
  doCheck = true;
  cargoTestFlags = [
    "--package"
    "ursula-stream"
  ];
})
